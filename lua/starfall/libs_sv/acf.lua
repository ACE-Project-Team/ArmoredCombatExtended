--- Library for interfacing with ACF entities
-- @name acf
-- @class library
-- @libtbl acf_library
-- @src https://github.com/ACE-Project-Team/ArmoredCombatExtended/tree/master/lua/starfall/lib_sv/acf.lua
SF.RegisterLibrary("acf")

local min, clamp, abs, round, floor = math.min, math.Clamp, math.abs, math.Round, math.floor
local rad, cos = math.rad, math.cos

local checkluatype = SF.CheckLuaType
local checkpermission = SF.Permissions.check
local hasaccess = SF.Permissions.hasAccess
local registerprivilege = SF.Permissions.registerPrivilege

registerprivilege("acf.createMobility", "Create acf engine", "Allows the user to create ACF engines and gearboxes", { usergroups = { default = 3 } })
registerprivilege("acf.createFuelTank", "Create acf fuel tank", "Allows the user to create ACF fuel tanks", { usergroups = { default = 3 } })
registerprivilege("acf.createGun", "Create acf gun", "Allows the user to create ACF guns", { usergroups = { default = 3 } })
registerprivilege("acf.createAmmo", "Create acf ammo", "Allows the user to create ACF ammoboxes", { usergroups = { default = 3 } } )
registerprivilege("acf.trackBullets", "Track ACF bullets", "Allows the user to track ACF bullets and the damage they deal to entities", { usergroups = { default = 1 } } )
registerprivilege("entities.acf", "ACF", "Allows the user to control ACF components", { entities = {} })

local function isEngine(ent)
	return ent:GetClass() == "acf_engine"
end

local function isGearbox(ent)
	return ent:GetClass() == "acf_gearbox"
end

local function isGun(ent)
	return ent:GetClass() == "acf_gun"
end

local function isAmmo(ent)
	return ent:GetClass() == "acf_ammo"
end

local function isFuel(ent)
	return ent:GetClass() == "acf_fueltank"
end


--Ripped from Armor Property Tool
-- Calculates mass, armor, and health given prop area and desired ductility and thickness.
local function CalcArmor( Area, Ductility, Thickness, Mat )

	Mat = Mat or "RHA"

	local MatData	= ACE_GetMaterialData( Mat )
	local MassMod	= MatData.massMod

	local mass		= Area * ( 1 + Ductility ) ^ 0.5 * Thickness * 0.00078 * MassMod
	local armor		= ACF_CalcArmor( Area, Ductility, mass / MassMod )
	local health		= ( Area + Area * Ductility ) / ACF.Threshold

	return mass, armor, health

end

local function E2SetACEArmor(ent, armor, ductility, material)

	ent.ACF = ent.ACF or {}

	local duct = math.Clamp( ductility or (ent.ACF.Ductility * 100) or 80, -80, 80 )
	local thickness = math.Clamp( armor or ent.ACF.Armour or 1, 0.1, 50000 )
	local mat  = material or ent.ACF.Material or "RHA"

	local mass		= CalcArmor( ent.ACF.Area, duct / 100, thickness , mat)

	local phys = ent:GetPhysicsObject()
	if IsValid( phys ) then phys:SetMass( mass ) end
	duplicator.StoreEntityModifier( ent, "mass", { Mass = mass } )

	ent.ACF.Ductility = duct / 100
	duplicator.StoreEntityModifier( ent, "acfsettings", { Ductility = duct } )

	local con = ent:GetContraption()
	if con then ACE_RemPts(con, ent) end --Stupid roundabout fix. But only executed when the mat is changed. Hey if it works.

	ent.ACF.Material = mat
	duplicator.StoreEntityModifier( ent, "acfsettings", { Material = mat } )

	if con then ACE_AddPts(con, ent) end

end

local radarTypes = {
	acf_missileradar = true,
	ace_irst = true,
	ace_trackingradar = true,
}

local function isRadar(ent)
	return radarTypes[ent:GetClass()] or false
end

-- link resources within each ent type. should point to an ent: true if adding link.Ent, false to add link itself
local linkTables = {
	acf_engine		= { GearLink = true, FuelLink = false },
	acf_gearbox		= { WheelLink = true, Master = false },
	acf_fueltank	= { Master = false },
	acf_gun			= { AmmoLink = false },
	acf_ammo		= { Master = false }
}

local function getLinks(ent, enttype)
	local ret = {}
	-- find the link resources available for this ent type
	for entry, mode in pairs(linkTables[enttype]) do
		if not ent[entry] then
			SF.Throw("[Internal ACE Error] Couldn't find link resource " .. entry .. " for entity " .. tostring(ent), 2)

			return
		end

		-- find all the links inside the resources
		for _, link in pairs(ent[entry]) do
			ret[#ret + 1] = mode and link.Ent or link
		end
	end

	return ret
end

local function searchForGearboxLinks(ent)
	local boxes = ents.FindByClass("acf_gearbox")
	local ret = {}
	for _, box in ipairs(boxes) do
		if IsValid(box) then
			for _, link in pairs(box.WheelLink) do
				if link.Ent == ent then
					ret[#ret + 1] = box

					break
				end
			end
		end
	end

	return ret
end


return function(instance)


local checktype = instance.CheckType
local acf_library = instance.Libraries.acf
local ents_methods = instance.Types.Entity.Methods
local vec_meta, vwrap, vunwrap = instance.Types.Vector, instance.Types.Vector.Wrap, instance.Types.Vector.Unwrap
local sanitize = instance.Sanitize
local getent = instance.Types.Entity.GetEntity

local function restrictInfo(ent)
	if GetConVar("acf_restrictinfo"):GetInt() ~= 0 then
		return ent:CPPIGetOwner() ~= instance.player
	end

	return false
end

local idNameCache = {}
local function listIDFromName(list, name)
	idNameCache[list] = idNameCache[list] or {}

	if idNameCache[list][name] then return idNameCache[list][name] end

	for id, data in pairs(list) do
		if data.name == name then
			idNameCache[list][name] = id

			return id
		end
	end
end

instance:AddHook("deinitialize", function()
end)

-- Utility functions
do
	--- Returns current ACF drag divisor
	-- @server
	-- @return number The current drag divisor
	function acf_library.dragDivisor()
		return ACF.DragDiv
	end

	--- Returns true if functions returning sensitive info are restricted to owned props
	-- @server
	-- @return boolean True if restriced, False if not
	function acf_library.infoRestricted()
		return GetConVar("acf_restrictinfo"):GetInt() ~= 0
	end

	--- Returns latest version of ACF
	-- @server
	-- @return number Version number
	function acf_library.getVersion()
		return ACF.CurrentVersion
	end

	--- Returns server version of acf
	-- @server
	-- @return number Version number
	function acf_library.getCurrentVersion()
		return ACF.Version
	end

	--- Returns velocity loss for every meter traveled. 0.2x means HEAT loses 20% of its energy every 2m traveled. 1m is about typical for the sideskirt spaced armor of most tanks.
	-- @server
	-- @return number Air gap factor
	function acf_library.getHEATAirGapFactor()
		return ACF.HEATAirGapFactor
	end

	--- Returns ACF wind direction
	-- @server
	-- @return vector Wind direction
	function acf_library.getWindVector()
		return vwrap(ACF.Wind)
	end

	--- Returns true if this entity contains sensitive info and is not accessable to us
	-- @server
	-- @return boolean Is the info restricted?
	function ents_methods:acfIsInfoRestricted()
		return restrictInfo(getent(self))
	end

	--- Returns the short name of an ACF entity
	-- @server
	-- @return string The short name
	function ents_methods:acfNameShort()
		local this = getent(self)

		if isEngine(this) then return this.Id or "" end
		if isGearbox(this) then return this.Id or "" end
		if isGun(this) then return this.Id or "" end
		if isAmmo(this) then return this.RoundId or "" end
		if isFuel(this) then return this.FuelType .. " " .. this.SizeId end

		return ""
	end

	--- Returns the maximum capacity of an acf ammo crate or fuel tank
	-- @server
	-- @return number The capacity
	function ents_methods:acfCapacity()
		local this = getent(self)

		if not (isAmmo(this) or isFuel(this)) then return 0 end
		if restrictInfo(this) then return 0 end

		return this.Capacity or 1
	end

	--- Returns true if the acf engine, fuel tank, or ammo crate is active
	-- @server
	-- @return boolean Is the entity active?
	function ents_methods:acfGetActive()
		local this = getent(self)

		if not (isEngine(this) or isAmmo(this) or isFuel(this)) then return false end
		if restrictInfo(this) then return false end
		if not isAmmo(this) then
			if this.Active then return true end
		else
			if this.Load then return true end
		end

		return false
	end

	--- Turns an ACF engine, ammo crate, or fuel tank on or off
	-- @server
	-- @param boolean state The state to set the entity to
	function ents_methods:acfSetActive(on)
		local this = getent(self)

		checkpermission(instance, this, "entities.acf")

		if not (isEngine(this) or isAmmo(this) or isFuel(this)) then return end

		this:TriggerInput("Active", on and 1 or 0)
	end

	--- Returns true if hitpos is on a clipped part of prop
	-- @server
	-- @param Vector hitpos The hit position
	-- @return boolean Is the hit position on a clipped part of the prop?
	function ents_methods:acfHitClip(hitpos)
		checktype(hitpos, vec_meta)

		local this = getent(self)
		hitpos = vunwrap(hitpos)

		checkpermission(instance, this, "entities.acf")
		if ACF_CheckClips(nil, nil, this, hitpos) then
			return true
		else
			return false
		end
	end

	--- Returns the ACF links associated with the entity
	-- @server
	-- @return table The links
	function ents_methods:acfLinks()
		local this = getent(self)

		local enttype = this:GetClass()
		if not linkTables[enttype] then return sanitize(searchForGearboxLinks(this)) end

		return sanitize(getLinks(this, enttype))
	end

	--- Returns the full name of an ACF entity
	-- @server
	-- @return string The full name
	function ents_methods:acfName()
		local this = getent(self)

		if isAmmo(this) then return this.RoundId .. " " .. this.RoundType end
		if isFuel(this) then return this.FuelType .. " " .. this.SizeId end

		local acftype = ""

		if isEngine(this) then acftype = "Mobility" end
		if isGearbox(this) then acftype = "Mobility" end
		if isGun(this) then acftype = "Guns" end

		if acftype == "" then return "" end
		local List = ACF.Weapons

		return List[acftype][this.Id].name or ""
	end

	--- Returns the type of ACF entity
	-- @server
	-- @return string The type
	function ents_methods:acfType()
		local this = getent(self)

		if isEngine(this) or isGearbox(this) then
			return ACF.Weapons["Mobility"][this.Id].category or ""
		end

		if isGun(this) then
			return ACF.Classes["GunClass"][this.Class].name or ""
		end

		if isAmmo(this) then return this.RoundType or "" end
		if isFuel(this) then return this.FuelType or "" end

		return ""
	end

	--- Perform ACF links
	-- @server
	-- @param Entity target The entity to link to
	-- @param boolean notify Whether to notify the player of the link's creation
	-- @return boolean Whether the link was successful
	-- @return string Status message regarding the link's creation
	function ents_methods:acfLinkTo(target, notify)
		local this = getent(self)
		local tar = getent(target)

		checkpermission(instance, this, "entities.acf")
		checkpermission(instance, tar, "entities.acf")
		if not (isGun(this) or isEngine(this) or isGearbox(this)) then
			SF.Throw("Target must be a gun, engine, or gearbox", 2)
		end

		local success, msg = this:Link(tar)
		if notify then
			ACF_SendNotify(instance.player, success, msg)
		end

		return success, msg
	end

	--- Perform ACF unlinks
	-- @server
	-- @param Entity target The entity to unlink from
	-- @param boolean notify Whether to notify the player of the link's removal
	-- @return boolean Whether the unlink was successful
	-- @return string Status message regarding the link's removal
	function ents_methods:acfUnlinkFrom(target, notify)
		local this = getent(self)
		local tar = getent(target)

		checkpermission(instance, this, "entities.acf")
		checkpermission(instance, tar, "entities.acf")
		if not (isGun(this) or isEngine(this) or isGearbox(this)) then
			SF.Throw("Target must be a gun, engine, or gearbox", 2)
		end

		local success, msg = this:Unlink(tar)
		if notify then
			ACF_SendNotify(instance.player, success, msg)
		end

		return success, msg
	end

	--- Returns the heat of an ACF entity
	-- @server
	-- @return number The heat value of the entity
	function ents_methods:acfHeat()
		checktype(self, ents_metatable)
		local this = getent(self)

		if restrictInfo(this) then return 0 end

		local Heat
		if isGun(this) then
			Heat = ACE_HeatFromGun(this, this.Heat, this.DeltaTime)
		elseif isEngine(this) then
			Heat = ACE_HeatFromEngine(this)
		else
			Heat = ACE.AmbientTemp
		end

		return Heat
	end

	--- Returns all crewseats linked to an acf entity
	-- @server
	-- @return table crewseats entities
	function ents_methods:acfGetCrew()
		checktype(self, ents_metatable)
		local this = getent(self)

		if restrictInfo(this) then return {} end
		local Crew = {}
		for _, v in ipairs(this.CrewLink) do
			if IsValid(v) then
				Crew[#Crew + 1] = v
			end
		end

		return sanitize(Crew)
	end
end

-- Spawning functions
--do
--end

-- Armor functions
do
	--- Returns the effective armor given an armor value and hit angle
	-- @param number armor The nominal armor value
	-- @param number hit The hit angle
	-- @server
	-- @return number The effective armor
	function acf_library.effectiveArmor(armor, angle)
		checkluatype(armor, TYPE_NUMBER)
		checkluatype(angle, TYPE_NUMBER)

		return round(armor / abs(cos(rad(min(angle, 89.999)))), 1)
	end

	--- Returns the current health of an entity
	-- @server
	-- @return number The current health
	function ents_methods:acfPropHealth()
		local this = getent(self)

		if not validPhysics(this) then return 0 end
		if restrictInfo(this) then return 0 end
		if not ACF_Check(this) then return 0 end

		return round(this.ACF.Health, 3)
	end

	--- Returns the current armor of an entity
	-- @server
	-- @return number The current armor
	function ents_methods:acfPropArmor()
		local this = getent(self)

		if not validPhysics(this) then return 0 end
		if restrictInfo(this) then return 0 end
		if not ACF_Check(this) then return 0 end

		return round(this.ACF.Armour, 3)
	end

	--- Returns the max health of an entity
	-- @server
	-- @return number The max health
	function ents_methods:acfPropHealthMax()
		local this = getent(self)

		if not validPhysics(this) then return 0 end
		if restrictInfo(this) then return 0 end
		if not ACF_Check(this) then return 0 end

		return round(this.ACF.MaxHealth, 3)
	end

	--- Returns the max armor of an entity
	-- @server
	-- @return number The max armor
	function ents_methods:acfPropArmorMax()
		local this = getent(self)

		if not validPhysics(this) then return 0 end
		if restrictInfo(this) then return 0 end
		if not ACF_Check(this) then return 0 end

		return round(this.ACF.MaxArmour, 3)
	end

	--- Returns the ductility of an entity
	-- @server
	-- @return number The ductility
	function ents_methods:acfPropDuctility()
		local this = getent(self)

		if not validPhysics(this) then return 0 end
		if restrictInfo(this) then return 0 end
		if not ACF_Check(this) then return 0 end

		return this.ACF.Ductility * 100
	end

	--- Returns the armor data of an entity
	-- @server
	-- @return table A table with keys: Curve, Effectiveness, HEATEffectiveness, Material
	function ents_methods:acfPropArmorData()
		local this = getent(self)
		local empty = {}

		if not validPhysics(this) then return empty end
		if restrictInfo(this) then return empty end
		if not ACF_Check(this) then return empty end

		local mat = this.ACF.Material
		if not mat then return empty end

		local matData = ACE.ArmorTypes[mat]
		if not matData then return empty end

		return {
			Curve = matData.curve,
			Effectiveness = matData.effectiveness,
			HEATEffectiveness = matData.HEATeffectiveness or matData.effectiveness,
			Material = mat
		}
	end

	function ents_methods:aceSetArmorProperties(thickness, ductility, material)
		checkluatype(thickness, TYPE_NUMBER)
		checkluatype(ductility, TYPE_NUMBER)
		checkluatype(material, TYPE_STRING)

		local this = getent(self)

		if not validPhysics(this) then return end
		if restrictInfo(this) then return end
		if not ACF_Check(this) then return end

		local matData = ACE.ArmorTypes[material]
		if not matData then return end

		E2SetACEArmor(this, thickness, ductility, material)

	end

	--- This gets called every time an entity takes damage with ACF.
	--- Needs acf.trackBullets privilege to work.
	-- @name ACFOnDamage
	-- @class hook
	-- @param Entity entity The entity that took damage
	-- @param table energy The energy of the projectile that hit the entity
	-- @param number surface The surface area of the projectile that hit the entity
	-- @param number angle The angle of the projectile that hit the entity
	-- @param Entity inflictor The entity that caused the damage
	-- @param number bone The bone that was hit
	-- @param Entity gun The gun that fired the projectile
	-- @param string type The type of the projectile that hit the entity
	-- @param table hitRes The hit resolution table
	-- @param table dmgInfo The damage info table, containing health and armor changes, if available
	-- @server
	SF.hookAdd("ACFOnDamage", nil, function(_, entity, energy, surface, angle, inflictor, bone, gun, type, hitRes, oldACFTbl)
		if not hasaccess(instance, nil, "acf.trackBullets") then return false end

		local dmgInfo = {}
		if oldACFTbl and entity.ACF then
			dmgInfo = {
				health = (entity.ACF.Health or 0) - (oldACFTbl.Health or 0),
				armour = (entity.ACF.Armour or 0) - (oldACFTbl.Armour or 0),
			}
		end
		return true,
		{
			entity,
			sanitize(energy or {}),
			surface,
			angle,
			inflictor,
			bone,
			gun,
			type,
			sanitize(hitRes or {}),
			sanitize(dmgInfo)
		}
	end)
end

-- Weapon functions
do
	--- Returns the specs of a specified gun
	-- @param string id id or name of the gun
	-- @server
	-- @return table The specs table
	function acf_library.getGunSpecs(id)
		checkluatype(id, TYPE_STRING)

		local listEntries = ACF.Weapons.Guns

		-- Not a valid id, try name
		if not listEntries[id] then
			id = listIDFromName(listEntries, id)

			-- Name is also invalid, error
			if not id or not listEntries[id] then
				SF.Throw("Invalid id or name", 2)
			end
		end

		local specs = table.Copy(listEntries[id])
		specs.BaseClass = nil

		return sanitize(specs)
	end

	--- Returns a list of all guns
	-- @server
	-- @return table The guns list
	function acf_library.getAllGuns()
		local tbl = {}

		for id, _ in pairs(ACF.Weapons.Guns) do
			tbl[#tbl + 1] = id
		end

		return tbl
	end

	--- Returns true if the entity is an ACF gun
	-- @server
	-- @return boolean True if the entity is an ACF gun
	function ents_methods:acfIsGun()
		return isGun(getent(self))
	end

	--- Returns true if the ACF gun is ready to fire
	-- @server
	-- @return boolean True if the ACF gun is ready to fire
	function ents_methods:acfReady()
		local this = getent(self)

		if not isGun(this) then return false end
		if restrictInfo(this) then return false end

		return this.Ready
	end

	--- Returns the magazine size for an ACF gun
	-- @server
	-- @return number The magazine size
	function ents_methods:acfMagSize()
		local this = getent(self)

		if not isGun(this) then return 0 end
		if restrictInfo(this) then return 0 end

		return this.MagSize
	end

	--- Returns the spread for an ACF gun or flechette ammo
	-- @server
	-- @return number The spread, in degrees
	function ents_methods:acfSpread()
		local this = getent(self)

		if not isGun(this) or isAmmo(this) then return 0 end
		local Spread = this.GetInaccuracy and this:GetInaccuracy() or this.Inaccuracy or 0
		if this.BulletData["Type"] == "FL" then
			if restrictInfo(this) then return Spread end

			return Spread + (this.BulletData["FlechetteSpread"] or 0)
		end

		return Spread
	end

	--- Returns true if an ACF gun is reloading
	-- @server
	-- @return boolean True if the ACF gun is reloading
	function ents_methods:acfIsReloading()
		local this = getent(self)

		if not isGun(this) then return false end
		if restrictInfo(this) then return false end

		return this.Reloading or false
	end

	--- Returns the rate of fire of an acf gun
	-- @server
	-- @return number The rate of fire
	function ents_methods:acfFireRate()
		local this = getent(self)

		if not isGun(this) then return 0 end
		if restrictInfo(this) then return 0 end

		return math.Round(this.RateOfFire, 3)
	end

	--- Returns the number of rounds left in a magazine for an ACF gun
	-- @server
	-- @return number The number of rounds left in the magazine
	function ents_methods:acfMagRounds()
		local this = getent(self)

		if not isGun(this) then return 0 end
		if restrictInfo(this) then return 0 end

		if this.MagSize > 1 then return (this.MagSize - this.CurrentShot) or 1 end
		if this.Ready and this.BulletData.Type ~= "Empty" then return 1 end

		return 0
	end

	--- Sets the firing state of an ACF weapon
	-- @server
	-- @param number state 1 to fire, 0 to stop firing
	function ents_methods:acfFire(fire)
		checkluatype(fire, TYPE_NUMBER)
		local this = getent(self)

		checkpermission(instance, this, "entities.acf")
		if not isGun(this) then return end

		this:TriggerInput("Fire", fire)
	end

	--- Sets the ROF limit of an ACF weapon
	-- @server
	-- @param number rate The rate of fire limit
	function ents_methods:acfSetROFLimit(rate)
		checkluatype(rate, TYPE_NUMBER)
		local this = getent(self)

		checkpermission(instance, this, "entities.acf")
		if not isGun(this) then return end

		this:TriggerInput("ROFLimit", rate)
	end

	--- Causes an ACF weapon to unload
	-- @server
	function ents_methods:acfUnload()
		local this = getent(self)

		checkpermission(instance, this, "entities.acf")
		if not isGun(this) then return end

		this:UnloadAmmo()
	end

	--- Causes an ACF weapon to reload
	-- @server
	function ents_methods:acfReload()
		local this = getent(self)

		checkpermission(instance, this, "entities.acf")
		if not isGun(this) then return end
		local isEmpty = this.BulletData.Type == "Empty"

		if isEmpty and not this.Reloading then
			this:LoadAmmo(false, true)
			this.Reloading = true
		end
	end

	--- Returns the number of rounds in active ammo crates linked to an ACF weapon
	-- @server
	-- @return number The number of rounds in active ammo crates
	function ents_methods:acfAmmoCount()
		local this = getent(self)

		if not isGun(this) then return 0 end
		if restrictInfo(this) then return 0 end

		local Ammo = 0
		for _, AmmoEnt in pairs(this.AmmoLink) do
			if AmmoEnt and AmmoEnt:IsValid() and AmmoEnt["Load"] then
				Ammo = Ammo + (AmmoEnt.Ammo or 0)
			end
		end

		return Ammo
	end

	--- Returns the number of rounds in all ammo crates linked to an ACF weapon
	-- @server
	-- @return number The number of rounds in all ammo crates
	function ents_methods:acfTotalAmmoCount()
		local this = getent(self)

		if not isGun(this) then return 0 end
		if restrictInfo(this) then return 0 end

		local Ammo = 0
		for _, AmmoEnt in pairs(this.AmmoLink) do
			if AmmoEnt and AmmoEnt:IsValid() then
				Ammo = Ammo + (AmmoEnt.Ammo or 0)
			end
		end

		return Ammo
	end

	--- Returns time to next shot of an ACF weapon
	-- @server
	-- @return number The time to next shot
	function ents_methods:acfReloadTime()
		local this = getent(self)

		if restrictInfo(this) or not isGun(this) or not this.ReloadTime then return 0 end

		return this.ReloadTime
	end

	--- Returns number between 0 and 1 which represents reloading progress of an ACF weapon. Useful for progress bars
	-- @server
	-- @return number The reloading progress
	function ents_methods:acfReloadProgress()
		local this = getent(self)

		if restrictInfo(this) or not isGun(this) then return 1 end

		local reloadTime
		if this.MagSize == 1 then
			reloadTime = this.ReloadTime
		else
			if this.MagSize - this.CurrentShot > 0 then
				reloadTime = this.ReloadTime
			else
				reloadTime = this.MagReload + this.ReloadTime
			end
		end

		return clamp(1 - (this.NextFire - CurTime()) / reloadTime, 0, 1)
	end

	--- Returns time it takes for an ACF weapon to reload magazine
	-- @server
	-- @return number The time it takes to reload the magazine
	function ents_methods:acfMagReloadTime()
		local this = getent(self)

		if restrictInfo(this) or not isGun(this) or not this.MagReload then return 0 end

		return this.MagReload
	end

	--- Returns the state of an ACF weapon
	-- @server
	-- @return string The state of the weapon
	function ents_methods:acfState()
		local this = getent(self)

		if not isGun(this) then return "" end
		if restrictInfo(this) then return "" end

		local state = ""

		local isEmpty = this.BulletData.Type == "Empty"
		local isReloading = not isEmpty and CurTime() < this.NextFire and (this.MagSize == 1 or (this.LastLoadDuration > this.ReloadTime))

		if isEmpty then
			state = "Empty"
		elseif isReloading or not this.Ready then
			state = "Loading"
		else
			state = "Loaded"
		end

		return state
	end
end

-- Ammo functions
do
	--- Returns true if the entity is an ACF ammo crate
	-- @server
	-- @return boolean True if the entity is an ACF ammo crate
	function ents_methods:acfIsAmmo ()
		return isAmmo(getent(self))
	end

	--- Returns the rounds left in an acf ammo crate
	-- @server
	-- @return number The rounds left in the crate
	function ents_methods:acfRounds()
		local this = getent(self)

		if not isAmmo(this) then return 0 end
		if restrictInfo(this) then return 0 end

		return this.Ammo
	end

	--- Returns the type of weapon the ammo in an ACF ammo crate loads into
	-- @server
	-- @return string The type of weapon the ammo in the crate loads into
	function ents_methods:acfRoundType()
		local this = getent(self)
		if not isAmmo(this) then return "" end
		if restrictInfo(this) then return "" end
		--return this.RoundId or ""
		-- E2 uses this one now

		return this.RoundType or ""
	end

	--- Returns the type of ammo in a crate or gun
	-- @server
	-- @return string The type of ammo
	function ents_methods:acfAmmoType()
		local this = getent(self)
		if not (isAmmo(this) or isGun(this)) then return "" end
		if restrictInfo(this) then return "" end

		return this.BulletData["Type"] or ""
	end

	--- Returns the caliber of an ammo or gun
	-- @server
	-- @return number The caliber
	function ents_methods:acfCaliber()
		local this = getent(self)
		if not (isAmmo(this) or isGun(this)) then return 0 end
		if restrictInfo(this) then return 0 end

		return this.Caliber * 10
	end

	--- Returns the muzzle velocity of the ammo in a crate or gun
	-- @server
	-- @return number The muzzle velocity
	function ents_methods:acfMuzzleVel()
		local this = getent(self)
		if not (isAmmo(this) or isGun(this)) then return 0 end
		if restrictInfo(this) then return 0 end

		return round((this.BulletData["MuzzleVel"] or 0) * ACF.VelScale, 3)
	end

	--- Returns the mass of the projectile in a crate or gun
	-- @server
	-- @return number The mass of the projectile
	function ents_methods:acfProjectileMass()
		local this = getent(self)
		if not (isAmmo(this) or isGun(this)) then return 0 end
		if restrictInfo(this) then return 0 end

		return round(this.BulletData["ProjMass"] or 0, 3)
	end

	--- Returns the number of projectiles in a flechette round
	-- @server
	-- @return number The number of projectiles
	function ents_methods:acfFLSpikes()
		local this = getent(self)
		if not (isAmmo(this) or isGun(this)) then return 0 end
		if restrictInfo(this) then return 0 end
		if this.BulletData["Type"] ~= "FL" then return 0 end

		return this.BulletData["Flechettes"] or 0
	end

	--- Returns the mass of a single spike in a FL round in a crate or gun
	-- @server
	-- @return number The mass of a single spike
	function ents_methods:acfFLSpikeMass()
		local this = getent(self)
		if not (isAmmo(this) or isGun(this)) then return 0 end
		if restrictInfo(this) then return 0 end
		if this.BulletData["Type"] ~= "FL" then return 0 end

		return round(this.BulletData["FlechetteMass"] or 0, 3)
	end

	--- Returns the radius of the spikes in a flechette round in mm
	-- @server
	-- @return number The radius of the spikes in mm
	function ents_methods:acfFLSpikeRadius()
		local this = getent(self)
		if not (isAmmo(this) or isGun(this)) then return 0 end
		if restrictInfo(this) then return 0 end
		if this.BulletData["Type"] ~= "FL" then return 0 end

		return round((this.BulletData["FlechetteRadius"] or 0) * 10, 3)
	end

	--- Returns the penetration of a round in an ACF ammo crate or gun
	-- @server
	-- @return number The penetration of the round
	function ents_methods:acfPenetration()
		local this = getent(self)
		if not (isAmmo(this) or isGun(this)) then return 0 end
		if restrictInfo(this) then return 0 end
		if not ACE_CheckRound(this.BulletData.Type) then return 0 end

		return ACF.RoundTypes[this.BulletData.Type].getDisplayData(this.BulletData).MaxPen or 0
	end

	--- Returns the blast radius of an HE, APHE, or HEAT round
	-- @server
	-- @return number The blast radius of the round
	function ents_methods:acfBlastRadius()
		local this = getent(self)
		if not (isAmmo(this) or isGun(this)) then return 0 end
		if restrictInfo(this) then return 0 end

		local Type = this.BulletData["Type"] or ""

		if Type == "HE" or Type == "APHE" then
			return round(this.BulletData["FillerMass"] ^ 0.33 * 8, 3)
		elseif Type == "HEAT" then
			return round((this.BulletData["FillerMass"] / 3) ^ 0.33 * 8, 3)
		end

		return 0
	end

	--- Returns the drag coef of the ammo in a crate or gun
	-- @server
	-- @return number The drag coef of the ammo
	function ents_methods:acfDragCoef()
		local this = getent(self)
		if not (isAmmo(this) or isGun(this)) then return 0 end
		if restrictInfo(this) then return 0 end

		return (this.BulletData["DragCoef"] or 0) / ACF.DragDiv
	end

	--- Returns the bullet data related to the index
	--- Needs acf.trackBullets privilege to work.
	-- @server
	-- @param number index The index of the bullet
	-- @return table The bullet data of the bullet or an empty table if the bullet doesn't exist
	function acf_library.getBulletDataByIndex( index )
		if not hasaccess(instance, nil, "acf.trackBullets") then
			SF.Throw("You need the acf.trackBullets privilege to use this function", 2)
			return {} -- Should not be needed but just in case
		end
		checkluatype(index, TYPE_NUMBER)
		return sanitize( ACF.Bullet[ index ] or {} )
	end

	--- This gets called everytime a bullet is fired.
	--- The bullet may be destroyed at the same time if it hits something very close.
	--- Needs acf.trackBullets privilege to work.
	-- @name ACFOnBulletCreation
	-- @class hook
	-- @param number bulletIndex The index of the bullet fired
	-- @param table bulletData The data of the bullet fired
	-- @server
	SF.hookAdd("ACFOnBulletCreation", nil, function(_, bulletIndex, bulletData)
		if not hasaccess(instance, nil, "acf.trackBullets") then return false end

		return true,
		{
			bulletIndex,
			sanitize(bulletData or {}),
		}
	end)

	--- This gets called everytime a bullet hit something (and is destroyed).
	--- Needs acf.trackBullets privilege to work.
	-- @name ACFOnBulletHit
	-- @class hook
	-- @param number bulletIndex The index of the bullet that hit
	-- @param table bulletData The data of the bullet that hit
	-- @param table flightRes The flight results of the bullet that hit
	-- @server
	SF.hookAdd("ACFOnBulletHit", nil, function(_, bulletIndex, bulletData, flightRes)
		if not hasaccess(instance, nil, "acf.trackBullets") then return false end

		return true,
			{
				bulletIndex,
			 	sanitize(bulletData or {}),
				sanitize(flightRes or {})
			}
	end)

	--- This gets called everytime a bullet ricochets off something.
	--- Needs acf.trackBullets privilege to work.
	-- @name ACFOnBulletRicochet
	-- @class hook
	-- @param number bulletIndex The index of the bullet that ricocheted
	-- @param table bulletData The data of the bullet that ricocheted
	-- @param table flightRes The flight results of the bullet that ricocheted
	-- @server
	SF.hookAdd("ACFOnBulletRicochet", nil, function(_, bulletIndex, bulletData, flightRes)
		if not hasaccess(instance, nil, "acf.trackBullets") then return false end

		return true,
		{
			bulletIndex,
			sanitize(bulletData or {}),
			sanitize(flightRes or {})
		}
	end)

	--- This gets called everytime a bullet penetrates something.
	--- Needs acf.trackBullets privilege to work.
	-- @name ACFOnBulletPenetrated
	-- @class hook
	-- @param number bulletIndex The index of the bullet that penetrated
	-- @param table bulletData The data of the bullet that penetrated
	-- @param table flightRes The flight results of the bullet that penetrated
	-- @server
	SF.hookAdd("ACFOnBulletPenetrated", nil, function(_, bulletIndex, bulletData, flightRes)
		if not hasaccess(instance, nil, "acf.trackBullets") then return false end

		return true,
		{
			bulletIndex,
			sanitize(bulletData or {}),
			sanitize(flightRes or {})
		}
	end)

	--- This gets called everytime a bullet is removed for any reason.
	--- Needs acf.trackBullets privilege to work.
	-- @name ACFOnBulletRemoved
	-- @class hook
	-- @param number bulletIndex The index of the bullet that was removed
	-- @param table bulletData The data of the bullet that was removed
	-- @server
	SF.hookAdd("ACFOnBulletRemoved", nil, function(_, bulletIndex, bulletData)
		if not hasaccess(instance, nil, "acf.trackBullets") then return false end

		return true,
		{
			bulletIndex,
			sanitize(bulletData or {}),
		}
	end)

end

-- Mobility functions
do
	--- Returns the specs of an engine or gearbox
	-- @param string id ID or name of the engine or gearbox
	-- @server
	-- @return table The specs table
	function acf_library.getMobilitySpecs(id)
		checkluatype(id, TYPE_STRING)

		local listEntries = ACF.Weapons.Mobility

		-- Not a valid id, try name
		if not listEntries[id] then
			id = listIDFromName(listEntries, id)

			-- Name is also invalid, error
			if not id or not listEntries[id] then
				SF.Throw("Invalid ID or name", 2)
			end
		end

		local specs = table.Copy(listEntries[id])
		specs.BaseClass = nil

		return sanitize(specs)
	end

	--- Returns a list of all mobility components
	-- @server
	-- @return table The mobility component list
	function acf_library.getAllMobility()
		local tbl = {}

		for id, _ in pairs(ACF.Weapons.Mobility) do
			tbl[#tbl + 1] = id
		end

		return tbl
	end

	--- Returns a list of all engines
	-- @server
	-- @return table The engine list
	function acf_library.getAllEngines()
		local tbl = {}

		for id, d in pairs(ACF.Weapons.Mobility) do
			if d.ent == "acf_engine" then
				tbl[#tbl + 1] = id
			end
		end

		return tbl
	end

	--- Returns a list of all gearboxes
	-- @server
	-- @return table The gearbox list
	function acf_library.getAllGearboxes()
		local tbl = {}

		for id, d in pairs(ACF.Weapons.Mobility) do
			if d.ent == "acf_gearbox" then
				tbl[#tbl + 1] = id
			end
		end

		return tbl
	end

	--- Returns any wheels linked to this engine/gearbox or child gearboxes
	-- @server
	-- @return table The linked wheels
	function ents_methods:acfGetLinkedWheels()
		local this = getent(self)

		if not (isEngine(this) or isGearbox(this)) then
			SF.Throw("Target must be an engine or gearbox", 2)
		end

		local wheels = {}
		for _, ent in pairs(ACF_GetLinkedWheels(this)) do
			wheels[#wheels + 1] = ent
		end

		return sanitize(wheels)
	end

	--- Returns true if the entity is an ACF engine
	-- @server
	-- @return boolean Whether the entity is an ACF engine
	function ents_methods:acfIsEngine()
		return isEngine(getent(self))
	end

	--- Returns true if an ACF engine is electric
	-- @server
	-- @return boolean Whether the engine is electric
	function ents_methods:acfIsElectric()
		return getent(self).iselec == true
	end

	--- Returns the torque in N/m of an ACF engine
	-- @server
	-- @return number The torque in N/m
	function ents_methods:acfMaxTorque()
		local this = getent(self)

		if not isEngine(this) then return 0 end

		return this.PeakTorque
	end

	--- Returns the torque in N/m of an ACF engine with fuel
	-- @server
	-- @return number The torque in N/m
	function ents_methods:acfMaxTorqueWithFuel()
		local this = getent(self)

		if not isEngine(this) then return 0 end

		return this.PeakTorque
	end

	--- Returns the power in kW of an ACF engine
	-- @server
	-- @return number The power in kW
	function ents_methods:acfMaxPower()
		local this = getent(self)

		if not isEngine(this) then return 0 end

		return this.peakkw
	end

	--- Returns the power in kW of an ACF engine with fuel
	-- @server
	-- @return number The power in kW
	function ents_methods:acfMaxPowerWithFuel()
		local this = getent(self)

		if not isEngine(this) then return 0 end

		return this.peakkw
	end

	--- Returns the idle rpm of an ACF engine
	-- @server
	-- @return number The idle rpm
	function ents_methods:acfIdleRPM()
		local this = getent(self)

		if not isEngine(this) then return 0 end

		return this.IdleRPM
	end

	--- Returns the powerband min and max of an ACF Engine
	-- @server
	-- @return number The powerband min
	-- @return number The powerband max
	function ents_methods:acfPowerband()
		local this = getent(self)

		if not isEngine(this) then return 0, 0 end

		return this.PeakMinRPM, this.PeakMaxRPM
	end

	--- Returns the powerband min of an ACF engine
	-- @server
	-- @return number The powerband min
	function ents_methods:acfPowerbandMin()
		local this = getent(self)

		if not isEngine(this) then return 0 end

		return this.PeakMinRPM
	end

	--- Returns the powerband max of an ACF engine
	-- @server
	-- @return number The powerband max
	function ents_methods:acfPowerbandMax()
		local this = getent(self)

		if not isEngine(this) then return 0 end

		return this.PeakMaxRPM
	end

	--- Returns the redline max of an ACF engine
	-- @server
	-- @return number The redline
	function ents_methods:acfRedline()
		local this = getent(self)

		if not isEngine(this) then return 0 end

		return this.LimitRPM
	end

	--- Returns the current rpm of an ACF engine
	-- @server
	-- @return number The current rpm
	function ents_methods:acfRPM()
		local this = getent(self)

		if not isEngine(this) then return 0 end
		if restrictInfo(this) then return 0 end

		return round(this.FlyRPM)
	end

	--- Returns the current torque of an ACF engine
	-- @server
	-- @return number The current torque
	function ents_methods:acfTorque()
		local this = getent(self)

		if not isEngine(this) then return 0 end
		if restrictInfo(this) then return 0 end

		return round(this.Torque)
	end

	--- Returns the inertia of an ACF engine's flywheel
	-- @server
	-- @return number The inertia of the flywheel
	function ents_methods:acfFlyInertia()
		local this = getent(self)

		if not isEngine(this) then return 0 end
		if restrictInfo(this) then return 0 end

		return this.Inertia
	end

	--- Returns the mass of an ACF engine's flywheel
	-- @server
	-- @return number The mass of the flywheel
	function ents_methods:acfFlyMass()
		local this = getent(self)

		if not isEngine(this) then return 0 end
		if restrictInfo(this) then return 0 end

		return this.Inertia / 3.1416 ^ 2
	end


	--- Returns the current power of an ACF engine in kW
	-- @server
	-- @return number The current power in kW
	function ents_methods:acfPower()
		local this = getent(self)

		if not isEngine(this) then return 0 end
		if restrictInfo(this) then return 0 end

		return round(this.Torque * this.FlyRPM / 9548.8)
	end

	--- Returns true if the RPM of an ACF engine is inside the powerband
	-- @server
	-- @return boolean True if the RPM is inside the powerband
	function ents_methods:acfInPowerband()
		local this = getent(self)

		if not isEngine(this) then return false end
		if restrictInfo(this) then return false end

		return this.FlyRPM > this.PeakMinRPM and this.FlyRPM < this.PeakMaxRPM
	end

	--- Returns the throttle value
	-- @server
	-- @return number The throttle value
	function ents_methods:acfGetThrottle()
		local this = getent(self)

		if not isEngine(this) then return 0 end
		if restrictInfo(this) then return 0 end

		return this.Throttle * 100
	end

	--- Sets the throttle value for an ACF engine
	-- @server
	-- @param number throttle The throttle value
	function ents_methods:acfSetThrottle(throttle)
		checkluatype(throttle, TYPE_NUMBER)

		local this = getent(self)

		checkpermission(instance, this, "entities.acf")

		if not isEngine(this) then return end

		this:TriggerInput("Throttle", throttle)
	end

	--- Gets the fuel remaining for an ACF engine
	-- @server
	-- @return number The fuel remaining, in litres or kilowatt-hours
	function ents_methods:acfFuelRemaining()
		local this = getent(self)

		if not isEngine(this) then return 0 end
		if restrictInfo(this) then return 0 end

		return this.TotalFuel
	end

	--- Returns true if the entity is an ACF gearbox
	-- @server
	-- @return boolean True if the entity is an ACF gearbox
	function ents_methods:acfIsGearbox ()
		return isGearbox(getent(self))
	end

	--- Returns the current gear for an ACF gearbox
	-- @server
	-- @return number The current gear
	function ents_methods:acfGear()
		local this = getent(self)

		if not isGearbox(this) then return 0 end
		if restrictInfo(this) then return 0 end

		return this.Gear
	end

	--- Returns the number of gears for an ACF gearbox
	-- @server
	-- @return number The number of gears
	function ents_methods:acfNumGears()
		local this = getent(self)

		if not isGearbox(this) then return 0 end
		if restrictInfo(this) then return 0 end

		return this.Gears
	end

	--- Returns the final drive ratio for an ACF gearbox
	-- @server
	-- @return number The final drive ratio
	function ents_methods:acfFinalRatio()
		local this = getent(self)

		if not isGearbox(this) then return 0 end
		if restrictInfo(this) then return 0 end

		return tonumber(this.GearTable["Final"])
	end

	--- Returns the total ratio (current gear * final) for an ACF gearbox
	-- @server
	-- @return number The total ratio
	function ents_methods:acfTotalRatio()
		local this = getent(self)

		if not isGearbox(this) then return 0 end
		if restrictInfo(this) then return 0 end

		return this.GearRatio
	end

	--- Returns the max torque for an ACF gearbox
	-- @server
	-- @return number The max torque
	function ents_methods:acfTorqueRating()
		local this = getent(self)

		if not isGearbox(this) then return 0 end

		return this.MaxTorque
	end

	--- Returns whether an ACF gearbox is dual clutch
	-- @server
	-- @return boolean True if the gearbox is dual clutch
	function ents_methods:acfIsDual()
		local this = getent(self)

		if not isGearbox(this) then return false end
		if restrictInfo(this) then return false end

		return this.Dual
	end

	--- Returns the time in ms an ACF gearbox takes to change gears
	-- @server
	-- @return number The time in ms
	function ents_methods:acfShiftTime()
		local this = getent(self)

		if not isGearbox(this) then return 0 end

		return this.SwitchTime * 1000
	end

	--- Returns true if an ACF gearbox is in gear
	-- @server
	-- @return boolean True if the gearbox is in gear
	function ents_methods:acfInGear()
		local this = getent(self)

		if not isGearbox(this) then return false end
		if restrictInfo(this) then return false end

		return this.InGear
	end

	--- Returns the ratio for a specified gear of an ACF gearbox
	-- @server
	-- @param number gear The gear to get the ratio for
	function ents_methods:acfGearRatio(gear)
		checkluatype(gear, TYPE_NUMBER)
		local this = getent(self)

		if not isGearbox(this) then return 0 end
		if restrictInfo(this) then return 0 end

		local g = clamp(floor(gear), 1, this.Gears)

		return tonumber(this.GearTable[g]) or 0
	end

	--- Returns the current torque output for an ACF gearbox
	-- @server
	-- @return number The current torque output
	function ents_methods:acfTorqueOut()
		local this = getent(self)

		if not isGearbox(this) then return 0 end

		return min(this.TotalReqTq, this.MaxTorque) / this.GearRatio
	end

	--- Sets the gear ratio of a CVT, set to 0 to use built-in algorithm
	-- @server
	-- @param number ratio The ratio to set
	function ents_methods:acfCVTRatio(ratio)
		checkluatype(ratio, TYPE_NUMBER)
		local this = getent(self)

		checkpermission(instance, this, "entities.acf")
		if not isGearbox(this) then return end
		if restrictInfo(this) then return end
		if not this.CVT then return end

		this.CVTRatio = math.Clamp(ratio, 0, 1)
	end

	--- Sets the current gear for an ACF gearbox
	-- @server
	-- @param number gear The gear to switch to
	function ents_methods:acfShift(gear)
		checkluatype(gear, TYPE_NUMBER)
		local this = getent(self)

		checkpermission(instance, this, "entities.acf")
		if not isGearbox(this) then return end
		if restrictInfo(this) then return end

		this:TriggerInput("Gear", gear)
	end

	--- Cause an ACF gearbox to shift up
	-- @server
	function ents_methods:acfShiftUp()
		local this = getent(self)

		checkpermission(instance, this, "entities.acf")
		if not isGearbox(this) then return end
		if restrictInfo(this) then return end

		this:TriggerInput("Gear Up", 1)
	end

	--- Cause an ACF gearbox to shift down
	-- @server
	function ents_methods:acfShiftDown()
		local this = getent(self)

		checkpermission(instance, this, "entities.acf")
		if not isGearbox(this) then return end
		if restrictInfo(this) then return end

		this:TriggerInput("Gear Down", 1)
	end

	--- Sets the brakes for an ACF gearbox
	-- @server
	-- @param number brake The brake value to apply
	function ents_methods:acfBrake(brake)
		checkluatype(brake, TYPE_NUMBER)
		local this = getent(self)

		checkpermission(instance, this, "entities.acf")
		if not isGearbox(this) then return end
		if restrictInfo(this) then return end

		this:TriggerInput("Brake", brake)
	end

	--- Sets the left brakes for an ACF gearbox
	-- @server
	-- @param number brake The brake value to apply
	function ents_methods:acfBrakeLeft(brake)
		checkluatype(brake, TYPE_NUMBER)
		local this = getent(self)

		checkpermission(instance, this, "entities.acf")
		if not isGearbox(this) then return end
		if restrictInfo(this) then return end
		if not this.Dual then return end

		this:TriggerInput("Left Brake", brake)
	end

	--- Sets the right brakes for an ACF gearbox
	-- @server
	-- @param number brake The brake value to apply
	function ents_methods:acfBrakeRight(brake)
		checkluatype(brake, TYPE_NUMBER)
		local this = getent(self)

		checkpermission(instance, this, "entities.acf")
		if not isGearbox(this) then return end
		if restrictInfo(this) then return end
		if not this.Dual then return end

		this:TriggerInput("Right Brake", brake)
	end

	--- Sets the clutch for an ACF gearbox
	-- @server
	-- @param number clutch The clutch value to apply
	function ents_methods:acfClutch(clutch)
		checkluatype(clutch, TYPE_NUMBER)
		local this = getent(self)

		checkpermission(instance, this, "entities.acf")
		if not isGearbox(this) then return end
		if restrictInfo(this) then return end

		this:TriggerInput("Clutch", clutch)
	end

	--- Sets the left clutch for an ACF gearbox
	-- @server
	-- @param number clutch The clutch value to apply
	function ents_methods:acfClutchLeft(clutch)
		checkluatype(clutch, TYPE_NUMBER)
		local this = getent(self)

		checkpermission(instance, this, "entities.acf")
		if not isGearbox(this) then return end
		if restrictInfo(this) then return end
		if not this.Dual then return end

		this:TriggerInput("Left Clutch", clutch)
	end

	--- Sets the right clutch for an ACF gearbox
	-- @server
	-- @param number clutch The clutch value to apply
	function ents_methods:acfClutchRight(clutch)
		checkluatype(clutch, TYPE_NUMBER)
		local this = getent(self)

		checkpermission(instance, this, "entities.acf")
		if not isGearbox(this) then return end
		if restrictInfo(this) then return end
		if not this.Dual then return end

		this:TriggerInput("Right Clutch", clutch)
	end

	--- Sets the steer ratio for an ACF gearbox
	-- @server
	-- @param number ratio The steer ratio to apply
	function ents_methods:acfSteerRate(rate)
		checkluatype(rate, TYPE_NUMBER)
		local this = getent(self)

		checkpermission(instance, this, "entities.acf")
		if not isGearbox(this) then return end
		if restrictInfo(this) then return end
		if not this.DoubleDiff then return end

		this:TriggerInput("Steer Rate", rate)
	end

	--- Applies gear hold for an automatic ACF gearbox
	-- @server
	-- @param number hold True to hold the current gear
	function ents_methods:acfHoldGear(hold)
		checkluatype(hold, TYPE_NUMBER)
		local this = getent(self)

		checkpermission(instance, this, "entities.acf")
		if not isGearbox(this) then return end
		if restrictInfo(this) then return end
		if not this.Auto then return end

		this:TriggerInput("Hold Gear", hold)
	end

	--- Sets the shift point scaling for an automatic ACF gearbox
	-- @server
	-- @param number scale The shift point scaling value
	function ents_methods:acfShiftPointScale(scale)
		checkluatype(scale, TYPE_NUMBER)
		local this = getent(self)

		checkpermission(instance, this, "entities.acf")
		if not isGearbox(this) then return end
		if restrictInfo(this) then return end
		if not this.Auto then return end

		this:TriggerInput("Shift Speed Scale", scale)
	end
end

-- Fuel functions
do
	--- Returns true if the entity is an ACF fuel tank
	-- @server
	-- @return boolean True if the entity is an ACF fuel tank
	function ents_methods:acfIsFuel()
		return isFuel(getent(self))
	end

	--- (DEPRECATED) Returns true if the current engine requires fuel to run
	-- @server
	-- @return boolean True if the current engine requires fuel to run
	function ents_methods:acfFuelRequired()
		return 1
	end

	--- Sets the ACF fuel tank refuel duty status, which supplies fuel to other fuel tanks
	-- @server
	-- @param[opt] boolean True to enable refuel duty, false to disable
	function ents_methods:acfRefuelDuty(on)
		checkluatype(on, TYPE_BOOL)
		local this = getent(self)

		checkpermission(instance, this, "entities.acf")
		if not isFuel(this) then return end

		this:TriggerInput("Refuel Duty", on and true or false)
	end

	--- Returns the remaining liters or kilowatt hours of fuel in an ACF fuel tank or engine
	-- @server
	-- @return number The remaining fuel
	function ents_methods:acfFuel()
		local this = getent(self)

		if restrictInfo(this) then return 0 end

		if isFuel(this) then
			return round(this.Fuel, 3)
		elseif isEngine(this) then
			if not #this.FuelLink then return 0 end --if no tanks, return 0

			local liters = 0
			for _, tank in pairs(this.FuelLink) do
				if validPhysics(tank) and tank.Active then
					liters = liters + tank.Fuel
				end
			end

			return round(liters, 3)
		end

		return 0
	end

	--- Returns the amount of fuel in an ACF fuel tank or linked to engine as a percentage of capacity
	-- @server
	-- @return number The fuel percentage
	function ents_methods:acfFuelLevel()
		local this = getent(self)

		if restrictInfo(this) then return 0 end

		if isFuel(this) then
			return round(this.Fuel / this.Capacity, 3)
		elseif isEngine(this) then
			if not #this.FuelLink then return 0 end --if no tanks, return 0

			local liters = 0
			local capacity = 0
			for _, tank in pairs(this.FuelLink) do
				if validPhysics(tank) and tank.Active then
					capacity = capacity + tank.Capacity
					liters = liters + tank.Fuel
				end
			end

			if capacity <= 0 then return 0 end

			return round(liters / capacity, 3)
		end

		return 0
	end

	--- Returns the current fuel consumption in liters or kilowatts per minute of an engine
	-- @server
	-- @return number The fuel consumption
	function ents_methods:acfFuelUse()
		local this = getent(self)

		if not isEngine(this) then return 0 end
		if restrictInfo(this) then return 0 end
		if not #this.FuelLink then return 0 end --if no tanks, return 0

		local tank
		for _, fueltank in pairs(this.FuelLink) do
			if validPhysics(fueltank) and fueltank.Fuel > 0 and fueltank.Active then
				tank = fueltank
				break
			end
		end

		if not tank then return 0 end

		local Consumption
		if this.FuelType == "Electric" then
			Consumption = 60 * (this.Torque * this.FlyRPM / 9548.8) * this.FuelUse
		else
			local Load = 0.3 + this.Throttle * 0.7
			Consumption = 60 * Load * this.FuelUse * (this.FlyRPM / this.PeakKwRPM) / ACF.FuelDensity[tank.FuelType]
		end

		return round(Consumption, 3)
	end

	--- Returns the peak fuel consumption in liters per minute or kilowatts of an engine at powerband max, for the current fuel type the engine is using
	-- @server
	-- @return number The peak fuel consumption
	function ents_methods:acfPeakFuelUse()
		local this = getent(self)

		if not isEngine(this) then return 0 end
		if restrictInfo(this) then return 0 end
		if not #this.FuelLink then return 0 end --if no tanks, return 0

		local fuel = "Petrol"
		local tank
		for _, fueltank in pairs(this.FuelLink) do
			if fueltank.Fuel > 0 and fueltank.Active then
				tank = fueltank
				break
			end
		end

		if tank then
			fuel = tank.Fuel
		end

		local Consumption
		if this.FuelType == "Electric" then
			Consumption = 60 * (this.PeakTorque * this.LimitRPM / (4 * 9548.8)) * this.FuelUse
		else
			Consumption = 60 * this.FuelUse / ACF.FuelDensity[fuel]
		end

		return round(Consumption, 3)
	end
end

-- Radar functions
do
	--- Returns a table containing the outputs you'd get from an ACF tracking radar, missile radar, or IRST
	-- @server
	-- @return table The radar data - check radar wire outputs for key names
	function ents_methods:acfRadarData()
		local this = getent(self)
		if not isRadar(this) then
			SF.Throw("Entity is not a radar", 2)
		end

		local data = {}
		local radarType = this:GetClass()

		if restrictInfo(this) then return data end

		data.Detected = this.OutputData.Detected
		data.Position = this.OutputData.Position

		if radarType == "acf_missileradar" then
			data.ClosestDistance = this.OutputData.ClosestDistance
			data.Entities = this.OutputData.Entities
			data.Velocity = this.OutputData.Velocity
		elseif radarType == "ace_trackingradar" or "ace_irst" then
			data.Owner = this.OutputData.Owner
			data.ClosestToBeam = this.OutputData.ClosestToBeam
			if radarType == "ace_trackingradar" then
				data.Velocity = this.OutputData.Velocity
				data.IsJammed = this.OutputData.IsJammed
			elseif radarType == "ace_irst" then
				data.Angle = this.OutputData.Angle
				data.EffHeat = this.OutputData.EffHeat
			end
		end

		return sanitize(data)
	end
end

end
