"""Check the built Rojo integration, not a running Studio session.

Usage: python3 tools/check_gameplay_project.py /tmp/lemonade-gameplay-only.rbxlx
"""
import re
import sys
import xml.etree.ElementTree as ET

root = ET.parse(sys.argv[1]).getroot()

def name(item):
    return item.findtext("Properties/string[@name='Name']")

services = {name(item): item for item in root.findall("Item")}
assert not {"Workspace", "Lighting", "ServerStorage"} & services.keys(), services.keys()
server = {name(item): item for item in services["ServerScriptService"].findall("Item")}
required = {
    "AdminSystem", "RuntimeBootstrap", "WorldLayout", "SafeHub", "GameplayActors", "GameplayServices",
    "EnemyCombat", "SwordSystem", "SwordDropSystem", "BossSwordFactory", "CombatUtil",
    "InventoryService", "InventorySystem", "LevelingSystem", "MerchantSystem", "QuestSystem",
    "RebirthSystem", "PlayerDataService", "PlayerDataStore", "VaultSystem", "TradeSystem", "ReforgeSystem",
}
assert required == server.keys(), required ^ server.keys()
assert server["WorldLayout"].attrib["class"] == "ModuleScript"
assert server["GameplayServices"].attrib["class"] == "Script"

scripts = [item for item in root.iter("Item") if item.attrib["class"] in {"Script", "LocalScript", "ModuleScript"}]
sources = {name(item): item.findtext("Properties/*[@name='Source']") or "" for item in scripts}
assert all(sources.values()), "A packaged script is missing its source"
for script_name, source in sources.items():
    assert not re.search(r":(?:Clear|FillBall|FillBlock|FillRegion|FillWedge|WriteVoxels)\s*\(", source), script_name
    assert not re.search(r"GetService\([\"']Lighting[\"']\)", source), script_name
    for dependency in re.findall(r'require\(script.Parent:WaitForChild\("([^"\n]+)"\)\)', source):
        if script_name in server:
            assert dependency in server, (script_name, dependency)

client_scripts = {name(item) for item in services["StarterPlayer"].iter("Item") if item.attrib["class"] == "LocalScript"}
assert "BossDoorClient" not in client_scripts
assert {"CombatController", "QuestGui", "MerchantGui", "MainMenuGui", "RunController", "ComboVFX", "Notifications", "HitStreakGui"} <= client_scripts
assert "OnboardingGui" not in client_scripts
assert len(client_scripts) == 17, client_scripts
assert "WorldLayout.BLANK_SLATE = true" not in sources["WorldLayout"]
assert "BLANK_SLATE = false" in sources["WorldLayout"]
assert "MapAnchors" not in sources["WorldLayout"]
assert "MapAnchors" not in sources["SafeHub"]
assert "GetEnemySpawns" in sources["WorldLayout"]
assert "GAMEPLAY_ONLY" in sources["MerchantSystem"] and "GAMEPLAY_ONLY" in sources["QuestSystem"]
print(f"PASS: {len(server)} server components and {len(client_scripts)} client scripts; no environment services or terrain writes")
