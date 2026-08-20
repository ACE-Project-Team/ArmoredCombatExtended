
-- Loads all files from shared folder
AddCSLuaFile()

ACE = ACE or {}

local GunClasses        = {}
local RackClasses       = {}
local RadarClasses      = {}

local GunTable          = {}
local RackTable         = {}
local Radars            = {}
local Tools             = {}

local AmmoTable         = {}
local LegacyAmmoTable   = {}

local EngineTable       = {}
local GearboxTable      = {}
local FuelTankTable     = {}
local FuelTankSizeTable = {}
local MuzzleFlashTable  = {}

local MobilityTable     = {}
local Crewseats         = {}
local Extras            = {}

local ExplosiveTable    = {}

local GSoundData        = {}
local ModelData         = {}
local MineData          = {}

-- setup base classes. This is necessary stuff if you want to setup a menu for a specific item.
-- Janky as fuck though.
local gun_base = {
	ent    = "acf_gun",
	type   = "Guns"
}
local ammo_base = {
	ent = "acf_ammo",
	type = "Ammo"
}
local engine_base = {
	ent    = "acf_engine",
	type   = "Engines"
}
local gearbox_base = {
	ent    = "acf_gearbox",
	type   = "Gearboxes",
	sound  = "vehicles/junker/jnk_fourth_cruise_loop2.wav"
}
local fueltank_base = {
	ent    = "acf_fueltank",
	type   = "FuelTanks"
}
local rack_base = {
	ent    = "acf_rack",
	type   = "Racks"
}
local radar_base = {
	ent    = "acf_missileradar",
	type   = "Radars"
}
local trackradar_base = {
	ent    = "ace_trackingradar",
	type   = "Radars"
}
local sonar_base = {
	ent    = "ace_sonar",
	type   = "Radars"
}
local irst_base = {
	ent    = "ace_irst",
	type   = "Radars"
}
local vheat_source_base = {
	ent    = "ace_vheat_source",
	type   = "Tools"
}

local crewseat_base = {
	type   = "Crewseats"
}

local extras_base = {
	type   = "Extras"
}

local explosive_base = {
	ent    = "ace_explosive",
	type   = "Explosives"
}

-- add gui stuff to base classes if this is client
-- more required stuff for the menu. Janky as fuck
if CLIENT then
	gun_base.guicreate           = function( _, Table ) ACE.GunGUICreate( Table )		end or nil
	gun_base.guiupdate           = function() return end

	engine_base.guicreate        = function( _, tbl ) ACE.EngineGUI_Update( tbl )		end or nil

	gearbox_base.guicreate       = function( _, tbl ) ACE.GearboxGUICreate( tbl )		end or nil
	gearbox_base.guiupdate       = function() return end

	fueltank_base.guicreate      = function( _, tbl ) ACE.FuelTankGUICreate( tbl )		end or nil
	fueltank_base.guiupdate      = function( _, tbl ) ACE.FuelTankGUIUpdate( tbl )		end or nil

	radar_base.guicreate         = function( _, Table ) ACE.RadarGUICreate( Table )	end
	radar_base.guiupdate         = function() return end

	trackradar_base.guicreate    = function( _, Table ) ACE.TrackRadarGUICreate( Table )  end or nil
	trackradar_base.guiupdate    = function() return end

	sonar_base.guicreate    = function( _, Table ) ACE.SonarGUICreate( Table )  end or nil
	sonar_base.guiupdate    = function() return end

	irst_base.guicreate          = function( _, Table ) ACE.IRSTGUICreate( Table )		end or nil
	irst_base.guiupdate          = function() return end

	vheat_source_base.guicreate  = function( _, Table ) ACE.VHeatSourceGUICreate( Table )	end or nil
	vheat_source_base.guiupdate  = function() return end

	crewseat_base.guicreate  = function( _, Table ) ACE.CrewMenuGUICreate( Table ) end or nil
	crewseat_base.guiupdate  = function() return end

	extras_base.guicreate    = function( _, Table ) ACE.ExtrasGUICreate( Table ) end or nil
	extras_base.guiupdate    = function() return end

	explosive_base.guicreate = function( _, Table ) ACE.ExplosiveGUICreate( Table ) end or nil
	explosive_base.guiupdate = function( _, Table ) ACE.ExplosiveGUIUpdate( Table ) end or nil
end

-- some factory functions for defining ents
-- Be patient. There are alot of functions here

--Gun class definition
function ACE.DefineGunClass( id, data )
	if (data.year or 0) < ACE.Year then
		data.id = id
		GunClasses[ id ] = data
	end
end

-- Crewseat definition
function ACE.DefineCrewseat( id, data )
	data.id = id
	table.Inherit( data, crewseat_base )
	Crewseats[ id ] = data
end

-- Extras definition (wind sensor, gforce meter, etc.)
function ACE.DefineExtras( id, data )
	data.id = id
	table.Inherit( data, extras_base )
	Extras[ id ] = data
end

-- Generic entity-definition entry point retained for shared metadata files.
function ACE.DefineEntity( id, data )
	if data.category == "Crew" then
		return ACE.DefineCrewseat(id, data)
	end

	return ACE.DefineExtras(id, data)
end

-- Gun definition
function ACE.DefineGun( id, data )
	if (data.year or 0) < ACE.Year then
		data.id = id
		data.round.id = id
		table.Inherit( data, gun_base )
		GunTable[ id ] = data
	end
end

-- Muzzleflash definition. The definitions are likely to be placed at the same location as the gun itself
function ACE.DefineMuzzleFlash(id, data)
	data.id = id
	MuzzleFlashTable[ id ] = data
end

function ACE.DefineAmmoCrate( id, data )
	data.id = id

	-- Backwards/forwards compatibility for legacy typo key.
	if data.Length == nil and data.Lenght ~= nil then
		data.Length = data.Lenght
	elseif data.Lenght == nil and data.Length ~= nil then
		data.Lenght = data.Length
	elseif data.Length ~= nil and data.Lenght ~= nil and data.Length ~= data.Lenght then
		-- Prefer canonical key when both are present but disagree.
		data.Lenght = data.Length
	end

	table.Inherit( data, ammo_base )
	AmmoTable[ id ] = data
end

-- Legacy Ammo crate definition
function ACE.DefineLegacyAmmoCrate( id, data )
	data.id = id
	LegacyAmmoTable[ id ] = data
end

-- Rack definition
function ACE.DefineRack( id, data )
	data.id = id
	table.Inherit( data, rack_base )
	RackTable[ id ] = data
end

-- Rack class definition
function ACE.DefineRackClass( id, data )
	data.id = id
	RackClasses[ id ] = data
end

--Engine definition
function ACE.DefineEngine( id, data )
	if (data.year or 0) < ACE.Year then
		local engineData = ACE.CalcEnginePerformanceData(data.torquecurve or ACE.GenericTorqueCurves[data.enginetype], data.torque, data.idlerpm, data.limitrpm)

		data.peaktqrpm    = engineData.peakTqRPM
		data.peakpower    = engineData.peakPower
		data.peakpowerrpm = engineData.peakPowerRPM
		data.peakminrpm   = engineData.powerbandMinRPM
		data.peakmaxrpm   = engineData.powerbandMaxRPM
		data.curvefactor  = (data.limitrpm - data.idlerpm) / data.limitrpm

		data.id = id
		table.Inherit( data, engine_base )
		EngineTable[ id ] = data
		MobilityTable[ id ] = data
	end
end

-- Gearbox definition
function ACE.DefineGearbox( id, data )
	data.id = id
	table.Inherit( data, gearbox_base )
	GearboxTable[ id ] = data
	MobilityTable[ id ] = data
end

-- fueltank definition
function ACE.DefineFuelTank( id, data )
	data.id = id
	table.Inherit( data, fueltank_base )
	FuelTankTable[ id ] = data
	MobilityTable[ id ] = data
end

-- fueltank size definition
function ACE.DefineFuelTankSize( id, data )
	data.id = id
	table.Inherit( data, fueltank_base )
	FuelTankSizeTable[ id ] = data
end

-- Radar definition
function ACE.DefineRadar( id, data )
	data.id = id
	table.Inherit( data, radar_base )
	Radars[ id ] = data
end

-- Explosive charge definition
function ACE.DefineExplosive( id, data )
	data.id = id
	table.Inherit( data, explosive_base )
	ExplosiveTable[ id ] = data
end

-- Radar Class definition
function ACE.DefineRadarClass( id, data )
	data.id = id
	RadarClasses[ id ] = data
end


-- Tracking Radar definition
function ACE.DefineTrackRadar( id, data )
	data.id = id
	table.Inherit( data, trackradar_base )
	Radars[ id ] = data
end

-- Tracking Radar Class definition
function ACE.DefineTrackRadarClass( id, data )
	data.id = id
	RadarClasses[ id ] = data
end

-- Sonar Array Class definition
function ACE.DefineSonarClass( id, data )
	data.id = id
	RadarClasses[ id ] = data
end

-- Sonar definition
function ACE.DefineSonar( id, data )
	data.id = id
	table.Inherit( data, sonar_base )
	Radars[ id ] = data
end

-- Tracking Radar definition
function ACE.DefineIRST( id, data )
	data.id = id
	table.Inherit( data, irst_base )
	Radars[ id ] = data
end

-- Tracking Radar Class definition
function ACE.DefineIRSTClass( id, data )
	data.id = id
	RadarClasses[ id ] = data
end

-- Virtual Heat Source definition
function ACE.DefineVHeatSource( id, data )
	data.id = id
	table.Inherit( data, vheat_source_base )
	Tools[ id ] = data
end

--Step 2: gather specialized sounds. Normally sounds that have associated sounds into it. Literally using the string path as id.
function ACE.DefineGunFireSound( id, data )
	data.id = id
	GSoundData[id] = data
end

-- The model definition. This is where you can "add" scalable models.
function ACE.DefineModelData( id, data )
	data.id = id
	ModelData[id] = data
	ModelData[data.Model] = data -- I will allow both model or fast name as id.
end

-- Where you define a new Mine
function ACE.DefineMine(id, data)
	data.id = id
	MineData[id] = data
end

-- Getters for guidance names, for use in missile definitions.
local function GetAllInTableExcept(tbl, list)

	for k, name in ipairs(list) do
		list[name] = k
		list[k] = nil
	end
	local ret = {}
	for name, _ in pairs(tbl) do
		if not list[name] then
			ret[#ret + 1] = name
		end
	end
	return ret
end

function ACE.GetAllGuidanceNames()

	local ret = {}
	for name, _ in pairs(ACE.Guidance) do
		ret[#ret + 1] = name
	end
	return ret
end

function ACE.GetAllGuidanceNamesExcept(list)
	return GetAllInTableExcept(ACE.Guidance, list)
end

-- Getters for fuse names, for use in missile definitions.
function ACE.GetAllFuseNames()

	local ret = {}
	for name, _ in pairs(ACE.Fuse) do
		ret[#ret + 1] = name
	end
	return ret
end

function ACE.GetAllFuseNamesExcept(list)
	return GetAllInTableExcept(ACE.Fuse, list)
end

-- search for and load a bunch of files or whatever
--
do

	local Gpath = "ace/shared/"
	local folders = {
		"armor",
		"guns",
		"rounds",
		"missiles",
		"mines",
		"radars",
		"ammocrates",
		"engines",
		"gearboxes",
		"guidances",
		"fueltanks",
		"fuses",
		"sounds",
		"tools",
		"crewseats",
		"extras",
		"explosives"
	}

	for _, folder in ipairs(folders) do

		local folderData = file.Find( Gpath .. folder .. "/*.lua", "LUA" )
		for _, v in pairs( folderData ) do
			AddCSLuaFile( "ace/shared/" .. folder .. "/" .. v )
			include( "ace/shared/" .. folder .. "/" .. v )
		end

	end

end

-- now that the tables are populated, throw them in the acf ents list
ACE.Classes.GunClass        = GunClasses
ACE.Classes.Rack            = RackClasses
ACE.Classes.Radar           = RadarClasses

ACE.Weapons.Ammo            = AmmoTable --end ammo containers listing
ACE.Weapons.LegacyAmmo      = LegacyAmmoTable

ACE.Weapons.Guns            = GunTable
ACE.Weapons.Racks           = RackTable
ACE.Weapons.Engines         = EngineTable
ACE.Weapons.Gearboxes       = GearboxTable
ACE.Weapons.FuelTanks       = FuelTankTable
ACE.Weapons.FuelTanksSize   = FuelTankSizeTable
ACE.Weapons.Radars          = Radars
ACE.Weapons.Tools           = Tools
ACE.Weapons.Crewseats       = Crewseats
ACE.Weapons.Extras          = Extras
ACE.Weapons.Explosives      = ExplosiveTable
ACE.MuzzleFlashes           = MuzzleFlashTable

--Small reminder of Mobility table. Still being used in stuff like starfall/e2. This can change
ACE.Weapons.Mobility    = MobilityTable

ACE.GSounds.GunFire     = GSoundData
ACE.ModelData           = ModelData
ACE.MineData            = MineData
