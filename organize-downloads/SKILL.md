---
name: organize-downloads
description: Sorts the loose files in the Downloads folder into subfolders by topic. Use when asked to organize, sort, or tidy the Downloads folder.
---

# Organize Downloads

## Goal

Move each loose file in `~/Downloads` into a subfolder named after its project or its topic,
so that no file stays loose.

## Quick start

List the loose files and the folders, and make a small copy of each image:

```bash
T="${TMPDIR:-/tmp/}organize-downloads"; rm -rf "$T"; mkdir -p "$T"
cd ~/Downloads
ls -p | grep -v / | grep -v '^\.'
ls -d */ 2>/dev/null
i=0; for f in *; do case "$(echo "$f" | tr 'A-Z' 'a-z')" in *.png|*.jpg|*.jpeg|*.heic) i=$((i+1)); n=$(printf %02d $i); sips -Z 900 -s format jpeg "$f" --out "$T/$n.jpg" >/dev/null 2>&1 && echo "$n = $f";; esac; done
```

* **DO** read every small copy with the Read tool; the name of a screenshot gives only the
  date, and only the image gives the topic
* **DO NOT** read the originals; a full screenshot is many times larger than its copy
* **DO** keep each folder that is already in Downloads, and put new files into it when they
  match its topic

## How to find the topic

Compare each image with the projects, and read the title of each PDF:

```bash
for d in ~/Developer/*/; do echo "== $d"; head -3 "$d/README.md" 2>/dev/null; done
grep -rl "<text on the screen>" ~/Developer/<project> --include="*.swift" | head -3
mdls -name kMDItemTitle ~/Downloads/<file>.pdf
md5 -r ~/Downloads/* 2>/dev/null | sort | awk '$1==p{print} {p=$1}'
```

* **DO** confirm a project with a string from the screen, found in its source; a README can
  hold text copied from another project
* **DO** tell the user about each pair that the last command prints; the two files are the
  same, and the user decides which one stays
* **DO** put a file that belongs to no project into `Other`, and say what it shows

## How to move the files

```bash
cd ~/Downloads
mkdir -p "<Topic>/<Subtopic>"
mv "<file>" "<Topic>/<Subtopic>/"
mv "Screenshot 2026-10-09 at 12.20.27"*.png "<Topic>/"
```

* **DO** match a name that holds `AM` or `PM` with a glob that ends before the time ends;
  macOS puts a narrow no-break space before `AM` and `PM`, so a typed space does not match
* **DO** make a subfolder only when a topic holds more than one kind of file, such as the
  screens of an app and its job posts
* **DO NOT** rename, and **DO NOT** delete, a file; the user looks at each folder later,
  and decides what to keep

## How to verify

```bash
cd ~/Downloads
ls -p | grep -v / | grep -v '^\.'
for d in */ */*/; do [ -d "$d" ] && echo "$(ls "$d" | grep -vc /) $d"; done
rm -rf "${TMPDIR:-/tmp/}organize-downloads"
```

* **DO** move each file that the first command still prints; it prints nothing when the
  task is done
* **DO** give the user the tree of folders, with the number of files in each and one line
  that says what each folder holds

## Reference

| Folder | What goes in |
| --- | --- |
| `<Project>` | Screenshots, photos, and mockups of one project in `~/Developer` |
| `Website` | Screenshots of the personal website |
| `Job Applications` | The CV, and screenshots of job posts |
| `Archives` | `.zip`, `.tar.gz`, and `.dmg` files |
| `Other` | Files that belong to no project |

Copyright © 2026 Lorenzo Mazzarotto
