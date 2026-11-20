# Android: `ref.focus()` on a `View` does nothing when called from a tap, with `enableImperativeFocus` on

React Native 0.90.0-nightly-20261120-bbfd39149, from the [React Native reproducer template](https://github.com/react-native-community/reproducer-react-native). `MainApplication.kt` turns on the `enableImperativeFocus` feature flag, under which `ref.focus()` on a `View` sends the native `focus` command. `ReproducerApp/App.tsx` renders:

- a `Pressable`, "move focus", whose `onPress` calls `focus()` on the next one;
- a `Pressable`, "focus target", which shows a pink border while it holds focus;
- a text counting the presses of "move focus".

## Steps

By hand, on an Android device or emulator:

1. Build and install the release APK: `cd ReproducerApp && yarn install && cd android && ./gradlew assembleRelease && adb install -r app/build/outputs/apk/release/app-release.apk`.
2. Open the app and tap "move focus". The press count goes up, but "focus target" does not take focus.
3. Restart the app, press Tab on a hardware keyboard to focus "move focus", then press Enter. The press count goes up and "focus target" takes focus.

Without a keyboard: `adb shell input keyevent KEYCODE_TAB`, then `adb shell input keyevent KEYCODE_ENTER`.

Scripted: `./reproduce.sh`, with one Android device attached, builds and installs the app, taps "move focus" on a fresh launch and reads which view holds focus from `uiautomator dump`, then on a fresh launch moves to "move focus" with Tab, presses Enter and reads it again. It exits 1 while the tap leaves "focus target" without focus although Enter focuses it, 0 once the tap focuses it too, and 2 when Enter does not focus it either, an `onPress` does not run, or a step fails.
