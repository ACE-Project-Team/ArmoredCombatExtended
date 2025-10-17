E2Lib.RegisterExtension("acf", true)

local isOwner, validPhysics = E2Lib.isOwner, E2Lib.validPhysics
local match = string.match
local abs, round, clamp, floor, min, max = math.abs, math.Round, math.Clamp, math.floor, math.min, math.max
local cos, rad, pi = math.cos, math.rad, math.pi
local tableCopy = table.Copy
local ACF = ACF

local function isACF(ent)
	if not validPhysics(ent) then return false end

	local matchACF = match(ent:GetClass(), "^acf_") and true or false
	local matchACE = match(ent:GetClass(), "^ace_") and true or false

	return matchACF or matchACE
end

local function isEngine(ent)
	if not validPhysics(ent) then return false end
	return ent:GetClass() == "acf_engine"
end

local function isGearbox(ent)
	if not validPhysics(ent) then return false end
	return ent:GetClass() == "acf_gearbox"
end

local function isGun(ent)
	if not validPhysics(ent) then return false end
	return ent:GetClass() == "acf_gun"
end

local function isRack(ent)
	if not validPhysics(ent) then return false end
	return ent:GetClass() == "acf_rack"
end

local function isAmmo(ent)
	if not validPhysics(ent) then return false end
	return ent:GetClass() == "acf_ammo"
end

local function isFuel(ent)
	if not validPhysics(ent) then return false end
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
	if not validPhysics(ent) then return false end
	return radarTypes[ent:GetClass()]
end

local function restrictInfo(ply, ent)
	if not ACF.RestrictInfo then return false end

	return not ent:CPPICanTool(ply, "acfmenu")
end

-- Link functions
do
	local function isLinkableACFEnt(ent)
		if not validPhysics(ent) then return false end
		local entClass = ent:GetClass()
	
		return ACF_E2_LinkTables[entClass] ~= nil
	end

	ACF_E2_LinkTables = ACF_E2_LinkTables or
	{ -- link resources within each ent type.  should point to an ent: true if adding link.Ent, false to add link itself
		acf_engine		= {GearLink = true, FuelLink = false},
		acf_gearbox		= {WheelLink = true, Master = false},
		acf_fueltank	= {Master = false},
		acf_gun			= {AmmoLink = false},
		acf_ammo		= {Master = false}
	}
	
	
	local function getLinks(ent, enttype)
		local ret = {}
		-- find the link resources available for this ent type
		for entry, mode in pairs(ACF_E2_LinkTables[enttype]) do
			if not ent[entry] then
				error("Couldn't find link resource " .. entry .. " for entity " .. tostring(ent))

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

		for _, box in pairs(boxes) do
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

	__e2setcost(20)

	-- Returns an array of all entities linked to this entity through ACF
	e2function array entity:acfLinks()
		if not validPhysics(this) then return self:throw("Entity is not valid", {}) end

		local class = this:GetClass()

		if not ACF_E2_LinkTables[class] then
			return searchForGearboxLinks(this)
		end

		return getLinks(this, class)
	end

	-- Returns an array of all wheels linked to this engine/gearbox, and child gearboxes
	e2function array entity:acfGetLinkedWheels()
		if not (isEngine(this) or isGearbox(this)) then return self:throw("Entity is not a valid ACF engine or gearbox", {}) end

		local wheels = {}

		for _, ent in pairs(ACF_GetLinkedWheels(this)) do
			wheels[#wheels + 1] = ent
		end

		return wheels
	end
end

-- General Functions
do
	__e2setcost(1)

	[nodiscard]
	e2function number acfInfoRestricted()
		return ACF.RestrictInfo and 1 or 0
	end

	[nodiscard]
	e2function string entity:acfNameShort()
		if not isACF(this) then return self:throw("Entity is not a valid ACF component", "") end
		if restrictInfo(self.player, this) then return "" end

		if isAmmo(this) then return this.RoundId or "" end
		if isFuel(this) then return this.FuelType .. " " .. this.SizeID end

		return this.Id or ""
	end

	-- Returns the capacity of an acf ammo crate or fuel tank
	[nodiscard]
	e2function number entity:acfCapacity()
		if not (isAmmo(this) or isFuel(this)) then return self:throw("Entity is not a valid ACF ammo crate or fuel tank", 0) end
		if restrictInfo(self.player, this) then return 0 end

		return this.Capacity or 0
	end

	-- Returns 1 if an ACF engine, ammo crate, or fuel tank is on
	[nodiscard]
	e2function number entity:acfActive()
		local isAmmoCrate = isAmmo(this)
		if not (isEngine(this) or isAmmoCrate or isFuel(this)) then return self:throw("Entity is not a valid ACF engine, ammo crate, or fuel tank", 0) end
		if restrictInfo(self.player, this) then return 0 end

		if isAmmoCrate then
			return this.Load and 1 or 0
		else
			return this.Active and 1 or 0
		end
	end

	__e2setcost(5)

	-- Turns an ACF engine, ammo crate, or fuel tank on or off
	e2function void entity:acfActive(number on)
		if not (isEngine(this) or isAmmo(this) or isFuel(this)) then return self:throw("Entity is not a valid ACF engine, ammo crate, or fuel tank") end
		if not this:CPPICanTool(self.player, "acfmenu") then return self:throw("You cannot control this entity") end

		this:TriggerInput("Active", on)
	end

	-- Returns 1 if the hitpos is on a clipped part of the entity
	[nodiscard]
	e2function number entity:acfHitClip(vector hitPos)
		if not this:CPPICanTool(self.player, "acfmenu") then return self:throw("You cannot target this entity", 0) end
		return ACF_CheckClips(this, hitPos) and 1 or 0
	end

	__e2setcost(2)
	
	-- Returns the full name of an ACF entity
	[nodiscard]
	e2function string entity:acfName()
		if not isACF(this) then return self:throw("Entity is not a valid ACF component", "") end

		if isAmmo(this) then return this.RoundId .. " " .. this.RoundType end
		if isFuel(this) then return this.FuelType .. " " .. this.SizeId end

		local acftype = ""

		if isGun(this) then 
			acftype = "Guns"
		elseif isEngine(this)  then 
			acftype = "Engines"
		elseif isGearbox(this)  then 
			acftype = "Gearboxes" 
		elseif isRack(this) then
			acftype = "Racks"
		elseif isRadar(this) then
			acftype = "Radars"
		end

		if acftype == "" then return "" end

		return ACF.Weapons[acftype][this.Id]["name"] or ""
	end

	-- Returns the type of ACF entity
	[nodiscard]
	e2function string entity:acfType()
		if not isACF(this) then return self:throw("Entity is not a valid ACF component", "") end

		if isEngine(this) then
			return ACF.Weapons["Engines"][this.Id]["category"] or ""
		elseif isGearbox(this) then
			return ACF.Weapons["Gearboxes"][this.Id]["category"] or ""
		elseif isGun(this) then
			return ACF.Classes["GunClass"][this.Class]["name"] or ""
		elseif isRack(this) then
			return ACF.Classes["Rack"][this.Class]["name"] or ""
		elseif isRadar(this) then
			return ACF.Classes["Radar"][this.Class]["name"] or ""
		end

		if isAmmo(this) then return this.RoundType or "" end
		if isFuel(this) then return this.FuelType or "" end

		return ""
	end

	__e2setcost(1)

	-- Return the current ACF drag divisor
	[nodiscard]
	e2function number acfDragDiv()
		return ACF.DragDiv
	end

	-- Returns the temperature of an ACF entity
	[nodiscard]
	e2function number entity:acfHeat()
		if not isACF(this) then return self:throw("Entity is not a valid ACF component", 0) end
		if restrictInfo(self.player, this) then return 0 end

		return this.Heat or 0
	end

	-- Returns the latest ACE version
	[nodiscard]
	e2function number acfVersion()
		return ACF.CurrentVersion
	end

	-- Returns the current ACE version
	[nodiscard]
	e2function number acfCurVersion()
		return ACF.Version
	end

	-- Returns the current air gap factor (air effectiveness against HEAT)
	[nodiscard]
	e2function number acfHEATAirGapFactor()
		return ACF.HeatAirGapFactor
	end

	-- Returns the current ACE wind direction
	[nodiscard]
	e2function vector acfWindVector()
		return ACF.Wind
	end

	-- Returns 1 if the entity is an ACF engine
	[nodiscard, deprecated = "Just check the entity class yourself"]
	e2function number entity:acfIsEngine()
		return isEngine(this) and 1 or 0
	end

	-- Returns 1 if the entity is an ACF gearbox
	[nodiscard, deprecated = "Just check the entity class yourself"]
	e2function number entity:acfIsGearbox()
		return isGearbox(this) and 1 or 0
	end

	-- Returns 1 if the entity is an ACF gun
	[nodiscard, deprecated = "Just check the entity class yourself"]
	e2function number entity:acfIsGun()
		return isGun(this) and 1 or 0
	end

	-- Returns 1 if the entity is an ACF rack
	[nodiscard, deprecated = "Just check the entity class yourself"]
	e2function number entity:acfIsRack()
		return isRack(this) and 1 or 0
	end

	-- Returns 1 if the entity is an ACF ammo crate
	[nodiscard, deprecated = "Just check the entity class yourself"]
	e2function number entity:acfIsAmmo()
		return isAmmo(this) and 1 or 0
	end

	-- Returns 1 if the entity is an ACF fuel tank
	[nodiscard, deprecated = "Just check the entity class yourself"]
	e2function number entity:acfIsFuel()
		return isFuel(this) and 1 or 0
	end

	-- Returns 1 if the entity is an ACF radar
	[nodiscard, deprecated = "Just check the entity class yourself"]
	e2function number entity:acfIsRadar()
		return isRadar(this) and 1 or 0
	end

	-- Links two ACF entities together
	e2function number entity:acfLinkTo(entity target, number notify)
		if not IsValid(this) then return self:throw("Invalid source entity", 0) end
		if not IsValid(target) then return self:throw("Invalid target entity", 0) end
		if this == target then return self:throw("Cannot link entity to itself", 0) end
		if not this:CPPICanTool(self.player, "acfmenu") then return self:throw("You do not have permission to target the source entity", 0) end
		if not target:CPPICanTool(self.player, "acfmenu") then return self:throw("You do not have permission to target the target entity", 0) end

		local success, msg

		if this.Link and target.Link then
			if target:GetClass() == "acf_engine" then
				success, msg = target:Link(this)
			else
				success, msg = this:Link(target)
			end
		elseif this.Link and not target.Link then
			success, msg = this:Link(target)
		elseif not this.Link and target.Link then
			success, msg = target:Link(this)
		else
			return self:throw("These entities cannot be linked to each other", 0)
		end

		if notify > 0 then
			ACF_SendNotify(self.player, success, msg)
		end

		return success and 1 or 0
	end

	-- Unlinks two ACF entities from each other
	e2function number entity:acfUnlinkFrom(entity target, number notify)
		if not IsValid(this) then return self:throw("Invalid source entity", 0) end
		if not IsValid(target) then return self:throw("Invalid target entity", 0) end
		if this == target then return self:throw("Cannot unlink entity from itself", 0) end
		if not this:CPPICanTool(self.player, "acfmenu") then return self:throw("You do not have permission to target the source entity", 0) end
		if not target:CPPICanTool(self.player, "acfmenu") then return self:throw("You do not have permission to target the target entity", 0) end

		local success, msg

		if this.Unlink and target.Unlink then
			if target:GetClass() == "acf_engine" then
				success, msg = target:Unlink(this)
			else
				success, msg = this:Unlink(target)
			end
		elseif this.Unlink and not target.Unlink then
			success, msg = this:Unlink(target)
		elseif not this.Unlink and target.Unlink then
			success, msg = target:Unlink(this)
		else
			return self:throw("These entities cannot be unlinked from each other", 0)
		end

		if notify > 0 then
			ACF_SendNotify(self.player, success, msg)
		end

		return success and 1 or 0
	end
end

-- Engine Functions
do
	__e2setcost(1)

	-- Returns 1 if the ACF engine is electric
	[nodiscard]
	e2function number entity:acfIsElectric()
		if not isEngine(this) then return self:throw("Entity is not a valid ACF engine", 0) end
		if restrictInfo(self.player, this) then return 0 end

		return ACF.Weapons["Engines"][this.Id]["category"] == "Electric" and 1 or 0
	end

	-- Returns the peak torque in Nm of an ACF engine
	[nodiscard]
	e2function number entity:acfMaxTorque()
		if not isEngine(this) then return self:throw("Entity is not a valid ACF engine", 0) end
		if restrictInfo(self.player, this) then return 0 end

		local torque = this.PeakTorque

		return torque
	end

	-- Returns the peak power in kW of an ACF engine
	[nodiscard]
	e2function number entity:acfMaxPower()
		if not isEngine(this) then return self:throw("Entity is not a valid ACF engine", 0) end
		if restrictInfo(self.player, this) then return 0 end

		local power = this.peakkw

		return power
	end

	-- Returns the peak torque in Nm of an ACF engine when supplied with fuel
	[nodiscard]
	e2function number entity:acfMaxTorqueWithFuel()
		if not isEngine(this) then return self:throw("Entity is not a valid ACF engine", 0) end
		if restrictInfo(self.player, this) then return 0 end

		return this.PeakTorque
	end

	-- Returns the peak power in kW of an ACF engine when supplied with fuel
	[nodiscard]
	e2function number entity:acfMaxPowerWithFuel()
		if not isEngine(this) then return self:throw("Entity is not a valid ACF engine", 0) end
		if restrictInfo(self.player, this) then return 0 end

		return this.peakkw
	end

	-- Returns the idle RPM of an ACF engine
	[nodiscard]
	e2function number entity:acfIdleRPM()
		if not isEngine(this) then return self:throw("Entity is not a valid ACF engine", 0) end
		if restrictInfo(self.player, this) then return 0 end

		return this.IdleRPM
	end

	-- Returns the lower powerband of an ACF engine
	[nodiscard]
	e2function number entity:acfPowerbandMin()
		if not isEngine(this) then return self:throw("Entity is not a valid ACF engine", 0) end
		if restrictInfo(self.player, this) then return 0 end

		return round(this.PeakMinRPM / 10) * 10
	end

	-- Returns the upper powerband of an ACF engine
	[nodiscard]
	e2function number entity:acfPowerbandMax()
		if not isEngine(this) then return self:throw("Entity is not a valid ACF engine", 0) end
		if restrictInfo(self.player, this) then return 0 end

		return round(this.PeakMaxRPM / 10) * 10
	end

	-- Returns the redline of an ACF engine
	[nodiscard]
	e2function number entity:acfRedline()
		if not isEngine(this) then return self:throw("Entity is not a valid ACF engine", 0) end
		if restrictInfo(self.player, this) then return 0 end

		return this.LimitRPM
	end

	-- Returns the current RPM of an ACF engine
	[nodiscard]
	e2function number entity:acfRPM()
		if not isEngine(this) then return self:throw("Entity is not a valid ACF engine", 0) end
		if restrictInfo(self.player, this) then return 0 end

		return round(this.FlyRPM)
	end

	-- Returns the torque output of an ACF engine, in Nm
	[nodiscard]
	e2function number entity:acfTorque()
		if not isEngine(this) then return self:throw("Entity is not a valid ACF engine", 0) end
		if restrictInfo(self.player, this) then return 0 end

		return round(this.Torque or 0)
	end

	-- Returns the power output of an ACF engine, in kW
	[nodiscard]
	e2function number entity:acfPower()
		if not isEngine(this) then return self:throw("Entity is not a valid ACF engine", 0) end
		if restrictInfo(self.player, this) then return 0 end

		return round((this.Torque or 0) * this.FlyRPM / 9548.8)
	end

	-- Returns the inertia of an ACF engine's flywheel
	[nodiscard]
	e2function number entity:acfFlyInertia()
		if not isEngine(this) then return self:throw("Entity is not a valid ACF engine", 0) end
		if restrictInfo(self.player, this) then return 0 end

		return this.Inertia
	end

	-- Returns the mass of an ACF engine's flywheel
	[nodiscard]
	e2function number entity:acfFlyMass()
		if not isEngine(this) then return self:throw("Entity is not a valid ACF engine", 0) end
		if restrictInfo(self.player, this) then return 0 end

		return this.Inertia / pi ^ 2
	end

	-- Returns 1 if the RPM of an ACF engine is within its powerband
	[nodiscard]
	e2function number entity:acfInPowerband()
		if not isEngine(this) then return self:throw("Entity is not a valid ACF engine", 0) end
		if restrictInfo(self.player, this) then return 0 end

		local rpm = this.FlyRPM
		local pbMin, pbMax = this.PeakMinRPM, this.PeakMaxRPM

		return (rpm >= pbMin and rpm <= pbMax) and 1 or 0
	end

	-- Returns the throttle of an ACF engine
	[nodiscard]
	e2function number entity:acfThrottle()
		if not isEngine(this) then return self:throw("Entity is not a valid ACF engine", 0) end
		if restrictInfo(self.player, this) then return 0 end

		return this.Throttle
	end

	-- Sets the throttle of an ACF engine
	e2function void entity:acfThrottle(number throttle)
		if not isEngine(this) then return self:throw("Entity is not a valid ACF engine") end
		if not this:CPPICanTool(self.player, "acfmenu") then return self:throw("You cannot control this entity") end

		this:TriggerInput("Throttle", throttle)
	end

	-- Returns the total fuel remaining for an ACF engine, in liters
	[nodiscard]
	e2function number entity:acfFuelRemaining()
		if not isEngine(this) then return self:throw("Entity is not a valid ACF engine", 0) end
		if restrictInfo(self.player, this) then return 0 end

		return this.TotalFuel
	end

	__e2setcost(5)

	-- Returns an array of all fuel tanks linked to an ACF engine
	[nodiscard]
	e2function array entity:acfGetFuelTanks()
		if not isEngine(this) then return self:throw("Entity is not a valid ACF engine", {}) end
		if restrictInfo(self.player, this) then return {} end
		if not next(this.FuelLink) then return {} end

		return tableCopy(this.FuelLink)
	end
end

-- Gearbox functions
do
	__e2setcost(1)

	-- Returns the current gear of an ACF gearbox
	[nodiscard]
	e2function number entity:acfGear()
		if not isGearbox(this) then return self:throw("Entity is not a valid ACF gearbox", 0) end
		if restrictInfo(self.player, this) then return 0 end

		return this.Gear
	end

	-- Returns the number of gears in an ACF gearbox
	[nodiscard]
	e2function number entity:acfNumGears()
		if not isGearbox(this) then return self:throw("Entity is not a valid ACF gearbox", 0) end
		if restrictInfo(self.player, this) then return 0 end

		return this.Gears
	end

	-- Returns the final drive of an ACF gearbox
	[nodiscard]
	e2function number entity:acfFinalRatio()
		if not isGearbox(this) then return self:throw("Entity is not a valid ACF gearbox", 0) end
		if restrictInfo(self.player, this) then return 0 end

		return tonumber(this.GearTable["Final"])
	end

	-- Returns the total gear ratio (current * final) of an ACF gearbox
	[nodiscard]
	e2function number entity:acfTotalRatio()
		if not isGearbox(this) then return self:throw("Entity is not a valid ACF gearbox", 0) end
		if restrictInfo(self.player, this) then return 0 end

		return this.GearRatio
	end

	-- Returns the torque rating of an ACF gearbox, in Nm
	[nodiscard]
	e2function number entity:acfTorqueRating()
		if not isGearbox(this) then return self:throw("Entity is not a valid ACF gearbox", 0) end
		if restrictInfo(self.player, this) then return 0 end

		return this.MaxTorque
	end

	-- Returns whether an ACF gearbox is dual clutch
	[nodiscard]
	e2function number entity:acfIsDual()
		if not isGearbox(this) then return self:throw("Entity is not a valid ACF gearbox", 0) end
		if restrictInfo(self.player, this) then return 0 end

		return this.Dual and 1 or 0
	end

	-- Returns the time it takes an ACF gearbox to change gears, in ms
	[nodiscard]
	e2function number entity:acfShiftTime()
		if not isGearbox(this) then return self:throw("Entity is not a valid ACF gearbox", 0) end
		if restrictInfo(self.player, this) then return 0 end

		return this.SwitchTime * 1000
	end

	-- Returns 1 if an ACF gearbox is in gear
	[nodiscard]
	e2function number entity:acfInGear()
		if not isGearbox(this) then return self:throw("Entity is not a valid ACF gearbox", 0) end
		if restrictInfo(self.player, this) then return 0 end

		return this.InGear and 1 or 0
	end

	-- Returns the ratio for a specified gear of an ACF gearbox
	[nodiscard]
	e2function number entity:acfGearRatio(number gear)
		if not isGearbox(this) then return self:throw("Entity is not a valid ACF gearbox", 0) end
		if restrictInfo(self.player, this) then return 0 end

		local gear = clamp(floor(gear), 1, this.Gears)

		return tonumber(this.GearTable[gear])
	end

	-- Returns the current torque output of an ACF gearbox, in Nm
	[nodiscard]
	e2function number entity:acfTorqueOut()
		if not isGearbox(this) then return self:throw("Entity is not a valid ACF gearbox", 0) end
		if restrictInfo(self.player, this) then return 0 end

		return min(this.TotalReqTq, this.MaxTorque) / this.GearRatio
	end

	-- Sets the gear ratio of a CVT, set to 0 to use automatic calculation
	e2function void entity:acfCVTRatio(number ratio)
		if not isGearbox(this) then return self:throw("Entity is not a valid ACF gearbox") end
		if not this.CVT then return self:throw("This function can only be used on CVTs") end
		if not this:CPPICanTool(self.player, "acfmenu") then return self:throw("You cannot control this entity") end

		this.CVTRatio = clamp(ratio, 0, 1)
	end

	__e2setcost(5)

	-- Sets the current gear for an ACF gearbox
	e2function void entity:acfShift(number gear)
		if not isGearbox(this) then return self:throw("Entity is not a valid ACF gearbox") end
		if not this:CPPICanTool(self.player, "acfmenu") then return self:throw("You cannot control this entity") end

		this:TriggerInput("Gear", gear)
	end

	-- Causes an ACF gearbox to shift up
	e2function void entity:acfShiftUp()
		if not isGearbox(this) then return self:throw("Entity is not a valid ACF gearbox") end
		if not this:CPPICanTool(self.player, "acfmenu") then return self:throw("You cannot control this entity") end

		this:TriggerInput("Gear Up", 1)
	end

	-- Causes an ACF gearbox to shift down
	e2function void entity:acfShiftDown()
		if not isGearbox(this) then return self:throw("Entity is not a valid ACF gearbox") end
		if not this:CPPICanTool(self.player, "acfmenu") then return self:throw("You cannot control this entity") end

		this:TriggerInput("Gear Down", 1)
	end

	-- Sets the brakes for an ACF gearbox
	e2function void entity:acfBrake(number brake)
		if not isGearbox(this) then return self:throw("Entity is not a valid ACF gearbox") end
		if not this:CPPICanTool(self.player, "acfmenu") then return self:throw("You cannot control this entity") end

		this:TriggerInput("Brake", brake)
	end
	
	-- Sets the left brakes for an ACF gearbox
	e2function void entity:acfBrakeLeft(number brake)
		if not isGearbox(this) then return self:throw("Entity is not a valid ACF gearbox") end
		if not this.Dual then return self:throw("This gearbox is not dual clutch") end
		if not this:CPPICanTool(self.player, "acfmenu") then return self:throw("You cannot control this entity") end

		this:TriggerInput("Left Brake", brake)
	end

	-- Sets the right brakes for an ACF gearbox
	e2function void entity:acfBrakeRight(number brake)
		if not isGearbox(this) then return self:throw("Entity is not a valid ACF gearbox") end
		if not this.Dual then return self:throw("This gearbox is not dual clutch") end
		if not this:CPPICanTool(self.player, "acfmenu") then return self:throw("You cannot control this entity") end

		this:TriggerInput("Right Brake", brake)
	end

	-- Sets the clutch for an ACF gearbox
	e2function void entity:acfClutch(number clutch)
		if not isGearbox(this) then return self:throw("Entity is not a valid ACF gearbox") end
		if not this:CPPICanTool(self.player, "acfmenu") then return self:throw("You cannot control this entity") end

		this:TriggerInput("Clutch", clutch)
	end

	-- Sets the left clutch for an ACF gearbox
	e2function void entity:acfClutchLeft(number clutch)
		if not isGearbox(this) then return self:throw("Entity is not a valid ACF gearbox") end
		if not this.Dual then return self:throw("This gearbox is not dual clutch") end
		if not this:CPPICanTool(self.player, "acfmenu") then return self:throw("You cannot control this entity") end

		this:TriggerInput("Left Clutch", clutch)
	end

	-- Sets the right clutch for an ACF gearbox
	e2function void entity:acfClutchRight(number clutch)
		if not isGearbox(this) then return self:throw("Entity is not a valid ACF gearbox") end
		if not this.Dual then return self:throw("This gearbox is not dual clutch") end
		if not this:CPPICanTool(self.player, "acfmenu") then return self:throw("You cannot control this entity") end

		this:TriggerInput("Right Clutch", clutch)
	end

	-- Sets the steer ratio for an ACF double differential gearbox
	e2function void entity:acfSteerRate(number steerRate)
		if not isGearbox(this) then return self:throw("Entity is not a valid ACF gearbox") end
		if not this.DoubleDiff then return self:throw("This gearbox is not a double differential") end
		if not this:CPPICanTool(self.player, "acfmenu") then return self:throw("You cannot control this entity") end

		this:TriggerInput("Steer Rate", steerRate)
	end

	-- Applies gear hold for an automatic ACF gearbox
	e2function void entity:acfHoldGear(number holdGear)
		if not isGearbox(this) then return self:throw("Entity is not a valid ACF gearbox") end
		if not this.Auto then return self:throw("This gearbox is not automatic") end
		if not this:CPPICanTool(self.player, "acfmenu") then return self:throw("You cannot control this entity") end

		this:TriggerInput("Hold Gear", holdGear)
	end

	-- Sets the shift point scaling for an automatic ACF gearbox
	e2function void entity:acfShiftPointScale(number scale)
		if not isGearbox(this) then return self:throw("Entity is not a valid ACF gearbox") end
		if not this.Auto then return self:throw("This gearbox is not automatic") end
		if not this:CPPICanTool(self.player, "acfmenu") then return self:throw("You cannot control this entity") end

		this:TriggerInput("Shift Speed Scale", scale)
	end
end

-- Gun functions
do
	__e2setcost(1)

	-- Returns 1 if the ACF gun or rack is ready to fire
	[nodiscard]
	e2function number entity:acfReady()
		if not (isGun(this) or isRack(this)) then return self:throw("Entity is not a valid ACF gun or rack", 0) end
		if restrictInfo(self.player, this) then return 0 end

		return this.Ready and 1 or 0
	end

	-- Returns the reload duration of an ACF weapon
	[nodiscard]
	e2function number entity:acfReloadTime()
		if not isGun(this) then return self:throw("Entity is not a valid ACF gun", 0) end
		if restrictInfo(self.player, this) then return 0 end

		return this.ReloadTime
	end

	__e2setcost(2)

	-- Returns a number from 0 to 1 representing the reload progress of an ACF weapon
	[nodiscard]
	e2function number entity:acfReloadProgress()
		if not isGun(this) then return self:throw("Entity is not a valid ACF gun", 0) end
		if restrictInfo(self.player, this) then return 0 end

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

	__e2setcost(1)

	-- Returns the time it takes for an ACF weapon to reload its magazine
	[nodiscard]
	e2function number entity:acfMagReloadTime()
		if not isGun(this) then return self:throw("Entity is not a valid ACF gun", 0) end
		if restrictInfo(self.player, this) then return 0 end

		return this.MagReload
	end

	-- Returns the magazine size of an ACF gun
	[nodiscard]
	e2function number entity:acfMagSize()
		if not isGun(this) then return self:throw("Entity is not a valid ACF gun", 0) end
		if restrictInfo(self.player, this) then return 0 end

		return this.MagSize
	end

	-- Returns the spread for an ACF gun or flechette ammo
	[nodiscard]
	e2function number entity:acfSpread()
		if not (isGun(this) or isAmmo(this)) then return self:throw("Entity is not a valid ACF gun or ammo crate", 0) end
		if restrictInfo(self.player, this) then return 0 end

		local spread = this.GetInaccuracy and this:GetInaccuracy() or this.Inaccuracy or 0

		if this.BulletData["Type"] == "FL" then
			return spread + (this.BulletData["FlechetteSpread"] or 0)
		end

		return spread
	end

	-- Returns 1 if an ACF gun is reloading
	[nodiscard]
	e2function number entity:acfIsReloading()
		if not isGun(this) then return self:throw("Entity is not a valid ACF gun", 0) end
		if restrictInfo(self.player, this) then return 0 end

		if not this.Ready then
			if this.MagSize == 1 then
				return 1
			else
				return this.CurrentShot >= this.MagSize and 1 or 0
			end
		end

		return 0
	end

	-- Returns the fire rate of an ACF gun
	[nodiscard]
	e2function number entity:acfFireRate()
		if not isGun(this) then return self:throw("Entity is not a valid ACF gun", 0) end
		if restrictInfo(self.player, this) then return 0 end

		return round(this.RateOfFire, 3)
	end

	__e2setcost(2)

	-- Sets the rate of fire limit of an ACF gun
	e2function void entity:acfSetROFLimit(number rate)
		if not isGun(this) then return self:throw("Entity is not a valid ACF gun") end
		if not this:CPPICanTool(self.player, "acfmenu") then return self:throw("You cannot control this entity") end

		this:TriggerInput("ROFLimit", rate)
	end

	__e2setcost(1)

	-- Returns the number of rounds left in a magazine of an ACF gun
	[nodiscard]
	e2function number entity:acfMagRounds()
		if not isGun(this) then return self:throw("Entity is not a valid ACF gun", 0) end
		if restrictInfo(self.player, this) then return 0 end

		if this.MagSize > 1 then
			return this.MagSize - this.CurrentShot
		end

		if this.Ready and this.BulletData.Type ~= "Empty" then return 1 end

		return 0
	end

	__e2setcost(2)

	-- Sets the firing state of an ACF gun or rack
	e2function void entity:acfFire(number fire)
		if not (isGun(this) or isRack(this)) then return self:throw("Entity is not a valid ACF gun or rack") end
		if not this:CPPICanTool(self.player, "acfmenu") then return self:throw("You cannot control this entity") end

		this:TriggerInput("Fire", fire)
	end

	-- Unloads an ACF gun
	e2function void entity:acfUnload()
		if not isGun(this) then return self:throw("Entity is not a valid ACF gun") end
		if not this:CPPICanTool(self.player, "acfmenu") then return self:throw("You cannot control this entity") end

		this:UnloadAmmo()
	end

	-- Reloads an ACF gun
	e2function void entity:acfReload()
		if not isGun(this) then return self:throw("Entity is not a valid ACF gun") end
		if not this:CPPICanTool(self.player, "acfmenu") then return self:throw("You cannot control this entity") end

		local isEmpty = this.BulletData.Type == "Empty"

		if isEmpty and not this.Reloading then
			this:LoadAmmo(false, true)
			this.Reloading = true
		end
	end

	__e2setcost(5)

	-- Returns an array of all crew seats linked to the ACF entity
	[nodiscard]
	e2function array entity:acfGetCrew()
		if not (isGun(this) or isEngine(this)) then return self:throw("Entity is not a valid ACF gun or engine", {}) end
		if restrictInfo(self.player, this) then return {} end
		if not next(this.CrewLink) then return {} end

		return tableCopy(this.CrewLink)
	end

	-- Returns an array of all ammo crates linked to the ACF entity
	[nodiscard]
	e2function array entity:acfGetAmmoCrates()
		if not (isGun(this) or isRack(this)) then return self:throw("Entity is not a valid ACF gun or rack", {}) end
		if restrictInfo(self.player, this) then return {} end
		if not next(this.AmmoLink) then return {} end

		return tableCopy(this.AmmoLink)
	end

	__e2setcost(10)

	-- Returns the number of rounds of an ACF Ammo Crate
	[nodiscard]
	e2function number entity:acfMunitions()
		if not isAmmo(this) then return self:throw("You can get the count from Ammo Crates only.", 0) end
		if restrictInfo(self.player, this) then return 0 end

		return this.Ammo
	end

	-- Returns the number of rounds in active ammo crates linked to an ACF gun or rack.
	[nodiscard]
	e2function number entity:acfAmmoCount()
		if not (isGun(this) or isRack(this)) then return self:throw("Only Guns, Racks and Ammo Crates are valid.", 0) end
		if restrictInfo(self.player, this) then return 0 end

		local count = 0

		for _, v in pairs(this.AmmoLink) do
			if IsValid(v) and v.Load then
				count = count + v.Ammo
			end
		end

		return count
	end

	-- Returns the number of rounds in all ammo crates linked to an ACF gun or rack, regardless of whether they are active or not.
	[nodiscard]
	e2function number entity:acfTotalAmmoCount()
		if not (isGun(this) or isRack(this)) then return self:throw("Only Guns, Racks and Ammo Crates are valid.", 0) end
		if restrictInfo(self.player, this) then return 0 end

		local count = 0

		for _, v in pairs(this.AmmoLink) do
			if IsValid(v) then
				count = count + v.Ammo
			end
		end

		return count
	end

	__e2setcost(2)

	-- Returns a string representing the state of the ACF gun
	[nodiscard]
	e2function string entity:acfState()
		if not isGun(this) then return self:throw("Entity is not a valid ACF gun", "") end
		if restrictInfo(self.player, this) then return "" end

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
	__e2setcost(1)

	-- Returns the number of rounds left in an ACF ammo crate
	[nodiscard]
	e2function number entity:acfRounds()
		if not isAmmo(this) then return self:throw("Entity is not a valid ACF ammo crate", 0) end
		if restrictInfo(self.player, this) then return 0 end

		return this.Ammo
	end

	-- Returns the type of weapon the ammo in an ACF ammo crate loads into
	[nodiscard]
	e2function string entity:acfRoundType()
		if not isAmmo(this) then return self:throw("Entity is not a valid ACF ammo crate", "") end
		if restrictInfo(self.player, this) then return "" end

		return this.RoundType
	end

	-- Returns the type of ammo in a crate or gun
	[nodiscard]
	e2function string entity:acfAmmoType()
		if not (isAmmo(this) or isGun(this)) then return self:throw("Entity is not a valid ACF ammo crate or gun", "") end
		if restrictInfo(self.player, this) then return "" end

		return this.BulletData.Type
	end

	-- Returns the caliber of an ammo crate or gun
	[nodiscard]
	e2function number entity:acfCaliber()
		if not (isAmmo(this) or isGun(this)) then return self:throw("Entity is not a valid ACF ammo crate or gun", 0) end
		if restrictInfo(self.player, this) then return 0 end

		return this.Caliber * 10
	end

	-- Returns the muzzle velocity of the ammo in an ACF ammo crate or gun
	[nodiscard]
	e2function number entity:acfMuzzleVel()
		if not (isAmmo(this) or isGun(this)) then return self:throw("Entity is not a valid ACF ammo crate or gun", 0) end
		if restrictInfo(self.player, this) then return 0 end

		return round((this.BulletData.MuzzleVel or 0) * ACF.VelScale, 3)
	end

	-- Returns the projectile mass of the ammo in an ACF ammo crate or gun
	[nodiscard]
	e2function number entity:acfProjectileMass()
		if not (isAmmo(this) or isGun(this)) then return self:throw("Entity is not a valid ACF ammo crate or gun", 0) end
		if restrictInfo(self.player, this) then return 0 end

		return round(this.BulletData.ProjMass or 0, 3)
	end

	-- Returns the number of projectiles in a flechette round in an ACF ammo crate or gun
	[nodiscard]
	e2function number entity:acfFLSpikes()
		if not (isAmmo(this) or isGun(this)) then return self:throw("Entity is not a valid ACF ammo crate or gun", 0) end
		if restrictInfo(self.player, this) then return 0 end

		return this.BulletData.Flechettes or 0
	end

	-- Returns the mass of a single spike in a flechette round in an ACF ammo crate or gun
	[nodiscard]
	e2function number entity:acfFLSpikeMass()
		if not (isAmmo(this) or isGun(this)) then return self:throw("Entity is not a valid ACF ammo crate or gun", 0) end
		if restrictInfo(self.player, this) then return 0 end

		return round(this.BulletData.FlechetteMass or 0, 3)
	end

	-- Returns the radius of the spikes in a flechette round, in mm
	[nodiscard]
	e2function number entity:acfFLSpikeRadius()
		if not (isAmmo(this) or isGun(this)) then return self:throw("Entity is not a valid ACF ammo crate or gun", 0) end
		if restrictInfo(self.player, this) then return 0 end

		return round((this.BulletData.FlechetteRadius or 0) * 10, 3)
	end

	-- Returns the drag coefficient of ammo contained in an ACF ammo crate or gun
	[nodiscard]
	e2function number entity:acfDragCoef()
		if not (isAmmo(this) or isGun(this)) then return self:throw("Entity is not a valid ACF ammo crate or gun", 0) end
		if restrictInfo(self.player, this) then return 0 end

		return (this.BulletData.DragCoef or 0) / ACF.DragDiv
	end

	__e2setcost(2)

	-- Returns the penetration of a round in an ACF ammo crate or gun
	[nodiscard]
	e2function number entity:acfPenetration()
		if not (isAmmo(this) or isGun(this)) then return self:throw("Entity is not a valid ACF ammo crate or gun", 0) end
		if restrictInfo(self.player, this) then return 0 end
		if not ACE_CheckRound(this.BulletData.Type) then return 0 end

		return ACF.RoundTypes[this.BulletData.Type].getDisplayData(this.BulletData).MaxPen or 0
	end

	-- Returns the penetration of a round in an ACF ammo crate or gun, with an index to check penetration for THEAT (uses indexes 1 and 2)
	[nodiscard]
	e2function number entity:acfPenetration(number index)
		if not (isAmmo(this) or isGun(this)) then return self:throw("Entity is not a valid ACF ammo crate or gun", 0) end
		if restrictInfo(self.player, this) then return 0 end
		if not ACE_CheckRound(this.BulletData.Type) then return 0 end

		local displayData = ACF.RoundTypes[this.BulletData.Type].getDisplayData(this.BulletData)

		if index == 1 then
			return displayData.MaxPen or 0
		elseif index == 2 then
			return displayData.MaxPen2 or 0
		end

		return 0
	end

	-- Returns the blast radius of an HE, APHE, or HEAT round in an ACF ammo crate or gun
	[nodiscard]
	e2function number entity:acfBlastRadius()
		if not (isAmmo(this) or isGun(this)) then return self:throw("Entity is not a valid ACF ammo crate or gun", 0) end
		if restrictInfo(self.player, this) then return 0 end
		if not ACE_CheckRound(this.BulletData.Type) then return 0 end

		local type = this.BulletData.Type

		if type == "HE" or type == "APHE" then
			return round(this.BulletData.FillerMass ^ 0.33 * 8, 3)
		elseif type == "HEAT" then
			return round((this.BulletData.FillerMass / 3) ^ 0.33 * 8, 3)
		end

		return 0
	end
end

-- Armor functions
do
	__e2setcost(1)

	-- Returns the effective armor given an armor value and hit angle
	[nodiscard]
	e2function number acfEffectiveArmor(number armor, number angle)
		local eff = armor / abs(cos(rad(min(angle, 89.999))))

		return round(eff, 1)
	end

	__e2setcost(5)

	-- Returns the current health of an entity
	[nodiscard]
	e2function number entity:acfPropHealth()
		if not validPhysics(this) then return self:throw("Entity is not valid", 0) end
		if restrictInfo(self.player, this) then return 0 end
		if not this.ACF or not this.ACF.Health then
			local check = ACF_Check(this)

			if not check then return 0 end
		end

		return round(this.ACF.Health, 3)
	end

	-- Returns the current armor of an entity
	[nodiscard]
	e2function number entity:acfPropArmor()
		if not validPhysics(this) then return self:throw("Entity is not valid", 0) end
		if restrictInfo(self.player, this) then return 0 end
		if not this.ACF or not this.ACF.Armour then
			local check = ACF_Check(this)

			if not check then return 0 end
		end

		return round(this.ACF.Armour, 3)
	end

	-- Returns the max health of an entity
	[nodiscard]
	e2function number entity:acfPropHealthMax()
		if not validPhysics(this) then return self:throw("Entity is not valid", 0) end
		if restrictInfo(self.player, this) then return 0 end
		if not this.ACF or not this.ACF.MaxHealth then
			local check = ACF_Check(this)

			if not check then return 0 end
		end

		return round(this.ACF.MaxHealth, 3)
	end

	-- Returns the max armor of an entity
	[nodiscard]
	e2function number entity:acfPropArmorMax()
		if not validPhysics(this) then return self:throw("Entity is not valid", 0) end
		if restrictInfo(self.player, this) then return 0 end
		if not this.ACF or not this.ACF.MaxArmour then
			local check = ACF_Check(this)

			if not check then return 0 end
		end

		return round(this.ACF.MaxArmour, 3)
	end

	-- Returns the ductility of an entity
	[nodiscard]
	e2function number entity:acfPropDuctility()
		if not validPhysics(this) then return self:throw("Entity is not valid", 0) end
		if restrictInfo(self.player, this) then return 0 end
		if not this.ACF then
			local check = ACF_Check(this)

			if not check then return 0 end
		end

		return round(this.ACF.Ductility, 3)
	end

	-- Returns the effective armor from a trace hitting a prop
	[nodiscard]
	e2function number ranger:acfEffectiveArmor()
		local ent = this.Entity
		if not (this and validPhysics(ent)) then return self:throw("Entity is not valid", 0) end
		if restrictInfo(self.player, ent) then return 0 end
		if not ent.ACF then
			local check = ACF_Check(ent)

			if not check then return 0 end
		end

		local eff = ent.ACF.Armour / abs(cos(rad(ACF_GetHitAngle(this.HitNormal, this.HitPos - this.StartPos))))
		return round(eff, 1)
	end

	-- Returns the material of an entity
	[nodiscard]
	e2function string entity:acfPropMaterial()
		if not validPhysics(this) then return self:throw("Entity is not valid", "") end
		if restrictInfo(self.player, this) then return "" end
		if not this.ACF then
			local check = ACF_Check(this)

			if not check then return "" end
		end

		return this.ACF.Material
	end

	__e2setcost(10)

	-- Returns a table containing the armor data of an entity
	[nodiscard]
	e2function table entity:acfPropArmorData()
		local ret = E2Lib.newE2Table()
		
		if not validPhysics(this) then return self:throw("Entity is not valid", ret) end
		if restrictInfo(self.player, this) then return ret end
		if not this.ACF then
			local check = ACF_Check(this)

			if not check then return ret end
		end

		local mat = this.ACF.Material
		if not mat then return ret end

		local matData = ACE.ArmorTypes[mat]
		if not matData then return ret end

		ret.size = 4

		ret.s.Curve = matData.curve
		ret.stypes.Curve = "n"

		ret.s.Effectiveness = matData.effectiveness
		ret.stypes.Effectiveness = "n"

		ret.s.HEATeffectiveness = matData.HEATeffectiveness or matData.effectiveness
		ret.stypes.HEATeffectiveness = "n"

		ret.s.Material = mat
		ret.stypes.Material = "s"

		return ret
	end

	__e2setcost(50)

	-- Sets the ACF armor, ductility, and material of an entity
	[nodiscard]
	e2function void entity:aceSetArmorProperties(number thickness, number ductility, string material)
		local ret = E2Lib.newE2Table()
		
		if not validPhysics(this) then return self:throw("Entity is not valid", ret) end
		if restrictInfo(self.player, this) then return end

		if not this.ACF then
			local check = ACF_Check(this)

			if not check then return end
		end

		local matData = ACE.ArmorTypes[material]
		if not matData then return end

		E2SetACEArmor(this, thickness, ductility, material)

		return
	end

end

-- Fuel functions
do
	__e2setcost(1)

	-- Returns 1 if the ACF engine requires fuel to run
	[nodiscard, deprecated = "All engines require fuel now"]
	e2function number entity:acfFuelRequired()
		return 1
	end

	__e2setcost(2)

	-- Sets the ACF fuel tank "refuel duty" state, which allows it to refuel other fuel tanks
	e2function void entity:acfRefuelDuty(number state)
		if not isFuel(this) then return self:throw("Entity is not a valid ACF fuel tank") end
		if not this:CPPICanTool(self.player, "acfmenu") then return self:throw("You cannot control this entity") end

		this:TriggerInput("Refuel Duty", state)
	end

	-- Returns the remaining fuel, in liters or kilowatt-hours, of an ACF engine or fuel tank
	[nodiscard]
	e2function number entity:acfFuel()
		if not (isEngine(this) or isFuel(this)) then return self:throw("Entity is not a valid ACF engine or fuel tank", 0) end
		if restrictInfo(self.player, this) then return 0 end

		if this:GetClass() == "acf_fueltank" then
			return round(this.Fuel, 3)
		else
			if not next(this.FuelLink) then return 0 end

			local fuel = 0

			for _, tank in pairs(this.FuelLink) do
				if validPhysics(tank) and tank.Active then
					fuel = fuel + tank.Fuel
				end
			end

			return round(fuel, 3)
		end
	end

	-- Returns the remaining fuel in an ACF engine or fuel tank as a percentage of its total capacity
	[nodiscard]
	e2function number entity:acfFuelLevel()
		if not (isEngine(this) or isFuel(this)) then return self:throw("Entity is not a valid ACF engine or fuel tank", 0) end
		if restrictInfo(self.player, this) then return 0 end

		if this:GetClass() == "acf_fueltank" then
			return round(this.Fuel / this.Capacity, 3)
		else
			if not next(this.FuelLink) then return 0 end

			local fuel = 0
			local capacity = 0

			for _, tank in pairs(this.FuelLink) do
				if validPhysics(tank) and tank.Active then
					fuel = fuel + tank.Fuel
					capacity = capacity + tank.Capacity
				end
			end

			if capacity == 0 then return 0 end

			return round(fuel / capacity, 3)
		end
	end

	-- Returns the current fuel consumption in liters or kilowatts per minute of an ACF engine
	[nodiscard]
	e2function number entity:acfFuelUse()
		if not isEngine(this) then return self:throw("Entity is not a valid ACF engine", 0) end
		if restrictInfo(self.player, this) then return 0 end
		if not next(this.FuelLink) then return 0 end

		local tank
		for _, v in pairs(this.FuelLink) do
			if validPhysics(v) and v.Active and v.Fuel > 0 then
				tank = v
				break
			end
		end

		if not tank then return 0 end

		local consumption
		if this.FuelType == "Electric" then
			Consumption = 60 * (this.Torque * this.FlyRPM / 9548.8) * this.FuelUse
		else
			local Load = 0.3 + this.Throttle * 0.7
			Consumption = 60 * Load * this.FuelUse * (this.FlyRPM / this.PeakKwRPM) / ACF.FuelDensity[Tank.FuelType]
		end

		return round(Consumption, 3)
	end

	-- Returns the peak fuel consumption in liters or kilowatts per minute of an ACF engine at powerband max
	[nodiscard]
	e2function number entity:acfPeakFuelUse()
		if not isEngine(this) then return self:throw("Entity is not a valid ACF engine", 0) end
		if restrictInfo(self.player, this) then return 0 end
		if not next(this.FuelLink) then return 0 end

		local fuel = "Petrol"
		local tank
		for _, v in pairs(this.FuelLink) do
			if validPhysics(v) and v.Active and v.Fuel > 0 then
				tank = v
				fuel = v.Fuel
				break
			end
		end

		local consumption
		if this.FuelType == "Electric" then
			consumption = 60 * (this.PeakTorque * this.LimitRPM / (4 * 9548.8)) * this.FuelUse
		else
			local Load = 0.3 + this.Throttle * 0.7
			Consumption = 60 * this.FuelUse / ACF.FuelDensity[fuel]
		end

		return round(consumption, 3)
	end
end

-- Radar functions
do
	__e2setcost(10)

	-- Returns a table containing all data from an ACF radar entity
	e2function table entity:acfRadarData()
		local ret = E2Lib.newE2Table()

		if not isRadar(this) then return self:throw("Entity is not a valid ACF radar", ret) end
		if restrictInfo(self, this) then return ret end
		local radarType = this:GetClass()

		ret.s.Detected = this.OutputData.Detected
		ret.stypes.Detected = "n"

		ret.s.Position = table.Copy(this.OutputData.Position)
		ret.stypes.Position = "r"

		if radarType == "acf_missileradar" then
			ret.s.ClosestDistance = this.OutputData.ClosestDistance
			ret.stypes.ClosestDistance = "n"

			ret.s.Entities = table.Copy(this.OutputData.Entities)
			ret.stypes.Entities = "r"

			ret.s.Velocity = table.Copy(this.OutputData.Velocity)
			ret.stypes.Velocity = "r"

			ret.size = 5
		elseif radarType == "ace_trackingradar" or "ace_irst" then
			ret.s.Owner = table.Copy(this.OutputData.Owner)
			ret.stypes.Owner = "r"

			ret.s.ClosestToBeam = this.OutputData.ClosestToBeam
			ret.stypes.ClosestToBeam = "n"

			if radarType == "ace_trackingradar" then
				ret.s.Velocity = table.Copy(this.OutputData.Velocity)
				ret.stypes.Velocity = "r"

				ret.s.IsJammed = this.OutputData.IsJammed
				ret.stypes.IsJammed = "n"
			elseif radarType == "ace_irst" then
				ret.s.Angle = table.Copy(this.OutputData.Angle)
				ret.stypes.Angle = "r"

				ret.s.EffHeat = table.Copy(this.OutputData.EffHeat)
				ret.stypes.EffHeat = "r"
			end

			ret.size = 6
		end

		return ret
	end
end