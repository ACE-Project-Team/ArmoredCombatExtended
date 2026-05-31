ACE_DefineFuelSynth("ACE Fuel Synthesizer", {
	name = "Fuel Synthesizer",
	ent = "ace_fuel_synth",
	category = "FuelSynths",
	AllowedShapes = { Box = true, Cylinder = true },
	MenuDefault = { L = 30, W = 30, H = 30, Shape = "Box" },
	desc = "A scalable electric fuel synthesizer.\n\nHow to use:\n1. Link an Electric battery (the power source) with the link tool.\n2. Link a liquid fuel tank (the output).\n3. Switch it on - it draws electricity and turns it into liquid fuel, fast, for as long as the battery has charge.\n\nThis closes the loop: solar/alternator -> battery -> fuel -> engine. It runs hot while working.\n\nInputs:\n- Active (Number): 1 to enable\n\nOutputs:\n- Fuel Rate (Number): litres/sec produced\n- Elec Draw (Number): electrical draw in kW\n- Heat (Number): temperature in C",
})
