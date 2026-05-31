ACE_DefineTransferStation("ACE Transfer Station", {
	name = "Transfer Station",
	ent = "ace_transfer_station",
	category = "TransferStations",
	AllowedShapes = { Box = true },
	MenuDefault = { L = 30, W = 30, H = 30, Shape = "Box" },
	desc = "The node of the electric grid. It converts between a battery (DC) and the grid (AC) and sets the line voltage.\n\nHow to use (link tool):\n1. Link an Electric battery (the station's DC side).\n2. Link this station directly to another grid node (station, transformer, or power line) to form the grid. A line is drawn between them. Chain nodes to cross the map.\n3. Set each station's Mode by wire: 1 = Source (battery -> grid), 2 = Sink (grid -> battery), 3 = Relay (re-boosts the line to push further). Idle = 0.\n\nIts CAPACITY is set by its size (bigger box = more kW it can carry) - it is no longer a free voltage dial. Voltage now only trades line loss vs heat: higher voltage loses less over distance but runs hotter. A station links only so far (chain relays/wires for longer). Overload it and it overheats, sparks, and trips offline until torch-repaired.\n\nInputs:\n- Mode (Number): 0 idle, 1 source, 2 sink, 3 relay\n- Voltage (Number): 1-10\nOutputs:\n- Mode / Voltage / Throughput (kW) / Temperature (C)\n- Energized (1 when feeding the grid)\n- Tripped (1 when overheated offline)",
})
