
AddCSLuaFile()

ACF.AmmoBlacklist.CHE = { "MG", "AC", "HMG","RAC", "ATR", "SL", "GL", "FFAR", "FGL", "ATR", "SBC", "AAM", "ATGM", "ASR", "SAM" }

local Round = {}

Round.type  = "Ammo" --Tells the spawn menu what entity to spawn
Round.name  = "[CLUSTER-HE] - " .. ACFTranslation.ShellHE[1] --Human readable name
Round.model = "models/missiles/glatgm/9m112f.mdl" --Shell flight model
Round.desc  = ACFTranslation.ShellHE[2]
Round.netid = 24 --Unique ammotype ID for network transmission

Round.Type  = "CHE"

-- Function to convert the player's slider data into the complete round data
function Round.convert( _, PlayerData )

	local Data		= {}
	local ServerData	= {}
	local GUIData	= {}

	PlayerData.PropLength	=  PlayerData.PropLength	or 0
	PlayerData.ProjLength	=  PlayerData.ProjLength	or 0
	PlayerData.Tracer	=  PlayerData.Tracer		or 0
	PlayerData.TwoPiece	=  PlayerData.TwoPiece	or 0
	PlayerData.Data5		= math.max(PlayerData.Data5 or 0, 0) --HEFiller
	PlayerData.Data13		= math.max(PlayerData.Data13 or 0, 5) --ClusterMult
	PlayerData.Data14		= math.max(PlayerData.Data14 or 2000, 500) --ExplodeDistance

	PlayerData, Data, ServerData, GUIData = ACF_RoundBaseGunpowder( PlayerData, Data, ServerData, GUIData )

	--Shell sturdiness calcs

	--Volume of the projectile as a cylinder - Volume of the filler * density of steel + Volume of the filler * density of TNT
	Data.ProjMass		= math.max(GUIData.ProjVolume-PlayerData.Data5,0) * 7.9 / 1000 + math.min(PlayerData.Data5,GUIData.ProjVolume) * ACF.HEDensity / 1000
	Data.FragMass = math.max(Data.ProjMass - Data.FillerMass, 0)
	Data.MuzzleVel		= ACF_MuzzleVelocity( Data.PropMass, Data.ProjMass, Data.Caliber )
	local Energy			= ACF_Kinetic( Data.MuzzleVel * 39.37 , Data.ProjMass, Data.LimitVel )
	local MaxVol			= ACF_RoundShellCapacity( Energy.Momentum, Data.FrArea, Data.Caliber, Data.ProjLength )


	GUIData.ClusterMult = math.Clamp(PlayerData.Data13, 10, 100)
	Data.ClusterMult = GUIData.ClusterMult

	GUIData.FuseDistance = math.Clamp(PlayerData.Data14, 500, 6000)
	Data.FuseDistance = GUIData.FuseDistance

	GUIData.MinFillerVol	= 0
	GUIData.MaxFillerVol	= math.min(GUIData.ProjVolume,MaxVol)
	GUIData.FillerVol	= math.min(PlayerData.Data5,GUIData.MaxFillerVol)
	Data.FillerMass		= GUIData.FillerVol * ACF.HEDensity / 1000

	Data.ProjMass		= math.max(GUIData.ProjVolume-GUIData.FillerVol,0) * 7.9 / 1000 + Data.FillerMass
	Data.MuzzleVel		= ACF_MuzzleVelocity( Data.PropMass, Data.ProjMass, Data.Caliber )

	--Random bullshit left
	Data.ShovePower		= 0.1
	Data.PenArea			= Data.FrArea ^ ACF.PenAreaMod
	Data.DragCoef		= ((Data.FrArea / 10000) / Data.ProjMass)
	Data.LimitVel		= 100									-- Most efficient penetration speed in m/s
	Data.KETransfert		= 0.1									-- Kinetic energy transfert to the target for movement purposes
	Data.Ricochet		= 70										-- Base ricochet angle
	Data.DetonatorAngle	= 70

	Data.BoomPower		= Data.PropMass + Data.FillerMass

	if SERVER then --Only the crates need this part
		ServerData.Id	= PlayerData.Id
		ServerData.Type	= PlayerData.Type
		return table.Merge(Data,ServerData)
	end

	if CLIENT then --Only tthe GUI needs this part
		GUIData = table.Merge(GUIData, Round.getDisplayData(Data))
		return table.Merge(Data,GUIData)
	end

end


function Round.getDisplayData(Data)
	local GUIData = {}

	GUIData.FuseDistance = Data.FuseDistance

	-- number of bomblets (same as your server logic)
	GUIData.BombletCount = math.Round(math.Clamp(math.Round((Data.FillerMass or 0) * 2), 10, 160) * (Data.ClusterMult or 100) / 100)

	-- Per-bomblet filler and casing assumptions:
	-- Your cluster spawner sets ProjMass ~= parent.ProjMass / Bomblets / 2 for each bomblet.
	-- So for display, approximate per-bomblet projectile mass as parent.ProjMass / (Bomblets * 2).
	local bomblets = math.max(GUIData.BombletCount, 1)

	local fillerPer = (Data.FillerMass or 0) / bomblets
	local projPer   = (Data.ProjMass or 0) / bomblets / 2
	local casingPer = math.max(projPer - fillerPer, 0)

	GUIData.AdjFillerMass = fillerPer

	local HE = ACF_GetHEDisplayData(fillerPer, casingPer)

	GUIData.BlastRadius = HE.BlastRadius
	GUIData.Fragments = HE.Fragments
	GUIData.FragmentsUncapped = HE.FragmentsUncapped
	GUIData.FragMass = HE.FragMass
	GUIData.FragVel = HE.FragVel
	GUIData.FragArea = HE.FragArea
	GUIData.FragEffectiveRange = HE.FragEffectiveRange
	GUIData.FragRadius = HE.FragRadius

	return GUIData
end


function Round.network( Crate, BulletData )

	Crate:SetNWString( "AmmoType", "CHE" )
	Crate:SetNWString( "AmmoID", BulletData.Id )
	Crate:SetNWFloat( "Caliber", BulletData.Caliber )
	Crate:SetNWFloat( "ProjMass", BulletData.ProjMass )
	Crate:SetNWFloat( "FillerMass", BulletData.FillerMass )
	Crate:SetNWFloat( "PropMass", BulletData.PropMass )
	Crate:SetNWFloat( "DragCoef", BulletData.DragCoef )
	Crate:SetNWFloat( "MuzzleVel", BulletData.MuzzleVel )
	Crate:SetNWFloat( "Tracer", BulletData.Tracer )

		--For propper bullet model
	Crate:SetNWFloat( "BulletModel", Round.model )

end

function Round.cratetxt( BulletData )

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

function Round.propimpact( _, Bullet, Target, HitNormal, HitPos, Bone )

	if ACF_Check( Target ) then
		local Speed	= Bullet.Flight:Length() / ACF.VelScale
		local Energy	= ACF_Kinetic( Speed , Bullet.ProjMass - Bullet.FillerMass, Bullet.LimitVel )
		local HitRes	= ACF_RoundImpact( Bullet, Speed, Energy, Target, HitPos, HitNormal , Bone )

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

	--[[local WhiteList = {
		HE	= true,
		HEAT	= true,
	}]]--

	local function GenerateCluster(bdata)

		--local RoundType = bdata.Type

		--Make cluster to fail. Allow with rounds on whitelist only.
		--if not WhiteList[RoundType] then return end

		local Bomblets  = math.Round(math.Clamp(math.Round(bdata.FillerMass * 2),10,160) * (bdata.ClusterMult or 100) / 100)	--30 bomblets original

		local GEnt = bdata.Gun

		GEnt.BulletDataC = {}

		GEnt.BulletDataC.Bomblets = Bomblets

		GEnt.BulletDataC["Accel"]			= Vector(0,0,-600)
		GEnt.BulletDataC["BoomPower"]		= bdata.BoomPower

		GEnt.BulletDataC["Caliber"] 		= math.Clamp(bdata.Caliber / Bomblets * 30, 0.05, bdata.Caliber ) --Controls visual size, does nothing else
		GEnt.BulletDataC["Crate"]			= bdata.Crate
		GEnt.BulletDataC["DragCoef"]		= bdata.DragCoef / Bomblets / 2
		GEnt.BulletDataC["FillerMass"]	= bdata.FillerMass / Bomblets 	--nan armor ocurrs when this value is > 1
		GEnt.BulletDataC["FragMass"] = math.max(GEnt.BulletDataC["ProjMass"] - GEnt.BulletDataC["FillerMass"], 0)

		--print(GEnt.BulletDataC["FillerMass"])
		--print(Bomblets)
		--print(missile.BulletDataC["FillerMass"])

		GEnt.BulletDataC["Filter"]		= GEnt
		GEnt.BulletDataC["Flight"]		= bdata.Flight
		GEnt.BulletDataC["FlightTime"]	= 0
		GEnt.BulletDataC["FrArea"]		= bdata.FrArea
		GEnt.BulletDataC["FuseLength"]	= 0
		GEnt.BulletDataC["Gun"]			= GEnt
		GEnt.BulletDataC["Id"]			= bdata.Id
		GEnt.BulletDataC["KETransfert"]	= bdata.KETransfert
		GEnt.BulletDataC["LimitVel"]		= 700
		GEnt.BulletDataC["MuzzleVel"]		= 75
		--GEnt.BulletDataC["MuzzleVel"]		= bdata.MuzzleVel * 20
		GEnt.BulletDataC["Owner"]			= bdata.Owner
		GEnt.BulletDataC["PenArea"]		= bdata.PenArea
		GEnt.BulletDataC["Pos"]			= bdata.Pos
		GEnt.BulletDataC["ProjLength"]	= bdata.ProjLength / Bomblets / 2
		GEnt.BulletDataC["ProjMass"]		= bdata.ProjMass / Bomblets / 2
		GEnt.BulletDataC["PropLength"]	= bdata.PropLength
		GEnt.BulletDataC["PropMass"]		= bdata.PropMass
		GEnt.BulletDataC["Ricochet"]		= 90--bdata.Ricochet

		GEnt.BulletDataC["RoundVolume"]	= bdata.RoundVolume
		GEnt.BulletDataC["ShovePower"]	= bdata.ShovePower
		GEnt.BulletDataC["Tracer"]		= 0

		GEnt.BulletDataC["Type"]		= "HE"

		GEnt.FakeCrate = GEnt.FakeCrate or ents.Create("acf_fakecrate2")

		GEnt.FakeCrate:RegisterTo(GEnt.BulletDataC)
		GEnt.BulletDataC["Crate"] = GEnt.FakeCrate:EntIndex()

		GEnt:DeleteOnRemove(GEnt.FakeCrate)

	end

	local function CreateCluster(bullet)

		local GEnt = bullet.Gun

		local MuzzleVec = bullet.Flight:GetNormalized()
		local GunBData = GEnt.BulletDataC or {}
		local CCount = GunBData.Bomblets or 0

		for I = 1, CCount do
			--print("Bobm")
			timer.Simple(0.01 * I, function()
				if IsValid(GEnt) then
					--Spread = ((GEnt:GetUp() * (2 * math.random() - 1)) + (GEnt:GetRight() * (2 * math.random() - 1))) * (I - 1) / 45
					local Spread = VectorRand()
					--Spread = Spread
					--Spread = Vector(Spread.x * math.abs(Spread.x), Spread.y * math.abs(Spread.y), Spread.z * math.abs(Spread.z))
					--GEnt.BulletDataC["Flight"] = (MuzzleVec + ( Spread * math.min((GEnt.BulletDataC.Bomblets/10) * 0.1 , 0.65))):GetNormalized() * GEnt.BulletDataC["MuzzleVel"] * 39.37 * math.Rand(0.5,1.0)
					GEnt.BulletDataC["Flight"] = (MuzzleVec + ( Spread * 0.6)):GetNormalized() * GEnt.BulletDataC["MuzzleVel"] * 39.37 * math.Rand(0.5,1.0) --Fixed scatter pattern since we're using the detonate offset to control spread.

					local MuzzlePos = bullet.Pos
					GEnt.BulletDataC.Pos = MuzzlePos - MuzzleVec
					GEnt.CreateShell = ACF.RoundTypes[GEnt.BulletDataC.Type].create
					GEnt:CreateShell( GEnt.BulletDataC )

				end
			end)
		end

	end

	function Round.create( _, BulletData )

		ACF_CreateBullet( BulletData )

		GenerateCluster(BulletData)

	end

	function Round.onbulletflight( Index, Bullet )
		--Flight * Deltatime , + Bullet.Flight * DeltaTime * -30
		local tr = util.QuickTrace(Bullet.Pos, Bullet.Flight:GetNormalized() * (Bullet.FuseDistance or 2000), {})

		if tr.Hit and not (tr.HitSky or Bullet.SkyLvL) and Bullet.FlightTime > 0.5 then

			ACF_BulletClient( Index, Bullet, "Update" , 1 , Bullet.Pos  ) --Ends the bullet flight on the clientside

			--local ACF_HE_Math = Bullet.Pos - Bullet.Flight:GetNormalized() * 3, Bullet.Flight:GetNormalized(), Bullet.FillerMass / 20, Bullet.ProjMass - Bullet.FillerMass
			--ACF_HE(ACF_HE_Math, Bullet.Owner, nil, Bullet.Gun ) --Seperation airbursts. Fillermass reduced by 20 because it's the seperation charge.

			local sepFiller = (Bullet.FillerMass or 0) / 20
			-- Separation charge should have small fragmentation too.
			-- Use a small fraction of the shell casing (or even 0 if you want blast-only separation).
			local casing = math.max((Bullet.ProjMass or 0) - (Bullet.FillerMass or 0), 0)
			local sepFrag = casing * 0.05

			ACF_HE(Bullet.Pos - Bullet.Flight:GetNormalized() * 3, Bullet.Flight:GetNormalized(), sepFiller, sepFrag, Bullet.Owner, nil, Bullet.Gun)

			local GunEnt = Bullet.Gun
			if IsValid(GunEnt) then
				--print("Valid")
				CreateCluster(Bullet,GunEnt.BulletData) --(bullet, bdata)
			end
			ACF_RemoveBullet( Index )


		end


	end

	function Round.endflight( Index, Bullet)
		ACF_BulletClient( Index, Bullet, "Update" , 1 , Bullet.Pos  ) --Ends the bullet flight on the clientside

		local sepFiller = (Bullet.FillerMass or 0) / 20

		-- Separation charge should have small fragmentation too.
		-- Use a small fraction of the shell casing (or even 0 if you want blast-only separation).
		local casing = math.max((Bullet.ProjMass or 0) - (Bullet.FillerMass or 0), 0)
		local sepFrag = casing * 0.05

		ACF_HE(Bullet.Pos - Bullet.Flight:GetNormalized() * 3, Bullet.Flight:GetNormalized(), sepFiller, sepFrag, Bullet.Owner, nil, Bullet.Gun)
		
		local GunEnt = Bullet.Gun
		if IsValid(GunEnt) then
			--print("Valid")
			CreateCluster(Bullet,GunEnt.BulletData) --(bullet, bdata)
		end
		ACF_RemoveBullet( Index )
	end

end

function Round.endeffect( _, Bullet )

	local Radius = (Bullet.FillerMass / 20) ^ 0.33 * 8 * 39.37 --Fillermass reduced by 20 because it's the seperation charge.
	local Flash = EffectData()
		Flash:SetOrigin( Bullet.SimPos )
		Flash:SetNormal( Bullet.SimFlight:GetNormalized() )
		Flash:SetRadius( math.Round(math.max(Radius / 39.37, 1),2) )
	util.Effect( "ACF_Scaled_Explosion", Flash )

end

function Round.pierceeffect( _, Bullet )

	local BulletEffect = {}
		BulletEffect.Num	= 1
		BulletEffect.Src	= Bullet.SimPos - Bullet.SimFlight:GetNormalized()
		BulletEffect.Dir	= Bullet.SimFlight:GetNormalized()
		BulletEffect.Spread = Vector(0,0,0)
		BulletEffect.Tracer = 0
		BulletEffect.Force  = 0
		BulletEffect.Damage = 0
	LocalPlayer():FireBullets(BulletEffect)

	util.Decal("ExplosiveGunshot", Bullet.SimPos + Bullet.SimFlight * 10, Bullet.SimPos - Bullet.SimFlight * 10)

	local Spall = EffectData()
		Spall:SetOrigin( Bullet.SimPos )
		Spall:SetNormal( (Bullet.SimFlight):GetNormalized() )
		Spall:SetScale(math.max(((Bullet.RoundMass * (Bullet.SimFlight:Length() / 39.37) ^ 2) / 2000) / 10000, 1))
	util.Effect( "AP_Hit", Spall )

end

function Round.ricocheteffect( _, Bullet )

	local Spall = EffectData()
		Spall:SetEntity( Bullet.Crate )
		Spall:SetOrigin( Bullet.SimPos )
		Spall:SetNormal( Bullet.SimFlight:GetNormalized() )
		Spall:SetScale( Bullet.SimFlight:Length() )
		Spall:SetMagnitude( Bullet.RoundMass )
	util.Effect( "ACF_AP_Ricochet", Spall )

end

function Round.guicreate( Panel, Table )

	acfmenupanel:AmmoSelect(ACF.AmmoBlacklist.CHE)

	acfmenupanel:CPanelText("CrateInfoBold", "Crate information:", "DermaDefaultBold")

	acfmenupanel:CPanelText("BonusDisplay", "")

	acfmenupanel:CPanelText("Desc", "") --Description (Name, Desc)
	acfmenupanel:CPanelText("BoldAmmoStats", "Round information: ", "DermaDefaultBold")
	acfmenupanel:CPanelText("LengthDisplay", "")	--Total round length (Name, Desc)
	acfmenupanel:CPanelText("VelocityDisplay", "")  --Proj muzzle velocity (Name, Desc)

	acfmenupanel:AmmoSlider("PropLength",0,0,1000,3, "Propellant Length", "")	--Slider (Name, Value, Min, Max, Decimals, Title, Desc)
	acfmenupanel:AmmoSlider("ProjLength",0,0,1000,3, "Projectile Length", "")	--Slider (Name, Value, Min, Max, Decimals, Title, Desc)
	acfmenupanel:AmmoSlider("FillerVol",0,0,1000,3, "HE Filler", "")			--Slider (Name, Value, Min, Max, Decimals, Title, Desc)

	acfmenupanel:AmmoSlider("ClusterMult",0,0,100,1, "Cluster Multiplier (%)", "")
	acfmenupanel:AmmoSlider("FuseDistance",0,500,6000,2, "Cluster Fuse Distance", "")

	ACE_Checkboxes()

	acfmenupanel:CPanelText("BlastDisplay", "") --HE Blast data (Name, Desc)
	acfmenupanel:CPanelText("FragDisplay", "")  --HE Fragmentation data (Name, Desc)

	Round.guiupdate( Panel, Table )

end

function Round.guiupdate( Panel )

	local PlayerData = {}
		PlayerData.Id		= acfmenupanel.AmmoData.Data.id		--AmmoSelect GUI
		PlayerData.Type		= "CHE"									--Hardcoded, match as Round.Type instead
		PlayerData.PropLength	= acfmenupanel.AmmoData.PropLength  --PropLength slider
		PlayerData.ProjLength	= acfmenupanel.AmmoData.ProjLength  --ProjLength slider
		PlayerData.Data5		= acfmenupanel.AmmoData.FillerVol
		PlayerData.Data13		= acfmenupanel.AmmoData.ClusterMult
		PlayerData.Data14		= acfmenupanel.AmmoData.FuseDistance
		PlayerData.Tracer	= acfmenupanel.AmmoData.Tracer
		PlayerData.TwoPiece	= acfmenupanel.AmmoData.TwoPiece

	local Data = Round.convert( Panel, PlayerData )

	RunConsoleCommand( "acfmenu_data1", acfmenupanel.AmmoData.Data.id )
	RunConsoleCommand( "acfmenu_data2", PlayerData.Type )
	RunConsoleCommand( "acfmenu_data3", Data.PropLength )	--For Gun ammo, Data3 should always be Propellant
	RunConsoleCommand( "acfmenu_data4", Data.ProjLength )	--And Data4 total round mass
	RunConsoleCommand( "acfmenu_data5", Data.FillerVol )
	RunConsoleCommand( "acfmenu_data13", Data.ClusterMult )
	RunConsoleCommand( "acfmenu_data14", Data.FuseDistance )
	RunConsoleCommand( "acfmenu_data10", Data.Tracer )
	RunConsoleCommand( "acfmenu_data11", Data.TwoPiece )

	---------------------------Ammo Capacity-------------------------------------
	ACE_AmmoCapacityDisplay( Data )
	-------------------------------------------------------------------------------
	acfmenupanel:CPanelText("VelocityDisplay", "Muzzle Velocity : " .. math.floor(Data.MuzzleVel * ACF.VelScale) .. " m/s") --Proj muzzle velocity (Name, Desc)

	acfmenupanel:AmmoSlider("PropLength", Data.PropLength, Data.MinPropLength, Data.MaxTotalLength, 3, "Propellant Length", "Propellant Mass : " .. (math.floor(Data.PropMass * 1000)) .. " g" .. "/ " .. (math.Round(Data.PropMass, 1)) .. " kg" )  --Propellant Length Slider (Name, Min, Max, Decimals, Title, Desc)
	acfmenupanel:AmmoSlider("ProjLength", Data.ProjLength, Data.MinProjLength, Data.MaxTotalLength, 3, "Projectile Length", "Projectile Mass : " .. (math.floor(Data.ProjMass * 1000)) .. " g" .. "/ " .. (math.Round(Data.ProjMass, 1)) .. " kg")  --Projectile Length Slider (Name, Min, Max, Decimals, Title, Desc)	--Projectile Length Slider (Name, Min, Max, Decimals, Title, Desc)
	acfmenupanel:AmmoSlider("FillerVol",Data.FillerVol,Data.MinFillerVol,Data.MaxFillerVol,3, "HE Filler Volume", "HE Filler Mass : " .. (math.floor(Data.FillerMass * 1000)) .. " g")	--HE Filler Slider (Name, Min, Max, Decimals, Title, Desc)

	acfmenupanel:AmmoSlider("ClusterMult",Data.ClusterMult,10,100,1, "Cluster Multiplier (%)", "Bomblets: " .. Data.BombletCount)	--HE Filler Slider (Name, Min, Max, Decimals, Title, Desc)
	acfmenupanel:AmmoSlider("FuseDistance",Data.FuseDistance,500,6000,2, "Cluster Fuse Distance", "")	--HE Filler Slider (Name, Min, Max, Decimals, Title, Desc)

	ACE_Checkboxes( Data )

	acfmenupanel:CPanelText("Desc", ACF.RoundTypes[PlayerData.Type].desc) --Description (Name, Desc)
	acfmenupanel:CPanelText("LengthDisplay", "Round Length : " .. (math.floor((Data.PropLength + Data.ProjLength + (math.floor(Data.Tracer * 5) / 10)) * 100) / 100) .. "/" .. Data.MaxTotalLength .. " cm") --Total round length (Name, Desc)
	acfmenupanel:CPanelText("BlastDisplay", "Blast Radius : " .. (math.floor(Data.BlastRadius * 100) / 100) .. " m") --Proj muzzle velocity (Name, Desc)
	acfmenupanel:CPanelText("FragDisplay", "Fragments : " .. Data.Fragments .. "\n Average Fragment Weight : " .. (math.floor(Data.FragMass * 10000) / 10) .. " g \n Average Fragment Velocity : " .. math.floor(Data.FragVel) .. " m/s") --Proj muzzle penetration (Name, Desc)

	---------------------------Chance of Ricochet table----------------------------

	acfmenupanel:CPanelText("RicoDisplay", "Max Detonation angle: " .. Data.DetonatorAngle .. "°")

	-------------------------------------------------------------------------------
end

list.Set("SPECSRoundTypes", Round.Type, Round ) --Set the round on chemical folder
ACF.RoundTypes[Round.Type] = Round     --Set the round properties
ACF.IdRounds[Round.netid] = Round.Type --Index must equal the ID entry in the table above, Data must equal the index of the table above