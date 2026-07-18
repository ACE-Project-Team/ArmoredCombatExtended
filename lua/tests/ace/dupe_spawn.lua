local FACTORIES = {
	{ class = "acf_ammo", factory = "MakeAmmo" },
	{ class = "acf_engine", factory = "MakeEngine" },
	{ class = "acf_gearbox", factory = "MakeGearbox" },
	{ class = "acf_fueltank", factory = "MakeFuelTank" },
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
					expect(registered.Func).to.equal(ACE[spec.factory])
					expect(registered.Func).to.beA("function")
				end
			end
		},
		{
			name = "spawns representative dupe entity classes",
			func = function()
				for index, spec in ipairs(FACTORIES) do
					local ent = ents.Create(spec.class)
					expect(ent).to.exist()
					ent:SetPos(Vector(index * 16, 0, 64))
					ent:Spawn()
					expect(IsValid(ent)).to.equal(true)
					ent:Remove()
				end
			end
		}
	}
}
