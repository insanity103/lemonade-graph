-- ModuleScript | ReplicatedStorage.NumberFormat | Short, readable numbers for HUD text (12.5K, 3.4M).
local NumberFormat = {}

local SUFFIXES = { { 1e12, "T" }, { 1e9, "B" }, { 1e6, "M" }, { 1e3, "K" } }

-- Values under 10,000 stay exact so early-game progress reads precisely; larger values keep
-- one decimal (dropped when it would be .0) and never round up past the true value, so
-- "999.9K / 1M" cannot display as a full bar's worth of text before the level actually ticks.
function NumberFormat.short(value: number): string
	if typeof(value) ~= "number" or value ~= value then
		return "0"
	end
	local sign = value < 0 and "-" or ""
	local n = math.abs(value)
	if n < 10000 then
		return sign .. tostring(math.floor(n))
	end
	for _, entry in ipairs(SUFFIXES) do
		if n >= entry[1] then
			local scaled = math.floor(n / entry[1] * 10) / 10
			local text = if scaled % 1 == 0 then string.format("%d", scaled) else string.format("%.1f", scaled)
			return sign .. text .. entry[2]
		end
	end
	return sign .. tostring(math.floor(n))
end

return NumberFormat
