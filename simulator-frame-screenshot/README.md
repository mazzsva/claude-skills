# simulator-frame-screenshot

A screenshot of the simulator is a rectangle. A screenshot in a bezel is a
product shot.

This takes the first, and gives back the second. It frames an image that already
exists just as well. Before every capture the status bar is set to 9:41, full
bars, full battery, the way Apple shoots it.

## Bezels

Four devices ship with the skill, in every stock colour, portrait and landscape.

iPhone 17. iPhone 17 Pro. iPhone 17 Pro Max. iPhone Air.

Apple draws a new set each year, at [Apple Design
Resources](https://developer.apple.com/design/resources/#product-bezels). A
folder of those PNGs inside `Bezels/`, under Apple's own file names, adds one.

## Safety

It uses the simulator that is already open, and never opens, creates, or deletes
one. With two of them open, it asks which.

Every shot is named `<project>-<view>-<colour>.png`, from the project it is in
and the view on the screen. A name already taken gets a number, so nothing is
overwritten.

The finished shot goes to `~/Downloads`. The raw capture is temporary, and it is
deleted as soon as the shot is framed.

A capture that fails leaves no file behind, so an old shot never goes out as a
new one. The status bar override stays after the shot, and `xcrun simctl
status_bar booted clear` puts it back.

## Requirements

macOS, and Xcode. A simulator already open, because it never opens one. Git names
the project part of the file, and the device and the time stand in without it.

`frame.swift` compiles itself on first use, and again whenever it changes.

Copyright © 2026 Lorenzo Mazzarotto
