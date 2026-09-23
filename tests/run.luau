--// tests/run.luau  (the headless test runner: `lune run tests/run.luau [--quick] [--seed N] [filter ...]`)
-- Runs every tests/spec/*.spec.luau against the real game code in a harness world (no Roblox, no
-- Studio). Prints PASS / FAIL per test with timings, the notes each test records, the failures in
-- full, and a summary. Exits non-zero if anything failed. Use tests/run.sh (or `make test`), which
-- runs this from the repo root.
--   --quick     sample sizes x0.1 (local iteration; CI runs the full sizes)
--   --seed N    the RNG seed (default 20260923; every test is reseeded from it, so order is irrelevant)
--   --verbose   print each test's notes even when it passes (default: notes only for failures)
--   --strict    known issues (tests marked knownIssue: confirmed game defects) fail the run too
--   filter      only specs / tests whose "file > name" contains one of these substrings
local fs = require("@lune/fs")
local process = require("@lune/process")
local stdio = require("@lune/stdio")

local Test = require("./harness/test")
local World = require("./harness/world")

local options = { quick = false, seed = 20260923, verbose = false, strict = false, filters = {} }
do
	local i = 1
	local args = process.args
	while i <= #args do
		local a = args[i]
		if a == "--quick" then options.quick = true
		elseif a == "--verbose" or a == "-v" then options.verbose = true
		elseif a == "--strict" then options.strict = true
		elseif a == "--seed" then i += 1 options.seed = tonumber(args[i]) or options.seed
		else table.insert(options.filters, a) end
		i += 1
	end
end

-- Colour only on a terminal-ish run; CI logs and NO_COLOR get plain text.
local useColor = process.env.NO_COLOR == nil and process.env.CI == nil
local function paint(c, text)
	if not useColor then return text end
	if c == "dim" then return stdio.style("dim") .. text .. stdio.style("reset") end
	return stdio.color(c) .. text .. stdio.color("reset")
end

local function matches(label)
	if #options.filters == 0 then return true end
	for _, f in ipairs(options.filters) do
		if string.find(label, f, 1, true) then return true end
	end
	return false
end

-- Stable per-test seed: the base seed mixed with the test's label, so adding or filtering tests
-- never changes what another test draws.
local function seedFor(label)
	local h = options.seed
	for i = 1, #label do h = (h * 31 + string.byte(label, i)) % 2147483647 end
	return h
end

local specDir = "tests/spec"
local files = {}
for _, name in ipairs(fs.readDir(specDir)) do
	if string.match(name, "%.spec%.luau$") then table.insert(files, name) end
end
table.sort(files)

print(string.format("lemonade-graph headless tests  (lune, seed %d%s)", options.seed, options.quick and ", QUICK" or ""))

local passed, failed, skipped, known = 0, 0, 0, 0
local failures = {}
local knownList = {}
local started = os.clock()

for _, file in ipairs(files) do
	local specName = string.gsub(file, "%.spec%.luau$", "")
	local t = Test.new(options)
	local ok, err = pcall(function()
		local register = require("./spec/" .. specName .. ".spec")
		register(t)
	end)
	if not ok then
		failed += 1
		table.insert(failures, { label = specName .. " (loading the spec)", failures = { tostring(err) }, logs = {} })
		print(paint("red", "FAIL") .. "  " .. specName .. " (could not load: " .. tostring(err) .. ")")
		continue
	end
	for _, entry in ipairs(t.tests) do
		local label = specName .. " > " .. entry.name
		if not matches(label) then
			skipped += 1
			continue
		end
		math.randomseed(seedFor(label))
		World.live = {}
		local t0 = os.clock()
		local result = t._run(entry)
		local dt = os.clock() - t0
		-- A game thread that errored (a Connect handler, a spawned task) fails the test too: in
		-- Roblox it would only print, which is how bugs like these get through.
		local logs = {}
		for _, world in ipairs(World.live) do
			for _, e in ipairs(world.errors) do
				table.insert(result.failures, "script error in game code: " .. e)
			end
			for _, line in ipairs(world.logs) do table.insert(logs, line) end
		end
		World.live = {}
		local good = #result.failures == 0
		local tag
		if entry.knownIssue and not options.strict then
			if good then
				-- the defect this test documents no longer reproduces: make someone remove the marker
				failed += 1
				tag = paint("red", "FIXED?")
				table.insert(failures, { label = label, logs = {}, failures = {
					"marked knownIssue but now PASSES -- if the defect is fixed, remove the knownIssue marker: "
						.. entry.knownIssue } })
			else
				known += 1
				tag = paint("yellow", "KNOWN")
				table.insert(knownList, { label = label, issue = entry.knownIssue, failures = result.failures })
			end
		elseif good then
			passed += 1
			tag = paint("green", "PASS")
		else
			failed += 1
			tag = paint("red", "FAIL")
			table.insert(failures, { label = label, failures = result.failures, logs = logs, notes = result.notes })
		end
		print(string.format("%s  %s  %s", tag, label, paint("dim", string.format("(%.2fs)", dt))))
		if options.verbose or not good then
			for _, note in ipairs(result.notes) do print("        " .. note) end
		end
	end
end

local elapsed = os.clock() - started
if #knownList > 0 then
	print("")
	print(paint("yellow", string.rep("-", 78)))
	print(paint("yellow", "KNOWN ISSUES") .. " (confirmed defects in the game code; not failing the run -- use --strict)")
	for _, k in ipairs(knownList) do
		print(paint("yellow", "KNOWN ") .. k.label)
		print("    issue: " .. k.issue)
		for i, msg in ipairs(k.failures) do
			if i > 12 then
				print(string.format("    ... and %d more", #k.failures - 12))
				break
			end
			print("    - " .. string.gsub(msg, "\n", "\n      "))
		end
	end
	print(paint("yellow", string.rep("-", 78)))
end
if #failures > 0 then
	print("")
	print(paint("red", string.rep("=", 78)))
	for _, f in ipairs(failures) do
		print(paint("red", "FAIL ") .. f.label)
		local shown = 0
		for _, msg in ipairs(f.failures) do
			shown += 1
			if shown > 40 then
				print(string.format("    ... and %d more", #f.failures - 40))
				break
			end
			print("    - " .. string.gsub(msg, "\n", "\n      "))
		end
		if #f.logs > 0 then
			print("    game log (last 15 lines):")
			for i = math.max(1, #f.logs - 14), #f.logs do
				print(string.format("      [%s] %s", f.logs[i].kind, f.logs[i].text))
			end
		end
	end
	print(paint("red", string.rep("=", 78)))
end
print("")
print(string.format("%s: %d passed, %d failed, %d known issue%s%s in %.1fs",
	failed == 0 and paint("green", "OK") or paint("red", "FAILED"), passed, failed, known, known == 1 and "" or "s",
	skipped > 0 and string.format(", %d filtered out", skipped) or "", elapsed))
process.exit(failed == 0 and 0 or 1)
