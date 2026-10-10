# organize-downloads-folder

Downloads fills up with screenshots named after the time they were taken.
The name says when. It never says what.

This one looks at every image, and finds the project it belongs to. Then it
moves each file into a folder named after that project, so nothing stays loose.

## How it decides

It reads a small copy of each image, not the file itself, so a folder of large
screenshots stays cheap.

A README can be wrong. A project can carry text copied from another one. So a
screen gets matched to a project by a string it shows, found in that project's
source.

A PDF gets its title from its own metadata.

## Safety

It moves files. It never renames them, and it never deletes them. The date stays
in each name, and every decision about what to keep stays with you.

Two files with the same content get reported, not removed.

## Requirements

macOS, for `sips`, `mdls`, and `md5`. Projects in `~/Developer`, each with a
README.

Copyright © 2026 Lorenzo Mazzarotto
