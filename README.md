# Claude Skills

Versioned [Claude Code](https://claude.com/claude-code) skills, symlinked into `~/.claude`

## Developer Tools

<table>
  <tr><td><a href="git-rebase-and-resolve-conflicts">git-rebase-and-resolve-conflicts</a></td><td>Rebases a branch and resolves every conflict.</td></tr>
  <tr><td><a href="simulator-frame-screenshot">simulator-frame-screenshot</a></td><td>Puts the simulator screen inside a real Apple bezel.</td></tr>
</table>

## Utilities

<table>
  <tr><td><a href="organize-downloads-folder">organize-downloads-folder</a></td><td>Sorts the Downloads folder into subfolders by topic.</td></tr>
</table>

## Install

You need Claude Code. Then link the skills into `~/.claude/skills`:

```
git clone https://github.com/mazzsva/claude-skills.git
cd claude-skills
./link.sh
```

Run `link.sh` again after you add a skill. It never deletes anything.

Copyright © 2026 Lorenzo Mazzarotto
