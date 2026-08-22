
AddCSLuaFile()

local Round = {}

Round.type = "Ammo" --Tells the spawn menu what entity to spawn
Round.name = "[CHF] - Chaff" --Human readable name
Round.model = "models/munitions/round_100mm_shot.mdl" --Shell flight model
Round.desc = "Aluminum particles for creating false radar signitures."
Round.netid = 26 --Unique ammotype ID for network transmission

Round.Type  = "CHF"

function Round.create( Gun, BulletData )

	local ent = ents.Create( "ace_flare" )

	if ( IsValid( ent ) ) then

		ent:SetPos( BulletData.Pos )
		ent:SetAngles( BulletData.Flight:Angle() )
		ent.Life = (BulletData.FillerMass or 1) / (0.4 * ACE.Missile.FlareBurnMultiplier) * 1
		ent.IsChaff = true
		ent:Spawn()
		ent:SetOwner( Gun )
		ent:CPPISetOwner( Gun:CPPIGetOwner())
		ent:SetColor( Color( 0, 0, 2, 1 ) ) --Blue set to 1 for flare, set to 2 for chaff

		local phys = ent:GetPhysicsObject()
		phys:SetVelocity( BulletData.Flight * 0.125 )
		--phys:EnableGravity(false)
		local avgFac = 1 - math.Rand(0,1.0)
		ent.Heat = 0 --No thermal signiture for chaff.
		ent.FirstHeat = ent.Heat

		ent.RadarSig = (BulletData.FillerMass or 1) * 1.85 * avgFac --1.71 is 1x. 2.1375 is 1.25x radar signiture avg at full filler.
		ent.FirstRadarSig = ent.RadarSig
		--print(avgFac)
		--print(ent.RadarSig)

	end

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
	if not PlayerData.Data5 then PlayerData.Data5 = 0 end

	PlayerData, Data, ServerData, GUIData = ACE.RoundBaseGunpowder( PlayerData, Data, ServerData, GUIData )

	--Shell sturdiness calcs
	Data.ProjMass = math.max(GUIData.ProjVolume-PlayerData.Data5,0) * 7.9 / 1000 + math.min(PlayerData.Data5,GUIData.ProjVolume) * 3.16 / 1000--Volume of the projectile as a cylinder - Volume of the filler * density of steel + Volume of the filler * density of TNT
	Data.MuzzleVel = ACE.MuzzleVelocity( Data.PropMass, Data.ProjMass, Data.Caliber )
	local Energy = ACE.Kinetic( Data.MuzzleVel * 39.37 , Data.ProjMass, Data.LimitVel )

	local MaxVol = ACE.RoundShellCapacity( Energy.Momentum, Data.FrArea, Data.Caliber, Data.ProjLength )
	GUIData.MinFillerVol = 0
	GUIData.MaxFillerVol = math.min(GUIData.ProjVolume,MaxVol * 0.9)
	GUIData.FillerVol = math.min(PlayerData.Data5,GUIData.MaxFillerVol)
	Data.FillerMass = GUIData.FillerVol * ACE.HEDensity / 200

	Data.ProjMass = math.max(GUIData.ProjVolume-GUIData.FillerVol,0) * 7.9 / 1000 + Data.FillerMass
	Data.MuzzleVel = ACE.MuzzleVelocity( Data.PropMass, Data.ProjMass, Data.Caliber )

	--Random bullshit left
	Data.ShovePower = 0.1
	Data.PenArea = Data.FrArea ^ ACE.PenAreaMod
	Data.DragCoef = ((Data.FrArea / 375) / Data.ProjMass)
	Data.LimitVel = 700										--Most efficient penetration speed in m/s
	Data.KETransfert = 0.1									--Kinetic energy transfert to the target for movement purposes
	Data.Ricochet = 75										--Base ricochet angle

	Data.BurnRate = 0.6 * ACE.Missile.FlareBurnMultiplier
	Data.DistractChance = (2 / math.pi) * math.atan(0.4 * ACE.Missile.FlareDistractMultiplier)
	Data.BurnTime = Data.FillerMass / Data.BurnRate

	Data.BoomPower = Data.PropMass + Data.FillerMass

	if SERVER then --Only the crates need this part
		ServerData.Id = PlayerData.Id
		ServerData.Type = PlayerData.Type
		return table.Merge(Data,ServerData)
	end

	if CLIENT then --Only tthe GUI needs this part
		GUIData = table.Merge(GUIData, Round.getDisplayData(Data))
		return table.Merge(Data,GUIData)
	end

end


function Round.getDisplayData(Data)
	local GUIData = {}

	GUIData.MaxPen = 0

	GUIData.BurnRate = Data.BurnRate
	GUIData.DistractChance = Data.DistractChance
	GUIData.BurnTime = Data.BurnTime

	return GUIData
end


function Round.network( Crate, BulletData )

	Crate:SetNWString( "AmmoType", "CHF" )
	Crate:SetNWString( "AmmoID", BulletData.Id )
	Crate:SetNWFloat( "Caliber", BulletData.Caliber )
	Crate:SetNWFloat( "ProjMass", BulletData.ProjMass )
	Crate:SetNWFloat( "FillerMass", BulletData.FillerMass )
	Crate:SetNWFloat( "PropMass", BulletData.PropMass )
	Crate:SetNWFloat( "DragCoef", BulletData.DragCoef )
	Crate:SetNWFloat( "MuzzleVel", BulletData.MuzzleVel )
	Crate:SetNWFloat( "Tracer", BulletData.Tracer )

end

function Round.cratetxt( BulletData )

	local DData = Round.getDisplayData(BulletData)

	local str =
	{
		"Muzzle Velocity: ", math.Round(BulletData.MuzzleVel, 1), " m/s\n",
		"Dissipation Rate: ", math.Round(DData.BurnRate, 1), " kg/s\n",
		"Lifetime: ", math.Round(DData.BurnTime, 1), " s\n"--,
	}

	return table.concat(str)

end

function Round.propimpact()

	return false

end

function Round.worldimpact()

	return false

end

function Round.endflight( Index )

	ACE.RemoveBullet( Index )

end

function Round.endeffect()

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

	acemenupanel:AmmoSelect( ACE.AmmoBlacklist.FLR )

	acemenupanel:CPanelText("CrateInfoBold", "Crate information:", "DermaDefaultBold")

	acemenupanel:CPanelText("BonusDisplay", "")

	acemenupanel:CPanelText("Desc", "")	--Description (Name, Desc)
	acemenupanel:CPanelText("BoldAmmoStats", "Round information: ", "DermaDefaultBold")
	acemenupanel:CPanelText("LengthDisplay", "")	--Total round length (Name, Desc)
	acemenupanel:CPanelText("VelocityDisplay", "")	--Proj muzzle velocity (Name, Desc)

	acemenupanel:AmmoSlider("PropLength",0,0,1000,3, "Propellant Length", "")	--Propellant Length Slider (Name, Value, Min, Max, Decimals, Title, Desc)
	acemenupanel:AmmoSlider("ProjLength",0,0,1000,3, "Projectile Length", "")	--Projectile Length Slider (Name, Value, Min, Max, Decimals, Title, Desc)
	acemenupanel:AmmoSlider("FillerVol",0,0,1000,3, "Chaff Particulate Filler", "") --Hollow Point Cavity Slider (Name, Value, Min, Max, Decimals, Title, Desc)

	acemenupanel:CPanelText("VelocityDisplay", "")	--Proj muzzle velocity (Name, Desc)
	acemenupanel:CPanelText("TempDisplay", "")	--Temperature of flares
	acemenupanel:CPanelText("BurnRateDisplay", "")	--Proj muzzle penetration (Name, Desc)
	acemenupanel:CPanelText("BurnDurationDisplay", "")	--HE Blast data (Name, Desc)
	--acemenupanel:CPanelText("DistractChanceDisplay", "")	--HE Fragmentation data (Name, Desc)

	Round.guiupdate( Panel, Table )

end

function Round.guiupdate( Panel )

	local PlayerData = {}
		PlayerData.Id = acemenupanel.AmmoData.Data.id			--AmmoSelect GUI
		PlayerData.Type = "CHF"										--Hardcoded, match as Round.Type instead
		PlayerData.PropLength = acemenupanel.AmmoData.PropLength	--PropLength slider
		PlayerData.ProjLength = acemenupanel.AmmoData.ProjLength	--ProjLength slider
		PlayerData.Data5 = acemenupanel.AmmoData.FillerVol
		PlayerData.Tracer	= acemenupanel.AmmoData.Tracer
		PlayerData.TwoPiece	= acemenupanel.AmmoData.TwoPiece

	local Data = Round.convert( Panel, PlayerData )

	RunConsoleCommand( "acemenu_data1", acemenupanel.AmmoData.Data.id )
	RunConsoleCommand( "acemenu_data2", PlayerData.Type )
	RunConsoleCommand( "acemenu_data3", Data.PropLength )		--For Gun ammo, Data3 should always be Propellant
	RunConsoleCommand( "acemenu_data4", Data.ProjLength )		--And Data4 total round mass
	RunConsoleCommand( "acemenu_data5", Data.FillerVol )
	RunConsoleCommand( "acemenu_data10", Data.Tracer )
	RunConsoleCommand( "acemenu_data11", Data.TwoPiece )

	---------------------------Ammo Capacity-------------------------------------
	ACE.AmmoCapacityDisplay( Data )
	-------------------------------------------------------------------------------
	acemenupanel:AmmoSlider("PropLength",Data.PropLength,Data.MinPropLength,Data.MaxTotalLength,3, "Propellant Length", "Propellant Mass : " .. (math.floor(Data.PropMass * 1000)) .. " g" )	--Propellant Length Slider (Name, Min, Max, Decimals, Title, Desc)
	acemenupanel:AmmoSlider("ProjLength",Data.ProjLength,Data.MinProjLength,Data.MaxTotalLength,3, "Projectile Length", "Projectile Mass : " .. (math.floor(Data.ProjMass * 1000)) .. " g")	--Projectile Length Slider (Name, Min, Max, Decimals, Title, Desc)
	acemenupanel:AmmoSlider("FillerVol",Data.FillerVol,Data.MinFillerVol,Data.MaxFillerVol,3, "Chaff Particulate Filler", "Filler Mass : " .. (math.floor(Data.FillerMass * 1000)) .. " g")	--HE Filler Slider (Name, Min, Max, Decimals, Title, Desc)

	acemenupanel:CPanelText("Desc", ACE.RoundTypes[PlayerData.Type].desc)	--Description (Name, Desc)
	acemenupanel:CPanelText("LengthDisplay", "Round Length : " .. (math.floor((Data.PropLength + Data.ProjLength + Data.Tracer) * 100) / 100) .. "/" .. Data.MaxTotalLength .. " cm")	--Total round length (Name, Desc)
	acemenupanel:CPanelText("VelocityDisplay", "Muzzle Velocity : " .. math.floor(Data.MuzzleVel * ACE.VelScale) .. " m/s")	--Proj muzzle velocity (Name, Desc)

	acemenupanel:CPanelText("TempDisplay", "Radar Signiture : " .. math.Round(Data.FillerMass * 2.565, 1) .. "x")

	acemenupanel:CPanelText("BurnRateDisplay", "Burn Rate : " .. math.Round(Data.BurnRate, 1) .. " kg/s")
	acemenupanel:CPanelText("BurnDurationDisplay", "Burn Duration : " .. math.Round(Data.BurnTime, 1) .. " s")

end

list.Set( "SPECSRoundTypes", "CHF", Round )
ACE.RoundTypes[Round.Type] = Round     --Set the round properties
ACE.IdRounds[Round.netid] = Round.Type --Index must equal the ID entry in the table above, Data must equal the index of the table above
