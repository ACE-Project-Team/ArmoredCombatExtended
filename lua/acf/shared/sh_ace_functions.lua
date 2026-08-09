AddCSLuaFile()

-- Pricing models must load before their shared callers in both realms.
AddCSLuaFile("acf/shared/sh_ace_points_model.lua")
include("acf/shared/sh_ace_points_model.lua")

AddCSLuaFile("acf/shared/sh_ace_manufacturing.lua")
include("acf/shared/sh_ace_manufacturing.lua")

local floor, Clamp = math.floor, math.Clamp

-- returns last parent in chain, which has physics
function ACE_GetPhysicalParent( obj, ForceRefresh )
	if not IsValid(obj) then return nil end

	--check for fresh cached parent
	if not ForceRefresh and obj.acfphysparent and ACE.CurTime < obj.acfphysstale then
		return obj.acfphysparent
	end

	local Parent = obj
	local Seen = {}
	local Depth = 0
	local Cycle = false
	obj.ACEPhysicalParentIssue = nil

	while IsValid(Parent) and Depth < 64 and not Seen[Parent] do
		Seen[Parent] = true
		local NextParent = Parent:GetParent()
		if not IsValid(NextParent) then break end
		if Seen[NextParent] then Cycle = true break end
		Parent = NextParent
		Depth = Depth + 1
	end

	if Depth >= 64 then
		obj.ACEPhysicalParentIssue = "Physical parent chain too deep"
	elseif Cycle then
		obj.ACEPhysicalParentIssue = "Physical parent cycle"
	end

	--update cached parent
	obj.acfphysparent = Parent
	obj.acfphysstale = ACE.CurTime + 10 --when cached parent is considered stale and needs updating

	return Parent
end

--Calculates a position along a catmull-rom spline (as defined on https://www.mvps.org/directx/articles/catmull/)
--This is used for calculating engine torque curves
function ACE_CalcCurve(Points, Pos)
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
function ACE_CalcEnginePerformanceData(curve, maxTq, idle, redline)
	local peakTq = 0
	local peakTqRPM
	local peakPower = 0
	local powerTable = {} --Power at each point on the curve for use in powerband calc
	local res = 32 --Iterations for use in calculating the curve, higher is more accurate

	--Calculate peak torque/power RPM
	for i = 0, res do
		local rpm = i / res * redline
		local perc = math.Remap(rpm, idle, redline, 0, 1)
		local curTq = ACE.CalcCurve(curve, perc)
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
function ACE_CalcArmor( Area, Ductility, Mass )

	return ( Mass * 1000 / Area / 0.78 ) / ( 1 + Ductility ) ^ 0.5 * ACE.ArmorMod

end

function ACE_MuzzleVelocity( Propellant, Mass )

	local PEnergy	= ACE.PBase * ((1 + Propellant) ^ ACE.PScale-1)
	local Speed	= ((PEnergy * 2000 / Mass) ^ ACE.MVScale)
	local Final	= Speed -- - Speed * math.Clamp(Speed/2000,0,0.5)

	return Final
end

function ACE_Kinetic( Speed , Mass, LimitVel )

	LimitVel = LimitVel or 99999
	Speed = Speed / 39.37

	local Energy = {}
		Energy.Kinetic = (Mass * (Speed ^ 2)) / 2000 --Energy in KiloJoules
		Energy.Momentum = Speed * Mass

		local KE = (Mass * (Speed ^ ACE.KinFudgeFactor)) / 2000 + Energy.Momentum
		Energy.Penetration = math.max(KE - (math.max(Speed - LimitVel, 0) ^ 2) / (LimitVel * 5) * (KE / 200) ^ 0.95, KE * 0.1)

	return Energy
end

-- Convert kinetic penetration energy and projectile area to RHA penetration in mm.
function ACE_CalcPenetration(Energy, PenArea, PenMul)
	local EnergyPen = istable(Energy) and tonumber(Energy.Penetration) or tonumber(Energy)
	local Area = tonumber(PenArea)

	if not EnergyPen or not Area or Area <= 0 then return 0 end

	local Pen = (EnergyPen / Area) * (ACE.KEtoRHA or 0)

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
	function ACE_CalcMassRatio( obj, pwr )
		if not IsValid(obj) then return end
		local Mass		= 0
		local PhysMass	= 0
		local power		= 0
		local Compositions  = {}
		local MatSums	= {}
		local PercentMat	= {}

		-- find the physical parent highest up the chain
		local Parent = ACE.GetPhysicalParent(obj)

		-- get the shit that is physically attached to the vehicle
		local PhysEnts = ACE.GetAllPhysicalConstraints( Parent )

		-- add any parented but not constrained props you sneaky bastards
		local AllEnts = table.Copy( PhysEnts )
		for _, v in pairs( AllEnts ) do

			table.Merge( AllEnts, ACE.GetAllChildren( v ) )

		end

		for _, v in pairs( AllEnts ) do

			if IsValid( v ) then

				if v:GetClass() == "acf_engine" then
					local driverBoost = v.HasDriver and ACE.DriverTorqueBoost or 1
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
			v.acflastupdatemass = ACE.CurTime
		end

		obj.acfphystotal = obj.acfphystotal or PhysMass
		obj.acftotal = obj.acftotal or Mass
		obj.acflastupdatemass = ACE.CurTime

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
function ACE_UpdateChecking( )
	http.Fetch("https://raw.githubusercontent.com/ACE-Project-Team/ArmoredCombatExtended/master/lua/autorun/acf_globals.lua",function(contents)

		--maybe not the best way to get git but well......
		local str = tostring("String:" .. contents)
		local _, versionEnd = string.find( str, "ACE.Version =" )

		if not versionEnd then
			_, versionEnd = string.find( str, "ACF.Version =" )
		end

		if not versionEnd then
			print( "[ACE | ERROR]- Unable to find the latest version! Failed to parse GitHub response." )
			return
		end

		local rev = tonumber( string.sub( str, versionEnd + 2, versionEnd + 4 ) ) or 0

		if rev and ACE.Version == rev  and rev ~= 0 then

			print("[ACE | INFO]- You have the latest version! Current version: " .. rev)

		elseif rev and ACE.Version > rev and rev ~= 0 then

			print("[ACE | INFO]- You have an experimental version! Your version: " .. ACE.Version .. ". Main version: " .. rev)
		elseif rev == 0 then

			print("[ACE | ERROR]- Unable to find the latest version! Failed to connect to GitHub.")

		else

			print("[ACE | INFO]- A new version of ACE is available! Your version: " .. ACE.Version .. ". New version: " .. rev)
			if CLIENT then chat.AddText( Color( 255, 0, 0 ), "A newer version of ACE is available!" ) end

		end
		ACE.CurrentVersion = rev

	end, function()
		print("[ACE | ERROR]- Unable to find the latest version! No internet available.")

		ACE.CurrentVersion = 0
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
				ACE.Dupes_Refresh()
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

			ACE.Dupes_Refresh()
		end)

	end
end

timer.Simple(1, function()
	ACE.UpdateChecking()
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

		if not ACE.CheckMaterial( Mat ) then

			Mat = not isstring(Mat) and ACE.BackCompMat[Mat] or "RHA"

			if not ACE.CheckMaterial( Mat ) then
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

	local rounddata = ACE.RoundTypes[ id ]

	if not rounddata then return false end

	return true
end

function ACE_CheckGun( gunid )

	local gundata = ACE.Weapons.Guns[ gunid ]

	if not gundata then return false end

	return true
end

function ACE_CheckRack( rackid )

	local rackdata = ACE.Weapons.Racks[ rackid ]

	if not rackdata then return false end

	return true
end

function ACE_CheckAmmo( ammoid )

	local Ammodata = ACE.Weapons.Ammo[ ammoid ]

	if not Ammodata then return false end

	return true
end

function ACE_CheckEngine( engineid )

	local enginedata = ACE.Weapons.Engines[ engineid ]

	if not enginedata then return false end

	return true
end

function ACE_CheckGearbox( gearid )

	local geardata = ACE.Weapons.Gearboxes[ gearid ]

	if not geardata then return false end

	return true
end

function ACE_CheckFuelTank( fueltankid )

	local fueltankid = ACE.Weapons.FuelTanksSize[ fueltankid ]

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
		input.ACFDefaultValue = input.ACFDefaultValue or 1
		input.Value = input.ACFDefaultValue
	end

	return input
end

function ACF.SetDefaultActiveInputState(ent, value, inputName)
	local input = GetDefaultActiveInput(ent, inputName)

	if input and input.Src == nil then
		input.ACFDefaultValue = value ~= 0 and 1 or 0
		input.Value = input.ACFDefaultValue

		return true
	end

	return false
end

function ACF.HasDefaultActiveInputState(ent, inputName)
	if not IsValid(ent) then return false end

	local inputs = ent.Inputs
	local input = inputs and inputs[inputName or "Active"]

	return input and input.ACFDefaultValue ~= nil or false
end

function ACF.IsDefaultActiveInputWired(ent, inputName)
	return ACE_IsDefaultActiveInputWired(ent, inputName)
end

function ACE_IsDefaultActiveInputWired(ent, inputName)
	local input = GetDefaultActiveInput(ent, inputName)

	return input and input.Src ~= nil
end

function ACF.GetDefaultActiveInputState(ent, value, inputName)
	return ACE_GetDefaultActiveInputState(ent, value, inputName)
end

function ACE_GetDefaultActiveInputState(ent, value, inputName)
	if not IsValid(ent) then return false end

	local legal = ent.Legal ~= false
	local input = GetDefaultActiveInput(ent, inputName)

	if not input then return legal end
	if input.Src == nil then return input.ACFDefaultValue ~= 0 and legal end

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

ACE.IsEnt = ACE_IsEnt

-- Check whether an entity is a Wiremod class.
function ACE_IsWireEntity(ent)
	if not ACE.IsEnt(ent) then return false end
	local cls = ent:GetClass()
	if not isstring(cls) then return false end
	return cls:sub(1, 10) == "gmod_wire_"
end

-- Check whether an entity is a missile entity.
function ACE_IsMissileEntity(ent)
	if not ACE.IsEnt(ent) then return false end
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
	-- itself (ACE.Points.ChargeEntCost, off its filler mass) rather than being free.
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
	if not ACE.IsEnt(ent) then return 0 end

	local effMm, maxHealth, massEfficiency = ACE.Points.PropArmor(ent)
	if not effMm or not maxHealth then return 0 end

	return math.max(ACE.Points.ArmorProp(effMm, maxHealth, massEfficiency), 0)
end

function ACE_GetArmorPoints(ent)
	if not ACE.IsEnt(ent) then return 0 end

	local previousACF = ent.ACF
	local previousMaxArmour = previousACF and previousACF.MaxArmour
	local previousMaxHealth = previousACF and previousACF.MaxHealth
	local previousMaterial = previousACF and previousACF.Material
	local previousFallbackMaterial = ent.ACF_Material

	local primitiveArmorPending = ent.IsPrimitive and (
		ent.ACE_PrimitiveRestoreSavedArmor or ent.ACE_PrimitiveArmorPending
	)
	if ACE.Check and not primitiveArmorPending then
		ACE.Check(ent)
	end

	local cacheKey = ent:EntIndex()
	ACE.ArmorPointCache = ACE.ArmorPointCache or {}

	local currentACF = ent.ACF
	if previousMaxArmour ~= (currentACF and currentACF.MaxArmour)
		or previousMaxHealth ~= (currentACF and currentACF.MaxHealth)
		or previousMaterial ~= (currentACF and currentACF.Material)
		or previousFallbackMaterial ~= ent.ACF_Material then
		ACE.ArmorPointCache[cacheKey] = nil
	end

	if ACE.ArmorPointCache[cacheKey] ~= nil then
		return ACE.ArmorPointCache[cacheKey]
	end

	local points = ACE.GetSurvivabilityIndex(ent)
	ACE.ArmorPointCache[cacheKey] = points

	return points
end

function ACE_GetCrewSeatPointCost(ent)
	local isLoader = ACE.IsEnt(ent) and ent:GetClass() == "ace_crewseat_loader"
	return ACE.Points.CrewCost(isLoader)
end

function ACE_ClearArmorPointCache(ent)
	if not ACE.IsEnt(ent) then return end
	if ACE.ArmorPointCache then
		ACE.ArmorPointCache[ent:EntIndex()] = nil
	end
end

hook.Add("EntityRemoved", "ACE_ClearArmorPointCache", function(ent)
	ACE.ClearArmorPointCache(ent)
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

	local gunData = (bdata.Id and ACF and ACE.Weapons and ACE.Weapons.Guns and ACE.Weapons.Guns[bdata.Id]) or nil
	return gunData and gunData.gunclass or nil
end

-- Determine whether an ammo type is a GLATGM family type.
function ACE_IsGLATGMAmmoType(ammoType)
	return ammoType == "GLATGM" or ammoType == "GLATGM-HE"
end

-- Resolve the most authoritative ammo type for an entity/bullet pair.
function ACE_ResolveAmmoType(ent, bdata)
	if ACE.IsEnt(ent) then
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
	if ACE.IsGLATGMAmmoType(bdata.Type) then return true end

	local gunClass = ACE.GetAmmoGunClass(bdata)
	if not gunClass then return false end

	local classes = ACF and ACE.Classes and ACE.Classes.GunClass
	local classData = classes and classes[gunClass] or nil

	return classData and classData.type == "missile" or false
end

-- Compute a gun's sustained RPS for one explicit ammo configuration.
function ACE_GetGunConfiguredRps(ent, rofLimit, bdata, crate)
	if not ACE.IsEnt(ent) or ent:GetClass() ~= "acf_gun" then return 0 end

	bdata = bdata or {}

	local roundVolume = tonumber(bdata.RoundVolume)
	if not roundVolume or roundVolume <= 0 then
		local length = (tonumber(bdata.ProjLength) or 0) + (tonumber(bdata.PropLength) or 0)
		roundVolume = (tonumber(bdata.FrArea) or 0) * length
	end

	local adj = tonumber(bdata.LengthAdj) or 1
	if adj <= 0 then adj = 1 end

	-- Missing candidate geometry falls back to the gun's definition-derived minimum volume,
	-- never the cadence of whichever round is currently loaded.
	local minRoundVolume = (tonumber(ent.MinLengthBonus) or 0) / adj
	if not roundVolume or roundVolume <= 0 then
		if minRoundVolume <= 0 then return 0 end
		roundVolume = 0
	end

	local safe = ACE.Points and ACE.Points.SafeNonNegative or function(value)
		local number = tonumber(value) or 0
		if number ~= number or number == math.huge or number == -math.huge then return 0 end
		return math.max(number, 0)
	end
	local function positiveModifier(value)
		local number = tonumber(value)
		if not number or number ~= number or number == math.huge or number == -math.huge or number <= 0 then
			return 1
		end
		return number
	end
	local fireRateModifier = positiveModifier(ent.RoFmod) * positiveModifier(ent.PGRoFmod)

	if ACE.IsEnt(crate) and crate.RoFMul then
		fireRateModifier = fireRateModifier * (1 + math.min(safe(crate.RoFMul), 100))
	end

	local defaultReloadTime = ((math.max(roundVolume, minRoundVolume) / 500) ^ 0.60) * fireRateModifier
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

-- Resolve the reload time attached to a rack ammo candidate, never its live tube state.
function ACE_GetRackConfiguredReloadTime(rack, bdata)
	if not ACE.IsEnt(rack) or rack:GetClass() ~= "acf_rack" then return 1 end

	local reload
	if istable(bdata) then
		reload = ACE.GetRackValue(bdata, "reloadspeed") or ACE.GetGunValue(bdata.Id, "reloadspeed")
	end
	if reload == nil then reload = ACE.GetRackValue(rack.Id, "magreload") end

	reload = tonumber(reload) or 1
	return reload > 0 and reload or 1
	end

-- Resolve the complete linked gun configuration with the highest final rate x round score.
local function resolveGunPricingCandidate(gun)
	if not ACE.IsEnt(gun) then return end

	local best
	local function consider(bdata, crate)
		local round = ACE.Points.RoundFromBullet(bdata)
		if not round then return end

		local rate = ACE.Points.GunSustainedRps(gun, bdata, crate)
		local roundScore = ACE.Points.RoundScore(round)
		local candidate = {
			Round = round,
			Rate = rate,
			RoundScore = roundScore,
			FinalScore = rate * roundScore,
			SourceIndex = ACE.IsEnt(crate) and crate:EntIndex() or math.huge,
		}

		if ACE.Points.IsBetterCandidate(candidate, best) then best = candidate end
	end

	for _, crate in pairs(gun.AmmoLink or {}) do
		if ACE.IsEnt(crate) and istable(crate.BulletData) then consider(crate.BulletData, crate) end
end

	return best
	end

-- Resolve the complete rack configuration with the highest final rate x round score.
local function resolveRackPricingCandidate(rack)
	if not ACE.IsEnt(rack) then return end

	local best
	for _, crate in pairs(rack.AmmoLink or {}) do
		if ACE.IsEnt(crate) and istable(crate.BulletData) then
			local round = ACE.Points.RoundFromBullet(crate.BulletData)
			if round then
				local reload = ACE.GetRackConfiguredReloadTime(rack, crate.BulletData)
				local rate = ACE.Points.RackRate(reload, rack.MaxMissile)
				local roundScore = ACE.Points.RoundScore(round)
				local candidate = {
					Round = round,
					Rate = rate,
					RoundScore = roundScore,
					FinalScore = rate * roundScore,
					SourceIndex = crate:EntIndex(),
				}

				if ACE.Points.IsBetterCandidate(candidate, best) then best = candidate end
			end
		end
	end

	return best
end

local function resolveWeaponPricingInputs(ent)
	if not ACE.IsEnt(ent) then return end

	local class = ent:GetClass()
	if class ~= "acf_gun" and class ~= "acf_rack" then return end

	local candidate = class == "acf_gun"
		and resolveGunPricingCandidate(ent)
		or resolveRackPricingCandidate(ent)
	local round = candidate and candidate.Round
	local rate = candidate and candidate.Rate or 0
	local threat = round and ACE.Points.Gate(ACE.Points.GatePen(round)) or 0
	local baseRoundCost = round and ACE.Points.BaseRoundCost(round) or 0
	local gunnerMultiplier = class == "acf_gun"
		and (ACE.Points.HasLegalGunner(ent) and 1 or 2)
		or 1
	local roundScore = threat * baseRoundCost
	local points = class == "acf_gun"
		and ACE.Points.GunCost(rate, baseRoundCost, threat, gunnerMultiplier)
		or ACE.Points.RackCostFromRate(rate, roundScore)
	local model = ACE.PointsModel or {}
	local firepowerScale = (tonumber(model.kGun) or 0) * (tonumber(model.Scale) or 0)
	local rawPoints = rate * roundScore * firepowerScale * gunnerMultiplier
	local rateFloor = ACE.Points.RateFloor and ACE.Points.RateFloor() or 0
	-- Compare against the FLOORED rate's raw product, not the true rate's -- otherwise every
	-- floor-affected weapon falsely reads as having hit the flat weapon minimum instead.
	local flooredRate = (rateFloor > 0) and math.max(rate, rateFloor) or rate
	local flooredRawPoints = flooredRate * roundScore * firepowerScale
	local minimumApplied = points > flooredRawPoints + 0.01

	return {
		Points = points,
		Rate = rate,
		Threat = threat,
		BaseRoundCost = baseRoundCost,
		GunnerMultiplier = gunnerMultiplier,
		FirepowerScale = firepowerScale,
		RawPoints = rawPoints,
		MinimumApplied = minimumApplied,
		-- Distinct from MinimumApplied: this is the delivery-rate floor, not the flat weapon
		-- minimum, and can engage on builds pricing well above the flat floor. Mutually
		-- exclusive with MinimumApplied so a build shows exactly one accurate notice.
		RateFloorApplied = not minimumApplied and rate > 0 and rate < rateFloor,
		RateFloorSeconds = rateFloor > 0 and (1.0 / rateFloor) or 0,
		RoundType = round and round.Type,
		Round = round
	}
end

function ACE_GetGunFirepowerPointsFor(ent, _)
	local readout = resolveWeaponPricingInputs(ent)
	return readout and readout.Points or 0
end

function ACE_GetGunFirepowerPoints(ent)
	return ACE.GetGunFirepowerPointsFor(ent, nil)
end

function ACE_GetGunFirepowerReadout(ent, _)
	return resolveWeaponPricingInputs(ent)
end

function ACE_GetGunFirepowerPricingLine(readout, menuFormat)
	if not istable(readout) then return end
	if readout.Points == nil then return end
	return "Points: " .. string.Comma(math.Round(readout.Points))
end

function ACE_GetGunnerMultiplierLine(readout)
	if not istable(readout) or (readout.GunnerMultiplier or 1) <= 1 then return end
	return "No Gunner: " .. tostring(readout.GunnerMultiplier) .. "x Firepower Cost"
end

-- Tells a player when their weapon priced off the delivery-rate floor instead of its true,
-- slower rate -- distinct from the flat weapon minimum, and can fire well above it.
function ACE_GetRateFloorLine(readout, menuFormat)
	if not istable(readout) or not readout.RateFloorApplied then return end

	if not menuFormat then
		return string.format("Slow-Fire Floor Applied: rate priced at 1 round / %.0fs (true rate %.3f/s)",
			readout.RateFloorSeconds or 0, readout.Rate or 0)
	end

	return string.format("Slow-Fire Floor Applied: rate priced at %.1f rpm (true rate %.1f rpm)",
		(readout.RateFloorSeconds or 0) > 0 and (60 / readout.RateFloorSeconds) or 0,
		(readout.Rate or 0) * 60)
end

-- Formats the lethality factors used by the points model.
function ACE_GetRoundLethalityLine(round, menuFormat)
	if not istable(round) then return nil end

	local base, hole, blast = ACE.Points.PostPenParts(round)
	local dmg = base + hole + blast
	if dmg <= 0 then return string.format("%s utility round", round.Type or "Unspecified") end

	local rawPen = tonumber(round.maxPen) or 0
	local pen = ACE.Points.LethalityPen(round)
	local penLabel = (pen > rawPen + 0.5) and "mm HE-equiv" or "mm pen"

	local line
	if menuFormat then
		line = string.format("%s %.1f%s x %.1f dmg",
			round.Type or "Round", pen, penLabel, dmg)
	else
		line = string.format("%s %d%s x %.2f dmg (%d + %.2f hole + %.2f blast)",
			round.Type or "Round", math.Round(pen), penLabel, dmg, base, hole, blast)
	end

	local guid = ACE.Points.GuidanceMul(round)
	if guid ~= 1.0 then
		line = line .. string.format(" x %.1f guidance", guid)
	end
	local intrinsicValue = ACE.Points.IntrinsicValueMul(round)
	if intrinsicValue ~= 1.0 then
		line = line .. string.format(" x %.1f HE utility", intrinsicValue)
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
	local round = rtype and ACF and ACE.RoundTypes and ACE.RoundTypes[rtype]
	if round and round.getDisplayData then
		local ok, display = pcall(round.getDisplayData, bdata)
		if ok and istable(display) then
			maxPen = math.max(maxPen, display.MaxPen or 0, display.MaxPen2 or 0)
		end
	end
	if maxPen > 0 then return maxPen end

	local filler  = bdata.BoomFillerMass or bdata.FillerMass or 0
	local hePower = ACF and ACE.HEPower or 0
	local blastDiv = ACF and ACE.HEBlastPenetration or 0
	if filler <= 0 or hePower <= 0 or blastDiv <= 0 then return 0 end

	return (filler * hePower) / blastDiv
end

-- Link anchor of a weapon with no CFW contraption of its own: the valid linked crate with the
-- lowest EntIndex that has a contraption. Exactly one contraption adopts (and bills) such a
-- weapon, independently of the order in which crates were linked.
function ACE_GetWeaponAnchorContraption(weapon)
	if not ACE.IsEnt(weapon) then return end

	local anchor
	local anchorIndex

	for _, crate in pairs(weapon.AmmoLink or {}) do
		if ACE.IsEnt(crate) then
			local con = ACE.GetContraptionFromEntity(crate)
			if con then
				local crateIndex = crate:EntIndex()
				if not anchorIndex or crateIndex < anchorIndex then
					anchor = con
					anchorIndex = crateIndex
				end
			end
		end
	end

	return anchor
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
		if not ACE.IsEnt(ent) then return end
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
					if ACE.IsEnt(weapon) and not visited[weapon]
						and not ACE.GetContraptionFromEntity(weapon)
						and ACE.GetWeaponAnchorContraption(weapon) == con then
						add(weapon)
					end
				end
			end
		end
	end

	if #ents == 0 and ACE.IsEnt(fallbackEnt) then
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
	if not ACE.IsEnt(ent) or not ent.CFW_GetContraption then return end
	local con = ent:CFW_GetContraption()
	if not con or not con.ents or table.IsEmpty(con.ents) then return end
	return con
end

-- Resolve contraption owner for messages.
function ACE_GetContraptionOwner(con)
	if not con then return nil end
	local base = con.GetACEBaseplate and con:GetACEBaseplate()
	if not ACE.IsEnt(base) or not base.CPPIGetOwner then return nil end
	local owner = base:CPPIGetOwner()
	return ACE.IsEnt(owner) and owner or nil
end

-- Safely format an owner name.
function ACE_GetOwnerName(owner)
	return ACE.IsEnt(owner) and owner:Nick() or "Unknown"
end

-- Armor and gun/rack firepower are priced by their dedicated passes; configured crates bill
-- their configuration (never their round count). Remaining component ACEPoints values are
-- treated as electronics tiers and scaled with the model.
function ACE_GetEntPoints(ent)
	if not ACE.IsEnt(ent) then return 0 end

	local class = ent:GetClass()
	if (ACE.ArmorClasses and ACE.ArmorClasses[class])
		or class == "acf_fueltank"
		or class == "acf_gun"
		or class == "acf_rack" then
		return 0
	end

	if class == "acf_engine" then
		return ACE.Points.EngineCost((tonumber(ent.peakkw) or 0) / 0.7457, ent.FuelType)
	end

	if class == "ace_crewseat_gunner" or class == "ace_crewseat_loader"
		or class == "ace_crewseat_driver" then
		return ACE.GetCrewSeatPointCost(ent)
	end

	if class == "ace_explosive" or class == "ace_explosive_prebuilt"
		or class == "ace_bomb_satchel" or class == "ace_bomb_aerial"
		or class == "ace_bomb_barrel" then
		return ACE.Points.ChargeEntCost(ent)
	end

	local scale = (ACE.PointsModel and ACE.PointsModel.Scale) or 1
	return (tonumber(ent.ACEPoints) or 0) * scale
end
