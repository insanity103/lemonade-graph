local WorldLayout = require(script.Parent:WaitForChild("WorldLayout"))

WorldLayout.EnsureBuilt()

print(string.format("[WorldBuilder] Terrain and progression layout v%d ready", WorldLayout.VERSION))
