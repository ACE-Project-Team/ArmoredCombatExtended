
ACE = ACE or {}
ACE.Fuse = ACE.Fuse or {}

local ClassName = "Optical"

local this = ACE.Fuse[ClassName] or inherit.NewSubOf(ACE.Fuse.Contact)
ACE.Fuse[ClassName] = this

---



this.Name = ClassName


this.Distance = 2000


this.desc = "This fuse fires a beam directly ahead and detonates when the beam hits something close-by.\nDistance in inches."


-- Configuration information for things like acemenu.
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




-- Do nothing, projectiles auto-detonate on contact anyway.
function this:GetDetonate(missile)

	if not self:IsArmed() then return false end

	local missilePos = missile:GetPos()

	local tracedata =
	{
		start = missilePos,
		endpos = missilePos + missile:GetForward() * self.Distance,
		filter = missile.Filter or missile,
		mins = Vector(0,0,0),
		maxs = Vector(0,0,0)
	}
	local trace = util.TraceHull(tracedata)

	if IsValid(trace.Entity) and (trace.Entity:GetClass() == "ace_missile" ) then return false end

	return trace.Hit

end



function this:GetDisplayConfig()
	return
	{
		["Arming delay"] = math.Round(self.Primer, 3) .. " s",
		["Ignition Delay"] = math.Round(self.StartDelay, 3) .. " s",
		["Distance"] = math.Round(self.Distance / 39.37, 1) .. " m"
	}
end
