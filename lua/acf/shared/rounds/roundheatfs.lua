
AddCSLuaFile()

ACF.AmmoBlacklist.HEATFS =  { "AC", "SA","C","MG", "AL","HMG" ,"RAC", "SC","ATR" , "MO" , "RM", "SL", "GL", "HW", "SC", "BOMB" , "GBU", "ASM", "AAM", "SAM", "UAR", "POD", "FFAR", "ATGM", "ARTY", "ECM", "FGL","NAV","mNAV"}


local Round = {}

Round.type = "Ammo" --Tells the spawn menu what entity to spawn
Round.name = "[HEAT-FS] - " .. ACFTranslation.ShellHEATFS[1] --Human readable name
Round.model = "models/munitions/round_100mm_mortar_shot.mdl" --Shell flight model
Round.desc = ACFTranslation.ShellHEATFS[2]
Round.netid = 18 --Unique ammotype ID for network transmission

Round.Type  = "HEATFS"

function Round.create( _, BulletData )

	ACF_CreateBullet( BulletData )

end

function Round.ConeCalc( ConeAngle, Radius )

	local ConeLength = math.tan(math.rad(ConeAngle)) * Radius
	local ConeArea = 3.1416 * Radius * (Radius ^ 2 + ConeLength ^ 2) ^ 0.5
	local ConeVol = (3.1416 * Radius ^ 2 * ConeLength) / 3

	return ConeLength, ConeArea, ConeVol

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
	if not PlayerData.Data7 then PlayerData.Data7 = 0 end


	PlayerData.Type = "HEATFS"
	PlayerData, Data, ServerData, GUIData = ACF_RoundBaseGunpowder( PlayerData, Data, ServerData, GUIData )

	local ConeThick = Data.Caliber / 50
	--local ConeLength = 0

	local ConeArea = 0
	local AirVol = 0

	ConeLength, ConeArea, AirVol = Round.ConeCalc( PlayerData.Data6, Data.Caliber / 2, Data.ProjLength )

	--Volume of the projectile as a cylinder - Volume of the filler - Volume of the crush cone * density of steel + Volume of the filler * density of TNT + Area of the cone * thickness * density of steel
	Data.ProjMass = math.max(GUIData.ProjVolume - PlayerData.Data5, 0) * 7.9 / 1000 + math.min(PlayerData.Data5, GUIData.ProjVolume) * ACF.HEDensity / 1000 + ConeArea * ConeThick * 7.9 / 1000
	Data.MuzzleVel = ACF_MuzzleVelocity(Data.PropMass, Data.ProjMass, Data.Caliber)
	local Energy = ACF_Kinetic(Data.MuzzleVel * 39.37, Data.ProjMass, Data.LimitVel)

	local MaxVol = 0
	--local MaxLength = 0
	--local MaxRadius = 0
	MaxVol, MaxLength, MaxRadius = ACF_RoundShellCapacity( Energy.Momentum, Data.FrArea, Data.Caliber, Data.ProjLength )

	GUIData.MinConeAng = 0
	GUIData.MaxConeAng = math.deg(math.atan((Data.ProjLength - ConeThick) / (Data.Caliber / 2)))
	GUIData.ConeAng = math.Clamp(PlayerData.Data6 * 1, GUIData.MinConeAng, GUIData.MaxConeAng)
	ConeLength, ConeArea, AirVol = Round.ConeCalc(GUIData.ConeAng, Data.Caliber / 2, Data.ProjLength)
	local ConeVol = ConeArea * ConeThick

	--print('Current filler: ' .. PlayerData.Data5)

	GUIData.MinFillerVol = 0
	GUIData.MaxFillerVol = math.max(MaxVol -  AirVol - ConeVol,GUIData.MinFillerVol) * 0.95
	GUIData.FillerVol = math.Clamp(PlayerData.Data5,GUIData.MinFillerVol,GUIData.MaxFillerVol)

	--print('After filler: ' .. PlayerData.Data5)
	--print('Max filler: ' .. GUIData.MaxFillerVol)


	Data.FillerMass = GUIData.FillerVol * ACF.HEDensity / 1450
	Data.BoomFillerMass = Data.FillerMass / 3 --manually update function "pierceeffect" with the divisor
	Data.ProjMass = math.max(GUIData.ProjVolume - GUIData.FillerVol - AirVol - ConeVol, 0) * 7.9 / 1000 + Data.FillerMass + ConeVol * 7.9 / 1000
	Data.MuzzleVel = ACF_MuzzleVelocity(Data.PropMass, Data.ProjMass, Data.Caliber)
	--local Energy = ACF_Kinetic(Data.MuzzleVel * 39.37, Data.ProjMass, Data.LimitVel)

	--Let's calculate the actual HEAT slug
	Data.SlugMass = ConeVol * 7.9 / 1000
	local Rad = math.rad(GUIData.ConeAng / 2)
	Data.SlugCaliber = Data.Caliber - Data.Caliber * (math.sin(Rad) * 0.5 + math.cos(Rad) * 1.5) / 2
	Data.SlugMV = 2.2 * (Data.FillerMass / 2 * ACF.HEPower * math.sin(math.rad(10 + GUIData.ConeAng) / 2) / Data.SlugMass) ^ ACF.HEATMVScale --keep fillermass/2 so that penetrator stays the same --1.3
	Data.SlugMass = Data.SlugMass * 4 ^ 2
	Data.SlugMV = Data.SlugMV / 4

	local SlugFrArea = 3.1416 * (Data.SlugCaliber / 2) ^ 2
	Data.SlugPenArea = SlugFrArea ^ ACF.PenAreaMod
	Data.SlugDragCoef = ((SlugFrArea / 10000) / Data.SlugMass)
	Data.SlugRicochet = 500 --Base ricochet angle (The HEAT slug shouldn't ricochet at all)

	--Random bullshit left
	Data.CasingMass = Data.ProjMass - Data.FillerMass - ConeVol * 7.9 / 1000
	Data.FragMass = math.max(Data.CasingMass, 0)
	Data.ShovePower = 0.1
	Data.PenArea = Data.FrArea ^ ACF.PenAreaMod
	Data.DragCoef = (Data.FrArea / 10000) / Data.ProjMass
	Data.LimitVel = 100 --Most efficient penetration speed in m/s
	Data.KETransfert = 0.1 --Kinetic energy transfert to the target for movement purposes
	Data.Ricochet = 80 --Base ricochet angle
	Data.DetonatorAngle = 80

	Data.Detonated = false
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

	local SlugEnergy = ACF_Kinetic(Data.SlugMV * 39.37, Data.SlugMass, 999999)
	GUIData.MaxPen = (SlugEnergy.Penetration / Data.SlugPenArea) * ACF.KEtoRHA

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

	Crate:SetNWString( "AmmoType", "HEATFS" )
	Crate:SetNWString( "AmmoID", BulletData.Id )
	Crate:SetNWFloat( "Caliber", BulletData.Caliber )
	Crate:SetNWFloat( "ProjMass", BulletData.ProjMass )
	Crate:SetNWFloat( "FillerMass", BulletData.FillerMass )
	Crate:SetNWFloat( "PropMass", BulletData.PropMass )
	Crate:SetNWFloat( "DragCoef", BulletData.DragCoef )
	Crate:SetNWFloat( "SlugMass", BulletData.SlugMass )
	Crate:SetNWFloat( "SlugCaliber", BulletData.SlugCaliber )
	Crate:SetNWFloat( "SlugDragCoef", BulletData.SlugDragCoef )
	Crate:SetNWFloat( "MuzzleVel", BulletData.MuzzleVel )
	Crate:SetNWFloat( "Tracer", BulletData.Tracer )

		--For propper bullet model
	Crate:SetNWFloat( "BulletModel", Round.model )

end


--local fakeent = {ACF = {Armour = 0}}
--local fakepen = {Penetration = 999999999}
function Round.cratetxt( BulletData )

	local DData = Round.getDisplayData(BulletData)

	local str =
	{
		"Muzzle Velocity: ", math.Round(BulletData.MuzzleVel, 1), " m/s\n",
		"Max Penetration: ", math.floor(DData.MaxPen), " mm\n",
		"Blast Radius: ", math.Round(DData.BlastRadius, 1), " m\n",
		"Blast Energy: ", math.floor(BulletData.BoomFillerMass * ACF.HEPower), " KJ"
	}

	return table.concat(str)

end

function Round.detonate( _, Bullet, HitPos, HitNormal )

	Bullet.CasingMass = tonumber(Bullet.CasingMass) or 0
	Bullet.FragMass   = tonumber(Bullet.FragMass) or Bullet.CasingMass

	ACF_HE(HitPos - Bullet.Flight:GetNormalized() * 3, HitNormal, Bullet.BoomFillerMass, Bullet.FragMass, Bullet.Owner, nil, Bullet.Gun)

	Bullet.Detonated = true
	Bullet.InitTime = SysTime()
	Bullet.Pos = HitPos
	Bullet.Flight = Bullet.Flight:GetNormalized() * Bullet.SlugMV * 39.37
	Bullet.FlightTime	= 0 --reseting timer
	Bullet.FuseLength = 0.1 + 10 / (Bullet.Flight:Length() * 0.0254)
	Bullet.DragCoef = Bullet.SlugDragCoef

	Bullet.ProjMass = Bullet.SlugMass
	Bullet.CannonCaliber = Bullet.Caliber * 2
	Bullet.Caliber = Bullet.SlugCaliber
	Bullet.PenArea = Bullet.SlugPenArea
	Bullet.Ricochet = Bullet.SlugRicochet

	local DeltaTime = SysTime() - Bullet.LastThink
	Bullet.StartTrace = Bullet.Pos - Bullet.Flight:GetNormalized() * (math.min(ACF.PhysMaxVel * DeltaTime,Bullet.FlightTime * Bullet.Flight:Length()) + 25)
	Bullet.NextPos = Bullet.Pos + (Bullet.Flight * ACF.VelScale * DeltaTime)		--Calculates the next shell position
	Bullet.HEATLastPos = HitPos --Used to backtrack the HEAT's travel distance

end

function Round.propimpact( Index, Bullet, Target, HitNormal, HitPos, Bone )

	if ACF_Check( Target ) then

		if Bullet.Detonated then
			Bullet.NotFirstPen = true

			local Speed = Bullet.Flight:Length() / ACF.VelScale
			local Energy = ACF_Kinetic( Speed , Bullet.ProjMass, 999999 )
			local HitRes = ACF_RoundImpact( Bullet, Speed, Energy, Target, HitPos, HitNormal , Bone )

			if HitRes.Overkill > 0 then
				table.insert( Bullet.Filter , Target )					--"Penetrate" (Ingoring the prop for the retry trace)
				ACF_Spall( HitPos , Bullet.Flight , Bullet.Filter , Energy.Kinetic * HitRes.Loss + 0.2 , Bullet.CannonCaliber * 2 , Target.ACF.Armour , Bullet.Owner , Target.ACF.Material) --Do some spalling
				Bullet.Flight = Bullet.Flight:GetNormalized() * math.sqrt(Energy.Kinetic * (1 - HitRes.Loss) * ((Bullet.NotFirstPen and ACF.HEATPenLayerMul) or 1) * 2000 / Bullet.ProjMass) * 39.37

				return "Penetrated"
			else
				return false
			end

		else

			local distanceTraveled = (HitPos-Bullet.HEATLastPos):Length()
			Bullet.Flight = Bullet.Flight * (1-math.Min( ACF.HEATAirGapFactor * distanceTraveled / 39.37 ,0.99 ))
--			print("Meters Traveled: "..distanceTraveled/39.37)
--			print("Speed Reduction: "..(1-math.Min( ACF.HEATAirGapFactor * distanceTraveled / 39.37 ,0.99 )).."x") --


			--Linter :)
			--local Speed = Bullet.Flight:Length() / ACF.VelScale
			--local Energy = ACF_Kinetic( Speed , Bullet.ProjMass - Bullet.FillerMass, Bullet.LimitVel )
			--local HitRes = ACF_RoundImpact( Bullet, Speed, Energy, Target, HitPos, HitNormal , Bone )


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

	if not Bullet.Detonated then
		Round.detonate( Index, Bullet, HitPos, HitNormal )
		return "Penetrated"
	end

	local Energy = ACF_Kinetic( Bullet.Flight:Length() / ACF.VelScale, Bullet.ProjMass, 999999 )
	local HitRes = ACF_PenetrateGround( Bullet, Energy, HitPos, HitNormal )
	if HitRes.Penetrated then
		return "Penetrated"
	--elseif HitRes.Ricochet then  --penetrator won't ricochet
	--	return "Ricochet"
	else
		return false
	end

end

function Round.endflight( Index, Bullet, HitPos, HitNormal )

	if not Bullet.Detonated then
		local filler = tonumber(Bullet.BoomFillerMass) or ((tonumber(Bullet.FillerMass) or 0) / 3)
		local casing = tonumber(Bullet.FragMass) or tonumber(Bullet.CasingMass) or 0

		ACF_HE(HitPos - Bullet.Flight:GetNormalized() * 3, HitNormal, filler, casing, Bullet.Owner, nil, Bullet.Gun)
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

	if Bullet.Detonated then

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

		Bullet.Detonated = true
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

	acfmenupanel:AmmoSelect( ACF.AmmoBlacklist.HEATFS )
	acfmenupanel:CPanelText("CrateInfoBold", "Crate information:", "DermaDefaultBold")

	acfmenupanel:CPanelText("BonusDisplay", "")

	acfmenupanel:CPanelText("Desc", "")	--Description (Name, Desc)
	acfmenupanel:CPanelText("BoldAmmoStats", "Round information: ", "DermaDefaultBold")
	acfmenupanel:CPanelText("LengthDisplay", "")	--Total round length (Name, Desc)

	--Slider (Name, Value, Min, Max, Decimals, Title, Desc)
	acfmenupanel:AmmoSlider("PropLength",0,0,1000,3, "Propellant Length", "")
	acfmenupanel:AmmoSlider("ProjLength",0,0,1000,3, "Projectile Length", "")
	acfmenupanel:AmmoSlider("ConeAng",0,0,1000,3, "HEAT Cone Angle", "")
	acfmenupanel:AmmoSlider("FillerVol",0,0,1000,3, "Total HEAT Warhead volume", "")

	ACE_Checkboxes()

	acfmenupanel:CPanelText("VelocityDisplay", "")	--Proj muzzle velocity (Name, Desc)
	acfmenupanel:CPanelText("BlastDisplay", "")	--HE Blast data (Name, Desc)
	acfmenupanel:CPanelText("FragDisplay", "")	--HE Fragmentation data (Name, Desc)

	--acfmenupanel:CPanelText("RicoDisplay", "")	--estimated rico chance
	acfmenupanel:CPanelText("SlugDisplay", "")	--HEAT Slug data (Name, Desc)

	Round.guiupdate( Panel, Table )

end

function Round.guiupdate( Panel )

	local PlayerData = {}
		PlayerData.Id = acfmenupanel.AmmoData.Data.id			--AmmoSelect GUI
		PlayerData.Type = "HEATFS"										--Hardcoded, match as Round.Type instead
		PlayerData.PropLength = acfmenupanel.AmmoData.PropLength	--PropLength slider
		PlayerData.ProjLength = acfmenupanel.AmmoData.ProjLength	--ProjLength slider
		PlayerData.Data5 = acfmenupanel.AmmoData.FillerVol
		PlayerData.Data6 = acfmenupanel.AmmoData.ConeAng
		PlayerData.Tracer	= acfmenupanel.AmmoData.Tracer
		PlayerData.TwoPiece	= acfmenupanel.AmmoData.TwoPiece

	local Data = Round.convert( Panel, PlayerData )

	RunConsoleCommand( "acfmenu_data1", acfmenupanel.AmmoData.Data.id )
	RunConsoleCommand( "acfmenu_data2", PlayerData.Type )
	RunConsoleCommand( "acfmenu_data3", Data.PropLength )		--For Gun ammo, Data3 should always be Propellant
	RunConsoleCommand( "acfmenu_data4", Data.ProjLength )
	RunConsoleCommand( "acfmenu_data5", Data.FillerVol )
	RunConsoleCommand( "acfmenu_data6", Data.ConeAng )
	RunConsoleCommand( "acfmenu_data10", Data.Tracer )
	RunConsoleCommand( "acfmenu_data11", Data.TwoPiece )

	---------------------------Ammo Capacity-------------------------------------
	ACE_AmmoCapacityDisplay( Data )
	-------------------------------------------------------------------------------

	acfmenupanel:AmmoSlider("PropLength",Data.PropLength, Data.MinPropLength + (Data.Caliber * 3.9) ,Data.MaxTotalLength,3, "Propellant Length", "Propellant Mass : " .. (math.floor(Data.PropMass * 1000)) .. " g" )	--Propellant Length Slider (Name, Min, Max, Decimals, Title, Desc)
	acfmenupanel:AmmoSlider("ProjLength",Data.ProjLength,Data.MinProjLength,Data.MaxTotalLength,3, "Projectile Length", "Projectile Mass : " .. (math.floor(Data.ProjMass * 1000)) .. " g")	--Projectile Length Slider (Name, Min, Max, Decimals, Title, Desc)
	acfmenupanel:AmmoSlider("ConeAng",Data.ConeAng,Data.MinConeAng,Data.MaxConeAng,0, "Crush Cone Angle", "")	--HE Filler Slider (Name, Min, Max, Decimals, Title, Desc)
	acfmenupanel:AmmoSlider("FillerVol",Data.FillerVol,Data.MinFillerVol,Data.MaxFillerVol,3, "HE Filler Volume", "HE Filler Mass : " .. (math.floor(Data.FillerMass * 1000)) .. " g")	--HE Filler Slider (Name, Min, Max, Decimals, Title, Desc)

	ACE_Checkboxes( Data )

	acfmenupanel:CPanelText("Desc", ACF.RoundTypes[PlayerData.Type].desc) --Description (Name, Desc)
	acfmenupanel:CPanelText("LengthDisplay", "Round Length : " .. (math.floor((Data.PropLength + Data.ProjLength + (math.floor(Data.Tracer * 5) / 10)) * 100) / 100) .. "/" .. Data.MaxTotalLength .. " cm") --Total round length (Name, Desc)
	acfmenupanel:CPanelText("VelocityDisplay", "Muzzle Velocity : " .. math.floor(Data.MuzzleVel * ACF.VelScale) .. " m/s") --Proj muzzle velocity (Name, Desc)
	acfmenupanel:CPanelText("BlastDisplay", "Blast Radius : " .. (math.floor(Data.BlastRadius * 100) / 100) .. " m") --Proj muzzle velocity (Name, Desc)
	acfmenupanel:CPanelText("FragDisplay", "Fragments : " .. Data.Fragments .. "\nAverage Fragment Weight : " .. (math.floor(Data.FragMass * 10000) / 10) .. " g \nAverage Fragment Velocity : " .. math.floor(Data.FragVel) .. " m/s") --Proj muzzle penetration (Name, Desc)

	---------------------------Chance of Ricochet table----------------------------

	acfmenupanel:CPanelText("RicoDisplay", "Max Detonation angle: " .. Data.DetonatorAngle .. "°")

	-------------------------------------------------------------------------------
	local R1V, R1P = ACF_PenRanging(Data.MuzzleVel, Data.DragCoef, Data.ProjMass, Data.PenArea, Data.LimitVel, 100)
	R1P = (ACF_Kinetic(Data.SlugMV * 39.37, Data.SlugMass, 999999).Penetration / Data.SlugPenArea) * ACF.KEtoRHA
	local R2V, R2P = ACF_PenRanging(Data.MuzzleVel, Data.DragCoef, Data.ProjMass, Data.PenArea, Data.LimitVel, 200)
	R2P = (ACF_Kinetic(Data.SlugMV * 39.37, Data.SlugMass, 999999).Penetration / Data.SlugPenArea) * ACF.KEtoRHA
	local R3V, R3P = ACF_PenRanging(Data.MuzzleVel, Data.DragCoef, Data.ProjMass, Data.PenArea, Data.LimitVel, 400)
	R3P = (ACF_Kinetic(Data.SlugMV * 39.37, Data.SlugMass, 999999).Penetration / Data.SlugPenArea) * ACF.KEtoRHA
	local R4V, R4P = ACF_PenRanging(Data.MuzzleVel, Data.DragCoef, Data.ProjMass, Data.PenArea, Data.LimitVel, 800)
	R4P = (ACF_Kinetic(Data.SlugMV * 39.37, Data.SlugMass, 999999).Penetration / Data.SlugPenArea) * ACF.KEtoRHA

	acfmenupanel:CPanelText("SlugDisplay", "Penetrator Mass : " .. (math.floor(Data.SlugMass * 10000) / 10) .. " g \nPenetrator Caliber : " .. (math.floor(Data.SlugCaliber * 100) / 10) .. " mm \nPenetrator Velocity : " .. math.floor(Data.MuzzleVel + Data.SlugMV) .. " m/s \nMax Penetration : " .. math.floor(Data.MaxPen) .. " mm RHA\n\n100m pen: " .. math.floor(R1P, 0) .. "mm @ " .. math.floor(R1V, 0) .. " m\\s\n200m pen: " .. math.floor(R2P, 0) .. "mm @ " .. math.floor(R2V, 0) .. " m\\s\n400m pen: " .. math.floor(R3P, 0) .. "mm @ " .. math.floor(R3V, 0) .. " m\\s\n800m pen: " .. math.floor(R4P, 0) .. "mm @ " .. math.floor(R4V, 0) .. " m\\s\n\nThe range data is an approximation and may not be entirely accurate.\n") --Proj muzzle penetration (Name, Desc)
end

list.Set("HERoundTypes", "HEATFS", Round )
ACF.RoundTypes[Round.Type] = Round     --Set the round properties
ACF.IdRounds[Round.netid] = Round.Type --Index must equal the ID entry in the table above, Data must equal the index of the table above