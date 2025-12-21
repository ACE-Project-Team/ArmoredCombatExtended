
AddCSLuaFile()

ACF.AmmoBlacklist.THEAT = { "MG", "HMG", "RAC", "SL", "ECM", "ATR" , "AC" , "SA" , "GL","AAM","SAM", "FGL"}

local Round = {}

Round.type  = "Ammo" --Tells the spawn menu what entity to spawn
Round.name  = "[THEAT] - " .. ACFTranslation.THEAT[1] --Human readable name
Round.model = "models/munitions/round_100mm_shot.mdl" --Shell flight model
Round.desc  = ACFTranslation.THEAT[2]
Round.netid = 15 --Unique ammotype ID for network transmission

Round.Type  = "THEAT"

function Round.create( _, BulletData )

	ACF_CreateBullet( BulletData )

end

function Round.ConeCalc( ConeAngle, Radius )

	local CLen = math.tan(math.rad(ConeAngle)) * Radius
	local CArea = 3.1416 * Radius * (Radius ^ 2 + CLen ^ 2) ^ 0.5
	local CVol = (3.1416 * Radius ^ 2 * CLen) / 3

	return CLen, CArea, CVol

end

-- Function to convert the player's slider data into the complete round data
function Round.convert( _, PlayerData )

	local Data		= {}
	local ServerData	= {}
	local GUIData	= {}

	PlayerData.PropLength	=  PlayerData.PropLength	or 0
	PlayerData.ProjLength	=  PlayerData.ProjLength	or 0
	PlayerData.Tracer	=  PlayerData.Tracer		or 0
	PlayerData.TwoPiece	=  PlayerData.TwoPiece	or 0
	PlayerData.Data5 = math.max(PlayerData.Data5 or 0, 0)
	if not PlayerData.Data6 then PlayerData.Data6 = 0 end
	if not PlayerData.Data13 then PlayerData.Data13 = 0 end
	if not PlayerData.Data14 then PlayerData.Data14 = 0 end

	PlayerData, Data, ServerData, GUIData = ACF_RoundBaseGunpowder( PlayerData, Data, ServerData, GUIData )

	local ConeThick = Data.Caliber / 50
	--local ConeLength = 0
	local ConeArea = 0
	--local ConeLength2 = 0
	local ConeArea2 = 0
	local AirVol = 0
	local AirVol2 = 0

	ConeLength, ConeArea, AirVol	= Round.ConeCalc( PlayerData.Data6, Data.Caliber / 2, PlayerData.ProjLength )
	ConeLength2, ConeArea2, AirVol2 = Round.ConeCalc( PlayerData.Data13, Data.Caliber / 2, PlayerData.ProjLength )

	Data.ProjMass		= math.max(GUIData.ProjVolume-PlayerData.Data5,0) * 7.9 / 1000 + math.min(PlayerData.Data5,GUIData.ProjVolume) * ACF.HEDensity / 1000 + ConeArea * ConeThick * 7.9 / 1000 --Volume of the projectile as a cylinder - Volume of the filler - Volume of the crush cone * density of steel + Volume of the filler * density of TNT + Area of the cone * thickness * density of steel
	Data.MuzzleVel		= ACF_MuzzleVelocity( Data.PropMass, Data.ProjMass, Data.Caliber )

	local Energy			= ACF_Kinetic( Data.MuzzleVel * 39.37 , Data.ProjMass, Data.LimitVel )
	local MaxVol			= 0
	--local MaxLength		= 0
	--local MaxRadius		= 0

	MaxVol, MaxLength, MaxRadius = ACF_RoundShellCapacity( Energy.Momentum, Data.FrArea, Data.Caliber, Data.ProjLength )

	GUIData.MinConeAng	= 0
	GUIData.MaxConeAng = math.deg(math.atan((Data.ProjLength - ConeThick) / (Data.Caliber / 2)))

	GUIData.ConeAng = math.Clamp(PlayerData.Data6 * 1, GUIData.MinConeAng, GUIData.MaxConeAng)
	GUIData.ConeAng2 = math.Clamp(PlayerData.Data13 * 1, GUIData.MinConeAng, GUIData.MaxConeAng)

	GUIData.HEAllocation	= PlayerData.Data14

	ConeLength, ConeArea, AirVol = Round.ConeCalc(GUIData.ConeAng, Data.Caliber / 2, Data.ProjLength)
	ConeLength2, ConeArea2, AirVol2 = Round.ConeCalc(GUIData.ConeAng2, Data.Caliber / 2, Data.ProjLength)

	local ConeVol		= ConeArea * ConeThick
	local ConeVol2		= ConeArea2 * ConeThick

	GUIData.MinFillerVol	= 0
	GUIData.MaxFillerVol	= math.max(MaxVol -  AirVol - ConeVol,GUIData.MinFillerVol)
	GUIData.FillerVol	= math.Clamp(PlayerData.Data5 * 1,GUIData.MinFillerVol,GUIData.MaxFillerVol)

	Data.FillerMass = GUIData.FillerVol * ACF.HEDensity / 1450
	Data.BoomFillerMass = Data.FillerMass / 3 --manually update function "pierceeffect" with the divisor
	Data.ProjMass = math.max(GUIData.ProjVolume - GUIData.FillerVol - AirVol - AirVol2 - ConeVol - ConeVol2, 0) * 7.9 / 1000 + Data.FillerMass + ConeVol * 7.9 / 1000 + ConeVol2 * 7.9 / 1000
	Data.MuzzleVel = ACF_MuzzleVelocity(Data.PropMass, Data.ProjMass, Data.Caliber)
	--local Energy = ACF_Kinetic(Data.MuzzleVel * 39.37, Data.ProjMass, Data.LimitVel)

	--Let's calculate the actual HEAT slug
	Data.SlugMass		= ConeVol * 7.9 / 1000
	Data.SlugMass2		= ConeVol2 * 7.9 / 1000

	local Rad			= math.rad(GUIData.ConeAng / 2)
	local Rad2			= math.rad(GUIData.ConeAng2 / 2)

	Data.SlugCaliber		= Data.Caliber - Data.Caliber * (math.sin(Rad) * 0.5 + math.cos(Rad) * 1.5) / 2
	Data.SlugCaliber2	= Data.Caliber - Data.Caliber * (math.sin(Rad2) * 0.5 + math.cos(Rad2) * 1.5) / 2

	Data.HEAllocation	= GUIData.HEAllocation

	Data.SlugMV = 1.15 * (Data.FillerMass / 2 * ACF.HEPower * (1 - Data.HEAllocation) * math.sin(math.rad(10 + GUIData.ConeAng) / 2) / Data.SlugMass) ^ ACF.HEATMVScaleTan --keep fillermass/2 so that penetrator stays the same
	Data.SlugMass = Data.SlugMass * 4 ^ 2
	Data.SlugMV = Data.SlugMV / 4

	Data.SlugMV2 = 1.15 * (Data.FillerMass / 2 * ACF.HEPower * Data.HEAllocation * math.sin(math.rad(10 + GUIData.ConeAng2) / 2) / Data.SlugMass2) ^ ACF.HEATMVScaleTan --keep fillermass/2 so that penetrator stays the same
	Data.SlugMass2 = Data.SlugMass2 * 4 ^ 2
	Data.SlugMV2 = Data.SlugMV2 / 4

	local SlugFrArea = 3.1416 * (Data.SlugCaliber / 2) ^ 2
	local SlugFrArea2 = 3.1416 * (Data.SlugCaliber2 / 2) ^ 2

	Data.SlugPenArea = SlugFrArea ^ ACF.PenAreaMod
	Data.SlugPenArea2 = SlugFrArea2 ^ ACF.PenAreaMod

	Data.SlugDragCoef = ((SlugFrArea / 10000) / Data.SlugMass)
	Data.SlugDragCoef2 = ((SlugFrArea2 / 10000) / Data.SlugMass2)

	Data.SlugRicochet	=	500									-- Base ricochet angle (The HEAT slug shouldn't ricochet at all)


	Data.CasingMass = Data.ProjMass - Data.FillerMass - ConeVol * 7.9 / 2000 - ConeVol2 * 7.9 / 2000
	Data.FragMass = math.max(Data.CasingMass, 0)

	--Random bullshit left
	Data.ShovePower = 0.1
	Data.PenArea = Data.FrArea ^ ACF.PenAreaMod
	Data.DragCoef = (Data.FrArea / 10000) / Data.ProjMass
	Data.LimitVel = 100 -- Most efficient penetration speed in m/s
	Data.KETransfert = 0.1 -- Kinetic energy transfert to the target for movement purposes
	Data.Ricochet = 63 -- Base ricochet angle
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

	local SlugEnergy  = ACF_Kinetic(Data.SlugMV  * 39.37, Data.SlugMass,  999999)
	local SlugEnergy2 = ACF_Kinetic(Data.SlugMV2 * 39.37, Data.SlugMass2, 999999)

	GUIData.MaxPen  = (SlugEnergy.Penetration  / Data.SlugPenArea)  * ACF.KEtoRHA
	GUIData.MaxPen2 = (SlugEnergy2.Penetration / Data.SlugPenArea2) * ACF.KEtoRHA

	local filler = tonumber(Data.BoomFillerMass) or ((tonumber(Data.FillerMass) or 0) / 3)
	local casing = tonumber(Data.FragMass) or tonumber(Data.CasingMass) or 0

	local HE = ACF_GetHEDisplayData(filler, casing)

	GUIData.BlastRadius = HE.BlastRadius
	GUIData.Fragments = HE.Fragments
	GUIData.FragmentsUncapped = HE.FragmentsUncapped
	GUIData.FragMass = HE.FragMass
	GUIData.FragVel = HE.FragVel
	GUIData.FragArea = HE.FragArea

	return GUIData
end

function Round.network( Crate, BulletData )

	Crate:SetNWString( "AmmoType", "THEAT" )
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
		"Blast Energy: ", math.floor(BulletData.BoomFillerMass * ACF.HEPower), " KJ"
	}

	return table.concat(str)

end

function Round.detonate( _, Bullet, HitPos, HitNormal )

	--print("Called function detonate during DetCount: " .. Bullet.Detonated )

	Bullet.Detonated	= (Bullet.Detonated or 0) + 1

	local DetCount	= Bullet.Detonated

	--First Detonation
	if DetCount == 1 then
		--print("1ST CHARGE")

		Bullet.NotFirstPen = false

		local casing = tonumber(Bullet.FragMass) or tonumber(Bullet.CasingMass) or 0
		ACF_HE(HitPos - Bullet.Flight:GetNormalized() * 3, HitNormal, Bullet.BoomFillerMass * (1 - Bullet.HEAllocation), casing, Bullet.Owner, nil, Bullet.Gun)

		Bullet.InitTime         = SysTime()
		Bullet.FlightTime       = 0 --reseting timer
		Bullet.FuseLength       = 0.005 + 40 / ((Bullet.Flight + Bullet.Flight:GetNormalized() * Bullet.SlugMV * 39.37):Length() * 0.0254)
		Bullet.Pos              = HitPos
		Bullet.Flight           = Bullet.Flight:GetNormalized() * Bullet.SlugMV * 39.37
		Bullet.DragCoef         = Bullet.SlugDragCoef

		Bullet.ProjMass         = Bullet.SlugMass
		Bullet.CannonCaliber    = Bullet.Caliber * 2
		Bullet.Caliber          = Bullet.SlugCaliber
		Bullet.PenArea          = Bullet.SlugPenArea
		Bullet.Ricochet         = Bullet.SlugRicochet

		local DeltaTime         = SysTime() - Bullet.LastThink
		Bullet.StartTrace       = Bullet.Pos - Bullet.Flight:GetNormalized() * math.min(ACF.PhysMaxVel * DeltaTime,Bullet.FlightTime * Bullet.Flight:Length())
		Bullet.NextPos          = Bullet.Pos + (Bullet.Flight * ACF.VelScale * DeltaTime)	--Calculates the next shell position
		Bullet.HEATLastPos = HitPos --Used to backtrack the HEAT's travel distance

	--Second Detonation
	elseif DetCount == 2 then
		--print("2ND CHARGE")

		Bullet.NotFirstPen = false

		local casing = tonumber(Bullet.FragMass) or tonumber(Bullet.CasingMass) or 0
		ACF_HE(HitPos - Bullet.Flight:GetNormalized() * 3, HitNormal, Bullet.BoomFillerMass * Bullet.HEAllocation, casing, Bullet.Owner, nil, Bullet.Gun)
		
		Bullet.InitTime		= SysTime()
		Bullet.FlightTime	= 0 --reseting timer
		Bullet.FuseLength	= 0.005 + 40 / ((Bullet.Flight:GetNormalized() * Bullet.SlugMV2 * 39.37):Length() * 0.0254)
		Bullet.Pos			= HitPos
		Bullet.Flight		= Bullet.Flight:GetNormalized() * Bullet.SlugMV2 * 39.37
		Bullet.DragCoef		= Bullet.SlugDragCoef2

		Bullet.ProjMass		= Bullet.SlugMass2
		Bullet.Caliber		= Bullet.SlugCaliber2
		Bullet.PenArea		= Bullet.SlugPenArea2
		Bullet.Ricochet		= Bullet.SlugRicochet

		local DeltaTime		= SysTime() - Bullet.LastThink
		Bullet.StartTrace	= Bullet.Pos - Bullet.Flight:GetNormalized() * math.min(ACF.PhysMaxVel * DeltaTime,Bullet.FlightTime * Bullet.Flight:Length())
		Bullet.NextPos		= Bullet.Pos + (Bullet.Flight * ACF.VelScale * DeltaTime)	--Calculates the next shell position
		Bullet.HEATLastPos = HitPos --Used to backtrack the HEAT's travel distance

	end
--  print(Bullet.Detonated)
end

--TODO: Make shell fire both tandem charges at once.
--BUG: 2nd charge trace doesnt return a valid HitNormal res, which makes impacted prop returns an infinite effective armor. Not always happens but its possible.
function Round.propimpact( Index, Bullet, Target, HitNormal, HitPos, Bone )

	-- DetCount = 0 -- the bullet has impacted something, it still doesnt detonate. Here checks if it should ricochet or detonate.
	-- DetCount = 1 -- the bullet has detonated and has penetrated the next layers. If fails to, a 2nd charge is called.
	-- DetCount = 2 -- the bullet has detonated its 2nd charge. The last one of this round.

	local DetCount = Bullet.Detonated or 0

	--print("THEAT DID HIT\n DetCount: " .. DetCount)
	--print("Hit Target: " .. (Target:GetClass()) )
	--print("ENTIndex: " .. Target:EntIndex())

	--2nd charge should always appear in the same place as 1st charge
	if Bullet.FirstPos then HitPos = Bullet.FirstPos end

	if ACF_Check( Target ) then

		if DetCount > 0 then --Bullet Has Detonated
			Bullet.NotFirstPen = true

			local distanceTraveled = (HitPos-Bullet.HEATLastPos):Length()
			Bullet.Flight = Bullet.Flight * (1-math.Min( ACF.HEATAirGapFactor * distanceTraveled / 39.37 ,0.99 ))
--			print("Meters Traveled: "..distanceTraveled/39.37)
--			print("Speed Reduction: "..(1-math.Min( ACF.HEATAirGapFactor * distanceTraveled / 39.37 ,0.99 )).."x") --

			local Speed	= Bullet.Flight:Length() / ACF.VelScale
			local Energy	= ACF_Kinetic( Speed , Bullet.ProjMass, 999999 )
			local HitRes	= ACF_RoundImpact( Bullet, Speed, Energy, Target, HitPos, HitNormal , Bone )

			if HitRes.Overkill > 0 then

				table.insert( Bullet.Filter , Target )				--"Penetrate" (Ingoring the prop for the retry trace)
				ACF_Spall( HitPos , Bullet.Flight , Bullet.Filter , Energy.Kinetic * HitRes.Loss + 0.2 , Bullet.CannonCaliber , Target.ACF.Armour , Bullet.Owner , Target.ACF.Material) --Do some spalling
				Bullet.Flight = Bullet.Flight:GetNormalized() * math.sqrt(Energy.Kinetic * (1 - HitRes.Loss) * ((Bullet.NotFirstPen and ACF.HEATPenLayerMul) or 1) * 2000 / Bullet.ProjMass) * 39.37

				return "Penetrated"

			--If bullet has detonated once and fails to pen
			elseif DetCount == 1 then

				Bullet.Filter = {}
				Round.detonate( Index, Bullet, HitPos, HitNormal )

				return "Penetrated"

			else

				return false
			end

		else

			--Linter :)
			--local Speed	= Bullet.Flight:Length() / ACF.VelScale
			--local Energy	= ACF_Kinetic( Speed , Bullet.ProjMass - Bullet.FillerMass, Bullet.LimitVel )
			--local HitRes	= ACF_RoundImpact( Bullet, Speed, Energy, Target, HitPos, HitNormal , Bone )


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
	local DetCount = Bullet.Detonated or 0

	if DetCount < 2 then
		Round.detonate( Index, Bullet, HitPos, HitNormal )
		return "Penetrated"
	end

	local Energy = ACF_Kinetic( Bullet.Flight:Length() / ACF.VelScale, Bullet.ProjMass, 999999 )
	local HitRes = ACF_PenetrateGround( Bullet, Energy, HitPos, HitNormal )
	if HitRes.Penetrated then
		return "Penetrated"
	else
		return false
	end

end

function Round.endflight( Index, Bullet, HitPos, HitNormal )
	local DetCount = Bullet.Detonated or 0

	--print("endflight during DetCount: " .. DetCount)

	if DetCount == 1 then
		--print("endflight during 1st charge, detonating 2nd charge")
		Round.detonate( Index, Bullet, HitPos, HitNormal )
		return
	end

	ACF_RemoveBullet( Index )

end

function Round.endeffect( _, Bullet )

	local Impact = EffectData()
		Impact:SetEntity( Bullet.Crate )
		Impact:SetOrigin( Bullet.SimPos )
		Impact:SetNormal( (Bullet.SimFlight):GetNormalized() )
		Impact:SetScale( Bullet.SimFlight:Length() )
		Impact:SetMagnitude( Bullet.RoundMass )
	util.Effect( "acf_ap_impact", Impact )

end

function Round.pierceeffect( Effect, Bullet )
	local DetCount = Bullet.Detonated or 0
	if DetCount > 0 then

		local Spall = EffectData()
			Spall:SetEntity( Bullet.Crate )
			Spall:SetOrigin( Bullet.SimPos )
			Spall:SetNormal( (Bullet.SimFlight):GetNormalized() )
			Spall:SetScale( Bullet.SimFlight:Length() )
			Spall:SetMagnitude( Bullet.RoundMass )
		util.Effect( "acf_ap_penetration", Spall )

	else

		local Radius = (Bullet.FillerMass / 3) ^ 0.33 * 8 * 39.37 --fillermass/3 has to be manually set, as this func uses networked data
		local Flash = EffectData()
			Flash:SetOrigin( Bullet.SimPos )
			Flash:SetNormal( Bullet.SimFlight:GetNormalized() )
			Flash:SetRadius( math.Round(math.max(Radius / 39.37, 1),2) )
		util.Effect( "acf_heat_explosion", Flash )

		Bullet.Detonated = 1
		Effect:SetModel("models/Gibs/wood_gib01e.mdl")

		Round.pierceeffect( Effect, Bullet )
	end

end

function Round.ricocheteffect( _, Bullet )

	local Spall = EffectData()
		Spall:SetEntity( Bullet.Gun )
		Spall:SetOrigin( Bullet.SimPos )
		Spall:SetNormal( (Bullet.SimFlight):GetNormalized() )
		Spall:SetScale( Bullet.SimFlight:Length() )
		Spall:SetMagnitude( Bullet.RoundMass )
	util.Effect( "acf_ap_ricochet", Spall )

end

function Round.guicreate( Panel, Table )

	acfmenupanel:AmmoSelect( ACF.AmmoBlacklist.THEAT )

	acfmenupanel:CPanelText("CrateInfoBold", "Crate information:", "DermaDefaultBold")

	acfmenupanel:CPanelText("BonusDisplay", "")

	acfmenupanel:CPanelText("Desc", "") --Description (Name, Desc)
	acfmenupanel:CPanelText("BoldAmmoStats", "Round information: ", "DermaDefaultBold")
	acfmenupanel:CPanelText("LengthDisplay", "")	--Total round length (Name, Desc)

	--Slider (Name, Value, Min, Max, Decimals, Title, Desc)
	acfmenupanel:AmmoSlider("PropLength",0,0,1000,3, "Propellant Length", "")
	acfmenupanel:AmmoSlider("ProjLength",0,0,1000,3, "Projectile Length", "")
	acfmenupanel:AmmoSlider("ConeAng",0,0,1000,3, "HEAT Cone Angle(1st)", "")
	acfmenupanel:AmmoSlider("ConeAng2",0,0,1000,3, "HEAT Cone Angle(2nd)", "")
	acfmenupanel:AmmoSlider("HEAllocation",0,0,1000,2, "HE Filler Allocation", "")
	acfmenupanel:AmmoSlider("FillerVol",0,0,1000,3, "Total HEAT Warhead volume", "")

	ACE_Checkboxes()

	acfmenupanel:CPanelText("VelocityDisplay", "")  --Proj muzzle velocity (Name, Desc)
	acfmenupanel:CPanelText("BlastDisplay", "") --HE Blast data (Name, Desc)
	acfmenupanel:CPanelText("FragDisplay", "")  --HE Fragmentation data (Name, Desc)

	--acfmenupanel:CPanelText("RicoDisplay", "")	--estimated rico chance
	acfmenupanel:CPanelText("SlugDisplay", "")  --HEAT Slug data (Name, Desc)
	acfmenupanel:CPanelText("SlugDisplay2", "") --HEAT Slug data (Name, Desc)

	Round.guiupdate( Panel, Table )

end

function Round.guiupdate( Panel )

	local PlayerData = {}
		PlayerData.Id = acfmenupanel.AmmoData.Data.id		--AmmoSelect GUI
		PlayerData.Type = "THEAT"									--Hardcoded, match as Round.Type instead
		PlayerData.PropLength = acfmenupanel.AmmoData.PropLength	--PropLength slider
		PlayerData.ProjLength = acfmenupanel.AmmoData.ProjLength	--ProjLength slider
		PlayerData.Data5 = acfmenupanel.AmmoData.FillerVol
		PlayerData.Data6 = acfmenupanel.AmmoData.ConeAng
		PlayerData.Data13 = acfmenupanel.AmmoData.ConeAng2
		PlayerData.Data14 = acfmenupanel.AmmoData.HEAllocation
		PlayerData.Tracer	= acfmenupanel.AmmoData.Tracer
		PlayerData.TwoPiece	= acfmenupanel.AmmoData.TwoPiece

	local Data = Round.convert( Panel, PlayerData )

	RunConsoleCommand( "acfmenu_data1", acfmenupanel.AmmoData.Data.id )
	RunConsoleCommand( "acfmenu_data2", PlayerData.Type )
	RunConsoleCommand( "acfmenu_data3", Data.PropLength )	--For Gun ammo, Data3 should always be Propellant
	RunConsoleCommand( "acfmenu_data4", Data.ProjLength )
	RunConsoleCommand( "acfmenu_data5", Data.FillerVol )
	RunConsoleCommand( "acfmenu_data6", Data.ConeAng )
	RunConsoleCommand( "acfmenu_data13", Data.ConeAng2 )
	RunConsoleCommand( "acfmenu_data14", Data.HEAllocation )
	RunConsoleCommand( "acfmenu_data10", Data.Tracer )
	RunConsoleCommand( "acfmenu_data11", Data.TwoPiece )

	---------------------------Ammo Capacity-------------------------------------
	ACE_AmmoCapacityDisplay( Data )
	-------------------------------------------------------------------------------
	acfmenupanel:AmmoSlider("PropLength", Data.PropLength, Data.MinPropLength, Data.MaxTotalLength, 3, "Propellant Length", "Propellant Mass : " .. math.floor(Data.PropMass * 1000) .. " g" .. "/ " .. math.Round(Data.PropMass, 1) .. " kg") --Propellant Length Slider (Name, Min, Max, Decimals, Title, Desc)
	acfmenupanel:AmmoSlider("ProjLength", Data.ProjLength, Data.MinProjLength, Data.MaxTotalLength, 3, "Projectile Length", "Projectile Mass : " .. math.floor(Data.ProjMass * 1000) .. " g" .. "/ " .. math.Round(Data.ProjMass, 1) .. " kg") --Projectile Length Slider (Name, Min, Max, Decimals, Title, Desc)	--Projectile Length Slider (Name, Min, Max, Decimals, Title, Desc)
	acfmenupanel:AmmoSlider("ConeAng", Data.ConeAng, Data.MinConeAng, Data.MaxConeAng, 0, "Crush Cone Angle(1st)", "") --HE Filler Slider (Name, Min, Max, Decimals, Title, Desc)
	acfmenupanel:AmmoSlider("ConeAng2", Data.ConeAng2, Data.MinConeAng, Data.MaxConeAng, 0, "Crush Cone Angle(2nd)", "") --HE Filler Slider (Name, Min, Max, Decimals, Title, Desc)
	acfmenupanel:AmmoSlider("FillerVol", Data.FillerVol, Data.MinFillerVol, Data.MaxFillerVol, 3, "HE Filler Volume", "HE Filler Mass : " .. math.floor(Data.FillerMass * 1000) .. " g") --HE Filler Slider (Name, Min, Max, Decimals, Title, Desc)
	acfmenupanel:AmmoSlider("HEAllocation", Data.HEAllocation, 0.05, 0.95, 2, "HE Filler Distribution", "HE Filler Ratio : " .. math.floor((1 - Data.HEAllocation) * 100) .. "% (1st), " .. math.floor(Data.HEAllocation * 100) .. "% (2nd)") --HE Filler Slider (Name, Min, Max, Decimals, Title, Desc)

	ACE_Checkboxes( Data )

	acfmenupanel:CPanelText("Desc", ACF.RoundTypes[PlayerData.Type].desc) --Description (Name, Desc)
	acfmenupanel:CPanelText("LengthDisplay", "Round Length : " .. (math.floor((Data.PropLength + Data.ProjLength + (math.floor(Data.Tracer * 5) / 10)) * 100) / 100) .. "/" .. Data.MaxTotalLength .. " cm") --Total round length (Name, Desc)
	acfmenupanel:CPanelText("VelocityDisplay", "Muzzle Velocity : " .. math.floor(Data.MuzzleVel * ACF.VelScale) .. " m/s") --Proj muzzle velocity (Name, Desc)
	acfmenupanel:CPanelText("BlastDisplay", "Blast Radius : " .. (math.floor(Data.BlastRadius * 100) / 100) .. " m") --Proj muzzle velocity (Name, Desc)
	acfmenupanel:CPanelText("FragDisplay", "Fragments : " .. Data.Fragments .. "\n Average Fragment Weight : " .. (math.floor(Data.FragMass * 10000) / 10) .. " g \n Average Fragment Velocity : " .. math.floor(Data.FragVel) .. " m/s") --Proj muzzle penetration (Name, Desc)

	acfmenupanel:CPanelText("SlugDisplay", "1st Penetrator \nPenetrator Mass : " .. (math.floor(Data.SlugMass * 10000) / 10) .. " g \nPenetrator Caliber : " .. (math.floor(Data.SlugCaliber * 100) / 10) .. " mm \nPenetrator Velocity : " .. math.floor(Data.SlugMV) .. " m/s \nMax Penetration : " .. math.floor(Data.MaxPen) .. " mm \n\n2nd Penetrator \nPenetrator Mass : " .. (math.floor(Data.SlugMass2 * 10000) / 10) .. " g \nPenetrator Caliber : " .. (math.floor(Data.SlugCaliber2 * 100) / 10) .. " mm \nPenetrator Velocity : " .. math.floor(Data.SlugMV2) .. " m/s \nMax Penetration : " .. math.floor(Data.MaxPen2) .. " mm \n") --Proj muzzle penetration (Name, Desc)
end

list.Set("HERoundTypes", "THEAT", Round )
ACF.RoundTypes[Round.Type] = Round     --Set the round properties
ACF.IdRounds[Round.netid] = Round.Type --Index must equal the ID entry in the table above, Data must equal the index of the table above