#!/usr/bin/env bash
# Exit 1 while a tap on "move focus", whose onPress calls ref.focus() on the View "focus target" with
# enableImperativeFocus on, leaves the target without focus although Enter on "move focus" focuses it; 0 once the tap
# focuses the target too; 2 when Enter does not focus the target either, an onPress does not run, or a step fails.
# Needs adb with one Android device attached (ANDROID_SERIAL picks one of several), node, yarn and a JDK.
set -u

package=com.reproducerapp
mover="move focus"
target="focus target"

fail_step() {
    echo "step failed: $1"
    exit 2
}

# The path as the platform's own programs take it: Git Bash's /c/... becomes C:/... for adb on Windows.
native_path() {
    if command -v cygpath > /dev/null; then
        cygpath -m "$1"
    else
        printf '%s\n' "$1"
    fi
}

# Sets the named variable to a device property, without the carriage return adb's shell ends it with.
read_device_property() {
    local value
    value="$(adb shell getprop "$2")" || fail_step "adb shell getprop $2: ${value}"
    printf -v "$1" '%s' "${value//$'\r'/}"
}

dump_window() {
    adb shell uiautomator dump /sdcard/ref-focus-reproducer.xml > /dev/null 2>&1
    adb exec-out cat /sdcard/ref-focus-reproducer.xml 2> /dev/null
    adb shell rm -f /sdcard/ref-focus-reproducer.xml
}

wait_for_label() {
    local label=$1 attempt hierarchy
    for ((attempt = 1; attempt <= 30; attempt += 1)); do
        hierarchy="$(dump_window)"
        if [[ "${hierarchy}" == *"content-desc=\"${label}\""* ]]; then
            return 0
        fi
        sleep 1
    done
    return 1
}

# Starts the app afresh, so no view holds focus and no press has run.
launch_app() {
    adb shell am force-stop "${package}" > /dev/null || fail_step "adb shell am force-stop ${package}"
    adb shell am start -W -n "${package}/.MainActivity" > /dev/null || fail_step "starting ${package}"
    wait_for_label "${target}" || fail_step "the app showed no \"${target}\""
}

# Prints the content-desc of the node uiautomator reads as focused, or "(nothing focused)". A dump with no focused
# node is taken again, up to three times, since focus can be on its way.
focused_label() {
    local attempt hierarchy node pattern='content-desc="([^"]*)"'
    for ((attempt = 1; attempt <= 3; attempt += 1)); do
        hierarchy="$(dump_window)"
        while IFS= read -r node; do
            if [[ "${node}" == *'focused="true"'* && "${node}" =~ ${pattern} ]]; then
                printf '%s\n' "${BASH_REMATCH[1]}"
                return 0
            fi
        done <<< "${hierarchy//<node/$'\n'<node}"
        sleep 1
    done
    printf '%s\n' "(nothing focused)"
}

# Prints the centre of the node whose content-desc is the label, as "x y".
centre_of() {
    local label=$1 hierarchy node pattern='bounds="\[([0-9]+),([0-9]+)\]\[([0-9]+),([0-9]+)\]"'
    hierarchy="$(dump_window)"
    while IFS= read -r node; do
        if [[ "${node}" == *"content-desc=\"${label}\""* && "${node}" =~ ${pattern} ]]; then
            printf '%s %s\n' $(((BASH_REMATCH[1] + BASH_REMATCH[3]) / 2)) $(((BASH_REMATCH[2] + BASH_REMATCH[4]) / 2))
            return 0
        fi
    done <<< "${hierarchy//<node/$'\n'<node}"
    return 1
}

# Taps "move focus" on a fresh launch and sets `tap_focus` to the view that holds focus after its onPress ran.
tap_path() {
    local centre
    launch_app
    echo "== tap \"${mover}\" on a fresh launch"
    centre="$(centre_of "${mover}")" || fail_step "no bounds for \"${mover}\""
    # shellcheck disable=SC2086 # the centre is two words, x and y
    adb shell input tap ${centre} > /dev/null || fail_step "tapping \"${mover}\""
    wait_for_label "${mover} pressed 1 times" || fail_step "the tap did not run \"${mover}\"'s onPress"
    tap_focus="$(focused_label)"
    echo "  after the tap and its onPress: \"${tap_focus}\" holds focus"
}

# Moves keyboard focus to "move focus" with Tab on a fresh launch, presses Enter, and sets `key_focus` to the view that
# holds focus after its onPress ran.
key_path() {
    local count focused=""
    launch_app
    echo "== Tab to \"${mover}\" on a fresh launch, then Enter"
    for ((count = 1; count <= 3; count += 1)); do
        adb shell input keyevent KEYCODE_TAB > /dev/null || fail_step "pressing Tab"
        sleep 1
        focused="$(focused_label)"
        [[ "${focused}" == "${mover}" ]] && break
    done
    [[ "${focused}" == "${mover}" ]] || fail_step "Tab did not reach \"${mover}\" (\"${focused}\" holds focus)"
    echo "  Tab ${count}: \"${focused}\" holds focus"
    adb shell input keyevent KEYCODE_ENTER > /dev/null || fail_step "pressing Enter"
    wait_for_label "${mover} pressed 1 times" || fail_step "Enter did not run \"${mover}\"'s onPress"
    key_focus="$(focused_label)"
    echo "  after Enter and its onPress: \"${key_focus}\" holds focus"
}

check_focus() {
    tap_path
    key_path
    if [[ "${key_focus}" != "${target}" ]]; then
        echo "SUMMARY: inconclusive: after Enter's onPress called focus(), \"${key_focus}\" holds focus, not \"${target}\""
        exit 2
    fi
    if [[ "${tap_focus}" == "${target}" ]]; then
        echo "SUMMARY: ref.focus() from a tap's onPress focuses \"${target}\", as from Enter's"
        exit 0
    fi
    local left="\"${tap_focus}\" focused"
    [[ "${tap_focus}" == "(nothing focused)" ]] && left="no view focused"
    echo "SUMMARY: ref.focus() from a tap's onPress leaves ${left}; from Enter's it focuses \"${target}\""
    exit 1
}

main() {
    local here app
    here="$(cd "$(dirname "$0")" && pwd)"
    app="${here}/ReproducerApp"

    local system node_version java_version
    system="$(uname -sm)"
    node_version="$(node --version 2>&1)" || fail_step "node --version: ${node_version}"
    java_version="$(java -version 2>&1)" || fail_step "java -version: ${java_version}"
    echo "${system}, node ${node_version}, ${java_version%%$'\n'*}"

    local device_state
    device_state="$(adb get-state 2>&1)"
    [[ "${device_state}" == "device" ]] || fail_step "adb get-state: ${device_state}"
    local model release sdk abi
    read_device_property model ro.product.model
    read_device_property release ro.build.version.release
    read_device_property sdk ro.build.version.sdk
    read_device_property abi ro.product.cpu.abi
    echo "device: ${model}, Android ${release} (API ${sdk}), ${abi}"

    local install_output react_native_version
    install_output="$(cd "${app}" && yarn install --frozen-lockfile --non-interactive 2>&1)" ||
        { printf '%s\n' "${install_output}" | tail -n 20; fail_step "yarn install"; }
    react_native_version="$(cd "${app}" && node -p 'require("react-native/package.json").version' 2>&1)" ||
        fail_step "reading react-native's version: ${react_native_version}"
    echo "react-native ${react_native_version}, enableImperativeFocus on (MainApplication.kt)"

    echo "== ./gradlew :app:assembleRelease -PreactNativeArchitectures=${abi}"
    local build_output
    build_output="$(cd "${app}/android" && ./gradlew --no-daemon --console=plain :app:assembleRelease \
        "-PreactNativeArchitectures=${abi}" 2>&1)" ||
        { printf '%s\n' "${build_output}" | tail -n 40; fail_step "the release build"; }

    local apk install_result
    apk="$(native_path "${app}/android/app/build/outputs/apk/release/app-release.apk")"
    install_result="$(adb install -r "${apk}" 2>&1)" || fail_step "adb install: ${install_result}"

    check_focus
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    main "$@"
fi
