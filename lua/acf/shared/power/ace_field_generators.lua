ACE_DefineFieldGenerator("ACE Field Generator", {
	name = "Oil Pump",
	ent = "ace_field_generator",
	category = "FieldGenerators",
	AllowedShapes = { Box = true },
	MenuDefault = { L = 30, W = 30, H = 40, Shape = "Box" },
	desc = "A scalable self-powered crude-oil pump (a \"thumper\" derrick).\n\nHow to use:\n1. Sit it ON THE GROUND - it only pumps while grounded.\n2. Link an Oil tank (or an empty Universal tank) with the link tool - it pumps crude OIL, which you then have to refine into petrol/diesel before an engine can use it.\n3. Wire its Active input (it starts OFF).\n\nThe start of the fuel chain: slow, runs hot and loud, no power needed. Bigger units pump faster but run hotter. Optionally spawn it as the HL2 thumper prop.\n\nInputs:\n- Active (Number): 1 to enable\n\nOutputs:\n- Fuel Rate (Number): litres/sec of oil produced\n- Heat (Number): temperature in C\n- Grounded (Number): 1 when resting on the ground",
})
