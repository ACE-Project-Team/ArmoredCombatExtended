AddCSLuaFile()

local floor, Clamp = math.floor, math.Clamp

ACE = ACE or {}

-- Human-readable energy/power with automatic unit scaling, so a tiny battery
-- reads "850 Wh" and a huge one "1.2 MWh" instead of an awkward kWh figure, and
-- a sub-kilowatt draw reads in W. Display only - internal maths stay in kWh/kW.
function ACE.FormatEnergy(kWh)
	kWh = tonumber(kWh) or 0
	local a = math.abs(kWh)
	if a < 1 then        return string.format("%.0f Wh", kWh * 1000)
	elseif a < 1000 then return string.format("%.1f kWh", kWh)
	elseif a < 1e6 then  return string.format("%.2f MWh", kWh / 1000)
	else                 return string.format("%.2f GWh", kWh / 1e6) end
end

function ACE.FormatPower(kW)
	kW = tonumber(kW) or 0
	local a = math.abs(kW)
	if a < 1 then        return string.format("%.0f W", kW * 1000)
	elseif a < 1000 then return string.format("%.1f kW", kW)
	else                 return string.format("%.2f MW", kW / 1000) end
end

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
	acf_gearbox = "Engines",
	acf_fueltank = "Ignore",
	acf_ammo = "Ammo",

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
	ace_wind_sensor = "Electronics",
	ace_alternator = "Electronics",
	ace_solarpanel = "Electronics",
	ace_fuel_synth = "Electronics",
	ace_field_generator = "Electronics",
	ace_explosive = "Ammo",
	ace_explosive_prebuilt = "Ammo",
	ace_bomb_satchel = "Ammo",
	ace_bomb_aerial = "Ammo",
	ace_bomb_barrel = "Ammo",
	ace_transfer_station = "Electronics",
	ace_power_consumer = "Electronics",
	ace_power_collector = "Electronics",
	ace_power_breaker = "Electronics",
	ace_refinery = "Electronics",
	ace_fuel_pump = "Electronics"
}

ACE.PointSubsystems = ACE.PointSubsystems or {
	"Engines",
	"Firepower",
	"Ammo",
	"Crew",
	"Electronics"
}

-- Resolve point category for an entity class.
function ACE_GetPtsType(className)
	if ACE.ArmorClasses[className] then return "Armor" end
	return ACE.ClassToType[className] or "Ignore"
end

-- Validate armor scan results.
function ACE_IsValidArmorResult(front, side)
	if not front or not side then return false end
	if front ~= front or side ~= side then return false end
	if front <= 0 or side <= 0 then return false end
	return true
end

-- Convert front/side scan values to armor points.
function ACE_CalcArmorPoints(front, side)
	front = tonumber(front) or 0
	side = tonumber(side) or 0

	local cfg = ACE.PointCostConfig or {}
	local frontWeight = tonumber(cfg.ArmorFrontWeight) or 1
	local sideWeight = tonumber(cfg.ArmorSideWeight) or 2.5
	local armorScale = tonumber(cfg.ArmorScale) or 4

	return (front * frontWeight + side * sideWeight) * armorScale
end

-- Validate cached armor detail list structure.
function ACE_IsValidArmorDetails(details)
	if details == nil then return true end
	if not istable(details) then return false end

	for _, row in ipairs(details) do
		if not istable(row) then return false end
		if not isnumber(row.Points) then return false end
	end

	return true
end

-- Safe helpers for point/readout math.
function ACE_SafeNonNegative(value)
	value = tonumber(value) or 0
	if value ~= value or value == math.huge or value == -math.huge then return 0 end
	return math.max(value, 0)
end

function ACE_SafeRatio(numerator, denominator)
	numerator = tonumber(numerator) or 0
	denominator = tonumber(denominator) or 0
	if denominator <= 0 then return 0 end
	local value = numerator / denominator
	if value ~= value or value == math.huge or value == -math.huge then return 0 end
	return value
end

function ACE_SafeRound1(value)
	return math.Round(ACE_SafeNonNegative(value), 1)
end

function ACE_FormatDetailLabel(ent)
	if not ACE_IsEnt(ent) then return "Unknown" end

	local name = ""
	if ent.GetNWString then
		name = ent:GetNWString("WireName", "")
	end
	if name == "" and ent.GetName then
		name = ent:GetName() or ""
	end
	if name == "" and ent.PrintName and ent.PrintName ~= "" then
		name = ent.PrintName
	end
	if name == "" then
		name = ent:GetClass() or "unknown"
	end

	return string.format("%s [#%d]", name, ent:EntIndex())
end

-- Resolve the ammo type multiplier for cost/points.
function ACE_GetAmmoTypeFactor(ammoType)
	local factors = ACE.AmmoTypeFactors
	return factors and factors[ammoType] or 1
end

-- Extract configurable class name from "Name:arg=val" serialized strings.
function ACE_GetConfigurableName(value, fallback)
	if type(value) ~= "string" or value == "" then return fallback end

	local name = string.match(value, "^[^:]+")
	if not name or name == "" then return fallback end

	return name
end

-- Resolve missile guidance multiplier from guidance configuration.
function ACE_GetMissileGuidanceFactor(guidanceValue)
	local factors = ACE.MissileGuidanceFactors or {}
	local fallback = tonumber(factors.Dumb) or 1

	local function normalizeName(name)
		if type(name) ~= "string" or name == "" then return nil end
		return (name:gsub("%s+", "_"):gsub("%-", "_"))
	end

	local function resolveFactorFromName(name)
		name = normalizeName(name)
		if not name then return nil end

		local direct = tonumber(factors[name])
		if direct then return direct end

		local lower = string.lower(name)
		for key, value in pairs(factors) do
			if string.lower(tostring(key)) == lower then
				return tonumber(value)
			end
		end

		return nil
	end

	-- Direct string forms, including configurable "Name:arg=val".
	if type(guidanceValue) == "string" then
		local name = ACE_GetConfigurableName(guidanceValue, "Dumb")
		local factor = resolveFactorFromName(name) or resolveFactorFromName(guidanceValue) or fallback
		return math.max(factor, 0)
	end

	-- Configurable/table forms used at runtime by missile entities.
	if istable(guidanceValue) then
		local candidates = {
			guidanceValue.Name,
			guidanceValue.name,
			guidanceValue.ClassName,
			guidanceValue.class,
			guidanceValue.GuidanceName,
			guidanceValue.Guidance,
			guidanceValue.Type
		}

		for _, candidate in ipairs(candidates) do
			local factor = resolveFactorFromName(candidate)
			if factor then return math.max(factor, 0) end
		end
	end

	return math.max(fallback, 0)
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

-- Determine whether bullet data should use ATGM-style missile costing.
function ACE_IsATGMCostAmmo(bdata)
	if not bdata then return false end
	if ACE_IsGLATGMAmmoType(bdata.Type) then return true end

	return ACE_GetAmmoGunClass(bdata) == "ATGM"
end

-- Resolve guidance scaling used by missile point/threat math.
local function ACE_GetAmmoGuidancePenFactor(bdata)
	if not bdata or not ACE_IsAmmoMissileType(bdata) then return 1 end
	-- Guidance should act as an upward threat modifier in pen-space, not make
	-- missiles artificially cheap when using low-end guidance packages.
	return math.max(ACE_GetMissileGuidanceFactor(bdata.Data7), 1)
end

-- Calculate per-missile legacy points (manufacturing-cost basis), including guidance.
function ACE_CalcMissileLegacyRoundCost(bdata)
	if not istable(bdata) then return 0 end

	local ammoId = bdata.Id
	local rackPointCost = ACF_GetRackValue and ACF_GetRackValue(bdata, "pointcost")
	local gunPointCost = ACF_GetGunValue and ACF_GetGunValue(ammoId, "pointcost")
	local legacyPts = tonumber(rackPointCost or 0) or tonumber(gunPointCost or 0) or 0
	legacyPts = math.max(legacyPts, 0)

	local factor = ACE_GetMissileGuidanceFactor(bdata.Data7)
	local basePts = legacyPts

	if ACE_IsATGMCostAmmo(bdata) then
		local cfg = ACE.ATGMCostConfig or {}
		local perfPts = ACE_GetAmmoRoundPoints(bdata)
		local perfMul = tonumber(cfg.PerformanceMul) or 1
		local legacyWeight = math.Clamp(tonumber(cfg.LegacyWeight) or 0, 0, 1)
		local minBase = tonumber(cfg.MinBase) or 25

		if perfPts > 0 then
			basePts = perfPts * perfMul
			if legacyPts > 0 and legacyWeight > 0 then
				basePts = basePts * (1 - legacyWeight) + legacyPts * legacyWeight
			end
		end

		basePts = math.max(basePts, minBase)

		-- Guidance is already applied in missile threat/penetration scaling for ATGM perf points.
		return math.max(basePts, 0)
	end

	-- Non-ATGM missile racks still use legacy pointcost, so guidance is applied here.
	return math.max(basePts, 0) * factor
end

-- Determine whether an ammo type should use HE utility scaling.
function ACE_IsHEAmmoType(ammoType)
	return ammoType == "HE" or ammoType == "HEFS" or ammoType == "CHE"
end

-- Calculate penetration threat scaling using normalized penetration.
function ACE_GetPenThreatFactor(maxPen, cfg)
	cfg = cfg or ACE.AmmoCostConfig or {}

	local refPen = tonumber(cfg.RefPen) or 0
	if refPen <= 0 then return 0 end

	local penRatio = math.max((tonumber(maxPen) or 0) / refPen, 0)
	if penRatio <= 0 then return 0 end

	-- Keep penetration scaling linear; RoF is the primary nonlinear term.
	return penRatio
end

-- Calculate RoF threat scaling as a saturating factor.
function ACE_GetRofThreatFactor(rps, cfg)
	cfg = cfg or ACE.AmmoCostConfig or {}

	local rpsValue = tonumber(rps) or 0
	if rpsValue <= 0 then return 0 end

	local kneeRpm = tonumber(cfg.RofKneeRpm) or 0
	if kneeRpm <= 0 then return 0 end

	local minRpm = tonumber(cfg.MinRofRpm) or 0
	local rpm = math.max(rpsValue * 60, minRpm)
	return rpm / (rpm + kneeRpm)
end

-- Compute ready rack capacity for a caliber.
function ACE_GetReadyRackCap(calMm)
	local cfg = ACE.AmmoCostConfig or {}
	local readyBase = cfg.ReadyRackBase or 0
	if readyBase <= 0 then return 0 end

	local pivot    = cfg.ReadyRackPivot or 0
	local lowBoost = cfg.ReadyRackLowBoost or 0

	local baseCap = readyBase / math.max(calMm, 1)

	if pivot > 0 and lowBoost > 0 and calMm < pivot then
		local ratio = (pivot - calMm) / pivot
		baseCap = baseCap * (1 + lowBoost * ratio)
	end

	return math.floor(baseCap + 0.5)
end

-- Calculate per-round points (no RPS factors) for ammo allocation weighting.
function ACE_GetAmmoRoundPoints(bdata)
	if not bdata then return 0 end

	local maxPen = ACE_GetAmmoMaxPen(bdata) * ACE_GetAmmoGuidancePenFactor(bdata)
	local blastMass = ACE_GetAmmoBlastMass(bdata)
	if maxPen <= 0 and blastMass <= 0 then return 0 end

	local calMm = ACE_GetAmmoCaliberMm(bdata)
	if calMm <= 0 then return 0 end

	local typeFactor = ACE_GetAmmoTypeFactor(bdata.Type)
	if typeFactor <= 0 then return 0 end

	local cfg = ACE.AmmoCostConfig or {}
	local refCal = cfg.RefCaliber or 0
	local baseRound = cfg.BaseRoundPts or 0
	if refCal <= 0 or baseRound <= 0 then return 0 end

	local penFactor = ACE_GetPenThreatFactor(maxPen, cfg)
	local blastExp = cfg.BlastExp or 1
	local blastWeight = cfg.BlastWeight or 0
	local refBlast = cfg.RefBlastMass or 0

	local blastFactor = 0
	if blastMass > 0 and refBlast > 0 then
		blastFactor = (blastMass / refBlast) ^ blastExp
	end

	local utilFactor = 0
	if ACE_IsHEAmmoType(bdata.Type) and blastMass > 0 then
		local utilWeight = cfg.HeUtilWeight or 0
		local utilExp = cfg.HeUtilExp or 1
		utilFactor = (blastMass / math.max(calMm, 1)) ^ utilExp * utilWeight
	end

	local threatFactor = penFactor + blastFactor * blastWeight + utilFactor
	if threatFactor <= 0 then return 0 end

	local threatExp = cfg.ThreatExp or 1
	if threatExp > 0 and threatExp ~= 1 then
		threatFactor = threatFactor ^ threatExp
	end

	local calFactor = calMm / refCal

	return baseRound * threatFactor * calFactor * typeFactor
end

-- Calculate threat weight for ready-rack allocation.
function ACE_GetAmmoThreatWeight(bdata)
	if not bdata then return 0 end

	local maxPen = ACE_GetAmmoMaxPen(bdata) * ACE_GetAmmoGuidancePenFactor(bdata)
	local blastMass = ACE_GetAmmoBlastMass(bdata)
	if maxPen <= 0 and blastMass <= 0 then return 0 end

	local cfg = ACE.AmmoCostConfig or {}
	local refBlast = cfg.RefBlastMass or 0

	local penFactor = ACE_GetPenThreatFactor(maxPen, cfg)
	local blastExp = cfg.BlastExp or 1
	local blastWeight = cfg.BlastWeight or 0

	local blastFactor = 0
	if blastMass > 0 and refBlast > 0 then
		blastFactor = (blastMass / refBlast) ^ blastExp
	end

	local utilFactor = 0
	if ACE_IsHEAmmoType(bdata.Type) and blastMass > 0 then
		local calMm = ACE_GetAmmoCaliberMm(bdata)
		if calMm > 0 then
			local utilWeight = cfg.HeUtilWeight or 0
			local utilExp = cfg.HeUtilExp or 1
			utilFactor = (blastMass / math.max(calMm, 1)) ^ utilExp * utilWeight
		end
	end

	local threatFactor = penFactor + blastFactor * blastWeight + utilFactor
	local threatExp = cfg.ThreatExp or 1
	if threatExp > 0 and threatExp ~= 1 then
		threatFactor = threatFactor ^ threatExp
	end

	return threatFactor
end

-- Compute sustained rounds per second for a gun/rack.
function ACE_GetEntRps(ent)
	local reload = ent.ReloadTime
	if reload and reload > 0 then return 1 / reload end

	local rof = ent.RateOfFire
	if rof and rof > 0 then return rof / 60 end

	return 0
end

-- Collect per-gun RPS totals and rack entities for a contraption.
function ACE_BuildGunRpsAndRacks(ents)
	local gunRpsById, racks = {}, {}

	for _, ent in ipairs(ents) do
		if ACE_IsEnt(ent) then
			local cls = ent:GetClass()
			if cls == "acf_gun" then
				local id = ent.Id
				local rps = ACE_GetEntRps(ent)
				if id and rps > 0 then
					gunRpsById[id] = (gunRpsById[id] or 0) + rps
				end
			elseif cls == "acf_rack" then
				racks[#racks + 1] = ent
			end
		end
	end

	return gunRpsById, racks
end

-- Extract HE filler mass from bullet data.
function ACE_GetAmmoBlastMass(bdata)
	if not bdata then return 0 end
	return tonumber(bdata.BoomFillerMass) or tonumber(bdata.FillerMass) or 0
end

-- Resolve ammo caliber in millimeters.
function ACE_GetAmmoCaliberMm(bdata)
	if not bdata then return 0 end

	local best = math.max(
		bdata.Caliber or 0,
		bdata.SlugCaliber or 0,
		bdata.SlugCaliber2 or 0,
		bdata.JetCaliber or 0
	)

	if best <= 0 and bdata.Id then
		best = ACF_GetGunValue(bdata.Id, "caliber") or 0
	end

	return best * 10
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

-- Collect entities belonging to a contraption.
function ACE_GetContraptionEntities(con, fallbackEnt)
	local ents = {}
	local visited = {}
	local queue = {}

	local function enqueue(ent)
		if not ACE_IsEnt(ent) then return end
		if visited[ent] then return end

		visited[ent] = true
		ents[#ents + 1] = ent
		queue[#queue + 1] = ent
	end

	if con and con.ents then
		for ent in pairs(con.ents) do
			enqueue(ent)
		end
	end

	if #ents == 0 and ACE_IsEnt(fallbackEnt) then
		enqueue(fallbackEnt)
	end

	-- Include ACF-linked entities that may not be physically welded into the contraption.
	local idx = 1
	while idx <= #queue do
		local cur = queue[idx]
		idx = idx + 1

		local ammoLink = cur.AmmoLink
		if istable(ammoLink) then
			for _, linked in pairs(ammoLink) do
				enqueue(linked)
			end
		end

		local master = cur.Master
		if istable(master) then
			for _, linked in pairs(master) do
				enqueue(linked)
			end
		end
	end

	table.sort(ents, function(a, b)
		return a:EntIndex() < b:EntIndex()
	end)

	return ents
end

-- Allocate ready-rack rounds across ammo crates.
function ACE_BuildAmmoReadyAlloc(ents)
	local cfg = ACE.AmmoCostConfig or {}
	if (cfg.ReadyRackBase or 0) <= 0 then return nil end

	local groups = {}
	-- Group ammo crates by caliber and weight by per-round cost.

	for _, ent in ipairs(ents) do
		if ACE_IsEnt(ent) and ent:GetClass() == "acf_ammo" then
			local bdata = ent.BulletData
			if bdata then
				local rounds = ent.Capacity or 0
				if rounds > 0 then
					local ammoId = bdata.Id
					if ammoId then
						local calMm = ACE_GetAmmoCaliberMm(bdata)
						if calMm > 0 then
							local group = groups[calMm]
							if not group then
								group = { calMm = calMm, total = 0, entries = {} }
								groups[calMm] = group
							end

						local threat = ACE_GetAmmoThreatWeight(bdata)
						local weight = threat * rounds
							group.total = group.total + math.max(weight, 0)
							group.entries[#group.entries + 1] = {
								ent = ent,
								rounds = rounds,
								weight = weight
							}
						end
					end
				end
			end
		end
	end

	local alloc = {}

	for _, group in pairs(groups) do
		local total = group.total or 0
		if total > 0 then
			local readyCap = ACE_GetReadyRackCap(group.calMm)
			if readyCap > 0 then
				local entries = {}
				local remaining = readyCap
				-- Use fractional remainders to distribute the leftover rounds.

				for _, entry in ipairs(group.entries) do
					local weight = entry.weight or 0
					local raw = 0
					if weight > 0 then
						raw = readyCap * weight / total
					end
					local base = math.floor(raw)
					local capped = math.min(base, entry.rounds)
					remaining = remaining - capped
					entries[#entries + 1] = {
						ent = entry.ent,
						rounds = entry.rounds,
						ready = capped,
						frac = raw - base
					}
				end

				table.sort(entries, function(a, b)
					if a.frac == b.frac then
						if a.rounds == b.rounds then
							local aIdx = IsValid(a.ent) and a.ent:EntIndex() or 0
							local bIdx = IsValid(b.ent) and b.ent:EntIndex() or 0
							return aIdx < bIdx
						end
						return a.rounds < b.rounds
					end
					return a.frac > b.frac
				end)

				for _, entry in ipairs(entries) do
					if remaining <= 0 then break end
					if entry.ready < entry.rounds then
						entry.ready = entry.ready + 1
						remaining = remaining - 1
					end
				end

				for _, entry in ipairs(entries) do
					alloc[entry.ent] = entry.ready
				end
			end
		end
	end

	return next(alloc) and alloc or nil
end



-- ============================================================
-- ACE parsing/get helpers
-- ============================================================

-- Resolve a contraption wrapper for an entity.
function ACE_GetContraptionFromEntity(ent)
	if not ACE_IsEnt(ent) or not ent.GetContraption then return end
	local con = ent:GetContraption()
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

-- Build a parent chain summary for debug logs.
function ACE_GetEntChainSummary(ent, maxDepth)
	if not ACE_IsEnt(ent) then return "?" end
	local parts = {}
	local cur = ent
	local depth = 0
	local limit = maxDepth or 4
	while ACE_IsEnt(cur) and depth <= limit do
		parts[#parts + 1] = string.format("%s(%d)", cur:GetClass(), cur:EntIndex())
		cur = cur:GetParent()
		depth = depth + 1
	end
	return table.concat(parts, " <- ")
end

-- Format a position/angle tuple for dupe signatures.
function ACE_FormatDupeTransform(pos, ang)
	if pos and pos.x ~= nil and pos.y ~= nil and pos.z ~= nil then
		pos = string.format("%.3f,%.3f,%.3f", pos.x, pos.y, pos.z)
	end

	if ang and ang.p ~= nil and ang.y ~= nil and ang.r ~= nil then
		ang = string.format("%.2f,%.2f,%.2f", ang.p, ang.y, ang.r)
	end

	return tostring(pos or ""), tostring(ang or "")
end

function ACE_FormatArmorKey(material, ductility, armour, maxArmour, mass)
	mass = mass or 0 -- shut up linter
	-- Cache signatures should ignore runtime mass drift.
	return string.format(
		"mat=%s|duct=%.3f|arm=%.2f|max=%.2f",
		tostring(material or ""),
		tonumber(ductility) or 0,
		tonumber(armour) or 0,
		tonumber(maxArmour) or 0
	)
end

local function ACE_ShouldIncludeArmorSignature(ent)
	if not IsValid(ent) then return false end

	local cls = ent:GetClass() or ""
	if cls:find("gmod_wire_", 1, true) then return false end
	if cls:find("starfall", 1, true) then return false end

	if ent.RenderOverride and tostring(ent.RenderOverride):find("MakeSpherical") then
		return false
	end

	if ACE_GetPtsType and ACE_GetPtsType(cls) == "Armor" then return true end

	if cls == "prop_physics" or cls == "primitive_shape" then
		local acf = ent.ACF
		if acf and ((acf.Armour or acf.Armor) or (acf.MaxArmour or acf.MaxArmor)) then
			return true
		end
	end

	return false
end

-- Build a signature for dupe cache lookups.
function ACE_GetDupeSignature(dupe, created)
	if not util or not util.SHA256 then return nil end

	local entData = dupe and (dupe.Entities or dupe.Ents or dupe.EntityList or (dupe.Dupe and dupe.Dupe.Entities))
	if istable(entData) then
		local parts = {}

		for _, data in pairs(entData) do
			if istable(data) then
				local class = data.Class or data.class or "unknown"
				local model = data.Model or data.model or ""

				local mods = data.EntityMods or data.entitymods
				local acfSettings = mods and mods.acfsettings
				local massMod = mods and mods.mass
				local acf = data.ACF or data.acf

				local material = (acfSettings and (acfSettings.Material or acfSettings.material)) or (acf and (acf.Material or acf.material))
				local ductility = (acfSettings and (acfSettings.Ductility or acfSettings.ductility)) or (acf and (acf.Ductility or acf.ductility))
				local armour = acf and (acf.Armour or acf.Armor)
				local maxArmour = acf and (acf.MaxArmour or acf.MaxArmor)
				local mass = massMod and (massMod.Mass or massMod.mass)
				local pos = data.Pos or data.pos
				local ang = data.Angle or data.angle or data.Ang
				local posKey, angKey = ACE_FormatDupeTransform(pos, ang)

				parts[#parts + 1] = table.concat({
					class,
					model,
					ACE_FormatArmorKey(material, ductility, armour, maxArmour, mass),
					posKey,
					angKey
				}, "|")
			end
		end

		table.sort(parts)
		if #parts > 0 then
			return tostring(ACE.DupeArmorCacheVersion) .. ":ents:" .. util.SHA256(table.concat(parts, ";"))
		end
	end

	if istable(created) then
		local parts = {}

		local refEnt
		for _, ent in pairs(created) do
			if ACE_ShouldIncludeArmorSignature(ent) then
				refEnt = ent
				break
			end
		end

		for _, ent in pairs(created) do
			if ACE_ShouldIncludeArmorSignature(ent) then
				local class = ent:GetClass() or "unknown"
				local model = ent:GetModel() or ""

				local acf = ent.ACF
				local material = acf and acf.Material
				local ductility = acf and acf.Ductility
				local armour = acf and (acf.Armour or acf.Armor)
				local maxArmour = acf and (acf.MaxArmour or acf.MaxArmor)

				local mass = 0
				local phys = ent:GetPhysicsObject()
				if IsValid(phys) then mass = phys:GetMass() end

				local posKey, angKey = "", ""
				if IsValid(refEnt) then
					local relPos = refEnt:WorldToLocal(ent:GetPos())
					local relAng = refEnt:WorldToLocalAngles(ent:GetAngles())
					posKey, angKey = ACE_FormatDupeTransform(relPos, relAng)
				end

				parts[#parts + 1] = table.concat({
					class,
					model,
					ACE_FormatArmorKey(material, ductility, armour, maxArmour, mass),
					posKey,
					angKey
				}, "|")
			end
		end

		table.sort(parts)
		if #parts > 0 then
			return tostring(ACE.DupeArmorCacheVersion) .. ":spawn:" .. util.SHA256(table.concat(parts, ";"))
		end
	end

	return nil
end

-- Build a signature for created entities using a fixed reference.
local function ACE_BuildCreatedSignature(created, refEnt, wantInfo)
	if not util or not util.SHA256 then return nil end
	if not istable(created) then return nil end

	refEnt = refEnt or nil
	local parts = {}
	local included = {}
	local sum = Vector(0, 0, 0)
	local count = 0

	for _, ent in pairs(created) do
		if ACE_ShouldIncludeArmorSignature(ent) then
			included[#included + 1] = ent
			sum = sum + ent:GetPos()
			count = count + 1
		end
	end

	if count == 0 then return nil end
	local center = sum / count

	local fallbackRef
	local refToken = ""
	if true then
		local candidates = {}
		for _, ent in ipairs(included) do
			local class = ent:GetClass() or "unknown"
			local model = ent:GetModel() or ""
			local acf = ent.ACF
			local material = acf and acf.Material
			local ductility = acf and acf.Ductility
			local armour = acf and (acf.Armour or acf.Armor)
			local maxArmour = acf and (acf.MaxArmour or acf.MaxArmor)
			local dist = (ent:GetPos() - center):Length()

			local token = table.concat({
				class,
				model,
				ACE_FormatArmorKey(material, ductility, armour, maxArmour, 0),
				string.format("%.1f", dist)
			}, "|")
			candidates[#candidates + 1] = { ent = ent, token = token }
		end

		if #candidates > 0 then
			table.sort(candidates, function(a, b) return a.token < b.token end)
			fallbackRef = candidates[1].ent
			refToken = candidates[1].token
		end
	end

	if not IsValid(fallbackRef) then return nil end

	for _, ent in ipairs(included) do
		local class = ent:GetClass() or "unknown"
		local model = ent:GetModel() or ""

		local acf = ent.ACF
		local material = acf and acf.Material
		local ductility = acf and acf.Ductility
		local armour = acf and (acf.Armour or acf.Armor)
		local maxArmour = acf and (acf.MaxArmour or acf.MaxArmor)

		local posKey = ""

		parts[#parts + 1] = table.concat({
			class,
			model,
			ACE_FormatArmorKey(material, ductility, armour, maxArmour, 0),
			posKey
		}, "|")
	end

	table.sort(parts)
	if #parts == 0 then return nil end

	local hash = util.SHA256(table.concat(parts, ";"))
	local key = tostring(ACE.DupeArmorCacheVersion) .. ":spawn:" .. hash
	if wantInfo then
		return key, {
			count = count,
			ref = refToken,
			hash = hash,
			first = parts[1],
			last = parts[#parts]
		}
	end

	return key
end

-- Build a signature for created entities using a fixed reference.
function ACE_GetCreatedSignature(created, refEnt)
	return ACE_BuildCreatedSignature(created, refEnt, false)
end

-- Build a signature plus debug info for created entities.
function ACE_GetCreatedSignatureInfo(created, refEnt)
	return ACE_BuildCreatedSignature(created, refEnt, true)
end

ACE.DupeSubsystemCacheVersion = ACE.DupeSubsystemCacheVersion or 1

-- Check if a class should participate in a subsystem signature.
local function ACE_IsSubsystemClass(subsystem, className)
	if subsystem == "Ammo" then
		return className == "acf_ammo" or className == "acf_gun" or className == "acf_rack"
	end

	if subsystem == "Firepower" then
		return className == "acf_gun" or className == "acf_rack"
	end

	return ACE_GetPtsType(className) == subsystem
end

-- Build a signature token for a subsystem-relevant entity.
local function ACE_GetSubsystemToken(ent, subsystem)
	if not ACE_IsEnt(ent) then return nil end

	local className = ent:GetClass() or ""
	if subsystem == "Ammo" and className == "acf_ammo" then
		local bdata = ent.BulletData
		if not bdata then return nil end

		local ammoId = bdata.Id or ""
		local ammoType = bdata.Type or ""
		local calMm = ACE_GetAmmoCaliberMm(bdata)
		local maxPen = ACE_GetAmmoMaxPen(bdata)
		local blastMass = ACE_GetAmmoBlastMass(bdata)
		local rounds = ent.Capacity or 0

		return table.concat({
			className,
			tostring(ammoId),
			tostring(ammoType),
			string.format("%.1f", calMm),
			string.format("%.2f", maxPen),
			string.format("%.3f", blastMass),
			tostring(rounds)
		}, "|")
	end

	if (subsystem == "Ammo" or subsystem == "Firepower") and (className == "acf_gun" or className == "acf_rack") then
		local model = ent:GetModel() or ""
		local rps = ACE_GetEntRps(ent)
		local id = ent.Id or ""

		return table.concat({
			className,
			tostring(id),
			string.format("%.4f", rps),
			model
		}, "|")
	end

	local model = ent:GetModel() or ""
	local pts = ACE_GetEntPoints(ent)

	return table.concat({
		className,
		model,
		string.format("%.2f", pts)
	}, "|")
end

-- Build a subsystem signature from a list of entities.
function ACE_GetSubsystemSignatureFromEnts(subsystem, ents)
	if not util or not util.SHA256 then return nil end
	if not subsystem or not istable(ents) then return nil end

	local parts = {}
	for _, ent in pairs(ents) do
		if ACE_IsEnt(ent) then
			local className = ent:GetClass() or ""
			if ACE_IsSubsystemClass(subsystem, className) then
				local token = ACE_GetSubsystemToken(ent, subsystem)
				if token then parts[#parts + 1] = token end
			end
		end
	end

	if #parts == 0 then return nil end
	table.sort(parts)

	return tostring(ACE.DupeSubsystemCacheVersion) .. ":" .. subsystem .. ":" .. util.SHA256(table.concat(parts, ";"))
end

-- Build subsystem signatures for a list of entities.
function ACE_GetSubsystemSignaturesFromEnts(ents)
	if not istable(ents) then return nil end

	local subsystems = ACE.PointSubsystems or {
		"Engines",
		"Firepower",
		"Ammo",
		"Crew",
		"Electronics"
	}

	local keys = {}
	for _, subsystem in ipairs(subsystems) do
		local key = ACE_GetSubsystemSignatureFromEnts(subsystem, ents)
		if key then keys[subsystem] = key end
	end

	return next(keys) and keys or nil
end

-- Normalize AdvDupe2 hook arguments.
function ACE_ParseAdvDupeArgs(...)
	-- Supports both common patterns:
	-- (ply, dupe, created) or (dupeInfoTable)
	local a, b, c = ...

	if istable(a) and (a.CreatedEntities or (a[1] and a[1].CreatedEntities)) then
		local info = a
		local dupe = info[1] or info.Dupe or info.dupe or info
		local created = info.CreatedEntities or (dupe and dupe.CreatedEntities)
		return dupe, created
	end

	if ACE_IsEnt(a) and a:IsPlayer() and istable(b) and istable(c) then
		return b, c
	end

	if istable(a) and istable(b) then
		return a, b
	end

	return nil, nil
end

-- Legacy manufacturing cost indicator (original mass/material system).
function ACE_GetEntLegacyCost(ent, massOverride)
	if not ACE_IsEnt(ent) then return 0 end

	local points = ent.ACEPoints or 0
	if points ~= 0 then return points end

	local class = ent:GetClass()
	local acf = ent.ACF or {}

	-- Armor props: derive manufacturing cost from raw thickness (mm), then apply ductility scalar.
	if ACE.ArmorClasses and ACE.ArmorClasses[class] then
		local mat = acf.Material or "RHA"
		local matData = ACE_GetMaterialData and ACE_GetMaterialData(mat)
		local armorData = ent.acfPropArmorData and ent:acfPropArmorData()
		local armorMod = ACF.ArmorMod or 1
		local armorMm = tonumber(acf.MaxArmour or acf.Armour) or 0
		local curve = (armorData and armorData.Curve) or 1

		-- Match point-scan weighting: KE 80% + CHEM 20% effectiveness.
		local effKE = (armorData and armorData.Effectiveness) or (matData and matData.effectiveness) or 1
		local effCHEM = (armorData and (armorData.HEATeffectiveness or armorData.HEATEffectiveness))
			or (matData and (matData.HEATeffectiveness or matData.effectiveness))
			or effKE
		local weightedEff = effKE * 0.8 + effCHEM * 0.2

		local effectiveMm = 0
		if armorMm > 0 then
			effectiveMm = (armorMm ^ curve) * weightedEff
		end

		local rawMm = 0
		if effectiveMm > 0 and armorMod > 0 then
			rawMm = effectiveMm / armorMod
		end

		local rawHP = tonumber(acf.MaxHealth or acf.Health) or 1
		rawHP = math.max(rawHP, 1)

		-- Manufacturing scalar is now driven by raw HP, not ductility:
		-- 1 HP => 0.2x (-80%), 100 HP => 1.2x (+20%), clamped for stability.
		local hpCostMul = math.Clamp(0.2 + (rawHP - 1) * (1.0 / 99), 0.2, 1.2)
		local perMm = ACE.LegacyRawMmCostPerProp or 1

		return math.max(rawMm * perMm * hpCostMul, 0)
	end

	-- Ammo crates: derive manufacturing cost from per-round ammo pricing so
	-- manufacturing scales with round performance and the amount stored.
	if class == "acf_ammo" then
		local bdata = ent.BulletData
		if istable(bdata) then
			local perRound
			if ACE_IsAmmoMissileType(bdata) then
				perRound = ACE_CalcMissileLegacyRoundCost(bdata)
			else
				perRound = ACE_GetAmmoRoundPoints(bdata)
			end

			if perRound > 0 then
				local rounds = tonumber(ent.Capacity) or tonumber(ent.Ammo) or 0
				rounds = math.max(rounds, 1)

				return perRound * rounds * 10
			end
		end
	end

	local mass = massOverride
	if mass == nil then
		local phys = ent:GetPhysicsObject()
		if IsValid(phys) then mass = phys:GetMass() end
	end

	mass = tonumber(mass) or 0
	local pointsPerTon = ACF.LegacyManufacturingPointsPerTon or 0
	if mass > 0 and pointsPerTon > 0 then
		local matTable = ACE.LegacyMatCostTables or ACE.MatCostTables or {}
		local mat = (ent.ACF and ent.ACF.Material) or "RHA"

		points = (mass / 1000) * pointsPerTon * (matTable[mat] or 1)
	end

	return points
end

-- Cached wrapper for per-crate ammo points.
function ACE_GetAmmoCratePointsForContraption(crate, con, fallbackEnt)
	if not ACE_IsEnt(crate) then return 0 end

	local ammoDirty = con and con.ACESubsystemDirty and con.ACESubsystemDirty.Ammo
	if con and con.ACEAmmoCache and not ammoDirty then
		local cache = con.ACEAmmoCache
		return ACE_CalcAmmoCratePoints(crate, cache.GunRpsById or {}, cache.Racks or {}, cache.ReadyAlloc)
	end

	local ents = ACE_GetContraptionEntities(con, fallbackEnt or crate)

	local gunRpsById, racks = ACE_BuildGunRpsAndRacks(ents)

	local readyAlloc = ACE_BuildAmmoReadyAlloc(ents)
	local pts, detail = ACE_CalcAmmoCratePoints(crate, gunRpsById, racks, readyAlloc)

	if con then
		con.ACEAmmoCache = { GunRpsById = gunRpsById, Racks = racks, ReadyAlloc = readyAlloc }
	end

	return pts, detail
end

-- Get points for a single entity.
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

	return ent.ACEPoints or 0
end

-- Run the armor scan for a contraption.
function ACE_GetArmorScan(ent)
	if not ACE_CalcContraptionArmor then return 0, 0 end
	local front, side = ACE_CalcContraptionArmor(ent)
	return front, side
end



















