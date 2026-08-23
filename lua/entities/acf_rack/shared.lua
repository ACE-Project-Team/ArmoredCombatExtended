-- shared.lua

DEFINE_BASECLASS("base_wire_entity")

ENT.PrintName         = "ACF Missile Rack"

local Weapons = ACE.Weapons.Guns
local Racks = ACE.Weapons.Racks

local function VerifyMountData(mountpoint)

	mountpoint.pos = mountpoint.pos or vector_origin
	mountpoint.offset = mountpoint.offset or vector_origin
	mountpoint.scaledir = mountpoint.scaledir or vector_origin

	return mountpoint
end

function ENT:GetMunitionAngPos(missile, _, attachname)

	local GunData = Weapons[missile.BulletData.Id]
	local RackData	= Racks[self.Id]

	if GunData and RackData then

		local offset = (GunData.bodydiameter and GunData.bodydiameter / 2) or (GunData.modeldiameter and GunData.modeldiameter / 2) or (GunData.caliber / 2.54)
		local mountpoint = VerifyMountData(RackData.mountpoints[attachname])
		local inverted = RackData.inverted or false

		local scaledir = mountpoint.scaledir:GetNormalized()
		local pos = self:LocalToWorld(mountpoint.pos + mountpoint.offset + scaledir * offset)
		local pos2 = self:LocalToWorld(mountpoint.pos + mountpoint.offset + scaledir) --for testing purposes

		debugoverlay.Cross(pos, 5, 10, Color(0,255,0,255) )
		debugoverlay.Cross(pos2, 5, 10, Color(183,255,0))

		return inverted, pos
	end
end

function ENT:GetMuzzle(shot, missile)
	shot = (shot or 0) + 1

	local attachname		= "missile" .. shot
	local inverted, pos  = self:GetMunitionAngPos(missile, attach, attachname)
	if attach ~= 0 then return attach, inverted, pos  end

	attachname			= "missile1"
	local inverted, pos  = self:GetMunitionAngPos(missile, attach, attachname)
	if attach ~= 0 then return attach, inverted, pos end

	attachname			= "muzzle"
	local inverted, pos  = self:GetMunitionAngPos(missile, attach, attachname)
	if attach ~= 0 then return attach, inverted, pos end

	return 0, false, pos
end
