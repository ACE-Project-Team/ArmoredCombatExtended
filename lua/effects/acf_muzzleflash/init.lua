
--[[---------------------------------------------------------
	Initializes the effect. The data is a table of data
	which was passed from the server.
]]-----------------------------------------------------------

function EFFECT:Init( data )

	local Gun = data:GetEntity()
	if not IsValid(Gun) then return end

	if not Gun.Parent then
		Gun.Parent = ACF_GetPhysicalParent(Gun) or Gun
	--	print(Gun.Parent)
	end

	self.GunVelocity = vector_origin

	if IsValid(Gun.Parent) then
		self.GunVelocity = Gun.Parent:GetVelocity()
	else
		self.GunVelocity = Gun:GetVelocity()
	end

	local Propellant   = data:GetScale()
	local ReloadTime   = data:GetMagnitude()

	local Sound        = Gun:GetNWString( "Sound", "" )
	local SoundPitch   = Gun:GetNWInt( "SoundPitch", 100 )
	local Class        = Gun:GetNWString( "Class", "C" )
	local Caliber      = Gun:GetNWInt( "Caliber", 1 ) * 10
	local MuzzleEffect = Gun:GetNWString( "Muzzleflash", "50cal_muzzleflash_noscale" )

	--This tends to fail
	local ClassData	= ACF.Classes.GunClass[Class]
	local Attachment	= "muzzle"

	if ClassData then
		local longbarrel	= ClassData.longbarrel or nil

		if longbarrel ~= nil and Gun:GetBodygroup( longbarrel.index ) == longbarrel.submodel then
			Attachment = longbarrel.newpos
		end
	end

	if not IsValidSound( Sound ) then
		Sound = ClassData.sound
	end

	if Propellant > 0 then

		ACE_SGunFire( Gun, Sound, SoundPitch, Propellant )

		local Muzzle = Gun:GetAttachment( Gun:LookupAttachment(Attachment)) or { Pos = Gun:GetPos(), Ang = Gun:GetAngles() }

		self.Origin 		= Muzzle.Pos
		self.DirAng			= Muzzle.Ang
		self.DirVec        = self.DirAng:Forward()
--			self.Radius 		= (Propellant * 1.35)
		self.Radius 		= (Caliber / 8)
		self.Emitter       = ParticleEmitter( self.Origin )

		if Gun:WaterLevel() ~= 3 then

			-- Gets the appropiated muzzleflash according to the defined in the gun class
			local MuzzleTable = ACE.MuzzleFlashes
			local MuzzleFunction = MuzzleTable[MuzzleEffect].muzzlefunc
			local MuzzleCallBack = MuzzleTable["Default"].muzzlefunc
			if MuzzleFunction then
				MuzzleFunction( self )
			else
				MuzzleCallBack( self )
			end

			-- Any ground detection system was ported inside of this. CHECK BELOW.
			self:Shockwave( MuzzleEffect )
			ACF_RenderLight(Gun:EntIndex(), Caliber * 75, Color(255, 128, 48), Muzzle.Pos + self.DirVec * (Caliber / 5))
		end

		local LocPly = LocalPlayer()
		if IsValid(LocPly) then
			local PlayerDist = (LocPly:GetPos() - self.Origin):Length() / 80 + 0.001 --Divide by 0 is death

			if PlayerDist < self.Radius * 4 and not LocPly:HasGodMode() then
				local Amp          = math.min(Propellant * 1.5 / math.max(PlayerDist,5),40)
				--local Amp          = math.min(self.Radius / 1.5 / math.max(PlayerDist,5),40)
				util.ScreenShake( self.Origin, 50 * Amp, 1.5 / Amp, math.min(Amp  * 2,self.Radius / 20), 0 , true)
			end
		end

		if Gun.Animate then
			Gun:Animate( Class, ReloadTime, false )
		end
	else
		if Gun.Animate then
			Gun:Animate( Class, ReloadTime, true )
		end
	end


end


--[[---------------------------------------------------------
	THINK
-----------------------------------------------------------]]
function EFFECT:Think( )
	return false
end

--[[---------------------------------------------------------
	Draw the effect
-----------------------------------------------------------]]
function EFFECT:Render()
end


function EFFECT:Shockwave( MuzzleType )
	if not self.Emitter then return end
	if MuzzleType ~= "C" and MuzzleType ~= "MO" then return end -- because rdc put the shockwave for those only.

	local GroundTr = { }
	GroundTr.start = self.Origin + Vector(0,0,1) * self.Radius
	GroundTr.endpos = self.Origin - Vector(0,0,1) * self.Radius * 25
	GroundTr.mask = MASK_NPCWORLDSTATIC
	local Ground = util.TraceLine( GroundTr )

	local MatType = Ground.MatType or 0
	local Materialvalue = ACE_GetMaterialName( MatType )
	local DustColors = table.Copy(ACE.DustMaterialColor)

	-- The explosion was detonated above a prop
	-- TODO: Network the armor material to retrieve a proper color.
	if Ground.HitNonWorld then --Overide with ACE prop material
		Materialvalue = "Metal"
	end

	local SmokeColor = DustColors[Materialvalue] or DustColors["Concrete"] --Enabling lighting on particles produced some yucky results when gravity pulled particles below the map.
	local AmbLight = render.GetLightColor( self.Origin ) * 2 + render.GetAmbientLightColor()
	SmokeColor.r = math.floor(SmokeColor.r * math.Clamp( AmbLight.x, 0, 1 ) * 0.9)
	SmokeColor.g = math.floor(SmokeColor.g * math.Clamp( AmbLight.y, 0, 1 ) * 0.9)
	SmokeColor.b = math.floor(SmokeColor.b * math.Clamp( AmbLight.z, 0, 1 ) * 0.9)

	if not Ground.Hit then return end

	-- RDC please, hardcoding magic multiplers into the code is truly bad. I moved your code out of the board.
	if MuzzleType == "MO" then
		Smult = 0.875
		LTMult = 0.5
	elseif MuzzleType == "C" then
		Smult = 1.3
		LTMult = 0.5
	else
		Smult = 1
		LTMult = 1
	end

	local PMul       = 1
	local Radius     = self.Radius * 0.5 * Smult --Removed (1-Ground.Fraction)
	local Density    = Radius * 6 * Smult
	local Angle      = Ground.HitNormal:Angle()

	for _ = 0, Density * PMul do

		Angle:RotateAroundAxis(Angle:Forward(), 360 / Density)
		local ShootVector = Angle:Up()
		local Smoke = self.Emitter:Add( "particle/smokesprites_000" .. math.random(1,9), Ground.HitPos )

		if Smoke then
			Smoke:SetVelocity( ShootVector * 350 * Radius * math.Rand(0.3, 1) )
			Smoke:SetLifeTime( 0 )
			Smoke:SetDieTime(  0.35 * Radius / 4 * LTMult )
			Smoke:SetStartAlpha( 125 / Smult )
			Smoke:SetEndAlpha( 0 )
			Smoke:SetStartSize( 7 * Radius )
			Smoke:SetEndSize( 35 * Radius * LTMult )
			Smoke:SetRoll( math.Rand(0, 360) )
			Smoke:SetRollDelta( math.Rand(-0.2, 0.2) )
			Smoke:SetAirResistance( 100 )
			Smoke:SetGravity(Vector(0, 0, 500 / LTMult))
			local SMKColor = math.random( 0 , 20 )
			Smoke:SetColor( SmokeColor.r + SMKColor, SmokeColor.g + SMKColor, SmokeColor.b + SMKColor )
		end
	end
end