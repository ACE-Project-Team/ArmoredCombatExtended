ACE_DefineSolarPanel("ACE Solar Panel", {
	name = "Solar Panel",
	ent = "ace_solarpanel",
	category = "SolarPanels",
	AllowedShapes = { Box = true },
	MenuDefault = { L = 40, W = 40, H = 3, Shape = "Box" },
	LockH = true,   -- a panel is a flat slab; thickness is fixed, only Length x Width matter
	desc = "A scalable photovoltaic solar panel.\n\nGenerates electricity from sunlight and charges linked Electric batteries. Output depends on panel AREA (Length x Width - thickness is fixed since a panel is a flat slab), how directly it faces the sun, whether the sky above it is clear, and its temperature - a baking panel produces noticeably less. Mount it flat and unobstructed for best results.\n\nInputs:\n- Active (Number): 1 to enable\n- Sunlight Factor (Number): 0-1 multiplier on detected sun\n\nOutputs:\n- Output Power (Number): electrical output in kW\n- Efficiency (Number): 0-1 (after temperature derate)\n- Panel Area (Number): m^2\n- Sun Angle (Number): 0-1 cosine of incidence\n- Panel Temp / Heat (Number): temperature in C\n- Shadowed (Number): 1 when the sky is blocked",
})
