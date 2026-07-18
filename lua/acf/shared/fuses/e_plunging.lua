ACF = ACF or {}
ACF.Fuse = ACF.Fuse or {}

local ClassName = "Plunging"

local this = ACF.Fuse[ClassName] or inherit.NewSubOf(ACF.Fuse.Contact)
ACF.Fuse[ClassName] = this

---



this.Name = ClassName


this.Distance = 0.1
this.Delay	= 0.1


this.desc = "This fuse modifies the heatjet direction, sending the charge down, allowing strikes from above. Note using this will make direct hits useless for HEAT missiles.\n\nOnly works with HEAT."


-- Configuration information for things like acfmenu.
this.Configurable = this:super() and table.Copy(this:super().Configurable) or {}


local configs = this.Configurable

configs[#configs + 1] = {

	Name		= "Distance",				-- name of the variable to change

	DisplayName = "Distance (in inches)",				-- name displayed to the user
	CommandName = "Ds",						-- shorthand name used in console commands

	Type		= "number",					-- lua type of the configurable variable
	Min		= 1,							-- number specific: minimum value
	Max		= 10000						-- number specific: maximum value

	-- in future if needed: min/max getter function based on munition type.  useful for modifying radar cones?
}

configs[#configs + 1] = {

	Name		= "Delay",					-- name of the variable to change

	DisplayName = "Detonation delay (in seconds)",		-- name displayed to the user
	CommandName = "Dd",						-- shorthand name used in console commands

	Type		= "number",					-- lua type of the configurable variable
	Min		= 0,						-- number specific: minimum value
	Max		= 2							-- number specific: maximum value

	-- in future if needed: min/max getter function based on munition type.  useful for modifying radar cones?
}

-- Do nothing, projectiles auto-detonate on contact anyway.
function this:GetDetonate(missile)

	if not self:IsArmed() then return false end

	local missilePos = missile:GetPos()

	local tracedata = {
		start	= missilePos,
		endpos  = missilePos + missile:GetUp() * -self.Distance,
		filter  = missile.Filter or missile,
	}
	local trace = util.TraceLine(tracedata)

	if trace.Hit and IsValid(trace.Entity) and not ACF.HEFilter[trace.Entity:GetClass()] then

		timer.Simple(self.Delay, function()
			if not IsValid(missile) then return end
			missile.PlungingDetonation = true
			missile.Flight = missile:GetUp() * -missile.Flight:Length() * 0.01

			missile.Bulletdata2.SlugMV = missile.Bulletdata2.SlugMV * 0.3
			missile.Bulletdata2.SlugMV2 = missile.Bulletdata2.SlugMV2 * 0.3

			missile:SetAngles(missile.Flight:Angle())
			missile:Detonate()
			return
		end)

	end

	return false
end

--[[
function this:PerformDetonation( missile, bdata, phys, pos )

	--HEAT system breaks and it becomes unusable. THEAT cannot be used until a proof can justify it. Really tandem doesn't exist since it's an Explosively formed penetrator.
	if not missile.PlungingDetonation or bdata.Type == "THEAT" then
		bdata.Type = "HE"
	end

	bdata.Flight = missile:GetUp() * - 200

	bdata.Owner = bdata.Owner or missile.Owner
	bdata.Pos	= pos + (missile.DetonateOffset or bdata.Flight)

	--Simple way to reduce penetration.
	bdata.PenArea = bdata.PenArea * ACF.HEATPlungingReduction

	bdata.NoOcc =	missile
	bdata.Gun	=	missile

	bdata.Filter = bdata.Filter or {}
	table.insert( bdata.Filter, missile )

	bdata.RoundMass = bdata.RoundMass or bdata.ProjMass
	bdata.ProjMass  = bdata.ProjMass or bdata.RoundMass

	bdata.HandlesOwnIteration = nil

	ACE.Missile_BulletLaunch(bdata)

	missile:SetSolid(SOLID_NONE)
	phys:EnableMotion(false)

	missile:DoReplicatedPropHit(bdata)
	missile:SetNoDraw(true)

end
]]--

function this:GetDisplayConfig()
	return
	{
		["Arming delay"]	= math.Round(self.Primer, 3) .. " s",
		["Ignition Delay"] = math.Round(self.StartDelay, 3) .. " s",
		["Distance"]		= math.Round(self.Distance / 39.37, 1) .. " m",
		["Detonation Delay"]  = tostring(math.Round(self.Delay, 3)) .. " s"
	}
end
