# lobotomy-Casino - Codex Guidelines

You are an expert game developer specializing in Godot Engine 4.x and GDScript 2.0.
Write clean, performant, modern Godot 4 code.

## Branching Workflow

Always create a dedicated branch before making changes. Never push directly to `main`
or the current session's base branch.

### Branch Naming

- Bug fixes: `Codex/fix-<short-description>`
- New features: `Codex/feat-<short-description>`
- Tweaks / balance / polish: `Codex/tweak-<short-description>`

### Rules

1. Create the branch at the start of the task. If the task grows, keep adding commits
   to the same branch.
2. Related fixes and tweaks can be batched onto one branch when they address the same
   area.
3. Push the branch and open a PR for review; do not merge to `main`.
4. Start a new branch only once the previous one is merged or explicitly abandoned.

## GitHub Workflow

- Never merge any branch locally or remotely without explicit consent from the owner.
- Never use `git merge` locally to absorb another branch; all merges go through a PR.
- If a branch's changes are already present in another branch due to a local merge,
  flag it clearly instead of silently proceeding.

## Godot Project

- The Godot project lives in `godot/`.
- The game uses a 160x320 virtual canvas.
- Runtime art, fonts, and sounds live under `godot/assets`.
- Exported builds must not depend on root-level assets outside `godot/`.
- Machine geometry constants in `godot/scenes/machine_scene.gd` are measured in
  source pixels. Re-measure them when replacing machine art.

## Verification

Before considering work done, run the checks relevant to the change:

```sh
godot --headless --editor --quit --path godot
godot --headless --path godot -s res://test/run_parity_headless.gd
godot --headless --path godot -s res://test/scene_smoke.gd
```

Run parity when touching rules, scoring, economy, saves, upgrades, dealer logic, or
content data. Run scene smoke checks when touching scenes, UI, controller flow, assets,
or save/runtime integration.

## GDScript Rules

- Use Godot 4 syntax only.
- Use `@export`, `@onready`, `await`, `super()`, and modern property setters/getters.
- Use strict static typing for variables, parameters, and return values.
- Use `:=` only when the type is obvious from the right-hand side.
- Cast nodes fetched from the scene tree.
- Use modern callable signal connections, never string-based connections.
- Prefer exported node references or `%UniqueName` over fragile relative node paths.
- Prefer signals/events over `_process` or `_physics_process` unless polling is needed.
- Use `StringName` for input actions, animation names, and dictionary keys where useful.

## Style

- Follow the official GDScript style guide.
- Use `snake_case` for variables and functions.
- Use `PascalCase` for class names and node names.
- Use `CONSTANT_CASE` for constants.
- Add brief docstrings only for complex functions and classes.
