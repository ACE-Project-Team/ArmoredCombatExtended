include("shared.lua")

-- ICON BACKGROUND: sprops/textures/sprops_metal5

SWEP.CSMuzzleFlashes = true
SWEP.ViewModelFlip = true

function SWEP:Initialize()
	self.m_bInitialized = true

	self:SetHoldType(self.HoldType)
	self:InitBulletData()
end

function SWEP:CustomAmmoDisplay()
	self.AmmoDisplay = self.AmmoDisplay or {}
	self.AmmoDisplay.Draw = true

	if self.Primary.ClipSize > 0 then
		self.AmmoDisplay.PrimaryClip = self:Clip1()
		self.AmmoDisplay.PrimaryAmmo = self:Ammo1()
	end

	return self.AmmoDisplay
end

function SWEP:DrawScope(Zoomed)
	if not (Zoomed and self.HasScope) then return end

	local scrw = ScrW()
	local scrh = ScrH()

	surface.SetDrawColor(0, 0, 0, 255)

	local rectsides = ((scrw - scrh) / 2) * 0.7

	surface.SetMaterial(Material("gmod/scope"))
	surface.DrawTexturedRect(rectsides, 0, scrw - rectsides * 2, scrh)
	surface.DrawRect(0, 0, rectsides + 2, scrh)
	surface.DrawRect(scrw - rectsides - 2, 0, rectsides + 2, scrh)
end

function SWEP:DoDrawCrosshair(x, y)
	local Zoom = self:GetZoomState()
	self:DrawScope(Zoom)

	local owner = self:GetOwner()
	local inaccuracy = math.min(owner:GetVelocity():Length() / owner:GetRunSpeed(), 1)
	inaccuracy = math.max(inaccuracy, self.Heat / self.HeatMax)

	local degrees = math.Clamp((self.Heat / self.HeatMax) ^ 2 * self.MaxSpread + self.BaseSpread, self.BaseSpread, self.BaseSpread + self.MaxSpread)

	--Inaccuracy based on player speed
	degrees = degrees + math.min(owner:GetVelocity():Length() / self.NormalPlayerRunSpeed, 1) * self.MovementSpread

	local IsCrouching = owner:Crouching()
	if PRONE_CUSTOM_ANIM_EVENT_NUM or false then
		IsCrouching = IsCrouching or owner:IsProne()
	end

	if not self:GetZoomState() then
		degrees = degrees + self.UnscopedSpread * (IsCrouching and self.CrouchRecoilBonus or 1)
	end


	if self.HasScope then
		local OuterReticleSize = 120 * (degrees / 3)
		if Zoom then
			surface.SetDrawColor(Color(0, 0, 0, 255))
				if self.HasScope then
					surface.DrawLine( x + 200, y, x + 7, y )
					surface.DrawLine( x - 200, y, x - 7, y )
					surface.DrawLine( x, y + 7, x, y + 200 )
					surface.DrawRect(x + 35 + OuterReticleSize, y, 1000, 2)
					surface.DrawRect(x - 1035 - OuterReticleSize, y, 1000, 2)
					surface.DrawRect(x-1.5, y + 35 + OuterReticleSize-1, 5, 1000)
					surface.SetDrawColor(Color(0, 150, 255, 255))
					surface.DrawLine( x, y - 7, x, y - 35 )
				end
			return true
		end

		--if self:GetClass() == "weapon_ace_awp" or self:GetClass() == "weapon_ace_scout" then return true end
	end

	local ReticuleBarSize = self.ReticuleSize
	local OffsetDist = 40 * (degrees / 3 )

	surface.SetDrawColor(0, 0, 0, 255)
	surface.DrawRect(x - 2, y - ReticuleBarSize - OffsetDist - 2, 4, ReticuleBarSize + 4)
	surface.DrawRect(x - 2, y + OffsetDist + 2, 4, ReticuleBarSize)
	surface.DrawRect(x + OffsetDist + 2, y - 1, ReticuleBarSize, 4)
	surface.DrawRect(x - OffsetDist - 2 - ReticuleBarSize, y - 1, ReticuleBarSize + 4, 4)

	surface.SetDrawColor(134, 255, 123)
	surface.DrawRect(x - 1, y - ReticuleBarSize - OffsetDist, 1, ReticuleBarSize)
	surface.DrawRect(x - 1, y + OffsetDist, 1, ReticuleBarSize)
	surface.DrawRect(x + OffsetDist, y, ReticuleBarSize, 1)
	surface.DrawRect(x - OffsetDist- ReticuleBarSize, y, ReticuleBarSize, 1)


	surface.SetFont( "Trebuchet24" )
	surface.SetTextColor( 134, 255, 123 )
	surface.SetTextPos( x + 30, y + 30 )
	surface.DrawText( "" .. self:Clip1() )
	--self.Primary.ClipSize

	return true
end
