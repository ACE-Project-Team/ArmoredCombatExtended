--- Tiny test runner for the pure ACE sustainability logic.
--
--   luajit tests/run.lua            (run all suites)
--   luajit tests/run.lua gridsolve  (run just test_gridsolve.lua)
--
-- Exits non-zero if any assertion fails, so it can gate a commit / CI.

-- Resolve the tests/ dir from how we were invoked, so the module loader and the
-- suite loader work regardless of the current working directory.
local SELF    = arg[0] or "tests/run.lua"
local TESTDIR = SELF:match("^(.*[/\\])") or "./"
_G.ACE_TEST_DIR   = TESTDIR
_G.ACE_MODULE_DIR = TESTDIR .. "../lua/acf/shared/sustainability/"

local pass, fail = 0, 0
local failures   = {}
local curSuite   = "?"

-- Assertion API exposed as globals to the suites (kept minimal on purpose).
function _G.suite(name) curSuite = name; io.write("\n# " .. name .. "\n") end

function _G.check(cond, msg)
	if cond then
		pass = pass + 1
		io.write("  ok   " .. (msg or "") .. "\n")
	else
		fail = fail + 1
		failures[#failures + 1] = curSuite .. ": " .. (msg or "(no message)")
		io.write("  FAIL " .. (msg or "") .. "\n")
	end
end

-- Approximate-equality assertion (the maths involves efficiency products).
function _G.near(a, b, msg, tol)
	tol = tol or 1e-6
	local ok = math.abs((a or 0) - (b or 0)) <= tol
	check(ok, (msg or "near") .. string.format("  (got %.6g, want %.6g)", a or 0/0, b or 0/0))
end

local SUITES = { "gridsolve", "fault", "power" }

local only = arg[1]
if only then SUITES = { only } end

for _, s in ipairs(SUITES) do
	dofile(TESTDIR .. "test_" .. s .. ".lua")
end

io.write(string.format("\n%d passed, %d failed\n", pass, fail))
if fail > 0 then
	io.write("\nFAILURES:\n")
	for _, f in ipairs(failures) do io.write("  - " .. f .. "\n") end
	os.exit(1)
end
os.exit(0)
