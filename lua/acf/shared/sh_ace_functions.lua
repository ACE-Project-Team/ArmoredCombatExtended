AddCSLuaFile()

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

		if pwr then
			--Get mass Material composition here
			for material, tablemass in pairs(Compositions) do

				MatSums[material] = 0

				for _, mass in pairs(tablemass) do

					MatSums[material] = MatSums[material] + mass

				end

				--Gets the actual material percent of the contraption
				PercentMat[material] = ( MatSums[material] / obj.acftotal ) or 0

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

		concommand.Add( "acf_dupes_remount", function()

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