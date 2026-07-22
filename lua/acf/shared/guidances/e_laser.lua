
local ClassName = "Laser"


ACE = ACE or {}
ACE.Guidance = ACE.Guidance or {}

local this = ACE.Guidance[ClassName] or inherit.NewSubOf(ACE.Guidance.Wire)
ACE.Guidance[ClassName] = this

this.Name = ClassName

-- Cone to retain targets within.
this.ViewCone = 30

this.desc = "This guidance package reads a target-position from the launcher and guides the munition towards it."




function this:Init()

end




function this:Configure(missile)

	self:super().Configure(self, missile)

	self.ViewCone = ACE_GetGunValue(missile.BulletData, "viewcone") or this.ViewCone
	self.ViewConeCos = math.cos(math.rad(self.ViewCone))

end




function this:GetGuidance(missile)

	local posVec = missile.Launcher.TargPos

	if not posVec or type(posVec) ~= "Vector" or posVec == Vector() then
		return {TargetPos = nil}
	end

	if posVec then
		local mfo	= missile:GetForward()
		local mdir	= (posVec - missile:GetPos()):GetNormalized()
		local dot	= mfo.x * mdir.x + mfo.y * mdir.y + mfo.z * mdir.z

		if dot < self.ViewConeCos then
			return {TargetPos = nil}
		end


		local GCtr = util.TraceHull( {
			start = missile:GetPos(),
			endpos = posVec ,
			collisiongroup  = COLLISION_GROUP_WORLD,
			mins = Vector(0,0,0),
			maxs = Vector(0,0,0),
			filter = function( ent ) if ( ent:GetClass() ~= "worldspawn" ) then return false end end
		})

		if (GCtr.Hit) then
			return {TargetPos = nil}
		end


	end

	self.TargetPos = posVec
	return {TargetPos = posVec, ViewCone = self.ViewCone}

end

--Another Stupid Workaround. Since guidance degrees are not loaded when ammo is created
function this:GetDisplayConfig(Type)

	local Guns = ACE.Weapons.Guns
	local GunTable = Guns[Type]
	local ViewCone = GunTable.viewcone and (GunTable.viewcone * 2) or 0

	return
	{
		["Tracking"] = math.Round(ViewCone, 1) .. " deg"
	}
end
