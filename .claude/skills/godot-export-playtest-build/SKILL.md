---
name: godot-export-playtest-build
description: >-
  Produce and hand out a playable build of this Godot project — export templates, a hand-authored
  export_presets.cfg, the headless export command, verifying the exported binary actually boots, and
  the warnings non-technical playtesters must be told or they will never reach the game. Use this
  WHENEVER the task involves exporting, packaging, building, shipping, distributing, or "sending
  someone something they can play", a web/browser build, an .exe, itch.io, or a playtest build. Front
  loads the decision that matters most here: a web build silently loses volumetric fog because web
  forces the Compatibility renderer, which would delete this project's entire atmosphere pass.
---

# Building something playtesters can run

## ⚠️ Decide the target first: web would delete the atmosphere

This project is **Forward Plus** (`project.godot` → `config/features=PackedStringArray("4.6", "Forward Plus")`).

Godot 4 **web exports only run on the Compatibility renderer**, and Compatibility **does not support
volumetric fog**. `volumetric_fog_enabled` is the backbone of the whole atmosphere pass — the shore's
mist ("endless water swallowed by mist"), the village's golden depth-haze, the tower's stairwell
haze. A browser build drops all three silently, with no error, and playtesters would be judging a
flat-looking game. That loses pillar #2 (Visuals/Atmosphere).

**Decision (2026-07-27): ship a Windows desktop build.** Revisit only if download friction ever
matters more than mood — and if it does, expect to re-tune the atmosphere for Compatibility rather
than assume it ports.

**The consequence to carry forward:** Forward+ requires working **Vulkan** drivers. A tester on an old
GPU may not launch at all. Their fallback is `--rendering-driver opengl3`, which works but drops to
Compatibility — so **any visual feedback from that run is invalid.** Ask testers to say if they used
it.

## One-time: install export templates

Export needs the template package matching the engine **exactly** (`4.6.3.stable`). It is **not**
bundled with the portable engine, and it is **~1.2 GB**.

```powershell
$ver  = "4.6-3-stable" -replace '-','.'   # actual tag form: 4.6.3-stable
$url  = "https://github.com/godotengine/godot/releases/download/4.6.3-stable/Godot_v4.6.3-stable_export_templates.tpz"
$tpz  = "$env:TEMP\templates.tpz"
$dest = "$env:APPDATA\Godot\export_templates\4.6.3.stable"

curl.exe -L --fail -o $tpz $url            # use curl, not Invoke-WebRequest, for a file this size
Copy-Item $tpz "$env:TEMP\templates.zip"   # .tpz IS a zip; Expand-Archive needs the extension
Expand-Archive "$env:TEMP\templates.zip" "$env:TEMP\tpz_extract" -Force
New-Item -ItemType Directory -Force $dest | Out-Null
Copy-Item "$env:TEMP\tpz_extract\templates\*" $dest -Recurse -Force
```

The archive contains a single `templates/` folder — its **contents** go directly in `$dest`, not the
folder itself. Verify before proceeding:

- `$dest\version.txt` must read exactly `4.6.3.stable`
- `$dest\windows_release_x86_64.exe` must exist (~100 MB)

A HEAD request first is cheap insurance against a 1.2 GB 404:
`Invoke-WebRequest -Uri $url -Method Head -UseBasicParsing`.

## export_presets.cfg is plain text — author it, and commit it

CLAUDE.md forbids editor-only steps, and this file is plain text with no secrets, so **hand-write it
and keep it in git**. It was originally in `.gitignore`; it was removed from there so builds are
reproducible. `build/` is gitignored instead.

Key options, and why:

| Option | Value | Why |
|---|---|---|
| `binary_format/embed_pck` | `true` | One self-contained `.exe`. No loose `.pck` to forget when sending. |
| `binary_format/architecture` | `"x86_64"` | Matches the template you installed. |
| `debug/export_console_wrapper` | `0` | No console window popping up for testers. |
| `exclude_filter` | `"tests/*, docs/*, *.md, addons/gut/*"` | GUT and the suite are dev-only — **editor plugins do not load in an exported game**, so excluding the addon is safe and shrinks the build. Internal docs shouldn't ship to testers. |
| `script_export_mode` | `2` | Compressed binary tokens (release default). |

## Build

```powershell
$GODOT = "C:\Users\TravisJones\Downloads\Godot_v4.6.3-stable_win64\Godot_v4.6.3-stable_win64_console.exe"
& $GODOT --headless --path . --export-release "Windows Desktop" build/vertical-slice.exe
```

Expect ~113 MB (≈100 MB template + ~13 MB embedded game data). The export log is long — 100+
`Storing File:` lines — and includes the **benign** Dialogic editor-sidebar error
(`sidebar.gd:507`, `current_resource` on Nil) plus the usual headless shutdown noise. Neither
indicates a bad build.

Swap `--export-debug` for a build that reports errors, when you need to reproduce something a tester
described.

## Verify the binary actually boots — do not ship on "the export exited 0"

The exported game accepts engine CLI flags, so smoke-test it the same way zones are tested:

```powershell
& ".\build\vertical-slice.exe" --headless --quit-after 240
```

Exit 0 with only the familiar shutdown noise (`ObjectDB instances leaked`, `26 resources still in
use`) proves a lot: the pack embedded correctly, all seven autoloads initialised, and
`main.tscn` → `SceneDirector` → the opening zone loaded and ran 240 frames.

**Most valuable signal: no `Cannot open file res://…` errors.** That is what tells you
`exclude_filter` didn't strip something the game needs — the real risk when excluding addons.

**What this does NOT prove:** anything visual. Headless cannot tell you the fog renders. Run the
`.exe` yourself on a real GPU once before sending it out.

## Package and hand it over

```powershell
Compress-Archive -Path "build\vertical-slice.exe" -DestinationPath "build\vertical-slice-playtest.zip" -CompressionLevel Optimal
```

113 MB compresses to ~39 MB. **Send the zip, not the loose `.exe`** — most browsers and mail clients
silently block bare executables.

Channels: **itch.io** password-protected draft page (link, download counts, updates without
re-sending) or a zip via Drive/WeTransfer. **GitHub Releases needs a working remote** — as of
2026-07-27 `git ls-remote origin` reports `Repository not found`, so that route is unavailable until
the remote is fixed.

## What testers must be told, or they will bounce

The build is **unsigned** (signing needs a paid certificate — not worth it for a friend playtest), so
Windows actively discourages running it. This is the single biggest drop-off point, ahead of anything
in the game:

1. **"Windows protected your PC"** → **More info** → **Run anyway**.
2. **Antivirus may quarantine it.** Routine for unsigned Godot exports.
3. **Extract the zip before running.** Launching from inside the zip can fail or behave oddly.
4. **Vulkan** — if it won't launch at all, see the fallback above, and note that it invalidates
   visual feedback.

Also worth telling them, because it reads as a bug: the **mouse cursor disappears** during play
(captured for camera control) and returns by itself in conversations and on `Esc`.

A ready-made, non-technical-friendly version of all this lives in **`docs/PLAYTESTER_GUIDE.md`**, with
the full build recipe in **`docs/BUILD.md`**. Update those rather than re-deriving.

## Collecting results

Tester saves land in `%APPDATA%\Godot\app_userdata\3d-cinematic-game\` — ask for that folder to see
where someone stalled.

The Milestone 1 success criterion is not a bug count: a friend plays ~10 minutes, asks an
**unprompted question about the world**, and wants to know what happens next. Ask for world questions
verbatim and rank them above bug reports, or you will get a tidy defect list and learn nothing about
whether the story landed.
