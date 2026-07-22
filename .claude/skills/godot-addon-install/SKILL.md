---
name: godot-addon-install
description: >-
  Install a Godot addon/plugin (Dialogic, Phantom Camera, GUT, etc.) into this
  project from GitHub as plain text, the reproducible way — no editor AssetLib
  GUI. Use this WHENEVER the task involves adding, installing, updating, pinning,
  or enabling a Godot addon/plugin/asset, or when someone says "add <addon> to
  the project", even if they don't say the word "install". Covers the Windows
  long-path extraction failure, the PowerShell sandbox `/E` gotcha, picking a
  Godot-compatible release, and enabling the plugin via project.godot.
---

# Installing a Godot addon as plain text (Windows)

This project's CLAUDE.md forbids editor-only GUI steps and binary-only workflows:
addons must go in as plain-text files you can reproduce and verify. This skill is
that reproducible path. It also encodes the two failures that cost real time the
first time through (long-path extraction, and a sandbox misread of robocopy `/E`).

## Environment assumptions
- Godot is a **portable** install, not on PATH. Reference the full exe path, e.g.
  `C:\Users\TravisJones\Downloads\Godot_v4.6.3-stable_win64\Godot_v4.6.3-stable_win64_console.exe`
  (use the `_console.exe` variant so `--version`/stdout print).
- Project root: `C:\Users\TravisJones\3d-cinematic-game`.
- Shell is Windows PowerShell 5.1 (see the gotchas below — its `Expand-Archive` and
  the tool sandbox both bite here).

## Step 1 — Pick a release that matches the engine version

Addons cap at specific Godot versions; picking blind is how you install something
that won't load. Query the GitHub API (handles prereleases, which `/releases/latest`
hides — Dialogic ships only alpha prereleases):

```powershell
Invoke-RestMethod -Uri "https://api.github.com/repos/<owner>/<repo>/releases?per_page=6" -Headers @{ "User-Agent"="claude" } |
  Select-Object -First 6 | ForEach-Object { "tag=$($_.tag_name)  prerelease=$($_.prerelease)  name=$($_.name)" }
```

Confirm the chosen release supports this project's Godot version before downloading.
If unsure, read the addon's release notes / plugin.cfg for a stated max version.
(Real example: Dialogic 2.0-alpha-19 maxes at Godot 4.6.x — it does NOT support 4.7.)

## Step 2 — Download the source tag zip

```powershell
$ProgressPreference='SilentlyContinue'; [Net.ServicePointManager]::SecurityProtocol=[Net.SecurityProtocolType]::Tls12
Invoke-WebRequest -Uri "https://github.com/<owner>/<repo>/archive/refs/tags/<tag>.zip" -OutFile "<scratchpad>\addon.zip" -UseBasicParsing
```

## Step 3 — Extract with `tar`, NOT `Expand-Archive`  ⚠️ long-path trap

PowerShell 5.1's `Expand-Archive -Force` throws `Remove-Item ... because it does not
exist` on deeply nested addon files — the paths exceed Windows' 260-char limit during
its cleanup pass. Use `tar` (bsdtar, ships with Win10+; long-path aware) into a SHORT
directory so the intermediate path stays well under 260 chars:

```powershell
$g = "C:\Users\TravisJones\gaddons"   # short root on purpose
New-Item -ItemType Directory -Force -Path "$g\x" | Out-Null
tar -xf "<scratchpad>\addon.zip" -C "$g\x"
# the addon lives at $g\x\<repo>-<tag>\addons\<addon_name>
```

## Step 4 — Copy into the project with `robocopy`  ⚠️ sandbox `/E` trap

`robocopy` (not `Copy-Item`) handles >260-char destination paths. But keep it in its
**own command** — do NOT combine it with `Remove-Item` in the same script. The tool
sandbox reads robocopy's `/E` flag as a filesystem path and blocks the call with
"Remove-Item on system path '/E' is blocked" when a deletion appears alongside it.

```powershell
robocopy "$g\x\<repo>-<tag>\addons\<addon_name>" "C:\Users\TravisJones\3d-cinematic-game\addons\<addon_name>" /E /NFL /NDL /NP /NJH /NJS
# robocopy exit codes 0-7 mean SUCCESS. Do not treat exit 1 as failure —
# verify by checking the file landed instead:
Test-Path "C:\Users\TravisJones\3d-cinematic-game\addons\<addon_name>\plugin.cfg"
```

## Step 5 — Find what the plugin registers, then enable it in project.godot

Most addons register an **autoload singleton** in their `plugin.gd`. Enabling the plugin
by hand in `project.godot` (plain text) reproduces exactly what the editor's "enable
plugin" checkbox does. Find the singleton name + path first:

```
Grep for: add_autoload_singleton   (in addons/<addon_name>/plugin.gd)
```

Then add to `project.godot`:
- Under `[autoload]`, one line per singleton, `*` prefix = enabled:
  `SingletonName="*res://addons/<addon_name>/<path-from-plugin.gd>"`
- Under `[editor_plugins]`, append the plugin.cfg to the array:
  `enabled=PackedStringArray("...existing...", "res://addons/<addon_name>/plugin.cfg")`

Keep the project's own game autoloads first in the list and addon autoloads after, so
game singletons load before anything that might reference them.

## Step 6 — Import to register everything AND to test compatibility

Running Godot's import is the real compatibility check — it parses every addon script
on the target engine and surfaces parse errors:

```powershell
& $godot --headless --path "C:\Users\TravisJones\3d-cinematic-game" --import *> "<scratchpad>\import.log"
"exit: $LASTEXITCODE"
Select-String -Path "<scratchpad>\import.log" -Pattern "SCRIPT ERROR|Parse Error|ERROR:|Failed" | Select-Object -ExpandProperty Line
```

**Success = exit 0 and zero error lines.**

### Expected: Godot rewrites project.godot on import/open — don't fight it
After import/first open, Godot will reformat the file: it converts autoload script
paths to `uid://...` form, tidies the header comment, and adds addon-owned setting
sections (e.g. a `[dialogic]` block). This is normal and means the plugin enabled
correctly. Re-read the file from disk before your next edit (the editor's copy wins).

## Final verification
Re-run the project's GUT suite (see the `godot-gut-headless-testing` skill) to confirm
the new addon's autoloads didn't disturb existing autoload load order or tests.
