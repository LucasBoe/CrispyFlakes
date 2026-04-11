# CrispyFlakes

Western-themed tycoon and management sim built in Godot 4.5 with GDScript and the GL Compatibility renderer.

## Project Snapshot

- Internal resolution: `640x360`
- Display resolution: `1280x720`
- Main scene: `scenes/mainscene.tscn`
- Godot version: `4.5`

Core folders:

- `scripts/` gameplay logic, autoloads, NPC AI, UI
- `scenes/` Godot scenes
- `assets/` sprites, shaders, room resources, audio
- `addons/` editor and debugging plugins
- `tools/` repository automation scripts
- `docs/` project documentation

## Opening The Project

1. Open the folder in Godot 4.5.
2. Let Godot import assets and plugins.
3. Run the main scene or press play in the editor.

Enabled editor plugins are configured in [project.godot](/Users/lucasbodeker/CrispyFlakes/project.godot:61).

## Versioning

Version metadata is derived from Git automatically.

- `project.godot` and `export_presets.cfg` are synced by [tools/sync_export_version.sh](/Users/lucasbodeker/CrispyFlakes/tools/sync_export_version.sh:1)
- a local pre-commit hook can update and stage version metadata automatically
- CI verifies that version metadata stays in sync

Install the local hook once per clone:

```sh
bash tools/install_git_hooks.sh
```

Version rules:

- exact tag like `v0.2.0` on `HEAD` becomes `0.2.0`
- commits after a semver tag become `<tag>-dev.<distance>.g<hash>`
- repos without tags fall back to `0.0.0-dev.<commit_count>.g<hash>`

## Exporting

The current repo includes a macOS export preset named `SALOON_TYCOON`.

Typical flow:

1. Commit your changes.
2. Open Godot 4.5.
3. Export using the `SALOON_TYCOON` preset.
4. Find the artifact in `builds/`.

More details are in [docs/exporting.md](/Users/lucasbodeker/CrispyFlakes/docs/exporting.md:1).

## Architecture Notes

- Autoloads in `project.godot` coordinate major game systems like resources, jobs, bounty handling, combat, tutorial flow, and placement.
- Rooms are data-driven through `.tres` definitions in `assets/resources/`.
- NPC behavior is organized into modules and behavior scripts under `scripts/npc/`.
- Signals are the main communication path between systems.

## Repository Hygiene

- local build output is ignored in Git via `builds/`
- local editor settings such as `.vscode/` are ignored
- formatting rules live in [.editorconfig](/Users/lucasbodeker/CrispyFlakes/.editorconfig:1)
- version sync is enforced in CI by [.github/workflows/version-sync.yml](/Users/lucasbodeker/CrispyFlakes/.github/workflows/version-sync.yml:1)
