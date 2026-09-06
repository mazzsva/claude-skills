---
name: simulator-frame-screenshot
description: Captures the open iOS Simulator and puts the screen inside an Apple bezel. Use when asked for a framed screenshot, a device mockup, or to frame an image that already exists.
---

# Simulator Frame Screenshot

## Goal

Capture the open simulator and put the screen inside an Apple bezel, named
`<project>-<view>-<colour>.png`.

## Quick start

Put the colour of the argument into `grep -Fix`. Put the name of a simulator into
`grep -Fi`, or leave it empty. Then run it:

```bash
SKILL=$(ls -d .claude/skills/simulator-frame-screenshot ~/.claude/skills/simulator-frame-screenshot 2>/dev/null | head -1)
SHOT="${TMPDIR:-/tmp/}simulator-frame-screenshot.png"
[ -n "$SKILL" ] && { [ "$SKILL/frame" -nt "$SKILL/frame.swift" ] || swiftc -O "$SKILL/frame.swift" -o "$SKILL/frame"; }
BOOTED=$(xcrun simctl list devices booted | sed -n 's/^ *\(.*\) (\([0-9A-Fa-f-]\{36\}\)) (Booted).*/\2 \1/p' | grep -Fi -- "<simulator>")
UDID=$(printf '%s\n' "$BOOTED" | head -1 | cut -d' ' -f1)
DEVICE=$(printf '%s\n' "$BOOTED" | head -1 | cut -d' ' -f2-)
COLOURS=$(DEVTOOLS_BEZELS="$SKILL/Bezels" "$SKILL/frame" --list "$DEVICE" 2>/dev/null)
COLOUR=$(printf '%s\n' "$COLOURS" | grep -Fix "<colour>")
if [ -z "$SKILL" ]; then echo "The simulator-frame-screenshot folder was not found."
elif [ -z "$UDID" ]; then echo "No simulator is open."
elif [ "$(printf '%s\n' "$BOOTED" | grep -c .)" -gt 1 ]; then printf 'More than one simulator is open. Name one:\n%s\n' "$BOOTED"
elif [ -z "$COLOURS" ]; then DEVTOOLS_BEZELS="$SKILL/Bezels" "$SKILL/frame" --list "$DEVICE"
elif [ -z "$COLOUR" ]; then printf 'Name a colour for %s:\n%s\n' "$DEVICE" "$COLOURS"
else
  rm -f "$SHOT"
  xcrun simctl status_bar "$UDID" override --time "9:41" --dataNetwork wifi --wifiMode active --wifiBars 3 --cellularMode active --cellularBars 4 --operatorName "" --batteryState discharging --batteryLevel 100
  if xcrun simctl io "$UDID" screenshot "$SHOT" >/dev/null 2>&1 && [ -s "$SHOT" ]
  then echo "$DEVICE | $COLOUR | captured"
  else echo "The capture failed, and no file was written."
  fi
fi
```

* **DO** stop when the block prints a failure, and give the user the message; it stops
  before the capture, and the steps after it fail in a way that hides the cause
* **DO NOT** guess the colour, and **DO NOT** carry one over from an earlier run
* **DO** put the colour list, or the names of the open simulators, in front of the user
  with `AskUserQuestion`, one option for each name; text makes the user type the name,
  but the tool gives a choice
* **DO NOT** put `<simulator>` in `grep -Fi` before the user names one; an empty pattern
  keeps every open simulator, and a name that matches none reads as no simulator at all
* **DO NOT** frame the capture without the `captured` line; the path is the same every
  run, and only a capture that worked leaves a file there
* **DO** keep the device and the colour from the last line as text; a shell variable does
  not live past one command block
* **DO** tell the user that the status bar override stays, and that
  `xcrun simctl status_bar booted clear` removes it
* **DO NOT** open, create, or delete a simulator; capture the one the user already has open

## How to name the files

Read the capture, take two strings that the screen shows, find the views that hold both,
then read each one and keep the one that draws the screen:

```bash
basename "$(git rev-parse --show-toplevel)" | tr 'A-Z' 'a-z'
grep -rl --include="*View.swift" "<text one>" . | xargs grep -l "<text two>"
ls **/*View.swift
```

* **DO** read the capture with the Read tool; no simulator command gives the view, and
  `launchctl` reports the same state for a foreground app and a background app
* **DO NOT** use one string alone; a word such as `"Search"` sits in several views, and
  two strings from the one screen cut the list down
* **DO** read the file the grep returns, and compare every string in it against the
  capture; the grep gives a candidate, and only the file itself gives the answer
* **DO NOT** keep a file whose text the capture does not show; `WelcomeView.swift` holds
  `"Welcome to"` and `"Continue"`, so it is the wrong file for a screen without them
* **DO** put the name of each `*View.swift` file beside the capture as well, because the
  name of the screen is often the name of the file; a sign-in screen is `SignInView.swift`
* **DO NOT** match a string that sits inside a longer sentence; `"Sign in with Apple"`
  inside `"Sign in with Apple to keep every entry in your account."` is prose, not a label
* **DO NOT** take a string that a system control draws, such as the label of a
  `SignInWithAppleButton` or a `.searchable` field; the view that shows it does not hold it
* **DO NOT** take a string from the file header; `"Created"` sits in every file
* **DO NOT** take a string that the app stores, such as the title of a list row; the data
  sits in a database, and no view holds it
* **DO** take the view part from the name of the file, in lowercase, so `SignInView.swift`
  gives `signinview`
* **DO** give the user the name you chose, and let the user correct it, when the command
  returns nothing or more than one file; a wrong name is worse than a plain name
* **DO** fall back to the device and the time, in the lowercase and the hyphens the other
  names use, such as `iphone-air-20260820-001203`, outside a git repository, or when the
  screen shows no text to match

## How to frame and save

Put the four values into the first line:

```bash
SKILL=$(ls -d .claude/skills/simulator-frame-screenshot ~/.claude/skills/simulator-frame-screenshot 2>/dev/null | head -1)
DEVICE="<device>"; COLOUR="<colour>"; PROJECT="<project>"; VIEW="<view>"
SHOT="${TMPDIR:-/tmp/}simulator-frame-screenshot.png"
SLUG=$(echo "$COLOUR" | tr 'A-Z ' 'a-z-')
DEVTOOLS_BEZELS="$SKILL/Bezels" "$SKILL/frame" "$SHOT" "$DEVICE" "$COLOUR"
FRAMED="$PROJECT-$VIEW-$SLUG"; N=2
while [ -e ~/Downloads/"$FRAMED".png ]; do FRAMED="$PROJECT-$VIEW-$SLUG-$N"; N=$((N + 1)); done
mv "${SHOT%.png} Framed.png" ~/Downloads/"$FRAMED".png
rm -f "$SHOT"
echo ~/Downloads/"$FRAMED".png
```

## How to frame an image that already exists

```bash
SKILL=$(ls -d .claude/skills/simulator-frame-screenshot ~/.claude/skills/simulator-frame-screenshot 2>/dev/null | head -1)
[ -n "$SKILL" ] && { [ "$SKILL/frame" -nt "$SKILL/frame.swift" ] || swiftc -O "$SKILL/frame.swift" -o "$SKILL/frame"; }
DEVTOOLS_BEZELS="$SKILL/Bezels" "$SKILL/frame" ~/Downloads/shot.png "<device>" "<colour>"
```

* **DO** keep the build line; this task can run without the quick start
* **DO** run it once for each image; it reads one path, takes no flags, and writes beside
  the source with ` Framed.png`

## Reference

`Bezels/` holds four devices. Apple draws more, and a new set each year, at [Apple Design
Resources](https://developer.apple.com/design/resources/#product-bezels). Put another folder
of PNGs inside `Bezels/`, and keep Apple's own file names, such as `iPhone 17 Pro - Silver -
Portrait.png`; the script finds the bezel by name.

Copyright © 2026 Lorenzo Mazzarotto
