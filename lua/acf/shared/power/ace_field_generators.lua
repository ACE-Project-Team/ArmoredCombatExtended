ACE_DefineFieldGenerator("ACE Field Generator", {
	name = "Oil Pump",
	ent = "ace_field_generator",
	category = "FieldGenerators",
	AllowedShapes = { Box = true },
	MenuDefault = { L = 30, W = 30, H = 40, Shape = "Box" },
	desc = "A crude-oil pump (a \"thumper\" derrick) - the start of the fuel chain.\n\nHow to use:\n1. Sit it ON THE GROUND - it only pumps while grounded.\n2. Give it power: link an Electric battery, or link it to the grid (a Transfer Station or power line). No power = no pumping.\n3. Link an Oil tank (or an empty Universal tank) to fill - it pumps crude OIL, which you then refine into petrol/diesel.\n4. Switch it on (starts OFF).\n\nIt pumps as fast as its power allows (full power = full rate). Bigger units pump faster but need more power and run hotter. Optionally use the thumper prop model.\n\nInputs: Active.\nOutputs: Fuel Rate (L/s), Heat (C), Grounded, Powered.",
})
