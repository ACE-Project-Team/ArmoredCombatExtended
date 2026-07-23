
AddCSLuaFile()

local Round = {}

ACF.AmmoBlacklist.CAP = { "MG", "AC", "HMG","RAC", "ATR", "SL", "GL", "FFAR", "FGL", "ATR", "SBC", "AAM", "ATGM", "ASR", "SAM" }

Round.type  = "Ammo" --Tells the spawn menu what entity to spawn
Round.name  = "[CLUSTER-AP] - " .. ACFTranslation.ShellAP[1] --Human readable name
Round.model = "models/missiles/glatgm/9m112f.mdl" --Shell flight model
Round.desc  = ACFTranslation.ShellAP[2]
Round.netid = 25 --Unique ammotype ID for network transmission

Round.Type  = "CAP"

-- Function to convert the player's slider data into the complete round data
function Round.convert( _, PlayerData )

	local Data		= {}
	local ServerData	= {}
	local GUIData	= {}

	PlayerData.PropLength	=  PlayerData.PropLength	or 0
	PlayerData.ProjLength	=  PlayerData.ProjLength	or 0
	PlayerData.Tracer	=  PlayerData.Tracer		or 0
	PlayerData.TwoPiece	=  PlayerData.TwoPiece	or 0
	PlayerData.Data13		= math.max(PlayerData.Data13 or 0, 5) --ClusterMult
	PlayerData.Data14		= math.max(PlayerData.Data14 or 2000, 500) --ExplodeDistance

	PlayerData, Data, ServerData, GUIData = ACF_RoundBaseGunpowder( PlayerData, Data, ServerData, GUIData )

	--Shell sturdiness calcs

	--Volume of the projectile as a cylinder - Volume of the filler * density of steel + Volume of the filler * density of TNT
	Data.ProjMass		= math.max(GUIData.ProjVolume,0) * 7.9 / 1000 * 2 --Tungsten carbide is roughly twice as dense as steel.
	Data.MuzzleVel		= ACF_MuzzleVelocity( Data.PropMass, Data.ProjMass, Data.Caliber )

	GUIData.ClusterMult = math.Clamp(PlayerData.Data13, 10, 100)
	Data.ClusterMult = GUIData.ClusterMult

	GUIData.FuseDistance = math.Clamp(PlayerData.Data14, 500, 6000)
	Data.FuseDistance = GUIData.FuseDistance

	--Random bullshit left
	Data.ShovePower		= 0.1
	Data.PenArea			= Data.FrArea ^ ACF.PenAreaMod
	Data.DragCoef		= ((Data.FrArea / 10000) / Data.ProjMass)
	Data.LimitVel		= 100									-- Most efficient penetration speed in m/s
	Data.KETransfert		= 0.1									-- Kinetic energy transfert to the target for movement purposes
	Data.Ricochet		= 70										-- Base ricochet angle
	Data.DetonatorAngle	= 70

	Data.BoomPower		= Data.PropMass

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
	GUIData.BombletCount = math.Round(math.Clamp(math.Round(Data.ProjMass * 0.2),5,120) * Data.ClusterMult / 100)
	return GUIData
end


function Round.network( Crate, BulletData )

	Crate:SetNWString( "AmmoType", "CAP" )
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

	local DData = Round.getDisplayData(BulletData)

	local str =
	{
		"Muzzle Velocity: ", math.Round(BulletData.MuzzleVel, 1), " m/s\n",
		"Submunition Count: ", DData.BombletCount, "\n"
	}

	return table.concat(str)

end

function Round.propimpact( _, Bullet, Target, HitNormal, HitPos, Bone )

	if ACF_Check( Target ) then
		local Speed	= Bullet.Flight:Length() / ACF.VelScale
		local Energy	= ACF_Kinetic( Speed , Bullet.ProjMass, Bullet.LimitVel )
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

	local function GenerateCluster(bdata)

		--local RoundType = bdata.Type

		--Make cluster to fail. Allow with rounds on whitelist only.
		--if not WhiteList[RoundType] then return end

		local Bomblets  = math.Round(math.Clamp(math.Round(bdata.ProjMass * 0.3),10,240) * (bdata.ClusterMult or 100) / 100)	--30 bomblets original

		local GEnt = bdata.Gun
		local Filter = istable(bdata.Filter) and table.Copy(bdata.Filter) or { GEnt }

		GEnt.BulletDataC = {}

		GEnt.BulletDataC.Bomblets = Bomblets

		GEnt.BulletDataC["Accel"]			= Vector(0,0,-600)
		GEnt.BulletDataC["BoomPower"]		= bdata.BoomPower

		GEnt.BulletDataC["Caliber"] 		= 0.001 --Controls visual size, does nothing else
		GEnt.BulletDataC["Crate"]			= bdata.Crate
		GEnt.BulletDataC["DragCoef"]		= 0

		--print(GEnt.BulletDataC["FillerMass"])
		--print(Bomblets)
		--print(missile.BulletDataC["FillerMass"])

		GEnt.BulletDataC["Filter"]		= Filter
		GEnt.BulletDataC["Flight"]		= bdata.Flight
		GEnt.BulletDataC["FlightTime"]	= 0
		GEnt.BulletDataC["FrArea"]		= bdata.FrArea
		GEnt.BulletDataC["FuseLength"]	= 0
		GEnt.BulletDataC["Gun"]			= GEnt
		GEnt.BulletDataC["Id"]			= bdata.Id
		GEnt.BulletDataC["KETransfert"]	= bdata.KETransfert
		GEnt.BulletDataC["LimitVel"]		= 700
		GEnt.BulletDataC["MuzzleVel"]		= 30
		--GEnt.BulletDataC["MuzzleVel"]		= bdata.MuzzleVel * 20
		GEnt.BulletDataC["Owner"]			= bdata.Owner
		GEnt.BulletDataC["PenArea"]		= bdata.PenArea
		GEnt.BulletDataC["Pos"]			= bdata.Pos
		GEnt.BulletDataC["ProjLength"]	= bdata.ProjLength / Bomblets / 2
		GEnt.BulletDataC["ProjMass"]		= bdata.ProjMass / Bomblets
		GEnt.BulletDataC["PropLength"]	= bdata.PropLength
		GEnt.BulletDataC["PropMass"]		= bdata.PropMass
		GEnt.BulletDataC["Ricochet"]		= 90--bdata.Ricochet

		GEnt.BulletDataC.FuseLength = 1 --Cluster munitions shouldn't travel that far
		--print(bdata.Ricochet)

		GEnt.BulletDataC["RoundVolume"]	= bdata.RoundVolume
		GEnt.BulletDataC["ShovePower"]	= bdata.ShovePower
		GEnt.BulletDataC["Tracer"]		= 0


		--GEnt.BulletDataC["Type"]		= bdata.Type
		GEnt.BulletDataC["Type"]		= "AP"

		GEnt.FakeCrate = GEnt.FakeCrate or ents.Create("acf_fakecrate2")

		GEnt.FakeCrate:RegisterTo(GEnt.BulletDataC)
		GEnt.BulletDataC["Crate"] = GEnt.FakeCrate:EntIndex()

		GEnt:DeleteOnRemove(GEnt.FakeCrate)

	end

	local function CreateCluster(bullet)

		local GEnt = bullet.Gun

		local MuzzleVec = bullet.Flight:GetNormalized()
		GEnt.BulletDataC = GEnt.BulletDataC or {}
		local MuzzleSpeed = bullet.Flight:Length() + (GEnt.BulletDataC["MuzzleVel"] or 0) * 2 * 39.37
		local GunBData = GEnt.BulletDataC or {}
		local CCount = GunBData.Bomblets or 0

		for I = 1, CCount do
			--print("Bobm")
			timer.Simple(0.01 * I, function()
				if IsValid(GEnt) then
					--Spread = ((GEnt:GetUp() * (2 * math.random() - 1)) + (GEnt:GetRight() * (2 * math.random() - 1))) * (I - 1) / 45
					local Spread = VectorRand()
					--Spread = Spread
					Spread = Vector(Spread.x * math.abs(Spread.x), Spread.y * math.abs(Spread.y), Spread.z * math.abs(Spread.z))
					--GEnt.BulletDataC["Flight"] = (MuzzleVec + ( Spread * math.min((GEnt.BulletDataC.Bomblets/10) * 0.1 , 0.65))):GetNormalized() * GEnt.BulletDataC["MuzzleVel"] * 39.37 * math.Rand(0.5,1.0)
					GEnt.BulletDataC["Flight"] = (MuzzleVec + ( Spread * 0.2)):GetNormalized() * MuzzleSpeed --Fixed scatter pattern since we're using the detonate offset to control spread.

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

			ACF_HE( Bullet.Pos - Bullet.Flight:GetNormalized() * 3, Bullet.Flight:GetNormalized(), Bullet.ProjMass / 100, Bullet.ProjMass - Bullet.ProjMass / 100, Bullet.Owner, nil, Bullet.Gun ) --Seperation airbursts. Fillermass reduced by 20 because it's the seperation charge.
			local GunEnt = Bullet.Gun
			if IsValid(GunEnt) then
				--print("Valid")
				CreateCluster(Bullet,GunEnt.BulletData) --(bullet, bdata)
			end
			ACF_RemoveBullet( Index )


		end


	end

	function Round.endflight(Index, Bullet)
		ACF_BulletClient( Index, Bullet, "Update", 1, Bullet.Pos  ) --Ends the bullet flight on the clientside

		ACF_HE( Bullet.Pos - Bullet.Flight:GetNormalized() * 3, Bullet.Flight:GetNormalized(), Bullet.ProjMass / 100, Bullet.ProjMass - Bullet.ProjMass / 100, Bullet.Owner, nil, Bullet.Gun ) --Seperation airbursts. Fillermass reduced by 20 because it's the seperation charge.
		local GunEnt = Bullet.Gun
		if IsValid(GunEnt) then
			--print("Valid")
			CreateCluster(Bullet,GunEnt.BulletData) --(bullet, bdata)
		end
		ACF_RemoveBullet( Index )
	end

end

function Round.endeffect( _, Bullet )

	local Radius = (Bullet.RoundMass / 50) ^ 0.33 * 8 * 39.37 --Fillermass reduced by 20 because it's the seperation charge.
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

	acfmenupanel:AmmoSelect(ACF.AmmoBlacklist.CAP)

	acfmenupanel:CPanelText("CrateInfoBold", "Crate information:", "DermaDefaultBold")

	acfmenupanel:CPanelText("BonusDisplay", "")

	acfmenupanel:CPanelText("Desc", "") --Description (Name, Desc)
	acfmenupanel:CPanelText("BoldAmmoStats", "Round information: ", "DermaDefaultBold")
	acfmenupanel:CPanelText("LengthDisplay", "")	--Total round length (Name, Desc)
	acfmenupanel:CPanelText("VelocityDisplay", "")  --Proj muzzle velocity (Name, Desc)

	acfmenupanel:AmmoSlider("PropLength",0,0,1000,3, "Propellant Length", "")	--Slider (Name, Value, Min, Max, Decimals, Title, Desc)
	acfmenupanel:AmmoSlider("ProjLength",0,0,1000,3, "Projectile Length", "")	--Slider (Name, Value, Min, Max, Decimals, Title, Desc)

	acfmenupanel:AmmoSlider("ClusterMult",0,0,100,1, "Cluster Multiplier (%)", "")
	acfmenupanel:AmmoSlider("FuseDistance",0,500,6000,2, "Cluster Fuse Distance", "")

	ACE.Checkboxes()

	Round.guiupdate( Panel, Table )

end

function Round.guiupdate( Panel )

	local PlayerData = {}
		PlayerData.Id		= acfmenupanel.AmmoData.Data.id		--AmmoSelect GUI
		PlayerData.Type		= "CAP"									--Hardcoded, match as Round.Type instead
		PlayerData.PropLength	= acfmenupanel.AmmoData.PropLength  --PropLength slider
		PlayerData.ProjLength	= acfmenupanel.AmmoData.ProjLength  --ProjLength slider
		PlayerData.Data13		= acfmenupanel.AmmoData.ClusterMult
		PlayerData.Data14		= acfmenupanel.AmmoData.FuseDistance
		PlayerData.Tracer	= acfmenupanel.AmmoData.Tracer
		PlayerData.TwoPiece	= acfmenupanel.AmmoData.TwoPiece

	local Data = Round.convert( Panel, PlayerData )

	RunConsoleCommand( "acfmenu_data1", acfmenupanel.AmmoData.Data.id )
	RunConsoleCommand( "acfmenu_data2", PlayerData.Type )
	RunConsoleCommand( "acfmenu_data3", Data.PropLength )	--For Gun ammo, Data3 should always be Propellant
	RunConsoleCommand( "acfmenu_data4", Data.ProjLength )	--And Data4 total round mass
	RunConsoleCommand( "acfmenu_data13", Data.ClusterMult )
	RunConsoleCommand( "acfmenu_data14", Data.FuseDistance )
	RunConsoleCommand( "acfmenu_data10", Data.Tracer )
	RunConsoleCommand( "acfmenu_data11", Data.TwoPiece )

	---------------------------Ammo Capacity-------------------------------------
	ACE.AmmoCapacityDisplay( Data )
	-------------------------------------------------------------------------------
	acfmenupanel:CPanelText("VelocityDisplay", "Muzzle Velocity : " .. math.floor(Data.MuzzleVel * ACF.VelScale) .. " m/s") --Proj muzzle velocity (Name, Desc)

	acfmenupanel:AmmoSlider("PropLength", Data.PropLength, Data.MinPropLength, Data.MaxTotalLength, 3, "Propellant Length", "Propellant Mass : " .. (math.floor(Data.PropMass * 1000)) .. " g" .. "/ " .. (math.Round(Data.PropMass, 1)) .. " kg" )  --Propellant Length Slider (Name, Min, Max, Decimals, Title, Desc)
	acfmenupanel:AmmoSlider("ProjLength", Data.ProjLength, Data.MinProjLength, Data.MaxTotalLength, 3, "Projectile Length", "Projectile Mass : " .. (math.floor(Data.ProjMass * 1000)) .. " g" .. "/ " .. (math.Round(Data.ProjMass, 1)) .. " kg")  --Projectile Length Slider (Name, Min, Max, Decimals, Title, Desc)	--Projectile Length Slider (Name, Min, Max, Decimals, Title, Desc)

	acfmenupanel:AmmoSlider("ClusterMult",Data.ClusterMult,10,100,1, "Cluster Multiplier (%)", "Bomblets: " .. Data.BombletCount)	--HE Filler Slider (Name, Min, Max, Decimals, Title, Desc)
	acfmenupanel:AmmoSlider("FuseDistance",Data.FuseDistance,500,6000,2, "Cluster Fuse Distance", "")	--HE Filler Slider (Name, Min, Max, Decimals, Title, Desc)

	ACE.Checkboxes( Data )

	acfmenupanel:CPanelText("Desc", ACF.RoundTypes[PlayerData.Type].desc) --Description (Name, Desc)
	acfmenupanel:CPanelText("LengthDisplay", "Round Length : " .. (math.floor((Data.PropLength + Data.ProjLength + (math.floor(Data.Tracer * 5) / 10)) * 100) / 100) .. "/" .. Data.MaxTotalLength .. " cm") --Total round length (Name, Desc)

	---------------------------Chance of Ricochet table----------------------------

	acfmenupanel:CPanelText("RicoDisplay", "Max Detonation angle: " .. Data.DetonatorAngle .. "°")

	-------------------------------------------------------------------------------
end

list.Set("SPECSRoundTypes", Round.Type, Round ) --Set the round on chemical folder
ACF.RoundTypes[Round.Type] = Round     --Set the round properties
ACF.IdRounds[Round.netid] = Round.Type --Index must equal the ID entry in the table above, Data must equal the index of the table above
