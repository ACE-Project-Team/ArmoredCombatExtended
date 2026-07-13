AddCSLuaFile()

-- Pricing models must load before their shared callers in both realms.
AddCSLuaFile("acf/shared/sh_ace_points_model.lua")
include("acf/shared/sh_ace_points_model.lua")

AddCSLuaFile("acf/shared/sh_ace_manufacturing.lua")
include("acf/shared/sh_ace_manufacturing.lua")

local floor, Clamp = math.floor, math.Clamp

-- returns last parent in chain, which has physics
function ACF_GetPhysicalParent( obj )
	if not IsValid(obj) then return nil end

	--check for fresh cached parent
	if obj.acfphysparent and ACF.CurTime < obj.acfphysstale then
		return obj.acfphysparent
	end

	local Parent = obj

	while IsValid(Parent:GetParent()) do
		Parent = Parent:GetParent()
	end

	--update cached parent
	obj.acfphysparent = Parent
	obj.acfphysstale = ACF.CurTime + 10 --when cached parent is considered stale and needs updating

	return Parent
end

--Calculates a position along a catmull-rom spline (as defined on https://www.mvps.org/directx/articles/catmull/)
--This is used for calculating engine torque curves
function ACF_CalcCurve(Points, Pos)
	local Count = #Points

	if Count < 3 then return 0 end

	if Pos <= 0 then
		return Points[1]
	elseif Pos >= 1 then
		return Points[Count]
	end

	local T	= (Pos * (Count - 1)) % 1
	local Current = math.floor(Pos * (Count - 1) + 1)
	local P0	= Points[Clamp(Current - 1, 1, Count - 2)]
	local P1	= Points[Clamp(Current, 1, Count - 1)]
	local P2	= Points[Clamp(Current + 1, 2, Count)]
	local P3	= Points[Clamp(Current + 2, 3, Count)]

	return 0.5 * ((2 * P1) +
		(P2 - P0) * T +
		(2 * P0 - 5 * P1 + 4 * P2 - P3) * T ^ 2 +
		(3 * P1 - P0 - 3 * P2 + P3) * T ^ 3)
end

--Calculates the performance characteristics of an engine, given a torque curve, max torque (in nm), idle, and redline rpm
function ACF_CalcEnginePerformanceData(curve, maxTq, idle, redline)
	local peakTq = 0
	local peakTqRPM
	local peakPower = 0
	local powerTable = {} --Power at each point on the curve for use in powerband calc
	local res = 32 --Iterations for use in calculating the curve, higher is more accurate

	--Calculate peak torque/power RPM
	for i = 0, res do
		local rpm = i / res * redline
		local perc = math.Remap(rpm, idle, redline, 0, 1)
		local curTq = ACF_CalcCurve(curve, perc)
		local power = maxTq * curTq * rpm / 9548.8

		powerTable[i] = power

		if power > peakPower then
			peakPower = power
			peakPowerRPM = rpm
		end

		if Clamp(curTq, 0, 1) > peakTq then
			peakTq = curTq
			peakTqRPM = rpm
		end
	end

	--Find the bounds of the powerband (within 10% of its peak)
	local powerbandMinRPM
	local powerbandMaxRPM

	for i = 0, res do
		local powerFrac = powerTable[i] / peakPower
		local rpm = i / res * redline

		if powerFrac > 0.9 and not powerbandMinRPM then
			powerbandMinRPM = rpm
		end

		if (powerbandMinRPM and powerFrac < 0.9 and not powerbandMaxRPM) or (i == res and not powerbandMaxRPM) then
			powerbandMaxRPM = rpm
		end
	end

	return {
		peakTqRPM = peakTqRPM,
		peakPower = peakPower,
		peakPowerRPM = peakPowerRPM,
		powerbandMinRPM = powerbandMinRPM,
		powerbandMaxRPM = powerbandMaxRPM
	}
end

-- A cheap way to check if the distance between 2 points is within a target distance.
function ACE_InDist( Pos1, Pos2, Distance )
	return (Pos2 - Pos1):LengthSqr() < Distance ^ 2
end

	-- Material Enum
	-- 65 ANTLION
	-- 66 BLOODYFLESH
	-- 67 CONCRETE / NODRAW
	-- 68 DIRT
	-- 70 FLESH
	-- 71 GRATE
	-- 72 ALIENFLESH
	-- 73 CLIP
	-- 76 PLASTIC
	-- 77 METAL
	-- 78 SAND
	-- 79 FOLIAGE
	-- 80 COMPUTER
	-- 83 SLOSH
	-- 84 TILE
	-- 86 VENT
	-- 87 WOOD
	-- 89 GLASS

function ACE_GetMaterialName( Mat )
	--concrete
	local GroundMat = "Concrete"

	--print(Mat)
	-- Dirt
	if Mat == 68 or Mat == 79 or Mat == 85 then
		GroundMat = "Dirt"
	--Sand
	elseif Mat == 78 then
	GroundMat = "Sand"
	--Metal
	elseif Mat == 77 or Mat == 86 or Mat == 80 then
	GroundMat = "Metal"
	--Snow
	elseif Mat == 74 then
	GroundMat = "Snow"
	--Glass
	elseif Mat == 89 then
		GroundMat = "Glass"
	elseif Mat == 87 then
		GroundMat = "Wood"
	elseif Mat == 66 or Mat == 70 then
		GroundMat = "Flesh"
	end

	--[[
	if GroundMat != "Concrete" then
	--print("GMat: "..GroundMat)
	else
	print("ID: "..Mat)
	end
	]]--

	return GroundMat
end

-- changes here will be automatically reflected in the armor properties tool
function ACF_CalcArmor( Area, Ductility, Mass )

	return ( Mass * 1000 / Area / 0.78 ) / ( 1 + Ductility ) ^ 0.5 * ACF.ArmorMod

end

function ACF_MuzzleVelocity( Propellant, Mass )

	local PEnergy	= ACF.PBase * ((1 + Propellant) ^ ACF.PScale-1)
	local Speed	= ((PEnergy * 2000 / Mass) ^ ACF.MVScale)
	local Final	= Speed -- - Speed * math.Clamp(Speed/2000,0,0.5)

	return Final
end

function ACF_Kinetic( Speed , Mass, LimitVel )

	LimitVel = LimitVel or 99999
	Speed = Speed / 39.37

	local Energy = {}
		Energy.Kinetic = (Mass * (Speed ^ 2)) / 2000 --Energy in KiloJoules
		Energy.Momentum = Speed * Mass

		local KE = (Mass * (Speed ^ ACF.KinFudgeFactor)) / 2000 + Energy.Momentum
		Energy.Penetration = math.max(KE - (math.max(Speed - LimitVel, 0) ^ 2) / (LimitVel * 5) * (KE / 200) ^ 0.95, KE * 0.1)

	return Energy
end

-- Convert kinetic penetration energy and projectile area to RHA penetration in mm.
function ACE_CalcPenetration(Energy, PenArea, PenMul)
	local EnergyPen = istable(Energy) and tonumber(Energy.Penetration) or tonumber(Energy)
	local Area = tonumber(PenArea)

	if not EnergyPen or not Area or Area <= 0 then return 0 end

	local Pen = (EnergyPen / Area) * (ACF.KEtoRHA or 0)

	if PenMul then
		Pen = Pen * PenMul
	end

	if Pen ~= Pen or Pen == math.huge or Pen == -math.huge then return 0 end

	return math.max(Pen, 0)
end

do

	--Convert old numeric IDs to the new string IDs
	local BackCompMat = {
		"RHA",
		"CHA",
		"Cer",
		"Rub",
		"ERA",
		"Alum",
		"Texto"
	}

	-- Global Ratio Setting Function
	function ACF_CalcMassRatio( obj, pwr )
		if not IsValid(obj) then return end
		local Mass		= 0
		local PhysMass	= 0
		local power		= 0
		local Compositions  = {}
		local MatSums	= {}
		local PercentMat	= {}

		-- find the physical parent highest up the chain
		local Parent = ACF_GetPhysicalParent(obj)

		-- get the shit that is physically attached to the vehicle
		local PhysEnts = ACF_GetAllPhysicalConstraints( Parent )

		-- add any parented but not constrained props you sneaky bastards
		local AllEnts = table.Copy( PhysEnts )
		for _, v in pairs( AllEnts ) do

			table.Merge( AllEnts, ACF_GetAllChildren( v ) )

		end

		for _, v in pairs( AllEnts ) do

			if IsValid( v ) then

				if v:GetClass() == "acf_engine" then
					local driverBoost = v.HasDriver and ACF.DriverTorqueBoost or 1
					power = power + (v.peakkw * 1.34 * driverBoost)
				end

				local phys = v:GetPhysicsObject()
				if IsValid( phys ) then

					Mass = Mass + phys:GetMass() --print("total mass of contraption: " .. Mass)

					if PhysEnts[ v ] then
						PhysMass = PhysMass + phys:GetMass()
					end

				end

				if pwr then
					local PhysObj = v:GetPhysicsObject()

					if IsValid(PhysObj) then

						local material		= v.ACF and v.ACF.Material or "RHA"

						--ACE doesnt update their material stats actively, so we need to update it manually here.
						if not isstring(material) then
							local Mat_ID = material + 1
							material = BackCompMat[Mat_ID]
						end

						Compositions[material]  = Compositions[material] or {}

						table.insert(Compositions[material], PhysObj:GetMass() )

					end
				end

			end
		end

		--Build the ratios here
		for _, v in pairs( AllEnts ) do
			v.acfphystotal	= PhysMass
			v.acftotal		= Mass
			v.acflastupdatemass = ACF.CurTime
		end

		obj.acfphystotal = obj.acfphystotal or PhysMass
		obj.acftotal = obj.acftotal or Mass
		obj.acflastupdatemass = ACF.CurTime

		if pwr then
			--Get mass Material composition here
			for material, tablemass in pairs(Compositions) do

				MatSums[material] = 0

				for _, mass in pairs(tablemass) do

					MatSums[material] = MatSums[material] + mass

				end

				--Gets the actual material percent of the contraption
				local totalMass = obj.acftotal or Mass
				if totalMass <= 0 then
					PercentMat[material] = 0
				else
					PercentMat[material] = MatSums[material] / totalMass
				end

			end
		end
		if pwr then return { Power = power, MaterialPercent = PercentMat, MaterialMass = MatSums } end
	end

end

--Checks if theres new versions for ACE
function ACF_UpdateChecking( )
	http.Fetch("https://raw.githubusercontent.com/ACE-Project-Team/ArmoredCombatExtended/master/lua/autorun/acf_globals.lua",function(contents)

		--maybe not the best way to get git but well......
		str = tostring("String:" .. contents)
		i,k = string.find(str,"ACF.Version =")

		local rev = tonumber(string.sub(str,k + 2,k + 4)) or 0

		if rev and ACF.Version == rev  and rev ~= 0 then

			print("[ACE | INFO]- You have the latest version! Current version: " .. rev)

		elseif rev and ACF.Version > rev and rev ~= 0 then

			print("[ACE | INFO]- You have an experimental version! Your version: " .. ACF.Version .. ". Main version: " .. rev)
		elseif rev == 0 then

			print("[ACE | ERROR]- Unable to find the latest version! Failed to connect to GitHub.")

		else

			print("[ACE | INFO]- A new version of ACE is available! Your version: " .. ACF.Version .. ". New version: " .. rev)
			if CLIENT then chat.AddText( Color( 255, 0, 0 ), "A newer version of ACE is available!" ) end

		end
		ACF.CurrentVersion = rev

	end, function()
		print("[ACE | ERROR]- Unable to find the latest version! No internet available.")

		ACF.CurrentVersion = 0
	end)
end


--Creates & updates ACE dupes.
--[[
-- USAGE:
	To Add a dupe, you have to put inside of your_addon_name/scripts/vehicles/>HERE< with the following naming:

	acedupe_[folder name]_[your dupe name].txt

	Note:
	- folder name must be ONE word (acecool, myaddon, tankpack, etc). It cannot have spaces!!!
	- your dupe name can have spaces, however, they must be '_' for the file. The loader will automatically change that symbol to spaces.

	Correct way examples:

	- acedupe_tanks_bmp2.txt
	- acedupe_cars_my_cool_car.txt
	- acedupe_thebest_the_best_of_the_best.txt
]]

do


	if CLIENT then

		concommand.Add( "ace_dupes_remount", function()

			if not AdvDupe2 then
				notification.AddLegacy( "Unable to reload the dupes.", NOTIFY_ERROR, 7)
				return
			end

			if file.Exists("acf/ace_dupespawn.txt", "DATA") then

				notification.AddLegacy( "Dupe files were reloaded!", NOTIFY_GENERIC, 7)
				file.Delete("acf/ace_dupespawn.txt")
				ACE_Dupes_Refresh()
			end
		end )

		function ACE_Dupes_Refresh()

			local files = file.Find("scripts/vehicles/acedupe_*.txt", "GAME")

			if files then

				local file_naming = {}

				local file_name
				local file_directory
				local file_exists
				local cfile_content
				local dupespawned = file.Exists("acf/ace_dupespawn.txt", "DATA")

				for _, txtfile in ipairs(files) do

					file_content   = file.Read("scripts/vehicles/" .. txtfile, "GAME") or ""
					file_naming    = string.Explode("_", txtfile)
					file_name      = table.concat( file_naming, " ", 3) -- Parses the file name
					file_name      = string.Replace( file_name, ".txt", "" )

					file_directory   = "advdupe2/ace " .. file_naming[2]
					file_exists      = file.Exists( file_directory .. "/" .. file_name .. ".txt", "DATA")

					if not file_exists then

						if not dupespawned then
							file.CreateDir(file_directory)
							file.Write(file_directory .. "/" .. file_name .. ".txt", file_content)

							print( "[ACE|INFO]- Creating dupe '" .. file_name .. "'' in " .. file_directory )
						end
					else
						--Idea: bring the analyzer from the internet instead of locally?
						cfile_content = file.Read(file_directory .. "/" .. file_name .. ".txt", "DATA") or ""

						if util.SHA256(cfile_content) ~= util.SHA256(file_content) then

							print("[ACE|INFO]- your dupe " .. file_name .. " is different/outdated! Updating....")

							file.Write(file_directory .. "/" .. file_name .. ".txt", file_content)

						end
					end
				end

				if not dupespawned then
					file.Write("acf/ace_dupespawn.txt", "This means, dupe loader will not populate the dupes if they were removed.")
				end
			end
		end

		timer.Simple(1,function()
			--Why do we need to create useless files if the user has not the advdupe2 in the first place.
			if not AdvDupe2 then
				return
			end

			ACE_Dupes_Refresh()
		end)

	end
end

timer.Simple(1, function()
	ACF_UpdateChecking()
end )


do

	--Used to reconvert old material ids
	ACE.BackCompMat = {
		[0] = "RHA",
		[1] = "CHA",
		[2] = "Cer",
		[3] = "Rub",
		[4] = "ERA",
		[5] = "Alum",
		[6] = "Texto"
	}

	--Dedicated function to get the material due to old numeric ids must be passed to the new string indexing now. Could change in a future.
	function ACE_GetMaterialData( Mat )

		if not ACE_CheckMaterial( Mat ) then

			Mat = not isstring(Mat) and ACE.BackCompMat[Mat] or "RHA"

			if not ACE_CheckMaterial( Mat ) then
				print("[ACE|ERROR]- No Armor material data found! Have the armor folder been renamed or removed? Unexpected results could occur!")
				return nil
			end
		end

		local MatData = ACE.ArmorTypes[Mat]

		return MatData
	end
end

--TODO: Use a universal function
function ACE_CheckMaterial( MatId )

	local matdata = ACE.ArmorTypes[ MatId ]

	if not matdata then return false end

	return true

end

function ACE_CheckRound( id )

	local rounddata = ACF.RoundTypes[ id ]

	if not rounddata then return false end

	return true
end

function ACE_CheckGun( gunid )

	local gundata = ACF.Weapons.Guns[ gunid ]

	if not gundata then return false end

	return true
end

function ACE_CheckRack( rackid )

	local rackdata = ACF.Weapons.Racks[ rackid ]

	if not rackdata then return false end

	return true
end

function ACE_CheckAmmo( ammoid )

	local Ammodata = ACF.Weapons.Ammo[ ammoid ]

	if not Ammodata then return false end

	return true
end

function ACE_CheckEngine( engineid )

	local enginedata = ACF.Weapons.Engines[ engineid ]

	if not enginedata then return false end

	return true
end

function ACE_CheckGearbox( gearid )

	local geardata = ACF.Weapons.Gearboxes[ gearid ]

	if not geardata then return false end

	return true
end

function ACE_CheckFuelTank( fueltankid )

	local fueltankid = ACF.Weapons.FuelTanksSize[ fueltankid ]

	if not fueltankid then return false end

	return true
end

if SERVER then
	function ACE_SendMsg(ply, ...)
		net.Start("ACE_SendMessage")
		net.WriteBool(false)
		net.WriteTable({...})
		net.Send(ply)
	end

	function ACE_SendNotification(ply, hint, duration)
		net.Start("ACE_SendMessage")
		net.WriteBool(true)
		net.WriteString(hint)
		net.WriteUInt(duration or 7, 8)
		net.Send(ply)
	end

	function ACE_BroadcastMsg(...)
		net.Start("ACE_SendMessage")
		net.WriteBool(false)
		net.WriteTable({...})
		net.Broadcast()
	end
else
	net.Receive("ACE_SendMessage", function()
		local isHint = net.ReadBool()

		if isHint then
			local hint = net.ReadString()
			local duration = net.ReadUInt(8)

			notification.AddLegacy(hint, NOTIFY_GENERIC, duration)
		else
			local msg = net.ReadTable()

			for k, v in pairs(msg) do
				if type(v) == "table" and #v == 4 then -- For some reason, color objects are sometimes converted to tables during networking?
					msg[k] = Color(v[1], v[2], v[3], v[4])
				end
			end

			chat.AddText(unpack(msg))
		end
	end)
end

--[[ IDK if this will take some usage
function ACE_Msg( type, txt )

	if not isstring(type) then
		ErrorNoHaltWithStack(( "bad argument #1 to 'type' (string expected, got " .. type( type ) .. ")" ))
		return
	end

	if not isstring(txt) then
		ErrorNoHaltWithStack(( "bad argument #2 to 'txt' (string expected, got " .. type( type ) .. ")" ))
		return
	end

	local Info

	if type == "warn"
		Info = "WARN"
	elseif type == "error"
		Info = "ERROR"
	elseif type == "info"
		Info = "INFO"
	end

	local prefix = "[ACE | " .. Info .. "]- "

	print( prefix .. txt )

end
]]

-- Helper function to check if a value exists in a table
function ACE_table_contains(table, element)
	for _, value in pairs(table) do
		if value == element then
			return true
		end
	end
	return false
end

local function GetDefaultActiveInput(ent, inputName)
	if not IsValid(ent) then return end

	local inputs = ent.Inputs
	local input = inputs and inputs[inputName or "Active"]

	if input and input.Src == nil then
		input.Value = 1
	end

	return input
end

function ACF.IsDefaultActiveInputWired(ent, inputName)
	local input = GetDefaultActiveInput(ent, inputName)

	return input and input.Src ~= nil
end

function ACF.GetDefaultActiveInputState(ent, value, inputName)
	if not IsValid(ent) then return false end

	local legal = ent.Legal ~= false
	local input = GetDefaultActiveInput(ent, inputName)

	if not input or input.Src == nil then return legal end

	local wireValue = value
	if wireValue == nil then wireValue = input.Value or 0 end

	return wireValue ~= 0 and legal
end

-- Radar/IRST-specific functions
if SERVER then
	local Indexes = {}
	local IndexCount = 0
	local Unused = {}

	--- Gets a unique ID for a contraption object
	---@param Contraption any
	---@return number ID The contraption's unique ID
	function ACE_GetContraptionIndex(Contraption)
		if Indexes[Contraption] then return Indexes[Contraption] end

		if next(Unused) then
			local Index = next(Unused)

			Indexes[Contraption] = Index
			Unused[Index] = nil
		else
			IndexCount = IndexCount + 1

			Indexes[Contraption] = IndexCount
		end

		local EntID = Indexes[Contraption]

		return EntID
	end

	function ACE_ClearContraptionIndex(Contraption)
		local Index = Indexes[Contraption]

		if Index then
			Indexes[Contraption] = nil
			Unused[Index] = true
		end
	end

	hook.Add("cfw.contraption.removed", "ACE_IndexTracking_ContraptionRemoved", ACE_ClearContraptionIndex)
	hook.Add("cfw.contraption.merged", "ACE_IndexTracking_ContraptionMerged", ACE_ClearContraptionIndex)

	--- Efficiently find the index to insert a value into a sorted table
	---@param Tbl table
	---@param Value number
	---@return number Index The index to insert the value at
	function ACE_GetBinaryInsertIndex(Tbl, Value)
		local Start = 1
		local Finish = #Tbl

		if not Tbl[1] then
			return 1
		end

		while Start < Finish do
			local Mid = floor((Start + Finish) / 2)
			if Value < Tbl[Mid] then
				Finish = Mid
			else
				Start = Mid + 1
			end
		end

		if Value < Tbl[Start] then
			return Start
		else
			return Start + 1
		end
	end
end

-- ============================================================
-- ACE points/cost helpers
-- ============================================================

-- Build a consistent description for ACE convars.
function ACE_ConVarHelp(desc)
	return "ACE - " .. desc
end

-- Helper: short IsValid wrapper for entities.
function ACE_IsEnt(ent)
	return IsValid(ent)
end

-- Check whether an entity is a Wiremod class.
function ACE_IsWireEntity(ent)
	if not ACE_IsEnt(ent) then return false end
	local cls = ent:GetClass()
	if not isstring(cls) then return false end
	return cls:sub(1, 10) == "gmod_wire_"
end

-- Check whether an entity is a missile entity.
function ACE_IsMissileEntity(ent)
	if not ACE_IsEnt(ent) then return false end
	local cls = ent:GetClass()
	return cls == "ace_missile" or cls == "acf_missile"
end

ACE.ArmorClasses = ACE.ArmorClasses or {
	prop_physics = true,
	primitive_shape = true,
	primitive_airfoil = true,
	primitive_rail_slider = true,
	primitive_slider = true,
	primitive_ladder = true
}

ACE.ClassToType = ACE.ClassToType or {
	acf_engine = "Engines",
	-- Gearboxes carry no peak power, so they are priced by the legacy ACEPoints lookup and
	-- bucketed with Electronics -- matching the points model, whose Engines category is
	-- engine peak-power only and whose Electronics category is the catch-all ACEPoints sum.
	acf_gearbox = "Electronics",
	acf_fueltank = "Ignore",
	acf_ammo = "Ignore",   -- Ammo is free: crates contribute zero points.
	-- Scalable explosives / bombs: MOUNTED ordnance costs points, stored ammo stays free. A
	-- charge bolted to an airframe is independently droppable, so it prices as one rack tube of
	-- itself (ACE_Points_ChargeEntCost, off its filler mass) rather than being free.
	ace_explosive = "Firepower",
	ace_explosive_prebuilt = "Firepower",
	ace_bomb_satchel = "Firepower",
	ace_bomb_aerial = "Firepower",
	ace_bomb_barrel = "Firepower",

	acf_gun = "Firepower",
	acf_rack = "Firepower",

	ace_crewseat_gunner = "Crew",
	ace_crewseat_loader = "Crew",
	ace_crewseat_driver = "Crew",

	ace_rwr_dir = "Electronics",
	ace_rwr_sphere = "Electronics",
	acf_missileradar = "Electronics",
	acf_opticalcomputer = "Electronics",
	ace_ecm = "Electronics",
	ace_trackingradar = "Electronics",
	ace_searchradar = "Electronics",
	ace_irst = "Electronics",
	ace_sonar = "Electronics",
	ace_gforce_meter = "Electronics",
	ace_vheat_source = "Electronics",
	ace_wind_sensor = "Electronics"
}

ACE.PointSubsystems = ACE.PointSubsystems or {
	"Engines",
	"Firepower",
	"Crew",
	"Electronics"
}

-- Resolve point category for an entity class.
function ACE_GetPtsType(className)
	if ACE.ArmorClasses[className] then return "Armor" end
	return ACE.ClassToType[className] or "Ignore"
end

function ACE_GetSurvivabilityIndex(ent)
	if not ACE_IsEnt(ent) then return 0 end

	local effMm, maxHealth = ACE_Points_PropArmor(ent)
	if not effMm or not maxHealth then return 0 end

	return math.max(ACE_Points_ArmorProp(effMm, maxHealth), 0)
end

function ACE_GetArmorPoints(ent)
	if not ACE_IsEnt(ent) then return 0 end

	if ACF_Check then
		ACF_Check(ent)
	end

	local cacheKey = ent:EntIndex()
	ACE.ArmorPointCache = ACE.ArmorPointCache or {}
	if ACE.ArmorPointCache[cacheKey] ~= nil then
		return ACE.ArmorPointCache[cacheKey]
	end

	local points = ACE_GetSurvivabilityIndex(ent)
	ACE.ArmorPointCache[cacheKey] = points

	return points
end

function ACE_GetCrewSeatPointCost(ent)
	local isLoader = ACE_IsEnt(ent) and ent:GetClass() == "ace_crewseat_loader"
	return ACE_Points_CrewCost(isLoader)
end

function ACE_ClearArmorPointCache(ent)
	if not ACE_IsEnt(ent) then return end
	if ACE.ArmorPointCache then
		ACE.ArmorPointCache[ent:EntIndex()] = nil
	end
end

hook.Add("EntityRemoved", "ACE_ClearArmorPointCache", function(ent)
	ACE_ClearArmorPointCache(ent)
end)


-- Extract configurable class name from "Name:arg=val" serialized strings.
function ACE_GetConfigurableName(value, fallback)
	if type(value) ~= "string" or value == "" then return fallback end

	local name = string.match(value, "^[^:]+")
	if not name or name == "" then return fallback end

	return name
end

-- Resolve the gun class string for ammo bullet data.
function ACE_GetAmmoGunClass(bdata)
	if not bdata then return nil end

	local gunClass = bdata.GunClass
	if gunClass and gunClass ~= "" then return gunClass end

	local gunData = (bdata.Id and ACF and ACF.Weapons and ACF.Weapons.Guns and ACF.Weapons.Guns[bdata.Id]) or nil
	return gunData and gunData.gunclass or nil
end

-- Determine whether an ammo type is a GLATGM family type.
function ACE_IsGLATGMAmmoType(ammoType)
	return ammoType == "GLATGM" or ammoType == "GLATGM-HE"
end

-- Resolve the most authoritative ammo type for an entity/bullet pair.
function ACE_ResolveAmmoType(ent, bdata)
	if ACE_IsEnt(ent) then
		local entType = ent.RoundType
		if isstring(entType) and entType ~= "" then return entType end

		if ent.GetNWString then
			local nwType = ent:GetNWString("AmmoType", "")
			if nwType ~= "" then return nwType end
		end
	end

	if bdata then
		local btype = bdata.Type or bdata.RoundType
		if isstring(btype) and btype ~= "" then return btype end
	end

	return ""
end

-- Resolve missile warhead behavior from ammo type.
function ACE_GetMissileWarheadType(ammoType)
	if ammoType == "GLATGM" then return "HEAT" end
	if ammoType == "GLATGM-HE" then return "HE" end
	return ammoType
end

-- Resolve explosion class used by ammo cookoff logic.
function ACE_GetAmmoCookoffClass(_, isMissile)
	if isMissile then return "MISSILE" end
	return "AMMO"
end

-- Resolve blast filler used by ammo cookoff logic.
function ACE_GetAmmoCookoffBlastMass(_, bdata)
	if not bdata then return 0 end

	local boom = tonumber(bdata.BoomFillerMass)
	if boom and boom > 0 then return boom end

	local filler = tonumber(bdata.FillerMass) or 0
	if filler > 0 then return filler end

	return 0
end

-- Resolve how many rounds are assumed to sympathetically detonate.
function ACE_GetAmmoCookoffAmmoCount(_, ammoCount, isMissile)
	local count = tonumber(ammoCount) or 0
	if count <= 0 then return 0 end

	if isMissile then
		return math.max(1, count * 0.15)
	end

	return count
end

-- Resolve propellant contribution multiplier by cookoff class.
function ACE_GetAmmoCookoffPropScale(cookClass)
	if cookClass == "HEAT" then return 0 end
	if cookClass == "MISSILE" then return 0.08 end
	return 1
end

-- Resolve storage scaling by cookoff class.
function ACE_GetAmmoCookoffStorageScale(cookClass, ammoScale, missileScale)
	local defaultAmmoScale = tonumber(ammoScale) or 0.55
	local defaultMissileScale = tonumber(missileScale) or 0.35

	if cookClass == "MISSILE" then return defaultMissileScale end
	return defaultAmmoScale
end

-- Determine whether bullet data should be treated as missile ammo.
function ACE_IsAmmoMissileType(bdata)
	if not bdata then return false end
	if ACE_IsGLATGMAmmoType(bdata.Type) then return true end

	local gunClass = ACE_GetAmmoGunClass(bdata)
	if not gunClass then return false end

	local classes = ACF and ACF.Classes and ACF.Classes.GunClass
	local classData = classes and classes[gunClass] or nil

	return classData and classData.type == "missile" or false
end

-- Compute a gun's configured sustained RPS from its current setup.
function ACE_GetGunConfiguredRps(ent, rofLimit)
	if not ACE_IsEnt(ent) or ent:GetClass() ~= "acf_gun" then return 0 end

	local bdata = ent.BulletData or {}
	local roundVolume = tonumber(bdata.RoundVolume)
	if not roundVolume or roundVolume <= 0 then
		local reload = tonumber(ent.ReloadTime)
		local baseRps = reload and reload > 0 and 1 / reload or (tonumber(ent.RateOfFire) or 0) / 60
		local limitRps = (tonumber(rofLimit) or 0) / 60
		if limitRps > 0 then return math.min(baseRps, limitRps) end
		return baseRps
	end

	local adj = tonumber(bdata.LengthAdj) or 1
	local fireRateModifier = (tonumber(ent.RoFmod) or 1) * (tonumber(ent.PGRoFmod) or 1)

	local crate = bdata.Crate and Entity(bdata.Crate) or nil
	if ACE_IsEnt(crate) and crate.RoFMul then
		fireRateModifier = fireRateModifier * (crate.RoFMul + 1)
	end

	local defaultReloadTime = ((math.max(roundVolume, (tonumber(ent.MinLengthBonus) or 0) / adj) / 500) ^ 0.60) * fireRateModifier
	local lowestReloadTime = defaultReloadTime
	local maxRof = tonumber(ent.maxrof) or 0
	rofLimit = tonumber(rofLimit) or 0

	if rofLimit > 0 and maxRof > 0 then
		maxRof = math.min(maxRof, rofLimit)
	elseif rofLimit > 0 then
		maxRof = rofLimit
	end

	if maxRof > 0 then
		lowestReloadTime = 60 / maxRof
	end

	local reloadTime = math.max(defaultReloadTime, lowestReloadTime)

	if reloadTime <= 0 then return 0 end

	return 1 / reloadTime
end

-- Best-scoring candidate round used by both pricing and readout: linked crates, contraption
-- crates by Id, then the gun's own round.
local function ACE_ResolveGunBestRound(gun, conEnts)
	if not ACE_IsEnt(gun) then return nil end

	local best, bestScore, scored = nil, -1, false
	local function consider(bdata)
		local round = ACE_Points_RoundFromBullet(bdata)
		if not round then return end
		local score = ACE_Points_RoundScore(round)
		if score > bestScore then best, bestScore = round, score end
		scored = true
	end

	local link = gun.AmmoLink
	if istable(link) then
		for _, crate in pairs(link) do
			if ACE_IsEnt(crate) and istable(crate.BulletData) then consider(crate.BulletData) end
		end
	end

	if not scored and istable(conEnts) then
		for _, ent in ipairs(conEnts) do
			if ACE_IsEnt(ent) and ent:GetClass() == "acf_ammo" and istable(ent.BulletData)
				and ent.BulletData.Id == gun.Id then
				consider(ent.BulletData)
			end
		end
	end

	if not scored and istable(gun.BulletData) then consider(gun.BulletData) end

	return best
end

-- Best-scoring candidate round for a rack, mirroring ACE_Points_RackBestScore (linked crates
-- -> the rack's own non-Empty round). Readout-only. Returns the round table or nil.
local function ACE_ResolveRackBestRound(rack)
	if not ACE_IsEnt(rack) then return nil end

	local best, bestScore, scored = nil, -1, false
	local function consider(bdata)
		local round = ACE_Points_RoundFromBullet(bdata)
		if not round then return end
		local score = ACE_Points_RoundScore(round)
		if score > bestScore then best, bestScore = round, score end
		scored = true
	end

	local link = rack.AmmoLink
	if istable(link) then
		for _, crate in pairs(link) do
			if ACE_IsEnt(crate) and istable(crate.BulletData) then consider(crate.BulletData) end
		end
	end

	if not scored and istable(rack.BulletData) then
		local rtype = rack.BulletData.Type
		if rtype and rtype ~= "" and rtype ~= "Empty" then consider(rack.BulletData) end
	end

	return best
end

-- Callers may supply a cached contraption entity list for gun round selection.
function ACE_GetGunFirepowerPointsFor(ent, conEnts)
	if not ACE_IsEnt(ent) then return 0 end

	local class = ent:GetClass()
	if class == "acf_rack" then
		return ACE_Points_RackCost(ent.ReloadTime, ent.MaxMissile, ACE_Points_RackBestScore(ent))
	end
	if class ~= "acf_gun" then return 0 end

	local round = ACE_ResolveGunBestRound(ent, conEnts)
	if not round then return ACE_Points_GunCost(ACE_Points_GunSustainedRps(ent), 0, 0) end

	return ACE_Points_GunCost(ACE_Points_GunSustainedRps(ent),
		ACE_Points_BaseRoundCost(round),
		ACE_Points_Gate(ACE_Points_GatePen(round)))
end

-- Resolves gun round candidates from the contraption when no list is supplied.
function ACE_GetGunFirepowerPoints(ent)
	if not ACE_IsEnt(ent) then return 0 end

	local class = ent:GetClass()
	if class == "acf_rack" then
		return ACE_GetGunFirepowerPointsFor(ent, nil)
	end
	if class ~= "acf_gun" then return 0 end

	local con = ACE_GetContraptionFromEntity(ent)
	local conEnts = con and ACE_GetContraptionEntities(con, ent) or {}
	return ACE_GetGunFirepowerPointsFor(ent, conEnts)
end

-- Returns rate/s, threat, base round cost, round type, and round data for the priced candidate.
local function ACE_GetGunFirepowerDetail(ent, conEnts)
	if not ACE_IsEnt(ent) then return end

	local class = ent:GetClass()
	local round, rate

	if class == "acf_gun" then
		round = ACE_ResolveGunBestRound(ent, conEnts)
		rate  = ACE_Points_GunSustainedRps(ent)
	elseif class == "acf_rack" then
		round = ACE_ResolveRackBestRound(ent)
		rate = ACE_Points_RackRate(ent.ReloadTime, ent.MaxMissile)
	else
		return
	end

	if not round then return rate end

	return rate, ACE_Points_Gate(ACE_Points_GatePen(round)), ACE_Points_BaseRoundCost(round), round.Type, round
end

function ACE_GetGunFirepowerReadout(ent, conEnts)
	if not ACE_IsEnt(ent) then return end

	if ent:GetClass() == "acf_gun" and conEnts == nil then
		local con = ACE_GetContraptionFromEntity(ent)
		conEnts = con and ACE_GetContraptionEntities(con, ent) or {}
	end

	local rate, threat, baseRoundCost, roundType, round = ACE_GetGunFirepowerDetail(ent, conEnts)
	local points
	if ent:GetClass() == "acf_rack" then
		points = ACE_Points_RackCost(ent.ReloadTime, ent.MaxMissile,
			(tonumber(baseRoundCost) or 0) * (tonumber(threat) or 0))
	else
		points = ACE_Points_GunCost(rate, baseRoundCost, threat)
	end
	local model = ACE.PointsModel or {}
	local firepowerScale = (tonumber(model.kGun) or 0) * (tonumber(model.Scale) or 0)
	local rawPoints = (tonumber(rate) or 0)
		* (tonumber(threat) or 0)
		* (tonumber(baseRoundCost) or 0)
		* firepowerScale

	return {
		Points = points,
		Rate = rate,
		Threat = threat,
		BaseRoundCost = baseRoundCost,
		FirepowerScale = firepowerScale,
		RawPoints = rawPoints,
		MinimumApplied = points > rawPoints + 0.01,
		RoundType = roundType,
		Round = round
	}
end

function ACE_GetGunFirepowerPricingLine(readout)
	if not istable(readout) then return end
	if not readout.Rate or not readout.Threat or not readout.BaseRoundCost then return end

	return string.format("%.3f/s x %.1f%% threat x %s base x %.4f scale = %s pts",
		readout.Rate,
		readout.Threat * 100,
		string.Comma(math.Round(readout.BaseRoundCost)),
		readout.FirepowerScale,
		string.Comma(math.Round(readout.RawPoints)))
end

-- Formats the lethality factors used by the points model.
function ACE_GetRoundLethalityLine(round)
	if not istable(round) then return nil end

	local base, hole, blast = ACE_Points_PostPenParts(round)
	local dmg = base + hole + blast
	if dmg <= 0 then return nil end

	local rawPen = tonumber(round.maxPen) or 0
	local pen = ACE_Points_LethalityPen(round)
	local penLabel = (pen > rawPen + 0.5) and "mm blast-pen" or "mm pen"

	local line = string.format("%s %d%s x %.2f dmg (%d + %.2f hole + %.2f blast)",
		round.Type or "Round", math.Round(pen), penLabel, dmg, base, hole, blast)

	local guid = ACE_Points_GuidanceMul(round)
	if guid ~= 1.0 then
		line = line .. string.format(" x %.1f guidance", guid)
	end

	return line
end

-- Extract HE filler mass from bullet data.
function ACE_GetAmmoBlastMass(bdata)
	if not bdata then return 0 end
	return tonumber(bdata.BoomFillerMass) or tonumber(bdata.FillerMass) or 0
end

-- Resolve maximum penetration from bullet data.
function ACE_GetAmmoMaxPen(bdata)
	if not bdata then return 0 end

	local maxPen = tonumber(bdata.MaxPen) or 0
	if bdata.MaxPen2 then
		maxPen = math.max(maxPen, tonumber(bdata.MaxPen2) or 0)
	end
	if maxPen > 0 then return maxPen end

	local rtype = bdata.Type
	local round = rtype and ACF and ACF.RoundTypes and ACF.RoundTypes[rtype]
	if round and round.getDisplayData then
		local ok, display = pcall(round.getDisplayData, bdata)
		if ok and istable(display) then
			maxPen = math.max(maxPen, display.MaxPen or 0, display.MaxPen2 or 0)
		end
	end
	if maxPen > 0 then return maxPen end

	local filler  = bdata.BoomFillerMass or bdata.FillerMass or 0
	local hePower = ACF and ACF.HEPower or 0
	local blastDiv = ACF and ACF.HEBlastPenetration or 0
	if filler <= 0 or hePower <= 0 or blastDiv <= 0 then return 0 end

	return (filler * hePower) / blastDiv
end

-- Link anchor of a weapon with no CFW contraption of its own: the FIRST valid linked crate
-- that has one. Exactly one contraption adopts (and bills) such a weapon, deterministically.
function ACE_GetWeaponAnchorContraption(weapon)
	if not ACE_IsEnt(weapon) then return end
	for _, crate in ipairs(weapon.AmmoLink or {}) do
		if ACE_IsEnt(crate) then
			local con = ACE_GetContraptionFromEntity(crate)
			if con then return con end
		end
	end
end

-- Collect entities belonging to a contraption. BILLING RULE: every entity prices in exactly
-- ONE contraption -- its own. The one exception: a gun/rack with no contraption of its own
-- (parent-only builds) is adopted by its link anchor's contraption (above). This keeps
-- link-only weapons priced without double-billing: a weapon reachable from two fragments
-- (its own turret + the hull holding its crates) must bill to exactly one contraption, not both.
-- Do NOT walk the AmmoLink/Master graph outward to gather members -- that reaches such a weapon
-- from both fragments and prices it in each, inflating Firepower and Engine totals.
function ACE_GetContraptionEntities(con, fallbackEnt)
	local ents = {}
	local visited = {}

	local function add(ent)
		if not ACE_IsEnt(ent) then return end
		if visited[ent] then return end

		visited[ent] = true
		ents[#ents + 1] = ent
	end

	if con and con.ents then
		for ent in pairs(con.ents) do
			add(ent)
		end

		local members = #ents
		for i = 1, members do
			local cur = ents[i]
			if cur:GetClass() == "acf_ammo" and istable(cur.Master) then
				for _, weapon in pairs(cur.Master) do
					if ACE_IsEnt(weapon) and not visited[weapon]
						and not ACE_GetContraptionFromEntity(weapon)
						and ACE_GetWeaponAnchorContraption(weapon) == con then
						add(weapon)
					end
				end
			end
		end
	end

	if #ents == 0 and ACE_IsEnt(fallbackEnt) then
		add(fallbackEnt)
	end

	table.sort(ents, function(a, b)
		return a:EntIndex() < b:EntIndex()
	end)

	return ents
end

-- ============================================================
-- ACE parsing/get helpers
-- ============================================================

-- Resolve a contraption wrapper for an entity.
function ACE_GetContraptionFromEntity(ent)
	if not ACE_IsEnt(ent) or not ent.GetContraption then return end
	local con = ent:CFW_GetContraption()
	if not con or not con.ents or table.IsEmpty(con.ents) then return end
	return con
end

-- Resolve contraption owner for messages.
function ACE_GetContraptionOwner(con)
	if not con then return nil end
	local base = con.GetACEBaseplate and con:GetACEBaseplate()
	if not ACE_IsEnt(base) or not base.CPPIGetOwner then return nil end
	local owner = base:CPPIGetOwner()
	return ACE_IsEnt(owner) and owner or nil
end

-- Safely format an owner name.
function ACE_GetOwnerName(owner)
	return ACE_IsEnt(owner) and owner:Nick() or "Unknown"
end

-- Armor and firepower are priced by their dedicated passes; ammo is free. Remaining
-- component ACEPoints values are treated as electronics tiers and scaled with the model.
function ACE_GetEntPoints(ent)
	if not ACE_IsEnt(ent) then return 0 end

	local class = ent:GetClass()
	if (ACE.ArmorClasses and ACE.ArmorClasses[class])
		or class == "acf_fueltank"
		or class == "acf_ammo"
		or class == "acf_gun"
		or class == "acf_rack" then
		return 0
	end

	if class == "acf_engine" then
		return ACE_Points_EngineCost((tonumber(ent.peakkw) or 0) / 0.7457, ent.FuelType)
	end

	if class == "ace_crewseat_gunner" or class == "ace_crewseat_loader"
		or class == "ace_crewseat_driver" then
		return ACE_GetCrewSeatPointCost(ent)
	end

	if class == "ace_explosive" or class == "ace_explosive_prebuilt"
		or class == "ace_bomb_satchel" or class == "ace_bomb_aerial"
		or class == "ace_bomb_barrel" then
		return ACE_Points_ChargeEntCost(ent)
	end

	local scale = (ACE.PointsModel and ACE.PointsModel.Scale) or 1
	return (tonumber(ent.ACEPoints) or 0) * scale
end



