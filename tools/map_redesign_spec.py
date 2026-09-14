"""Single source of placement truth; distances are Roblox studs, Y is up."""
from math import cos, sin, radians

VERSION = 1
SEED = 13092026
HUB_RADIUS = 180
SAFE_RADIUS = 195
HUB_Y = 6
BRIDGE_WIDTH = 28
ARENA_SIZE = 68
DOOR_WIDTH = 14

REGIONS = [
    dict(id="IronLowlands", title="Iron Lowlands", subtitle="THE OVERGROWN CITADEL", angle=0,
         level=1, height=10, boss="Boss_Gorgon", boss_level=10, style="Woodland",
         color="#749553", stone="#8b8772", dark="#4b5550", accent="#d8b16b",
         minions=[("IronSquire", 1), ("IronBerserker", 2)], elite=("IronBerserker", 3),
         pocket=dict(id="Briarwood", title="Briarwood", level=8, boss="RootWarden", boss_level=14,
                     minions=[("ThornStalker", 9), ("BriarBrute", 11)], style="Briar")),
    dict(id="FrostboundGlacier", title="Frostbound Glacier", subtitle="THE SHATTERED CROWN", angle=72,
         level=15, height=18, boss="Boss_FrostRevenant", boss_level=25, style="FrostPine",
         color="#d5e9e6", stone="#88b8ce", dark="#3c657f", accent="#9ae9ed",
         minions=[("FrostImp", 18), ("GlacialGargoyle", 21)], elite=("GlacialGargoyle", 23),
         pocket=dict(id="SunkenMarsh", title="Sunken Marsh", level=23, boss="DrownedBellwarden", boss_level=29,
                     minions=[("BogLurker", 24), ("MireHulk", 26)], style="Marsh")),
    dict(id="InfernalCaldera", title="Infernal Caldera", subtitle="THE EMBER FORGE", angle=144,
         level=30, height=14, boss="Boss_InfernalColossus", boss_level=45, style="Infernal",
         color="#65554b", stone="#50464b", dark="#302e37", accent="#ff994b",
         minions=[("CinderFiend", 34), ("MagmaJuggernaut", 38)], elite=("MagmaJuggernaut", 41),
         pocket=dict(id="Stormwatch", title="Stormwatch", level=40, boss="TempestWarden", boss_level=48,
                     minions=[("Stormcaller", 41), ("ThunderConstruct", 44)], style="Storm")),
    dict(id="VoidRift", title="Void Rift", subtitle="THE HOLLOW OBSERVATORY", angle=216,
         level=50, height=22, boss="Boss_VoidWraith", boss_level=70, style="Void",
         color="#615273", stone="#675e88", dark="#302d48", accent="#bd94ee",
         minions=[("VoidShade", 55), ("AbyssTormentor", 62)], elite=("AbyssTormentor", 66)),
    dict(id="CelestialSummit", title="Celestial Summit", subtitle="THE SUNWARD TEMPLE", angle=288,
         level=75, height=30, boss="Boss_CelestialTitan", boss_level=100, style="Celestial",
         color="#b1beb0", stone="#f1e4cd", dark="#777e87", accent="#efc579",
         minions=[("AstralWisp", 80), ("SolarDominator", 88)], elite=("SolarDominator", 92)),
]

def world(region, x, distance, y=None):
    """Map-local right/outward to Roblox XYZ (arena CFrame local X is reversed)."""
    a = radians(region["angle"])
    return [round(x*cos(a) + distance*sin(a), 4),
            region["height"] if y is None else y,
            round(x*sin(a) - distance*cos(a), 4)]

def arena(region, x, distance, spec):
    y = region["height"] + 2
    center = world(region, x, distance, y)
    entries = [(spec["boss"], 0, 10, spec["boss_level"], "boss")]
    for i, (dx, dz) in enumerate([(-15,-7),(15,-7),(-14,17),(14,17)]):
        enemy, level = spec["minions"][i//2]
        entries.append((enemy, dx, dz, level + i%2, "minion"))
    if "elite" in spec:
        entries.append((spec["elite"][0], -7, 26, spec["elite"][1], "elite"))
    return dict(Name=spec["id"], DisplayName=spec.get("title"), Region=region["id"],
                RequiredLevel=spec["level"], Center=center,
                Approach=world(region, x, distance-52, y),
                Door=world(region, x, distance-34, y+7),
                Exit=world(region, x, distance-45, y+3),
                BoundsCenter=world(region, x, distance, y+11),
                BoundsSize=[62,22,62], FloorDiameter=68, DoorSize=[14,14,1.5],
                Style=spec["style"],
                Spawns=[dict(Archetype=e, LocalPosition=[dx,0,dz], Level=lv, Role=role,
                             Position=world(region,x-dx,distance+dz,y)) for e,dx,dz,lv,role in entries])

def make_contract():
    zones, branches, spawns = [], [], []
    for r in REGIONS:
        points = [world(r,0,d,HUB_Y if d<=178 else r["height"] if d>=306
                        else round(HUB_Y+(r["height"]-HUB_Y)*(d-178)/128,4))
                  for d in (24,92,152,178,220,265,306,340,390,445,498)]
        b = dict(Id=r["id"], DisplayName=r["title"], AngleDegrees=r["angle"],
                 RequiredLevel=r["level"], Waypoints=points, Width=BRIDGE_WIDTH,
                 GroundY=r["height"], Color=r["color"], Accent=r["accent"],
                 Landmark=world(r,0,630), CombatEntry=world(r,0,314),
                 ReturnAnchor=world(r,-20,306,r["height"]+3),
                 EnemyTerritory=dict(Center=world(r,0,467), Size=[280,160,382]),
                 MainArena=r["id"], SecondaryArena=r.get("pocket",{}).get("id"))
        branches.append(b)
        zones.append(arena(r,0,550,r))
        if "pocket" in r:
            zones.append(arena(r,91,445,r["pocket"]))
        for i,(dx,d) in enumerate([(-58,342),(-43,357),(-75,365),(48,343),(66,358),(46,377),
                                    (-62,410),(-48,432),(-78,430),(25,415),(38,438),(19,450)]):
            enemy, lv = r["minions"][i//6]
            spawns.append(dict(Id=f"{r['id']}_Field_{i+1:02}",Region=r["id"],
                               Archetype=enemy,Level=lv+i%3,Role="field",
                               Position=world(r,dx,d), LeashRadius=50))
    r=REGIONS[3]
    for i,(enemy,lv) in enumerate([("AbyssTormentor",70),("VoidShade",72),("AstralWisp",74)]):
        spawns.append(dict(Id=f"RiftSummitSteps_{i+1}",Region="VoidRift",Zone="RiftSummitSteps",
                           Archetype=enemy,Level=lv,Role="bridge_camp",
                           Position=world(r,86+(i-1)*12,443+i%2*14),LeashRadius=50))
    return dict(Version=VERSION, Name="Fivefold Sanctuary", Units="studs", UpAxis="Y",
                BlenderMapping="Blender (x,y,z) = Roblox (X,-Z,Y); glTF Y-up restores Roblox XYZ",
                Hub=dict(Center=[0,HUB_Y,0], Radius=HUB_RADIUS, SafeRadius=SAFE_RADIUS,
                         SafeHeight=[-80,200], SpawnPosition=[0,HUB_Y+3,42],
                         QuestGiverPosition=[-42,HUB_Y+.3,12], MerchantPosition=[98,HUB_Y+.3,27],
                         RebirthPosition=[-98,HUB_Y+.3,32], RebirthPromptPosition=[-98,HUB_Y+3.8,36],
                         RebirthFacing=[0,0,1], RebirthInteractionRadius=12),
                Branches=branches, Zones=zones, FieldSpawns=spawns,
                Secrets=[dict(Id="BriarRelic",Region="IronLowlands",Position=world(REGIONS[0],-98,492,22),Kind="visible ledge"),
                         dict(Id="RiftArchive",Region="VoidRift",Position=world(REGIONS[3],-92,475,22),Kind="screened alcove")],
                RuntimeRequirements=["Consume Branches independently; never concatenate into one ROUTE polyline",
                  "Keep all eight zone identifiers; five main regions contain three secondary arenas",
                  "Spawn FieldSpawns in addition to Zones.Spawns",
                  "Server safe-zone target/damage rejection and leash clamps are required",
                  "Rebirth prompt opens the existing confirmation panel; it must not perform a rebirth directly",
                  "Disable old procedural world geometry only after the imported map is present"])
