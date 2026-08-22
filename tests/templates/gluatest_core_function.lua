-- Place under lua/tests/ace/<area>/<function_name>.lua when this is a real native test.
-- Keep one focused function or small module per file.
local function returns(name, callback, expected)
    return {
        name = name,
        func = function(State)
            expect(callback(State)).to.equal(expected)
        end
    }
end

local function greaterThan(name, callback, expected)
	return {
		name = name,
		func = function(State)
			expect(callback(State)).to.beGreaterThan(expected)
		end
	}
end

local function lessThan(name, callback, expected)
	return {
		name = name,
		func = function(State)
			expect(callback(State)).to.beLessThan(expected)
		end
	}
end

local function changesWhen(name, before, after)
	return {
		name = name,
		func = function(State)
			local beforeValue = before(State)
			local afterValue = after(State)
			expect(afterValue).notTo.equal(beforeValue)
		end
	}
end

return {
    groupName = "ACE.<Area>.<Function>",

    beforeEach = function(State)
        -- Build only the fixture this function needs.
        State.Subject = MakeSmallTestFixture()
    end,

    afterEach = function(State)
        -- Remove hooks, stubs, entities, timers, and shared-table entries here.
        CleanupSmallTestFixture(State.Subject)
        if State.InvalidSubject then
            CleanupSmallTestFixture(State.InvalidSubject)
        end
    end,

	cases = {
		returns("returns the normal result", function(State)
			return ACE.Area.Function(State.Subject)
		end, ExpectedValue),
		greaterThan("returns a larger result for the stronger fixture", function(State)
			return ACE.Area.Function(State.StrongerSubject)
		end, ExpectedValue),
		lessThan("returns a smaller result for the weaker fixture", function(State)
			return ACE.Area.Function(State.WeakerSubject)
		end, ExpectedValue),
		changesWhen("responds when the input changes", function(State)
			return ACE.Area.Function(State.Subject)
		end, function(State)
			State.Subject.Input = ChangedInput
			return ACE.Area.Function(State.Subject)
		end),
		{
            name = "handles invalid input safely",
            func = function()
                expect(ACE.Area.Function(nil)).to.beFalse()
            end
        },
        {
            name = "does not call the side effect on early return",
            func = function(State)
                -- Arrange the condition that should make the function return early.
                State.InvalidSubject = MakeInvalidFixture()
                local SideEffect = stub(ACE.Area, "SideEffect")

                ACE.Area.Function(State.InvalidSubject)

                expect(SideEffect).wasNot.called()
            end
        }
    }
}
