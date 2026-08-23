
ACE.DefineTrackRadarClass("DIR-SEARCH", {
	name = "Search Radar",
	type = "Search-Radar",
	desc = "Search radar with unlimited range. Will periodically scan in a full 360 circle. Larger radars will scan faster. More susceptible than Track radars to jamming."
} )


--ECM Beam width strength
--Center beam 1x strength
--1 axis off (90 deg) - 1/3x
--2 axis off (180deg) - 1/6x


--Massive early warning radar for quickly scanning the airspace. Very good burnthrough capability.
ACE.DefineTrackRadar("Large-SEARCH", {
	name		= "Large Search Radar",
	ent			= "ace_searchradar",
	desc		= "Massive search radar for quickly searching the airspace. Extremely jam resistent.",
	model		= "models/radar/radar_sp_big.mdl",
	class		= "DIR-SEARCH",
	weight		= 1400,
	viewcone	= 360 / 2,				--sets the horizontal search cone of the radar in degrees. 360/4 is 90 deg/s scanning
	burnthrough = 600,					--Maximum burnthrough range. 800 means the radar will burn-through at 800m
	powerid		= 4,					--Power ranking of radar for RWR identification
	animspeed = 1,
	acepoints = 1500 --In current system roughly amounts to ~1000pts
} )

--Gold standard search radar. Decently pricey and heavy but good search time.
ACE.DefineTrackRadar("Medium-SEARCH", {
	name		= "Medium Search Radar",
	ent			= "ace_searchradar",
	desc		= "Middle size search radar. Sweeps the air at a decent rate. Not particularly jam resistent but gets the job done.",
	model		= "models/radar/radar_sp_mid.mdl",
	class		= "DIR-SEARCH",
	weight		= 700,
	viewcone	= 360 / 4,				--sets the cone of this radar in degrees. this represents the half of the total cone, so 15 means 30 degrees in total
	burnthrough = 400,					--Maximum burnthrough range. 500 means the radar will burn-through at 500m
	powerid		= 5,					--Power ranking of radar for RWR identification
	animspeed = 0.375,
	acepoints = 600 --In current system roughly amounts to ~400pts
} )

--Slowly scanning light search radar
ACE.DefineTrackRadar("Small-SEARCH", { --Does not burn through.
	name		= "Small Search Radar",
	ent			= "ace_searchradar",
	desc		= "Compact. Though usable as a search radar the tiny viewcone makes it difficult to use. Will never burn through but it is light.",
	model		= "models/radar/radar_sp_sml.mdl",
	class		= "DIR-SEARCH",
	weight		= 180,
	viewcone	= 360 / 7,				--sets the cone of this radar in degrees. this represents the half of the total cone, so 15 means 30 degrees in total
	burnthrough = 0,					--Will not burn through.
	powerid		= 6,					--Power ranking of radar for RWR identification
	animspeed = 0.28,
	acepoints = 300 --In current system roughly amounts to ~200pts
} )

--Rapidly scanning dual purpose radar
ACE.DefineTrackRadar("Small-SEARCH-Omni", { --Does not burn through.
	name		= "Omni Search Radar",
	ent			= "ace_searchradar",
	desc		= "Tiny, purpose-built search radar that frantically combs the local airspace for missiles and drone threats. Excellent Point-defense radar. Unlike the other search radar this radar is limited to 75m range.",
	model		= "models/radar/radar_sp_sml.mdl",
	class		= "DIR-SEARCH",
	weight		= 70,
	viewcone	= 1440,				--sets the cone of this radar in degrees. this represents the half of the total cone, so 15 means 30 degrees in total
	burnthrough = 0,					--Will not burn through.
	powerid		= 6,					--Power ranking of radar for RWR identification
	animspeed = 8,
	acepoints = 600, --In current system roughly amounts to ~400pts
	maxrange = 75 --Max range of radar in meters
} )

--Base inaccuracy of radars is 0.02 meters per every meter range.
--8 meters @ 400m. 
--16 meters @ 800m. 
--Jamming adds 50% inaccuracy even when burning through.
--12 meters @ 400m
--18 meters @ 800m
