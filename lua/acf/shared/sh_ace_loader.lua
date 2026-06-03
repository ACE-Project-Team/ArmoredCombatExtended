
-- Loads all files from shared folder
AddCSLuaFile()

ACF = ACF or {}

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

local AlternatorTable   = {}
local SolarPanelTable   = {}
local FuelSynthTable    = {}
local FieldGenTable     = {}
local FuelPlugTable     = {}
local FuelSocketTable   = {}
local FuelPipeTable     = {}
local TransferStationTable = {}
local TransformerTable  = {}
local PowerLineTable    = {}
local ConsumerTable     = {}
local CapacitorTable    = {}
local BurnerTable       = {}
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

local alternator_base = {
	ent    = "ace_alternator",
	type   = "Alternators"
}

local solar_base = {
	ent    = "ace_solarpanel",
	type   = "SolarPanels"
}

local fuelsynth_base = {
	ent    = "ace_fuel_synth",
	type   = "FuelSynths"
}

local fieldgen_base = {
	ent    = "ace_field_generator",
	type   = "FieldGenerators"
}

local fuelplug_base = {
	ent    = "ace_fuel_plug",
	type   = "FuelPlugs"
}

local fuelsocket_base = {
	ent    = "ace_fuel_socket",
	type   = "FuelSockets"
}

local fuelpipe_base = {
	ent    = "ace_fuel_pipe",
	type   = "FuelPipes"
}

local transferstation_base = {
	ent    = "ace_transfer_station",
	type   = "TransferStations"
}

local transformer_base = {
	ent    = "ace_transformer",
	type   = "Transformers"
}

local powerline_base = {
	ent    = "ace_power_line",
	type   = "PowerLines"
}

local consumer_base = {
	ent    = "ace_power_consumer",
	type   = "Consumers"
}

local capacitor_base = {
	ent    = "ace_capacitor",
	type   = "Capacitors"
}

local burner_base = {
	ent    = "ace_burner",
	type   = "Burners"
}

local explosive_base = {
	ent    = "ace_explosive",
	type   = "Explosives"
}

-- add gui stuff to base classes if this is client
-- more required stuff for the menu. Janky as fuck
if CLIENT then
	gun_base.guicreate           = function( _, Table ) ACFGunGUICreate( Table )		end or nil
	gun_base.guiupdate           = function() return end

	engine_base.guicreate        = function( _, tbl ) ACE_EngineGUI_Update( tbl )		end or nil

	gearbox_base.guicreate       = function( _, tbl ) ACFGearboxGUICreate( tbl )		end or nil
	gearbox_base.guiupdate       = function() return end

	fueltank_base.guicreate      = function( _, tbl ) ACFFuelTankGUICreate( tbl )		end or nil
	fueltank_base.guiupdate      = function( _, tbl ) ACFFuelTankGUIUpdate( tbl )		end or nil

	radar_base.guicreate         = function( _, Table ) ACFRadarGUICreate( Table )	end
	radar_base.guiupdate         = function() return end

	trackradar_base.guicreate    = function( _, Table ) ACFTrackRadarGUICreate( Table )  end or nil
	trackradar_base.guiupdate    = function() return end

	sonar_base.guicreate    = function( _, Table ) ACFSonarGUICreate( Table )  end or nil
	sonar_base.guiupdate    = function() return end

	irst_base.guicreate          = function( _, Table ) ACFIRSTGUICreate( Table )		end or nil
	irst_base.guiupdate          = function() return end

	vheat_source_base.guicreate  = function( _, Table ) ACEVHeatSourceGUICreate( Table )	end or nil
	vheat_source_base.guiupdate  = function() return end

	crewseat_base.guicreate  = function( _, Table ) ACECrewseatGUICreate( Table ) end or nil
	crewseat_base.guiupdate  = function() return end

	extras_base.guicreate    = function( _, Table ) ACEExtrasGUICreate( Table ) end or nil
	extras_base.guiupdate    = function() return end

	alternator_base.guicreate = function( _, Table ) ACEAlternatorGUICreate( Table ) end or nil
	alternator_base.guiupdate = function( _, Table ) ACEAlternatorGUIUpdate( Table ) end or nil

	solar_base.guicreate = function( _, Table ) ACESolarGUICreate( Table ) end or nil
	solar_base.guiupdate = function( _, Table ) ACESolarGUIUpdate( Table ) end or nil

	fuelsynth_base.guicreate = function( _, Table ) ACEFuelSynthGUICreate( Table ) end or nil
	fuelsynth_base.guiupdate = function( _, Table ) ACEFuelSynthGUIUpdate( Table ) end or nil

	fieldgen_base.guicreate = function( _, Table ) ACEFieldGenGUICreate( Table ) end or nil
	fieldgen_base.guiupdate = function( _, Table ) ACEFieldGenGUIUpdate( Table ) end or nil

	-- Plug and socket share one combined connector GUI (with a dropdown).
	fuelplug_base.guicreate = function( _, Table ) ACEFuelConnectorGUICreate( Table ) end or nil
	fuelplug_base.guiupdate = function( _, Table ) ACEFuelConnectorGUIUpdate( Table ) end or nil

	fuelsocket_base.guicreate = function( _, Table ) ACEFuelConnectorGUICreate( Table ) end or nil
	fuelsocket_base.guiupdate = function( _, Table ) ACEFuelConnectorGUIUpdate( Table ) end or nil

	fuelpipe_base.guicreate = function( _, Table ) ACEFuelConnectorGUICreate( Table ) end or nil
	fuelpipe_base.guiupdate = function( _, Table ) ACEFuelConnectorGUIUpdate( Table ) end or nil

	transferstation_base.guicreate = function( _, Table ) ACETransferStationGUICreate( Table ) end or nil
	transferstation_base.guiupdate = function( _, Table ) ACETransferStationGUIUpdate( Table ) end or nil

	transformer_base.guicreate = function( _, Table ) ACETransformerGUICreate( Table ) end or nil
	transformer_base.guiupdate = function( _, Table ) ACETransformerGUIUpdate( Table ) end or nil

	powerline_base.guicreate = function( _, Table ) ACEPowerLineGUICreate( Table ) end or nil
	powerline_base.guiupdate = function( _, Table ) ACEPowerLineGUIUpdate( Table ) end or nil

	consumer_base.guicreate = function( _, Table ) ACEConsumerGUICreate( Table ) end or nil
	consumer_base.guiupdate = function( _, Table ) ACEConsumerGUIUpdate( Table ) end or nil

	capacitor_base.guicreate = function( _, Table ) ACECapacitorGUICreate( Table ) end or nil
	capacitor_base.guiupdate = function( _, Table ) ACECapacitorGUIUpdate( Table ) end or nil

	burner_base.guicreate = function( _, Table ) ACEBurnerGUICreate( Table ) end or nil
	burner_base.guiupdate = function( _, Table ) ACEBurnerGUIUpdate( Table ) end or nil

	explosive_base.guicreate = function( _, Table ) ACEExplosiveGUICreate( Table ) end or nil
	explosive_base.guiupdate = function( _, Table ) ACEExplosiveGUIUpdate( Table ) end or nil
end

-- some factory functions for defining ents
-- Be patient. There are alot of functions here

--Gun class definition
function ACF_defineGunClass( id, data )
	if (data.year or 0) < ACF.Year then
		data.id = id
		GunClasses[ id ] = data
	end
end

-- Crewseat definition
function ACE_DefineCrewseat( id, data )
	data.id = id
	table.Inherit( data, crewseat_base )
	Crewseats[ id ] = data
end

-- Extras definition (wind sensor, gforce meter, etc.)
function ACE_DefineExtras( id, data )
	data.id = id
	table.Inherit( data, extras_base )
	Extras[ id ] = data
end

-- Gun definition
function ACF_defineGun( id, data )
	if (data.year or 0) < ACF.Year then
		data.id = id
		data.round.id = id
		table.Inherit( data, gun_base )
		GunTable[ id ] = data
	end
end

-- Muzzleflash definition. The definitions are likely to be placed at the same location as the gun itself
function ACE_DefineMuzzleFlash(id, data)
	data.id = id
	MuzzleFlashTable[ id ] = data
end

function ACE_DefineAmmoCrate( id, data )
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
function ACE_DefineLegacyAmmoCrate( id, data )
	data.id = id
	LegacyAmmoTable[ id ] = data
end

-- Rack definition
function ACF_DefineRack( id, data )
	data.id = id
	table.Inherit( data, rack_base )
	RackTable[ id ] = data
end

-- Rack class definition
function ACF_DefineRackClass( id, data )
	data.id = id
	RackClasses[ id ] = data
end

--Engine definition
function ACF_DefineEngine( id, data )
	if (data.year or 0) < ACF.Year then
		local engineData = ACF_CalcEnginePerformanceData(data.torquecurve or ACF.GenericTorqueCurves[data.enginetype], data.torque, data.idlerpm, data.limitrpm)

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
function ACF_DefineGearbox( id, data )
	data.id = id
	table.Inherit( data, gearbox_base )
	GearboxTable[ id ] = data
	MobilityTable[ id ] = data
end

-- fueltank definition
function ACF_DefineFuelTank( id, data )
	data.id = id
	table.Inherit( data, fueltank_base )
	FuelTankTable[ id ] = data
	MobilityTable[ id ] = data
end

-- fueltank size definition
function ACF_DefineFuelTankSize( id, data )
	data.id = id
	table.Inherit( data, fueltank_base )
	FuelTankSizeTable[ id ] = data
end

-- Radar definition
function ACF_DefineRadar( id, data )
	data.id = id
	table.Inherit( data, radar_base )
	Radars[ id ] = data
end

-- Alternator definition
function ACE_DefineAlternator( id, data )
	data.id = id
	table.Inherit( data, alternator_base )
	AlternatorTable[ id ] = data
end

-- Solar panel definition
function ACE_DefineSolarPanel( id, data )
	data.id = id
	table.Inherit( data, solar_base )
	SolarPanelTable[ id ] = data
end

-- Fuel synthesizer definition
function ACE_DefineFuelSynth( id, data )
	data.id = id
	table.Inherit( data, fuelsynth_base )
	FuelSynthTable[ id ] = data
end

-- Field generator definition
function ACE_DefineFieldGenerator( id, data )
	data.id = id
	table.Inherit( data, fieldgen_base )
	FieldGenTable[ id ] = data
end

-- Fuel plug definition (supply-side nozzle)
function ACE_DefineFuelPlug( id, data )
	data.id = id
	table.Inherit( data, fuelplug_base )
	FuelPlugTable[ id ] = data
end

-- Fuel socket definition (receiver-side port)
function ACE_DefineFuelSocket( id, data )
	data.id = id
	table.Inherit( data, fuelsocket_base )
	FuelSocketTable[ id ] = data
end

-- Fuel pipe definition (long-distance link between two sockets)
function ACE_DefineFuelPipe( id, data )
	data.id = id
	table.Inherit( data, fuelpipe_base )
	FuelPipeTable[ id ] = data
end

-- Transfer station definition (DC<->AC grid converter)
function ACE_DefineTransferStation( id, data )
	data.id = id
	table.Inherit( data, transferstation_base )
	TransferStationTable[ id ] = data
end

-- Transformer definition (AC voltage step-up/step-down, optional rectifier)
function ACE_DefineTransformer( id, data )
	data.id = id
	table.Inherit( data, transformer_base )
	TransformerTable[ id ] = data
end

-- Power line definition (scalable physical conductor / catenary)
function ACE_DefinePowerLine( id, data )
	data.id = id
	table.Inherit( data, powerline_base )
	PowerLineTable[ id ] = data
end

-- Power consumer definition (scalable grid load)
function ACE_DefineConsumer( id, data )
	data.id = id
	table.Inherit( data, consumer_base )
	ConsumerTable[ id ] = data
end

-- Capacitor definition (scalable fast buffer node)
function ACE_DefineCapacitor( id, data )
	data.id = id
	table.Inherit( data, capacitor_base )
	CapacitorTable[ id ] = data
end

-- Fuel burner / flare definition (burns liquid fuel from a linked tank)
function ACE_DefineBurner( id, data )
	data.id = id
	table.Inherit( data, burner_base )
	BurnerTable[ id ] = data
end

-- Explosive charge definition
function ACE_DefineExplosive( id, data )
	data.id = id
	table.Inherit( data, explosive_base )
	ExplosiveTable[ id ] = data
end

-- Radar Class definition
function ACF_DefineRadarClass( id, data )
	data.id = id
	RadarClasses[ id ] = data
end


-- Tracking Radar definition
function ACF_DefineTrackRadar( id, data )
	data.id = id
	table.Inherit( data, trackradar_base )
	Radars[ id ] = data
end

-- Tracking Radar Class definition
function ACF_DefineTrackRadarClass( id, data )
	data.id = id
	RadarClasses[ id ] = data
end

-- Sonar Array Class definition
function ACF_DefineSonarClass( id, data )
	data.id = id
	RadarClasses[ id ] = data
end

-- Sonar definition
function ACF_DefineSonar( id, data )
	data.id = id
	table.Inherit( data, sonar_base )
	Radars[ id ] = data
end

-- Tracking Radar definition
function ACF_DefineIRST( id, data )
	data.id = id
	table.Inherit( data, irst_base )
	Radars[ id ] = data
end

-- Tracking Radar Class definition
function ACF_DefineIRSTClass( id, data )
	data.id = id
	RadarClasses[ id ] = data
end

-- Virtual Heat Source definition
function ACF_DefineVHeatSource( id, data )
	data.id = id
	table.Inherit( data, vheat_source_base )
	Tools[ id ] = data
end

--Step 2: gather specialized sounds. Normally sounds that have associated sounds into it. Literally using the string path as id.
function ACE_DefineGunFireSound( id, data )
	data.id = id
	GSoundData[id] = data
end

-- The model definition. This is where you can "add" scalable models.
function ACE_DefineModelData( id, data )
	data.id = id
	ModelData[id] = data
	ModelData[data.Model] = data -- I will allow both model or fast name as id.
end

-- Where you define a new Mine
function ACE_DefineMine(id, data)
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

function ACF_GetAllGuidanceNames()

	local ret = {}
	for name, _ in pairs(ACF.Guidance) do
		ret[#ret + 1] = name
	end
	return ret
end

function ACF_GetAllGuidanceNamesExcept(list)
	return GetAllInTableExcept(ACF.Guidance, list)
end

-- Getters for fuse names, for use in missile definitions.
function ACF_GetAllFuseNames()

	local ret = {}
	for name, _ in pairs(ACF.Fuse) do
		ret[#ret + 1] = name
	end
	return ret
end

function ACF_GetAllFuseNamesExcept(list)
	return GetAllInTableExcept(ACF.Fuse, list)
end

-- search for and load a bunch of files or whatever
--
do

	local Gpath = "acf/shared/"
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
		"power",
		"solar",
		"explosives"
	}

	for _, folder in ipairs(folders) do

		local folderData = file.Find( Gpath .. folder .. "/*.lua", "LUA" )
		for _, v in pairs( folderData ) do
			AddCSLuaFile( "acf/shared/" .. folder .. "/" .. v )
			include( "acf/shared/" .. folder .. "/" .. v )
		end

	end

end

-- now that the tables are populated, throw them in the acf ents list
ACF.Classes.GunClass        = GunClasses
ACF.Classes.Rack            = RackClasses
ACF.Classes.Radar           = RadarClasses

ACF.Weapons.Ammo            = AmmoTable --end ammo containers listing
ACF.Weapons.LegacyAmmo      = LegacyAmmoTable

ACF.Weapons.Guns            = GunTable
ACF.Weapons.Racks           = RackTable
ACF.Weapons.Engines         = EngineTable
ACF.Weapons.Gearboxes       = GearboxTable
ACF.Weapons.FuelTanks       = FuelTankTable
ACF.Weapons.FuelTanksSize   = FuelTankSizeTable
ACF.Weapons.Radars          = Radars
ACF.Weapons.Tools           = Tools
ACF.Weapons.Crewseats       = Crewseats
ACF.Weapons.Extras          = Extras
ACF.Weapons.Alternators     = AlternatorTable
ACF.Weapons.SolarPanels     = SolarPanelTable
ACF.Weapons.FuelSynths      = FuelSynthTable
ACF.Weapons.FieldGenerators = FieldGenTable
ACF.Weapons.FuelPlugs       = FuelPlugTable
ACF.Weapons.FuelSockets     = FuelSocketTable
ACF.Weapons.FuelPipes       = FuelPipeTable
ACF.Weapons.TransferStations = TransferStationTable
ACF.Weapons.Transformers    = TransformerTable
ACF.Weapons.PowerLines      = PowerLineTable
ACF.Weapons.Consumers       = ConsumerTable
ACF.Weapons.Capacitors      = CapacitorTable
ACF.Weapons.Burners         = BurnerTable
ACF.Weapons.Explosives      = ExplosiveTable
ACE.MuzzleFlashes           = MuzzleFlashTable

--Small reminder of Mobility table. Still being used in stuff like starfall/e2. This can change
ACF.Weapons.Mobility    = MobilityTable

ACE.GSounds.GunFire     = GSoundData
ACE.ModelData           = ModelData
ACE.MineData            = MineData