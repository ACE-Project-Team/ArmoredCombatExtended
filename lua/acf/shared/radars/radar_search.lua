
ACE_DefineTrackRadarClass("DIR-SEARCH", {
	name = "Search Radar",
	type = "Search-Radar",
	desc = "Search radar with unlimited range. Will periodically scan in a full 360 circle. Larger radars will scan faster. More susceptible than Track radars to jamming."
} )


--ECM Beam width strength
--Center beam 1x strength
--1 axis off (90 deg) - 1/3x
--2 axis off (180deg) - 1/6x


--Large SAM Radar better able to search for targets and burn-through jamming. Max burn through at 200m. Negligible accuracy loss from offbore targets.
ACE_DefineTrackRadar("Large-SEARCH", {
	name		= "Large Search Radar",
	ent			= "ace_searchradar",
	desc		= "Massive search radar for quickly searching the airspace. More jam resistent than its smaller counterparts.",
	model		= "models/radar/radar_sp_big.mdl",
	class		= "DIR-SEARCH",
	weight		= 2400,
	viewcone	= 360 / 2,				--sets the horizontal search cone of the radar in degrees. 360/4 is 90 deg/s scanning
	burnthrough = 4,					--Burn through power at 1 degree seeker. x4 means burn through at 400m when fully in the center of a jam beam and set to 1 degree cone.
	powerid		= 4,					--Power ranking of radar for RWR identification
	animspeed = 1,
	acepoints = 600
} )

--Baseline radar. Solid track cone. Center beam burn through at 200m. Decent offbore accuracy.
ACE_DefineTrackRadar("Medium-SEARCH", {
	name		= "Medium Search Radar",
	ent			= "ace_searchradar",
	desc		= "Middle size search radar. Sweeps the air at a decent rate. Not particularly jam resistent but gets the job done.",
	model		= "models/radar/radar_sp_mid.mdl",
	class		= "DIR-SEARCH",
	weight		= 900,
	viewcone	= 360 / 4,				--sets the cone of this radar in degrees. this represents the half of the total cone, so 15 means 30 degrees in total
	burnthrough = 2.5,					--Burn through power at 1 degree seeker. x2.5 means burn through at 250m when fully in the center of a jam beam and set to 1 degree cone.
	powerid		= 5,					--Power ranking of radar for RWR identification
	animspeed = 0.375,
	acepoints = 300
} )

--Only useful as a fire director
ACE_DefineTrackRadar("Small-SEARCH", { --Does not burn through.
	name		= "Small Search Radar",
	ent			= "ace_searchradar",
	desc		= "Compact. Though usable as a fire director the tiny viewcone and offbore accuracy make it difficult to use. Will never burn through but it is light.",
	model		= "models/radar/radar_sp_sml.mdl",
	class		= "DIR-SEARCH",
	weight		= 300,
	viewcone	= 360 / 7,				--sets the cone of this radar in degrees. this represents the half of the total cone, so 15 means 30 degrees in total
	burnthrough = 0,					--Will not burn through.
	powerid		= 6,					--Power ranking of radar for RWR identification
	animspeed = 0.28,
	acepoints = 150
} )

--For every 200m, apply 2 units of inaccuracy. Across map there are 8 units accuracy. diagonally 12 units of inaccuracy.
