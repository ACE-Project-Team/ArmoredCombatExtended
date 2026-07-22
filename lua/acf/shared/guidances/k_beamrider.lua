
local ClassName = "Beam_Riding"


ACE = ACE or {}
ACE.Guidance = ACE.Guidance or {}

local this = ACE.Guidance[ClassName] or inherit.NewSubOf(ACE.Guidance.Wire)
ACE.Guidance[ClassName] = this

this.Name = ClassName

-- Cone to retain targets within.
this.ViewCone = 30

this.desc = "This guidance package directs the missile to keep it in line with the sight as if it were riding a beam. Results in a fast traveltime."

this.GuidanceEntity = nil


function this:Init()

end




function this:Configure(missile)

	self:super().Configure(self, missile)

	self.ViewCone = ACE_GetGunValue(missile.BulletData, "viewcone") or this.ViewCone
	self.ViewConeCos = math.cos(math.rad(self.ViewCone))

	local GuidEnt = missile.Launcher
	if not IsValid(GuidEnt) then
		GuidEnt = missile
	end

	if next(ACE.Opticals) then

		for _, Optical in pairs(ACE.Opticals) do
			--print("Looking for computer...")

			if not IsValid(Optical) then
				continue
			end

			--Range: 250. Note im using squared distance. So 250 ^ 2 means distance is 250
			if IsValid(missile.Launcher) and Optical:GetPos():DistToSqr(missile.Launcher:GetPos()) < 90000 ^ 2 and Optical:CPPIGetOwner() == missile.Launcher:CPPIGetOwner() then

				--print("Attaching Nearest Computer...")
				--debugoverlay.Cross(Optical:GetPos(), 10, 10, Color(255,100,0), true)

				GuidEnt = Optical
				break
			end
		end
	end
	self.GuidanceEntity = GuidEnt

end




function this:GetGuidance(missile)

	--local posVec = missile.Launcher.TargPos

	--if not posVec or type(posVec) ~= "Vector" or posVec == Vector() then
	--	return {TargetPos = nil}
	--end

	if not IsValid(self.GuidanceEntity) or (missile.IsJammed ~= 0) then return {TargetPos = nil} end

	local GEntPos = self.GuidanceEntity:GetPos()
	local GEntDir = self.GuidanceEntity:GetForward()

	local Dist = GEntPos:Distance(missile:GetPos())


	self.TargetPos = GEntPos + GEntDir * (Dist + 39.37 * 35)
	return {TargetPos = self.TargetPos, ViewCone = self.ViewCone}

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
