
local ClassName = "Contact"


ACE = ACE or {}
ACE.Fuse = ACE.Fuse or {}

local this = ACE.Fuse[ClassName] or inherit.NewBaseClass()
ACE.Fuse[ClassName] = this

---



this.Name = ClassName

this.desc = "This fuse triggers upon direct contact against solid surfaces."

this.Primer = 0
this.StartDelay = 0

-- Configuration information for things like acemenu.
this.Configurable =
{
	{
		Name		= "Primer",						-- name of the variable to change
		DisplayName = "Arming Delay (in seconds)",	-- name displayed to the user
		CommandName = "AD",							-- shorthand name used in console commands

		Type		= "number",						-- lua type of the configurable variable
		Min		= 0,								-- number specific: minimum value
		--MinConfig	= "armdelay",					-- round specific override for minimum value
		Max		= 2								-- number specific: maximum value

		-- in future if needed: min/max getter function based on munition type.  useful for modifying radar cones?
	},
	{
		Name = "StartDelay",		-- name of the variable to change
		DisplayName = "Ignition Delay (in seconds)",	-- name displayed to the user
		CommandName = "Id",		-- shorthand name used in console commands

		Type = "number",			-- lua type of the configurable variable
		Min = 0,					-- number specific: minimum value
		Max = 5				-- number specific: maximum value
	}
}

function this:Init()
	self.TimeStarted = nil
end


function this:IsArmed()
	return self.TimeStarted and (self.TimeStarted + self.Primer <= CurTime()) or false
end


function this:Configure(Missile)
	self.TimeStarted = CurTime()
	Missile.IgnitionDelay = self.StartDelay
	self.Primer = math.max(Missile.MinStartDelay,self.Primer)
end


-- Do nothing, projectiles auto-detonate on contact anyway.
function this:GetDetonate()
	return false
end

function this:PerformDetonation( missile, bdata, phys, pos )

	bdata.Owner = bdata.Owner or missile.Owner
	bdata.Pos	= pos + (missile.DetonateOffset or bdata.Flight:GetNormalized()) * 20

	bdata.NoOcc =	missile
	bdata.Gun	=	missile

	if bdata.Filter then bdata.Filter[#bdata.Filter + 1] = missile else bdata.Filter = {missile} end

	bdata.RoundMass = bdata.RoundMass or bdata.ProjMass
	bdata.ProjMass  = bdata.ProjMass or bdata.RoundMass

	bdata.HandlesOwnIteration = nil

	ACE_Missile_BulletLaunch(bdata)

	missile:SetSolid(SOLID_NONE)
	phys:EnableMotion(false)

	missile:DoReplicatedPropHit(bdata)
	missile:SetNoDraw(true)
end

function this:GetDisplayConfig()
	return {
		["Arming delay"] = math.Round(self.Primer, 3) .. " s",
		["Ignition Delay"] = math.Round(self.StartDelay, 3) .. " s"
	}
end
