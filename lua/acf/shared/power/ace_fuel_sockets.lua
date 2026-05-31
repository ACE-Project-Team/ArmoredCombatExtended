ACE_DefineFuelSocket("ACE Fuel Socket", {
	name = "Fuel Socket",
	ent = "ace_fuel_socket",
	category = "FuelSockets",
	AllowedShapes = { Box = true },
	MenuDefault = { L = 10, W = 10, H = 10, Shape = "Box" },
	desc = "The receiver-side port of a physical refuelling link.\n\nHow to use:\n1. Mount it on the vehicle you want to refuel.\n2. Link it to that vehicle's fuel tank or battery (the receiver) with the link tool.\n3. When a linked Fuel Plug is pushed against it, it locks on and fuel/charge flows from the plug's supply into this tank - the way you fill a gas tank in real life.\n\nFuel types must match (or both be Electric). A small amount is lost in transfer.",
})
