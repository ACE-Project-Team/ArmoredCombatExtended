ACE_DefineFuelPipe("ACE Fuel Pipe", {
	name = "Fuel Pipe",
	ent = "ace_fuel_pipe",
	category = "FuelPipes",
	AllowedShapes = { Box = true, Cylinder = true },
	MenuDefault = { L = 10, W = 10, H = 10, Shape = "Cylinder" },
	desc = "A pipeline segment. Lay several end-to-end to carry liquid fuel across the map - a real network you build, not a single magic link.\n\nHow to use (ACE link tool):\n1. Link a pipe to a SUPPLY tank (one with 'Refuel Duty' on - that's the giver) and chain pipe->pipe toward the destination.\n2. Link the last pipe to a RECEIVER tank (Refuel Duty off - it takes fuel). A Universal tank takes on whatever arrives.\n3. Each pipe spans a limited distance; chain more pipes, and splice in Fuel Pumps to push fuel further.\n\nBore matters: a fatter pipe carries more (L/s) and loses less to friction. Pipes wear slowly while flowing - throughput drops, they leak, then break (burnt look + gush). Repair with the ACE Torch.\n\nOutputs:\n- Flow Rate (Number): L/s through this pipe\n- Condition (Number): 0-1 pipe health",
})
