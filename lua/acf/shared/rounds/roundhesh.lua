
AddCSLuaFile()

ACE.AmmoBlacklist.HESH = { "SBC", "MG", "HMG", "RAC", "SL" , "AC" , "SA" , "GL", "ECM", "ATR", "BOMB" , "GBU", "AAM", "SAM", "ECM", "FGL"}

local Round = {}

Round.type = "Ammo" --Tells the spawn menu what entity to spawn
Round.name = "[HESH] - " .. ACE.Translation.ShellHESH[1] --Human readable name
Round.model = "models/munitions/round_100mm_shot.mdl" --Shell flight model
Round.desc = ACE.Translation.ShellHESH[2]
Round.netid = 12 --Unique ammotype ID for network transmission

Round.Type  = "HESH"

function Round.create( _, BulletData )

	ACE_CreateBullet( BulletData )

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

	PlayerData, Data, ServerData, GUIData = ACE_RoundBaseGunpowder( PlayerData, Data, ServerData, GUIData )

	--Shell sturdiness calcs
	Data.ProjMass = math.max(GUIData.ProjVolume - PlayerData.Data5, 0) * 7.9 / 1000 + math.min(PlayerData.Data5, GUIData.ProjVolume) * ACE.HEDensity / 1000 --Volume of the projectile as a cylinder - Volume of the filler * density of steel + Volume of the filler * density of TNT
	Data.MuzzleVel = ACE_MuzzleVelocity(Data.PropMass, Data.ProjMass, Data.Caliber)
	local Energy = ACE_Kinetic(Data.MuzzleVel * 39.37, Data.ProjMass, Data.LimitVel)

	local MaxVol = ACE_RoundShellCapacity(Energy.Momentum, Data.FrArea, Data.Caliber, Data.ProjLength)
	GUIData.MinFillerVol = 0
	GUIData.MaxFillerVol = math.min(GUIData.ProjVolume, MaxVol)
	GUIData.FillerVol = math.min(PlayerData.Data5, GUIData.MaxFillerVol)
	Data.FillerMass = GUIData.FillerVol * ACE.HEDensity / 1000

	Data.ProjMass = math.max(GUIData.ProjVolume - GUIData.FillerVol, 0) * 7.9 / 1000 + Data.FillerMass
	Data.MuzzleVel = ACE_MuzzleVelocity(Data.PropMass, Data.ProjMass, Data.Caliber)

	--Random bullshit left
	Data.ShovePower = 0.1
	Data.PenArea = Data.FrArea ^ ACE.PenAreaMod
	Data.DragCoef = (Data.FrArea / 10000) / Data.ProjMass
	Data.LimitVel = 100 --Most efficient penetration speed in m/s
	Data.KETransfert = 0.1 --Kinetic energy transfert to the target for movement purposes
	Data.Ricochet = 62 --Base ricochet angle
	Data.DetonatorAngle = 62

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
	GUIData.BlastRadius = (Data.FillerMass * 0.7) ^ 0.33 * 8
	local FragMass = Data.ProjMass - Data.FillerMass
	GUIData.Fragments = math.max(math.floor((Data.FillerMass / FragMass) * ACE.HEFrag), 2)
	GUIData.FragMass = FragMass / GUIData.Fragments
	GUIData.FragVel = (Data.FillerMass * ACE.HEPower * 1000 / GUIData.FragMass / GUIData.Fragments) ^ 0.5
	GUIData.MaxPen = Data.FillerMass / 300 * ACE.HEPower

	return GUIData
end


function Round.network( Crate, BulletData )

	Crate:SetNWString( "AmmoType", "HESH" )
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
		"Blast Radius: ", math.Round(DData.BlastRadius, 1), " m\n",
		"Blast Energy: ", math.floor(BulletData.FillerMass * ACE.HEPower * 0.7), " KJ\n",
		"Blast Penetration: ", math.floor(DData.MaxPen), " mm"
	}

	return table.concat(str)

end

function Round.propimpact( _, Bullet, Target, _, HitPos, Bone ) --Hitnormal not used.

	if ACE_Check( Target ) then

		local Speed = Bullet.Flight:Length() / ACE.VelScale
		-- HESH should not behave like a giant AP slug; use mostly-casing impact mass.
		local ImpactMass = math.max(Bullet.ProjMass - Bullet.FillerMass * 0.85, Bullet.ProjMass * 0.1)
		local Energy = ACE_Kinetic(Speed, ImpactMass, Bullet.LimitVel)

		local Mat		= Target.ACF.Material or "RHA"
		local MatData	= ACE_GetMaterialData( Mat )

		local Pen = Bullet.FillerMass / 300 * ACE.HEPower
		if ( Pen * 1.25 ) > ( Target.ACF.Armour * (MatData.ArmorMul or 1) ) then

			ACE_RoundImpact(Bullet, Speed, Energy, Target, HitPos, -Bullet.Flight:GetNormalized(), Bone) --( Bullet, Speed, Energy, Target, HitPos, HitNormal , Bone  )

			table.insert( Bullet.Filter , Target )
			ACE_Spall_HESH( HitPos, Bullet.Flight, Bullet.Filter, Bullet.FillerMass * ACE.HEPower, Bullet.Caliber, Target.ACF.Armour, Bullet.Owner, Target.ACF.Material) --Do some spalling

		end

		local Radius = Bullet.FillerMass ^ 0.33 * 8 * 39.37
		local Flash = EffectData()
			Flash:SetOrigin( HitPos )
			Flash:SetNormal( Bullet.Flight:GetNormalized() )
			Flash:SetRadius( math.Round(math.max(Radius / 39.37, 1),2) )
		util.Effect( "ACE_Scaled_Explosion", Flash )

	else
		table.insert( Bullet.Filter , Target )
	return "Penetrated" end

end

function Round.worldimpact( )

	return false

end

function Round.endflight( Index, Bullet, HitPos, HitNormal )

	ACE_HE( HitPos - Bullet.Flight:GetNormalized() * 3, HitNormal, Bullet.FillerMass * 0.7, Bullet.ProjMass - Bullet.FillerMass * 0.7, Bullet.Owner, nil, Bullet.Gun )
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

	local BulletEffect = {}
		BulletEffect.Num = 1
		BulletEffect.Src = Bullet.SimPos - Bullet.SimFlight:GetNormalized()
		BulletEffect.Dir = Bullet.SimFlight:GetNormalized()
		BulletEffect.Spread = Vector(0,0,0)
		BulletEffect.Tracer = 0
		BulletEffect.Force = 0
		BulletEffect.Damage = 0
	LocalPlayer():FireBullets(BulletEffect)

	util.Decal("ExplosiveGunshot", Bullet.SimPos + Bullet.SimFlight * 10, Bullet.SimPos - Bullet.SimFlight * 10)

	local Spall = EffectData()
		Spall:SetOrigin( Bullet.SimPos )
		Spall:SetNormal( (Bullet.SimFlight):GetNormalized() )
		Spall:SetScale(math.max(((Bullet.RoundMass * (Bullet.SimFlight:Length() / 39.37) ^ 2) / 2000) / 10000, 1))
	util.Effect( "ACE_AP_Impact", Spall )

end

function Round.ricocheteffect( _, Bullet )

	local Spall = EffectData()
		Spall:SetEntity( Bullet.Crate )
		Spall:SetOrigin( Bullet.SimPos )
		Spall:SetNormal( Bullet.SimFlight:GetNormalized() )
		Spall:SetScale( Bullet.SimFlight:Length() )
		Spall:SetMagnitude( Bullet.RoundMass )
	util.Effect( "ACE_AP_Ricochet", Spall )

end

function Round.guicreate( Panel, Table )

	acemenupanel:AmmoSelect(ACE.AmmoBlacklist.HESH)

	acemenupanel:CPanelText("CrateInfoBold", "Crate information:", "DermaDefaultBold")

	acemenupanel:CPanelText("BonusDisplay", "")

	acemenupanel:CPanelText("Desc", "")	--Description (Name, Desc)
	acemenupanel:CPanelText("BoldAmmoStats", "Round information: ", "DermaDefaultBold")
	acemenupanel:CPanelText("LengthDisplay", "")	--Total round length (Name, Desc)

	acemenupanel:AmmoSlider("PropLength",0,0,1000,3, "Propellant Length", "")	--Slider (Name, Value, Min, Max, Decimals, Title, Desc)
	acemenupanel:AmmoSlider("ProjLength",0,0,1000,3, "Projectile Length", "")	--Slider (Name, Value, Min, Max, Decimals, Title, Desc)
	acemenupanel:AmmoSlider("FillerVol",0,0,1000,3, "HE Filler", "")			--Slider (Name, Value, Min, Max, Decimals, Title, Desc)

	ACE_Checkboxes()

	acemenupanel:CPanelText("VelocityDisplay", "")	--Proj muzzle velocity (Name, Desc)
	acemenupanel:CPanelText("BlastDisplay", "")	--HE Blast data (Name, Desc)
	acemenupanel:CPanelText("FragDisplay", "")	--HE Fragmentation data (Name, Desc)
	--acemenupanel:CPanelText("RicoDisplay", "")	--estimated rico chance

	Round.guiupdate( Panel, Table )

end

function Round.guiupdate( Panel )

	local PlayerData = {}
		PlayerData.Id = acemenupanel.AmmoData.Data.id			--AmmoSelect GUI
		PlayerData.Type = "HESH"										--Hardcoded, match as Round.Type instead
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
	ACE_AmmoCapacityDisplay( Data )
	-------------------------------------------------------------------------------
	acemenupanel:AmmoSlider("PropLength",Data.PropLength,Data.MinPropLength,Data.MaxTotalLength,3, "Propellant Length", "Propellant Mass : " .. (math.floor(Data.PropMass * 1000)) .. " g" )	--Propellant Length Slider (Name, Min, Max, Decimals, Title, Desc)
	acemenupanel:AmmoSlider("ProjLength",Data.ProjLength,Data.MinProjLength,Data.MaxTotalLength,3, "Projectile Length", "Projectile Mass : " .. (math.floor(Data.ProjMass * 1000)) .. " g")	--Projectile Length Slider (Name, Min, Max, Decimals, Title, Desc)
	acemenupanel:AmmoSlider("FillerVol",Data.FillerVol,Data.MinFillerVol,Data.MaxFillerVol,3, "HE Filler Volume", "HE Filler Mass : " .. (math.floor(Data.FillerMass * 1000)) .. " g")	--HE Filler Slider (Name, Min, Max, Decimals, Title, Desc)

	ACE_Checkboxes( Data )

	acemenupanel:CPanelText("Desc", ACE.RoundTypes[PlayerData.Type].desc) --Description (Name, Desc)
	acemenupanel:CPanelText("LengthDisplay", "Round Length : " .. (math.floor((Data.PropLength + Data.ProjLength + (math.floor(Data.Tracer * 5) / 10)) * 100) / 100) .. "/" .. Data.MaxTotalLength .. " cm") --Total round length (Name, Desc)
	acemenupanel:CPanelText("VelocityDisplay", "Muzzle Velocity : " .. math.floor(Data.MuzzleVel * ACE.VelScale) .. " m/s") --Proj muzzle velocity (Name, Desc)
	acemenupanel:CPanelText("BlastDisplay", "Blast Radius : " .. (math.floor(Data.BlastRadius * 100) / 100) .. " m" .. "\nShockwave Max penetration: " .. math.floor(Data.MaxPen) .. " mm RHA") --Proj muzzle velocity (Name, Desc)
	acemenupanel:CPanelText("FragDisplay", "Fragments : " .. Data.Fragments .. "\n Average Fragment Weight : " .. (math.floor(Data.FragMass * 10000) / 10) .. " g \n Average Fragment Velocity : " .. math.floor(Data.FragVel) .. " m/s") --Proj muzzle penetration (Name, Desc)

	---------------------------Chance of Ricochet table----------------------------

	acemenupanel:CPanelText("RicoDisplay", "Max Detonation angle: " .. Data.DetonatorAngle .. "°")

	-------------------------------------------------------------------------------
end

list.Set("HERoundTypes", "HESH", Round ) --Set the round on chemical folder
ACE.RoundTypes[Round.Type] = Round     --Set the round properties
ACE.IdRounds[Round.netid] = Round.Type --Index must equal the ID entry in the table above, Data must equal the index of the table above
