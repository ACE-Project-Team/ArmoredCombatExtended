local root = assert(arg[1], "usage: ace_gluatest_guard_luajit_selftest.lua <ACE repo>")
local finished
local writes

hook = {
	Add = function(_, _, callback)
		finished = callback
	end,
}

file = {
	Write = function(name, contents)
		writes[#writes + 1] = {
			name = name,
			contents = contents,
		}
	end,
}

util = {
	TableToJSON = function(value)
		return value
	end,
}

istable = function(value)
	return type(value) == "table"
end

dofile(root .. "/tests/gluatest_overrides/lua/autorun/ace_gluatest_guard.lua")
assert(type(finished) == "function", "native suite guard did not register its completion hook")

local canaryGroup = {
	groupName = "ACE GLuaTest discovery canary",
	cases = {
		{ name = "discovers and executes the native ACE suite" },
	},
}
local dslCase = { name = "[ace.test.example] Example DSL case" }
local dslGroup = {
	groupName = "ACE interpreted core validation",
	cases = { dslCase },
}
local groups = { canaryGroup, dslGroup }
local canaryResult = {
	testGroup = canaryGroup,
	case = canaryGroup.cases[1],
	success = true,
}

local function run(expectedCases, results)
	ACE_GLuaTestExpectedCases = expectedCases
	writes = {}
	finished(groups, results)
	return writes
end

local expected = {
	["ace.test.example"] = dslCase.name,
}

assert(#run(expected, {
	canaryResult,
	{ testGroup = dslGroup, case = dslCase, success = true },
}) == 0, "complete successful DSL execution should pass the guard")

assert(#run(nil, { canaryResult }) == 1, "missing generated expectations should fail")
assert(#run(expected, { canaryResult }) == 1, "missing DSL execution should fail")
assert(#run(expected, {
	canaryResult,
	{
		testGroup = { groupName = "Unrelated test group" },
		case = { name = dslCase.name },
		success = true,
	},
}) == 1, "an unrelated group cannot satisfy the DSL execution contract")
assert(#run(expected, {
	canaryResult,
	{ testGroup = dslGroup, case = dslCase, success = false },
}) == 1, "failed DSL execution should fail")
assert(#run(expected, {
	canaryResult,
	{ testGroup = dslGroup, case = dslCase, success = true },
	{ testGroup = dslGroup, case = dslCase, success = true },
}) == 1, "duplicate DSL execution should fail")

print("ACE GLuaTest guard self-test passed")
