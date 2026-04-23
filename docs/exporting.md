# Exporting Builds

This project currently ships with a macOS export preset in [export_presets.cfg](/Users/lucasbodeker/CrispyFlakes/export_presets.cfg).

## Automatic Versioning

Version metadata uses the leading semver from Godot's project version and appends a Git-based dev build number.

`tools/sync_export_version.sh` updates both:

- `config/version` in `project.godot`
- `application/short_version`
- `application/version`
- the macOS `export_path` in `export_presets.cfg`

The version rules are:

- set `Project Settings > Application > Config > Version` to a base semver like `0.0.1`
- `tools/sync_export_version.sh` keeps that `0.0.1` prefix
- the script replaces anything after that prefix with `-dev.<commit_count>`

Examples:

- `0.0.1` -> `0.0.1-dev.<count>`
- `0.0.1-dev.12` -> `0.0.1-dev.<count>`
- `0.0.1-preview` -> `0.0.1-dev.<count>`

## Automatic Sync On Commit

Install the local Git hook once:

```sh
bash tools/install_git_hooks.sh
```

After that, every commit will automatically:

1. read the base semver from `project.godot`
2. sync `project.godot`
3. sync `export_presets.cfg`
4. stage those version changes into the commit

If you need a one-off manual fix without the hook, run:

```sh
bash tools/sync_export_version.sh sync-next
```

## CI Enforcement

The repository also includes a GitHub Actions check at [.github/workflows/version-sync.yml](/Users/lucasbodeker/CrispyFlakes/.github/workflows/version-sync.yml:1).

It runs:

```sh
bash tools/sync_export_version.sh check
```

That means even if a clone does not have the local hook installed yet, pull requests and pushes to the main branch will fail when version metadata is out of sync.

## Local Export Flow

1. Commit your changes.
2. Open Godot 4.5 and export with the `SALOON_TYCOON` preset.
3. The build artifact will be written to `builds/CrispyFlakes_<version>.dmg`.

## Notes

- `builds/` is ignored in Git, so local export artifacts do not pollute the working tree.
- To bump the main version, change `Project Settings > Application > Config > Version` to a new semver like `0.0.2` and let the sync script rebuild the `-dev.<count>` suffix.
