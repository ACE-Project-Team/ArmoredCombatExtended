ACE_DefinePowerLine("ACE Power Line", {
	name = "Power Line",
	ent = "ace_power_line",
	category = "PowerLines",
	AllowedShapes = { Box = true, Cylinder = true },
	MenuDefault = { L = 6, W = 6, H = 72, Shape = "Cylinder" },
	desc = "A real wire you can place and run along a track - a tram catenary or third rail.\n\nHow to use:\n1. Link it to a grid part (Transfer Station, Transformer, or another Power Line). A cable is drawn between them.\n2. Chain segments to cover distance (the Grid Tool lays and links them for you). A vehicle's Power Collector picks up from any live line nearby.\n\nIt's always a live conductor (no on/off) - it just carries power, it doesn't change voltage. A thicker wire carries more; a thinner or longer run loses more and runs hotter, so it carries the voltage of whatever feeds it (step up with a transformer for long runs). Massive overload or battle damage breaks it (torch-repair to restore); a broken live line arcs.\n\nOutputs: Live, Carrying (V), Throughput (kW), Capacity (kW), Temperature (C).",
})
