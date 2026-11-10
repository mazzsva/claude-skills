# Claude Skills

Versioned [Claude Code](https://claude.com/claude-code) skills, symlinked into `~/.claude`

## Developer tools

<table>
  <tr><td><a href="specify">specify</a></td><td>Finds the open decisions of a feature and writes a spec.</td></tr>
  <tr><td><a href="prove">prove</a></td><td>Checks a finished change against its spec in a fresh context.</td></tr>
  <tr><td><a href="propose">propose</a></td><td>Proposes changes as logical commits and pull requests.</td></tr>
  <tr><td><a href="rebase">rebase</a></td><td>Rebases a branch and resolves every conflict.</td></tr>
</table>

## Utility tools

<table>
  <tr><td><a href="organize-downloads-folder">organize-downloads-folder</a></td><td>Sorts the Downloads folder into subfolders by topic.</td></tr>
</table>

## Installation steps

You need Claude Code. Then link the skills into `~/.claude/skills`:

```
git clone https://github.com/mazzsva/claude-skills.git
cd claude-skills
./link.sh
```

Run `link.sh` again after you add a skill. It never deletes anything.

Copyright © 2026 Lorenzo Mazzarotto
