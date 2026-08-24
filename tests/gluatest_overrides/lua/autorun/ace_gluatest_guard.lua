local canaryGroupName = "ACE GLuaTest discovery canary"
local canaryCaseName = "discovers and executes the native ACE suite"
local dslGroupName = "ACE interpreted core validation"

hook.Add("GLuaTest_Finished", "ACE_NativeSuiteGuard", function(testGroups, results)
	local caseCount = 0
	local canaryPassed = false
	local failures = {}
	local expectedCases = ACE_GLuaTestExpectedCases
	local observedCases = {}

	for _, group in ipairs(testGroups or {}) do
		caseCount = caseCount + #(group.cases or {})
		if group.groupName == canaryGroupName then
			for _, result in ipairs(results or {}) do
				if result.testGroup == group
					and result.case
					and result.case.name == canaryCaseName
					and result.success == true then
					canaryPassed = true
				end
			end
		end
	end

	for _, result in ipairs(results or {}) do
		local caseName = result.case and result.case.name
		if caseName and result.testGroup and result.testGroup.groupName == dslGroupName then
			local observed = observedCases[caseName] or {
				count = 0,
				passed = false,
			}

			observed.count = observed.count + 1
			observed.passed = observed.passed or result.success == true
			observedCases[caseName] = observed
		end
	end

	if caseCount == 0 or not canaryPassed then
		failures[#failures + 1] = {
			reason = "ACE native GLuaTest discovery guard did not observe the canary",
		}
	end

	if not istable(expectedCases) or not next(expectedCases) then
		failures[#failures + 1] = {
			reason = "ACE DSL suite did not declare any expected cases",
		}
	else
		for scenarioID, caseName in pairs(expectedCases) do
			local observed = observedCases[caseName]

			if not observed then
				failures[#failures + 1] = {
					reason = "ACE DSL case was not executed",
					scenario_id = scenarioID,
				}
			elseif observed.count ~= 1 then
				failures[#failures + 1] = {
					reason = "ACE DSL case executed more than once",
					scenario_id = scenarioID,
					observed_count = observed.count,
				}
			elseif not observed.passed then
				failures[#failures + 1] = {
					reason = "ACE DSL case did not pass",
					scenario_id = scenarioID,
				}
			end
		end
	end

	if #failures > 0 then
		file.Write("gluatest_failures.json", util.TableToJSON(failures))
	end
end)
