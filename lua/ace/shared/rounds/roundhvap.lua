
AddCSLuaFile()

ACE.AmmoBlacklist.HVAP =  { "MO", "RM", "SL", "GL", "HW", "MG", "SC", "BOMB" , "GBU", "ASM", "AAM", "SAM", "UAR", "POD", "FFAR", "ATGM", "ARTY", "ECM", "FGL","SBC","NAV","mNAV" }

local Round = {}

Round.type = "Ammo" --Tells the spawn menu what entity to spawn
Round.name = "[APCR / HVAP] - " .. ACE.Translation.ShellAPCR[1] --Human readable name
Round.model = "models/munitions/round_100mm_shot.mdl" --Shell flight model
Round.desc = ACE.Translation.ShellAPCR[2]
Round.netid = 11 --Unique ammotype ID for network transmission

Round.Type  = "HVAP"

function Round.create( _, BulletData )

			ACE.CreateBullet( BulletData )

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
	if not PlayerData.SCalMult then PlayerData.SCalMult = 0.5 end
	if not PlayerData["Data5"] then PlayerData["Data5"] = 0.5 end --caliber in mm count

	PlayerData, Data, ServerData, GUIData = ACE.RoundBaseGunpowder( PlayerData, Data, ServerData, GUIData )

--	local GunClass = ACE.Weapons["Guns"][(Data["Id"] or PlayerData["Id"])]["gunclass"]

--	if GunClass == "C" then

	Data.MinCalMult = 0.25
	Data.MaxCalMult = 1
	Data.PenModifier = 1.7
	Data.Ricochet = 50  --do u think im evil?, consider using FS instead  - Marty
--	end

	Data.SCalMult = PlayerData["Data5"]
	Data.SubFrArea = Data.FrArea * math.min(PlayerData.Data5, Data.MaxCalMult) ^ 2
	Data.ProjMass = Data.SubFrArea * (Data.ProjLength * 7.9 / 1000) * 1.5 + (Data.FrArea - Data.SubFrArea) * (Data.ProjLength * 7.9 / 10000) --(Tungsten Core Mass + Sabot Exterior Mass) * Mass modifier used for bad aerodynamics
	Data.ShovePower = 0.4
	Data.PenArea = (Data.PenModifier * Data.SubFrArea) ^ ACE.PenAreaMod

	Data.DragCoef = ((Data.FrArea / 10000) / Data.ProjMass) * 0.5
	Data.CaliberMod = Data.Caliber * math.min(PlayerData.Data5, Data.MaxCalMult)
	Data.LimitVel = 900 --Most efficient penetration speed in m/s
	Data.KETransfert = 0.2 --Kinetic energy transfert to the target for movement purposes
	Data.MuzzleVel = ACE.MuzzleVelocity(Data.PropMass * 0.5, Data.ProjMass * 1.98, Data.Caliber)
	Data.BoomPower = Data.PropMass

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
	local Energy = ACE.Kinetic(Data.MuzzleVel * 39.37, Data.ProjMass, Data.LimitVel)
	GUIData.MaxPen = ACE.CalcPenetration(Energy, Data.PenArea, 1.055)

	return GUIData
end



function Round.network( Crate, BulletData )

	Crate:SetNWString( "AmmoType", "HVAP" )
	Crate:SetNWString( "AmmoID", BulletData.Id )
	Crate:SetNWFloat( "Caliber", BulletData.Caliber )
	Crate:SetNWFloat( "ProjMass", BulletData.ProjMass )
	Crate:SetNWFloat( "PropMass", BulletData.PropMass )
	Crate:SetNWFloat( "DragCoef", BulletData.DragCoef )
	Crate:SetNWFloat( "MuzzleVel", BulletData.MuzzleVel )
	Crate:SetNWFloat( "Tracer", BulletData.Tracer )

		--For propper bullet model
	Crate:SetNWFloat( "BulletModel", Round.model )

end

function Round.cratetxt( BulletData )

	--local FrArea = BulletData.FrArea
	local DData = Round.getDisplayData(BulletData)

	--fakeent.ACE.Armour = DData.MaxPen or 0
	--fakepen.Penetration = (DData.MaxPen * FrArea) / ACE.KEtoRHA
	--local fakepen = ACE_Kinetic( BulletData.SlugMV * 39.37 , BulletData.SlugMass, 9999999 )
	--local MaxHP = ACE_CalcDamage( fakeent , fakepen , FrArea , 0 )

	--[[
	local TotalMass = BulletData.ProjMass + BulletData.PropMass
	local MassUnit

	if TotalMass < 0.1 then
		TotalMass = TotalMass * 1000
		MassUnit = " g"
	else
		MassUnit = " kg"
	end
	]]--

	local str =
	{
		--"Cartridge Mass: ", math.Round(TotalMass, 2), MassUnit, "\n",
		"Muzzle Velocity: ", math.Round(BulletData.MuzzleVel, 1), " m/s\n",
		"Max Penetration: ", math.floor(DData.MaxPen), " mm"
		--"Max Pen. Damage: ", math.Round(MaxHP.Damage, 1), " HP\n",
	}

	return table.concat(str)

end

function Round.propimpact( _, Bullet, Target, HitNormal, HitPos, Bone )

	if ACE.Check( Target ) then

		local Speed = Bullet.Flight:Length() / ACE.VelScale
		local Energy = ACE.Kinetic( Speed , Bullet.ProjMass, Bullet.LimitVel )
		local HitRes = ACE.RoundImpact( Bullet, Speed, Energy, Target, HitPos, HitNormal , Bone )

		if HitRes.PostPenetration.Continue then
			table.insert( Bullet.Filter , Target )					--"Penetrate" (Ingoring the prop for the retry trace)
			ACE.Spall( HitPos , Bullet.Flight , Bullet.Filter , HitRes.PostPenetration.SpentKinetic , Bullet.Caliber , Target.ACE.Armour , Bullet.Owner , Target.ACE.Material) --Do some spalling
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
	util.Effect( "ACE_AP_Impact", Spall )

end

-- Bullet penetrated something
function Round.pierceeffect( _, Bullet )

	local Spall = EffectData()
		Spall:SetEntity( Bullet.Crate )
		Spall:SetOrigin( Bullet.SimPos )
		Spall:SetNormal( (Bullet.SimFlight):GetNormalized() )
		Spall:SetScale( Bullet.SimFlight:Length() )
		Spall:SetMagnitude( Bullet.RoundMass )
	util.Effect( "ACE_AP_Penetration", Spall )

end

-- Bullet ricocheted off something
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

	acemenupanel:AmmoSelect( ACE.AmmoBlacklist.HVAP )

	ACE.UpperCommonDataDisplay()

	acemenupanel:AmmoSlider("PropLength",0,0,1000,3, "Propellant Length", "")	--Propellant Length Slider (Name, Value, Min, Max, Decimals, Title, Desc)
	acemenupanel:AmmoSlider("ProjLength",0,0,1000,3, "Projectile Length", "")	--Projectile Length Slider (Name, Value, Min, Max, Decimals, Title, Desc)
	acemenupanel:AmmoSlider("SCalMult",0,0,1000,2, "Subcaliber Size Multiplier", "") --Subcaliber Slider (Name, Value, Min, Max, Decimals, Title, Desc)

	acemenupanel:AmmoCheckbox("Tracer", "Tracer", "")			--Tracer checkbox (Name, Title, Desc)
	acemenupanel:AmmoCheckbox("TwoPiece", "Enable Two Piece Storage", "", "" )

	acemenupanel:CPanelText("RicoDisplay", "")	--estimated rico chance
	acemenupanel:CPanelText("PenetrationDisplay", "")	--Proj muzzle penetration (Name, Desc)

	Round.guiupdate( Panel, Table )

end

function Round.guiupdate( Panel )

	local PlayerData = {}
		PlayerData.Id = acemenupanel.AmmoData.Data.id			--AmmoSelect GUI
		PlayerData.Type = "HVAP"										--Hardcoded, match as Round.Type instead
		PlayerData.PropLength = acemenupanel.AmmoData.PropLength	--PropLength slider
		PlayerData.ProjLength = acemenupanel.AmmoData.ProjLength	--ProjLength slider
		PlayerData.Data5 = acemenupanel.AmmoData.SCalMult
		PlayerData.Tracer	= acemenupanel.AmmoData.Tracer
		PlayerData.TwoPiece	= acemenupanel.AmmoData.TwoPiece
	local Data = Round.convert( Panel, PlayerData )

	RunConsoleCommand( "acemenu_data1", acemenupanel.AmmoData.Data.id )
	RunConsoleCommand( "acemenu_data2", PlayerData.Type )
	RunConsoleCommand( "acemenu_data3", Data.PropLength )		--For Gun ammo, Data3 should always be Propellant
	RunConsoleCommand( "acemenu_data4", Data.ProjLength )		--And Data4 total round mass
	RunConsoleCommand( "acemenu_data5", Data.SCalMult )
	RunConsoleCommand( "acemenu_data10", Data.Tracer )
	RunConsoleCommand( "acemenu_data11", Data.TwoPiece )

	acemenupanel:AmmoSlider("PropLength",Data.PropLength,Data.MinPropLength,Data.MaxTotalLength,3, "Propellant Length", "Propellant Mass : " .. (math.floor(Data.PropMass * 1000)) .. " g" )	--Propellant Length Slider (Name, Min, Max, Decimals, Title, Desc)
	acemenupanel:AmmoSlider("ProjLength",Data.ProjLength,Data.MinProjLength,Data.MaxTotalLength,3, "Projectile Length", "Projectile Mass : " .. (math.floor(Data.ProjMass * 1000)) .. " g")	--Projectile Length Slider (Name, Min, Max, Decimals, Title, Desc)

	acemenupanel:AmmoSlider("SCalMult",Data.SCalMult,Data.MinCalMult,Data.MaxCalMult,2, "Subcaliber Size Multiplier", "Caliber : " .. math.floor(Data.Caliber * math.min(PlayerData.Data5,Data.MaxCalMult) * 10) .. " mm") --Subcaliber round slider (Name, Min, Max, Decimals, Title, Desc)

	ACE.UpperCommonDataDisplay( Data, PlayerData )
	ACE.CommonDataDisplay( Data )

end

list.Set( "APRoundTypes", "HVAP", Round )
ACE.RoundTypes[Round.Type] = Round     --Set the round properties
ACE.IdRounds[Round.netid] = Round.Type --Index must equal the ID entry in the table above, Data must equal the index of the table above
