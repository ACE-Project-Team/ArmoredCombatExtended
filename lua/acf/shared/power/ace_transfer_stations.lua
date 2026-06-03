ACE_DefineTransferStation("ACE Transfer Station", {
	name = "Transfer Station",
	ent = "ace_transfer_station",
	category = "TransferStations",
	AllowedShapes = { Box = true },
	MenuDefault = { L = 30, W = 30, H = 30, Shape = "Box" },
	desc = "The heart of the electric grid: it puts a battery's power onto the grid, or pulls power back to charge a battery, and sets the line voltage.\n\nHow to use:\n1. Link an Electric battery.\n2. Link it to other grid parts (stations, transformers, power lines) to build the grid.\n3. Set its Mode by wire: 1 = feed the grid from the battery, 2 = charge the battery from the grid, 3 = relay to extend a long line. 0 = off.\n\nIts capacity (kW it can move) comes from its size. Voltage trades distance for heat: higher carries further but runs hotter. Overload it and it overheats and trips off until you torch-repair it.\n\nInputs: Mode (0-3), Voltage.\nOutputs: Mode, Voltage, Throughput, Energized, Temperature, Tripped.",
})
