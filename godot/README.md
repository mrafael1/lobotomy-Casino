# lobotomy-Casino - Godot 4

Godot 4 / GDScript version of the slot machine game, targeting portrait Android first.
The Expo / React Native prototype has been removed; `godot/` is now the runtime
project and `godot/assets` is the shipped asset tree.

## Layout

```text
godot/
  project.godot            # autoloads, portrait, 160x320 virtual canvas
  rules/                   # pure rules/content
  autoload/                # run/meta state singletons and shared asset cache
  scenes/                  # menu, shop, machine, dealer, scores, settings
  assets/                  # exported runtime art, fonts, and sounds
  test/                    # parity, sacred-rule, save, and scene smoke checks
```

The game uses a 160x320 virtual canvas. Runtime PNGs in `assets/images` are authored
at fixed integer scale, and scene overlays/tap targets are positioned in source-pixel
coordinates measured from the art.

## Verification

From the repository root:

```sh
godot --headless --editor --quit --path godot
godot --headless --path godot -s res://test/run_parity_headless.gd
godot --headless --path godot -s res://test/scene_smoke.gd
```

`run_parity_headless.gd` checks the GDScript rules against the frozen golden vectors
under `../parity/vectors`. `scene_smoke.gd` exercises the main scenes/controllers.

## Running

Open this folder in Godot and press Play, or run:

```sh
godot --path godot
```

The default scene is the start menu. The loop is:

```text
menu -> shop/upgrades -> machine run -> dealer visits -> ending/bank -> menu
```

## Assets

Godot loads textures, fonts, and sounds from `res://assets`. Exported builds must not
depend on files outside the Godot project directory. If art is replaced, re-measure the
machine geometry constants in `scenes/machine_scene.gd` and rerun the headless checks.
