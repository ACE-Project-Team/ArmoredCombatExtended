ACE_DefineBurner("ACE Fuel Burner", {
	name = "Fuel Burner",
	ent = "ace_burner",
	category = "Burners",
	AllowedShapes = { Box = true, Cylinder = true },
	MenuDefault = { L = 16, W = 16, H = 24, Shape = "Cylinder" },
	desc = "A fuel burner / flare stack. Link it to a fuel tank and it burns that tank's liquid fuel at a fixed rate - a way to get rid of excess fuel (e.g. a product your synthesizer makes but you don't want).\n\nHow to use (link tool):\n1. Link a liquid fuel tank (it burns from this).\n2. Switch it on.\n\nIt does NOT manage the tank for you - it just burns at its rate, so it's up to you to feed it. It runs hot: the flame hurts players standing in it. Server owners can disable the fire particles with acf_burner_fx 0.\n\nModel: the Canister prop (fixed size; stats from its real volume) or a scalable Box/Cylinder.\n\nInputs:\n- Active (Number): 1 to enable\nOutputs:\n- Burning (Number): litres/sec burned\n- Lit (Number): 1 when burning",
})
