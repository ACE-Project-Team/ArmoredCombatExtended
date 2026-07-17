local canaryGroupName = "ACE GLuaTest discovery canary"
local canaryCaseName = "discovers and executes the native ACE suite"

hook.Add("GLuaTest_Finished", "ACE_NativeSuiteGuard", function(testGroups, results)
	local caseCount = 0
	local canaryPassed = false

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

	if caseCount == 0 or not canaryPassed then
		file.Write("gluatest_failures.json", util.TableToJSON({ {
			reason = "ACE native GLuaTest discovery guard did not observe the canary",
		} }))
	end
end)
