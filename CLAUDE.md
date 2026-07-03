# lobotomy-Casino - Claude Guidelines

This repository is now Godot-only. Follow the same engineering and verification
rules as `AGENTS.md`.

## Project

- Godot project: `godot/`
- Runtime assets: `godot/assets`
- Golden parity vectors: `parity/vectors`
- Main verification scripts:
  - `res://test/run_parity_headless.gd`
  - `res://test/scene_smoke.gd`

## Required Checks

```sh
godot --headless --editor --quit --path godot
godot --headless --path godot -s res://test/run_parity_headless.gd
godot --headless --path godot -s res://test/scene_smoke.gd
```

Use modern Godot 4 / GDScript 2.0 syntax and keep branches/PRs isolated.
