
AddCSLuaFile()

local Round = {}

Round.type = "Ammo" --Tells the spawn menu what entity to spawn
Round.name = "[Supply] - " .. ACE.Translation.ShellRef[1] --Human readable name
Round.model = "models/munitions/round_100mm_shot.mdl" --Shell flight model
Round.desc = ACE.Translation.ShellRef[2]

Round.Type  = "Refill"

-- Function to convert the player's slider data into the complete round data
function Round.convert()

	local BulletData = {}
		BulletData.Id = "7.62mmMG"
		BulletData.Type = "Refill"

		BulletData.Caliber = 1
		BulletData.ProjMass = 1 --Volume of the projectile as a cylinder * streamline factor (Data5) * density of steel
		BulletData.PropMass = 1 --Volume of the case as a cylinder * Powder density converted from g to kg
		BulletData.FillerMass = 0
		BulletData.DragCoef = 0
		BulletData.Tracer = 0
		BulletData.MuzzleVel = 0
		BulletData.RoundVolume = 1

	return BulletData

end


function Round.getDisplayData()
	return {}
end


function Round.network( Crate, BulletData )

	Crate:SetNWString( "AmmoType", "Refill" )
	Crate:SetNWString( "AmmoID", BulletData.Id )
	Crate:SetNWFloat( "Caliber", BulletData.Caliber )
	Crate:SetNWFloat( "ProjMass", BulletData.ProjMass )
	Crate:SetNWFloat( "FillerMass", BulletData.FillerMass )
	Crate:SetNWFloat( "PropMass", BulletData.PropMass )
	Crate:SetNWFloat( "DragCoef", BulletData.DragCoef )
	Crate:SetNWFloat( "MuzzleVel", BulletData.MuzzleVel )
	Crate:SetNWFloat( "Tracer", BulletData.Tracer )

end

function Round.cratetxt()

	return ""

end

function Round.guicreate( Panel, Table )

	acemenupanel:AmmoSelect()
	acemenupanel:CPanelText("Desc", ACE.Translation.ShellRef[2])	--Description (Name, Desc)
	Round.guiupdate( Panel, Table )

end

function Round.guiupdate()

	RunConsoleCommand( "acemenu_data1", acemenupanel.CData.AmmoId )
	RunConsoleCommand( "acemenu_data2", "Refill")

	acemenupanel.CustomDisplay:PerformLayout()

end

list.Set( "SPECSRoundTypes", "Refill", Round )
ACE.RoundTypes[Round.Type] = Round     --Set the round properties
