local FACTORIES = {
	{ class = "acf_ammo", factory = "ACE_MakeAmmo" },
	{ class = "acf_engine", factory = "ACE_MakeEngine" },
	{ class = "acf_gearbox", factory = "ACE_MakeGearbox" },
	{ class = "acf_fueltank", factory = "ACE_MakeFuelTank" },
	{ class = "acf_gun", factory = "ACE_MakeGun" },
	{ class = "acf_rack", factory = "ACE_MakeRack" },
	{ class = "acf_explosive", factory = "ACE_MakeLegacyExplosive" },
	{ class = "ace_explosive", factory = "ACE_MakeExplosive" },
	{ class = "acf_missileradar", factory = "ACE_MakeMissileRadar" },
	{ class = "acf_missile_to_rack", factory = "ACE_MakeMissileToRack" },
}

local SPAWNABLE = {
	{ class = "acf_ammo", factory = "ACE_MakeAmmo" },
	{ class = "acf_engine", factory = "ACE_MakeEngine" },
	{ class = "acf_gearbox", factory = "ACE_MakeGearbox" },
	{ class = "acf_fueltank", factory = "ACE_MakeFuelTank" },
}

return {
	groupName = "ACE dupe registration and spawn smoke tests",
	cases = {
		{
			name = "registers namespace-backed duplicator factories",
			func = function()
				for _, spec in ipairs(FACTORIES) do
					local registered = duplicator.FindEntityClass(spec.class)
					expect(registered).to.exist()
					expect(registered.Func).to.equal(_G[spec.factory])
					expect(registered.Func).to.beA("function")
				end
			end
		},
		{
			name = "spawns representative dupe entity classes",
			func = function()
				for index, spec in ipairs(SPAWNABLE) do
					local ent = ents.Create(spec.class)
					expect(ent).to.exist()
					ent:SetPos(Vector(index * 16, 0, 64))
					ent:Spawn()
					expect(IsValid(ent)).to.equal(true)
					ent:Remove()
				end
			end
		},
		{
			name = "keeps pipeline-specific global factories available",
			func = function()
				for _, spec in ipairs(FACTORIES) do
					expect(_G[spec.factory]).to.beA("function")
				end
			end
		}
	}
}
