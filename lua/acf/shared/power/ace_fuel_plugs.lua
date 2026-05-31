ACE_DefineFuelPlug("ACE Fuel Plug", {
	name = "Fuel Plug",
	ent = "ace_fuel_plug",
	category = "FuelPlugs",
	AllowedShapes = { Box = true },
	MenuDefault = { L = 10, W = 8, H = 8, Shape = "Box" },
	desc = "The supply-side nozzle of a physical refuelling link.\n\nHow to use:\n1. Link it to a fuel tank or battery (the supply) with the link tool.\n2. Move it up against a Fuel Socket - like pushing a pump nozzle into a fuel port. It snaps and locks on.\n3. While connected, fuel (or charge) flows from the plug's tank into the socket's tank. Pull them apart to stop.\n\nFuel types must match (or both be Electric). A small amount is lost in transfer.",
})
