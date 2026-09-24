# Outfit gauntlet — live progress

Target: original NPC and enemy outfits with Deepwoken-level tailoring, coherent materials,
recognizable silhouettes and readable equipment. Started 2026-09-19.

## Scope and plan

[ASSUMPTION] The target game is the active `lemonade-graph` project. Its nine prebuilt R15
town NPCs and all enemy archetypes are in scope. Outfit geometry and appearance may change;
rig contracts, role props, combat balance and the gameplay-only world baseline are preserved.

| Group | Construction direction | Verification |
| --- | --- | --- |
| Town NPCs | Fitted layered garments, distinct profession silhouettes, restrained metal trim | R15 joints and welds, front/back previews, role recognition |
| Quarry enemies | Scavenged leather and iron, wraps, asymmetric plate, rank progression | Moving-limb binding, scale, elite variant, boss weapon clearance |
| Other enemy families | Region-specific materials and silhouettes, distinct light/heavy/boss kits | Complete archetype coverage, attachment safety, readable faction/rank |

Runtime flow: existing actor spawner → existing rig → outfit data / native model → existing
animation and combat. No new remotes, gameplay states or saved-data fields are needed.

The earlier NPC builder worked in a separate Git worktree. Its generated models are now
integrated here. Blender preview renders were compared with the references to identify
the remaining visual gap. A local render is not Studio runtime proof.

## References inspected

- [Deepwoken Black Diver](https://deepwoken.fandom.com/wiki/Black_Diver): fitted layered coat,
  shaped lapels, restrained palette, small warm focal point, functional straps.
- [Deepwoken Abyss Wanderer's Plate](https://deepwoken.fandom.com/wiki/Abyss_Wanderer%27s_Plate):
  in-game armor view with overlapping plates, edge trim, belt and hanging cloth.
- [Deepwoken Etris guard](https://deepwoken.fandom.com/wiki/Etris): in-game guard reference.

Downloaded comparison images live in `artifacts/outfit-gauntlet/references/`. They are
reference material only, never game assets.

## Current status

- [x] Located active outfit integration and preserved the existing gameplay baseline.
- [x] Downloaded actual Deepwoken reference images.
- [x] Completed and integrated the nine tailored R15 NPC models.
- [x] Added region-specific outfits for all 24 enemy archetypes and the quarry elite variant.
- [x] Rendered baseline and candidate models in Blender under matching preview conditions.
- [x] Reviewed representative NPC and enemy renders; revised the NPC hats, beard, coat panels and armor, and added readable eyes and collars to regional enemies.
- [x] Validated NPC rig joints and new outfit welds, enemy welds and scale placement, and the Rojo build.
- [ ] Studio movement, attack, interaction and collision verification.

Studio control check: WEPPY currently reports zero connected Studio clients. Local
verification can proceed, but live animation, collisions and final in-game appearance
cannot yet be certified.

Local verification: `python3 tools/check_npc_outfits.py` passes all nine NPCs;
`/tmp/gauntlet-lune/lune run tools/check_outfits.luau . artifacts/outfit-gauntlet/candidate-enemies`
passes 24 archetypes and 25 variants; `rojo build default.project.json -o
/tmp/lemonade-outfits.rbxlx` and `python3 tools/check_gameplay_project.py
/tmp/lemonade-outfits.rbxlx` pass. The `/tmp/gauntlet-lune/lune` binary is a local
temporary tool, not a repository dependency.

The native-part enemy kits are complete and visibly distinct by region and rank, but
the Blender previews still show the blocky R6 base rig. They do not yet meet the
fidelity of the Deepwoken references. Reaching that bar would require custom mesh
heads/hair, textured clothing and Studio asset import; these local native-part kits
are the usable in-game result of this pass.
