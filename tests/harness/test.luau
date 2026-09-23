--// tests/harness/test.luau  (a small test API for the spec files)
-- A spec file returns function(t) and registers its tests with t.test(name, fn). Inside a test:
--   t.check(cond, message, ...)   record a failure and KEEP GOING (report every bad row, not the first)
--   t.expect(cond, message, ...)  record a failure and STOP this test
--   t.eq(actual, expected, label) / t.near(actual, expected, tolerance, label)
--   t.note(message, ...)          a line printed under the test even when it passes (measurements)
--   t.scale(n)                    n scaled for --quick runs (sample sizes)
local Test = {}

local Abort = {}

function Test.new(options)
	local self = { tests = {}, options = options or {} }
	local current = nil

	local function fmt(message, ...)
		if select("#", ...) > 0 then return string.format(message, ...) end
		return tostring(message)
	end

	-- opts.knownIssue: a one-line description of a CONFIRMED defect in the game code that this test
	-- catches. The test still runs and its failures are printed in full, but it is reported as
	-- KNOWN instead of failing the run, so CI stays useful while the defect is open. When the code
	-- is fixed the test passes, and the runner then fails the run until the marker is removed.
	-- `--strict` treats known issues as plain failures.
	function self.test(name, fn, opts)
		table.insert(self.tests, { name = name, fn = fn, knownIssue = opts and opts.knownIssue })
	end

	function self.check(cond, message, ...)
		if not cond then
			table.insert(current.failures, fmt(message or "check failed", ...))
		end
		return cond
	end

	function self.expect(cond, message, ...)
		if not cond then
			table.insert(current.failures, fmt(message or "expectation failed", ...))
			error(Abort, 0)
		end
		return cond
	end

	function self.eq(actual, expected, label)
		return self.check(actual == expected, "%s: expected %s, got %s", label or "value", tostring(expected), tostring(actual))
	end

	function self.near(actual, expected, tolerance, label)
		return self.check(type(actual) == "number" and math.abs(actual - expected) <= tolerance,
			"%s: expected %s +- %s, got %s", label or "value", tostring(expected), tostring(tolerance), tostring(actual))
	end

	function self.note(message, ...)
		table.insert(current.notes, fmt(message, ...))
	end

	function self.scale(n)
		local factor = self.options.quick and 0.1 or 1
		return math.max(1, math.floor(n * factor))
	end

	function self._run(entry)
		current = { failures = {}, notes = {} }
		local ok, err = xpcall(entry.fn, function(e)
			if e == Abort then return Abort end
			return debug.traceback(tostring(e), 2)
		end)
		if not ok and err ~= Abort then
			table.insert(current.failures, "error: " .. tostring(err))
		end
		local result = current
		current = nil
		return result
	end

	return self
end

return Test
