return {
	groupName = "ACE and ACF scripted entity registration",
	cases = {
		{
			name = "registers every mounted ACE and ACF entity",
			func = function()
				local _, folders = file.Find("entities/*", "LUA")
				local checked = 0

				for _, className in ipairs(folders) do
					if className:match("^ace_") or className:match("^acf_") then
						local stored = scripted_ents.GetStored(className)
						expect(stored).to.exist()
						expect(stored.t).to.exist()
						checked = checked + 1
					end
				end

				expect(checked).to.beGreaterThan(0)
			end,
		},
	},
}
