# VertigoDemo

Unity project for a Vertigo take-home — battle pass UI and weapon VFX work.

---

## Scenes

All scenes live under `Assets/Scenes/`.

| Scene | Path | What it is |
|-------|------|------------|
| **VertigoUI** | `Assets/Scenes/VertigoUI.unity` | Battle pass screen. Scrollable reward road, progress bar, free/paid tracks. This is the default scene in build settings. |
| **VertigoVFX** | `Assets/Scenes/VertigoVFX.unity` | Weapon showcase. MCX Top Scorer with custom shaders — wisps, energy filaments, wind, distortion. |

To open one: Project window → `Assets/Scenes/` → double-click the scene. Or File → Open Scene.

Screen recordings (where I have them) are in `Assets/Scenes/Recordings/`. `VertigoVFX.mov` is in the repo. `VertigoUI.mov` is kept locally only — the file is ~136 MB and GitHub won't take it.

---

## Project layout (quick map)

- `Assets/Task1_UI/` — battle pass prefabs, sprites, scripts
- `Assets/Task2_VFX/` — weapon model, materials, shaders, reference footage
- `Assets/Settings/` — URP render pipeline assets (PC + mobile)

Main scripts for the UI are in `Assets/Task1_UI/scripts/` — `BattlePassController`, `BattlePassRoadUI`, `RewardNodeUI`, `TiledBackgroundScroller`. Config lives in `New Battle Pass Config.asset`.

VFX shaders are in `Assets/Task2_VFX/weapon_model/Materials/`.

---

## Notes

Built on Unity URP. Open in a recent Unity 6 editor if you can — project was last worked on in 2025/2026.

If something looks pink or missing after clone: let Unity reimport (first open takes a minute). `Library/` and `Temp/` are gitignored on purpose — Unity regenerates those.

Reference images and a demo video for the battle pass are in `Assets/Task1_UI/references/`. VFX references are in `Assets/Task2_VFX/references/`.

---

## Running it

1. Clone the repo
2. Open the folder in Unity Hub
3. Open `VertigoUI` or `VertigoVFX` from `Assets/Scenes/`
4. Press Play

That's it.
