AddCSLuaFile("cl_init.lua")
AddCSLuaFile("shared.lua")

include("shared.lua")

local GunClasses = ACE.Classes.GunClass

local GunTable = ACE.Weapons.Guns

--The distances these ents would have if its caliber was 10mm. Incremented by caliber size.
local CrewLinkDistBase = 200
local AmmoLinkDistBase = 512

local function AttemptFirstLoad(Gun, Crate)
	if not IsValid(Gun) or not IsValid(Crate) then return end
	if Gun.BulletData.Type ~= "Empty" then return end
	if not Crate.Load or not Gun.FirstLoad or not Gun.Legal then return end

	-- Reload=true sends the scale-0 muzzleflash effect (no sound/flash), which runs the client
	-- Animate(LoadOnly) that initializes the gun's animation state. Without it the client stays in
	-- cl_init's default state (Reload == CloseTime -> infinite playback rate + per-Think
	-- ResetSequence), which strobes the load animation.
	Gun:LoadAmmo(false, true)
end

-- Compute the next-shot reload time without mutating ammo, stamina, or the active
-- reload timer. Link changes and ROFLimit use this same calculation as LoadAmmo so
-- the visible Fire Rate cannot lag behind the configured weapon state.
local function GetGunReloadTime(Gun, BulletData, RoFMul)
	if not BulletData then return end

	local Adj = BulletData.LengthAdj or 1
	local MaxRof = Gun.ROFLimit
	if Gun.maxrof then
		MaxRof = MaxRof ~= 0 and math.min(Gun.maxrof, MaxRof) or Gun.maxrof
	end

	local FireRateModifier = Gun.RoFmod * Gun.PGRoFmod * ((RoFMul or 0) + 1)
	local DefaultReloadTime = ((math.max(BulletData.RoundVolume, Gun.MinLengthBonus / Adj) / 500) ^ 0.60)
		* FireRateModifier
	local LowestReloadTime = MaxRof > 0 and 60 / MaxRof or DefaultReloadTime
	local Loader = Gun:ChooseLoader()
	local CanUseLoader = not ACE_table_contains({ "AC", "MG", "RAC", "HMG", "GL", "SA" }, Gun.Class)
		and Gun.maxrof and Gun.LoaderCount > 0 and IsValid(Loader)

	if CanUseLoader then
		local CrewReload = Loader.Stamina / 100
		return math.Clamp(LowestReloadTime / CrewReload, LowestReloadTime, DefaultReloadTime), Loader
	end

	return math.max(DefaultReloadTime, LowestReloadTime)
end

local function RefreshGunRateOfFire(Gun, AmmoEnt)
	local BulletData
	local RoFMul
	if IsValid(AmmoEnt) and AmmoEnt.BulletData then
		BulletData = AmmoEnt.BulletData
		RoFMul = AmmoEnt.RoFMul
	elseif Gun.BulletData and Gun.BulletData.Type ~= "Empty" then
		BulletData = Gun.BulletData
		local Crate = BulletData.Crate and Entity(BulletData.Crate)
		RoFMul = IsValid(Crate) and Crate.RoFMul or 0
	end

	local ReloadTime = GetGunReloadTime(Gun, BulletData, RoFMul)
	if not ReloadTime then return false end

	Gun.RateOfFire = 60 / ReloadTime
	Wire_TriggerOutput(Gun, "Fire Rate", Gun.RateOfFire)

	return true
end

function ENT:Initialize()

	self.ReloadTime          = 1

	self.FirstLoad           = true
	self.Ready               = true
	self.Firing              = nil
	self.Reloading           = nil
	self.NextFire            = 0
	self.LastSend            = 0
	self.LastLoadDuration    = 0
	self.NextLegalCheck      = ACE.CurTime + math.random(ACE.Legal.Min, ACE.Legal.Max) -- give any spawning issues time to iron themselves out
	self.Legal               = true
	self.LegalIssues         = ""
	self.FuseTime            = 0
	self.OverrideFuse        = false		-- Override disabled by default
	self.ROFLimit            = 0			-- Used for selecting firerate

	self.IsMaster            = true		-- needed?
	self.OTWarnings	         = {} --Used to remember all the one time warnings.
	self.AmmoLink            = {}
	self.CrewLink            = {}
	self.HasGunner           = false
	self.RequiresGunner      = false
	self.LoaderCount         = 0
	self.CurAmmo             = 1
	self.Sequence            = 1
	self.GunClass            = "MG"

	self.Heat                = ACE.AmbientTemp
	self.IsOverheated        = false

	self.BulletData          = {}
	self.BulletData.Type     = "Empty"
	self.BulletData.PropMass = 0
	self.BulletData.ProjMass = 0

	self.Inaccuracy          = 1
	self.KERecoil			 = 0
	self.LastThink           = 0

	self.CanLegalCheck		= true

	self:CallOnRemove("ACE_Points", function(ent)
		if ACE_PointsInputChanged then ACE_PointsInputChanged(ent, "gun-removed") end
	end)
end

do
	local Inputs = {
		Fire        = "Fire (Shoots a bullet if loaded. Hold to keep shooting.)",
		Unload      = "Unload (Unloads the current shell from the gun. Leaving the gun empty.)",
		Reload      = "Reload (Reloads the current weapon, according to the active ammo it has.)",
		FuseTime    = "Fuse Time (Defines the required time for shell self-detonation in seconds. \nThis only work with SM, HE & HEAT rounds. \nNote that this is not really accurate.)",
		ROFLimit    = "ROFLimit (Adjusts the Gun's Rate of Fire. \nNote that setting this to 0 WILL disable overriding! \nIf you want lower rof, use values like 0.1.)",
	}
	local Outputs = {
		Ready           = "Ready (Returns if the gun is ready to fire.)",
		AmmoCount       = "AmmoCount (Returns the total ammo this gun can shoot.)",
		Entity          = "Entity [ENTITY]",
		ShotsLeft       = "Shots Left (Returns the number of shots in the gun.)",
		FireRate        = "Fire Rate (Returns the Rate of Fire of this gun)",
		MuzzleWeight    = "Muzzle Weight (Returns the muzzle weight)",
		MuzzleVelocity  = "Muzzle Velocity (Returns the muzzle velocity)" ,
		Heat            = "Heat (Returns the gun's temperature.)",
		OverHeat        = "OverHeat (Is the gun overheating?)"
	}

	local Inputs_Fuse = {
		Inputs.Fire,
		Inputs.Unload,
		Inputs.Reload,
		Inputs.FuseTime,
		Inputs.ROFLimit
	}
	local Inputs_NoFuse = {
		Inputs.Fire,
		Inputs.Unload,
		Inputs.Reload,
		Inputs.ROFLimit
	}
	local Inputs_Fuse_noreload = {
		Inputs.Fire,
		Inputs.Unload,
		Inputs.FuseTime,
		Inputs.ROFLimit
	}
	local Inputs_NoFuse_noreload = {
		Inputs.Fire,
		Inputs.Unload,
		Inputs.ROFLimit
	}
	local Outputs_Default = {
		Outputs.Ready,
		Outputs.AmmoCount,
		Outputs.Entity,
		Outputs.ShotsLeft,
		Outputs.FireRate,
		Outputs.MuzzleWeight,
		Outputs.MuzzleVelocity,
		Outputs.Heat,
		Outputs.OverHeat
	}

	--List of ids which no longer stay on ACE. Useful to replace them with the closest counterparts
	local BackComp = {
		["20mmHRAC"]     = "20mmRAC",
		["30mmHRAC"]     = "30mmRAC",
		["40mmGLSingle"] = "40mmSL",
		["105mmSB"]      = "100mmSBC",
		["120mmSB"]      = "120mmSBC",
		["140mmSB"]      = "140mmSBC",
		["170mmSB"]      = "170mmSBC"

	}

	local rapidgun = {
		RAC = true,
		MG  = true,
		AC  = true,
		SA  = true,
		HMG = true
	}

	function ACE_MakeGun(Owner, Pos, Angle, Id)

		local Gun = ents.Create("acf_gun")
		if not IsValid(Gun) then return false end

		if not ACE_CheckGun( Id ) then
			Id = BackComp[Id] or "100mmC"
		end

		local Lookup	= GunTable[Id]
		local ClassData = GunClasses[Lookup.gunclass]

		if Lookup.gunclass == "SL" then
			if not Owner:CheckLimit("_ace_smokelauncher") then return false end
			Owner:AddCount("_ace_smokelauncher", Gun)

		elseif rapidgun[Lookup.gunclass] then
			if not Owner:CheckLimit("_ace_rapidgun") then return false end
			Owner:AddCount("_ace_rapidgun", Gun)

		elseif Lookup.caliber >= ACE.LargeCaliber then
			if not Owner:CheckLimit("_ace_largegun") then return false end
			Owner:AddCount("_ace_largegun", Gun)

		else
			if not Owner:CheckLimit("_ace_gun") then return false end
			Owner:AddCount("_ace_gun", Gun)
		end

		Gun:SetAngles(Angle)
		Gun:SetPos(Pos)
		Gun:Spawn()
		Gun:CPPISetOwner(Owner)
		Gun.Id              = Id
		Gun.Caliber         = Lookup.caliber
		Gun.Model           = Lookup.model
		Gun.Mass            = Lookup.weight
		Gun.Class           = Lookup.gunclass
		Gun.Heat            = ACE.AmbientTemp
		Gun.LinkRangeMul    = math.max(Gun.Caliber / 10,1) ^ 1.2
		Gun.RequiresGunner	= false
		local GunnerExcluded	= Lookup.gunnerexception or false

		Gun.noloaders	= ClassData.noloader or nil

		Gun.Inaccuracy = ClassData.spread

		if not GunnerExcluded and (Gun.Caliber * 10) > ACE.LargeGunsThreshold and ACE.LargeGunsRequireGunners ~= 0 then --If the caliber is large enough it requires a gunner.
			Gun.RequiresGunner = true
		end

		if ClassData.color then
			Gun:SetColor(Color(ClassData.color[1],ClassData.color[2],ClassData.color[3], 255))
		end

		Gun.PGRoFmod	= Lookup.rofmod and math.max(0.01, Lookup.rofmod) or 1 --per gun rof
		Gun.maxrof = Lookup.maxrof
		Gun.CurrentShot = 0
		Gun.MagSize	= 1

		--IDK why does this has been broken, giving it sense now
		--to cover guns that uses magazines
		if Lookup.magsize then

			Gun.MagSize = math.max(Gun.MagSize, Lookup.magsize)
			local Cal = Gun.Caliber

			if Cal >= 3 then
				Gun.Inputs = WireLib.CreateInputs( Gun, Inputs_Fuse )
			else
				Gun.Inputs = WireLib.CreateInputs( Gun, Inputs_NoFuse )
			end

		--to cover guns that get its ammo directly from the crate
		else
			local Cal = Gun.Caliber

			if Cal >= 3 then
				Gun.Inputs = WireLib.CreateInputs( Gun, Inputs_Fuse_noreload )
			else
				Gun.Inputs = WireLib.CreateInputs( Gun, Inputs_NoFuse_noreload )
			end
		end

		Gun.Outputs = WireLib.CreateOutputs( Gun, Outputs_Default )

		Wire_TriggerOutput(Gun, "Entity", Gun)

		Gun.MagReload = 0
		if Lookup.magreload then
			Gun.MagReload = math.max(Gun.MagReload, Lookup.magreload )
		end

		Gun.MinLengthBonus    = 0.5 * 3.1416 * (Gun.Caliber / 2) ^ 2 * Lookup.round.maxlength

		Gun.Muzzleflash       = Lookup.muzzleflash or ClassData.muzzleflash
		Gun.RoFmod            = ClassData.rofmod
		Gun.RateOfFire        = 1 --updated when gun is linked to ammo
		Gun.Sound             = Lookup.sound or ClassData.sound
		Gun.DefaultSound      = Gun.Sound
		Gun.SoundPitch        = 100
		Gun.AutoSound         = ClassData.autosound and (Lookup.autosound or ClassData.autosound) or nil
		Gun.CurrentRecoil     = 0

		Gun:SetNWInt( "Caliber", Gun.Caliber )
		Gun:SetNWString( "WireName", Lookup.name )
		Gun:SetNWString( "Class", Gun.Class )
		Gun:SetNWString( "ID", Gun.Id )
		Gun:SetNWString( "Muzzleflash", Gun.Muzzleflash )
		Gun:SetNWString( "Sound", Gun.Sound )
		Gun:SetNWInt( "SoundPitch", Gun.SoundPitch )

		Gun:SetModel( Gun.Model )

		Gun:PhysicsInit( SOLID_VPHYSICS )
		Gun:SetMoveType( MOVETYPE_VPHYSICS )
		Gun:SetSolid( SOLID_VPHYSICS )

		local Muzzle = Gun:GetAttachment( Gun:LookupAttachment( "muzzle" ) )
		Gun.Muzzle = Gun:WorldToLocal(Muzzle.Pos)

		local longbarrel = ClassData.longbarrel
		if longbarrel ~= nil then
			timer.Simple(0.25, function() --need to wait until after the property is actually set
				if not IsValid(Gun) then return end
				if Gun:GetBodygroup( longbarrel.index ) == longbarrel.submodel then
					local Muzzle = Gun:GetAttachment( Gun:LookupAttachment( longbarrel.newpos ) )
					Gun.Muzzle = Gun:WorldToLocal(Muzzle.Pos)
				end
			end)
		end

		local phys = Gun:GetPhysicsObject()
		if IsValid( phys ) then
			phys:SetMass( Gun.Mass )
			Gun.ModelInertia = 0.99 * phys:GetInertia() / phys:GetMass() -- giving a little wiggle room
		end

		Gun:UpdateOverlayText()

		Owner:AddCleanup("acemenu", Gun)

		ACE_Activate(Gun, 0)

		return Gun

	end
end

list.Set( "ACFCvars", "acf_gun", {"id"} )
duplicator.RegisterEntityClass("acf_gun", ACE_MakeGun, "Pos", "Angle", "Id")

function ENT:UpdateOverlayText()

	local roundType = self.BulletData.Type

	if self.BulletData.Tracer and self.BulletData.Tracer > 0 then
		roundType = roundType .. "-T"
	end

	local isEmpty = self.BulletData.Type == "Empty"

	local clipLeft	= isEmpty and 0 or (self.MagSize - self.CurrentShot)
	local ammoLeft	= (self.Ammo or 0) + clipLeft
	local isReloading	= not isEmpty and CurTime() < self.NextFire and (self.MagSize == 1 or (self.LastLoadDuration > self.ReloadTime))
	local gunStatus	= isReloading and "reloading" or (clipLeft .. " in gun")

	local text = roundType .. " - " .. ammoLeft .. (ammoLeft == 1 and " shot left" or " shots left ( " .. gunStatus .. " )")

	text = text .. "\nRounds Per Minute: " .. math.Round( self.RateOfFire or 0, 2 )

	if ACE_GetGunFirepowerReadout then
		local readout = ACE_GetGunFirepowerReadout(self)
		if readout then
			text = text .. "\nFirepower: " .. string.Comma(math.Round(readout.Points)) .. " pts"
			local roundLine = readout.Round and ACE_GetRoundLethalityLine
				and ACE_GetRoundLethalityLine(readout.Round, true)
			if roundLine then text = text .. "\nBest Round: " .. roundLine end
			if readout.MinimumApplied then
				text = text .. "\nWeapon Minimum Applied: " .. string.Comma(math.Round(readout.Points)) .. " pts"
			end
			local floorLine = ACE_GetRateFloorLine and ACE_GetRateFloorLine(readout, true)
			if floorLine then text = text .. "\n" .. floorLine end
		end
	end

	text = text .. "\nTemp: " .. math.Round(self.Heat) .. " °C / 200 °C"

	if #self.CrewLink > 0 then
		text = text .. "\n\nHas Gunner: " .. (self.HasGunner and "Yes" or "No")
		text = text .. ( self.noloaders and "" or "\nTotal Loaders: " .. self.LoaderCount  )
	end

	if self.IsOverheated then
		text = text .. "\nWarning: Overheated"
	end

	if not self.Legal then
		text = text .. "\n\nNot legal, disabled for " .. math.ceil(self.NextLegalCheck - ACE.CurTime) .. "s\nIssues: " .. self.LegalIssues
	end

	self:SetOverlayText( text )


end

local function IsInRetDist( enta, entb, Distance )
	if not IsValid(enta) or not IsValid(entb) then return end
	return ACE_InDist( enta:GetPos(), entb:GetPos(), Distance )
end

local BreakSoundTbl = {
	ace_crewseat_gunner = "physics/metal/metal_canister_impact_hard",
	ace_crewseat_loader = "physics/metal/metal_canister_impact_hard",
	acf_ammo = "physics/metal/metal_box_impact_bullet",
}

local function BreakGunLink( Gun, LinkedEnt )
	Gun:Unlink( LinkedEnt )
	Gun:EmitSound( (BreakSoundTbl[LinkedEnt:GetClass()] or "physics/metal/metal_box_impact_bullet" ) .. tostring(math.random(1, 3)) .. ".wav", 100, 100)
end

function ENT:Link( Target )

	if not IsValid( Target ) then
		return false, "Target not a valid entity!"
	end

	if not Target.Legal then
		return false, "This entity is illegal!"
	end

	-- CrewLink
	-- the gunner
	if Target:GetClass() == "ace_crewseat_gunner" then

		--Don't link if it's already linked
		for _, v in pairs( self.CrewLink ) do
			if v == Target then
				return false, "That crewseat is already linked to this gun!"
			end
		end

		--Don't link if it's too far from this gun
		if not IsInRetDist( self, Target, CrewLinkDistBase * self.LinkRangeMul ) then
			return false, "That crewseat is too far to be linked to this gun!"
		end

		--Don't link if it's already linked
		if self.HasGunner then
			return false, "The gun already has a gunner!"
		end

		table.insert( self.CrewLink, Target )
		table.insert( Target.Master, self )

		self.HasGunner = true
		Target.LinkedGun = self
		RefreshGunRateOfFire(self)

		if ACE_PointsInputChanged and not self._ACEPointsSuppress and (not Target or not Target._ACEPointsSuppress) then
			ACE_PointsInputChanged({ self, Target }, "gunner-linked")
		end
		return true, "Link successful!"

	-- the loader
	elseif Target:GetClass() == "ace_crewseat_loader" then

		-- Don't link if it's already linked
		for _, v in pairs( self.CrewLink ) do
			if v == Target then
				return false, "That crewseat is already linked to this gun!"
			end
		end

		--Don't link if it's too far from this gun
		if not IsInRetDist( self, Target, CrewLinkDistBase * self.LinkRangeMul ) then
			return false, "That crewseat is too far to be linked to this gun!"
		end

		if not self.HasGunner then --IK there is going to be an exploit to delete the gunner after placing a loader but idk how to fix *shrugs* --NO LONGER
			return false, "You need a gunner before you can have a loader!"
		end

		if self.noloaders then
			return false, "This gun cannot have a loader!"
		end

		table.insert( self.CrewLink, Target )
		table.insert( Target.Master, self )

		self.LoaderCount = self.LoaderCount + 1
		Target.LinkedGun = self
		RefreshGunRateOfFire(self)

		if ACE_PointsInputChanged and not self._ACEPointsSuppress and (not Target or not Target._ACEPointsSuppress) then
			ACE_PointsInputChanged({ self, Target }, "loader-linked")
		end
		return true, "Link successful!"

	--Ammo Link
	elseif Target:GetClass() == "acf_ammo" then

		-- Don't link if it's already linked
		for _, v in pairs( self.AmmoLink ) do
			if v == Target then
				return false, "That crate is already linked to this gun!"
			end
		end

		-- Dont't link if it's too far from this gun
		if not IsInRetDist( self, Target, AmmoLinkDistBase * self.LinkRangeMul ) then
			return false, "That crate is too far to be connected with this gun!"
		end

		-- Don't link if it's a refill crate
		if Target.RoundType == "Refill" then
			return false, "Refill crates cannot be linked!"
		end

		-- Don't link if it's not the right ammo type
		if Target.BulletData.Id ~= self.Id then
			return false, "Wrong ammo type!"
		end

		-- Don't link if it's a blacklisted round type for this gun
		local Blacklist = ACE.AmmoBlacklist[ Target.RoundType ] or {}

		if table.HasValue( Blacklist, self.Class ) then
			return false, "That round type cannot be used with this gun!"
		end

		table.insert( self.AmmoLink, Target )
		table.insert( Target.Master, self )

		if self.BulletData.Type == "Empty" and self.FirstLoad then
			timer.Simple(0, function()
				AttemptFirstLoad(self, Target)
			end)
		end

		RefreshGunRateOfFire(self, Target)
		Wire_TriggerOutput( self, "Muzzle Weight", math.floor( Target.BulletData.ProjMass * 1000 ) )
		Wire_TriggerOutput( self, "Muzzle Velocity", math.floor( Target.BulletData.MuzzleVel * ACE.VelScale ) )

		if ACE_PointsInputChanged and not self._ACEPointsSuppress and (not Target or not Target._ACEPointsSuppress) then
			ACE_PointsInputChanged({ self, Target }, "gun-ammo-linked")
		end
		return true, "Link successful!"

	else
		return false, "Guns can only be linked to ammo crates or crew seats!"
	end

end

function ENT:Unlink( Target )

	local Success = false
	for Key,Value in pairs(self.AmmoLink) do
		if Value == Target then
			table.remove(self.AmmoLink,Key)
			Success = true
		end
	end
	for Key,Value in pairs(self.CrewLink) do
		if Value == Target then
			if Target:GetClass() == "ace_crewseat_gunner" then
				self.HasGunner = false
			elseif Target:GetClass() == "ace_crewseat_loader" then
				self.LoaderCount = self.LoaderCount - 1
			end

			Target.LinkedGun = nil

			table.remove(self.CrewLink,Key)
			Success = true
		end
	end

	if Success then
		RefreshGunRateOfFire(self)
		if ACE_PointsInputChanged and not self._ACEPointsSuppress and (not Target or not Target._ACEPointsSuppress) then
			ACE_PointsInputChanged({ self, Target }, "gun-unlinked")
		end
		return true, "Unlink successful!"
	else
		return false, "That entity is not linked to this gun!"
	end

end

function ENT:CanProperty( _, property )

	if property == "bodygroups" then
		local longbarrel = GunClasses[self.Class].longbarrel
		if longbarrel ~= nil then
			timer.Simple(0.25, function() --need to wait until after the property is actually set
				if self:GetBodygroup( longbarrel.index ) == longbarrel.submodel then
					local Muzzle = self:GetAttachment( self:LookupAttachment( longbarrel.newpos ) )
					self.Muzzle = self:WorldToLocal(Muzzle.Pos)
				else
					local Muzzle = self:GetAttachment( self:LookupAttachment( "muzzle" ) )
					self.Muzzle = self:WorldToLocal(Muzzle.Pos)
				end
			end)
		end
	end

	return true

end

function ENT:TriggerInput(iname, value)
	if iname == "Unload" and value > 0 and not self.Reloading then
		-- Triggered to unload ammo
		self:UnloadAmmo()
	elseif iname == "Fire" and value > 0 and ACE.GunfireEnabled and self.Legal then
		-- Triggered to fire if conditions are met
		if self.NextFire < CurTime() then
			-- Check if it's time to fire
			self.User = ACE_GetWeaponUser(self, self.Inputs.Fire.Src)
			if not IsValid(self.User) then
				self.User = self:CPPIGetOwner()
			end
			self:FireShell()
			self:Think()
			self.Firing = true
		end
	elseif iname == "Fire" and value <= 0 then
		-- Triggered to stop firing
		self.Firing = false
	elseif iname == "Reload" and value ~= 0 then
		-- Triggered to start reloading
		self.Reloading = true
	elseif iname == "Fuse Time" then
		-- Set the fuse time if value is greater than 0
		if value > 0 then
			self.FuseTime = value
			self.OverrideFuse = true
		else
			self.FuseTime = 0
			self.BulletData.FuseLength = 0
			self.OverrideFuse = false
		end
	elseif iname == "ROFLimit" then
		-- Set the rate of fire limit if value is greater than 0
		local lowestROF = 0.1
		local oldLimit = self.ROFLimit
		if value > 0 then
			self.ROFLimit = math.max(value, lowestROF) -- Limit the rate of fire
		else
			self.ROFLimit = 0
		end

		if oldLimit ~= self.ROFLimit then
			RefreshGunRateOfFire(self)
			if ACE_PointsInputChanged then
				ACE_PointsInputChanged(self, "gun-rof-limit")
			end
		end
	end
end



function ENT:Heat_Function()

	--print(DeltaTime)

	self.Heat = ACE_HeatFromGun( self , self.Heat, self.DeltaTime )
	Wire_TriggerOutput(self, "Heat", math.Round(self.Heat))

	-- TODO: instead of breaking the gun by heat, decrease accurancy and jam it
	local OverHeat = math.max(self.Heat / 200, 0) --overheat will start affecting the gun at 200° celcius. STILL unrealistic, weird
	if OverHeat > 1 and self.Caliber < 10 then  --leave the low calibers to damage themselves only

		self.IsOverheated = true
		Wire_TriggerOutput(self,"OverHeat", 1)

		--local phys = self:GetPhysicsObject()
		--local Mass = phys:GetMass()

		--[[
		HitRes = ACE_Damage(self, {
			Kinetic = (1 * OverHeat) * (1 + math.max(Mass - 300, 0.1)),
			Momentum = 0,
			Penetration = (1 * OverHeat) * (1 + math.max(Mass - 300, 0.1))
		}, 2, 0, self:CPPIGetOwner())

		if HitRes.Kill then
			ACE_HEKill( self, VectorRand() , 0)
		end
		]]--

	else
		self.IsOverheated = false
		Wire_TriggerOutput(self,"OverHeat", 0)
	end

end

function ENT:TrimDistantCrates()

	for _, Crate in pairs(self.AmmoLink) do
		if IsValid( Crate ) and Crate.Load and not IsInRetDist( self, Crate, AmmoLinkDistBase * self.LinkRangeMul ) then
			BreakGunLink( self, Crate )
		end
	end

end

function ENT:TrimDistantCrewSeats()
	for _, Seat in pairs(self.CrewLink) do
		if IsValid( Seat ) and not IsInRetDist( self, Seat, CrewLinkDistBase * self.LinkRangeMul ) then
			BreakGunLink( self, Seat )
		end
	end
end

--[[
	function ENT:TrimInvalidLoaders()

		local Crewmates = table.Copy(self.CrewLink)

		if self.LoaderCount > 0 and not self.HasGunner then
			for k, Crew in pairs(Crewmates) do

				PrintTable(Crewmates)

				if IsValid(Crew) then
					print("Removing loader...")
					if Crew:GetClass() == "ace_crewseat_loader" then
						self:Unlink( Crew )
					end
				end
			end
		end
	end
]]

function ENT:Think()

	--Legality check part
	if ACE.CurTime > self.NextLegalCheck then

		-- check gun is legal
		self.Legal, self.LegalIssues = ACE_CheckLegal(self, self.Model, math.Round(self.Mass,2), self.ModelInertia, nil, true)
		self.NextLegalCheck = ACE.Legal.NextCheck(self.legal)

		-- check the seat is legal
		local seat = IsValid(self.User) and self.User:GetVehicle() or nil

		if IsValid(seat) then
			local legal, issues = ACE_CheckLegal(seat, nil, nil, nil, nil, false)
			if not legal then
				self.Legal = false
				self.LegalIssues = self.LegalIssues .. "\nSeat not legal: " .. issues
			end
		end

		self:UpdateOverlayText()

		if not self.Legal and self.Firing then self:TriggerInput("Fire", 0) end

	end

	-- IDK how an object can break this bad but it did. Hopefully this fixes the 1 in a million bug
	local PhysObj = self:GetPhysicsObject()
	if not IsValid(PhysObj) then return end

	self.DeltaTime = CurTime() - self.LastThink

	self:Heat_Function()

	local Time = CurTime()
	if self.LastSend + 1 <= Time then

		local Ammo = 0

		--UnlinkDistance
		for _, Crate in pairs(self.AmmoLink) do
			if IsValid( Crate ) and Crate.Load and Crate.Legal then

			if IsInRetDist( self, Crate, AmmoLinkDistBase * self.LinkRangeMul ) then
					Ammo = Ammo + (Crate.Ammo or 0)
				else
					BreakGunLink( self, Crate )
				end
			end
		end

		self:TrimDistantCrewSeats()

		self.Ammo = Ammo
		self:UpdateOverlayText()

		Wire_TriggerOutput(self, "AmmoCount", Ammo)


		local isEmpty = self.BulletData.Type == "Empty"
		if self.MagSize then
			Wire_TriggerOutput(self, "Shots Left", isEmpty and 0 or (self.MagSize - self.CurrentShot))
		else
			Wire_TriggerOutput(self, "Shots Left", isEmpty and 0 or 1)
		end

		self:SetNWString("GunType", self.Id)
		self:SetNWInt("Ammo",Ammo)
		self:SetNWString("Type", self.BulletData.Type)
		self:SetNWFloat("Mass", self.BulletData.ProjMass * 100)
		self:SetNWFloat("Propellant", self.BulletData.PropMass * 1000)
		self:SetNWFloat("FireRate", self.RateOfFire)

		self.LastSend = Time

	end

	if self.NextFire <= Time then
		if self.BulletData.Type and self.BulletData.Type ~= "Empty" then
			self.Ready = true
			Wire_TriggerOutput(self, "Ready", 1)
		else
			self.Ready = false
			Wire_TriggerOutput(self, "Ready", 0)
		end

		if self.MagSize and self.MagSize == 1 then
			self.CurrentShot = 0
		end

		if self.Firing then
			--print("Fire!")
			self:FireShell()
		elseif self.Reloading then
			--print("Reloading!")
			self:ReloadMag()
			self.Reloading = false
		end
	end

	self.LastThink = ACE.CurTime
	self:NextThink(Time)

	if self.CurrentRecoil > 0 then
		local Dir = -self:GetForward()
		--local MuzzlePos		= self:LocalToWorld(self.Muzzle)
		--local MuzzlePos		= self:GetForward() * self.Muzzle.x + self:GetRight()  * self.Muzzle.y + self:GetUp() * self.Muzzle.z
		--local MuzzlePos		= self:GetPos()
		ACE_KEShove(self, self:GetPos() , Dir , self.KERecoil * self.CurrentRecoil )

		self.CurrentRecoil = math.max(self.CurrentRecoil - self.DeltaTime / 0.5,0) --Divided by time to dissipate recoil. Currently 0.5
		--self.CurrentRecoil = 0
	end

	return true

end

function ENT:ReloadMag()
	if self.IsUnderWeight == nil then
		self.IsUnderWeight = true
	end
	if ( (self.CurrentShot > 0) and self.IsUnderWeight and self.Ready and self.Legal ) then
		if ( ACE.RoundTypes[self.BulletData.Type] ) then		--Check if the roundtype loaded actually exists
			self:LoadAmmo(self.MagReload, false)
			self:EmitSound("weapons/357/357_reload4.wav", 68, 100)
			self.CurrentShot = 0
			Wire_TriggerOutput(self, "Ready", 0)
		else
			self.CurrentShot = 0
			self.Ready = false
			Wire_TriggerOutput(self, "Ready", 0)
			self:LoadAmmo(false, true)
		end
	end
end

do

	local FSTable = {
		APFSDS  = true,
		HEATFS  = true,
		HEFS	= true,
		THEATFS = true
	}

	function ENT:GetInaccuracy()

		local SpreadScale = ACE.SpreadScale
		local IaccMult = 1

		if self.ACF.Health and self.ACF.MaxHealth then
			IaccMult = math.Clamp(((1 - SpreadScale) / 0.5) * ((self.ACF.Health / self.ACF.MaxHealth) - 1) + 1, 1, SpreadScale)
		end

		-- Increased FS accuracy. Hardcoded.
		if FSTable[self.BulletData.Type] then
			IaccMult = IaccMult * 0.25
		end

		-- No gunner = more inaccuracy
		if not self.HasGunner then
			IaccMult = IaccMult * 1.5
		end

		local coneAng = self.Inaccuracy * ACE.GunInaccuracyScale * IaccMult

		return coneAng
	end

end

do

	function ENT:ChooseLoader()

		local highestStaminaLoader = nil
		local highestStamina = 0

		for _, crewEnt in ipairs(self.CrewLink) do
			if crewEnt:GetClass() == "ace_crewseat_loader" and crewEnt.Legal then
				local stamina = crewEnt.Stamina
				if stamina >= highestStamina then
					highestStamina = stamina
					highestStaminaLoader = crewEnt
				end
			end
		end

		return highestStaminaLoader
	end


	local FusedRounds = {
		HE	= true,
		HEFS	= true,
		HESH	= true,
		HEAT	= true,
		THEAT	= true,
		SM	= true,
		CHE	= true,
		CHEAT	= true,
		CAP	= true
	}

	function ENT:FireShell()

		local CanDo = hook.Run("ACE_FireShell", self, self.BulletData )
		if CanDo == false then return end

		if self.IsUnderWeight == nil then
			self.IsUnderWeight = true
		end

		if self.RequiresGunner and not self.HasGunner then
			local HasWarned = self.OTWarnings.WarnedGunner or false
			--self.OTWarnings
			if not HasWarned then
				--print("No")
				ACE_ChatMessagePly( self:CPPIGetOwner() , "[ACE] Your gun is above [" .. ACE.LargeGunsThreshold .. " mm] and requires a gunner to operate.", Color( 255, 0, 0 ))
				self.OTWarnings.WarnedGunner = true
			end
			return
		end

		ACE_DoContraptionLegalCheck(self)

		local bool = true

		-- An empty gun reports Ready = 0 (correct for wire), but it must still be
		-- able to attempt a reload when fired, otherwise it stays locked empty once
		-- its crate runs dry. Letting it through here lands in the else branch below,
		-- which calls LoadAmmo to pull a round from any active crate.
		local isEmpty = self.BulletData.Type == "Empty"

		if ( bool and self.IsUnderWeight and (self.Ready or isEmpty) and self.Legal ) then

			local Blacklist = {}
			if not ACE.AmmoBlacklist[self.BulletData.Type] then
				Blacklist = {}
			else
				Blacklist = ACE.AmmoBlacklist[self.BulletData.Type]
			end

			if ( ACE.RoundTypes[self.BulletData.Type] and not table.HasValue( Blacklist, self.Class ) ) then	--Check if the roundtype loaded actually exists

				self.HeatFire = true  --Used by Heat

				local MuzzlePos		= self:LocalToWorld(self.Muzzle)
				local MuzzleVec		= self:GetForward()

				local coneAng		= math.tan(math.rad(self:GetInaccuracy()))
				local randUnitSquare	= (self:GetUp() * (2 * math.random() - 1) + self:GetRight() * (2 * math.random() - 1))
				local spread			= randUnitSquare:GetNormalized() * coneAng * (math.random() ^ (1 / math.Clamp(ACE.GunInaccuracyBias, 0.5, 4)))
				local ShootVec		= (MuzzleVec + spread):GetNormalized()

				self:MuzzleEffect( MuzzlePos, MuzzleVec )

				local GPos = self:GetPos()
				local TestVel = self:WorldToLocal(ACE_GetPhysicalParent(self):GetVelocity() + GPos)

				--Traceback component
				TestVel = self:LocalToWorld(Vector(math.max(TestVel.x,-0.1),TestVel.y,TestVel.z)) - GPos

				self.BulletData.Pos = MuzzlePos + TestVel * self.DeltaTime * 5 --Less clipping on fast vehicles, especially moving perpindicular since traceback doesnt compensate for that. A multiplier of 3 is semi-reliable. A multiplier of 5 guarentees it doesnt happen.
				self.BulletData.Flight = ShootVec * self.BulletData.MuzzleVel * 39.37 + TestVel
				self.BulletData.Owner = self.User
				self.BulletData.Gun = self

				--local Cal = self.Caliber

				--using fusetime via wire will override the ammo fusetime!
				if FusedRounds[self.BulletData.Type] and FusedRounds[self.BulletData.Type] and self.OverrideFuse then
					self.BulletData.FuseLength = self.FuseTime
				end

				self.CreateShell = ACE.RoundTypes[self.BulletData.Type].create
				self:CreateShell( self.BulletData )

				self.CurrentRecoil = 1

				self.Ready = false
				self.CurrentShot = math.min(self.CurrentShot + 1, self.MagSize)

				if (self.CurrentShot >= self.MagSize) and (self.MagSize > 1) then
					self:LoadAmmo(self.MagReload, false)
					self:EmitSound("weapons/357/357_reload4.wav",68,100)
					timer.Simple(self.LastLoadDuration, function() if IsValid(self) then self.CurrentShot = 0 end end)
				else
					self:LoadAmmo(false, false)
				end
				Wire_TriggerOutput(self, "Ready", 0)

			else
				self:EmitSound("weapons/shotgun/shotgun_empty.wav", 68, 100)
				self.CurrentShot = 0
				self.Ready = false
				Wire_TriggerOutput(self, "Ready", 0)
				self:LoadAmmo(false, true)
			end
		end

	end
end

function ENT:FindNextCrate()

	local MaxAmmo = #self.AmmoLink
	local AmmoEnt = nil
	local i = 0

	while i <= MaxAmmo and not (AmmoEnt and AmmoEnt:IsValid() and AmmoEnt.Ammo > 0) do -- need to check ammoent here? returns if found

		self.CurAmmo = self.CurAmmo + 1
		if self.CurAmmo > MaxAmmo then self.CurAmmo = 1 end

		AmmoEnt = self.AmmoLink[self.CurAmmo]
		if AmmoEnt and AmmoEnt:IsValid() and AmmoEnt.Ammo > 0 and AmmoEnt.Load and AmmoEnt.Legal then
			return AmmoEnt
		end
		AmmoEnt = nil

		i = i + 1
	end

	return false
end

function ENT:LoadAmmo( AddTime, Reload )

	self:TrimDistantCrates()

	local AmmoEnt = self:FindNextCrate()
	local curTime = CurTime()

	if AmmoEnt and AmmoEnt.Legal then
		AmmoEnt.Ammo = AmmoEnt.Ammo - 1
		self.BulletData = AmmoEnt.BulletData
		self.BulletData.Crate = AmmoEnt:EntIndex()

		local ReloadTime, Loader = GetGunReloadTime(self, AmmoEnt.BulletData, AmmoEnt.RoFMul)
		self.ReloadTime = ReloadTime
		if IsValid(Loader) then Loader:DecreaseStamina() end

		Wire_TriggerOutput(self, "Loaded", self.BulletData.Type)

		self.RateOfFire = (60 / self.ReloadTime)
		Wire_TriggerOutput(self, "Fire Rate", self.RateOfFire)
		Wire_TriggerOutput(self, "Muzzle Weight", math.floor(self.BulletData.ProjMass * 1000) )
		Wire_TriggerOutput(self, "Muzzle Velocity", math.floor(self.BulletData.MuzzleVel * ACE.VelScale) )

		self.KERecoil = (self.BulletData.PropMass * 39.37) * (GetConVar("ace_recoilpush"):GetFloat() or 1) * 375

		self.NextFire = curTime + self.ReloadTime
		local reloadTime = self.ReloadTime

		if AddTime then
			reloadTime = reloadTime + AddTime
		end
		if self.FirstLoad then
			self.FirstLoad = false
			reloadTime = 0.1
		end

		if Reload then
			-- Send the effective ready time: a FirstLoad gun is ready in 0.1s, and the client's
			-- Animate(LoadOnly) holds the reload pose for ~75% of the received magnitude.
			self:ReloadEffect(reloadTime)
		end

		self.NextFire = curTime + reloadTime
		self.LastLoadDuration = reloadTime

		self:Think()
		return true
	else
		self.BulletData = {}
			self.BulletData.Type = "Empty"
			self.BulletData.PropMass = 0
			self.BulletData.ProjMass = 0

		Wire_TriggerOutput(self, "Loaded", "Empty")

		self.NextFire = curTime + 0.5
		self:Think()
	end
	return false

end

function ENT:UnloadAmmo()

	if not self.BulletData or not self.BulletData.Crate then return end
	if not self.Ready then
		if (self.NextFire-CurTime()) < 0 then return end -- see above; preventing spam
		if self.MagSize > 1 and self.CurrentShot >= self.MagSize then return end -- prevent unload in middle of mag reload
	end

	local Crate = Entity( self.BulletData.Crate )
	if Crate and Crate:IsValid() and self.BulletData.Type == Crate.BulletData.Type then
		Crate.Ammo = math.min(Crate.Ammo + 1, Crate.Capacity)
	end

	self.Ready = false
	Wire_TriggerOutput(self, "Ready", 0)
	self:EmitSound("weapons/shotgun/shotgun_empty.wav", 68, 100)

	local unloadtime = self.ReloadTime / 2 -- base time to swap a fully loaded shell out
	if self.NextFire < CurTime() then -- unloading in middle of reload
		unloadtime = math.min(unloadtime, math.max(self.ReloadTime - (self.NextFire - CurTime()), 0) )
	end
	self:LoadAmmo( unloadtime, true )

end

function ENT:MuzzleEffect()

	local Effect = EffectData()
		Effect:SetEntity( self )
		Effect:SetScale( self.BulletData.PropMass )
		Effect:SetMagnitude( self.ReloadTime )
		Effect:SetSurfaceProp( ACE.RoundTypes[self.BulletData.Type].netid  )	--Encoding the ammo type into a table index
	util.Effect( "ACE_MuzzleFlash", Effect, true, true )

	if self.AutoSound and self.Sound ~= "" then
		timer.Simple(0.6, function()
			self:EmitSound(self.AutoSound, 73, math.random(84, 86))
		end )
	end
end

function ENT:ReloadEffect( EffectTime )

	local Effect = EffectData()
		Effect:SetEntity( self )
		Effect:SetScale( 0 )
		Effect:SetMagnitude( EffectTime or self.ReloadTime )
		Effect:SetSurfaceProp( ACE.RoundTypes[self.BulletData.Type].netid  )	--Encoding the ammo type into a table index
	util.Effect( "ACE_MuzzleFlash", Effect, true, true )

end

function ENT:PreEntityCopy()

	local info = {}
	local entids = {}
	for _, Value in pairs(self.AmmoLink) do				--First clean the table of any invalid entities
		if not Value:IsValid() then
			table.remove(self.AmmoLink, Value)
		end
	end
	for _, Value in pairs(self.AmmoLink) do				--Then save it
		table.insert(entids, Value:EntIndex())
	end
	for _, Value in pairs(self.CrewLink) do				--First clean the table of any invalid entities
		if not Value:IsValid() then
			table.remove(self.CrewLink, Value)
		end
	end
	for _, Value in pairs(self.CrewLink) do				--Then save it
		table.insert(entids, Value:EntIndex())
	end
	info.entities = entids
	if info.entities then
		duplicator.StoreEntityModifier( self, "ACFAmmoLink", info )
	end

	--Wire dupe info
	self.BaseClass.PreEntityCopy( self )

end

function ENT:PostEntityPaste( Player, Ent, CreatedEntities )
	local pointSources = { self }
	self._ACEPointsSuppress = true

	if Ent.EntityMods and Ent.EntityMods.ACFAmmoLink and Ent.EntityMods.ACFAmmoLink.entities then

		local AmmoLink = Ent.EntityMods.ACFAmmoLink

		if AmmoLink.entities and table.Count(AmmoLink.entities) > 0 then

			for _, AmmoID in pairs(AmmoLink.entities) do

				local Ammo = CreatedEntities[ AmmoID ]

				if IsValid(Ammo) then
					pointSources[#pointSources + 1] = Ammo

					if Ammo:GetClass() == "acf_ammo" then
						self:Link( Ammo )
					elseif Ammo:GetClass() == "ace_crewseat_gunner" then
						self:Link( Ammo )
					elseif Ammo:GetClass() == "ace_crewseat_loader" then
						if not self.noloaders then
							self:Link( Ammo )
						end
					end
				end
			end
		end

		Ent.EntityMods.ACFAmmoLink = nil
	end

	self._ACEPointsSuppress = nil

	--Wire dupe info
	self.BaseClass.PostEntityPaste( self, Player, Ent, CreatedEntities )
	if ACE_PointsInputChanged then
		ACE_PointsInputChanged(pointSources, "gun-links-pasted")
	end
end
