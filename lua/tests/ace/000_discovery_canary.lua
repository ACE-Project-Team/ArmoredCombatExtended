return {
	groupName = "ACE GLuaTest discovery canary",
	cases = {
		{
			name = "discovers and executes the native ACE suite",
			func = function()
				expect(true).to.equal(true)
			end,
		},
	},
}
