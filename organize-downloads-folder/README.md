# organize-downloads-folder

A file name says little. `Document.pdf` can be a contract or a manual, so a sort by name or by
file type puts it in the wrong place.

This skill reads the content of each item in the Downloads folder, and moves it into a folder
for its topic. It only moves items, so no file is lost or changed.

## How it works

* **It sorts by content, not by name.** One command gets the text of each PDF, Word, RTF, and
  HTML file, and the file list of each archive, through the Spotlight importers of macOS. No
  app opens.
* **It sorts by topic, not by file type.** The items of one task stay together.
* **It marks its own folders.** Each topic folder gets an extended attribute. A folder with no
  mark is yours: the skill moves it whole, and never puts an item into it or takes one out.
  Run the skill again, and it sorts only the new items.
* **It waits for a download that is not complete.** It skips each partial file, and each file
  whose size changes during five seconds.
* **It never replaces a file.** When a topic folder already holds an item of the same name, it
  makes a subfolder that says how the two differ.
* **It reports duplicates, and deletes none.** It compares the MD5 of each file, and you
  decide which one stays.
* **It keeps secrets closed.** It reads only the first line of a key or a credential file, and
  never shows the content.
* **It handles two traps of macOS.** macOS puts a narrow no-break space before `AM` and `PM`
  in a file name, so a typed space does not match, and the skill copies each name from the
  output of a command. `mkdir -p` hides a name that is already in use, so the skill does not
  use it.

## Safety

It has no step that deletes, renames, or replaces an item in Downloads. It does not open,
mount, run, or install an app, a disk image, a package, or a script.

## Requirements

macOS.

Copyright © 2026 Lorenzo Mazzarotto
