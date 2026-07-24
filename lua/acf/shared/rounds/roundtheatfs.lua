
AddCSLuaFile()

ACE.AmmoBlacklist.THEATFS =  { "AC", "SA","C","MG", "AL","HMG" ,"RAC", "SC","ATR" , "MO" , "RM", "SL", "GL", "HW", "SC", "BOMB" , "GBU", "ASM", "AAM", "SAM", "UAR", "POD", "FFAR", "ATGM", "ARTY", "ECM", "FGL","NAV","mNAV" }

local Round = {}

Round.type = "Ammo" --Tells the spawn menu what entity to spawn
Round.name = "[THEAT-FS] - " .. ACE.Translation.THEATFS[1] --Human readable name
Round.model = "models/munitions/round_100mm_mortar_shot.mdl" --Shell flight model
Round.desc = ACE.Translation.THEATFS[2]
Round.netid = 19 --Unique ammotype ID for network transmission

Round.Type  = "THEATFS"

function Round.create( _, BulletData )

	ACE_CreateBullet( BulletData )

end

function Round.ConeCalc( ConeAngle, Radius )

	local CLen = math.tan(math.rad(ConeAngle)) * Radius
	local CArea = 3.1416 * Radius * (Radius ^ 2 + CLen ^ 2) ^ 0.5
	local CVol = (3.1416 * Radius ^ 2 * CLen) / 3

	return CLen, CArea, CVol

end

-- Function to convert the player's slider data into the complete round data
function Round.convert( _, PlayerData )

	local Data = {}
	local ServerData = {}
	local GUIData = {}

	PlayerData.PropLength	=  PlayerData.PropLength	or 0
	PlayerData.ProjLength	=  PlayerData.ProjLength	or 0
	PlayerData.Tracer	=  PlayerData.Tracer		or 0
	PlayerData.TwoPiece	=  PlayerData.TwoPiece	or 0
	PlayerData.Data5 = math.max(PlayerData.Data5 or 0, 0)
	if not PlayerData.Data6 then PlayerData.Data6 = 0 end
	if not PlayerData.Data13 then PlayerData.Data13 = 0 end
	if not PlayerData.Data14 then PlayerData.Data14 = 0 end

	PlayerData.Type = "THEATFS"

	PlayerData, Data, ServerData, GUIData = ACE_RoundBaseGunpowder( PlayerData, Data, ServerData, GUIData )

	local ConeThick = Data.Caliber / 50
	--local ConeLength = 0
	local ConeArea = 0
	--local ConeLength2 = 0
	local ConeArea2 = 0
	local AirVol = 0
	local AirVol2 = 0
	ConeLength, ConeArea, AirVol = Round.ConeCalc(PlayerData.Data6, Data.Caliber / 2, PlayerData.ProjLength)
	ConeLength2, ConeArea2, AirVol2 = Round.ConeCalc(PlayerData.Data13, Data.Caliber / 2, PlayerData.ProjLength)
	Data.ProjMass = math.max(GUIData.ProjVolume - PlayerData.Data5, 0) * 7.9 / 1000 + math.min(PlayerData.Data5, GUIData.ProjVolume) * ACE.HEDensity / 1000 + ConeArea * ConeThick * 7.9 / 1000 --Volume of the projectile as a cylinder - Volume of the filler - Volume of the crush cone * density of steel + Volume of the filler * density of TNT + Area of the cone * thickness * density of steel
	Data.MuzzleVel = ACE_MuzzleVelocity(Data.PropMass, Data.ProjMass, Data.Caliber)
	local Energy = ACE_Kinetic(Data.MuzzleVel * 39.37, Data.ProjMass, Data.LimitVel)

	local MaxVol = 0
	--local MaxLength = 0
	--local MaxRadius = 0
	MaxVol, MaxLength, MaxRadius = ACE_RoundShellCapacity( Energy.Momentum, Data.FrArea, Data.Caliber, Data.ProjLength )

	GUIData.MinConeAng = 0
	GUIData.MaxConeAng = math.deg(math.atan((Data.ProjLength - ConeThick) / (Data.Caliber / 2)))
	GUIData.ConeAng = math.Clamp(PlayerData.Data6 * 1, GUIData.MinConeAng, GUIData.MaxConeAng)
	GUIData.ConeAng2 = math.Clamp(PlayerData.Data13 * 1, GUIData.MinConeAng, GUIData.MaxConeAng)
	GUIData.HEAllocation = PlayerData.Data14
	ConeLength, ConeArea, AirVol = Round.ConeCalc(GUIData.ConeAng, Data.Caliber / 2, Data.ProjLength)
	ConeLength2, ConeArea2, AirVol2 = Round.ConeCalc(GUIData.ConeAng2, Data.Caliber / 2, Data.ProjLength)
	local ConeVol = ConeArea * ConeThick
	local ConeVol2 = ConeArea2 * ConeThick

	GUIData.MinFillerVol = 0
	GUIData.MaxFillerVol = math.max(MaxVol -  AirVol - ConeVol,GUIData.MinFillerVol) * 0.95
	GUIData.FillerVol = math.Clamp(PlayerData.Data5,GUIData.MinFillerVol,GUIData.MaxFillerVol)

	Data.FillerMass = GUIData.FillerVol * ACE.HEDensity / 1450
	Data.BoomFillerMass = Data.FillerMass / 3 --manually update function "pierceeffect" with the divisor
	Data.ProjMass = math.max(GUIData.ProjVolume - GUIData.FillerVol - AirVol - AirVol2 - ConeVol - ConeVol2, 0) * 7.9 / 1000 + Data.FillerMass + ConeVol * 7.9 / 1000 + ConeVol2 * 7.9 / 1000
	Data.MuzzleVel = ACE_MuzzleVelocity(Data.PropMass, Data.ProjMass, Data.Caliber)
	--local Energy = ACE_Kinetic(Data.MuzzleVel * 39.37, Data.ProjMass, Data.LimitVel)

	--Let's calculate the actual HEAT slug
	Data.SlugMass = ConeVol * 7.9 / 1000
	Data.SlugMass2 = ConeVol2 * 7.9 / 1000
	local Rad = math.rad(GUIData.ConeAng / 2)
	local Rad2 = math.rad(GUIData.ConeAng2 / 2)
	Data.SlugCaliber = Data.Caliber - Data.Caliber * (math.sin(Rad) * 0.5 + math.cos(Rad) * 1.5) / 2
	Data.SlugCaliber2 = Data.Caliber - Data.Caliber * (math.sin(Rad2) * 0.5 + math.cos(Rad2) * 1.5) / 2
	Data.HEAllocation = GUIData.HEAllocation
	Data.SlugMV = 2.1 * (Data.FillerMass / 2 * ACE.HEPower * (1 - Data.HEAllocation) * math.sin(math.rad(10 + GUIData.ConeAng) / 2) / Data.SlugMass) ^ ACE.HEATMVScaleTan --keep fillermass/2 so that penetrator stays the same
	Data.SlugMass = Data.SlugMass * 4 ^ 2
	Data.SlugMV = Data.SlugMV / 4
	Data.SlugMV2 = 2.1 * (Data.FillerMass / 2 * ACE.HEPower * Data.HEAllocation * math.sin(math.rad(10 + GUIData.ConeAng2) / 2) / Data.SlugMass2) ^ ACE.HEATMVScaleTan --keep fillermass/2 so that penetrator stays the same
	Data.SlugMass2 = Data.SlugMass2 * 4 ^ 2
	Data.SlugMV2 = Data.SlugMV2 / 4

	local SlugFrArea = 3.1416 * (Data.SlugCaliber / 2) ^ 2
	local SlugFrArea2 = 3.1416 * (Data.SlugCaliber2 / 2) ^ 2
	Data.SlugPenArea = SlugFrArea ^ ACE.PenAreaMod
	Data.SlugPenArea2 = SlugFrArea2 ^ ACE.PenAreaMod
	Data.SlugDragCoef = ((SlugFrArea / 10000) / Data.SlugMass)
	Data.SlugDragCoef2 = ((SlugFrArea2 / 10000) / Data.SlugMass2)
	Data.SlugRicochet = 500 --Base ricochet angle (The HEAT slug shouldn't ricochet at all)


	Data.CasingMass = Data.ProjMass - Data.FillerMass - ConeVol * 7.9 / 2000 - ConeVol2 * 7.9 / 2000

	--Random bullshit left
	Data.ShovePower = 0.1
	Data.PenArea = Data.FrArea ^ ACE.PenAreaMod
	Data.DragCoef = (Data.FrArea / 10000) / Data.ProjMass
	Data.LimitVel = 100 --Most efficient penetration speed in m/s
	Data.KETransfert = 0.1 --Kinetic energy transfert to the target for movement purposes
	Data.Ricochet = 64 --Base ricochet angle
	Data.DetonatorAngle = 85

	Data.Detonated = 0
	Data.HEATLastPos	= Vector(0,0,0)
	Data.NotFirstPen = false
	Data.BoomPower = Data.PropMass + Data.FillerMass

	if SERVER then --Only the crates need this part
		ServerData.Id = PlayerData.Id
		ServerData.Type = PlayerData.Type
		return table.Merge(Data,ServerData)
	end

	if CLIENT then --Only the GUI needs this part
		GUIData = table.Merge(GUIData, Round.getDisplayData(Data))
		return table.Merge(Data, GUIData)
	end

end

function Round.getDisplayData(Data)
	local GUIData = {}

	local SlugEnergy = ACE_Kinetic(Data.SlugMV * 39.37, Data.SlugMass, 999999)
	local SlugEnergy2 = ACE_Kinetic(Data.SlugMV2 * 39.37, Data.SlugMass2, 999999)
	GUIData.MaxPen = ACE_CalcPenetration(SlugEnergy, Data.SlugPenArea)
	GUIData.MaxPen2 = ACE_CalcPenetration(SlugEnergy2, Data.SlugPenArea2)
	--GUIData.BlastRadius = (Data.FillerMass/2) ^ 0.33 * 5*10
	GUIData.BlastRadius = Data.BoomFillerMass ^ 0.33 * 8 -- * 39.37
	GUIData.Fragments = math.max(math.floor((Data.BoomFillerMass / Data.CasingMass) * ACE.HEFrag), 2)
	GUIData.FragMass = Data.CasingMass / GUIData.Fragments
	GUIData.FragVel = (Data.BoomFillerMass * ACE.HEPower * 1000 / Data.CasingMass / GUIData.Fragments) ^ 0.5

	return GUIData
end

function Round.network( Crate, BulletData )

	Crate:SetNWString( "AmmoType", "THEATFS" )
	Crate:SetNWString( "AmmoID", BulletData.Id )
	Crate:SetNWFloat( "Caliber", BulletData.Caliber )
	Crate:SetNWFloat( "ProjMass", BulletData.ProjMass )
	Crate:SetNWFloat( "FillerMass", BulletData.FillerMass )
	Crate:SetNWFloat( "PropMass", BulletData.PropMass )
	Crate:SetNWFloat( "DragCoef", BulletData.DragCoef )
	Crate:SetNWFloat( "SlugMass", BulletData.SlugMass )
	Crate:SetNWFloat( "SlugCaliber", BulletData.SlugCaliber )
	Crate:SetNWFloat( "SlugDragCoef", BulletData.SlugDragCoef )
	Crate:SetNWFloat( "SlugMass2", BulletData.SlugMass2 )
	Crate:SetNWFloat( "SlugCaliber2", BulletData.SlugCaliber2 )
	Crate:SetNWFloat( "SlugDragCoef2", BulletData.SlugDragCoef2 )
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
		"Max Penetration(1st): ", math.floor(DData.MaxPen), " mm\n",
		"Max Penetration(2nd): ", math.floor(DData.MaxPen2), " mm\n",
		"Blast Radius: ", math.Round(DData.BlastRadius, 1), " m\n",
		"Blast Energy: ", math.floor(BulletData.BoomFillerMass * ACE.HEPower), " KJ"
	}

	return table.concat(str)

end

function Round.detonate( _, Bullet, HitPos, HitNormal )

	Bullet.Detonated = Bullet.Detonated + 1
	local DetCount = Bullet.Detonated or 0

	if DetCount == 1 then --First Detonation

		Bullet.NotFirstPen = false

		ACE_HE( HitPos - Bullet.Flight:GetNormalized() * 3, HitNormal, Bullet.BoomFillerMass * (1-Bullet.HEAllocation), Bullet.CasingMass, Bullet.Owner, nil, Bullet.Gun )

		Bullet.Pos			= HitPos
		Bullet.Flight		= Bullet.Flight:GetNormalized() * Bullet.SlugMV * 39.37
		Bullet.FlightTime	= 0 --reseting timer
		Bullet.FuseLength	= 0.1 + 10 / (Bullet.Flight:Length() * 0.0254)
		Bullet.DragCoef		= Bullet.SlugDragCoef

		Bullet.ProjMass		= Bullet.SlugMass
		Bullet.CannonCaliber	= Bullet.Caliber * 2
		Bullet.Caliber		= Bullet.SlugCaliber
		Bullet.PenArea		= Bullet.SlugPenArea
		Bullet.Ricochet		= Bullet.SlugRicochet

		local DeltaTime		= SysTime() - Bullet.LastThink
		Bullet.StartTrace	= Bullet.Pos - Bullet.Flight:GetNormalized() * math.min(ACE.PhysMaxVel * DeltaTime,Bullet.FlightTime * Bullet.Flight:Length() + 25)
		Bullet.NextPos		= Bullet.Pos + (Bullet.Flight * ACE.VelScale * DeltaTime)	--Calculates the next shell position
		Bullet.HEATLastPos = HitPos --Used to backtrack the HEAT's travel distance

	elseif DetCount == 2 then --Second Detonation

		Bullet.NotFirstPen = false

		ACE_HE( HitPos - Bullet.Flight:GetNormalized() * 3, HitNormal, Bullet.BoomFillerMass * Bullet.HEAllocation, Bullet.CasingMass, Bullet.Owner, nil, Bullet.Gun )

		Bullet.InitTime	= SysTime()
		Bullet.Pos		= HitPos
		Bullet.Flight	= Bullet.Flight:GetNormalized() * Bullet.SlugMV2 * 39.37
		Bullet.FlightTime	= 0 --reseting timer
		Bullet.FuseLength	= 0.1 + 10 / (Bullet.Flight:Length() * 0.0254)
		Bullet.DragCoef	= Bullet.SlugDragCoef2

		Bullet.ProjMass	= Bullet.SlugMass2
		Bullet.Caliber	= Bullet.SlugCaliber2
		Bullet.PenArea	= Bullet.SlugPenArea2
		Bullet.Ricochet	= Bullet.SlugRicochet

		local DeltaTime	= SysTime() - Bullet.LastThink
		Bullet.StartTrace	= Bullet.Pos - Bullet.Flight:GetNormalized() * (math.min(ACE.PhysMaxVel * DeltaTime,Bullet.FlightTime * Bullet.Flight:Length()) + 25)
		Bullet.NextPos	= Bullet.Pos + (Bullet.Flight * ACE.VelScale * DeltaTime)	--Calculates the next shell position
		Bullet.HEATLastPos = HitPos --Used to backtrack the HEAT's travel distance

	end
--  print(Bullet.Detonated)
end

function Round.propimpact( Index, Bullet, Target, HitNormal, HitPos, Bone )

	local DetCount = Bullet.Detonated or 0

	if ACE_Check( Target ) then

		if DetCount > 0 then --Bullet Has Detonated
			Bullet.NotFirstPen = true

			local distanceTraveled = (HitPos-Bullet.HEATLastPos):Length()
			Bullet.Flight = Bullet.Flight * (1-math.Min( ACE.HEATAirGapFactor * distanceTraveled / 39.37 ,0.99 ))
--			print("Meters Traveled: "..distanceTraveled/39.37)
--			print("Speed Reduction: "..(1-math.Min( ACE.HEATAirGapFactor * distanceTraveled / 39.37 ,0.99 )).."x") --

			local Speed = Bullet.Flight:Length() / ACE.VelScale
			local Energy = ACE_Kinetic( Speed , Bullet.ProjMass, 999999 )
			local HitRes = ACE_RoundImpact( Bullet, Speed, Energy, Target, HitPos, HitNormal , Bone )

			if HitRes.PostPenetration.Continue then

				table.insert( Bullet.Filter , Target )				--"Penetrate" (Ingoring the prop for the retry trace)

				ACE_Spall( HitPos , Bullet.Flight , Bullet.Filter , HitRes.PostPenetration.SpentKinetic + 0.2 , Bullet.CannonCaliber , Target.ACF.Armour , Bullet.Owner , Target.ACF.Material) --Do some spalling
				Bullet.Flight = Bullet.Flight:GetNormalized() * math.sqrt(HitRes.PostPenetration.RemainingKinetic * ((Bullet.NotFirstPen and ACE.HEATPenLayerMul) or 1) * 2000 / Bullet.ProjMass) * 39.37


				return "Penetrated"
			elseif DetCount == 1 then --If bullet has detonated once and fails to pen

				Round.detonate( Index, Bullet, HitPos, HitNormal )

				return "Penetrated"
			else

				return false
			end

		else

			--Linter :)
			--local Speed = Bullet.Flight:Length() / ACE.VelScale
			--local Energy = ACE_Kinetic( Speed , Bullet.ProjMass - Bullet.FillerMass, Bullet.LimitVel )
			--local HitRes = ACE_RoundImpact( Bullet, Speed, Energy, Target, HitPos, HitNormal , Bone )


			--Breaks effect hitnormal. Though HEAT failing to fuse is nice.
			--if HitRes.Ricochet then
			--	return "Ricochet"
			--else
				Round.detonate( Index, Bullet, HitPos, HitNormal )
				return "Penetrated"
			--end

		end
	else
		table.insert( Bullet.Filter , Target )
		return "Penetrated"
	end

	return false

end

function Round.worldimpact( Index, Bullet, HitPos, HitNormal )
	DetCount = Bullet.Detonated or 0
	if DetCount < 2 then
		Round.detonate( Index, Bullet, HitPos, HitNormal )
		return "Penetrated"
	end

	local Energy = ACE_Kinetic( Bullet.Flight:Length() / ACE.VelScale, Bullet.ProjMass, 999999 )
	local HitRes = ACE_PenetrateGround( Bullet, Energy, HitPos, HitNormal )
	if HitRes.Penetrated then
		return "Penetrated"
	--elseif HitRes.Ricochet then  --penetrator won't ricochet
	--  return "Ricochet"
	else
		return false
	end

end

function Round.endflight( Index )

	ACE_RemoveBullet( Index )

end

function Round.endeffect( _, Bullet )

	local Impact = EffectData()
		Impact:SetEntity( Bullet.Crate )
		Impact:SetOrigin( Bullet.SimPos )
		Impact:SetNormal( (Bullet.SimFlight):GetNormalized() )
		Impact:SetScale( Bullet.SimFlight:Length() )
		Impact:SetMagnitude( Bullet.RoundMass )
	util.Effect( "ACE_ap_impact", Impact )

end

function Round.pierceeffect( Effect, Bullet )
	DetCount = Bullet.Detonated or 0
	if DetCount > 0 then

		local Spall = EffectData()
			Spall:SetEntity( Bullet.Crate )
			Spall:SetOrigin( Bullet.SimPos )
			Spall:SetNormal( (Bullet.SimFlight):GetNormalized() )
			Spall:SetScale( Bullet.SimFlight:Length() )
			Spall:SetMagnitude( Bullet.RoundMass )
		util.Effect( "ACE_ap_penetration", Spall )

	else

		local Radius = (Bullet.FillerMass / 3) ^ 0.33 * 8 * 39.37 --fillermass/3 has to be manually set, as this func uses networked data
		local Flash = EffectData()
			Flash:SetOrigin( Bullet.SimPos )
			Flash:SetNormal( Bullet.SimFlight:GetNormalized() )
			Flash:SetRadius( math.Round(math.max(Radius / 39.37, 1),2) )
		util.Effect( "ACE_heat_explosion", Flash )

		Bullet.Detonated = 1
		Effect:SetModel("models/Gibs/wood_gib01e.mdl")

	end

end

function Round.ricocheteffect( _, Bullet )

	local Spall = EffectData()
		Spall:SetEntity( Bullet.Gun )
		Spall:SetOrigin( Bullet.SimPos )
		Spall:SetNormal( (Bullet.SimFlight):GetNormalized() )
		Spall:SetScale( Bullet.SimFlight:Length() )
		Spall:SetMagnitude( Bullet.RoundMass )
	util.Effect( "ACE_ap_ricochet", Spall )

end

function Round.guicreate( Panel, Table )

	acemenupanel:AmmoSelect( ACE.AmmoBlacklist.THEATFS )

	acemenupanel:CPanelText("CrateInfoBold", "Crate information:", "DermaDefaultBold")
	acemenupanel:CPanelText("BonusDisplay", "")

	acemenupanel:CPanelText("Desc", "") --Description (Name, Desc)
	acemenupanel:CPanelText("BoldAmmoStats", "Round information: ", "DermaDefaultBold")
	acemenupanel:CPanelText("LengthDisplay", "")	--Total round length (Name, Desc)

	--Slider (Name, Value, Min, Max, Decimals, Title, Desc)
	acemenupanel:AmmoSlider("PropLength",0,0,1000,3, "Propellant Length", "")
	acemenupanel:AmmoSlider("ProjLength",0,0,1000,3, "Projectile Length", "")
	acemenupanel:AmmoSlider("ConeAng",0,0,1000,3, "HEAT Cone Angle(1st)", "")
	acemenupanel:AmmoSlider("ConeAng2",0,0,1000,3, "HEAT Cone Angle(2nd)", "")
	acemenupanel:AmmoSlider("HEAllocation",0,0,1000,2, "HE Filler Allocation", "")
	acemenupanel:AmmoSlider("FillerVol",0,0,1000,3, "Total HEAT Warhead volume", "")

	ACE_Checkboxes()

	acemenupanel:CPanelText("VelocityDisplay", "")  --Proj muzzle velocity (Name, Desc)
	acemenupanel:CPanelText("BlastDisplay", "") --HE Blast data (Name, Desc)
	acemenupanel:CPanelText("FragDisplay", "")  --HE Fragmentation data (Name, Desc)

	--acemenupanel:CPanelText("RicoDisplay", "")	--estimated rico chance
	acemenupanel:CPanelText("SlugDisplay", "")  --HEAT Slug data (Name, Desc)
	acemenupanel:CPanelText("SlugDisplay2", "") --HEAT Slug data (Name, Desc)

	Round.guiupdate( Panel, Table )

end

function Round.guiupdate( Panel )

	local PlayerData = {}
		PlayerData.Id = acemenupanel.AmmoData.Data.id		--AmmoSelect GUI
		PlayerData.Type = "THEATFS"									--Hardcoded, match as Round.Type instead
		PlayerData.PropLength = acemenupanel.AmmoData.PropLength	--PropLength slider
		PlayerData.ProjLength = acemenupanel.AmmoData.ProjLength	--ProjLength slider
		PlayerData.Data5 = acemenupanel.AmmoData.FillerVol
		PlayerData.Data6 = acemenupanel.AmmoData.ConeAng
		PlayerData.Data13 = acemenupanel.AmmoData.ConeAng2
		PlayerData.Data14 = acemenupanel.AmmoData.HEAllocation
		PlayerData.Tracer	= acemenupanel.AmmoData.Tracer
		PlayerData.TwoPiece	= acemenupanel.AmmoData.TwoPiece

	local Data = Round.convert( Panel, PlayerData )

	RunConsoleCommand( "acemenu_data1", acemenupanel.AmmoData.Data.id )
	RunConsoleCommand( "acemenu_data2", PlayerData.Type )
	RunConsoleCommand( "acemenu_data3", Data.PropLength )	--For Gun ammo, Data3 should always be Propellant
	RunConsoleCommand( "acemenu_data4", Data.ProjLength )
	RunConsoleCommand( "acemenu_data5", Data.FillerVol )
	RunConsoleCommand( "acemenu_data6", Data.ConeAng )
	RunConsoleCommand( "acemenu_data13", Data.ConeAng2 )
	RunConsoleCommand( "acemenu_data14", Data.HEAllocation )
	RunConsoleCommand( "acemenu_data10", Data.Tracer )
	RunConsoleCommand( "acemenu_data11", Data.TwoPiece )

	---------------------------Ammo Capacity-------------------------------------
	ACE_AmmoCapacityDisplay( Data )
	-------------------------------------------------------------------------------
	acemenupanel:AmmoSlider("PropLength", Data.PropLength, Data.MinPropLength + (Data.Caliber * 3.9), Data.MaxTotalLength, 3, "Propellant Length", "Propellant Mass : " .. math.floor(Data.PropMass * 1000) .. " g") --Propellant Length Slider (Name, Min, Max, Decimals, Title, Desc)
	acemenupanel:AmmoSlider("ProjLength", Data.ProjLength, Data.MinProjLength, Data.MaxTotalLength, 3, "Projectile Length", "Projectile Mass : " .. math.floor(Data.ProjMass * 1000) .. " g") --Projectile Length Slider (Name, Min, Max, Decimals, Title, Desc)
	acemenupanel:AmmoSlider("ConeAng", Data.ConeAng, Data.MinConeAng, Data.MaxConeAng, 0, "Crush Cone Angle(1st)", "") --HE Filler Slider (Name, Min, Max, Decimals, Title, Desc)
	acemenupanel:AmmoSlider("ConeAng2", Data.ConeAng2, Data.MinConeAng, Data.MaxConeAng, 0, "Crush Cone Angle(2nd)", "") --HE Filler Slider (Name, Min, Max, Decimals, Title, Desc)
	acemenupanel:AmmoSlider("FillerVol", Data.FillerVol, Data.MinFillerVol, Data.MaxFillerVol, 3, "HE Filler Volume", "HE Filler Mass : " .. math.floor(Data.FillerMass * 1000) .. " g") --HE Filler Slider (Name, Min, Max, Decimals, Title, Desc)
	acemenupanel:AmmoSlider("HEAllocation", Data.HEAllocation, 0.05, 0.95, 2, "HE Filler Distribution", "HE Filler Ratio : " .. math.floor((1 - Data.HEAllocation) * 100) .. "% (1st), " .. math.floor(Data.HEAllocation * 100) .. "% (2nd)") --HE Filler Slider (Name, Min, Max, Decimals, Title, Desc)

	ACE_Checkboxes( Data )

	acemenupanel:CPanelText("Desc", ACE.RoundTypes[PlayerData.Type].desc) --Description (Name, Desc)
	acemenupanel:CPanelText("LengthDisplay", "Round Length : " .. (math.floor((Data.PropLength + Data.ProjLength + (math.floor(Data.Tracer * 5) / 10)) * 100) / 100) .. "/" .. Data.MaxTotalLength .. " cm") --Total round length (Name, Desc)
	acemenupanel:CPanelText("VelocityDisplay", "Muzzle Velocity : " .. math.floor(Data.MuzzleVel * ACE.VelScale) .. " m/s") --Proj muzzle velocity (Name, Desc)
	acemenupanel:CPanelText("BlastDisplay", "Blast Radius : " .. (math.floor(Data.BlastRadius * 100) / 100) .. " m") --Proj muzzle velocity (Name, Desc)
	acemenupanel:CPanelText("FragDisplay", "Fragments : " .. Data.Fragments .. "\n Average Fragment Weight : " .. (math.floor(Data.FragMass * 10000) / 10) .. " g \n Average Fragment Velocity : " .. math.floor(Data.FragVel) .. " m/s") --Proj muzzle penetration (Name, Desc)

	acemenupanel:CPanelText("SlugDisplay", "1st Penetrator \n Penetrator Mass : " .. (math.floor(Data.SlugMass * 10000) / 10) .. " g \n Penetrator Caliber : " .. (math.floor(Data.SlugCaliber * 100) / 10) .. " mm \n Penetrator Velocity : " .. math.floor(Data.SlugMV) .. " m/s \nMax Penetration: " .. math.floor(Data.MaxPen) .. " mm \n\n 2nd Penetrator \n Penetrator Mass : " .. (math.floor(Data.SlugMass2 * 10000) / 10) .. " g \n Penetrator Caliber : " .. (math.floor(Data.SlugCaliber2 * 100) / 10) .. " mm \n Penetrator Velocity : " .. math.floor(Data.SlugMV2) .. " m/s \n Max Penetration : " .. math.floor(Data.MaxPen2) .. " mm \n") --Proj muzzle penetration (Name, Desc)
end

list.Set("HERoundTypes", "THEATFS", Round )

ACE.RoundTypes[Round.Type] = Round     --Set the round properties
ACE.IdRounds[Round.netid] = Round.Type --Index must equal the ID entry in the table above, Data must equal the index of the table above
