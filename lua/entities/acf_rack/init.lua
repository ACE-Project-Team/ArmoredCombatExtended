-- init.lua

AddCSLuaFile( "shared.lua" )
AddCSLuaFile( "cl_init.lua" )

include("shared.lua")

DEFINE_BASECLASS( "base_wire_entity" )

--local GunClasses	= ACF.Classes.GunClass
local RackClasses	= ACF.Classes.Rack

--local GunTable	= ACF.Weapons.Guns
local RackTable	= ACF.Weapons.Racks

local GuidanceTable = ACF.Guidance
local FuseTable	= ACF.Fuse

local AmmoLinkDistBase = 512

local RackWireDescs = {
	--Inputs
	["Reload"]       = "Arms this rack. Its mandatory to set this since racks don't reload automatically.",
	["TargetPos"]    = "Defines the Target position for the ordnance in this rack. This only works for Wire and laser guidances.",
	["Delay"]        = "Sets a specific delay to guidance control over the default one in seconds.",
	["Detonate"]        = "Remotely detonate any currently outbound missiles.",

	--Outputs
	["Ready"]        = "Returns if the rack is ready to fire.",
	["CurMissile"]        = "Outputs the next position of the missile in the rack getting fired.",
	["PositionFiredMissile"] = "Outputs the position of the missile last fired by this launcher"

}

function ENT:Initialize()

	self.PhysObj = self:GetPhysicsObject()

	self.BaseClass.Initialize(self)
	self:CPPISetOwner(self)

	--self.NextLegalCheck  = ACF.CurTime + math.random(ACF.Legal.Min, ACF.Legal.Max) -- give any spawning issues time to iron themselves out
	self.NextLegalCheck  = ACF.CurTime + 3 -- give any spawning issues time to iron themselves out
	self.Legal			= true
	self.LegalIssues	= ""
	self.SpecialHealth	= false	--If true needs a special ACF_Activate function
	self.SpecialDamage	= true	--If true needs a special ACF_OnDamage function --NOTE: you can't "fix" missiles with setting this to false, it acts like a prop!!!!

	self.ReloadTime		= 1
	self.ReloadDelay	= 1 --Delay before can fire again. Decreased by refills. Set to 30 for now.
	self.NextFire		= 1
	self.FireDelay		= 0.5
	self.NextReload		= 0
	self.ReloadMultiplierBonus = 1

	self.Firing			= false
	self.Reloading		= false
	self.GuidanceActive = false


	self.RackStatus      = "Empty"
	self.Ready           = false

	self.LastSend        = 0
	self.LastThink             = CurTime()


	self.BulletData            = {}
	self.BulletData.Type       = "Empty"
	self.BulletData.PropMass   = 0
	self.BulletData.ProjMass   = 0

	self.IsMaster = 1

	self.MaxMissile				= 1 or self.MaxMissile
	self.CurMissile				= 0

	self.TrackDelay				= 0

	self.SelfContraption = nil

	self.Inputs = WireLib.CreateSpecialInputs( self, { "Fire",	"Reload (" .. RackWireDescs["Reload"] .. ")",	"Target Pos (" .. RackWireDescs["TargetPos"] .. ")", "Activate Guidance", "Track Delay (" .. RackWireDescs["Delay"] .. ")", "Detonate Missile (" .. RackWireDescs["Detonate"] .. ")" },
													{ "NORMAL", "NORMAL", "VECTOR", "NORMAL", "NORMAL", "NORMAL" } )

	self.Outputs = WireLib.CreateSpecialOutputs( self,  { "Ready (" .. RackWireDescs["Ready"] .. ")",	"Shots Left", "AcquiredTarget", "TargetDirection", "Current Missile", "Missile Info", "CurMissile", "PositionFiredMissile" },
														{ "NORMAL", "NORMAL", "NORMAL", "VECTOR", "ENTITY", "STRING", "NORMAL", "VECTOR" } )

	Wire_TriggerOutput(self, "Ready", 1)
	Wire_TriggerOutput(self, "Current Missile", nil)
	Wire_TriggerOutput(self, "Missile Info", "")
	Wire_TriggerOutput(self, "PositionFiredMissile", vector_origin)
	self.WireDebugName = "ACF Rack"

	self.lastCol = self:GetColor() or Color(255, 255, 255)

	self.Missiles = {}
	--Self.Missiles[ID] Stores entity in 1 and whether missile exists and is valid in 2

	self.AmmoLink = {}

	self:GetOverlayText()


	self.NextHudUpdate			= 0
	self.UpdateNextMissile		= 0
	self.NextAuxilaryFunctions	= 0
	self.Inaccuracy				= 0

	self.LastFiredMissile = nil

	self.ScuttleMissiles = false


	self.MissileEntity = NULL
	self.MissileText = ""

	self.CanLegalCheck = true

end


function MakeACF_Rack(Owner, Pos, Angle, Id)


	if not Owner:CheckLimit("_acf_rack") then return false end

	local Rack = ents.Create("acf_rack")

	if not IsValid(Rack) then return false end

	Rack:SetAngles(Angle)
	Rack:SetPos(Pos)
	Rack:Spawn()

	Owner:AddCount("_acf_rack", Rack)
	Owner:AddCleanup( "acfmenu", Rack )

	if not ACE_CheckRack( Id ) then
		Id = "1xRK"
	end

	local gundef = RackTable[Id]

	Rack:CPPISetOwner(Owner)
	Rack.Id	= Id

	Rack.MinCaliber	= gundef.mincaliber
	Rack.MaxCaliber	= gundef.maxcaliber
	Rack.Caliber		= gundef.caliber
	Rack.Model		= gundef.model
	Rack.Mass		= gundef.weight
	Rack.name		= gundef.name
	Rack.Class		= gundef.gunclass

	Rack:SetModel( Rack.Model )
	Rack:PhysicsInit( SOLID_VPHYSICS )
	Rack:SetMoveType( MOVETYPE_VPHYSICS )
	Rack:SetSolid( SOLID_VPHYSICS )

	-- Custom BS for karbine. Per Rack ROF.
--	Rack.PGRoFmod = 1
--	if gundef["rofmod"] then
--		Rack.PGRoFmod = math.max(0, gundef["rofmod"])
--	end

	Rack.MaxMissile = table.Count(gundef.mountpoints) or 1
	Rack.ReloadTime = gundef.magreload or 1 --Replace with fixed time delay rather than multiplier
	Rack.ACEPoints	= (100 + (Rack.MaxMissile-1) * 50)
	--Rack.ACEPoints	= 200

	local gunclass = RackClasses[Rack.Class] or ErrorNoHalt("Couldn't find the " .. tostring(Rack.Class) .. " gun-class!")

	Rack.Muzzleflash       = gundef.muzzleflash	or gunclass.muzzleflash	or ""
	Rack.RoFmod            = gunclass["rofmod"]								or 1
	Rack.Sound             = gundef.sound		or gunclass.sound		or "acf_extra/airfx/rocket_fire2.wav"
	Rack.DefaultSound      = Rack.Sound
	Rack.SoundPitch        = 100
	Rack.Inaccuracy        = gundef["spread"]	or gunclass["spread"]	or 0


	Rack.HideMissile       = ACF_GetRackValue(Id, "hidemissile")			or false
	Rack.ProtectMissile    = gundef.protectmissile or gunclass.protectmissile  or false
	Rack.CustomArmour      = gundef.armour		or gunclass.armour		or 1

	Rack.ReloadMultiplier  = ACF_GetRackValue(Id, "reloadmul")
	Rack.WhitelistOnly     = ACF_GetRackValue(Id, "whitelistonly")

	Rack:SetNWString("WireName",Rack.name)
	Rack:SetNWString( "Class",  Rack.Class )
	Rack:SetNWString( "ID",	Rack.Id )
	Rack:SetNWString( "Sound",  Rack.Sound )
	Rack:SetNWInt( "SoundPitch",  Rack.SoundPitch )


	Rack.PhysObj = Rack:GetPhysicsObject()
	if (Rack.PhysObj:IsValid()) then
		Rack.PhysObj:SetMass(Rack.Mass or 1)
	end

	hook.Call("ACF_RackCreate", nil, Rack)

	undo.Create( "acf_rack" )
		undo.AddEntity( Rack )
		undo.SetPlayer( Owner )
	undo.Finish()

	return Rack

end

list.Set( "ACFCvars", "acf_rack" , {"id"} )
duplicator.RegisterEntityClass("acf_rack", MakeACF_Rack, "Pos", "Angle", "Id")


function ENT:TriggerInput( iname , value )

	if ( iname == "Fire" ) then
		if value > 0 then
			self.Firing = true
		else
			self.Firing = false
		end
	elseif iname == "Reload"then
		if value > 0 then
			self.Reloading = true
		else
			self.Reloading = false
		end
	elseif iname == "Target Pos" then
		if value:LengthSqr() > 1 then
			self.TargPos = value --I didn't like using wire outputs to pass target positions to missiles. The value also didn't make sense to the user.
		else
			self.TargPos = nil
		end
	elseif iname == "Track Delay" then
		if value > 0 then
			self.TrackDelay = value
		else
			self.TrackDelay = 0
		end
	elseif iname == "Detonate Missile" then
		if value > 0 then
			self.ScuttleMissiles = true
		else
			self.ScuttleMissiles = false
		end
	elseif iname == "Activate Guidance" then
		if value > 0 then
			self.GuidanceActive = true

			if self.MissileEntity then
				self.MissileEntity.GuidanceActive = true
			end
		else
			self.GuidanceActive = false

			if self.MissileEntity:IsValid() then

				self.MissileEntity.GuidanceActive = false

				if self.MissileEntity.Guidance.Target  then
				self.MissileEntity.Guidance.Target = nil
				end
				self.MissileEntity.TargetPos = Vector()
				self.MissileEntity.TargetAcquired = false
			end
		end
	end
end

function ENT:UpdateValidMissiles()
	local ValidCount = 0

	--	self.EmptyWeight
	--	missile.RoundWeight
	local Tmass = self.Mass
	for i = 1, self.MaxMissile do

		local MissileArray = self.Missiles[i] or {}
		local MissileTest = MissileArray[1] or NULL

		if not MissileTest:IsValid() then
			self.Missiles[i] = {}
			self.Missiles[i][1] = NULL
			self.Missiles[i][2] = false
		else
			ValidCount = ValidCount + 1
			Tmass = Tmass + (MissileTest.RoundWeight or 10)
		end
	end

	self:GetPhysicsObject():SetMass( Tmass )

	--Find the next available missile in the stack.
	--Used to pass guidance info to and from the missile to the launcher and back.
	--local MissileToShoot = nil
	for i = 1, self.MaxMissile do
		local MissileTest = self.Missiles[i][2] or false
		if MissileTest then
			MissileToShoot = i
			self.MissileEntity = self.Missiles[i][1]
			self.MissileText = self.MissileEntity.StringName
			Wire_TriggerOutput(self, "Missile Info", self.MissileText)
			Wire_TriggerOutput(self, "Current Missile", self.MissileEntity)
			Wire_TriggerOutput(self, "CurMissile", MissileToShoot)
			break
		end
	end

	if self.MissileEntity then
		if self.GuidanceActive then
			self.MissileEntity.GuidanceActive = true
		else
			self.MissileEntity.GuidanceActive = false
		end
	end

	return ValidCount
end

	--ACF.GunfireEnabled and self.Legal. Add to later think function.

function ENT:Think()

	local CT = ACF.CurTime
	self:NextThink( CT )

	if self.CurMissile == 0 then
		self.RackStatus = "Empty"
	elseif not self.Ready then
		self.RackStatus = "Loading"
		if CT > self.NextFire and self.MissileEntity:IsValid() then
			self.Ready = true
			self.RackStatus = "Ready"
			Wire_TriggerOutput(self, "Ready", 1)
			self:EmitSound("acf_extra/airfx/satellite_target.wav", 500, 60)
		end
	end

	if IsValid(self.LastFiredMissile) then
		Wire_TriggerOutput(self, "PositionFiredMissile", self.LastFiredMissile.MissilePosition or vector_origin)
	else
		Wire_TriggerOutput(self, "PositionFiredMissile", vector_origin)
	end

	if CT > self.NextHudUpdate then
		self.NextHudUpdate = CT + 0.5
		self:UpdateRefillBonus()
		self:GetOverlayText()
	end

	if CT > self.UpdateNextMissile then
		self.UpdateNextMissile = CT + 0.75

		self.CurMissile = self:UpdateValidMissiles()
		Wire_TriggerOutput(self, "Shots Left", self.CurMissile)
		self:TrimDistantCrates()

		self.SelfContraption = self:GetContraption() or {}
	end

	if self.GuidanceActive then

		if self.MissileEntity:IsValid() then
			if self.TargPos and not self.MissileEntity.TargetAcquired then --and not self.MissileEntity.TargetAcquired
				self.MissileEntity.TargetPos = self.TargPos
				--self.MissileEntity.TargetAcquired = false
			else
				self.MissileEntity.TargetPos = nil
			end

			if self.MissileEntity.TargetAcquired then
				Wire_TriggerOutput(self, "AcquiredTarget", 1)
				Wire_TriggerOutput(self, "TargetDirection", self.MissileEntity.TargetDir)
			else
				Wire_TriggerOutput(self, "AcquiredTarget", 0)
				Wire_TriggerOutput(self, "TargetDirection", Vector())
			end
		end
	else
		Wire_TriggerOutput(self, "AcquiredTarget", 0)
		Wire_TriggerOutput(self, "TargetDirection", Vector())
	end

	if self.Firing and self.Ready and self.Legal then
		self:ShootMissile()
	elseif self.Reloading and CT > self.NextReload then
		self:Reload()
	end

	if CT > self.NextAuxilaryFunctions then
		self.NextAuxilaryFunctions = CT + 3
		self.Parent = ACF_GetPhysicalParent(self)
	end

	if CT > self.NextLegalCheck then
		self.Legal, self.LegalIssues = ACF_CheckLegal(self, nil, math.Round(self.Mass,2), self.ModelInertia, nil, true) -- requiresweld overrides parentable, need to set it false for parent-only gearboxes
		self.NextLegalCheck = ACF.Legal.NextCheck(self.legal)

		if not self.Legal and self.Firing then
			self.Firing = false
		end
	end

	return true

end

function ENT:ShootMissile()

	local CT = CurTime()

	--Find the next available missile in the stack.
	local MissileToShoot = 1
	for i = 1, self.MaxMissile do
		local MissileTest = self.Missiles[i][2] or false
		if MissileTest then
			MissileToShoot = i
			break
		end
	end

	--print("Shoot Tube: "..MissileToReload)

	local ShotMissile = self.Missiles[MissileToShoot][1] or nil

	if not ShotMissile:IsValid() then self.CurMissile = self:UpdateValidMissiles() return end

	ACE_DoContraptionLegalCheck(self)

	self.NextReload = CT + self.ReloadTime

	self.MissileEntity = NULL
	Wire_TriggerOutput(self, "Missile Info", "")

	--Activate the missile
	self.LastFiredMissile = self.Missiles[MissileToShoot][1]

	self.Missiles[MissileToShoot][1].MissileActive = true
	self.Missiles[MissileToShoot][1].GuidanceActive = true
	if self.TargPos then
		self.Missiles[MissileToShoot][1].TargetPos = self.TargPos --Sets target position of missile. Used for inertial navigation.
	end
	self.Missiles[MissileToShoot][1].GuidanceActivationDelay = self.TrackDelay
	self.Missiles[MissileToShoot][1].LastThink = CurTime()
	self.Missiles[MissileToShoot][1].ActivationTime = CurTime()
	self.Missiles[MissileToShoot][1].Flight = self.Parent:GetVelocity() / 39.37

	self.Missiles[MissileToShoot][1]:SetNoDraw(false)
	self.Missiles[MissileToShoot][1]:SetNotSolid(false)
	self.Missiles[MissileToShoot][1]:SetModelEasy( self.Missiles[MissileToShoot][1].OutSideRackModel )

	self.Missiles[MissileToShoot][1]:EmitSound(self.Sound, 500, self.SoundPitch, 1, CHAN_WEAPON ) --Formerly 107
	self.Missiles[MissileToShoot][1].MotorSound = self.Sound

	self.Missiles[MissileToShoot][1].Contraption = self.SelfContraption

	--Shamelessly stolen from the gun code
	local coneAng		= math.tan(math.rad(self.Inaccuracy))
	local randUnitSquare	= (self.Missiles[MissileToShoot][1]:GetUp() * (2 * math.random() - 1) + self.Missiles[MissileToShoot][1]:GetRight() * (2 * math.random() - 1))
	local spread		= randUnitSquare:GetNormalized() * coneAng * (math.random() ^ (1 / math.Clamp(ACF.GunInaccuracyBias, 0.5, 4)))
	local ShootVec		= (ShotMissile:GetForward() + spread):GetNormalized()

	self.Missiles[MissileToShoot][1]:SetAngles(ShootVec:Angle())

	--Detach it from the rack
	self.Missiles[MissileToShoot][1]:SetParent(NULL)
	--Then clear the stored missile array.
	self.Missiles[MissileToShoot][1] = NULL
	self.Missiles[MissileToShoot][2] = false

	local ValidCount = self:UpdateValidMissiles()
	self.CurMissile = ValidCount


	Wire_TriggerOutput(self, "Shots Left", self.CurMissile)

	self.Ready = false
	self.NextFire = CT + self.FireDelay
end

function ENT:Reload() --
	local CT = CurTime()

--	if self.CurMissile >= self.MaxMissile then return end--a

	local ValidCount = self:UpdateValidMissiles()

	local ReloadTest = ACF.CurTime + self.ReloadDelay * self.ReloadMultiplierBonus
	if self.NextFire > ReloadTest then
	   self.NextFire = ReloadTest
	end

	--print(self.ReloadDelay * self.ReloadMultiplierBonus)

	if ValidCount >= self.MaxMissile then return end--a

	local MissileToReload = -1

	--Find next missile slot to reload
	for i = 1, self.MaxMissile do
		local MissileTest = self.Missiles[i][2] or false
		if not MissileTest then
			MissileToReload = i
			break
		end
	end

	local Reloaded = false

	if MissileToReload ~= -1 then
		Reloaded = self:AddMissile(MissileToReload)
	end

	--self.Missiles = {}
	--Self.Missiles[ID] Stores entity in 1 and whether missile exists and is valid in 2

	if Reloaded then
		self:EmitSound("acf_extra/tankfx/gnomefather/reload12.wav", 500, 110)
		self.NextReload = CT + self.ReloadTime * self.ReloadMultiplierBonus or 1
		self.NextFire = CT + math.Max(self.ReloadDelay * self.ReloadMultiplierBonus or 1,0.2)
		self.Ready = false
		Wire_TriggerOutput(self, "Ready", 0)
		self.CurMissile = ValidCount + 1

		Wire_TriggerOutput(self, "Shots Left", self.CurMissile)
	else
		self.NextReload = CT + 5

		local ValidCount = self:UpdateValidMissiles()
		self.CurMissile = ValidCount
	end

end


--Technically a MUCH more efficient way to do this would be to cache the data every time the ammocrate gets swapped instead of redoing it every reload.
function ENT:AddMissile(MissileSlot) --Where the majority of the missile paramaters are initialized. Also sets launcher properties by the most recent missile.

	local Crate = self:FindNextCrate(true)
	if not IsValid(Crate) then return false end

	local ply = self:CPPIGetOwner()

	local missile = ents.Create("ace_missile")
	missile:CPPISetOwner(ply)
	missile.DoNotDuplicate  = true
	missile.Launcher		= self

	missile.ContrapId = ACF_Check( self ) and self.ACF.ContraptionId or 1

	local BulletData = ACFM_CompactBulletData(Crate)
	BulletData.IsShortForm  = true
	BulletData.Owner		= ply
	missile:SetBulletData(BulletData)
	missile.Bulletdata2 = Crate.BulletData --Sets non compacted bulletdata for spawning a shell. I guarantee there's a better way to do this.

	BulletDataMath(missile)

	missile.OutSideRackModel = ACF_GetRackValue(self.Id, "rocketmdl") or ACF_GetGunValue(BulletData.Id, "rocketmdl")

	local rackmodel = ACF_GetRackValue(self.Id, "rackmdl") or ACF_GetGunValue(BulletData.Id, "rackmdl") or missile.OutSideRackModel
	if rackmodel then
		missile:SetModelEasy( rackmodel )
		--missile.RackModelApplied = true
	end

	local _, _, pos = self:GetMuzzle( MissileSlot-1 , missile )

	missile:SetPos(pos)
	missile:SetAngles(self:GetAngles())

	missile:SetParent(self)
	missile:SetParentPhysNum(0)

	local prop = missile.BulletData.FrArea * (missile.BulletData.PropLength * ACF.PDensity / 1000) --Volume of the case as a cylinder * Powder density converted from g to kg
	local ThrustRatio = 1 + (prop-( ACF_GetRackValue(BulletData, "propweight") or ACF_GetGunValue(BulletData.Id, "propweight") or 1 ))	--Multiplies burntime by the amount of proppelant compared to max.

	missile.ACF = missile.ACF or {}
	missile.ACF.Ductility = -0.8
	missile.ACF.Material = "RHA" --Add material customization option to missiles?
	self.RoundWeight = ACF_GetGunValue(BulletData, "weight") or 10
	missile.RoundWeight = self.RoundWeight --Used to scale thrust acceleration.

	missile.Drag = ACF_GetRackValue(BulletData, "dragcoef") or ACF_GetGunValue(BulletData.Id, "dragcoef") or 0

	local TVal = (ACF_GetRackValue(BulletData, "thrust") or ACF_GetGunValue(BulletData.Id, "thrust") or 0)
	missile.Thrust = TVal


	missile.BurnTime = (ACF_GetRackValue(BulletData, "burntime") or ACF_GetGunValue(BulletData.Id, "burntime") or 0) * ThrustRatio
	missile.Burndelay = ACF_GetRackValue(BulletData, "startdelay") or ACF_GetGunValue(BulletData.Id, "startdelay") or 0

	missile.BoostAccel = (ACF_GetRackValue(BulletData, "boostacceleration") or ACF_GetGunValue(BulletData.Id, "boostacceleration") or 0)
	missile.BoostTime = (ACF_GetRackValue(BulletData, "boostertime") or ACF_GetGunValue(BulletData.Id, "boostertime") or 0) * ThrustRatio
	missile.BoostIgnitionDelay = ACF_GetRackValue(BulletData, "boostdelay") or ACF_GetGunValue(BulletData.Id, "boostdelay") or 0

	missile.BoostKick = ACF_GetRackValue(BulletData, "launchkick") or ACF_GetGunValue(BulletData.Id, "launchkick") or 0

	missile.Lifetime = ACF_GetRackValue(BulletData, "fusetime") or ACF_GetGunValue(BulletData.Id, "fusetime") or 20

	missile.TurnRate = ACF_GetRackValue(BulletData, "turnrate") or ACF_GetGunValue(BulletData.Id, "turnrate") or 50
	missile.FinMul = ACF_GetRackValue(BulletData, "finefficiency") or ACF_GetGunValue(BulletData.Id, "finefficiency") or 0.2
	missile.ThrustTurnRate = ACF_GetRackValue(BulletData, "thrusterturnrate") or ACF_GetGunValue(BulletData.Id, "thrusterturnrate") or 0
	missile.HasInertial = ACF_GetRackValue(BulletData, "inertialcapable") or ACF_GetGunValue(BulletData.Id, "inertialcapable") or false
	missile.HasDatalink = ACF_GetRackValue(BulletData, "datalink") or ACF_GetGunValue(BulletData.Id, "datalink") or false

	missile.StraightRunning = ACF_GetRackValue(BulletData, "predictiondelay") or ACF_GetGunValue(BulletData.Id, "predictiondelay") or 1.25
	missile.StringName = (ACF_GetRackValue(BulletData, "name") or ACF_GetGunValue(BulletData.Id, "name") or "") .. " - " .. BulletData.Type
	missile.MinStartDelay = ACF_GetRackValue(BulletData, "armdelay") or ACF_GetGunValue(BulletData.Id, "armdelay") or 0.3

	missile.MissileVelocityMul = ACF_GetRackValue(BulletData, "velmul") or ACF_GetGunValue(BulletData.Id, "velmul") or 3
	missile.MissileCalMul = ACF_GetRackValue(BulletData, "calmul") or ACF_GetGunValue(BulletData.Id, "calmul") or 1

	--0-stops underwater
	--1-booster only underwater - DEFAULT
	--2-works above and below 
	--3-underwater only
	--4-booster all and under thrust only

	missile.UnderwaterThrust = ACF_GetRackValue(BulletData, "waterthrusttype") or ACF_GetGunValue(BulletData.Id, "waterthrusttype") or 1
	missile.Buoyancy = ACF_GetRackValue(BulletData, "buoyancy") or ACF_GetGunValue(BulletData.Id, "buoyancy") or 0.5

	local guidance  = BulletData.Data7
	local fuse	= BulletData.Data8

	if guidance then
		guidance = ACFM_CreateConfigurable(guidance, GuidanceTable, bdata, "guidance")
		--if guidance then missile:SetGuidance(guidance) end
		if guidance then
			missile.Guidance = guidance
			guidance:Configure(missile)
		end
	end

	--print(GuidanceTable.guidance)

	if fuse then
		fuse = ACFM_CreateConfigurable(fuse, FuseTable, bdata, "fuses")
		if fuse then
			missile.Fuse = fuse
			fuse:Configure(missile, missile.Guidance or missile:SetGuidance(GuidanceTable.Dumb()))
		end
	end


	UpdateMissileBodygroups(missile)
	UpdateMissileSkin(missile)



	local phys = missile:GetPhysicsObject()
	if (IsValid(phys)) then

				--1.8 is 80 ductility
		missile.ACF.Area = (phys:GetSurfaceArea() * 6.45) * 0.52505066107
		phys:SetMass( missile.ACF.Area * 0.2 ^ 0.5 * (ACF_GetRackValue(self.Id, "armour") or ACF_GetGunValue(BulletData.Id, "armour") or 10) * 0.00078 ) --Sets missile armor thickness.
	end

	if self.HideMissile then missile:SetNoDraw(true) end
	if self.ProtectMissile then missile:SetNotSolid(true) end

	missile:Spawn()

	Crate.Ammo = Crate.Ammo - 1
	missile:SetColor(Crate:GetColor())
	self.Missiles[MissileSlot][1] = missile
	self.Missiles[MissileSlot][2] = true

	self.FireDelay = ACF_GetRackValue(BulletData, "firedelay") or ACF_GetGunValue(BulletData.Id, "firedelay") or 1
	self.ReloadTime = ACF_GetRackValue(BulletData, "reloadspeed") or ACF_GetGunValue(BulletData.Id, "reloadspeed") or 1
	self.ReloadDelay = ACF_GetRackValue(BulletData, "reloaddelay") or ACF_GetGunValue(BulletData.Id, "reloaddelay") or 1
	self.Inaccuracy = ACF_GetRackValue(BulletData, "inaccuracy") or ACF_GetGunValue(BulletData.Id, "inaccuracy") or 0

	missile.ACEPoints = CalculateMissileCost(BulletData)

	if missile:IsValid() then
		self:EmitSound("acf_extra/tankfx/gnomefather/reload12.wav", 500, 110)
		return true
	else
		return false
	end

end

function ENT:FindNextCrate( doSideEffect )

	local MaxAmmo = #self.AmmoLink
	local AmmoEnt = nil
	local i = 0

	local curAmmo = self.CurMissile

	while i <= MaxAmmo and not (AmmoEnt and AmmoEnt:IsValid() and AmmoEnt.Ammo > 0) do

		curAmmo = curAmmo + 1
		if curAmmo > MaxAmmo then curAmmo = 1 end

		AmmoEnt = self.AmmoLink[curAmmo]
		if AmmoEnt and AmmoEnt:IsValid() and AmmoEnt.Ammo > 0 and AmmoEnt.Load then
			return AmmoEnt
		end
		AmmoEnt = nil

		i = i + 1
	end

	if doSideEffect then
		self.CurMissile = curAmmo
	end

	return false
end




function ENT:CanReload()

	local Ammo = table.Count(self.Missiles)
	if Ammo >= self.MagSize then return false end

	local Crate = self:FindNextCrate()
	if not IsValid(Crate) then return false end

	if self.NextFire < 1 then return false end

	return true

end




function ENT:SetLoadedWeight()

	self:TrimNullMissiles()

	for _, missile in pairs(self.Missiles) do

		local phys = missile:GetPhysicsObject()
		if (IsValid(phys)) then
			phys:SetMass( missile.RoundWeight ) --phys:SetMass( 5 )  -- Will result in slightly heavier rack but is probably a good idea to have some mass for any damage calcs.
		end
	end

end


function ENT:LoadAmmo()

	self:TrimDistantCrates()

	if not self:CanReload() then return false end

	local missile = self:AddMissile()

	self:TrimNullMissiles()
	Ammo = table.Count(self.Missiles)
	self:SetNWInt("Ammo",	Ammo)

	local ReloadTime = 1

	if IsValid(missile) then
		ReloadTime = self:GetReloadTime(missile)
	end

	self.NextFire = 0
	self.PostReloadWait = CurTime() -- + 5 --CurTime() + 4.5
	self.WaitFunction = self.GetReloadTime

	self.Ready = false
	self.ReloadTime = ReloadTime

	Wire_TriggerOutput(self, "Ready", 0)

	self:GetOverlayText()

	self:Think()
	return true

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
	info.entities = entids
	if info.entities then
		duplicator.StoreEntityModifier( self, "ACFAmmoLink", info )
	end

	--Wire dupe info
	self.BaseClass.PreEntityCopy( self )

end

function ENT:PostEntityPaste( Player, Ent, CreatedEntities )

	if Ent.EntityMods and Ent.EntityMods.ACFAmmoLink and Ent.EntityMods.ACFAmmoLink.entities then
		local AmmoLink = Ent.EntityMods.ACFAmmoLink
		if AmmoLink.entities and next(AmmoLink.entities) then
			for _,AmmoID in pairs(AmmoLink.entities) do
				local Ammo = CreatedEntities[ AmmoID ]
				if Ammo and Ammo:IsValid() and Ammo:GetClass() == "acf_ammo" then
					self:Link( Ammo )
				end
			end
		end
		Ent.EntityMods.ACFAmmoLink = nil
	end

	--Wire dupe info
	self.BaseClass.PostEntityPaste( self, Player, Ent, CreatedEntities )

end

function ENT:OnRemove()
	Wire_Remove(self)
end

function ENT:OnRestore()
	Wire_Restored(self)
end

--New Overlay text that is shown when you are looking at the rack.
function ENT:GetOverlayText()

	local Ammo		= self.CurMissile	-- Ammo count
	local FireRate	= self.FireDelay or 1	-- How many time take one lauch from another. in secs
	local Reload		= self.ReloadTime		-- reload time. in secs
	local ReloadDelay   = self.ReloadDelay
	local ReloadBonus	= 1-self.ReloadMultiplierBonus  -- the word explains by itself
	local Status		= self.RackStatus				-- this was used to show ilegality issues before. Now this shows about rack state (reloading?, ready?, empty and so on...)
	local txt = ""

	txt = "-  " .. Status
	if self.RackStatus == "Loading" then
		local reloadtime = math.max(math.Round(self.NextFire - ACF.CurTime),0)
		txt = txt .. " (Seconds left: " .. reloadtime .. ")"
	end

	txt = txt .. "  -"

	if Ammo > 0 then
		if Ammo == 1 then
			txt = txt .. "\n" .. Ammo .. " Launch left"
		else
			txt = txt .. "\n" .. Ammo .. " Launches left"
		end

		if self.MissileEntity then

		txt = txt .. "\n" .. "Current Missile: " .. self.MissileText

		end

		txt = txt .. "\n\nFire Rate: " .. math.Round(FireRate, 2) .. " secs"
		txt = txt .. "\nReload Interval: " .. math.Round(Reload, 2) .. " secs"
		txt = txt .. "\nDelay After Reload: " .. math.Round(ReloadDelay, 2) .. " secs"

		if ReloadBonus > 0 then
			txt = txt .. "\n" .. math.floor(ReloadBonus * 100) .. "% Reload Time Decreased"
		end
	else
		if #self.AmmoLink ~= 0 then
			txt = txt .. "\n\nProvided with ammo.\n"
		else
			txt = txt .. "\n\nAmmo not found!\n"
		end
	end

	if not self.Legal then
		txt = txt .. "\nNot legal, disabled for " .. math.ceil(self.NextLegalCheck - ACF.CurTime) .. "s\nIssues: " .. self.LegalIssues
	end

	self:SetOverlayText(txt)

end





function ENT:CanLoadCaliber(cal)

	return ACF_RackCanLoadCaliber(self.Id, cal)

end

function ENT:CanLinkCrate(crate)

	local bdata = crate.BulletData

	-- Don't link if it's a refill crate
	if bdata["RoundType"] == "Refill" or bdata["Type"] == "Refill" then
		return false, "Refill crates cannot be linked!"
	end


	-- Don't link if it's a blacklisted round type for this rack
	local class = ACF_GetGunValue(bdata, "gunclass")
	local Blacklist = ACF.AmmoBlacklist[ bdata.RoundType or bdata.Type ] or {}

	if not class or table.HasValue( Blacklist, class ) then
		return false, "That round type cannot be used with this rack!"
	end


	-- Dont't link if it's too far from this rack
	if RetDist( self, crate ) >= AmmoLinkDistBase then
		return false, "That crate is too far to be connected with this rack!"
	end


	-- Don't link if it's not a missile.
	local ret, msg = ACF_CanLinkRack(self.Id, bdata.Id, bdata, self)
	if not ret then return ret, msg end


	-- Don't link if it's already linked
	for _, v in pairs( self.AmmoLink ) do
		if v == crate then
			return false, "That crate is already linked to this rack!"
		end
	end


	return true

end

function ENT:Link( Target )

	-- Don't link if it's not an ammo crate
	if not IsValid( Target ) or Target:GetClass() ~= "acf_ammo" then
		return false, "Racks can only be linked to ammo crates!"
	end

	-- Don't link if it's a blacklisted round type for this gun
	local Blacklist = ACF.AmmoBlacklist[ Target.RoundType ] or {}

	if table.HasValue( Blacklist, self.Class ) then
		return false, "That round type cannot be used with this gun!"
	end

	local ret, msg = self:CanLinkCrate(Target)
	if not ret then
		return false, msg
	end


	table.insert( self.AmmoLink, Target )
	table.insert( Target.Master, self )

	self:SetOverlayText(txt)

	return true, "Link successful!"

end

function ENT:Unlink( Target )

	local Success = false
	for Key,Value in pairs(self.AmmoLink) do
		if Value == Target then
			table.remove(self.AmmoLink,Key)
			Success = true
		end
	end

	if Success then

		self:GetOverlayText()

		return true, "Unlink successful!"
	else
		return false, "That entity is not linked to this gun!"
	end

end


function RetDist( enta, entb )
	if not ((enta and enta:IsValid()) or (entb and entb:IsValid())) then return 0 end
	return enta:GetPos():Distance(entb:GetPos())
end

function ENT:SetStatusString()

	local Missile = self:PeekMissile()

	if not IsValid(Missile) then
		self.RackStatus = "Empty"
		--self:SetNWString("Status", "Empty")
		self:GetOverlayText()
		return
	else
		if not self.Ready then

		self.RackStatus = "Loading"
		--self:SetNWString("Status", "Loading")
		self:GetOverlayText()
		return
		else

		self.RackStatus = "Ready"
		--self:SetNWString("Status", "Ready")
		self:GetOverlayText()
		return
		end
	end
	self:SetNWString("Linked", "")
	self:SetNWString("Status", "")
	self:GetOverlayText()

end

function ENT:TrimDistantCrates()

	for _, Crate in pairs(self.AmmoLink) do
		if IsValid( Crate ) and Crate.Load and RetDist( self, Crate ) >= AmmoLinkDistBase then
			self:Unlink( Crate )
			self:EmitSound("physics/metal/metal_box_impact_bullet" .. tostring(math.random(1, 3)) .. ".wav", 500, 100)
		end
	end

end

do

	local InstantDetTable = {
		HE		= true,
		CHE		= true,
		HEAT	= true,
		THEAT	= true
	}

	--Jank terrible bad hardcoded function to copy bullet data over so it can be spawned by the missle. Has variables to convert every type of round data. There has to be a better way.
	function BulletDataMath(self)


		self.Bulletdata2 = {}
		self.Bulletdata2.Type = self.BulletData.Type

		--print(self.Bulletdata2.Type)

		if InstantDetTable[self.Bulletdata2.Type] then
			self.Bulletdata2.FuseLength = 0.00001
		else
			self.Bulletdata2.FuseLength = 0.2 --The missile exploded. The shell shouldn't travel across the map.
		end

		self.Bulletdata2.Id = self.BulletData.Id
		self.Bulletdata2.Caliber = self.BulletData.Caliber
		self.Bulletdata2.PropLength = self.BulletData.PropLength --Volume of the case as a cylinder * Powder density converted from g to kg
		self.Bulletdata2.ProjLength = self.BulletData.ProjLength --Volume of the projectile as a cylinder * streamline factor (Data5) * density of steel
		self.Bulletdata2.Data5 = self.BulletData.BoomFillerMass or self.BulletData.FillerMass or 0 --He Filler or Flechette count
		self.Bulletdata2.Data6 = self.BulletData.Data6 or 55 --HEAT ConeAng or Flechette Spread
		self.Bulletdata2.Data7 = self.BulletData.Data7
		self.Bulletdata2.Data8 = self.BulletData.Data8
		self.Bulletdata2.Data9 = self.BulletData.Data9
		self.Bulletdata2.Data10 = self.BulletData.Data10 -- Tracer
		self.Bulletdata2.Data13 = self.BulletData.Data13 or 55 --THEAT ConeAng2
		self.Bulletdata2.Data14 = self.BulletData.Data14 or 0.05 --THEAT HE Allocation

		--print(self.BulletData.Data14)

		self.Bulletdata2.HEAllocation	= self.Bulletdata2.Data14
		self.Bulletdata2.Data15 = self.BulletData.Data15
		self.Bulletdata2.Colour = self:GetColor() or Color(255, 255, 255)

		--
		self.Bulletdata2.AmmoType = self.Bulletdata2.Type
		self.Bulletdata2.FrArea = 3.1416 * (self.BulletData.Caliber / 2) ^ 2
		self.Bulletdata2.ProjMass = self.BulletData.FrArea * (self.BulletData.ProjLength * 7.9 / 1000)
		self.Bulletdata2.PropMass = self.BulletData.FrArea * (self.BulletData.PropLength * ACF.PDensity / 1000) --Volume of the case as a cylinder * Powder density converted from g to kg


		self.Bulletdata2.FillerMass = self.Bulletdata2.Data5
		local ConeThick = self.Bulletdata2.Caliber / 50
		local Radius = (self.Bulletdata2.Caliber / 2)
		local ConeLength = math.tan(math.rad(self.Bulletdata2.Data6)) * Radius
		local ConeArea = 3.1416 * Radius * (Radius ^ 2 + ConeLength ^ 2) ^ 0.5
		local ConeVol = ConeArea * ConeThick
		self.Bulletdata2.SlugMass = ConeVol * 7.9 / 1000
			ConeLength = math.tan(math.rad(self.Bulletdata2.Data13)) * Radius
			ConeArea = 3.1416 * Radius * (Radius ^ 2 + ConeLength ^ 2) ^ 0.5
			ConeVol = ConeArea * ConeThick
		self.Bulletdata2.SlugMass2 = ConeVol * 7.9 / 1000
		local Rad = math.rad(self.Bulletdata2.Data6 / 2)
		self.Bulletdata2.SlugCaliber = self.Bulletdata2.Caliber - self.Bulletdata2.Caliber * (math.sin(Rad) * 0.5 + math.cos(Rad) * 1.5) / 2
			  Rad = math.rad(self.Bulletdata2.Data13 / 2)

		if self.Bulletdata2.Type ~= "THEAT" then
			self.Bulletdata2.HEAllocation = 0
		end

		self.Bulletdata2.SlugCaliber2 = self.Bulletdata2.Caliber - self.Bulletdata2.Caliber * (math.sin(Rad) * 0.5 + math.cos(Rad) * 1.5) / 2
		self.Bulletdata2.SlugMV = ((self.Bulletdata2.FillerMass / 2 * ACF.HEPower * (1 - self.Bulletdata2.HEAllocation) * math.sin(math.rad(10 + self.Bulletdata2.Data6) / 2) / self.Bulletdata2.SlugMass) ^ ACF.HEATMVScale) * (ACF_GetRackValue(self.BulletData, "penmul") or ACF_GetGunValue(self.BulletData.Id, "penmul") or 1) / ACF.KEtoRHA -- / math.sqrt(ACF.ShellPenMul)
		self.Bulletdata2.SlugMV2 = ((self.Bulletdata2.FillerMass / 2 * ACF.HEPower * self.Bulletdata2.HEAllocation * math.sin(math.rad(10 + self.Bulletdata2.Data13) / 2) / self.Bulletdata2.SlugMass2) ^ ACF.HEATMVScaleTan) --keep fillermass/2 so that penetrator stays the same

		local BoomMul = 1
		if self.Bulletdata2.Type == "HEAT" or self.Bulletdata2.Type == "THEAT" then
			BoomMul = 1 / 4
		end
		self.Bulletdata2.FillerMass = self.Bulletdata2.FillerMass * BoomMul
		self.Bulletdata2.BoomFillerMass = self.Bulletdata2.FillerMass
		self.Bulletdata2.FillerVol = self.Bulletdata2.BoomFillerMass or self.Bulletdata2.FillerMass

		--data.SlugMV = (slugMV or 0) * (ACF_GetGunValue(data.Id, "penmul") or 1.2)
		--data.SlugMV2 = (slugMV2 or 0) * (ACF_GetGunValue(data.Id, "penmul") or 1.2)

		--		print("SlugMV: " .. self.BulletData.SlugMV)
		local SlugFrArea = 3.1416 * (self.Bulletdata2.SlugCaliber / 2) ^ 2
		self.Bulletdata2.SlugPenArea = SlugFrArea ^ ACF.PenAreaMod
		self.Bulletdata2.SlugDragCoef = ((SlugFrArea / 10000) / self.Bulletdata2.SlugMass)
		SlugFrArea = 3.1416 * (self.Bulletdata2.SlugCaliber2 / 2) ^ 2
		self.Bulletdata2.SlugPenArea2 = SlugFrArea ^ ACF.PenAreaMod
		self.Bulletdata2.SlugDragCoef2 = ((SlugFrArea / 10000) / self.Bulletdata2.SlugMass2)
		self.Bulletdata2.SlugRicochet = 500 --Base ricochet angle (The HEAT slug shouldn't ricochet at all)
		self.Bulletdata2.CasingMass = self.Bulletdata2.ProjMass - self.Bulletdata2.FillerMass - ConeVol * 7.9 / 1000
		self.Bulletdata2.Fragments = math.max(math.floor((self.Bulletdata2.BoomFillerMass / self.Bulletdata2.CasingMass) * ACF.HEFrag), 2)
		self.Bulletdata2.FragMass = self.Bulletdata2.CasingMass / self.Bulletdata2.Fragments
		--		self.BulletData.DragCoef  = 0 --Alternatively manually set it
		self.Bulletdata2.DragCoef = ((self.Bulletdata2.FrArea / 10000) / self.Bulletdata2.ProjMass)
		--print(self.BulletData.SlugDragCoef)
		--Don't touch below here
		self.Bulletdata2.MuzzleVel = ACF_MuzzleVelocity(self.Bulletdata2.PropMass, self.Bulletdata2.ProjMass, self.Bulletdata2.Caliber)
		self.Bulletdata2.ShovePower = 0.1
		self.Bulletdata2.KETransfert = 0.3
		self.Bulletdata2.PenArea = self.Bulletdata2.FrArea ^ ACF.PenAreaMod
		self.Bulletdata2.Pos = Vector(0, 0, 0)
		self.Bulletdata2.LimitVel = 800
		self.Bulletdata2.Ricochet = 999
		self.Bulletdata2.Flight = Vector(0, 0, 0)
		self.Bulletdata2.BoomPower = self.Bulletdata2.PropMass + self.Bulletdata2.FillerMass
		--		local SlugEnergy = ACF_Kinetic( self.BulletData.MuzzleVel * 39.37 + self.BulletData.SlugMV * 39.37 , self.BulletData.SlugMass, 999999 )
		local SlugEnergy = ACF_Kinetic(self.Bulletdata2.SlugMV * 39.37, self.Bulletdata2.SlugMass, 999999)
		self.Bulletdata2.MaxPen = (SlugEnergy.Penetration / self.Bulletdata2.SlugPenArea) * ACF.KEtoRHA
				--print(((SlugEnergy.Penetration / self.Bulletdata2.SlugPenArea) * ACF.KEtoRHA))
		--For Fake Crate
		self.BoomFillerMass = self.Bulletdata2.BoomFillerMass
		self.Type = self.Bulletdata2.Type
		self.Bulletdata2.Tracer = self.Bulletdata2.Data10
		self.Tracer = self.Bulletdata2.Data10
		self.Caliber = self.Bulletdata2.Caliber
		self.ProjMass = self.Bulletdata2.ProjMass
		self.FillerMass = self.Bulletdata2.FillerMass
		self.DragCoef = self.Bulletdata2.DragCoef
		self.Colour = self.Bulletdata2.Colour
		self.DetonatorAngle = 80
	end

end

function UpdateMissileSkin(Missile)

	if Missile.BulletData then

		local warhead = Missile.BulletData.Type

		local skins = ACF_GetGunValue(Missile.BulletData, "skinindex")
		if not skins then return end

		local skin = skins[warhead] or 0

		Missile:SetSkin(skin)

	end
end

function UpdateMissileBodygroups(Missile) --Guidance



	local bodygroups = Missile:GetBodyGroups()

	for _, group in pairs(bodygroups) do

		if string.lower(group.name) == "guidance" and Missile.Guidance then

			ApplyBodySubgroup(Missile, group, Missile.Guidance.Name) --Applies if not dumb guidance. Taken from original missiles. Replace with table lookup for guidance bodygroups.
			continue

		end

		if string.lower(group.name) == "warhead" and Missile.BulletData then

			ApplyBodySubgroup(Missile, group, Missile.BulletData.Type)
			continue
		end


	end
end

function ApplyBodySubgroup(missile, group, targetname)

	local name = string.lower(targetname) .. ".smd"

	for subId, subName in pairs(group.submodels) do
		if string.lower(subName) == name then
			missile:SetBodygroup(group.id, subId)
			return
		end
	end
end

function ENT:UpdateRefillBonus()

	local totalBonus			= 0
	local selfPos			= self:GetPos()

	local Efficiency			= 0.11 * ACF.AmmoMod		-- Copied from acf_ammo, beware of changes!
	local minFullEfficiency	= 50000 * Efficiency	-- The minimum crate volume to provide full efficiency bonus all by itself.
	local maxDist			= ACF.RefillDistance

	for _, crate in pairs(ACF.AmmoCrates or {}) do

		if crate.RoundType ~= "Refill" then
			continue

		elseif crate.Ammo > 0 and crate.Load then
			local dist = selfPos:Distance(crate:GetPos())

			if dist < maxDist then

				dist = math.max(0, dist * 2 - maxDist)

				local bonus = ( (crate.Volume or 0.1) / minFullEfficiency ) * ( maxDist - dist ) / maxDist

				totalBonus = totalBonus + bonus

			end
		end

	end


	self.ReloadMultiplierBonus = 1 - math.min(totalBonus, 1)

	--self:SetNWFloat(  "ReloadBonus", self.ReloadMultiplierBonus)

	return self.ReloadMultiplierBonus

end

function ENT:ACF_OnDamage( Entity, Energy, FrArea, _, Inflictor, _, _ )	--This function needs to return HitRes

	local HitRes	= ACF_PropDamage( Entity, Energy , FrArea, 0, Inflictor ) --Calling the standard damage prop function. Angle of incidence set to 0 for more consistent damage.

	--print(math.Round(HitRes.Damage * 100))
	--print(HitRes.Loss * 100)

	if HitRes.Kill then



		for i = 1, self.MaxMissile do

			local MissileArray = self.Missiles[i] or {}
			local MissileTest = MissileArray[1] or NULL

			if MissileTest:IsValid() then
				MissileTest.MissileActive = true
				MissileTest.ActivationTime = 0
				MissileTest.Lifetime = 0 --Instantly scuttle as soon as can execute.
				MissileTest:SetParent(NULL)
			end

		end

		--self:Detonate()
		self.MissileActive = true
		self.ActivationTime = 0
		self.Lifetime = 0 --Instantly scuttle as soon as can execute.

		return { Damage = 1, Overkill = 0, Loss = 0, Kill = true }

	end

	return HitRes --This function needs to return HitRes

end

do
	local MissileGuidanceFactors = {
		Dumb				= 0.3,
		Straight_Running	= 0.45,
		GPS					= 0.6,
		Antimissile			= 0.6,
		AntiRadiation		= 0.7,
		Beam_Riding			= 0.7,
		GPS_TerrainAvoidant = 0.8,
		SACLOS				= 0.75,
		Semiactive			= 0.85,
		Wire				= 1.0,
		Acoustic_Straight 	= 1.0,
		Acoustic_Helical	= 1.0,
		Laser				= 1.2,
		Infrared			= 1.2,
		Top_Attack_IR		= 1.5,
		Radar				= 1.5
	}

	function CalculateMissileCost(BulletData) --Used for both the missiles on the rack and the ammo entities
		local Pts = ACF_GetRackValue(BulletData, "pointcost") or ACF_GetGunValue(BulletData.Id, "pointcost") or 0.9
		local Guid = BulletData.Data7 or "Dumb"
		Pts = Pts * MissileGuidanceFactors[Guid] or 0
		return Pts

	end


end