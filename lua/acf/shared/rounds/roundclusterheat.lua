AddCSLuaFile()

local Round = {}

Round.type  = "Ammo"
Round.name  = "[CLUSTER-HEAT] - " .. ACFTranslation.ShellHEAT[1]
Round.model = "models/missiles/glatgm/9m112f.mdl"
Round.desc  = ACFTranslation.ShellHEAT[2]
Round.netid = 28

Round.Type  = "CHEAT"

function Round.ConeCalc(ConeAngle, Radius)
	local ConeLength = math.tan(math.rad(ConeAngle)) * Radius
	local ConeArea   = 3.1416 * Radius * (Radius ^ 2 + ConeLength ^ 2) ^ 0.5
	local ConeVol    = (3.1416 * Radius ^ 2 * ConeLength) / 3

	return ConeLength, ConeArea, ConeVol
end

function Round.convert(_, PlayerData)
	local Data       = {}
	local ServerData = {}
	local GUIData    = {}

	PlayerData.PropLength = PlayerData.PropLength or 0
	PlayerData.ProjLength = PlayerData.ProjLength or 0
	PlayerData.Tracer     = PlayerData.Tracer or 0
	PlayerData.TwoPiece   = PlayerData.TwoPiece or 0

	PlayerData.Data5  = math.max(PlayerData.Data5 or 0, 0) -- filler vol
	PlayerData.Data6  = PlayerData.Data6 or 0              -- cone angle
	PlayerData.Data7  = PlayerData.Data7 or 0

	PlayerData.Data13 = math.max(PlayerData.Data13 or 0, 5)      -- ClusterMult
	PlayerData.Data14 = math.max(PlayerData.Data14 or 2000, 500) -- FuseDistance

	PlayerData, Data, ServerData, GUIData = ACF_RoundBaseGunpowder(PlayerData, Data, ServerData, GUIData)

	local ConeThick = Data.Caliber / 50
	local ConeArea  = 0
	local AirVol    = 0

	local ConeLength
	ConeLength, ConeArea, AirVol = Round.ConeCalc(PlayerData.Data6, Data.Caliber / 2, PlayerData.ProjLength)

	-- preliminary mass for shell capacity limits
	Data.ProjMass  = math.max(GUIData.ProjVolume - PlayerData.Data5, 0) * 7.9 / 1000
	             + math.min(PlayerData.Data5, GUIData.ProjVolume) * ACF.HEDensity / 1000
	             + ConeArea * ConeThick * 7.9 / 1000

	Data.MuzzleVel = ACF_MuzzleVelocity(Data.PropMass, Data.ProjMass, Data.Caliber)

	local Energy = ACF_Kinetic(Data.MuzzleVel * 39.37, Data.ProjMass, Data.LimitVel)
	local MaxVol, MaxLength, MaxRadius = ACF_RoundShellCapacity(Energy.Momentum, Data.FrArea, Data.Caliber, Data.ProjLength)

	GUIData.ClusterMult  = math.Clamp(PlayerData.Data13, 10, 100)
	Data.ClusterMult     = GUIData.ClusterMult

	GUIData.FuseDistance = math.Clamp(PlayerData.Data14, 500, 6000)
	Data.FuseDistance    = GUIData.FuseDistance

	GUIData.MinConeAng = 0
	GUIData.MaxConeAng = math.deg(math.atan((Data.ProjLength - ConeThick) / (Data.Caliber / 2)))
	GUIData.ConeAng    = math.Clamp(PlayerData.Data6 * 1, GUIData.MinConeAng, GUIData.MaxConeAng)

	ConeLength, ConeArea, AirVol = Round.ConeCalc(GUIData.ConeAng, Data.Caliber / 2, Data.ProjLength)
	local ConeVol = ConeArea * ConeThick

	GUIData.MinFillerVol = 0
	GUIData.MaxFillerVol = math.max(MaxVol - AirVol - ConeVol, GUIData.MinFillerVol)
	GUIData.FillerVol    = math.Clamp(PlayerData.Data5 * 1, GUIData.MinFillerVol, GUIData.MaxFillerVol)

	Data.FillerMass     = GUIData.FillerVol * ACF.HEDensity / 1450
	Data.BoomFillerMass = Data.FillerMass / 3 -- HE blast component for shaped-charge rounds

	Data.ProjMass  = math.max(GUIData.ProjVolume - GUIData.FillerVol - AirVol - ConeVol, 0) * 7.9 / 1000
	               + Data.FillerMass
	               + ConeVol * 7.9 / 1000

	Data.MuzzleVel = ACF_MuzzleVelocity(Data.PropMass, Data.ProjMass, Data.Caliber)

	-- HEAT slug
	Data.SlugMass = ConeVol * 7.9 / 1000

	local Rad = math.rad(GUIData.ConeAng / 2)
	Data.SlugCaliber = Data.Caliber - Data.Caliber * (math.sin(Rad) * 0.5 + math.cos(Rad) * 1.5) / 2

	Data.SlugMV   = (1.3 * (Data.FillerMass / 2 * ACF.HEPower * math.sin(math.rad(10 + GUIData.ConeAng) / 2) / Data.SlugMass) ^ ACF.HEATMVScale) * math.sqrt(ACF.ShellPenMul)
	Data.SlugMass = Data.SlugMass * 4 ^ 2
	Data.SlugMV   = Data.SlugMV / 4

	local SlugFrArea   = 3.1416 * (Data.SlugCaliber / 2) ^ 2
	Data.SlugPenArea   = SlugFrArea ^ ACF.PenAreaMod
	Data.SlugDragCoef  = (SlugFrArea / 10000) / Data.SlugMass
	Data.SlugRicochet  = 500

	-- Casing mass available for fragments (kg)
	Data.CasingMass = math.max(Data.ProjMass - Data.FillerMass - (ConeVol * 7.9 / 1000), 0)
	Data.FragMass   = Data.CasingMass

	-- Random ACF values
	Data.ShovePower    = 0.1
	Data.PenArea       = Data.FrArea ^ ACF.PenAreaMod
	Data.DragCoef      = (Data.FrArea / 10000) / Data.ProjMass
	Data.LimitVel      = 100
	Data.KETransfert   = 0.1
	Data.Ricochet      = 80
	Data.DetonatorAngle = 80

	Data.Detonated   = false
	Data.HEATLastPos = Vector(0,0,0)
	Data.NotFirstPen = false
	Data.BoomPower   = Data.PropMass + Data.FillerMass

	if SERVER then
		ServerData.Id   = PlayerData.Id
		ServerData.Type = PlayerData.Type
		return table.Merge(Data, ServerData)
	end

	if CLIENT then
		GUIData = table.Merge(GUIData, Round.getDisplayData(Data))
		return table.Merge(Data, GUIData)
	end
end

function Round.getDisplayData(Data)
	local GUIData = {}

	GUIData.FuseDistance = Data.FuseDistance

	-- Matches server bomblet count logic
	GUIData.BombletCount = math.Round(math.Clamp(math.Round((Data.FillerMass or 0) * 3), 10, 160) * (Data.ClusterMult or 100) / 100)
	local bomblets = math.max(GUIData.BombletCount, 1)

	-- Display per-bomblet blast/frags (approximation based on how you spawn them)
	local fillerPer = (Data.FillerMass or 0) / bomblets / 2
	GUIData.AdjFillerMass = fillerPer

	-- You spawn HEAT bomblets with ProjMass ~= parent.ProjMass / bomblets / 6
	local projPer = (Data.ProjMass or 0) / bomblets / 6
	local casingPer = math.max(projPer - fillerPer, 0)

	local HE = ACF_GetHEDisplayData(fillerPer, casingPer)

	GUIData.BlastRadius = HE.BlastRadius
	GUIData.Fragments = HE.Fragments
	GUIData.FragMass = HE.FragMass
	GUIData.FragVel = HE.FragVel

	return GUIData
end

function Round.network(Crate, BulletData)
	Crate:SetNWString("AmmoType", "CHEAT")
	Crate:SetNWString("AmmoID", BulletData.Id)
	Crate:SetNWFloat("Caliber", BulletData.Caliber)
	Crate:SetNWFloat("ProjMass", BulletData.ProjMass)
	Crate:SetNWFloat("FillerMass", BulletData.FillerMass)
	Crate:SetNWFloat("PropMass", BulletData.PropMass)
	Crate:SetNWFloat("DragCoef", BulletData.DragCoef)
	Crate:SetNWFloat("SlugMass", BulletData.SlugMass)
	Crate:SetNWFloat("SlugCaliber", BulletData.SlugCaliber)
	Crate:SetNWFloat("SlugDragCoef", BulletData.SlugDragCoef)
	Crate:SetNWFloat("MuzzleVel", BulletData.MuzzleVel)
	Crate:SetNWFloat("Tracer", BulletData.Tracer)

	Crate:SetNWFloat("BulletModel", Round.model)
end

function Round.cratetxt(BulletData)
	local DData = Round.getDisplayData(BulletData)

	local str =
	{
		"Muzzle Velocity: ", math.Round(BulletData.MuzzleVel, 1), " m/s\n",
		"Bomblet Count: ", DData.BombletCount, "\n",
		"Blast Radius: ", math.Round(DData.BlastRadius, 1), " m\n",
		"Blast Energy: ", math.floor(DData.AdjFillerMass * ACF.HEPower), " KJ"
	}

	return table.concat(str)
end

function Round.propimpact(_, Bullet, Target, HitNormal, HitPos, Bone)
	if ACF_Check(Target) then
		local Speed  = Bullet.Flight:Length() / ACF.VelScale
		local Energy = ACF_Kinetic(Speed, Bullet.ProjMass - Bullet.FillerMass, Bullet.LimitVel)
		local HitRes = ACF_RoundImpact(Bullet, Speed, Energy, Target, HitPos, HitNormal, Bone)

		if HitRes.Ricochet then
			return "Ricochet"
		end
	end
	return false
end

function Round.worldimpact()
	return false
end

do
	local function GenerateCluster(bdata)
		local Bomblets = math.Round(math.Clamp(math.Round((bdata.FillerMass or 0) * 3), 10, 160) * (bdata.ClusterMult or 100) / 100)

		local GEnt = bdata.Gun
		if not IsValid(GEnt) then return end

		GEnt.BulletDataC = {}
		GEnt.BulletDataC.Bomblets = Bomblets

		GEnt.BulletDataC["Accel"]      = Vector(0,0,-600)
		GEnt.BulletDataC["BoomPower"]  = bdata.BoomPower

		GEnt.BulletDataC["Caliber"]    = math.Clamp(bdata.Caliber / Bomblets * 5, 0.05, bdata.Caliber)
		GEnt.BulletDataC["Crate"]      = bdata.Crate
		GEnt.BulletDataC["DragCoef"]   = (bdata.DragCoef or 0) / Bomblets / 4

		-- Per-bomblet filler for HEAT bomblet (small)
		GEnt.BulletDataC["FillerMass"] = (bdata.FillerMass or 0) / Bomblets / 2

		GEnt.BulletDataC["Filter"]     = {} -- must be a table
		GEnt.BulletDataC["Flight"]     = bdata.Flight
		GEnt.BulletDataC["FlightTime"] = 0
		GEnt.BulletDataC["FrArea"]     = bdata.FrArea
		GEnt.BulletDataC["FuseLength"] = 0
		GEnt.BulletDataC["Gun"]        = GEnt
		GEnt.BulletDataC["Id"]         = bdata.Id
		GEnt.BulletDataC["KETransfert"]= bdata.KETransfert
		GEnt.BulletDataC["LimitVel"]   = 700
		GEnt.BulletDataC["MuzzleVel"]  = 100
		GEnt.BulletDataC["Owner"]      = bdata.Owner
		GEnt.BulletDataC["PenArea"]    = bdata.PenArea
		GEnt.BulletDataC["Pos"]        = bdata.Pos

		-- Small bomblet body
		GEnt.BulletDataC["ProjLength"] = (bdata.ProjLength or 0) / Bomblets / 6
		GEnt.BulletDataC["ProjMass"]   = (bdata.ProjMass or 0) / Bomblets / 6

		GEnt.BulletDataC["PropLength"] = bdata.PropLength
		GEnt.BulletDataC["PropMass"]   = bdata.PropMass
		GEnt.BulletDataC["Ricochet"]   = 90

		GEnt.BulletDataC["RoundVolume"]= bdata.RoundVolume
		GEnt.BulletDataC["ShovePower"] = bdata.ShovePower
		GEnt.BulletDataC["Tracer"]     = 0

		GEnt.BulletDataC["Type"]       = "HEAT"

		-- Slug fields (scaled)
		GEnt.BulletDataC["SlugMass"]     = (bdata.SlugMass or 0) / Bomblets
		GEnt.BulletDataC["SlugCaliber"]  = (bdata.SlugCaliber or 0) / Bomblets
		GEnt.BulletDataC["SlugDragCoef"] = (bdata.SlugDragCoef or 0) / Bomblets
		GEnt.BulletDataC["SlugMV"]       = (bdata.SlugMV or 0) * 3
		GEnt.BulletDataC["SlugPenArea"]  = bdata.SlugPenArea
		GEnt.BulletDataC["SlugRicochet"] = bdata.SlugRicochet

		-- Derive a "cone volume" consistent with old approach
		-- (used only to subtract liner mass from casing mass)
		GEnt.BulletDataC["ConeVol"] = ((bdata.SlugMass or 0) * 1000 / 7.9) / Bomblets

		-- HEAT blast uses BoomFillerMass
		GEnt.BulletDataC["BoomFillerMass"] = GEnt.BulletDataC["FillerMass"]

		-- Cone liner mass in kg
		local coneMass = (GEnt.BulletDataC["ConeVol"] or 0) * 7.9 / 1000

		-- Correct casing mass for fragments (kg)
		GEnt.BulletDataC["CasingMass"] = math.max((GEnt.BulletDataC["ProjMass"] or 0) - (GEnt.BulletDataC["FillerMass"] or 0) - coneMass, 0)
		GEnt.BulletDataC["FragMass"]   = GEnt.BulletDataC["CasingMass"]

		GEnt.FakeCrate = GEnt.FakeCrate or ents.Create("acf_fakecrate2")
		GEnt.FakeCrate:RegisterTo(GEnt.BulletDataC)
		GEnt.BulletDataC["Crate"] = GEnt.FakeCrate:EntIndex()

		GEnt:DeleteOnRemove(GEnt.FakeCrate)
	end

	local function CreateCluster(bullet)
		local GEnt = bullet.Gun
		if not IsValid(GEnt) then return end

		local MuzzleVec = bullet.Flight:GetNormalized()
		local GunBData  = GEnt.BulletDataC or {}
		local CCount    = GunBData.Bomblets or 0

		for I = 1, CCount do
			timer.Simple(0.012 * I, function()
				if not IsValid(GEnt) then return end

				local Spread = VectorRand()
				GEnt.BulletDataC["Flight"] = (MuzzleVec + (Spread * 0.6)):GetNormalized()
					* GEnt.BulletDataC["MuzzleVel"] * 39.37 * math.Rand(0.5, 1.0)

				local MuzzlePos = bullet.Pos
				GEnt.BulletDataC.Pos = MuzzlePos - MuzzleVec

				GEnt.CreateShell = ACF.RoundTypes[GEnt.BulletDataC.Type].create
				GEnt:CreateShell(GEnt.BulletDataC)
			end)
		end
	end

	function Round.create(_, BulletData)
		ACF_CreateBullet(BulletData)
		GenerateCluster(BulletData)
	end

	local function DoSeparationExplosion(Index, Bullet)
		ACF_BulletClient(Index, Bullet, "Update", 1, Bullet.Pos)

		local sepFiller = (Bullet.FillerMass or 0) / 20

		-- Prevent insane fragments: separation has limited casing breakup.
		local casing = math.max((Bullet.ProjMass or 0) - (Bullet.FillerMass or 0), 0)
		local sepFrag = casing * 0.05

		ACF_HE(Bullet.Pos - Bullet.Flight:GetNormalized() * 3, Bullet.Flight:GetNormalized(), sepFiller, sepFrag, Bullet.Owner, nil, Bullet.Gun)

		local GunEnt = Bullet.Gun
		if IsValid(GunEnt) then
			CreateCluster(Bullet)
		end

		ACF_RemoveBullet(Index)
	end

	function Round.onbulletflight(Index, Bullet)
		local tr = util.QuickTrace(Bullet.Pos, Bullet.Flight:GetNormalized() * (Bullet.FuseDistance or 2000), {})

		if tr.Hit and not (tr.HitSky or Bullet.SkyLvL) and Bullet.FlightTime > 0.5 then
			DoSeparationExplosion(Index, Bullet)
		end
	end

	function Round.endflight(Index, Bullet)
		DoSeparationExplosion(Index, Bullet)
	end
end

function Round.endeffect(_, Bullet)
	local Radius = ((Bullet.FillerMass or 0) / 20) ^ 0.33 * 8 * 39.37
	local Flash = EffectData()
	Flash:SetOrigin(Bullet.SimPos)
	Flash:SetNormal(Bullet.SimFlight:GetNormalized())
	Flash:SetRadius(math.Round(math.max(Radius / 39.37, 1), 2))
	util.Effect("ACF_Scaled_Explosion", Flash)
end

function Round.pierceeffect(_, Bullet)
	local BulletEffect = {}
	BulletEffect.Num = 1
	BulletEffect.Src = Bullet.SimPos - Bullet.SimFlight:GetNormalized()
	BulletEffect.Dir = Bullet.SimFlight:GetNormalized()
	BulletEffect.Spread = Vector(0,0,0)
	BulletEffect.Tracer = 0
	BulletEffect.Force  = 0
	BulletEffect.Damage = 0
	LocalPlayer():FireBullets(BulletEffect)

	util.Decal("ExplosiveGunshot", Bullet.SimPos + Bullet.SimFlight * 10, Bullet.SimPos - Bullet.SimFlight * 10)

	local Spall = EffectData()
	Spall:SetOrigin(Bullet.SimPos)
	Spall:SetNormal(Bullet.SimFlight:GetNormalized())
	Spall:SetScale(math.max(((Bullet.RoundMass * (Bullet.SimFlight:Length() / 39.37) ^ 2) / 2000) / 10000, 1))
	util.Effect("AP_Hit", Spall)
end

function Round.ricocheteffect(_, Bullet)
	local Spall = EffectData()
	Spall:SetEntity(Bullet.Crate)
	Spall:SetOrigin(Bullet.SimPos)
	Spall:SetNormal(Bullet.SimFlight:GetNormalized())
	Spall:SetScale(Bullet.SimFlight:Length())
	Spall:SetMagnitude(Bullet.RoundMass)
	util.Effect("ACF_AP_Ricochet", Spall)
end

function Round.guicreate(Panel, Table)
	acfmenupanel:AmmoSelect(ACF.AmmoBlacklist.CHE)

	acfmenupanel:CPanelText("CrateInfoBold", "Crate information:", "DermaDefaultBold")
	acfmenupanel:CPanelText("BonusDisplay", "")
	acfmenupanel:CPanelText("Desc", "")
	acfmenupanel:CPanelText("BoldAmmoStats", "Round information: ", "DermaDefaultBold")
	acfmenupanel:CPanelText("VelocityDisplay", "")
	acfmenupanel:CPanelText("LengthDisplay", "")

	acfmenupanel:AmmoSlider("PropLength",0,0,1000,3, "Propellant Length", "")
	acfmenupanel:AmmoSlider("ProjLength",0,0,1000,3, "Projectile Length", "")
	acfmenupanel:AmmoSlider("ConeAng",0,0,1000,3, "HEAT Cone Angle", "")
	acfmenupanel:AmmoSlider("FillerVol",0,0,1000,3, "Total HEAT Warhead volume", "")

	acfmenupanel:AmmoSlider("ClusterMult",0,0,100,1, "Cluster Multiplier (%)", "")
	acfmenupanel:AmmoSlider("FuseDistance",0,500,6000,2, "Cluster Fuse Distance", "")

	ACE_Checkboxes()

	acfmenupanel:CPanelText("BlastDisplay", "")
	acfmenupanel:CPanelText("FragDisplay", "")

	Round.guiupdate(Panel, Table)
end

function Round.guiupdate(Panel)
	local PlayerData = {}
	PlayerData.Id         = acfmenupanel.AmmoData.Data.id
	PlayerData.Type       = "CHEAT"
	PlayerData.PropLength = acfmenupanel.AmmoData.PropLength
	PlayerData.ProjLength = acfmenupanel.AmmoData.ProjLength
	PlayerData.Data5      = acfmenupanel.AmmoData.FillerVol
	PlayerData.Data6      = acfmenupanel.AmmoData.ConeAng
	PlayerData.Data13     = acfmenupanel.AmmoData.ClusterMult
	PlayerData.Data14     = acfmenupanel.AmmoData.FuseDistance
	PlayerData.Tracer     = acfmenupanel.AmmoData.Tracer
	PlayerData.TwoPiece   = acfmenupanel.AmmoData.TwoPiece

	local Data = Round.convert(Panel, PlayerData)

	RunConsoleCommand("acfmenu_data1", acfmenupanel.AmmoData.Data.id)
	RunConsoleCommand("acfmenu_data2", PlayerData.Type)
	RunConsoleCommand("acfmenu_data3", Data.PropLength)
	RunConsoleCommand("acfmenu_data4", Data.ProjLength)
	RunConsoleCommand("acfmenu_data5", Data.FillerVol)
	RunConsoleCommand("acfmenu_data6", Data.ConeAng)
	RunConsoleCommand("acfmenu_data13", Data.ClusterMult)
	RunConsoleCommand("acfmenu_data14", Data.FuseDistance)
	RunConsoleCommand("acfmenu_data10", Data.Tracer)
	RunConsoleCommand("acfmenu_data11", Data.TwoPiece)

	ACE_AmmoCapacityDisplay(Data)
	acfmenupanel:CPanelText("VelocityDisplay", "Muzzle Velocity : " .. math.floor(Data.MuzzleVel * ACF.VelScale) .. " m/s")

	acfmenupanel:AmmoSlider("PropLength", Data.PropLength, Data.MinPropLength, Data.MaxTotalLength, 3, "Propellant Length",
		"Propellant Mass : " .. (math.floor(Data.PropMass * 1000)) .. " g" .. "/ " .. (math.Round(Data.PropMass, 1)) .. " kg")

	acfmenupanel:AmmoSlider("ProjLength", Data.ProjLength, Data.MinProjLength, Data.MaxTotalLength, 3, "Projectile Length",
		"Projectile Mass : " .. (math.floor(Data.ProjMass * 1000)) .. " g" .. "/ " .. (math.Round(Data.ProjMass, 1)) .. " kg")

	acfmenupanel:AmmoSlider("ConeAng", Data.ConeAng, Data.MinConeAng, Data.MaxConeAng, 0, "Crush Cone Angle", "")
	acfmenupanel:AmmoSlider("FillerVol", Data.FillerVol, Data.MinFillerVol, Data.MaxFillerVol, 3, "HE Filler Volume",
		"HE Filler Mass : " .. (math.floor(Data.FillerMass * 1000)) .. " g")

	acfmenupanel:AmmoSlider("ClusterMult", Data.ClusterMult, 10, 100, 1, "Cluster Multiplier (%)", "Bomblets: " .. Data.BombletCount)
	acfmenupanel:AmmoSlider("FuseDistance", Data.FuseDistance, 500, 6000, 2, "Cluster Fuse Distance", "")

	ACE_Checkboxes(Data)

	acfmenupanel:CPanelText("Desc", ACF.RoundTypes[PlayerData.Type].desc)
	acfmenupanel:CPanelText("LengthDisplay", "Round Length : " .. (math.floor((Data.PropLength + Data.ProjLength + (math.floor(Data.Tracer * 5) / 10)) * 100) / 100) .. "/" .. Data.MaxTotalLength .. " cm")
	acfmenupanel:CPanelText("BlastDisplay", "Blast Radius : " .. (math.floor(Data.BlastRadius * 100) / 100) .. " m")
	acfmenupanel:CPanelText("FragDisplay",
		"Fragments : " .. Data.Fragments ..
		"\n Average Fragment Weight : " .. (math.floor(Data.FragMass * 10000) / 10) .. " g" ..
		"\n Average Fragment Velocity : " .. math.floor(Data.FragVel) .. " m/s")

	acfmenupanel:CPanelText("RicoDisplay", "Max Detonation angle: " .. Data.DetonatorAngle .. "°")
end

list.Set("SPECSRoundTypes", Round.Type, Round)
ACF.RoundTypes[Round.Type] = Round
ACF.IdRounds[Round.netid] = Round.Type