ACE_DefineConsumer("ACE Power Consumer", {
	name = "Power Consumer",
	ent = "ace_power_consumer",
	category = "Consumers",
	AllowedShapes = { Box = true, Cylinder = true },
	MenuDefault = { L = 18, W = 18, H = 18, Shape = "Box" },
	desc = "A grid load - your 'house', building or machine. Its load scales with SIZE (a small box ~ a house, a large one ~ a small factory); wire 'Draw' to override with an exact kW.\n\nReal-world reference: a house ~2 kW average / ~10 kW peak, an office or shop ~50-200 kW, a small factory ~0.5-2 MW. The grid charges losses to the SOURCE, so the load gets the full kW it asks for (no efficiency haircut).\n\nHow to use (link tool):\n1. Link it to any grid node (Transfer Station, Transformer, Power Line, Capacitor) or directly to an Electric battery (local load). Link order does not matter.\n2. Optionally wire 'Draw' to a kW; set it to 0 to revert to the size-based load. Outputs 'Powered' (1 when fully supplied at sufficient voltage), 'Supplied', and delivered 'Voltage'.\n\nIf the grid can't keep up it browns out (Powered = 0). Optionally spawn it as a real console prop instead of a box.\n\nInputs:\n- Active (Number): 1 to enable\n- Draw (Number): desired load in kW (0 = use size-based load)\nOutputs:\n- Powered / Supplied (kW) / Shortfall (kW) / Voltage (V)",
})
