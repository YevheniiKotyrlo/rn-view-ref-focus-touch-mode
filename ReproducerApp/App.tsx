/**
 * With enableImperativeFocus on (MainApplication.kt), "move focus" calls ref.focus() on "focus target" from its
 * onPress. A tap on "move focus" should focus the target, as Enter on it does.
 *
 * @format
 */

import { useRef, useState } from 'react';
import { Pressable, StyleSheet, Text, View } from 'react-native';

function App() {
  const target = useRef<View>(null);
  const [presses, setPresses] = useState(0);
  const [targetFocused, setTargetFocused] = useState(false);
  return (
    <View style={styles.screen}>
      <Text style={styles.caption}>
        Tap "move focus": it calls focus() on "focus target", which should
        then hold focus and show a pink border.
      </Text>
      <Pressable
        accessibilityLabel="move focus"
        onPress={() => {
          setPresses(count => count + 1);
          target.current?.focus();
        }}
        style={styles.button}
      >
        <Text style={styles.buttonText}>move focus</Text>
      </Pressable>
      <Pressable
        ref={target}
        accessibilityLabel="focus target"
        onFocus={() => setTargetFocused(true)}
        onBlur={() => setTargetFocused(false)}
        style={[styles.button, targetFocused && styles.focused]}
      >
        <Text style={styles.buttonText}>focus target</Text>
      </Pressable>
      <Text
        accessibilityLabel={`move focus pressed ${presses} times`}
        style={styles.caption}
      >
        move focus pressed {presses} times
      </Text>
    </View>
  );
}

const styles = StyleSheet.create({
  screen: {
    flex: 1,
    backgroundColor: 'white',
    paddingHorizontal: 24,
    paddingTop: 64,
    gap: 16,
  },
  caption: {
    color: 'black',
    fontSize: 16,
  },
  button: {
    alignSelf: 'flex-start',
    backgroundColor: '#eeeeee',
    borderColor: '#eeeeee',
    borderWidth: 4,
    paddingHorizontal: 20,
    paddingVertical: 12,
  },
  focused: {
    borderColor: '#d81b60',
  },
  buttonText: {
    color: 'black',
    fontSize: 16,
  },
});

export default App;
