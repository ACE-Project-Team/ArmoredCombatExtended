ACE_DefineCapacitor("ACE Capacitor", {
	name = "Capacitor",
	ent = "ace_capacitor",
	category = "Capacitors",
	AllowedShapes = { Box = true, Cylinder = true },
	MenuDefault = { L = 20, W = 20, H = 28, Shape = "Cylinder" },
	desc = "A fast grid buffer - tiny energy store, huge power. Place it on the grid near a spiky load: it discharges hard to cover sudden demand and refills slowly from the grid behind it, so the load sees smooth power and the upstream wires/stations only carry the average (peak-shaving). It tops itself up automatically.\n\nHow to use (link tool):\n1. Link it into the grid like a station/transformer (to a station, transformer, another capacitor, or a power line).\n2. That's it - it auto-charges from the grid and auto-supplies nearby loads.\n\nMore efficient than a battery and near-instant, but holds very little energy - it's for smoothing, not storage.\n\nInputs:\n- Active (Number)\nOutputs:\n- Charge (kWh) / Throughput (kW) / Temperature (C)",
})
