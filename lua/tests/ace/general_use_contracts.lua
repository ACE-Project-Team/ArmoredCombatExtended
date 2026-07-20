local function assertRegistryEntries(registry, names)
	for _, name in ipairs(names) do
		expect(registry[name]).to.exist()
	end
end

return {
	groupName = "ACE general-use contract coverage",
	cases = {
		{
			name = "covers player-facing round families",
			func = function()
				assertRegistryEntries(ACF.RoundTypes, {
					"AP", "APFSDS", "HE", "HEAT", "HESH", "THEAT",
				})

				for _, roundType in ipairs({ "AP", "APFSDS", "HE", "HEAT", "HESH", "THEAT" }) do
					local round = ACF.RoundTypes[roundType]
					expect(round.name).to.exist()
					expect(round.desc).to.exist()
					if round.netid then
						expect(round.create).to.beA("function")
						expect(ACF.IdRounds[round.netid]).to.equal(roundType)
					end
				end
			end,
		},
		{
			name = "covers armor materials used by layered vehicle builds",
			func = function()
				assertRegistryEntries(ACE.ArmorTypes, {
					"RHA", "DU", "Rub", "Texto", "Cer", "Alum",
				})

				for _, materialId in ipairs({ "RHA", "DU", "Rub", "Texto", "Cer", "Alum" }) do
					local material = ACE.ArmorTypes[materialId]
					expect(material.name).to.exist()
					expect(material.massMod).to.beA("number")
					expect(material.ArmorResolution).to.beA("function")
				end
			end,
		},
		{
			name = "covers propulsion fuel crew weapons racks sensors and missiles",
			func = function()
				for _, registryName in ipairs({
					"Engines", "FuelTanks", "Crewseats", "Guns", "Racks", "Radars",
				}) do
					expect(ACF.Weapons[registryName]).to.exist()

					local count = 0
					for _ in pairs(ACF.Weapons[registryName]) do
						count = count + 1
					end

					expect(count).to.beGreaterThan(0)
				end
			end,
		},
		{
			name = "keeps scripted entity families registered for lifecycle scenarios",
			func = function()
				for _, className in ipairs({
					"acf_gun", "acf_ammo", "acf_rack", "acf_engine", "acf_fueltank",
					"ace_crewseat_driver", "ace_searchradar", "ace_missile",
				}) do
					local stored = scripted_ents.GetStored(className)
					expect(stored).to.exist()
					expect(stored.t).to.exist()
				end
			end,
		},
	},
}
