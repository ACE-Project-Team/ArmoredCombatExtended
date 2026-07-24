
AddCSLuaFile()

ACE.AmmoBlacklist.APHE = { "MO", "RM", "SL", "GL", "FGL","SBC","NAV","mNAV"}

local Round = {}

Round.type = "Ammo" --Tells the spawn menu what entity to spawn
Round.name = "[APHE] - " .. ACE.Translation.ShellAPHE[1] --Human readable name
Round.model = "models/munitions/round_100mm_shot.mdl" --Shell flight model
Round.desc = ACE.Translation.ShellAPHE[2]
Round.netid = 5 --Unique ammotype ID for network transmission

Round.Type  = "APHE"

function Round.create( _, BulletData )

	ACE_CreateBullet( BulletData )

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
	PlayerData.Data5	= PlayerData.Data5 and math.max(PlayerData.Data5, 0) or 0
	PlayerData.Data6	= PlayerData.Data6		or 0

	PlayerData, Data, ServerData, GUIData = ACE_RoundBaseGunpowder( PlayerData, Data, ServerData, GUIData )

	--Shell sturdiness calcs
	Data.ProjMass		= math.max(GUIData.ProjVolume-PlayerData.Data5,0) * 7.9 / 1000 + math.min(PlayerData.Data5,GUIData.ProjVolume) * ACE.HEDensity / 1000--Volume of the projectile as a cylinder - Volume of the filler * density of steel + Volume of the filler * density of TNT
	Data.MuzzleVel		= ACE_MuzzleVelocity( Data.PropMass, Data.ProjMass, Data.Caliber )
	local Energy			= ACE_Kinetic( Data.MuzzleVel * 39.37 , Data.ProjMass, Data.LimitVel )

	local MaxVol			= ACE_RoundShellCapacity( Energy.Momentum, Data.FrArea, Data.Caliber, Data.ProjLength )
	GUIData.MinFillerVol	= 0
	GUIData.MaxFillerVol	= math.min(GUIData.ProjVolume,MaxVol * 0.9)
	GUIData.FillerVol	= math.min(PlayerData.Data5,GUIData.MaxFillerVol)
	Data.FillerMass		= GUIData.FillerVol * ACE.HEDensity / 1000

	Data.ProjMass		= math.max(GUIData.ProjVolume-GUIData.FillerVol,0) * 7.9 / 1000 + Data.FillerMass
	Data.MuzzleVel		= ACE_MuzzleVelocity( Data.PropMass, Data.ProjMass, Data.Caliber )

	--Random bullshit left
	Data.ShovePower		= 0.1
	Data.PenArea			= Data.FrArea ^ ACE.PenAreaMod
	Data.DragCoef		= ((Data.FrArea / 10000) / Data.ProjMass)
	Data.LimitVel		= 700									--Most efficient penetration speed in m/s
	Data.KETransfert		= 0.1								--Kinetic energy transfert to the target for movement purposes
	Data.Ricochet		= 54									--Base ricochet angle

	Data.BoomPower		= Data.PropMass + Data.FillerMass

	Data.HasPenned		= false
	Data.DetDelay		= math.Clamp(PlayerData.Data6, 0, 5)

	if SERVER then --Only the crates need this part
		ServerData.Id	= PlayerData.Id
		ServerData.Type	= PlayerData.Type
		return table.Merge(Data,ServerData)
	end

	if CLIENT then --Only tthe GUI needs this part
		GUIData			= table.Merge(GUIData, Round.getDisplayData(Data))
		return table.Merge(Data,GUIData)
	end
end

function Round.getDisplayData(Data)

	local GUIData	= {}
	local Energy		= ACE_Kinetic( Data.MuzzleVel * 39.37 , Data.ProjMass, Data.LimitVel )
	local FragMass	= Data.ProjMass - Data.FillerMass

	GUIData.MaxPen	= ACE_CalcPenetration(Energy, Data.PenArea)
	GUIData.BlastRadius = Data.FillerMass ^ 0.33 * 8
	GUIData.Fragments	= math.max(math.floor((Data.FillerMass / FragMass) * ACE.HEFrag),2)
	GUIData.FragMass	= FragMass / GUIData.Fragments
	GUIData.FragVel	= (Data.FillerMass * ACE.HEPower * 1000 / GUIData.FragMass / GUIData.Fragments) ^ 0.5
	return GUIData
end

function Round.network( Crate, BulletData )

	Crate:SetNWString( "AmmoType", "APHE" )
	Crate:SetNWString( "AmmoID", BulletData.Id )
	Crate:SetNWFloat( "Caliber", BulletData.Caliber )
	Crate:SetNWFloat( "ProjMass", BulletData.ProjMass )
	Crate:SetNWFloat( "FillerMass", BulletData.FillerMass )
	Crate:SetNWFloat( "FuseDelay", BulletData.DetDelay )
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
		"Max Penetration: ", math.floor(DData.MaxPen), " mm\n",
		"Blast Radius: ", math.Round(DData.BlastRadius, 1), " m\n",
		"Blast Energy: ", math.floor(BulletData.FillerMass * ACE.HEPower), " KJ\n",
		"Fuse Delay: ", math.floor(BulletData.DetDelay * 1000), " ms\n",
		"Max Blast Penetration: ", math.floor(BulletData.FillerMass * ACE.HEPower / ACE.HEBlastPenetration), " mm"
	}

	return table.concat(str)

end

function Round.propimpact( _, Bullet, Target, HitNormal, HitPos, Bone )

	if ACE_Check( Target ) then

		local Speed	= Bullet.Flight:Length() / ACE.VelScale
		local Energy	= ACE_Kinetic( Speed , Bullet.ProjMass, Bullet.LimitVel )
		local HitRes	= ACE_RoundImpact( Bullet, Speed, Energy, Target, HitPos, HitNormal , Bone )

		if HitRes.PostPenetration.Continue then

			if Bullet.HasPenned == false then

				Bullet.HasPenned	= true
				Bullet.FuseLength	= Bullet.DetDelay or 0
				Bullet.InitTime	= SysTime()
				Bullet.FlightTime	= 0
			end

			table.insert( Bullet.Filter , Target )				--"Penetrate" (Ingoring the prop for the retry trace)

			ACE_Spall( HitPos , Bullet.Flight , Bullet.Filter , HitRes.PostPenetration.SpentKinetic , Bullet.Caliber , Target.ACF.Armour , Bullet.Owner , Target.ACF.Material) --Do some spalling
			Bullet.Flight = Bullet.Flight:GetNormalized() * (HitRes.PostPenetration.RemainingKinetic * 2000 / Bullet.ProjMass) ^ 0.5 * 39.37

			return "Penetrated"
		elseif HitRes.Ricochet then
			return "Ricochet"
		else
			return false
		end
	else
		table.insert( Bullet.Filter , Target )
	return "Penetrated" end

end

function Round.worldimpact( _, Bullet, HitPos, HitNormal )

	local Energy = ACE_Kinetic( Bullet.Flight:Length() / ACE.VelScale, Bullet.ProjMass, Bullet.LimitVel )
	local HitRes = ACE_PenetrateGround( Bullet, Energy, HitPos, HitNormal )
	if HitRes.Penetrated then
		return "Penetrated"
	elseif HitRes.Ricochet then
		return "Ricochet"
	else
		return false
	end

end

function Round.endflight( Index, Bullet, HitPos, HitNormal )

	ACE_HE( HitPos - Bullet.Flight:GetNormalized() * 3, HitNormal, Bullet.FillerMass, Bullet.ProjMass - Bullet.FillerMass, Bullet.Owner, nil, Bullet.Gun )
	ACE_RemoveBullet( Index )

end

function Round.endeffect( _, Bullet )

	local Radius = Bullet.FillerMass ^ 0.33 * 8 * 39.37
	local Flash = EffectData()
		Flash:SetOrigin( Bullet.SimPos )
		Flash:SetNormal( Bullet.SimFlight:GetNormalized() )
		Flash:SetRadius( math.Round(math.max(Radius / 39.37, 1),2) )
	util.Effect( "ACE_Scaled_Explosion", Flash )

end

function Round.pierceeffect( _, Bullet )

	local Spall = EffectData()
		Spall:SetEntity( Bullet.Crate )
		Spall:SetOrigin( Bullet.SimPos )
		Spall:SetNormal( (Bullet.SimFlight):GetNormalized() )
		Spall:SetScale( Bullet.SimFlight:Length() )
		Spall:SetMagnitude( Bullet.RoundMass )
	util.Effect( "ACE_AP_Penetration", Spall )

end

function Round.ricocheteffect( _, Bullet )

	local Spall = EffectData()
		Spall:SetEntity( Bullet.Crate )
		Spall:SetOrigin( Bullet.SimPos )
		Spall:SetNormal( (Bullet.SimFlight):GetNormalized() )
		Spall:SetScale( Bullet.SimFlight:Length() )
		Spall:SetMagnitude( Bullet.RoundMass )
	util.Effect( "ACE_AP_Ricochet", Spall )

end

function Round.guicreate( Panel, Table )

	acemenupanel:AmmoSelect( ACE.AmmoBlacklist.APHE )

	ACE_UpperCommonDataDisplay()

	acemenupanel:AmmoSlider("PropLength",0,0,1000,3, "Propellant Length", "")	--Propellant Length Slider (Name, Value, Min, Max, Decimals, Title, Desc)
	acemenupanel:AmmoSlider("ProjLength",0,0,1000,3, "Projectile Length", "")	--Projectile Length Slider (Name, Value, Min, Max, Decimals, Title, Desc)
	acemenupanel:CPanelText("BlastPenDisplay", "")  --HE Fragmentation data (Name, Desc)
	acemenupanel:AmmoSlider("FillerVol",0,0,1000,3, "HE Filler", "")			--Hollow Point Cavity Slider (Name, Value, Min, Max, Decimals, Title, Desc)

	acemenupanel:AmmoCheckbox("Tracer", "Tracer", "")	--Tracer checkbox (Name, Title, Desc)
	acemenupanel:AmmoCheckbox("TwoPiece", "Enable Two Piece Storage", "", "" )

	acemenupanel:CPanelText("BlastDisplay", "")		--HE Blast data (Name, Desc)
	acemenupanel:CPanelText("FragDisplay", "")		--HE Fragmentation data (Name, Desc)
	acemenupanel:CPanelText("RicoDisplay", "")		--estimated rico chance
	acemenupanel:CPanelText("PenetrationDisplay", "")	--Proj muzzle penetration (Name, Desc)

	Round.guiupdate( Panel, Table )

end

function Round.guiupdate( Panel )

	local PlayerData = {}
		PlayerData.Id		= acemenupanel.AmmoData.Data.id			--AmmoSelect GUI
		PlayerData.Type		= "APHE"									--Hardcoded, match as Round.Type instead
		PlayerData.PropLength	= acemenupanel.AmmoData.PropLength		--PropLength slider
		PlayerData.ProjLength	= acemenupanel.AmmoData.ProjLength		--ProjLength slider
		PlayerData.Data5		= acemenupanel.AmmoData.FillerVol
		PlayerData.Data6		= acemenupanel.AmmoData.DetDelay
		PlayerData.Tracer	= acemenupanel.AmmoData.Tracer
		PlayerData.TwoPiece	= acemenupanel.AmmoData.TwoPiece

	local Data = Round.convert( Panel, PlayerData )

	RunConsoleCommand( "acemenu_data1", acemenupanel.AmmoData.Data.id )
	RunConsoleCommand( "acemenu_data2", PlayerData.Type )
	RunConsoleCommand( "acemenu_data3", Data.PropLength )	--For Gun ammo, Data3 should always be Propellant
	RunConsoleCommand( "acemenu_data4", Data.ProjLength )	--And Data4 total round mass
	RunConsoleCommand( "acemenu_data5", Data.FillerVol )
	RunConsoleCommand( "acemenu_data6", Data.DetDelay )
	RunConsoleCommand( "acemenu_data10", Data.Tracer )
	RunConsoleCommand( "acemenu_data11", Data.TwoPiece )

	acemenupanel:AmmoSlider("PropLength", Data.PropLength, Data.MinPropLength, Data.MaxTotalLength, 3, "Propellant Length", "Propellant Mass : " .. (math.floor(Data.PropMass * 1000)) .. " g" .. "/ " .. (math.Round(Data.PropMass, 1)) .. " kg" )  --Propellant Length Slider (Name, Min, Max, Decimals, Title, Desc)
	acemenupanel:AmmoSlider("ProjLength", Data.ProjLength, Data.MinProjLength, Data.MaxTotalLength, 3, "Projectile Length", "Projectile Mass : " .. (math.floor(Data.ProjMass * 1000)) .. " g" .. "/ " .. (math.Round(Data.ProjMass, 1)) .. " kg")  --Projectile Length Slider (Name, Min, Max, Decimals, Title, Desc)	--Projectile Length Slider (Name, Min, Max, Decimals, Title, Desc)
	acemenupanel:CPanelText("BlastPenDisplay", "Max Blast Penetration: " .. math.floor(Data.FillerMass * ACE.HEPower / ACE.HEBlastPenetration,1) .. " mm")
	acemenupanel:AmmoSlider("FillerVol",Data.FillerVol,Data.MinFillerVol,Data.MaxFillerVol,3, "HE Filler Volume", "HE Filler Mass : " .. (math.floor(Data.FillerMass * 1000)) .. " g")	--HE Filler Slider (Name, Min, Max, Decimals, Title, Desc)
	acemenupanel:AmmoSlider("DetDelay",Data.DetDelay,0,1,3, "Detonation Fuse Delay", "Delay : " .. (math.Round(Data.DetDelay * 1000,3)) .. " ms") --HE Filler Slider (Name, Min, Max, Decimals, Title, Desc)

	acemenupanel:CPanelText("BlastDisplay", "Blast Radius : " .. (math.floor(Data.BlastRadius * 100) / 100) .. " m")	--Proj muzzle velocity (Name, Desc)
	acemenupanel:CPanelText("FragDisplay", "Fragments : " .. Data.Fragments .. "\n Average Fragment Weight : " .. (math.floor(Data.FragMass * 10000) / 10) .. " g \n Average Fragment Velocity : " .. math.floor(Data.FragVel) .. " m/s") --Proj muzzle penetration (Name, Desc)

	ACE_UpperCommonDataDisplay( Data, PlayerData )
	ACE_CommonDataDisplay( Data )

end

list.Set( "APRoundTypes", "APHE", Round )
ACE.RoundTypes[Round.Type] = Round     --Set the round properties
ACE.IdRounds[Round.netid] = Round.Type --Index must equal the ID entry in the table above, Data must equal the index of the table above
