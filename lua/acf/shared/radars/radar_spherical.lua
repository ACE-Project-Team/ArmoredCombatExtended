
ACE.DefineRadarClass("OMNI-AM", {
	name = "Spherical Anti-missile Radar",
	type = "Anti-missile",
	desc = ACE.Translation.Radar[5],
} )




ACE.DefineRadar("SmallOMNI-AM", {
	name		= "Small Spherical Anti-Missile Radar",
	ent			= "acf_missileradar",
	desc		= ACE.Translation.Radar[6],
	model		= "models/radar/radar_sp_sml.mdl",
	class		= "OMNI-AM",
	weight		= 300,
	range		= 7874, -- range in inches.
	acepoints = 900
} )


ACE.DefineRadar("MediumOMNI-AM", {
	name		= "Medium Spherical Anti-Missile Radar",
	ent			= "acf_missileradar",
	desc		= ACE.Translation.Radar[7],
	model		= "models/radar/radar_sp_mid.mdl", -- medium one is for now scalled big one - will be changed
	class		= "OMNI-AM",
	weight		= 600,
	range		= 15748, -- range in inches.
	acepoints = 1400
} )


ACE.DefineRadar("LargeOMNI-AM", {
	name		= "Large Spherical Anti-Missile Radar",
	ent			= "acf_missileradar",
	desc		= ACE.Translation.Radar[8],
	model		= "models/radar/radar_sp_big.mdl",
	class		= "OMNI-AM",
	weight		= 1200,
	range		= 31496, -- range in inches.
	acepoints = 2000
} )
