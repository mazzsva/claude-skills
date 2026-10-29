---
name: organize-downloads-folder
description: Sorts the loose files and folders in the Downloads folder into subfolders by topic. Use when asked to organize, sort, or tidy the Downloads folder.
---

# Organize Downloads Folder

## Goal

Move each item in `~/Downloads` into a topic folder that this skill made, so that only
topic folders stay at the top, and no item is lost or changed.

## Quick start

List each item at the top of the folder, and mark the topic folders that this skill made:

```bash
cd ~/Downloads
for f in *; do if xattr -p organize-downloads-folder "./$f" >/dev/null 2>&1; then echo "TOPIC | $f"; else echo "$(file -b "./$f" | cut -d, -f1) | $f"; fi; done
```

* **DO** sort each item that is not marked `TOPIC`: each file, each link, each app, and
  each folder
* **DO NOT** move a hidden file, or a download that is not complete, such as `.crdownload`,
  `.download`, or `.part`; the browser can still be writing it
* **DO NOT** delete, rename, or change an item, and **DO NOT** run `rm` in Downloads; the
  user cannot get back an item that this skill loses

## How to look inside an item

Find the topic from the content, not the name:

```bash
T="${TMPDIR:-/tmp/}organize-downloads-folder"; mkdir -p "$T"
for f in *; do case "$f" in *.p8|*.p12|*.pem|*.key) continue;; esac; [ -f "$f" ] && { echo "== $f"; mdimport -t -d3 "./$f" 2>&1 | sed -n 's/.*kMDItemTextContent = //p' | head -c 300; echo; }; done
find "./<folder>" -not -name '.*' | head -30
sips -Z 900 -s format jpeg "./<image>" --out "$T/<n>.jpg"
head -c 2000 "./<text file>"
mdls -raw -name kMDItemWhereFroms "./<item>"
```

* **DO** get the text of every document with the `mdimport` loop, in one command; it reads
  PDF, Word, RTF, HTML, and plain text, and the file list of an archive
* **DO** find the topic of a folder from the names of its items, and read an item inside it
  only when the names do not give the topic
* **DO** read each image with the Read tool, through its small copy
* **DO** read a file that the loop gives no text for with `head`, or with the Read tool
  through a copy that ends in the correct extension
* **DO** read only the first line of a key or a credential file, such as `.p8`, `.pem`, or
  `.key`, and **DO NOT** show its content to the user
* **DO NOT** open, mount, run, or install an app, a disk image, a package, or a script
* **DO** copy each name from the output of a command, or match it with a glob; macOS puts
  a narrow no-break space before `AM` and `PM`, so a typed space does not match

## How to move the items

Make each topic folder with `mkdir`, and mark it; then move each item into it whole:

```bash
cd ~/Downloads
Z="${TMPDIR:-/tmp/}organize-downloads-folder/sizes"; stat -f '%z %N' -- * > "$Z"; sleep 5; stat -f '%z %N' -- * | diff "$Z" -
mkdir "<Topic>" && xattr -w organize-downloads-folder 1 "<Topic>"
ls "<Topic>/<name>" 2>/dev/null
mv -n -- "<item>" "<Topic>/"
```

* **DO NOT** move a file that the `diff` prints; it still grows, so something still writes
  it; run the `diff` again later, and move it when it prints nothing
* **DO** move a folder whole, with its items inside it; a folder that is not marked belongs
  to the user, so **DO NOT** move an item out of it, or put an item into it
* **DO** put items only into a folder marked `TOPIC`, or into a subfolder of one that you
  make and mark the same way
* **DO NOT** add `-p` to `mkdir`; it fails when any item has that name, in any case, and
  `-p` hides that failure; choose another name for the topic when it fails
* **DO** name each folder after a topic, not after a file type, so that the items of one
  task stay together
* **DO** put an item that has no topic into `Other`, and say what it holds
* **DO** check for an item of the same name in the folder before each move; when one is
  there, move the item into a subfolder that says how it differs, such as `Travel/Lisbon`

## How to verify

```bash
cd ~/Downloads
for f in *; do xattr -p organize-downloads-folder "./$f" >/dev/null 2>&1 || echo "$f"; done | grep -v -e '\.crdownload$' -e '\.download$' -e '\.part$'
find . -type f -size +0 -not -name '.*' -not -path '*.app/*' -exec md5 -r {} + | sort | awk '$1==p{if(!s)print q; print; s=1; next} {p=$1; q=$0; s=0}'
find . -mindepth 1 -maxdepth 2 -type d -not -path '*.app/*' | sort
rm -rf "${TMPDIR:-/tmp/}organize-downloads-folder"
```

* **DO** sort each item that the first command prints, then run it again; the user can add
  an item while this skill runs, and it prints nothing only when the task is done
* **DO** tell the user about each pair that the second command prints; the two files are
  the same, and the user decides which one stays
* **DO** give the user the tree of folders, with the number of items in each and one line
  that says what each folder holds

Copyright © 2026 Lorenzo Mazzarotto
