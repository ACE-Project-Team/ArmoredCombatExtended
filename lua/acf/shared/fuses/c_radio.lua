
local ClassName = "Radio"


ACF = ACF or {}
ACF.Fuse = ACF.Fuse or {}

local this = ACF.Fuse[ClassName] or inherit.NewSubOf(ACF.Fuse.Contact)
ACF.Fuse[ClassName] = this

---



this.Name = ClassName

-- The entity to measure distance to.
this.Target = nil

-- the fuse may trigger at some point under this range - unless it's travelling so fast that it steps right on through.
this.Distance = 2000


this.desc = "This fuse tracks around the missile itself in a radius detonating as soon as a target enters the radius. This may lead to early detonations.\n Useful for countering flares at the cost of detonating further from the target.\nDistance in inches." --This fuse tracks the guidance module's target and detonates when the distance becomes low enough.\nDistance in inches.


-- Configuration information for things like acfmenu.
this.Configurable = table.Copy(this:super().Configurable)

local configs = this.Configurable

configs[#configs + 1] =
{
	Name = "Distance",		-- name of the variable to change
	DisplayName = "Distance",	-- name displayed to the user
	CommandName = "Ds",		-- shorthand name used in console commands

	Type = "number",			-- lua type of the configurable variable
	Min = 0,					-- number specific: minimum value
	Max = 10000				-- number specific: maximum value

	-- in future if needed: min/max getter function based on munition type.  useful for modifying radar cones?
}

do

	local whitelist = {
		[ "acf_rack" ]				= true,
		[ "prop_vehicle_prisoner_pod" ] = true,
		[ "ace_crewseat_gunner" ]	= true,
		[ "ace_crewseat_loader" ]	= true,
		[ "ace_crewseat_driver" ]	= true,
		[ "ace_rwr_dir" ]			= true,
		[ "ace_rwr_sphere" ]			= true,
		[ "acf_missileradar" ]		= true,
		[ "acf_opticalcomputer" ]	= true,
		[ "gmod_wire_expression2" ]	= true,
		[ "gmod_wire_gate" ]			= true,
		[ "prop_physics" ]			= true,
		[ "ace_ecm" ]				= true,
		[ "ace_trackingradar" ]		= true,
		[ "ace_irst" ]				= true,
		[ "acf_gun" ]				= true,
		[ "acf_ammo" ]				= true,
		[ "acf_engine" ]				= true,
		[ "acf_fueltank" ]			= true,
		[ "acf_gearbox" ]			= true,
		[ "primitive_shape" ]		= true,
		[ "primitive_airfoil" ]		= true,
		[ "primitive_rail_slider" ]	= true,
		[ "primitive_slider" ]		= true,
		[ "primitive_ladder" ]		= true
	}

	local function FilterFunction(ent)

		local Class = ent:GetClass()

		-- Return true to skip entities that are not valid radio fuze targets.
		return not whitelist[Class]
	end

	function this:Configure(Missile)
		self:super().Configure(self, Missile)
		Missile.DPos = Missile:GetPos()
	end

	--Question: Should radio fuze be limited to detect props in front of the missile only? Its weird it detonates by detecting something behind it.
	function this:GetDetonate(missile)

		local CPPIOwn = missile:CPPIGetOwner()

		if not self:IsArmed() then return false end

		local MissilePos = missile.CurPos or missile:GetPos()

		for _, HitEnt in ipairs(ents.FindInSphere(MissilePos, self.Distance)) do
			if not IsValid(HitEnt) or HitEnt == missile then continue end
			if FilterFunction(HitEnt) then continue end

			if CPPIOwn == HitEnt:CPPIGetOwner() then continue end

			local HitPos = HitEnt:NearestPoint(MissilePos)
			local tolocal = missile:WorldToLocal(HitPos)
			if tolocal.x <= 0 then continue end

			if CFW then
				local conLauncher = missile.Launcher and missile.Launcher:CFW_GetContraption() or nil
				local conTarget = HitEnt:CFW_GetContraption() or nil

				if conLauncher and conTarget and conLauncher == conTarget then
					continue
				end
			else
				local HitId = HitEnt.ACF and HitEnt.ACF.ContraptionId or nil
				local OwnId = missile.ContrapId or nil

				if HitId and OwnId and HitId == OwnId then
					continue
				end
			end

			return true
		end

		return false
	end
end


function this:GetDisplayConfig()
	return
	{
		["Arming delay"] = math.Round(self.Primer, 3) .. " s",
		["Ignition Delay"] = math.Round(self.StartDelay, 3) .. " s",
		["Distance"] = math.Round(self.Distance / 39.37, 1) .. " m"
	}
end
