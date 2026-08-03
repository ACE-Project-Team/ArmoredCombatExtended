local function countEntries(registry, expectValue)
	local count = 0
	for id, entry in pairs(registry) do
		expectValue(type(id)).to.equal("string")
		expectValue(type(entry)).to.equal("table")
		expectValue(entry.id).to.equal(id)
		count = count + 1
	end

	expectValue(count).to.beGreaterThan(0)
	return count
end

return {
	groupName = "ACE and ACF runtime registries",
	cases = {
		{
			name = "exposes every loader category",
			func = function()
				expect(ACF).to.exist()
				expect(ACE.Weapons).to.exist()
				expect(ACE.Classes).to.exist()
				expect(ACE).to.exist()

				for _, name in ipairs({
					"Ammo", "LegacyAmmo", "Guns", "Racks", "Engines", "Gearboxes",
					"FuelTanks", "FuelTanksSize", "Radars", "Tools", "Crewseats",
					"Extras", "Explosives", "Mobility",
				}) do
					expect(ACE.Weapons[name]).to.exist()
					countEntries(ACE.Weapons[name], expect)
				end

				for _, name in ipairs({ "GunClass", "Rack", "Radar" }) do
					expect(ACE.Classes[name]).to.exist()
					countEntries(ACE.Classes[name], expect)
				end
			end,
		},
		{
			name = "preserves the required shape of core definitions",
			func = function()
				for id, gun in pairs(ACE.Weapons.Guns) do
					expect(gun.round).to.exist()
					expect(gun.gunclass).to.exist()
					expect(gun.caliber).to.beA("number")
					expect(gun.caliber).to.beGreaterThan(0)
					expect(id).to.equal(gun.id)
				end

				for id, engine in pairs(ACE.Weapons.Engines) do
					expect(engine.torque).to.beA("number")
					expect(engine.limitrpm).to.beA("number")
					expect(engine.limitrpm).to.beGreaterThan(engine.idlerpm)
					expect(id).to.equal(engine.id)
				end

				for id, gearbox in pairs(ACE.Weapons.Gearboxes) do
					expect(gearbox.gears).to.beA("number")
					expect(gearbox.geartable).to.beA("table")
					expect(id).to.equal(gearbox.id)
				end
			end,
		},
		{
			name = "publishes ACE extension registries",
			func = function()
				expect(ACE.MuzzleFlashes).to.exist()
				expect(ACE.ModelData).to.exist()
				expect(ACE.MineData).to.exist()
				expect(ACE.GSounds).to.exist()
				expect(ACE.GSounds.GunFire).to.exist()
				countEntries(ACE.MineData, expect)
			end,
		},
		{
			name = "loads the CFW ACE extension methods",
			func = function()
				expect(CFW).to.exist()
				expect(CFW.Classes).to.exist()
				expect(CFW.Classes.Contraption).to.exist()
				for _, name in ipairs({
					"GetACEBaseplate", "GetACEAltitude", "GetACEHottestEntity",
					"GetACEHotEnts", "GetACEHeatPosition",
				}) do
					expect(CFW.Classes.Contraption[name]).to.beA("function")
				end
			end,
		},
		{
			name = "keeps round type and network ID registries coherent",
			func = function()
				expect(ACE.RoundTypes).to.exist()
				expect(ACE.IdRounds).to.exist()
				local count = 0

				for roundType, round in pairs(ACE.RoundTypes) do
					expect(type(roundType)).to.equal("string")
					expect(type(round)).to.equal("table")
					expect(round.Type).to.equal(roundType)
					if round.netid then
						expect(round.create).to.beA("function")
					end
					if round.netid then
						expect(ACE.IdRounds[round.netid]).to.beA("string")
					end
					count = count + 1
				end

				expect(count).to.beGreaterThan(0)
			end,
		},
	},
}
