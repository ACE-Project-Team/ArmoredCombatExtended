
ACE.DefineTrackRadarClass("DIR-TRACK", {
	name = "Tracking Radar",
	type = "Tracking-Radar",
	desc = "A radar with unlimited range but limited view cone. Unlike the antimissile radar, this can detect vehicles in front of it, but is affected by ground clutter and subject to jamming.\n\nTo reduce inaccuracy point radar directly at the intended target. Offbore aim reduces accuracy. \n\nIf being jammed set a lower scan cone to increase resistence to jamming. Larger radars are also more jam resistent."
} )


--ECM Beam width strength
--Center beam 1x strength
--1 axis off (90 deg) - 1/3x
--2 axis off (180deg) - 1/6x


--Large SAM Radar better able to search for targets and burn-through jamming. Max burn through at 200m. Negligible accuracy loss from offbore targets.
ACE.DefineTrackRadar("Large-TRACK", {
	name		= "Large Tracking Radar",
	ent			= "ace_trackingradar",
	desc		= "A large tracking radar mostly meant for ground installations. Can track offbore targets with negligible loss of accuracy. Powerful and capable of burning through jamming with ease.",
	model		= "models/radar/radar_big.mdl",
	class		= "DIR-TRACK",
	weight		= 140,
	viewcone	= 15,				--sets the cone of this radar in degrees. this represents half of the total cone, so 15 means 30 degrees in total.
	offborefactor = 5,				--Largest multiplier for radar inaccuracy when targets are at the very edge of the radar cone. 5x means 5x inaccuracy at the max cone angle of the radar.
	burnthrough = 400,				--Maximum burnthrough range. 400 means the radar will burn-through at 400m when the radar is set to a 5 degree cone.
	powerid		= 1,				--Power ranking of radar for RWR identification
	acepoints = 770 --In current system roughly amounts to ~500pts
} )

--Baseline radar. Solid track cone. Center beam burn through at 200m. Decent offbore accuracy.
ACE.DefineTrackRadar("Medium-TRACK", {
	name		= "Medium Tracking Radar",
	ent			= "ace_trackingradar",
	desc		= "Mid-size radar useful in jets and fire directors when you cannot fit the larger radar. Needs to be aiming at a target to be fully accurate. Less useful for searching than the larger counterpart.",
	model		= "models/radar/radar_mid.mdl",
	class		= "DIR-TRACK",
	weight		= 90,
	viewcone	= 8,				--sets the cone of this radar in degrees. this represents half of the total cone, so 15 means 30 degrees in total
	offborefactor = 10,				--Largest multiplier for radar inaccuracy when targets are at the very edge of the radar cone. 5x means 5x inaccuracy at the max cone angle of the radar.
	burnthrough = 250,				--Maximum burnthrough range. 250 means the radar will burn-through at 250m when the radar is set to a 5 degree cone.
	powerid		= 2,				--Power ranking of radar for RWR identification
	acepoints = 540 --In current system roughly amounts to ~350pts
} )

--Only useful as a fire director
ACE.DefineTrackRadar("Small-TRACK", { --Does not burn through.
	name		= "Small Tracking Radar",
	ent			= "ace_trackingradar",
	desc		= "Compact. Though usable as a fire director the tiny viewcone and offbore accuracy make it difficult to use. Will never burn through but it is light.",
	model		= "models/radar/radar_sml.mdl",
	class		= "DIR-TRACK",
	weight		= 50,
	viewcone	= 4,				--sets the cone of this radar in degrees. this represents half of the total cone, so 15 means 30 degrees in total
	offborefactor = 2.5,				--Largest multiplier for radar inaccuracy when targets are at the very edge of the radar cone. 5x means 5x inaccuracy at the max cone angle of the radar.
	burnthrough = 0,				--Will not burn through.
	powerid		= 3,				--Power ranking of radar for RWR identification
	acepoints = 380 --In current system roughly amounts to ~250pts
} )

--Base inaccuracy of radars is 0.02 meters per every meter range.
--4 meters @ 400m. 
--8 meters @ 800m. 
--Jamming adds 50% inaccuracy even when burning through.
--6 meters @ 400m
--12 meters @ 800m


--Offbore factor is 1x when 1/8th the total angle offbore and 5x when fully offbore.
