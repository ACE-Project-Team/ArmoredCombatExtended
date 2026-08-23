local FACTORIES = {
	{ class = "acf_ammo", factory = "ACE.MakeAmmo" },
	{ class = "acf_engine", factory = "ACE.MakeEngine" },
	{ class = "acf_gearbox", factory = "ACE.MakeGearbox" },
	{ class = "acf_fueltank", factory = "ACE.MakeFuelTank" },
	{ class = "acf_gun", factory = "ACE.MakeGun" },
	{ class = "acf_rack", factory = "ACE.MakeRack" },
	{ class = "acf_explosive", factory = "ACE.MakeLegacyExplosive" },
	{ class = "ace_explosive", factory = "ACE.MakeExplosive" },
	{ class = "acf_missileradar", factory = "ACE.MakeMissileRadar" },
	{ class = "acf_missile_to_rack", factory = "ACE.MakeMissileToRack" },
}

local function resolve(path)
	local value = _G
	for part in string.gmatch(path, "[^%.]+") do value = value[part] end
	return value
end

local SPAWNABLE = {
	{ class = "acf_ammo", factory = "ACE.MakeAmmo", args = { "Shell75mm" } },
	{ class = "acf_engine", factory = "ACE.MakeEngine", args = { "3.2-B4" } },
	{ class = "acf_gearbox", factory = "ACE.MakeGearbox", args = { "1Gear-T-S", 0.1, 0.2, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8, 0.9, 0.5 } },
	{ class = "acf_fueltank", factory = "ACE.MakeFuelTank", args = { "Tank_4x4x2", "Tank_4x4x2", "Petrol", "Box" } },
}

local function makeTestOwner()
	local entityMeta = FindMetaTable("Entity")
	-- Headless-only compatibility shims: native tests have no player/CPPI addon.
	if entityMeta and not entityMeta.CPPISetOwner then
		entityMeta.CPPISetOwner = function(self, owner) self._TestCPPIOwner = owner end
	end
	if entityMeta and not entityMeta.UniqueID then
		entityMeta.UniqueID = function(self) return "ACE_HEADLESS_" .. self:EntIndex() end
	end
	local owner = ents.Create("prop_physics")
	owner:SetModel("models/props_c17/oildrum001.mdl")
	owner:SetPos(Vector(0, 0, 64))
	owner:Spawn()
	owner.CheckLimit = function() return true end
	owner.AddCount = function() end
	owner.AddCleanup = function() end
	return owner
end

return {
	groupName = "ACE dupe registration and spawn smoke tests",
	cases = {
		{
			name = "registers namespace-backed duplicator factories",
			func = function()
				for _, spec in ipairs(FACTORIES) do
					local registered = duplicator.FindEntityClass(spec.class)
					expect(registered).to.exist()
					expect(registered.Func).to.equal(resolve(spec.factory))
					expect(registered.Func).to.beA("function")
				end
			end
		},
		{
			name = "spawns representative dupe entity classes",
			func = function()
				local owner = makeTestOwner()
				for index, spec in ipairs(SPAWNABLE) do
					local factory = _G
					for part in string.gmatch(spec.factory, "[^%.]+") do factory = factory[part] end
					local ent = factory(owner, Vector(index * 16, 0, 64), Angle(0, 0, 0), unpack(spec.args))
					expect(IsValid(ent)).to.equal(true)
					if IsValid(ent) then ent:Remove() end
				end
				owner:Remove()
			end
		},
		{
			name = "keeps pipeline-specific global factories available",
			func = function()
				for _, spec in ipairs(FACTORIES) do
					expect(resolve(spec.factory)).to.beA("function")
				end
			end
		}
	}
}
