
AddCSLuaFile("shared.lua")
AddCSLuaFile("cl_init.lua")

include("shared.lua")

local GunClasses = ACF.Classes.GunClass

local GunTable  = ACF.Weapons.Guns
local AmmoTable = ACF.Weapons.Ammo
local LegacyAmmoTable = ACF.Weapons.LegacyAmmo

local Inputs = {
	"Active"
}
local Outputs = {
	"Munitions (Returns the current number of rounds in this crate.)",
	"Capacity (Returns the capacity of this crate.)"
}

function ENT:Initialize()

	self.SpecialHealth       = true  --If true needs a special ACF_Activate function
	self.SpecialDamage       = true  --If true needs a special ACF_OnDamage function

	self.IsExplosive         = true
	self.Exploding           = false
	self.Damaged             = false
	self.DamageDelay         = 0

	self.CanUpdate           = true
	self.Load                = false
	self.EmptyMass           = 1
	self.AmmoMassMax         = 0
	self.NextMassUpdate      = 0

	self.Ammo                = 0
	self.IsTwoPiece          = false

	self.NextLegalCheck      = ACF.CurTime + math.random(ACF.Legal.Min, ACF.Legal.Max) -- give any spawning issues time to iron themselves out
	self.Legal               = true
	self.LegalIssues         = ""

	self.Active              = false
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

	ACF.AmmoCrates           = ACF.AmmoCrates or {}

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
	local Health	= self.ACF.Volume / ACF.Threshold						--Setting the threshold of the prop Area gone
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

	function ENT:ACF_OnDamage( Entity, Energy, FrArea, Angle, Inflictor, _, Type )	--This function needs to return HitRes

		local Mul	= (( HEATtbl[Type] and ACF.HEATMulAmmo ) or 1) --Heat penetrators deal bonus damage to ammo
		local HitRes	= ACF_PropDamage( Entity, Energy, FrArea * Mul, Angle, Inflictor ) --Calling the standard damage prop function

		if self.Exploding or not self.IsExplosive then return HitRes end

		if HitRes.Kill then

			if hook.Run("ACF_AmmoExplode", self, self.BulletData ) == false then return HitRes end

			self.Exploding = true

			if Inflictor and IsValid(Inflictor) and Inflictor:IsPlayer() then
				self.Inflictor = Inflictor
			end

			if self.Ammo > 1 and self.BulletData.Type ~= "Refill" then --Not a refill and has ammo. Instant detonation.
				ACF_ScaledExplosion( self, true )
			else
				self:Remove()
			end
		end

		-- cookoff chance calculation
		if self.Damaged then return HitRes end

		if table.IsEmpty( self.BulletData or {} ) then
			self:Remove()
		else

			local Ratio	= math.max(( HitRes.Damage / self.BulletData.RoundVolume ) ^ 0.2, 1.0)
			local CMul	= 1  --30% Chance to detonate, 5% chance to cookoff
			local DetRand	= 0

			--Heat penetrators deal bonus damage to ammo, 90% chance to detonate, 15% chance to cookoff
			if HEATtbl[Type] then
				CMul = 6
			elseif HEtbl[Type] then
				CMul = 10
			end

			if self.BulletData.Type == "Refill" then
				DetRand = 0.75
			else
				DetRand = math.Rand(0,1) * CMul
			end


			--Cookoff chance
			if DetRand > 0.45 then --Passed chance for a cookoff.
				DetRand = math.Rand(0,1)
				self.Exploding = true

				--Instantly detonate all the ammo
				if DetRand < 0.35 then --55% of all ammo detonations

					self.Inflictor  = Inflictor
					self.Damaged	= 1 --Instant explosion guarenteed
					--self.Ammo = self.Ammo * 2

				--Explode a portion of the ammo then cook off
				elseif DetRand < 0.95 then --40% of all ammo detonations

					local DetDelay = 0.001
					if math.Rand(0,1) > 0.25 then --75% chance to have a several second delay before the cookoff starts
						DetDelay = math.Rand(0,3)
						self.DamageDelay = ACF.CurTime + DetDelay
					end


					--util.Effect not working during MP workaround. Waiting a while fixes the issue.

					timer.Simple(DetDelay, function()
						if not IsValid(self) then return end

						local OldAmmo = self.Ammo
						local Ratio = math.Rand(0.1,0.4)
						self.Ammo = math.ceil(OldAmmo * Ratio * 2)
						ACF_ScaledExplosion( self, false ) --Make the crate instantly explode without destroying it. Creates a nice violent explosion.

						--Originally from 0 to 0.5 as half of the ammo was used for the explosion.
						--Lead to inconsistent cookoffs with fast cooking ammo.
						self.Ammo = math.ceil(OldAmmo * (1-Ratio))
					end )

					self.Inflictor  = Inflictor
					self.Damaged	= ACF.CurTime + (10 - Ratio * 8)

				--Long cookoff. Rare.
				else

				if math.Rand(0,1) > 0.2 then --80% chance to have a several second delay before the cookoff starts
					self.DamageDelay = ACF.CurTime + math.Rand(0,3)
				end

				self.Ammo = math.ceil(self.Ammo * math.Rand(0.35,1))

				self.Inflictor  = Inflictor
				self.Damaged	= ACF.CurTime + 15 --Cookoffs until the box runs out of ammo or for 15 seconds. Whichever happens first.

				end

			end


		end

		return HitRes --This function needs to return HitRes
	end

end


do

	-- Checks if the provided string vector matches the desired format.
	-- Define a pattern to match the format
	local pattern = "^%d+%.?%d*:%d+%.?%d*:%d+%.?%d*$"
	local function IsValidStringScale( Id )
		if not isstring( Id ) then return false end
		if not string.match(Id, pattern) then return false end
		return true
	end

	-- Converts an already verified string vector into a valid vector scale.
	local function ParseToVector( ScaleId )
		if not isstring(ScaleId) then return end

		local Result = string.Explode( ":", ScaleId )

		local X = tonumber(Result[1])
		local Y = tonumber(Result[2])
		local Z = tonumber(Result[3])

		return Vector(X, Y, Z)
	end

	-- Clamps the already converted scale so its within the size limits, defined on globals.
	local function ClampScale( Scale )
		if not isvector( Scale ) then return end

		local MinSize = ACF.CrateMinimumSize
		local MaxSize = ACF.CrateMaximumSize

		Scale.x = math.Clamp( math.Round(Scale.x, 1), MinSize, MaxSize)
		Scale.y = math.Clamp( math.Round(Scale.y, 1), MinSize, MaxSize)
		Scale.z = math.Clamp( math.Round(Scale.z, 1), MinSize, MaxSize)

		return Scale
	end

	-- Tries to convert a scale id, having a string format, to a vector scale. If its already a vector, skip the process.
	local function ConvertStringScale( ScaleId )
		if isvector( ScaleId ) then return ScaleId end
		if not IsValidStringScale( ScaleId ) then return end

		local Scale = ParseToVector( ScaleId )
		Scale = ClampScale( Scale )

		return Scale
	end

	-- If the incoming Id belongs to an invalid ammo crate, but belongs to the legacy crates list, convert it into its scalable counterpart.
	local function CreateLegacyScale( Id, Ammo )
		local Content = LegacyAmmoTable[Id]
		Scale = Vector( Content.Length, Content.Width, Content.Height )
		Ammo:SetPos( Ammo:LocalToWorld( vector_up * Content.Offset ) ) -- necessary to do, since some old crates had not a coordinated origin at its center but the base of them.

		return Scale
	end

	function MakeACF_Ammo(Owner, Pos, Angle, Id, Data1, Data2, Data3, Data4, Data5, Data6, Data7, Data8, Data9, Data10, Data11, Data12, Data13, Data14, Data15)

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
			if not ACE_CheckAmmo( Id ) then

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
			if ACE_CheckAmmo( Id ) then

				local AmmoData = AmmoTable[Id]

				Model = AmmoData.model
				Weight = AmmoData.weight
				Dimensions = Vector( AmmoData.Lenght, AmmoData.Width, AmmoData.Height )

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

			table.insert(ACF.AmmoCrates, Ammo)

			return Ammo
		end
	end
end

list.Set( "ACFCvars", "acf_ammo", {"id", "data1", "data2", "data3", "data4", "data5", "data6", "data7", "data8", "data9", "data10", "data11", "data12", "data13", "data14", "data15"} )
duplicator.RegisterEntityClass("acf_ammo", MakeACF_Ammo, "Pos", "Angle", "Id", "RoundId", "RoundType", "RoundPropellant", "RoundProjectile", "RoundData5", "RoundData6", "RoundData7", "RoundData8", "RoundData9", "RoundData10" , "RoundData11", "RoundData12", "RoundData13", "RoundData14", "RoundData15" )


function ENT:Update( ArgsTable )

	-- That table is the player data, as sorted in the ACFCvars above, with player who shot,
	-- and pos and angle of the tool trace inserted at the start

	local msg = "Ammo crate updated successfully!"

	if ArgsTable[6] == "Refill" then -- Argtable[6] is the round type. If it's refill it shouldn't be loaded into guns, so we refuse to change to it
		return false, "Refill ammo type is only avaliable for new crates!"
	end

	if ArgsTable[5] ~= self.RoundId then -- Argtable[5] is the weapon ID the new ammo loads into
		for _, Gun in pairs( self.Master ) do
			if IsValid( Gun ) then
				Gun:Unlink( self )
			end
		end
		msg = "New ammo type loaded, crate unlinked."
	else -- ammotype wasn't changed, but let's check if new roundtype is blacklisted
		local Blacklist = ACF.AmmoBlacklist[ ArgsTable[6] ] or {}

		for _, Gun in pairs( self.Master ) do
			if IsValid( Gun ) and table.HasValue( Blacklist, Gun.Class ) then
				Gun:Unlink( self )
				msg = "New round type cannot be used with linked gun, crate unlinked."
			end
		end
	end

	local AmmoPercent = self.Ammo / math.max(self.Capacity,1)

	self:CreateAmmo(ArgsTable[4], ArgsTable[5], ArgsTable[6], ArgsTable[7], ArgsTable[8], ArgsTable[9], ArgsTable[10], ArgsTable[11], ArgsTable[12], ArgsTable[13], ArgsTable[14], ArgsTable[15], ArgsTable[16], ArgsTable[17], ArgsTable[18], ArgsTable[19])

	self.Ammo = math.floor(self.Capacity * AmmoPercent)

	self.LastMass = 1 -- force update of mass
	self:UpdateMass()

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

		local RoundData = ACF.RoundTypes[ self.BulletData.Type ]

		if RoundData and RoundData.cratetxt then
			text = text .. "\n" .. RoundData.cratetxt( self.BulletData, self )
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
		text = text .. "\n\nNot legal, disabled for " .. math.ceil(self.NextLegalCheck - ACF.CurTime) .. "s\nIssues: " .. self.LegalIssues
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

		if not ACE_CheckGun( Data1 ) then
			Data1 = BackComp[Data1] or "100mmC"
		end
		if not ACE_CheckRound( Data2 ) then
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

		self.ConvertData    = ACF.RoundTypes[self.RoundType].convert
		self.BulletData     = self:ConvertData( PlayerData )

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
			self.ACEPoints = 4000
		else

			self.IsTwoPiece = false

			--Getting entity's dimensions
			local Dimensions = self.Dimensions

			local GunId = AmmoGunData.gunclass
			local WeaponType = GunClasses[GunId].type

			local width
			local shellLength

			if WeaponType == "missile" then

				width = AmmoGunData.modeldiameter or (AmmoGunData.caliber / ACF.AmmoLengthMul / toInch)
				shellLength = AmmoGunData.length / ACF.AmmoLengthMul / toInch

			else

				width = AmmoGunData.caliber / ACF.AmmoWidthMul / toInch
				shellLength = ((self.BulletData.PropLength or 0) + (self.BulletData.ProjLength or 0)) / ACF.AmmoLengthMul / toInch

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

			if WeaponType ~= "missile" then
				self.ACEPoints = math.ceil(AmmoMaxMass / 1000 * ACE.AmmoPerTon)
			else
				local BulletData2 = ACFM_CompactBulletData(self)
				local MissileCost = CalculateMissileCost(BulletData2)
				self.ACEPoints = Capacity * MissileCost
			end

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

		self.NetworkData = ACF.RoundTypes[self.BulletData.Type].network
		self:NetworkData( self.BulletData )

		Wire_TriggerOutput( self, "Capacity", self.Capacity )
		self:UpdateOverlayText()

	end

end

function ENT:UpdateMass()

	self.Mass = self.EmptyMass + math.Round( self.AmmoMassMax * (self.Ammo / math.max(self.Capacity,1)) )

	--reduce superflous engine calls, update crate mass every 5 kgs change or every 10s-15s
	if math.abs((self.LastMass or 0) - self.Mass) > 5 or ACF.CurTime > self.NextMassUpdate then

		self.LastMass	= self.Mass
		self.NextMassUpdate = ACF.CurTime + math.Rand(10,15)

		local phys = self:GetPhysicsObject()
		if (phys:IsValid()) then

			phys:SetMass( self.Mass )

		end
	end

end

function ENT:GetInaccuracy()
	--local SpreadScale = ACF.SpreadScale
	local inaccuracy = 0
	local Gun = GunTable[self.RoundId]

	if Gun then
		inaccuracy = (GunClasses[Gun.gunclass] or {spread = 0}).spread
	end

	local coneAng = inaccuracy * ACF.GunInaccuracyScale
	return coneAng
end

function ENT:TriggerInput( iname, value )

	if (iname == "Active") then
		if value > 0 then
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
			Gun:LoadAmmo(false, false)
		end
	end

end

function ENT:Think()

	if not self.BulletData then return false end

	if ACF.CurTime > self.NextLegalCheck then

		self.Legal, self.LegalIssues = ACF_CheckLegal(self, self.Model, math.min(math.Round(self.EmptyMass,2),50000), nil, true, true)
		self.NextLegalCheck = ACF.Legal.NextCheck(self.legal)
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

		if self.DamageDelay < ACF.CurTime then
			local CrateType = self.BulletData.Type or "Refill"

			--If that is a refill, remove it
			if CrateType == "Refill" then

				self:Remove()

			-- immediately detonate if there's 1 or 0 shells
			elseif self.Ammo <= 1 or self.Damaged < CurTime() then

				ACF_ScaledExplosion( self, true ) -- going to let empty crates harmlessly poot still, as an audio cue it died

			else

				--if math.Rand(20,150) > self.BulletData.RoundVolume ^ 0.5 and math.Rand(0,1) < self.Ammo / math.max(self.Capacity,1) and ACF.RoundTypes[CrateType] then
				if math.Rand(0,1) < self.Ammo / math.max(self.Capacity,1) and ACF.RoundTypes[CrateType] then

					self:EmitSound( "acf_other/explosions/cookoff/cookOff" .. math.random(1,4) .. ".mp3", 550, math.max(140 - self.BulletData.PropMass * 35,35)  )
					self.BulletCookSpeed	= self.BulletCookSpeed or ACF_MuzzleVelocity( self.BulletData.PropMass, self.BulletData.ProjMass / 2, self.Caliber )

					self.BulletData.Tracer = 1
					self.RoundData10 = 1

					self.BulletData.Pos = self:LocalToWorld(self:OBBCenter() + VectorRand() * (self:OBBMaxs() - self:OBBMins()) / 2)
					self.BulletData.Flight  = (VectorRand()):GetNormalized() * self.BulletCookSpeed * 39.37 + self:GetVelocity() * 0.25

					self.BulletData.Owner	= self.BulletData.Owner or self.Inflictor or self:CPPIGetOwner()
					self.BulletData.Gun	= self.BulletData.Gun	or self
					self.BulletData.Crate	= self.BulletData.Crate or self:EntIndex()

					self.CreateShell		= ACF.RoundTypes[CrateType].create
					self:CreateShell( self.BulletData )

					self.Ammo = self.Ammo - 1


						--util.Effect not working during MP workaround. Waiting a while fixes the issue.
						timer.Simple(0.001, function()
							local Flash = EffectData()
								Flash:SetAttachment( 1 )
								Flash:SetOrigin( self.BulletData.Pos )
								Flash:SetNormal( -vector_up )
								Flash:SetRadius( self.BulletData.RoundVolume ^ 0.4 * 0.75 )
							util.Effect( "ace_cookoff_puff", Flash )
						end )

						--1 in 3 chance to create explosion for double round's HE weight

						if math.Rand(0,1) > 0.5 then

							local HE       = self.BulletData.FillerMass	or 0
							local Propel   = self.BulletData.PropMass	or 0

							local HEWeight = ((  HE + Propel * ACF.APAmmoDetonateFactor * ( ACF.PBase / ACF.HEPower) ) * ACF.BoomMult)
							local HERadius = ACE_CalculateHERadius( HEWeight )

							ACF_HE( self.BulletData.Pos , vector_origin , HEWeight , HEWeight , Inflictor , ent, ent )

							--util.Effect not working during MP workaround. Waiting a while fixes the issue.
							timer.Simple(0.001, function()
								local Flash = EffectData()
									Flash:SetAttachment( 1 )
									Flash:SetOrigin( self.BulletData.Pos )
									Flash:SetNormal( -vector_up )
									Flash:SetRadius( math.Round(math.max(HERadius / 39.37, 1),2) )
								util.Effect( "acf_scaled_explosion", Flash )
							end )

					end

				end

				self:NextThink( CurTime() + self.ExplosionInterval + (self.BulletData.RoundVolume ^ 0.5 / 150 ) )

			end
		end

	-- Completely new, fresh, genius, beautiful, flawless refill system.
	elseif self.BulletData.Type == "Refill" and self.Load then

		for _,Ammo in pairs( ACF.AmmoCrates ) do

			if Ammo.BulletData.Type ~= "Refill" then

				local distsqrt = self:GetPos():DistToSqr( Ammo:GetPos() )

				if distsqrt < ACF.RefillDistance ^ 2 and Ammo.Capacity > Ammo.Ammo then

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
				if (dist > ACF.RefillDistance) or (Ammo.Capacity <= Ammo.Ammo) or self.Damaged or not self.Load or not Ammo.Legal then
					table.remove(self.SupplyingTo, k)
					self:StopRefillEffect( EntID )
				end
			end
		end
	end

	Wire_TriggerOutput(self, "Munitions", self.Ammo)
	return true

end

util.AddNetworkString("ACF_RefillEffect")
function ENT:RefillEffect( Target )
	net.Start("ACF_RefillEffect")
		net.WriteUInt( self:EntIndex(), 14 )
		net.WriteUInt( Target:EntIndex(), 14 )
	net.Broadcast()
end

util.AddNetworkString("ACF_StopRefillEffect")
function ENT:StopRefillEffect( TargetID )
	net.Start("ACF_StopRefillEffect")
		net.WriteUInt( self:EntIndex(), 14 )
		net.WriteUInt( TargetID, 14 )
	net.Broadcast()
end

function ENT:OnRemove()

	for Key in pairs(self.Master) do
		if self.Master[Key] and self.Master[Key]:IsValid() then
			self.Master[Key]:Unlink( self )
			self.Ammo = 0
		end
	end
	for k,v in pairs(ACF.AmmoCrates) do
		if v == self then
			table.remove(ACF.AmmoCrates,k)
		end
	end

end
