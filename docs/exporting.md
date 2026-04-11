# Exporting Builds

This project currently ships with a macOS export preset in [export_presets.cfg](/Users/lucasbodeker/CrispyFlakes/export_presets.cfg).

## Automatic Versioning

Version metadata is derived from Git, not edited by hand.

`tools/sync_export_version.sh` updates both:

- `config/version` in `project.godot`
- `application/short_version`
- `application/version`
- the macOS `export_path` in `export_presets.cfg`

The version rules are:

- exact tag like `v0.2.0` on `HEAD` -> `0.2.0`
- commits after a semver tag -> `<tag>-dev.<distance>.g<hash>`
- no semver tags yet -> `0.0.0-dev.<commit_count>.g<hash>`

## Automatic Sync On Commit

Install the local Git hook once:

```sh
bash tools/install_git_hooks.sh
```

After that, every commit will automatically:

1. derive the current version from Git
2. sync `project.godot`
3. sync `export_presets.cfg`
4. stage those version changes into the commit

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
- When you start tagging releases, use semver tags like `v0.1.0` to get clean release versions automatically.
