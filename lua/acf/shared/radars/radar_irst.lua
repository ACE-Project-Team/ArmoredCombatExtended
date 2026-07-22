ACE_DefineIRSTClass("DIR-IRST", {
	name = "Infrared Search and Track",
	type = "IRST",
	desc = "The Infra-Red Search and Track (IRST) is a device which can detect targets by their heat. Has a limited range but the IRST will not alert to its opponent if he's being tracked unlike tracking radars, being useful for stealth applications."
} )

ACE_DefineIRST("Small-IRST", {
	name			= "Small IRST Device",
	ent				= "ace_irst",
	desc			= "A small IRST device used by fighter jets to track the heat of its target.",
	model			= "models/props_lab/monitor01b.mdl",
	class			= "DIR-IRST",
	weight			= 400,
	viewcone		= 60,				--sets the cone of this radar in degrees. this represents the half of the total cone, so 15 means 30 degrees in total
	acepoints = 250
} )
