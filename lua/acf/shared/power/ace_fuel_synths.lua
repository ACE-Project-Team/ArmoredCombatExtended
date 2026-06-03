ACE_DefineFuelSynth("ACE Fuel Synthesizer", {
	name = "Fuel Synthesizer",
	ent = "ace_fuel_synth",
	category = "FuelSynths",
	AllowedShapes = { Box = true, Cylinder = true },
	MenuDefault = { L = 30, W = 30, H = 30, Shape = "Box" },
	desc = "A powered plant that makes petrol and diesel at the same time.\n\nHow to use:\n1. Give it power: link an Electric battery, or link it to the grid (a Transfer Station or power line).\n2. Give each fuel somewhere to go: link a Petrol tank AND a Diesel tank (a Universal tank takes either). A fuel with no tank backs up inside, slows the plant, and if ignored the reactor explodes.\n3. Switch it on.\n\nReactor Temp sets the mix: hotter = more petrol, cooler = more diesel, middle = even.\n\nIf you feed it above its rated voltage the electronics overheat and shut it off - step the supply down with a transformer.\n\nModel: scalable Box/Cylinder, or the Cooling Tank prop.\n\nInputs: Active, Reactor Temp.\nOutputs: fuel rates (L/s), draw (kW), pressure, temperature.",
})
