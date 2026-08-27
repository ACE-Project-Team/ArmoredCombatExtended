local root = assert(arg[1], "usage: ace_test_dsl_runtime_selftest.lua <ACE repo root>")
root = root:gsub("\\\\", "/"):gsub("/$", "")

ACE = {
	Activate = function() end,
	Identity = function(Value) return Value end,
	Legal = {},
}

function istable(Value) return type(Value) == "table" end
function isfunction(Value) return type(Value) == "function" end
table.Copy = function(Value) return Value end

local Runtime = dofile(root .. "/lua/ace/test_dsl_runtime.lua")
local Spec = {
	scenarioId = "ace.selftest.diagnostic",
	fixturesRegistry = {
		actual = { kind = "value", value = 1 },
	},
	fixtures = {
		{ fixture = "actual", alias = "Actual" },
	},
	actions = {
		{ action = "ACE.Identity", args = { "Actual" }, result = "Result" },
	},
	expects = {
		{ subject = "Result", operator = "is", value = "10" },
	},
}

local function expect(Actual)
	return {
		to = {
			equal = function(Expected)
				if Actual ~= Expected then
					error("lua/gluatest/expectations/positive.lua:12: Expected " .. tostring(Actual) .. " to equal " .. tostring(Expected), 0)
				end
			end,
			exist = function()
				if Actual == nil then
					error("lua/gluatest/expectations/positive.lua:12: Expected nil to exist", 0)
				end
			end,
		},
	}
end

local Ok, Message = pcall(Runtime.Run, {}, Spec, expect)
assert(not Ok, "the deliberately wrong expectation must fail")
assert(Message:match("test_dsl_runtime.lua:%d+: ACE DSL scenario"), Message)
assert(Message:find("ACE DSL scenario ace.selftest.diagnostic expectation 1 failed", 1, true), Message)
assert(Message:find("expect Result is 10 (actual 1)", 1, true), Message)
assert(Message:find("Expected 1 to equal 10", 1, true), Message)

local ExistsSpec = {
	scenarioId = "ace.selftest.valueless_diagnostic",
	fixturesRegistry = {
		missing = { kind = "value", invalid = true },
	},
	fixtures = {
		{ fixture = "missing", alias = "Missing" },
	},
	actions = {},
	expects = {
		{ subject = "Missing", operator = "exists" },
	},
}

Ok, Message = pcall(Runtime.Run, {}, ExistsSpec, expect)
assert(not Ok, "the deliberately missing value must fail")
assert(Message:match("test_dsl_runtime.lua:%d+: ACE DSL scenario"), Message)
assert(Message:find("ACE DSL scenario ace.selftest.valueless_diagnostic expectation 1 failed", 1, true), Message)
assert(Message:find("expect Missing exists (actual nil)", 1, true), Message)
assert(Message:find("Expected nil to exist", 1, true), Message)

print("ace_test_dsl_runtime_selftest: ok")
