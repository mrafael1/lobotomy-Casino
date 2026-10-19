# Production tools and discovery

Checked 19 October 2026. Discovery did not install or connect anything.

| Capability | Evidence | Decision |
|---|---|---|
| Python + Pillow | Python runs locally; Pillow 12.3.0 is installed. Existing `tools/pixel_art` already uses integer drawing recipes. | Selected. New independent recipes in `tools/house_identity` author contours, material planes, symbols, character and illustrations. No existing generator or image is overwritten. |
| Existing pixel pipeline | `tools/generate_pixel_art.py`, `tools/verify_pixel_art.py`, `tools/pixel_art/core.py`, `docs/pixel-art/README.md` inspected. | Retain for the live game. Its current asset contracts encode the previous geometry; phase one must not overwrite these with new compositions. |
| Godot GDScript patterns skill | Read `.agents/skills/godot-gdscript-patterns/SKILL.md`. | Selected for integration planning: signals, typed presentation objects, independent animation layers. No functional GDScript change in phase one. |
| Plugin Management skill | Read its installed `SKILL.md`; queried the trusted plugin directory for UltraCode, Ultra Code, Aseprite and pixel art. | Selected for discovery. Results included Figma, MagicPath and coding aids; none verified a pixel-art atlas capability or an installed UltraCode. No addition recommended for this task. |
| Aseprite | Project has editable `.aseprite` files. Executable not found on PATH or the checked common installation paths. Official [CLI documentation](https://www.aseprite.org/docs/cli/) supports batch export, layers, atlas PNG and JSON. | Useful optional future hand-editing/atlas tool; not a dependency. PNGs and integer recipes are editable now. Do not claim native `.aseprite` exports were produced. |
| UltraCode | No matching local skill or enabled tool found. Primary [faxenoff/ultracode repository](https://github.com/faxenoff/ultracode) describes code graphs, semantic indexing and code modification; [just-every/plugin-ultracode](https://github.com/just-every/plugin-ultracode) is a coding-workflow plugin. The name also refers to unrelated coding CLIs. | Verified as a lead, not assumed installed. No documented raster/animation production benefit; no verified GDScript integration advantage needed here. Do not install it or make assets depend on it. |
| Image generation | Available, but the requested pipeline is coded pixel art. | Unused. No generated painting, resampling-to-pixel filter or reference-face reproduction. |
| UI review | Native image viewer can inspect outputs. Browser inventory returned no enabled browsers. | Visual QA uses source PNGs, layout reductions, close-ups and a generated phone-size contact sheet. HTML source and JavaScript are checked locally; interactive browser behaviour is not claimed as verified. |

## Rebuild

From the repository root:

```powershell
python tools/generate_house_identity.py
python tools/verify_house_identity.py
```

`docs/visual-identity/review.html` works offline; all image references are relative. Scripts read only metadata in the existing game during verification, and do not alter existing runtime recipes, scenes, rules, saves or bindings. New proposal images live under `godot/assets/art_direction/house_remembers`, so an eventual export never depends on art outside `godot/`.

The current revisions use a common 640×1280 source grid. Stable recipe coordinates are converted to the finer source grid **before** primitive rasterisation; cubic contours are integer-sampled, and native one-pixel strokes refine material/anatomy detail. The verifier rejects simple repeated 2× raster blocks in the benchmark assets. PNG and GIF writes use atomic replacement to avoid partial reads/imports by an open editor or preview.

The manifest includes source sizes, all card IDs, explicit atlas frame sizes/timing, palette values and SHA-256 image hashes. Rebuilding twice must reproduce the same image bytes on the pinned Pillow version. Integer rasterization and fixed-palette GIF encoding are independent of seeded game randomness.
