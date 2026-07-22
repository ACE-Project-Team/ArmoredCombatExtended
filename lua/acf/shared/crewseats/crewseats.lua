ACE_DefineCrewseat("Crewseat_Driver", {
	name = "Driver Seat",
	ent = "ace_crewseat_driver",
	desc = "A driver seat for your vehicle. Link to an engine to enable crew functionality.\n\nThe driver can be replaced by a nearby loader if killed.",
	model = "models/chairs_playerstart/sitpose.mdl",
	weight = 85,
	defaultModel = "Sitting",
})

ACE_DefineCrewseat("Crewseat_Gunner", {
	name = "Gunner Seat",
	ent = "ace_crewseat_gunner",
	desc = "A gunner seat for your vehicle. Link to a gun to enable crew functionality.\n\nHigh G-forces will reduce gunner effectiveness.\nThe gunner can be replaced by a nearby loader if killed.",
	model = "models/chairs_playerstart/sitpose.mdl",
	weight = 85,
	defaultModel = "Sitting",
})

ACE_DefineCrewseat("Crewseat_Loader", {
	name = "Loader Seat",
	ent = "ace_crewseat_loader",
	desc = "A loader seat for your vehicle. Link to a gun to enable crew functionality.\n\nThe loader has stamina that affects reload speed.\nHigh G-forces will reduce stamina regeneration.\nLoaders can replace dead drivers or gunners.",
	model = "models/chairs_playerstart/standingpose.mdl",
	weight = 85,
	defaultModel = "Standing",
})
