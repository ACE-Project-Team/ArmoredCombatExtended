ACF_DefineEntity("GForceMeter", {
	name = "G-Force Meter",
	ent = "ace_gforce_meter",
	category = "Misc",
	desc = "A sensor that measures the current G-force experienced by the contraption.\n\nUseful for monitoring vehicle dynamics and crew stress.\n\nUses CFW contraption tracking when available.\n\nOutputs:\n- GForce: Total G-force magnitude\n- GForceVec: G-force direction vector\n- GForceX/Y/Z: Individual axis values",
	model = "models/bull/various/gyroscope.mdl",
	weight = 2,
	acepoints = 20,
})