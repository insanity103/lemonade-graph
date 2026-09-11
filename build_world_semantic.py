#!/usr/bin/env python3
"""Semantic extraction for the world/ docs, in graphify's chunk-JSON schema.

World (non-script) instances become nodes; edges link them to the AST code nodes
that reference them. Every edge target is validated against the real code node
IDs so we never emit dangling endpoints.
"""
import json, pathlib, sys

ROOT = pathlib.Path(__file__).parent
CODE_IDS = set()
ast_path = ROOT / "graphify-out" / ".graphify_ast.json"
graph_path = ROOT / "graphify-out" / "graph.json"
if ast_path.exists():
    CODE_IDS = {n["id"] for n in json.loads(ast_path.read_text())["nodes"]}
elif graph_path.exists():
    CODE_IDS = {n["id"] for n in json.loads(graph_path.read_text())["nodes"]}

W = "lemonade-game/world/"
nodes, edges, hyperedges = [], [], []


def N(nid, label, src, ftype="concept", rationale=None):
    n = {"id": nid, "label": label, "file_type": ftype, "source_file": W + src,
         "source_location": None, "source_url": None, "captured_at": None,
         "author": None, "contributor": None}
    if rationale:
        n["rationale"] = rationale
    nodes.append(n)
    return nid


def E(s, t, rel, conf="EXTRACTED", score=1.0, src="Workspace.md"):
    edges.append({"source": s, "target": t, "relation": rel, "confidence": conf,
                  "confidence_score": score, "source_file": W + src,
                  "source_location": None, "weight": 1.0})


# ---------------------------------------------------------------- Workspace
WS = "Workspace.md"
spawn = N("world_workspace_spawnlocation", "Player SpawnLocation", WS)
trees = N("world_workspace_trees", "Authored biome decor clusters (25 Models)", WS,
          rationale="Fixed, code-generated scenery clusters frame arena edges: woodland and frost "
                    "trees, infernal deadwood, void crystals, and celestial ruins. Placement is "
                    "authored rather than random so entrances and sightlines stay clear.")
boulders = N("world_workspace_boulders", "Boulder decor clusters (16 Models)", WS,
             rationale="Fixed clusters of three-part Anchored rocks reinforce region edges and "
                       "landmarks without obstructing the progression trail.")
base = N("world_workspace_baseplate", "Baseplate", WS,
         rationale="WorldLayout restores the classic visible 512x20x512 baseplate at y=-10: "
                   "Medium stone grey Plastic, anchored, collidable, with Studs on top and Inlet below.")
runtime_enemies = N("world_workspace_runtimeenemies", "Runtime-spawned enemy rigs", WS,
                    rationale="Enemies exist only at runtime: EnemyCombat builds R6 rigs from "
                              "scratch with Motor6D joints and parents them to Workspace. Nothing "
                              "enemy-shaped is saved in the place file, so the world export cannot "
                              "show them. WorldLayout.GetEnemySpawns supplies five level-ordered "
                              "zones, each with one boss plus four minions: Boss_Gorgon (Lv10), "
                              "Boss_FrostRevenant (Lv25), Boss_InfernalColossus (Lv45), "
                              "Boss_VoidWraith (Lv70), and Boss_CelestialTitan (Lv100). Four roadside "
                              "WILD_CAMPS (3 mobs each, Lv11-13 / 26-28 / 44-48 / 70-74) sit beside ROUTE "
                              "transition nodes to close the level gap before each next door. Only bosses carry the "
                              "welded SwordMeshTemplate, tinted per boss via swordColor / "
                              "swordMaterial, and swing it with swingWeapon(). Every rig is "
                              "stamped with an Archetype attribute, which is how SwordDropSystem "
                              "knows which named weapon a dead boss drops.")

E(runtime_enemies, "serverscriptservice_enemycombat_server_createenemyrig", "references")
E(runtime_enemies, "serverscriptservice_enemycombat_server_spawnenemy", "references")
E(runtime_enemies, "serverscriptservice_worldlayout_worldlayout_getenemyspawns", "references")
E(runtime_enemies, "serverscriptservice_levelingsystem_server_connectenemyhumanoid",
  "conceptually_related_to", "INFERRED", 0.95)
E(runtime_enemies, "serverscriptservice_sworddropsystem_server_hook",
  "conceptually_related_to", "INFERRED", 0.95)
E(spawn, "serverscriptservice_levelingsystem_server_setupplayer",
  "conceptually_related_to", "INFERRED", 0.65)

boss_rooms = N("world_workspace_bossrooms", "Boss ruins (5 level-gated arenas)", WS,
               rationale="WorldLayout rebuilds Workspace/BossRooms with one circular 68-stud ruin per ascending "
                         "zone (Iron Lowlands, Frostbound Glacier, Infernal Caldera, Void Rift, "
                         "Celestial Summit). The shared layout places each boss and four minions inside. "
                         "Each doorway faces an authored junction on the main trail and holds a ForceField "
                         "'Door' whose RequiredLevel attribute (1/15/30/50/75) is the single tuning "
                         "knob. Each room also has an invisible Bounds part (the interior, used for "
                         "ejection) and an Exit marker outside the door.")
E(boss_rooms, "serverscriptservice_bossroomgate_server", "referenced_by")
E(boss_rooms, "serverscriptservice_worldlayout_buildbossroom", "created_by")
E(boss_rooms, "starterplayer_starterplayerscripts_bossdoorclient_client", "referenced_by")
E(boss_rooms, runtime_enemies, "contains")
E(boss_rooms, spawn, "conceptually_related_to", "INFERRED", 0.8)

# ---------------------------------------------------------------- Terrain
TR = "Terrain.md"
terrain = N("world_terrain_terrain", "Voxel Terrain", TR,
            rationale="WorldLayout clears the legacy voxels and creates one continuous authored landmass "
                      "along an ascending S-curve trail. Five regions use blended terrain ribbons, asymmetric "
                      "ridges, fixed decor clusters, and distinct skyline landmarks. EnemyCombat raycasts "
                      "against Terrain, Baseplate, and BossRooms so rigs snap to arena floors.")
E(terrain, "serverscriptservice_enemycombat_server_resolvegroundposition", "references", src=TR)
E(terrain, "serverscriptservice_worldlayout_buildterrain", "created_by", src=TR)
E(terrain, base, "semantically_similar_to", "INFERRED", 0.75, src=TR)

# ---------------------------------------------------------------- RemoteEvents
RS = "ReplicatedStorage.md"
remotes_folder = N("world_replicatedstorage_remoteevents", "RemoteEvents folder", RS,
                   rationale="The entire client/server contract of the game: 15 RemoteEvents, "
                             "every one of them the only channel between a server system and its "
                             "matching client UI. No RemoteFunctions — everything is fire-and-forget.")

# remote -> (server consumers, client consumers)
REMOTES = {
    "enemyattack":       ("EnemyAttack",       ["serverscriptservice_enemycombat_server"],
                          ["starterplayer_starterplayerscripts_combatcontroller_client"]),
    "damagenumber":      ("DamageNumber",      ["serverscriptservice_enemycombat_server",
                                                "serverscriptservice_swordsystem_server"],
                          ["starterplayer_starterplayerscripts_damagenumbers_client"]),
    "xpgain":            ("XPGain",            ["serverscriptservice_levelingsystem_server"],
                          ["starterplayer_starterplayerscripts_xpgainui_client"]),
    "spendskillpoint":   ("SpendSkillPoint",   ["serverscriptservice_levelingsystem_server"],
                          ["starterplayer_starterplayerscripts_combatcontroller_client",
                           "starterplayer_starterplayerscripts_mainmenugui_client"]),
    "goldgain":          ("GoldGain",          ["serverscriptservice_levelingsystem_server",
                                                "serverscriptservice_sworddropsystem_server"],
                          ["starterplayer_starterplayerscripts_goldnumbers_client"]),
    "levelupburst":      ("LevelUpBurst",      ["serverscriptservice_levelingsystem_server"],
                          ["starterplayer_starterplayerscripts_levelupburst_client"]),
    "toggleautoattack":  ("ToggleAutoAttack",  ["serverscriptservice_enemycombat_server"],
                          ["starterplayer_starterplayerscripts_combatcontroller_client"]),
    "inventoryupdated":  ("InventoryUpdated",  ["serverscriptservice_inventoryservice"],
                          ["starterplayer_starterplayerscripts_mainmenugui_client"]),
    "inventoryaction":   ("InventoryAction",   ["serverscriptservice_inventorysystem_server"],
                          ["starterplayer_starterplayerscripts_mainmenugui_client"]),
    "rebirth":           ("Rebirth",           ["serverscriptservice_rebirthsystem_server"],
                          ["starterplayer_starterplayerscripts_mainmenugui_client"]),
    "rebirthresult":     ("RebirthResult",     ["serverscriptservice_rebirthsystem_server"], []),
    "sworddrop":         ("SwordDrop",         ["serverscriptservice_sworddropsystem_server",
                                                "serverscriptservice_merchantsystem_server"],
                          ["starterplayer_starterplayerscripts_sworddroptoast_client"]),
    "merchantaction":    ("MerchantAction",    ["serverscriptservice_merchantsystem_server"],
                          ["starterplayer_starterplayerscripts_merchantgui_client"]),
    "toggleautosell":    ("ToggleAutoSell",    ["serverscriptservice_sworddropsystem_server"],
                          ["starterplayer_starterplayerscripts_mainmenugui_client"]),
    "autosellnotice":    ("AutoSellNotice",    ["serverscriptservice_sworddropsystem_server"],
                          ["starterplayer_starterplayerscripts_sworddroptoast_client"]),
    "swordlostondeath":  ("SwordLostOnDeath",  ["serverscriptservice_sworddropsystem_server"],
                          ["starterplayer_starterplayerscripts_sworddroptoast_client"]),
    "bossdoornotice":    ("BossDoorNotice",    ["serverscriptservice_bossroomgate_server"],
                          ["starterplayer_starterplayerscripts_bossdoorclient_client"]),
}
REMOTE_NOTES = {
    "rebirthresult": "Orphaned: RebirthSystem still fires it, but its only listener was RebirthGui, "
                     "which was deleted when the rebirth UI moved into MainMenuGui's "
                     "buildRebirthPanel(). Rebirth success/failure currently reaches no client.",
    "toggleautosell": "Client -> server. Flips the player's AutoSellLowerSwords attribute; "
                      "MainMenuGui's Inventory tab renders the toggle and re-renders on change.",
    "autosellnotice": "Server -> client. Fired instead of SwordDrop when a boss drop is auto-sold "
                      "because it has fewer modifier slots than the equipped weapon.",
    "swordlostondeath": "Server -> client. On death SwordDropSystem moves the equipped boss sword "
                        "to the Backpack so it survives respawn; with DEATH_SWORD_LOSS_CHANCE (2%) "
                        "it destroys the sword instead and fires this so SwordDropToast shows a "
                        "red 'shattered' card.",
}
remote_ids = {}
for key, (label, servers, clients) in REMOTES.items():
    rid = N(f"world_replicatedstorage_remoteevents_{key}", f"{label} (RemoteEvent)", RS,
            rationale=REMOTE_NOTES.get(key))
    remote_ids[key] = rid
    E(rid, remotes_folder, "references", src=RS)
    for s in servers:
        E(s, rid, "references", src=RS)
    for c in clients:
        E(c, rid, "references", src=RS)

config = N("world_replicatedstorage_config",
           "Config folder (Sword, Items, RebirthConfig, WeaponModifiers, MerchantConfig, BossWeapons)", RS,
           rationale="Shared tuning tables replicated to clients so UI can show the same numbers "
                     "the server uses. Sword and Items cover base damage and item definitions; "
                     "RebirthConfig owns rebirth multipliers, milestone perks and per-rarity drop "
                     "bonuses; WeaponModifiers rolls the prefix modifiers on boss drops; "
                     "BossWeapons is the single table of the five boss weapons' stats and look; "
                     "MerchantConfig holds only prices and shop blurbs and fills the stats in "
                     "from BossWeapons; SaveConfig lists what PlayerDataService persists between "
                     "sessions.")
for m in ("sword", "items", "rebirthconfig", "weaponmodifiers", "merchantconfig", "bossweapons",
          "saveconfig"):
    E(config, f"replicatedstorage_config_{m}", "references", src=RS)

# ---------------------------------------------------------------- persistence
save_flow = N("world_persistence_playerdata", "Cross-session player save", RS,
              rationale="PlayerDataStore drives PlayerDataService off PlayerAdded / PlayerRemoving: "
                        "on join it claims a DataStore session lock, reads the profile and applies "
                        "it (leaderstats Level/Experience/Gold/Rebirths, the persisted attributes, "
                        "inventory stacks via InventoryService.LoadPlayer, and boss swords rebuilt "
                        "with BossSwordFactory.rebuild from their exact saved attributes); a 120s "
                        "autosave loop and a BindToClose save-all cover mid-session and shutdown. "
                        "SaveConfig is the whitelist. InventorySystem was changed to defer inventory "
                        "ownership to PlayerDataService so a saved inventory is not overwritten with "
                        "starter items on join. Without Studio API access it degrades to memory-only "
                        "with a warning; a published game needs no toggle.")
for t in ("serverscriptservice_playerdatastore_server", "serverscriptservice_playerdataservice",
          "replicatedstorage_config_saveconfig", "serverscriptservice_inventoryservice",
          "serverscriptservice_bossswordfactory", "serverscriptservice_inventorysystem_server"):
    E(save_flow, t, "references", src=RS)

# ---------------------------------------------------------------- StarterPack
SP = "StarterPack.md"
sword = N("world_starterpack_classicsword", "ClassicSword (Tool)", SP,
          rationale="The plain part-built blade every player spawns holding. Deliberately simpler "
                    "than the boss's imported mesh sword so a boss drop reads as an upgrade; it is "
                    "only SwordDropSystem's fallback template now, not its normal source.")
handle = N("world_starterpack_handle", "ClassicSword Handle", SP,
           rationale="The leather grip Part, and the Tool's required Handle. Pommel, Guard, Blade "
                     "and the two tip wedges are welded to it, and all three sounds live inside it. "
                     "Grip is identity, so the hand sits at this part's centre.")
blade_parts = N("world_starterpack_bladeparts", "Starter sword blade assembly", SP,
                rationale="Pommel / Guard / Blade / TipUpper / TipLower, welded along the Handle's "
                          "-Z axis. TipUpper and TipLower are the same WedgePart mirrored 180 deg "
                          "about Z, meeting in a symmetric point 3.89 studs in front of the hand.")
slash = N("world_starterpack_swordslash", "SwordSlash sound", SP)
unsheath = N("world_starterpack_unsheath", "Unsheath sound", SP)
lunge = N("world_starterpack_swordlunge", "SwordLunge sound (unused)", SP,
          rationale="Present on the Handle but never played by any script — leftover from the "
                    "stock Roblox classic sword.")
for t in ("starterpack_classicsword_swordclient_client", "starterpack_classicsword_mouseicon_client",
          "serverscriptservice_swordsystem_server", "serverscriptservice_sworddropsystem_server"):
    E(sword, t, "references", src=SP)
E(handle, sword, "references", src=SP)
E(blade_parts, handle, "welded_to", src=SP)
E(slash, "starterpack_classicsword_swordclient_client", "references", src=SP)
E(unsheath, "starterpack_classicsword_swordclient_client", "references", src=SP)
E(lunge, handle, "references", src=SP)

# ---------------------------------------------------------------- ServerStorage
SS = "ServerStorage.md"
mesh_tpl = N("world_serverstorage_swordmeshtemplate", "SwordMeshTemplate (MeshPart)", SS,
             rationale="The imported boss blade, kept unparented as a sizing template. EnemyCombat "
                       "clones it for any archetype with weapon = true and sets "
                       "Size = SWORD_ASPECT * SWORD_LENGTH * scale, so a scale-1.5 boss carries a "
                       "6.3-stud version of the same undistorted mesh.")
mesh_flip = N("world_serverstorage_importer_flip", "Importer 180 deg Y flip", SS,
              rationale="Studio's 3D importer rotates the source model 180 deg about Y, so the "
                        "imported MeshPart is grip-at--Z / tip-at-+Z with the crossguard at local "
                        "z = -0.245*L — the opposite of the OBJ it was built from. Every placement "
                        "of this mesh must apply CFrame.Angles(0, math.pi, 0) or the rig ends up "
                        "holding the blade instead of the handle.")
boss_tool = N("world_serverstorage_bossswordtool", "BossSwordTool (Tool)", SS,
              rationale="The same mesh wrapped as an equippable Tool, and the template "
                        "BossSwordFactory.build() clones for every boss drop and merchant purchase. Each of the 5 "
                        "bosses has its own named weapon (Warlord Greatsword, Frostfang Cleaver, "
                        "Inferno Edge, Voidrend Blade, Astral Eclipse); the clone is renamed, "
                        "stamped with Rarity / DamageMult / CritChance / RangeBonus / "
                        "KnockbackBonus / BossTier attributes, given WeaponModifiers prefixes, "
                        "and retinted. It ships without SwordClient, so the factory copies that "
                        "in from ClassicSword. Its Grip folds in both the importer flip and the "
                        "0.38*L offset that puts the hand in the handle.")
E(mesh_tpl, "serverscriptservice_enemycombat_server", "referenced_by", src=SS)
E(mesh_flip, mesh_tpl, "constrains", src=SS)
E(mesh_flip, "serverscriptservice_enemycombat_server", "constrains", src=SS)
E(mesh_flip, boss_tool, "constrains", src=SS)
E(boss_tool, mesh_tpl, "wraps", src=SS)
E(boss_tool, "serverscriptservice_sworddropsystem_server", "referenced_by", src=SS)
E(sword, boss_tool, "fallback_for", conf="INFERRED", score=0.9, src=SS)

# ---------------------------------------------------------------- Lighting
LT = "Lighting.md"
lighting_nodes = []
for key, label in [("sky", "Sky"), ("atmosphere", "Atmosphere"), ("bloom", "BloomEffect"),
                   ("sunrays", "SunRaysEffect"), ("depthoffield", "DepthOfFieldEffect")]:
    nid = N(f"world_lighting_{key}", f"Lighting/{label}", LT)
    lighting_nodes.append(nid)
    if key != "depthoffield" and key != "sky":
        E("workspace_daycycle_server", nid, "references", src=LT)
    else:
        E(nid, "workspace_daycycle_server", "conceptually_related_to", "INFERRED", 0.65, src=LT)

# ---------------------------------------------------------------- place
PJ = "place.json"
place = N("world_place_lemonadegame", "Lemonade RPG place (root)", PJ, ftype="document",
          rationale="Sword-combat RPG built by the Lemonade AI Studio plugin; every instance it "
                    "touched carries a _lemonadeUniqueId attribute. 157 instances total across "
                    "9 services, 29 Luau scripts.")
for t in (terrain, remotes_folder, sword, boss_tool, spawn, runtime_enemies):
    E(place, t, "references", src=PJ)

# ---------------------------------------------------------------- hyperedges
hyperedges.append({
    "id": "daynight_lighting_stack", "label": "Day/night lighting stack",
    "nodes": lighting_nodes + ["workspace_daycycle_server"],
    "relation": "participate_in", "confidence": "EXTRACTED", "confidence_score": 1.0,
    "source_file": W + LT})
hyperedges.append({
    "id": "boss_weapon_drop_loop", "label": "Boss weapon drop + auto-sell loop",
    "nodes": [runtime_enemies, boss_tool, mesh_tpl, remote_ids["sworddrop"],
              remote_ids["toggleautosell"], remote_ids["autosellnotice"],
              "serverscriptservice_sworddropsystem_server",
              "replicatedstorage_config_weaponmodifiers", "replicatedstorage_config_rebirthconfig",
              "starterplayer_starterplayerscripts_sworddroptoast_client",
              "starterplayer_starterplayerscripts_mainmenugui_client",
              "replicatedstorage_config_bossweapons", "serverscriptservice_bossswordfactory"],
    "relation": "participate_in", "confidence": "EXTRACTED", "confidence_score": 1.0,
    "source_file": W + SS})
hyperedges.append({
    "id": "boss_room_gating", "label": "Level-gated boss rooms",
    "nodes": [boss_rooms, runtime_enemies, remote_ids["bossdoornotice"],
              "serverscriptservice_bossroomgate_server",
              "starterplayer_starterplayerscripts_bossdoorclient_client",
              "serverscriptservice_levelingsystem_server"],
    "relation": "participate_in", "confidence": "EXTRACTED", "confidence_score": 1.0,
    "source_file": W + WS})
hyperedges.append({
    "id": "cross_session_save", "label": "Cross-session player save/load",
    "nodes": [save_flow, "serverscriptservice_playerdatastore_server",
              "serverscriptservice_playerdataservice", "replicatedstorage_config_saveconfig",
              "serverscriptservice_inventoryservice", "serverscriptservice_bossswordfactory",
              "serverscriptservice_inventorysystem_server"],
    "relation": "participate_in", "confidence": "EXTRACTED", "confidence_score": 1.0,
    "source_file": W + RS})
hyperedges.append({
    "id": "merchant_purchase_flow", "label": "Merchant sword purchase",
    "nodes": [remote_ids["merchantaction"], remote_ids["sworddrop"], boss_tool,
              "serverscriptservice_merchantsystem_server",
              "starterplayer_starterplayerscripts_merchantgui_client",
              "replicatedstorage_config_merchantconfig", "replicatedstorage_config_bossweapons",
              "serverscriptservice_bossswordfactory"],
    "relation": "participate_in", "confidence": "EXTRACTED", "confidence_score": 1.0,
    "source_file": W + SS})
hyperedges.append({
    "id": "rebirth_progression", "label": "Rebirth progression",
    "nodes": ["replicatedstorage_config_rebirthconfig", "serverscriptservice_rebirthsystem_server",
              remote_ids["rebirth"], remote_ids["rebirthresult"],
              "starterplayer_starterplayerscripts_mainmenugui_client",
              "serverscriptservice_swordsystem_server", "serverscriptservice_sworddropsystem_server"],
    "relation": "participate_in", "confidence": "EXTRACTED", "confidence_score": 1.0,
    "source_file": W + RS})

# ---------------------------------------------------------------- validate
world_ids = {n["id"] for n in nodes}
known = world_ids | CODE_IDS

# graphify derives AST node IDs from the path it was pointed at, so running it on the
# project root instead of lemonade-game/ prefixes every code ID ("lemonade_game_...").
# The IDs written above are the unprefixed form; resolve by unique suffix match so a
# change of scan root doesn't silently dangle every edge into the code layer.
_by_suffix = {}
for cid in CODE_IDS:
    parts = cid.split("_")
    for i in range(len(parts)):
        _by_suffix.setdefault("_".join(parts[i:]), []).append(cid)


def resolve(nid):
    if nid in known:
        return nid
    hits = _by_suffix.get(nid, [])
    return hits[0] if len(hits) == 1 else nid


for e in edges:
    e["source"] = resolve(e["source"])
    e["target"] = resolve(e["target"])
for h in hyperedges:
    h["nodes"] = [resolve(n) for n in h["nodes"]]

dangling = [e for e in edges if e["source"] not in known or e["target"] not in known]
for e in dangling:
    bad = e["source"] if e["source"] not in known else e["target"]
    print(f"DROPPED dangling edge -> {bad}", file=sys.stderr)
edges = [e for e in edges if e["source"] in known and e["target"] in known]
for h in hyperedges:
    missing = [n for n in h["nodes"] if n not in known]
    if missing:
        print(f"hyperedge {h['id']}: dropping unknown {missing}", file=sys.stderr)
        h["nodes"] = [n for n in h["nodes"] if n in known]
hyperedges = [h for h in hyperedges if len(h["nodes"]) >= 3]

out = {"nodes": nodes, "edges": edges, "hyperedges": hyperedges,
       "input_tokens": 0, "output_tokens": 0}
dest = ROOT / "graphify-out" / ".graphify_semantic.json"
dest.parent.mkdir(parents=True, exist_ok=True)
dest.write_text(json.dumps(out, indent=2), encoding="utf-8")
print(f"world semantic: {len(nodes)} nodes, {len(edges)} edges, "
      f"{len(hyperedges)} hyperedges  ({len(dangling)} dangling dropped)")
print(f"validated against {len(CODE_IDS)} known code node ids")
