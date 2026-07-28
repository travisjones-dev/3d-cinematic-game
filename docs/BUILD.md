# Building a playtest build

How to produce the Windows build you send to playtesters. Everything here is plain text and
reproducible from the command line — no editor GUI steps (CLAUDE.md hard rule).

## Why Windows and not web

The project is **Forward Plus** (`project.godot` → `config/features=…"Forward Plus"`). Godot 4 web
exports only run on the **Compatibility** renderer, which **does not support volumetric fog**.
`volumetric_fog_enabled` is the backbone of the whole atmosphere pass — the shore's mist, the
village's golden depth-haze, the tower's stairwell haze. A web build silently drops all three and
makes the game look flat, which loses pillar #2 (Visuals/Atmosphere). Decision 2026-07-27: ship a
Windows desktop build.

**Consequence to remember:** Forward+ requires working **Vulkan** drivers. A playtester on an old
GPU may fail to launch. Their fallback is `vertical-slice.exe --rendering-driver opengl3`, but that
drops to Compatibility and loses the fog, so their visual feedback is no longer valid — note it if
they report a flat-looking game.

## One-time setup: export templates

Export needs the template package matching the engine **exactly** (`4.6.3.stable`). It is not
installed with the portable engine.

```powershell
$ver  = "4.6.3-stable"
$url  = "https://github.com/godotengine/godot/releases/download/$ver/Godot_v${ver}_export_templates.tpz"
$tpz  = "$env:TEMP\templates.tpz"
$dest = "$env:APPDATA\Godot\export_templates\4.6.3.stable"

curl.exe -L --fail -o $tpz $url          # ~1.2 GB
New-Item -ItemType Directory -Force $dest | Out-Null
Expand-Archive -Path $tpz -DestinationPath "$env:TEMP\tpz_extract" -Force
# The .tpz is a zip containing a single `templates/` folder; its CONTENTS go directly in $dest.
Copy-Item "$env:TEMP\tpz_extract\templates\*" $dest -Recurse -Force
```

Verify — `$dest` must contain `windows_release_x86_64.exe` and `windows_debug_x86_64.exe`.

`.tpz` is a plain zip despite the extension, so `Expand-Archive` handles it.

## Building

```powershell
$GODOT = "C:\Users\TravisJones\Downloads\Godot_v4.6.3-stable_win64\Godot_v4.6.3-stable_win64_console.exe"

& $GODOT --headless --path . --import                                              # once, if needed
& $GODOT --headless --path . --export-release "Windows Desktop" build/vertical-slice.exe
```

Output is a **single self-contained `.exe`** (`binary_format/embed_pck=true`), so there is no
loose `.pck` to send alongside. `build/` is gitignored; `export_presets.cfg` is **not** — it is
plain text with no secrets and is committed so builds are reproducible.

### What the preset deliberately excludes
`exclude_filter="tests/*, docs/*, *.md, addons/gut/*"` — the GUT addon and the test suite are
dev-only (editor plugins do not load in an exported game), and internal docs should not ship to
playtesters. This also keeps the build smaller.

### Debug build for diagnosing reports
A release build hides errors. To reproduce something a playtester reports:

```powershell
& $GODOT --headless --path . --export-debug "Windows Desktop" build/vertical-slice-debug.exe
```

## Tell playtesters this, or they will not get past the first screen

The build is **unsigned** (no code-signing certificate), so Windows will actively discourage running
it. This is expected, not a broken build:

- **SmartScreen:** "Windows protected your PC" → **More info** → **Run anyway**.
- **Browser/email blocking:** many clients refuse a bare `.exe` download. Send the **zip**
  (`build/vertical-slice-playtest.zip`) rather than the loose exe.
- **Antivirus false positives** are common for unsigned Godot exports. If a tester's AV quarantines
  it, that is not evidence of a real problem.
- **Vulkan:** Forward+ needs working Vulkan drivers. If it refuses to launch at all, the fallback is
  `vertical-slice.exe --rendering-driver opengl3` — but that drops to Compatibility and loses the
  volumetric fog, so treat any "looks flat" feedback from that run as invalid.

Signing properly needs a paid certificate; not worth it for a friend playtest, but it is the reason
for every warning above.

## Sending it

- **itch.io**, password-protected draft page — the usual playtest channel; gives testers a link,
  you get download counts, and you can push updates without re-sending files.
- **Zip via Drive/WeTransfer** — zero setup, fine for a handful of testers.
- **GitHub Releases** — *not currently available*: `git ls-remote origin` reports
  `Repository not found` for `travisjones-dev/3d-cinematic-game`, so that remote is either
  private-unauthenticated or gone. Fix the remote first if you want this route.

## Collecting feedback

Playtester saves land in `%APPDATA%\Godot\app_userdata\3d-cinematic-game\` — ask for that folder if
you need to inspect where someone got stuck. The Phase E success criterion is a friend playing ~10
minutes, asking an **unprompted question about the world**, and wanting to know what happens next,
so log world questions verbatim, not just bugs.
