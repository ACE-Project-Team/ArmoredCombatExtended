
AddCSLuaFile()

--put all guns that this ammo should NOT fit
ACE.AmmoBlacklist.AP =  { "SL", "GL", "ECM", "FGL","SBC","NAV","mNAV"}

local Round   = {}

Round.type    = "Ammo"									-- Tells the spawn menu what entity to spawn
Round.name    = "[AP] - " .. ACE.Translation.ShellAP[1]	-- Human readable name
Round.model   = "models/munitions/round_100mm_shot.mdl"	-- Shell flight model
Round.desc    = ACE.Translation.ShellAP[2]				-- Ammo description
Round.netid   = 1										-- Unique ID for this ammo

Round.Type  = "AP"

function Round.create( _, BulletData )

	ACE.CreateBullet( BulletData )

end

-- Function to convert the player's slider data into the complete round data
function Round.convert( _, PlayerData )

	local Data         = {}
	local ServerData   = {}
	local GUIData      = {}

	PlayerData.PropLength    = PlayerData.PropLength	or 0
	PlayerData.ProjLength    = PlayerData.ProjLength	or 0
	PlayerData.Tracer        = PlayerData.Tracer		or 0
	PlayerData.TwoPiece      = PlayerData.TwoPiece	or 0

	PlayerData, Data, ServerData, GUIData = ACE.RoundBaseGunpowder( PlayerData, Data, ServerData, GUIData )

	--3.16
	Data.ProjMass    = Data.FrArea * (Data.ProjLength * 7.9 / 1000) -- Volume of the projectile as a cylinder * density of steel
	Data.ShovePower  = 0.2
	Data.PenArea     = Data.FrArea ^ ACE.PenAreaMod
	Data.DragCoef    = (Data.FrArea / 10000) / Data.ProjMass
	Data.LimitVel    = 750 -- Most efficient penetration speed in m/s
	Data.KETransfert = 0.3 -- Kinetic energy transfert to the target for movement purposes
	Data.Ricochet    = 53 -- Base ricochet angle
	Data.MuzzleVel   = ACE.MuzzleVelocity(Data.PropMass, Data.ProjMass, Data.Caliber)
	Data.BoomPower   = Data.PropMass

	if SERVER then --Only the crates need this part
		ServerData.Id   = PlayerData.Id
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
	local Energy = ACE.Kinetic(Data.MuzzleVel * 39.37, Data.ProjMass, Data.LimitVel)
	GUIData.MaxPen = ACE.CalcPenetration(Energy, Data.PenArea)
	return GUIData
end

function Round.network( Crate, BulletData )

	Crate:SetNWString( "AmmoType", Round.Type )
	Crate:SetNWString( "AmmoID", BulletData.Id )
	Crate:SetNWFloat( "Caliber", BulletData.Caliber )
	Crate:SetNWFloat( "ProjMass", BulletData.ProjMass )
	Crate:SetNWFloat( "PropMass", BulletData.PropMass )
	Crate:SetNWFloat( "DragCoef", BulletData.DragCoef )
	Crate:SetNWFloat( "MuzzleVel", BulletData.MuzzleVel )
	Crate:SetNWFloat( "Tracer", BulletData.Tracer )

	-- For propper bullet model
	Crate:SetNWFloat( "BulletModel", Round.model )

end

function Round.cratetxt( BulletData )

	local DData = Round.getDisplayData(BulletData)

	local str =
	{
		"Muzzle Velocity: ", math.floor(BulletData.MuzzleVel, 1), " m/s\n",
		"Max Penetration: ", math.floor(DData.MaxPen), " mm"
	}

	return table.concat(str)

end

function Round.propimpact( _, Bullet, Target, HitNormal, HitPos, Bone )

	if ACE.Check( Target ) then

		local Speed	= Bullet.Flight:Length() / ACE.VelScale
		local Energy	= ACE.Kinetic( Speed , Bullet.ProjMass, Bullet.LimitVel )
		local HitRes	= ACE.RoundImpact( Bullet, Speed, Energy, Target, HitPos, HitNormal , Bone )

		if HitRes.PostPenetration.Continue then

			table.insert( Bullet.Filter , Target )				--"Penetrate" (Ingoring the prop for the retry trace)

			ACE.Spall(HitPos, Bullet.Flight, Bullet.Filter, HitRes.PostPenetration.SpentKinetic, Bullet.Caliber, Target.ACE.Armour, Bullet.Owner, Target.ACE.Material) --Do some spalling
			-- Solid shot pays part of its remaining energy for every plate it penetrates (ACE.KEPenLayerMul), like the HEAT jet rule
			Bullet.Flight = Bullet.Flight:GetNormalized() * (HitRes.PostPenetration.RemainingKinetic * ACE.KEPenLayerMul * 2000 / Bullet.ProjMass) ^ 0.5 * 39.37

			return "Penetrated"
		elseif HitRes.Ricochet then

			return "Ricochet"
		else
			return false
		end
	else
		table.insert( Bullet.Filter , Target )
		return "Penetrated"
	end

end

function Round.worldimpact( _, Bullet, HitPos, HitNormal )

	local Energy = ACE.Kinetic( Bullet.Flight:Length() / ACE.VelScale, Bullet.ProjMass, Bullet.LimitVel )
	local HitRes = ACE.PenetrateGround( Bullet, Energy, HitPos, HitNormal )

	if HitRes.Penetrated then

		return "Penetrated"
	elseif HitRes.Ricochet then

		return "Ricochet"
	else
		return false
	end

end

function Round.endflight( Index )

	ACE.RemoveBullet( Index )

end

-- Bullet stops here
function Round.endeffect( _, Bullet )

	local Spall = EffectData()
		Spall:SetEntity( Bullet.Crate )
		Spall:SetOrigin( Bullet.SimPos )
		Spall:SetNormal( (Bullet.SimFlight):GetNormalized() )
		Spall:SetScale( Bullet.SimFlight:Length() )
		Spall:SetMagnitude( Bullet.RoundMass )
	util.Effect( "ACE_ap_impact", Spall )

end

-- Bullet penetrated something
function Round.pierceeffect( _, Bullet )

	local Spall = EffectData()
		Spall:SetEntity( Bullet.Crate )
		Spall:SetOrigin( Bullet.SimPos )
		Spall:SetNormal( (Bullet.SimFlight):GetNormalized() )
		Spall:SetScale( Bullet.SimFlight:Length() )
		Spall:SetMagnitude( Bullet.RoundMass )
	util.Effect( "ACE_ap_penetration", Spall )

end

-- Bullet ricocheted off something
function Round.ricocheteffect( _, Bullet )

	local Spall = EffectData()
		Spall:SetEntity( Bullet.Crate )
		Spall:SetOrigin( Bullet.SimPos )
		Spall:SetNormal( (Bullet.SimFlight):GetNormalized() )
		Spall:SetScale( Bullet.SimFlight:Length() )
		Spall:SetMagnitude( Bullet.RoundMass )
	util.Effect( "ACE_ap_ricochet", Spall )

end

function Round.guicreate( Panel, Table )

	acemenupanel:AmmoSelect( ACE.AmmoBlacklist.AP )

	ACE.UpperCommonDataDisplay()

	acemenupanel:AmmoSlider("PropLength",0,0,1000,3, "Propellant Length", "")	--Propellant Length Slider (Name, Value, Min, Max, Decimals, Title, Desc)
	acemenupanel:AmmoSlider("ProjLength",0,0,1000,3, "Projectile Length", "")	--Projectile Length Slider (Name, Value, Min, Max, Decimals, Title, Desc)

	ACE.CommonDataDisplay()

	Round.guiupdate( Panel, Table )

end

function Round.guiupdate( Panel )

	local PlayerData = {}
		PlayerData.Id		= acemenupanel.AmmoData.Data.id					-- AmmoSelect GUI
		PlayerData.Type		= Round.Type										-- Hardcoded, match as Round.Type instead
		PlayerData.PropLength	= acemenupanel.AmmoData.PropLength				-- PropLength slider
		PlayerData.ProjLength	= acemenupanel.AmmoData.ProjLength				-- ProjLength slider
		PlayerData.Tracer	= acemenupanel.AmmoData.Tracer
		PlayerData.TwoPiece	= acemenupanel.AmmoData.TwoPiece

	local Data = Round.convert( Panel, PlayerData )

	RunConsoleCommand( "acemenu_data1", acemenupanel.AmmoData.Data.id )
	RunConsoleCommand( "acemenu_data2", PlayerData.Type )
	RunConsoleCommand( "acemenu_data3", Data.PropLength )						--For Gun ammo, Data3 should always be Propellant
	RunConsoleCommand( "acemenu_data4", Data.ProjLength )						--And Data4 total round mass
	RunConsoleCommand( "acemenu_data10", Data.Tracer )
	RunConsoleCommand( "acemenu_data11", Data.TwoPiece )

	acemenupanel:AmmoSlider("PropLength", Data.PropLength, Data.MinPropLength, Data.MaxTotalLength, 3, "Propellant Length", "Propellant Mass : " .. (math.floor(Data.PropMass * 1000)) .. " g" .. "/ " .. (math.Round(Data.PropMass, 1)) .. " kg" )  --Propellant Length Slider (Name, Min, Max, Decimals, Title, Desc)
	acemenupanel:AmmoSlider("ProjLength", Data.ProjLength, Data.MinProjLength, Data.MaxTotalLength, 3, "Projectile Length", "Projectile Mass : " .. (math.floor(Data.ProjMass * 1000)) .. " g" .. "/ " .. (math.Round(Data.ProjMass, 1)) .. " kg")  --Projectile Length Slider (Name, Min, Max, Decimals, Title, Desc)

	ACE.UpperCommonDataDisplay( Data, PlayerData )
	ACE.CommonDataDisplay( Data )

end

list.Set( "APRoundTypes", Round.Type , Round )

ACE.RoundTypes[Round.Type] = Round     --Set the round properties
ACE.IdRounds[Round.netid] = Round.Type --Index must equal the ID entry in the table above, Data must equal the index of the table above
