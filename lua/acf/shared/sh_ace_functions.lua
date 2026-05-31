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

-- Resolve armor point tuning with conservative defaults.
function ACE_GetArmorPointConfig()
	local cfg = ACE.ArmorPointConfig or {}

	return {
		KEWeight = tonumber(cfg.KEWeight) or 0.8,
		ChemWeight = tonumber(cfg.ChemWeight) or 0.2,
		DamageReferenceMm = tonumber(cfg.DamageReferenceMm) or 50,
		SurvivabilityScale = tonumber(cfg.SurvivabilityScale) or 100,
		ArmorCostMultiplier = tonumber(cfg.ArmorCostMultiplier) or 1,
		SurvivabilityArmorExponent = tonumber(cfg.SurvivabilityArmorExponent) or 1.15,
		SurvivabilityHPExponent = tonumber(cfg.SurvivabilityHPExponent) or 0.45,
		SurvivabilityHPReference = tonumber(cfg.SurvivabilityHPReference) or 100
	}
end

-- Calculate material-adjusted armor thickness for one entity.
function ACE_GetArmorEquivalentMm(ent)
	if not ACE_IsEnt(ent) then return 0 end

	local acf = ent.ACF or {}
	if not istable(acf) then return 0 end

	local mat = acf.Material or "RHA"
	local matData = ACE_GetMaterialData and ACE_GetMaterialData(mat)
	local armorData = ent.acfPropArmorData and ent:acfPropArmorData()
	local armorMod = ACF.ArmorMod or 1
	local armorMm = tonumber(acf.MaxArmour or acf.Armour) or 0
	if armorMm <= 0 then return 0 end

	local curve = (armorData and armorData.Curve) or 1
	local effKE = (armorData and armorData.Effectiveness) or (matData and matData.effectiveness) or 1
	local effCHEM = (armorData and (armorData.HEATeffectiveness or armorData.HEATEffectiveness))
		or (matData and (matData.HEATeffectiveness or matData.effectiveness))
		or effKE

	local cfg = ACE_GetArmorPointConfig()
	local weightedEff = effKE * cfg.KEWeight + effCHEM * cfg.ChemWeight

	local effectiveMm = 0
	if armorMm > 0 then
		effectiveMm = (armorMm ^ curve) * weightedEff
	end

	local rawMm = 0
	if effectiveMm > 0 and armorMod > 0 then
		rawMm = effectiveMm / armorMod
	end

	return rawMm
end

function ACE_GetSurvivabilityIndex(ent)
	if not ACE_IsEnt(ent) then return 0 end

	local armorMm = ACE_GetArmorEquivalentMm(ent)
	if armorMm <= 0 then return 0 end

	local acf = ent.ACF or {}
	local hp = tonumber(acf.MaxHealth or acf.Health) or 0
	if hp <= 0 then return 0 end

	local cfg = ACE_GetArmorPointConfig()
	local armorBase = math.max(cfg.DamageReferenceMm, 1)
	local hpBase = math.max(cfg.SurvivabilityHPReference, 1)

	return cfg.SurvivabilityScale
		* ((armorMm / armorBase) ^ cfg.SurvivabilityArmorExponent)
		* ((hp / hpBase) ^ cfg.SurvivabilityHPExponent)
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

	local acf = ent.ACF or {}
	if not istable(acf) then return 0 end

	local armorMm = tonumber(acf.MaxArmour or acf.Armour) or 0
	if armorMm <= 0 then return 0 end

	local cfg = ACE_GetArmorPointConfig()
	local points = math.max(ACE_GetSurvivabilityIndex(ent) * cfg.ArmorCostMultiplier, 0)
	ACE.ArmorPointCache[cacheKey] = points

	return points
end

-- Resolve crewseat point cost by role.
function ACE_GetCrewSeatPointCost(ent)
	if ACE_IsEnt(ent) and ent:GetClass() == "ace_crewseat_loader" then
		return tonumber(ACE.LoaderSeatPointCost)
			or tonumber((ACE.PointCostConfig or {}).LoaderSeatFlat)
			or 300
	end

	return tonumber(ACE.CrewSeatPointCost)
		or tonumber((ACE.PointCostConfig or {}).CrewSeatFlat)
		or 100
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

-- Resolve guidance scaling used by missile point/threat math. The factor from
-- ACE.MissileGuidanceFactors maps directly onto the missile's pen multiplier:
-- entries below 1 represent unreliable guidance that often misses and scale
-- threat-per-round down, entries above 1 represent premium seekers that
-- consistently land hits and scale threat up.
--
-- A previous version wrapped the return in math.max(factor, 1), which left
-- the above-1 entries alone but neutered every below-1 entry to 1. That made
-- the missile ammo crate path and the ATGM perf-points path disagree with
-- the non-ATGM rack path, which multiplies by the raw factor. Applying the
-- factor directly keeps all three paths consistent: every missile with a
-- MissileGuidanceFactors entry has that guidance factor into its cost.
-- Non-missile ammo is unaffected.
--
-- GLATGM family rounds are explicitly excluded: they are launched from
-- grenade launchers (gun-class ammo), not racks, and should be priced like
-- any other gun ammo with their AmmoTypeFactor doing the work -- no
-- missile-class guidance premium.
local function ACE_GetAmmoGuidancePenFactor(bdata)
	if not bdata or not ACE_IsAmmoMissileType(bdata) then return 1 end
	if ACE_IsGLATGMAmmoType(bdata.Type) then return 1 end
	return ACE_GetMissileGuidanceFactor(bdata.Data7)
end

-- Calculate per-missile points. Delegates to ACE_GetAmmoRoundPoints, which
-- already applies MissileCostConfig.PerformanceMul for missile ammo; this
-- function just adds the MinBase floor so low-threat missiles still register.
function ACE_CalcMissileRoundPoints(bdata)
	if not istable(bdata) then return 0 end

	local cfg = ACE.MissileCostConfig or {}
	local minBase = tonumber(cfg.MinBase) or 1

	return math.max(ACE_GetAmmoRoundPoints(bdata), minBase)
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
	local roundPts = baseRound * threatFactor * calFactor * typeFactor

	-- Missiles get their own multiplier on top so MissileCostConfig is the one
	-- knob that tunes missile pricing for both the ammo crate path
	-- (ACE_CalcAmmoCratePoints) and the per-missile path
	-- (ACE_CalcMissileRoundPoints). GLATGM family rounds opt out: they are
	-- gun-class grenade-launcher ammo, not rack-fired missiles, and pay through
	-- their AmmoTypeFactor (0.75) like any other gun round.
	if ACE_IsAmmoMissileType(bdata) and not ACE_IsGLATGMAmmoType(bdata.Type) then
		local mcfg = ACE.MissileCostConfig or {}
		roundPts = roundPts * (tonumber(mcfg.PerformanceMul) or 1)
	end

	return roundPts
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

-- Compute a gun's configured sustained RPS from its current setup.
function ACE_GetGunConfiguredRps(ent, rofLimit)
	if not ACE_IsEnt(ent) or ent:GetClass() ~= "acf_gun" then return 0 end

	local bdata = ent.BulletData or {}
	local roundVolume = tonumber(bdata.RoundVolume)
	if not roundVolume or roundVolume <= 0 then
		local reload = tonumber(ent.ReloadTime)
		if reload and reload > 0 then return 1 / reload end

		local rof = tonumber(ent.RateOfFire)
		if rof and rof > 0 then return rof / 60 end

		return 0
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

-- Compute sustained rounds per second for a gun/rack.
function ACE_GetEntRps(ent)
	if ACE_IsEnt(ent) and ent:GetClass() == "acf_gun" then
		return ACE_GetGunConfiguredRps(ent, ent.ROFLimit)
	end

	if ACE_IsEnt(ent) and ent:GetClass() == "acf_rack" then
		local bdata = ent.BulletData or {}
		local reload = (ACF_GetRackValue and ACF_GetRackValue(bdata, "reloadspeed"))
			or (ACF_GetGunValue and ACF_GetGunValue(bdata.Id, "reloadspeed"))
			or ent.ReloadTime

		reload = tonumber(reload) or 0
		if reload > 0 then return 1 / reload end
	end

	local reload = tonumber(ent.ReloadTime)
	if reload and reload > 0 then return 1 / reload end

	local rof = ent.RateOfFire
	if rof and rof > 0 then return rof / 60 end

	return 0
end

-- Guns/racks keep ACEPoints at zero; firepower points are derived for readouts.
function ACE_GetGunFirepowerPoints(ent)
	if not ACE_IsEnt(ent) then return 0 end

	local class = ent:GetClass()
	if class == "acf_rack" then
		local maxMissile = tonumber(ent.MaxMissile) or 1
		return 100 + math.max(maxMissile - 1, 0) * 50
	end

	if class ~= "acf_gun" then
		return 0
	end

	local basePoints = tonumber(ACF_GetGunValue and ACF_GetGunValue(ent.Id, "acepoints")) or 0.404
	basePoints = basePoints * (tonumber(ACE.GunPointCostMultiplier) or 0.85)
	if basePoints <= 0 then return 0 end

	local currentRps = ACE_GetEntRps(ent)
	local baseRps = ACE_GetGunConfiguredRps(ent, 0)
	if currentRps <= 0 or baseRps <= 0 then return basePoints end

	local cfg = ACE.AmmoCostConfig or {}
	local currentThreat = ACE_GetRofThreatFactor(currentRps, cfg)
	local baseThreat = ACE_GetRofThreatFactor(baseRps, cfg)
	if currentThreat <= 0 or baseThreat <= 0 then return basePoints end

	return basePoints * math.min(currentThreat / baseThreat, 1)
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
function ACE_BuildAmmoReadyAlloc(ents, rackReserve)
	local cfg = ACE.AmmoCostConfig or {}
	if (cfg.ReadyRackBase or 0) <= 0 then return nil end

	local groups = {}
	-- Group ammo crates by caliber and weight each entry by its per-round cost.
	-- A crate's "rounds" include any rack pre-load assigned to it by
	-- ACE_BuildRackReserveAlloc, so the per-crate clamp (math.min later in this
	-- function) won't strip the rack reserve back out -- and so the weighting
	-- doesn't under-credit crates whose racks are primed full.

	for _, ent in ipairs(ents) do
		if ACE_IsEnt(ent) and ent:GetClass() == "acf_ammo" then
			local bdata = ent.BulletData
			if bdata then
				local reserve = (rackReserve and rackReserve[ent]) or 0
				local rounds = (ent.Capacity or 0) + reserve
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

-- Collect every ammo crate in 'ents' that currently holds rounds. Rack
-- reserve only flows from crates with positive Capacity (an empty crate
-- couldn't have loaded the rack in the first place) and a valid BulletData Id.
local function ACE_CollectLoadedAmmoCrates(ents)
	local crates = {}
	for _, ent in ipairs(ents) do
		if ACE_IsEnt(ent) and ent:GetClass() == "acf_ammo" then
			local bdata = ent.BulletData
			if bdata and bdata.Id and (tonumber(ent.Capacity) or 0) > 0 then
				crates[#crates + 1] = ent
			end
		end
	end
	return crates
end

-- For one rack, decide how its MaxMissile pre-load gets split across the
-- crates it can feed from. Returns {crate -> share}, or nil if the rack has
-- no slots, no Id, or no compatible crates.
--
-- Splits by ammo threat weight (high-pen / big-blast rounds get the larger
-- share). If every candidate has zero threat the split is even. Uses
-- largest-remainder rounding so shares stay integer; EntIndex tiebreaks so
-- identical setups allocate identically across re-scans.
local function ACE_AllocateRackPreload(rack, crates)
	local maxMissile = tonumber(rack.MaxMissile) or 0
	if maxMissile <= 0 or not rack.Id then return nil end

	-- Gather candidate crates and their threat weights.
	local candidates, totalWeight = {}, 0
	for _, crate in ipairs(crates) do
		local bdata = crate.BulletData
		if ACF_CanLinkRack(rack.Id, bdata.Id, bdata, rack) then
			local weight = math.max(ACE_GetAmmoThreatWeight(bdata), 0)
			candidates[#candidates + 1] = { crate = crate, weight = weight }
			totalWeight = totalWeight + weight
		end
	end
	if #candidates == 0 then return nil end

	-- Even split when no candidate carries any threat (e.g. all Refill).
	if totalWeight <= 0 then
		for _, entry in ipairs(candidates) do entry.weight = 1 end
		totalWeight = #candidates
	end

	-- Each crate takes its whole share first; track the fractional remainder.
	local remaining = maxMissile
	for _, entry in ipairs(candidates) do
		local raw        = maxMissile * entry.weight / totalWeight
		entry.wholeShare = math.floor(raw)
		entry.remainder  = raw - entry.wholeShare
		remaining        = remaining - entry.wholeShare
	end

	-- Hand the leftover slots to whichever crates were closest to rounding up.
	table.sort(candidates, function(a, b)
		if a.remainder == b.remainder then
			return a.crate:EntIndex() < b.crate:EntIndex()
		end
		return a.remainder > b.remainder
	end)

	for _, entry in ipairs(candidates) do
		if remaining <= 0 then break end
		entry.wholeShare = entry.wholeShare + 1
		remaining = remaining - 1
	end

	local shares = {}
	for _, entry in ipairs(candidates) do
		if entry.wholeShare > 0 then
			shares[entry.crate] = entry.wholeShare
		end
	end
	return next(shares) and shares or nil
end

-- Spread each rack's MaxMissile pre-load across the ammo crates that could
-- feed it, so the rounds sitting in rack tubes count toward the feeding
-- crate's points. Without this, a 2-round crate would price for 2 even when
-- its 8-tube rack is fully primed and ready to dump them.
--
-- "Could feed it" means ACF_CanLinkRack returns true -- the same compatibility
-- rule ACE_CalcAmmoCratePoints uses to credit a rack's RPS to a crate. Keep
-- the two checks in lockstep: if you change which crates a rack contributes
-- RPS to, change which crates it contributes reserve to as well.
--
-- 'racks' is optional; pass the list from ACE_BuildGunRpsAndRacks to skip the
-- re-scan. Returns {crate -> reserve_rounds}, or nil if nothing was allocated.
function ACE_BuildRackReserveAlloc(ents, racks)
	if not ACF_CanLinkRack then return nil end

	if not racks then
		racks = {}
		for _, ent in ipairs(ents) do
			if ACE_IsEnt(ent) and ent:GetClass() == "acf_rack" then
				racks[#racks + 1] = ent
			end
		end
	end
	if #racks == 0 then return nil end

	local crates = ACE_CollectLoadedAmmoCrates(ents)
	if #crates == 0 then return nil end

	local alloc = {}
	for _, rack in ipairs(racks) do
		local shares = ACE_AllocateRackPreload(rack, crates)
		if shares then
			for crate, count in pairs(shares) do
				alloc[crate] = (alloc[crate] or 0) + count
			end
		end
	end

	return next(alloc) and alloc or nil
end

-- Public per-rack version of ACE_AllocateRackPreload, for callers (e.g. the
-- armor tool popup) that have a single rack and want to see which crates
-- fill its tubes. Returns {crate -> reserve_rounds} or nil.
function ACE_GetRackPreloadAlloc(rack, con, fallbackEnt)
	if not ACE_IsEnt(rack) or rack:GetClass() ~= "acf_rack" then return nil end
	if not ACF_CanLinkRack then return nil end

	local ents = ACE_GetContraptionEntities(con, fallbackEnt or rack)
	local crates = ACE_CollectLoadedAmmoCrates(ents)
	if #crates == 0 then return nil end

	return ACE_AllocateRackPreload(rack, crates)
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

-- Cached wrapper for per-crate ammo points.
function ACE_GetAmmoCratePointsForContraption(crate, con, fallbackEnt)
	if not ACE_IsEnt(crate) then return 0 end

	if con and con.ACEAmmoCache then
		local cache = con.ACEAmmoCache
		return ACE_CalcAmmoCratePoints(crate, cache.GunRpsById or {}, cache.Racks or {}, cache.ReadyAlloc, cache.RackReserve)
	end

	local ents = ACE_GetContraptionEntities(con, fallbackEnt or crate)

	local gunRpsById, racks = ACE_BuildGunRpsAndRacks(ents)

	local rackReserve = ACE_BuildRackReserveAlloc(ents, racks)
	local readyAlloc = ACE_BuildAmmoReadyAlloc(ents, rackReserve)
	local pts, detail = ACE_CalcAmmoCratePoints(crate, gunRpsById, racks, readyAlloc, rackReserve)

	if con then
		con.ACEAmmoCache = {
			GunRpsById = gunRpsById,
			Racks = racks,
			ReadyAlloc = readyAlloc,
			RackReserve = rackReserve
		}
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



