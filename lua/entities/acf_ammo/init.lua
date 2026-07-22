
AddCSLuaFile("shared.lua")
AddCSLuaFile("cl_init.lua")

include("shared.lua")

local GunClasses = ACE.Classes.GunClass

local GunTable  = ACE.Weapons.Guns
local AmmoTable = ACE.Weapons.Ammo
local LegacyAmmoTable = ACE.Weapons.LegacyAmmo

local COOKOFF_THRESHOLD = 0.02
local COOKOFF_MIN_DURATION = 0.45

local MACHINEGUN_ROUND_TYPES = {
	SM = true,
}

local function IsMachineGunAmmo( ent )
	local bullet = ent and ent.BulletData or {}
	local id = bullet.Id or ent.RoundId
	local gun = (id and GunTable and GunTable[id]) or nil
	local gunclass = (gun and gun.gunclass) or bullet.GunClass or ent.GunClass
	local roundType = bullet.Type or ent.RoundType

	if roundType and MACHINEGUN_ROUND_TYPES[roundType] then
		return true
	end
	return gunclass == "MG"
end

local function IsMissileAmmo( ent )
	local bullet = ent and ent.BulletData or {}
	local id = bullet.Id or ent.RoundId
	local gun = (id and GunTable and GunTable[id]) or nil
	local gunclass = (gun and gun.gunclass) or bullet.GunClass or ent.GunClass
	local classData = gunclass and GunClasses and GunClasses[gunclass] or nil

	return (classData and classData.type == "missile") or false
end

local function SpawnMiniHEFlash(ent, pos, radius)
	if not IsValid(ent) then return end
	local HEFlash = EffectData()
	HEFlash:SetOrigin( pos )
	HEFlash:SetNormal( -vector_up )
	HEFlash:SetRadius( radius )
	util.Effect( "ACE_Scaled_Explosion", HEFlash )
end

local function ScheduleFinalExplosion( ent )
	local now = CurTime()
	ent.CookoffEnd = math.min(ent.CookoffEnd or now, now + 0.18)
	ent.CookoffNext = now + 0.05
end

local function GetCookoffConfig( ent, severity )
	local volume = math.max((ent.BulletData and ent.BulletData.RoundVolume) or 1, 1)
	local sizeFactor = math.Clamp((volume ^ 0.5) / 15, 0, 1)
	local ammoFrac = math.Clamp((ent.Ammo or 0) / math.max(ent.Capacity or 1, 1), 0, 1)
	local severityScale = math.Clamp((severity or 0) / 0.2, 0, 1)
	local isMG = IsMachineGunAmmo(ent)

	local baseDuration = Lerp(sizeFactor, 2.2, 0.9)
	local duration = Lerp(severityScale, baseDuration, baseDuration * 0.6) * Lerp(ammoFrac, 0.7, 1.1)
	if isMG then
		duration = duration * 2.4
	end
	duration = math.max(duration, COOKOFF_MIN_DURATION)

	local baseDelay = Lerp(sizeFactor, 0.35, 0.08)
	local minDelay = Lerp(sizeFactor, 0.1, 0.03)
	baseDelay = Lerp(severityScale, baseDelay, baseDelay * 0.6)
	minDelay = Lerp(severityScale, minDelay, minDelay * 0.6)
	if isMG then
		baseDelay = baseDelay * 0.75
		minDelay = minDelay * 0.75
	end

	local roundsScale = Lerp(sizeFactor, 0.08, 0.02)
	local maxRounds = math.Clamp(math.ceil((ent.Ammo or 0) * roundsScale), 4, 40)
	if isMG then
		maxRounds = math.Clamp(math.ceil(maxRounds * 4), 20, 220)
	end
	local minRounds = math.Clamp(math.ceil(maxRounds * 0.35), 2, maxRounds)

	if IsMissileAmmo(ent) then
		-- Missile cookoff should be short and sporadic, not prolonged autocannon-like detonation.
		maxRounds = math.Clamp(maxRounds, 1, 3)
		minRounds = math.Clamp(math.ceil(maxRounds * 0.4), 1, maxRounds)
	end

	return {
		SizeFactor = sizeFactor,
		Duration = duration,
		BaseDelay = baseDelay,
		MinDelay = minDelay,
		MaxRounds = maxRounds,
		MinRounds = minRounds
	}
end

local Inputs = {
	"Active"
}
local Outputs = {
	"Munitions (Returns the current number of rounds in this crate.)",
	"Capacity (Returns the capacity of this crate.)"
}

function ENT:Initialize()

	self.SpecialHealth       = true  --If true needs a special ACE_Activate function
	self.SpecialDamage       = true  --If true needs a special ACE_OnDamage function

	self.IsExplosive         = true
	self.Exploding           = false
	self.Damaged             = false
	self.DamageDelay         = 0

	self.CanUpdate           = true
	self.Load                = true
	self.EmptyMass           = 1
	self.AmmoMassMax         = 0
	self.NextMassUpdate      = 0

	self.Ammo                = 0
	self.IsTwoPiece          = false

	self.NextLegalCheck      = ACE.CurTime + math.random(ACE.Legal.Min, ACE.Legal.Max) -- give any spawning issues time to iron themselves out
	self.Legal               = true
	self.LegalIssues         = ""

	self.Active              = true
	self.Master              = {}
	self.Sequence            = 0

	self.Interval            = 1		-- Think Interval when its not damaged
	self.ExplosionInterval   = 0.03	-- Base Think Interval when its damaged and its about to explode

	self.Capacity            = 1
	self.AmmoMassMax         = 1
	self.Caliber             = 1
	self.RoFMul              = 1
	self.LastMass            = 1

	self.Inputs              = Wire_CreateInputs( self, Inputs ) --, "Fuse Length"
	self.Outputs             = Wire_CreateOutputs( self, Outputs )
	ACE.GetDefaultActiveInputState(self)

	ACE.AmmoCrates           = ACE.AmmoCrates or {}

end

function ENT:ACF_Activate( Recalc )

	local EmptyMass = math.max(self.EmptyMass, self:GetPhysicsObject():GetMass() - self.AmmoMassMax)

	self.ACF = self.ACF or {}

	local PhysObj = self:GetPhysicsObject()

	if not self.ACF.Area then
		self.ACF.Area = PhysObj:GetSurfaceArea() * 6.45
	end

	if not self.ACF.Volume then
		self.ACF.Volume = PhysObj:GetVolume() * 16.38
	end

	local Armour	= EmptyMass * 1000 / self.ACF.Area / 0.78 --So we get the equivalent thickness of that prop in mm if all it's weight was a steel plate
	local Health	= (self.ACF.Volume / ACE.Threshold) / 20					--Ammo crates get reduced HP relative to props
	local Percent	= 1

	if Recalc and self.ACF.Health and self.ACF.MaxHealth then
		Percent = self.ACF.Health / self.ACF.MaxHealth
	end

	self.ACF.Health	= Health * Percent
	self.ACF.MaxHealth  = Health
	self.ACF.Armour	= Armour * (0.5 + Percent / 2)
	self.ACF.MaxArmour  = Armour
	self.ACF.Type	= nil
	self.ACF.Mass	= self.Mass
	self.ACF.Density	= (self:GetPhysicsObject():GetMass() * 1000) / self.ACF.Volume
	self.ACF.Type	= "Prop"

	self.ACF.Material	= not isstring(self.ACF.Material) and ACE.BackCompMat[self.ACF.Material] or self.ACF.Material or "RHA"

	--Forces an update of mass
	self.LastMass = 1
	self:UpdateMass()

end

do

	local HEATtbl = {
		HEAT	= true,
		THEAT	= true,
		HEATFS  = true,
		THEATFS = true
	}

	local HEtbl = {
		HE	= true,
		HESH	= true,
		HEFS	= true
	}

	function ENT:StartCookoff( Inflictor, severity )
		if self.CookoffActive then return end

		self.Exploding    = true
		self.Inflictor    = Inflictor or self.Inflictor
		self.Damaged      = true
		self.DamageDelay  = ACE.CurTime

		local config = GetCookoffConfig( self, severity )

		self.CookoffActive    = true
		self.CookoffStart     = CurTime()
		self.CookoffEnd       = self.CookoffStart + config.Duration + math.Rand(0, 0.2)
		self.CookoffBaseDelay = config.BaseDelay
		self.CookoffMinDelay  = config.MinDelay
		self.CookoffMaxRounds = config.MaxRounds
		self.CookoffMinRounds = config.MinRounds
		self.CookoffCount = 0
		self.CookoffNext      = self.CookoffStart
		self.CookoffHEToggle  = true
		self.CookoffExplosionPos = nil
		self.ExplosionPending = false
	end

	function ENT:ACF_OnDamage( Entity, Energy, FrArea, Angle, Inflictor, _, Type )	--This function needs to return HitRes

		local Mul	= (( HEATtbl[Type] and ACE.HEATMulAmmo ) or 1) --Heat penetrators deal bonus damage to ammo
		local HitRes	= ACE.PropDamage( Entity, Energy, FrArea * Mul, Angle, Inflictor ) --Calling the standard damage prop function

		if self.Exploding or not self.IsExplosive then return HitRes end

		if self.CookoffActive then
			HitRes.Damage = 0
			HitRes.Kill = false
			return HitRes
		end

		if HEtbl[Type] then
			if HitRes.Kill then
				self:Remove()
			end
			return HitRes
		end

		local maxHealth = (self.ACF and self.ACF.MaxHealth) or 0
		local damageFrac = maxHealth > 0 and ((HitRes.Damage or 0) / maxHealth) or 0
		local hpThreshold = 0.5

		if damageFrac < COOKOFF_THRESHOLD and (HitRes.Damage or 0) < hpThreshold then
			local healthFrac = maxHealth > 0 and math.Clamp((self.ACF.Health or 0) / maxHealth, 0, 1) or 0
			local newAmmo = math.ceil((self.Capacity or 0) * healthFrac)
			if self.Ammo and newAmmo < self.Ammo then
				self.Ammo = newAmmo
				self:UpdateMass()
				self:UpdateOverlayText()
			end
			if HitRes.Kill then
				self:Remove()
			end
			return HitRes
		end

		local severity = damageFrac
		if HitRes.Kill then
			severity = math.max(severity, 0.5)
		end

		if hook.Run("ACE_AmmoExplode", self, self.BulletData ) == false then return HitRes end

		self.Exploding = true

		if Inflictor and IsValid(Inflictor) and Inflictor:IsPlayer() then
			self.Inflictor = Inflictor
		end

		if self.BulletData.Type == "Refill" then
			self:Remove()
		else
			self:StartCookoff( Inflictor, severity )
		end

		return HitRes --This function needs to return HitRes
	end

end


do

	-- Parses + clamps an "L:W:H" string into a Vector. Shared with fuel tanks and
	-- scalable explosives (see ACE.Scalable.ParseScale); crates pass the crate size
	-- limits as their bounds.
	local function ConvertStringScale( ScaleId )
		return ACE.Scalable.ParseScale( ScaleId, { min = ACE.CrateMinimumSize, max = ACE.CrateMaximumSize } )
	end

	-- If the incoming Id belongs to an invalid ammo crate, but belongs to the legacy crates list, convert it into its scalable counterpart.
	local function CreateLegacyScale( Id, Ammo )
		local Content = LegacyAmmoTable[Id]
		Scale = Vector( Content.Length, Content.Width, Content.Height )
		Ammo:SetPos( Ammo:LocalToWorld( vector_up * Content.Offset ) ) -- necessary to do, since some old crates had not a coordinated origin at its center but the base of them.

		return Scale
	end

	function ACE.MakeAmmo(Owner, Pos, Angle, Id, Data1, Data2, Data3, Data4, Data5, Data6, Data7, Data8, Data9, Data10, Data11, Data12, Data13, Data14, Data15)

		if not Owner:CheckLimit("_acf_ammo") then return false end

		local Ammo = ents.Create("acf_ammo")
		if IsValid(Ammo) then

			local Model
			local Weight
			local Dimensions

			Ammo:CPPISetOwner(Owner)
			Ammo:SetAngles(Angle)
			Ammo:SetPos(Pos)
			Ammo:Spawn()

			-- If the crate is not valid in the system, but it could be in the LegacyAmmoTable o be scalable.
			if not ACE.CheckAmmo( Id ) then

				local Scale

				if isstring(Id) and LegacyAmmoTable[Id] then
					Scale = CreateLegacyScale(Id, Ammo)
				else
					Scale = ConvertStringScale(Id)
				end

				if isvector(Scale) then

					local ModelData = ACE.ModelData["Box"]

					Id = Scale
					Model = ModelData.Model
					Weight = (Scale.x * Scale.y * Scale.z) / 200
					Dimensions = Scale

					local DefaultSize    = ModelData.DefaultSize
					local Mesh           = ModelData.CustomMesh
					local PhysMaterial   = ModelData.physMaterial
					local EntityScale    = Vector(Scale.x / DefaultSize, Scale.y / DefaultSize, Scale.z / DefaultSize)

					Ammo.ScaleData = {
						Mesh = Mesh,
						Scale = EntityScale,
						Size = DefaultSize,
						Material = PhysMaterial,
					}

					Ammo:SetMaterial("models/props_canal/metalwall005b")
					Ammo:SetModel( Model ) --Sending the model to client
					Ammo:PhysicsInit( SOLID_VPHYSICS )
					Ammo:SetMoveType( MOVETYPE_VPHYSICS )
					Ammo:SetSolid( SOLID_VPHYSICS )

					Ammo.IsScalable = true
					Ammo:ACE_SetScale( Ammo.ScaleData )

				else
					Id = "Shell100mm"
				end
			end

			-- If the crate is legacy, but still valid in the system
			if ACE.CheckAmmo( Id ) then

				local AmmoData = AmmoTable[Id]

				Model = AmmoData.model
				Weight = AmmoData.weight

				local Length = tonumber(AmmoData.Length or AmmoData.Lenght)
				local Width = tonumber(AmmoData.Width)
				local Height = tonumber(AmmoData.Height)

				if not Length or not Width or not Height then
					ErrorNoHalt(string.format("[ACE] Invalid ammo crate dimensions for '%s' (Length/Lenght=%s, Width=%s, Height=%s). Falling back to 1x1x1.\n", tostring(Id), tostring(AmmoData.Length or AmmoData.Lenght), tostring(AmmoData.Width), tostring(AmmoData.Height)))
					Length = Length or 1
					Width = Width or 1
					Height = Height or 1
				end

				Dimensions = Vector( Length, Width, Height )

				Ammo:SetModel( Model )
				Ammo:PhysicsInit( SOLID_VPHYSICS )
				Ammo:SetMoveType( MOVETYPE_VPHYSICS )
				Ammo:SetSolid( SOLID_VPHYSICS )

			end

			Ammo.Id = Id
			Ammo.Model = Model
			Ammo.Dimensions = Dimensions

			Ammo:CreateAmmo(Id, Data1, Data2, Data3, Data4, Data5, Data6, Data7, Data8, Data9, Data10, Data11, Data12, Data13, Data14, Data15)

			Ammo.Ammo        = Ammo.Capacity
			Ammo.EmptyMass   = Weight or 1
			Ammo.AmmoMass    = Ammo.EmptyMass + Ammo.AmmoMassMax

			Ammo.LastMass	= 1
			Ammo:UpdateMass()

			Owner:AddCount( "_acf_ammo", Ammo )
			Owner:AddCleanup( "acfmenu", Ammo )

			table.insert(ACE.AmmoCrates, Ammo)

			return Ammo
		end
	end
end

list.Set( "ACFCvars", "acf_ammo", {"id", "data1", "data2", "data3", "data4", "data5", "data6", "data7", "data8", "data9", "data10", "data11", "data12", "data13", "data14", "data15"} )
ACE_MakeAmmo = ACE.MakeAmmo
duplicator.RegisterEntityClass("acf_ammo", ACE_MakeAmmo, "Pos", "Angle", "Id", "RoundId", "RoundType", "RoundPropellant", "RoundProjectile", "RoundData5", "RoundData6", "RoundData7", "RoundData8", "RoundData9", "RoundData10" , "RoundData11", "RoundData12", "RoundData13", "RoundData14", "RoundData15" )


function ENT:Update( ArgsTable )

	-- That table is the player data, as sorted in the ACFCvars above, with player who shot,
	-- and pos and angle of the tool trace inserted at the start

	local msg = "Ammo crate updated successfully!"
	local pointSources = { self }
	for _, Gun in pairs(self.Master or {}) do
		if IsValid(Gun) then pointSources[#pointSources + 1] = Gun end
	end

	if ArgsTable[6] == "Refill" then -- Argtable[6] is the round type. If it's refill it shouldn't be loaded into guns, so we refuse to change to it
		return false, "Refill ammo type is only avaliable for new crates!"
	end

	self._ACEPointsSuppress = true

	if ArgsTable[5] ~= self.RoundId then -- Argtable[5] is the weapon ID the new ammo loads into
		for _, Gun in pairs( self.Master ) do
			if IsValid( Gun ) then
				Gun:Unlink( self )
			end
		end
		msg = "New ammo type loaded, crate unlinked."
	else -- ammotype wasn't changed, but let's check if new roundtype is blacklisted
		local Blacklist = ACE.AmmoBlacklist[ ArgsTable[6] ] or {}

		for _, Gun in pairs( self.Master ) do
			if IsValid( Gun ) and table.HasValue( Blacklist, Gun.Class ) then
				Gun:Unlink( self )
				msg = "New round type cannot be used with linked gun, crate unlinked."
			end
		end
	end
	self._ACEPointsSuppress = nil

	local AmmoPercent = self.Ammo / math.max(self.Capacity,1)

	self:CreateAmmo(ArgsTable[4], ArgsTable[5], ArgsTable[6], ArgsTable[7], ArgsTable[8], ArgsTable[9], ArgsTable[10], ArgsTable[11], ArgsTable[12], ArgsTable[13], ArgsTable[14], ArgsTable[15], ArgsTable[16], ArgsTable[17], ArgsTable[18], ArgsTable[19])

	self.Ammo = math.floor(self.Capacity * AmmoPercent)

	self.LastMass = 1 -- force update of mass
	self:UpdateMass()

	if ACE.PointsInputChanged then ACE.PointsInputChanged(pointSources, "ammo-updated") end

	return true, msg

end

function ENT:UpdateOverlayText()

	local roundType = self.BulletData.Type

	if table.IsEmpty( self.BulletData or {} ) then  return end

	local text = ""

	if self.BulletData.Type == "Refill" then

		text = " - " .. roundType .. " - "

		if self.SupplyingTo and not table.IsEmpty(self.SupplyingTo) then
			text = text .. "\nSupplying " .. #self.SupplyingTo .. " Ammo Crates"
		end

	else
		if self.BulletData.Tracer and self.BulletData.Tracer > 0 then
			roundType = roundType .. "-T"
		end

		text = roundType .. " - " .. self.Ammo .. " / " .. self.Capacity

		local RoundData = ACE.RoundTypes[ self.BulletData.Type ]

		if RoundData and RoundData.cratetxt then
			text = text .. "\n" .. RoundData.cratetxt( self.BulletData, self )
		end

		if ACE.Points_RoundFromBullet and ACE.Points_BaseRoundCost then
			local round = ACE.Points_RoundFromBullet( self.BulletData )
			if round then
				local roundLine = ACE.GetRoundLethalityLine and ACE.GetRoundLethalityLine( round )
				if roundLine then text = text .. "\nLethality: " .. roundLine end
				text = text .. "\nBase Round Cost: " .. string.Comma(math.Round(ACE.Points_BaseRoundCost(round)))
				text = text .. "\nCrate Inventory Points: 0"
			end
		end

		if self.IsScalable then
			local x = math.Round(self.Dimensions.x, 1) / 10
			local y = math.Round(self.Dimensions.y, 1) / 10
			local z = math.Round(self.Dimensions.z, 1) / 10

			local dims = x .. "x" .. y .. "x" .. z
			text = text .. "\n\n Size: " .. dims
		end

		if self.IsTwoPiece then
			text = text .. "\n\nUses 2 piece ammo\n30% reload penalty"
		end
	end

	if not self.Legal then
		text = text .. "\n\nNot legal, disabled for " .. math.ceil(self.NextLegalCheck - ACE.CurTime) .. "s\nIssues: " .. self.LegalIssues
	end

	self:SetOverlayText( text )

end

do

	--List of ids which no longer stay on ACE. Useful to replace them with the closest counterparts
	local BackComp = {
		["20mmHRAC"]		= "20mmRAC",
		["30mmHRAC"]		= "30mmRAC",
		["105mmSB"]		= "100mmSBC",
		["120mmSB"]		= "120mmSBC",
		["140mmSB"]		= "140mmSBC",
		["170mmSB"]		= "170mmSBC",
		["70mmFFARDAGR"]	= "70mmFFAR",
		["9M113 ASM"]	= "9M133 ASM",
		["9M311"]		= "9M311 SAM",
		["SIMBAD-RC SAM"]	= "Mistral SAM"
	}

	--List of munitions no longer stay on ACE
	local AmmoComp = {
		["APDSS"]		= "APDS",
		["APFSDSS"]		= "APFSDS",
		["APBC"]		= "AP",
		["APC"]			= "AP",
		["APCBC"]		= "AP",
		["APBC"]		= "AP",
		["APHECBC"]		= "APHE"
	}

	function ENT:CreateAmmo(_, Data1, Data2, Data3, Data4, Data5, Data6, Data7, Data8, Data9, Data10 , Data11 , Data12 , Data13 , Data14 , Data15)

		if not ACE.CheckGun( Data1 ) then
			Data1 = BackComp[Data1] or "100mmC"
		end
		if not ACE.CheckRound( Data2 ) then
			Data2 = AmmoComp[ Data2 ] or "AP"
		end

		--For some reason, removing this will also break several things with missile code. bad
		self.RoundId            = Data1
		self.RoundType          = Data2							-- Type of round, IE AP, HE, HEAT ...
		self.RoundPropellant    = Data3					or 0	-- Lenght of propellant
		self.RoundProjectile    = Data4					or 0	-- Lenght of the projectile
		self.RoundData5         = Data5					or 0
		self.RoundData6         = Data6					or 0
		self.RoundData7         = Data7					or 0
		self.RoundData8         = Data8					or 0
		self.RoundData9         = Data9					or 0
		self.RoundData10        = tonumber(Data10)		or 0 -- Tracer. For some reason, both Data10 and Data are sent as strings. Needs to review this.
		self.RoundData11        = tonumber(Data11)		or 0 -- Two Piece check
		self.RoundData12        = Data12				or 0
		self.RoundData13        = Data13				or 0
		self.RoundData14        = Data14				or 0
		self.RoundData15        = Data15				or 0


		local PlayerData        = {}	--what a mess
		PlayerData.Id           = self.RoundId
		PlayerData.Type         = self.RoundType
		PlayerData.PropLength   = self.RoundPropellant
		PlayerData.ProjLength   = self.RoundProjectile
		PlayerData.Data5        = self.RoundData5
		PlayerData.Data6        = self.RoundData6
		PlayerData.Data7        = self.RoundData7
		PlayerData.Data8        = self.RoundData8
		PlayerData.Data9        = self.RoundData9
		PlayerData.Tracer       = self.RoundData10
		PlayerData.TwoPiece     = self.RoundData11
		PlayerData.Data12       = self.RoundData12
		PlayerData.Data13       = self.RoundData13
		PlayerData.Data14       = self.RoundData14
		PlayerData.Data15       = self.RoundData15

		self.ConvertData    = ACE.RoundTypes[self.RoundType].convert
		self.BulletData     = self:ConvertData( PlayerData )
		if IsMissileAmmo( self ) then self.BulletData.Data7 = self.RoundData7 end

		self:BuildAmmoCapacity()

	end

	local Floor = math.floor
	local MaxValue = math.max
	local toInch = 2.54		--Number used for cm -> inche conversion

	function ENT:BuildAmmoCapacity()

		local AmmoGunData = GunTable[self.BulletData.Id]
		local Vol		= Floor(self:GetPhysicsObject():GetVolume())
		local WireName	= "No data"
		local Capacity
		local AmmoMaxMass

		--ammo capacity start code
		if self.BulletData.Type == "Refill" then

			Capacity = 99999999 --can't use math huge because weight sets to 1
			AmmoMaxMass = Vol

			WireName = "ACE Universal Supply Crate"
		else

			self.IsTwoPiece = false

			--Getting entity's dimensions
			local Dimensions = self.Dimensions

			local GunId = AmmoGunData.gunclass
			local WeaponType = GunClasses[GunId].type

			local width
			local shellLength

			if WeaponType == "missile" then

				width = AmmoGunData.modeldiameter or (AmmoGunData.caliber / ACE.AmmoLengthMul / toInch)
				shellLength = AmmoGunData.length / ACE.AmmoLengthMul / toInch

			else

				width = AmmoGunData.caliber / ACE.AmmoWidthMul / toInch
				shellLength = ((self.BulletData.PropLength or 0) + (self.BulletData.ProjLength or 0)) / ACE.AmmoLengthMul / toInch

			end

			-- Calculate the capacity based on the dimensions of the entity and the dimensions of the ammo
			local cap1 = Floor(Dimensions.x / shellLength) * Floor(Dimensions.y / width) * Floor(Dimensions.z / width)
			local cap2 = Floor(Dimensions.y / shellLength) * Floor(Dimensions.x / width) * Floor(Dimensions.z / width)
			local cap3 = Floor(Dimensions.z / shellLength) * Floor(Dimensions.x / width) * Floor(Dimensions.y / width)

			--Split the shell in 2, leave the other piece next to it.
			local piececap1 = Floor(Dimensions.x / (shellLength / 2)) * Floor(Dimensions.y / (width * 2)) * Floor(Dimensions.z / width)
			local piececap2 = Floor(Dimensions.y / (shellLength / 2)) * Floor(Dimensions.x / (width * 2)) * Floor(Dimensions.z / width)
			local piececap3 = Floor(Dimensions.z / (shellLength / 2)) * Floor(Dimensions.x / (width * 2)) * Floor(Dimensions.y / width)

			local FCap	= MaxValue(cap1,cap2,cap3)
			local FpieceCap = MaxValue(piececap1,piececap2,piececap3)

			--Why would you need the 2 piece for rounds below 50mm? Unless you want legos there....
			--Missiles & bombs are excluded from using this method...
			if AmmoGunData.caliber >= 5 and WeaponType ~= "missile" and FpieceCap > FCap and self.BulletData.TwoPiece > 0 then
				FCap = FpieceCap
				self.IsTwoPiece = true
			end

			Capacity	= FCap
			AmmoMaxMass = ( (self.BulletData.ProjMass + self.BulletData.PropMass) * Capacity ) or 1

			debugoverlay.Box(self:GetPos() + Vector(0, 0, 50), -Vector(shellLength / 2, width / 2, width / 2), Vector(shellLength / 2, width / 2, width / 2), 20, Color(255, 0, 0, 100))
			debugoverlay.Text(self:GetPos() + Vector(0,0,50), "Bullet Dimensions", 20)
			debugoverlay.Text(self:GetPos() + Vector(0,0,15), "Mass per Round: " .. (self.BulletData.ProjMass + self.BulletData.PropMass) .. "kgs", 20 )
			debugoverlay.Text(self:GetPos() + Vector(0,0,10), "Total Ammo Mass: " .. self.AmmoMassMax .. "kgs", 20 )
			WireName = AmmoGunData.name .. " Ammo"

		-- end capacity calculations
		end

		self.AmmoMassMax    = AmmoMaxMass
		self.Capacity       = Capacity
		self.Volume         = Vol --Used by the missile reload bonus
		self.Caliber        = AmmoGunData.caliber or 1
		self.RoFMul         = self.IsTwoPiece and 0.3 or 0						--30% ROF penalty for 2 piece

		self:SetNWString( "Ammo", self.Ammo )
		self:SetNWString( "WireName", WireName )

		self.NetworkData = ACE.RoundTypes[self.BulletData.Type].network
		self:NetworkData( self.BulletData )

		Wire_TriggerOutput( self, "Capacity", self.Capacity )
		self:UpdateOverlayText()

	end

end

function ENT:UpdateMass()

	self.Mass = self.EmptyMass + math.Round( self.AmmoMassMax * (self.Ammo / math.max(self.Capacity,1)) )

	--reduce superflous engine calls, update crate mass every 5 kgs change or every 10s-15s
	if math.abs((self.LastMass or 0) - self.Mass) > 5 or ACE.CurTime > self.NextMassUpdate then

		self.LastMass	= self.Mass
		self.NextMassUpdate = ACE.CurTime + math.Rand(10,15)

		local phys = self:GetPhysicsObject()
		if (phys:IsValid()) then

			phys:SetMass( self.Mass )

		end
	end

end

function ENT:GetInaccuracy()
	--local SpreadScale = ACE.SpreadScale
	local inaccuracy = 0
	local Gun = GunTable[self.RoundId]

	if Gun then
		inaccuracy = (GunClasses[Gun.gunclass] or {spread = 0}).spread
	end

	local coneAng = inaccuracy * ACE.GunInaccuracyScale
	return coneAng
end

function ENT:TriggerInput( iname, value )

	if (iname == "Active") then
		local active = ACE.GetDefaultActiveInputState(self, value)

		if active then
			self.Active = true

			if self.Legal then
				self.Load = true
				self:FirstLoad()
			end
		else
			self.Active = false
			self.Load = false
		end
	end

end

function ENT:FirstLoad()

	for Key in pairs(self.Master) do
		local Gun = self.Master[Key]
		if IsValid(Gun) and Gun.FirstLoad and Gun.BulletData.Type == "Empty" and Gun.Legal then
			-- Reload=true: scale-0 muzzleflash effect (soundless) so the client initializes its
			-- animation state; a fully silent load leaves the load animation strobing (see acf_gun).
			Gun:LoadAmmo(false, true)
		end
	end

end

function ENT:Think()

	if not self.BulletData then return false end

	if not ACE.IsDefaultActiveInputWired(self) then
		self.Active = true

		if self.Legal and not self.Load then
			self.Load = true
			self:FirstLoad()
		end
	end

	if ACE.CurTime > self.NextLegalCheck then

		self.Legal, self.LegalIssues = ACE.CheckLegal(self, self.Model, math.min(math.Round(self.EmptyMass,2),50000), nil, true, true)
		self.NextLegalCheck = ACE.Legal.NextCheck(self.legal)
		self:UpdateOverlayText()

		if not self.Legal then
			self.Load = false
		else
			--if legal, go back to the action
			if self.Active then self.Load = true end
		end

	end

	if self.BulletData.Type == "Refill" then
		self:UpdateOverlayText()
	else

		self:UpdateMass()

		if self.Ammo ~= self.AmmoLast or not self.Legal then
			self:UpdateOverlayText()
			self.AmmoLast = self.Ammo
		end
	end

	local color = self:GetColor()
	self:SetNWVector("TracerColour", Vector( color.r, color.g, color.b ) )

	local cvarGrav = GetConVar("sv_gravity")
	local vec = Vector(0,0,cvarGrav:GetInt() * -1)

	self:SetNWVector("Accel", vec)

	self:NextThink( CurTime() +  self.Interval )

	-- cookoff handling
	if self.Damaged then

		--Unlink any gun from this crate
		for Key in pairs(self.Master) do
			local Gun = self.Master[Key]
			if IsValid(Gun) then
				Gun:Unlink( self )
			end
		end

		if self.DamageDelay < ACE.CurTime then
			local CrateType = self.BulletData.Type or "Refill"

			--If that is a refill, remove it
			if CrateType == "Refill" then

				self:Remove()

			else
				if not self.CookoffActive then
					self:StartCookoff( self.Inflictor )
				end

				local Now = CurTime()
				local EndTime = self.CookoffEnd or Now

				if Now >= EndTime or self.Ammo <= 0 then
					if (self.CookoffCount or 0) < (self.CookoffMinRounds or 0) and self.Ammo > 0 then
						self.CookoffEnd = Now + 0.2
						self.CookoffNext = Now
						self:NextThink( Now + 0.02 )
						return
					end
					if not self.ExplosionPending then
						self.ExplosionPending = true
						if IsMachineGunAmmo( self ) then
							timer.Simple(0.02, function()
								if not IsValid(self) then return end
								self:Remove()
							end)
						else
							local delay = 0.03
							timer.Simple(delay, function()
								if not IsValid(self) then return end
								self.CookoffScale = 0.4
								self.CookoffExplosionPos = self.CookoffExplosionPos or self:LocalToWorld(self:OBBCenter())
								ACE.ScaledExplosion( self, true )
								self.CookoffExplosionPos = nil
							end)
						end
					end
					return
				end

				if Now >= (self.CookoffNext or Now) then

					if self.CookoffCount < (self.CookoffMaxRounds or 1) and ACE.RoundTypes[CrateType] then

						local isMG = IsMachineGunAmmo( self )

						self:EmitSound( "acf_other/explosions/cookoff/cookOff" .. math.random(1,4) .. ".mp3", 250, math.max(140 - self.BulletData.PropMass * 35,35)  )
						self.BulletCookSpeed	= self.BulletCookSpeed or ACE.MuzzleVelocity( self.BulletData.PropMass, self.BulletData.ProjMass / 2, self.Caliber )

						self.BulletData.Tracer = 1
						self.RoundData10 = 1

					self.BulletData.Pos = self:LocalToWorld(self:OBBCenter() + VectorRand() * (self:OBBMaxs() - self:OBBMins()) / 2)
					self.CookoffExplosionPos = self.BulletData.Pos
						self.BulletData.Flight  = (VectorRand()):GetNormalized() * self.BulletCookSpeed * 39.37 + self:GetVelocity() * 0.25

						self.BulletData.Owner	= self.BulletData.Owner or self.Inflictor or self:CPPIGetOwner()
						self.BulletData.Gun	= self.BulletData.Gun	or self
						self.BulletData.Crate	= self.BulletData.Crate or self:EntIndex()

					local CookoffBullet = table.Copy( self.BulletData )
					CookoffBullet.ProjMass = (CookoffBullet.ProjMass or 0) * 0.5
					CookoffBullet.PropMass = (CookoffBullet.PropMass or 0) * 0.5
					CookoffBullet.FillerMass = (CookoffBullet.FillerMass or 0) * 0.75
					CookoffBullet.BoomFillerMass = (CookoffBullet.BoomFillerMass or CookoffBullet.FillerMass or 0) * 0.75
					CookoffBullet.MuzzleVel	= (CookoffBullet.MuzzleVel or 0) * 0.75
					local IsMissile = IsMissileAmmo(self)
					local CookoffType = CrateType
					if not ACE.RoundTypes[CookoffType] then
						CookoffType = CrateType
					end
					CookoffBullet.Type = CookoffType

					self.CreateShell = ACE.RoundTypes[CookoffType].create
					self:CreateShell( CookoffBullet )

						self.Ammo = self.Ammo - 1

						if not isMG then
							timer.Simple(0.001, function()
								if not IsValid(self) then return end
								local Flash = EffectData()
									Flash:SetAttachment( 1 )
									Flash:SetOrigin( self.BulletData.Pos )
									Flash:SetNormal( -vector_up )
									Flash:SetRadius( self.BulletData.RoundVolume ^ 0.4 * 0.75 )
								util.Effect( "ace_cookoff_puff", Flash )

								local HEFlash = EffectData()
									HEFlash:SetOrigin( self.BulletData.Pos )
									HEFlash:SetNormal( -vector_up )
									HEFlash:SetRadius( math.Clamp(self.BulletData.RoundVolume ^ 0.4 * 0.5, 0.6, 6) )
								util.Effect( "ACE_Scaled_Explosion", HEFlash )
							end )

							local MiniRoundType = self.BulletData.Type
							local MiniClass = ACE.GetAmmoCookoffClass(MiniRoundType, IsMissile)
							local HE = ACE.GetAmmoCookoffBlastMass(MiniRoundType, self.BulletData)
							local Propel = self.BulletData.PropMass or 0
							local PropScale = ACE.GetAmmoCookoffPropScale(MiniClass)
							local HEWeight = ((HE + Propel * PropScale * ACE.APAmmoDetonateFactor * (ACE.PBase / ACE.HEPower)) * ACE.BoomMult)
							local RunHE = self.CookoffHEToggle
							self.CookoffHEToggle = not self.CookoffHEToggle

							if HEWeight > 0 and RunHE then
								local MiniWeight = HEWeight * 0.2
								ACE.HE( self.BulletData.Pos , vector_origin , MiniWeight , MiniWeight , self.Inflictor , self, self, 0.5 )
								local radius = math.Clamp(self.BulletData.RoundVolume ^ 0.4 * 0.8, 0.8, 10)
								timer.Simple(0.001, function()
									SpawnMiniHEFlash(self, self.BulletData.Pos, radius)
								end)
							end
						end

						local Duration = math.max( (self.CookoffEnd or Now) - (self.CookoffStart or Now), 0.01 )
						local T = math.Clamp( (Now - (self.CookoffStart or Now)) / Duration, 0, 1 )
						local Delay = math.max( self.CookoffMinDelay or 0.05, (self.CookoffBaseDelay or 0.4) * math.exp(-4 * T) )
						self.CookoffNext = Now + Delay
						self.CookoffCount = self.CookoffCount + 1
						if self.CookoffCount >= (self.CookoffMaxRounds or 1) then
							ScheduleFinalExplosion( self )
						end

					else

						local Duration = math.max( (self.CookoffEnd or Now) - (self.CookoffStart or Now), 0.01 )
						local T = math.Clamp( (Now - (self.CookoffStart or Now)) / Duration, 0, 1 )
						local Delay = math.max( self.CookoffMinDelay or 0.05, (self.CookoffBaseDelay or 0.4) * math.exp(-4 * T) )
						self.CookoffNext = Now + Delay
						if self.CookoffCount >= (self.CookoffMaxRounds or 1) then
							self.CookoffEnd = math.min(self.CookoffEnd or Now, Now + 0.2)
							ScheduleFinalExplosion( self )
						end
					end

					local NextTick = math.max(self.CookoffNext or CurTime() + 0.05, CurTime() + 0.02)
					self:NextThink( NextTick )

				end

			end
		end

	-- Completely new, fresh, genius, beautiful, flawless refill system.
	elseif self.BulletData.Type == "Refill" and self.Load then

		for _,Ammo in pairs( ACE.AmmoCrates ) do

			if Ammo.BulletData.Type ~= "Refill" then

				local distsqrt = self:GetPos():DistToSqr( Ammo:GetPos() )

				if distsqrt < ACE.RefillDistance ^ 2 and Ammo.Capacity > Ammo.Ammo then

					self.SupplyingTo = self.SupplyingTo or {}

					if not table.HasValue( self.SupplyingTo, Ammo:EntIndex() ) then

						table.insert(self.SupplyingTo, Ammo:EntIndex())
						self:RefillEffect( Ammo )

					end

					local Supply = math.ceil((1 / ((Ammo.BulletData.ProjMass + Ammo.BulletData.PropMass) * 5000)) * self:GetPhysicsObject():GetMass() ^ 1.2)
					local Transfert = math.min(Supply, Ammo.Capacity - Ammo.Ammo)
					Ammo.Ammo	= Ammo.Ammo + Transfert

					Ammo.Supplied = true
					Ammo.Entity:EmitSound( "weapons/ar2/ar2_reload.wav", 511, 100, 1 )

				end
			end
		end
	end

	-- checks to stop supply
	if self.SupplyingTo then
		for k, EntID in pairs( self.SupplyingTo ) do
			local Ammo = ents.GetByIndex(EntID)
			if not IsValid( Ammo ) then
				table.remove(self.SupplyingTo, k)
				self:StopRefillEffect( EntID )
			else
				local dist = self:GetPos():Distance(Ammo:GetPos())
				-- If ammo crate is out of refill max distance or is full or our refill crate is damaged or just in-active then stop refiliing it.
				if (dist > ACE.RefillDistance) or (Ammo.Capacity <= Ammo.Ammo) or self.Damaged or not self.Load or not Ammo.Legal then
					table.remove(self.SupplyingTo, k)
					self:StopRefillEffect( EntID )
				end
			end
		end
	end

	Wire_TriggerOutput(self, "Munitions", self.Ammo)
	return true

end

util.AddNetworkString("ACE_RefillEffect")
function ENT:RefillEffect( Target )
	net.Start("ACE_RefillEffect")
		net.WriteUInt( self:EntIndex(), 14 )
		net.WriteUInt( Target:EntIndex(), 14 )
	net.Broadcast()
end

util.AddNetworkString("ACE_StopRefillEffect")
function ENT:StopRefillEffect( TargetID )
	net.Start("ACE_StopRefillEffect")
		net.WriteUInt( self:EntIndex(), 14 )
		net.WriteUInt( TargetID, 14 )
	net.Broadcast()
end

function ENT:OnRemove()

	-- Preserve linked weapons before CFW's removal hook can receive an invalid crate.
	local pointSources = { self }
	for _, Gun in pairs(self.Master or {}) do
		if IsValid(Gun) then pointSources[#pointSources + 1] = Gun end
	end
	self._ACEPointsSuppress = true

	for Key in pairs(self.Master) do
		if self.Master[Key] and self.Master[Key]:IsValid() then
			self.Master[Key]:Unlink( self )
			self.Ammo = 0
		end
	end
	self._ACEPointsSuppress = nil
	if ACE.PointsInputChanged then ACE.PointsInputChanged(pointSources, "ammo-removed") end
	for k,v in pairs(ACE.AmmoCrates) do
		if v == self then
			table.remove(ACE.AmmoCrates,k)
		end
	end

end
