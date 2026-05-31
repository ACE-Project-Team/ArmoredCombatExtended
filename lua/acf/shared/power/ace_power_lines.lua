ACE_DefinePowerLine("ACE Power Line", {
	name = "Power Line",
	ent = "ace_power_line",
	category = "PowerLines",
	AllowedShapes = { Box = true, Cylinder = true },
	MenuDefault = { L = 6, W = 6, H = 72, Shape = "Cylinder" },
	desc = "A physical conductor - the optional 'make the wire real' layer. It carries power across the grid like a station-to-station link, but as a placed object you can run along a track for a tram catenary or third rail.\n\nHow to use (link tool):\n1. Link it to a grid node (Transfer Station, Transformer, or another Power Line). A conductor is drawn between them.\n2. Chain segments to span distance. A vehicle's Power Collector picks up from any LIVE line in range.\n\nIts cross-section (Width x Height) sets ampacity, so a thicker conductor carries more power and a thinner/longer run is more resistive (more loss per hop). Unlike a transformer it does NOT change voltage or convert - it just carries. Overload or battle damage can break it (it stops carrying, and a faulted live line arcs); torch-repair to restore.\n\nInputs:\n- Active (Number): 1 to enable\nOutputs:\n- Live (1 when carrying power) / Carrying (V) / Throughput (kW) / Capacity (kW) / Temperature (C)",
})
