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

Version metadata uses the Godot project version as the base and Git commit count as the dev suffix.

- `project.godot` and `export_presets.cfg` are synced by [tools/sync_export_version.sh](/Users/lucasbodeker/CrispyFlakes/tools/sync_export_version.sh:1)
- a local pre-commit hook can update and stage version metadata automatically
- CI verifies that version metadata stays in sync

Install the local hook once per clone:

```sh
bash tools/install_git_hooks.sh
```

Version rules:

- set `Project Settings > Application > Config > Version` to a base semver like `0.0.1`
- the sync script keeps that `0.0.1` prefix
- the sync script rewrites any suffix to `-dev.<commit_count>`

For example, `0.0.1`, `0.0.1-dev.12`, and `0.0.1-preview` all sync to `0.0.1-dev.<count>`.

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
