
ACE_DefineTrackRadarClass("DIR-TRACK", {
	name = "Tracking Radar",
	type = "Tracking-Radar",
	desc = "A radar with unlimited range but limited view cone. Unlike the antimissile radar, this can detect vehicles in front of it, but is affected by ground clutter and subject to jamming.\n\nTo reduce inaccuracy point radar directly at the intended target. Offbore aim reduces accuracy. \n\nIf being jammed set a lower scan cone to increase resistence to jamming. Larger radars are also more jam resistent."
} )


--ECM Beam width strength
--Center beam 1x strength
--1 axis off (90 deg) - 1/3x
--2 axis off (180deg) - 1/6x


--Large SAM Radar better able to search for targets and burn-through jamming. Max burn through at 200m. Negligible accuracy loss from offbore targets.
ACE_DefineTrackRadar("Large-TRACK", {
	name		= "Large Tracking Radar",
	ent			= "ace_trackingradar",
	desc		= "A large and HEAVY tracking radar mostly meant for ground installations. Can track offbore targets with negligible loss of accuracy. Powerful and capable of burning through jamming with ease.",
	model		= "models/radar/radar_big.mdl",
	class		= "DIR-TRACK",
	weight		= 4200,
	viewcone	= 15,				--sets the cone of this radar in degrees. this represents the half of the total cone, so 15 means 30 degrees in total.
	offborefactor = 5,				--Inaccuracy modifier for targets at maximum offbore
	burnthrough = 4,				--Burn through power at 1 degree seeker. x4 means burn through at 400m when fully in the center of a jam beam and set to 1 degree cone.
	powerid		= 1,				--Power ranking of radar for RWR identification
	acepoints = 1200
} )

--Baseline radar. Solid track cone. Center beam burn through at 200m. Decent offbore accuracy.
ACE_DefineTrackRadar("Medium-TRACK", {
	name		= "Medium Tracking Radar",
	ent			= "ace_trackingradar",
	desc		= "Mid-size radar useful in jets and fire directors when you cannot fit the larger radar. Needs to be aiming at a target to be fully accurate. Less useful for searching than the larger counterpart.",
	model		= "models/radar/radar_mid.mdl",
	class		= "DIR-TRACK",
	weight		= 1200,
	viewcone	= 8,				--sets the cone of this radar in degrees. this represents the half of the total cone, so 15 means 30 degrees in total
	offborefactor = 10,				--Inaccuracy modifier for targets at maximum offbore
	burnthrough = 2.5,				--Burn through power at 1 degree seeker. x2.5 means burn through at 250m when fully in the center of a jam beam and set to 1 degree cone.
	powerid		= 2,				--Power ranking of radar for RWR identification
	acepoints = 800
} )

--Only useful as a fire director
ACE_DefineTrackRadar("Small-TRACK", { --Does not burn through.
	name		= "Small Tracking Radar",
	ent			= "ace_trackingradar",
	desc		= "Compact. Though usable as a fire director the tiny viewcone and offbore accuracy make it difficult to use. Will never burn through but it is light.",
	model		= "models/radar/radar_sml.mdl",
	class		= "DIR-TRACK",
	weight		= 600,
	viewcone	= 4,				--sets the cone of this radar in degrees. this represents the half of the total cone, so 15 means 30 degrees in total
	offborefactor = 20,				--Inaccuracy modifier for targets at maximum offbore
	burnthrough = 0,				--Will not burn through.
	powerid		= 3,				--Power ranking of radar for RWR identification
	acepoints = 550
} )

--For every 400m, apply 1 unit of inaccuracy. Across map there are 4 units accuracy. diagonally 6 units of inaccuracy.
--Offbore factor is 1x when 1/8th the total angle offbore and 5x when fully offbore.
