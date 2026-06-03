ACE_DefineConsumer("ACE Power Consumer", {
	name = "Power Consumer",
	ent = "ace_power_consumer",
	category = "Consumers",
	AllowedShapes = { Box = true, Cylinder = true },
	MenuDefault = { L = 18, W = 18, H = 18, Shape = "Box" },
	desc = "A grid load - a house, building or machine that draws power. Its load scales with SIZE (bigger = more kW); wire 'Draw' to set an exact kW instead (0 = back to size-based).\n\nHow to use:\n1. Link it straight to any grid part (Transfer Station, Transformer, Power Line, Capacitor) or to an Electric battery. Order doesn't matter.\n2. Switch it on.\n\nIf the grid can't keep up it browns out (Powered = 0). Feed it above its rated voltage and it overheats and trips off until it cools - step the supply down with a transformer to keep it happy.\n\nModel: scalable box, or a real console prop.\n\nInputs: Active, Draw (kW).\nOutputs: Powered, Supplied (kW), Shortfall (kW), Voltage, Temperature.",
})
