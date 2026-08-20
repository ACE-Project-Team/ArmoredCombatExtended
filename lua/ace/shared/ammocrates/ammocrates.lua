
------------------------------
--Ammocrate Shells 75mm -> 170mm
------------------------------

ACE.DefineAmmoCrate( "Shell75mm", {

	name = "Modular Ammo Crate",
	desc = "A single 75mm Shell. As an alternative to the bulky ammocrates.\n",
	model = "models/munitions/round_75mm.mdl",
	weight = 5,
	Length = 3,
	Width = 3,
	Height = 31,

})

ACE.DefineAmmoCrate("Shell100mm", {
	name = "Modular Ammo Crate",
	desc = "A single 100mm Shell. As an alternative to the bulky ammocrates.\n",
	model = "models/munitions/round_100mm.mdl",
	weight = 10,
	Length = 4,
	Width = 4,
	Height = 36.7,
})

ACE.DefineAmmoCrate("Shell120mm", {
	name = "Modular Ammo Crate",
	desc = "A single 120mm Shell. As an alternative to the bulky ammocrates.\n",
	model = "models/munitions/round_120mm.mdl",
	weight = 15,
	Length = 4.73,
	Width = 4.73,
	Height = 44,
})

ACE.DefineAmmoCrate("Shell120mmAP", {
	name = "Modular Ammo Crate",
	desc = "A single 120mm AP Shell. As an alternative to the bulky ammocrates.\n",
	model = "models/munitions/round_120mm_ap.mdl",
	weight = 15,
	Length = 4.73,
	Width = 4.73,
	Height = 44,
})

ACE.DefineAmmoCrate("Shell140mm", {
	name = "Modular Ammo Crate",
	desc = "A single 140mm Shell. As an alternative to the bulky ammocrates.\n",
	model = "models/munitions/round_130mm.mdl",
	weight = 35,
	Length = 5.52,
	Width = 5.52,
	Height = 50,
})

ACE.DefineAmmoCrate("Shell170mm", {
	name = "Modular Ammo Crate",
	desc = "A single 170mm Shell. As an alternative to the bulky ammocrates.\n",
	model = "models/munitions/round_200mm.mdl",
	weight = 65,
	Length = 6.7,
	Width = 6.7,
	Height = 60.7,
})

--Cube
ACE.DefineModelData("Box",{

	Shape = "Box",
	Model = "models/holograms/rcube_thin.mdl", --Note: The model can be used as ID if needed.
	physMaterial = "metal",
	DefaultSize = 12,
	CustomMesh = { --Its a box anyways
		{
			Vector(6, 6, 6),
			Vector(6, -6, 6),
			Vector(-6, 6, 6),
			Vector(-6, -6, 6),
			Vector(6, 6, -6),
			Vector(6, -6, -6),
			Vector(-6, 6, -6),
			Vector(-6, -6, -6)
		},
	},
	volumefunction = function( L, W, H )
		local volume = L * W * H
		return volume
	end
})

--Triangle / Wedge
ACE.DefineModelData("Wedge",{

	Shape = "Wedge",
	Model = "models/holograms/right_prism.mdl",
	physMaterial = "metal",
	DefaultSize = 12,
	CustomMesh = { --Its a box anyways
		{
			Vector(-6, 6, 6),
			Vector(-6, -6, 6),
			Vector(6, 6, -6),
			Vector(6, -6, -6),
			Vector(-6, 6, -6),
			Vector(-6, -6, -6)
		},
	},
	volumefunction = function( L, W, H )
		local volume = (L * W * H) / 2
		return volume
	end
})

--Another type of wedge.
ACE_DefineModelData("Prism",{

	Shape = "Prism",
	Model = "models/holograms/prism.mdl",
	physMaterial = "metal",
	DefaultSize = 12,
	CustomMesh = { --Its a box anyways
		{
			Vector(0, 6, 6),
			Vector(0, -6, 6),
			Vector(6, 6, -6),
			Vector(6, -6, -6),
			Vector(-6, 6, -6),
			Vector(-6, -6, -6)
		},
	},
	volumefunction = function( L, W, H )
		local volume = (( L * H  ) / 2 ) * W
		return volume
	end
})

local PI = math.pi

--Cylinder
ACE.DefineModelData("Cylinder",{

	Shape = "Cylinder",
	Model = "models/holograms/hq_rcylinder_thin.mdl",
	physMaterial = "metal",
	DefaultSize = 12,
	CustomMesh = {
		{
			Vector(6, 0, -6),
			Vector(0, -6, -6),
			Vector(-6, 0, -6),
			Vector(0, 6, -6),

			Vector(4.24, -4.24, -6),
			Vector(-4.24, -4.24, -6),
			Vector(-4.24, 4.24, -6),
			Vector(4.24, 4.24, -6),

			Vector(6, 0, 6),
			Vector(0, -6, 6),
			Vector(-6, 0, 6),
			Vector(0, 6, 6),

			Vector(4.24, -4.24, 6),
			Vector(-4.24, -4.24, 6),
			Vector(-4.24, 4.24, 6),
			Vector(4.24, 4.24, 6),
		}
	},
	volumefunction = function( L, W, H )
		local volume = PI * (L / 2) * (W / 2) * H
		return volume
	end
})

-- The sphere. Dont ask how i got its vertex.
ACE_DefineModelData("Sphere",{

	Shape = "Sphere",
	Model = "models/holograms/hq_sphere.mdl", --Note: The model can be used as ID if needed.
	physMaterial = "metal",
	DefaultSize = 12,
	CustomMesh = { --Its a box anyways
		{
			Vector(4.242640, -4.242640, 0.000000),
			Vector(3.919689, -3.919689, 2.296101),
			Vector(6.000000, 0.000000, -0.000000),
			Vector(5.543278, 0.000000, 2.296100),
			Vector(5.543278, 0.000000, -2.296100),
			Vector(3.919689, -3.919689, -2.296101),
			Vector(0.000000, -6.000000, -0.000000),
			Vector(0.000000, -5.543278, 2.296100),
			Vector(-0.000000, -5.543278, -2.296100),
			Vector(3.000000, 3.000000, -4.242640),
			Vector(0.000000, 2.296101, -5.543277),
			Vector(1.623588, 1.623588, -5.543277),
			Vector(0.000000, 4.242641, -4.242640),
			Vector(0.000000, 0.000000, -6.000000),
			Vector(-1.623588, 1.623588, -5.543277),
			Vector(-3.000000, 3.000000, -4.242640),
			Vector(0.000000, 4.242641, 4.242640),
			Vector(-3.919689, 3.919689, 2.296101),
			Vector(0.000000, 5.543278, 2.296100),
			Vector(-0.000000, 6.000000, 0.000000),
			Vector(3.919689, 3.919689, 2.296101),
			Vector(4.242640, 4.242640, -0.000000),
			Vector(3.919689, 3.919689, -2.296101),
			Vector(0.000000, -2.296101, -5.543277),
			Vector(1.623588, -1.623588, -5.543277),
			Vector(2.296101, -0.000000, -5.543277),
			Vector(0.000000, -4.242641, -4.242640),
			Vector(3.000000, -3.000000, -4.242640),
			Vector(4.242641, 0.000000, -4.242640),
			Vector(-3.919689, -3.919689, -2.296101),
			Vector(-4.242641, 0.000000, 4.242640),
			Vector(-3.000000, 3.000000, 4.242640),
			Vector(-2.296101, 0.000000, 5.543277),
			Vector(-1.623588, -1.623588, 5.543277),
			Vector(0.000000, 0.000000, 6.000000),
			Vector(-1.623588, 1.623588, 5.543277),
			Vector(-3.000000, -3.000000, 4.242640),
			Vector(-0.000000, 5.543278, -2.296100),
			Vector(-3.919689, 3.919689, -2.296101),
			Vector(1.623588, -1.623588, 5.543277),
			Vector(3.000000, -3.000000, 4.242640),
			Vector(0.000000, -2.296101, 5.543277),
			Vector(0.000000, -4.242641, 4.242640),
			Vector(2.296101, -0.000000, 5.543277),
			Vector(4.242641, -0.000000, 4.242640),
			Vector(-3.919689, -3.919689, 2.296101),
			Vector(-4.242640, -4.242640, 0.000000),
			Vector(-5.543278, 0.000000, 2.296100),
			Vector(-2.296101, 0.000000, -5.543277),
			Vector(3.000000, 3.000000, 4.242640),
			Vector(-4.242641, -0.000000, -4.242640),
			Vector(-5.543278, 0.000000, -2.296100),
			Vector(-3.000000, -3.000000, -4.242640),
			Vector(-1.623588, -1.623588, -5.543277),
			Vector(0.000000, 2.296101, 5.543277),
			Vector(1.623588, 1.623588, 5.543277),
			Vector(-6.000000, 0.000000, -0.000000),
			Vector(-4.242640, 4.242640, 0.000000)
		},
	},
	volumefunction = function( L, W, H )
		local volume = ( 4 / 3 ) * PI * (L / 2) * (W / 2) * (H / 2)
		return volume
	end
})

--Cone
ACE.DefineModelData("Cone",{

	Shape = "Cone",
	Model = "models/holograms/hq_cone.mdl",
	physMaterial = "metal",
	DefaultSize = 12,
	CustomMesh = {
		{
			Vector(6, 0, -6),
			Vector(0, -6, -6),
			Vector(-6, 0, -6),
			Vector(0, 6, -6),

			Vector(4.24, -4.24, -6),
			Vector(-4.24, -4.24, -6),
			Vector(-4.24, 4.24, -6),
			Vector(4.24, 4.24, -6),

			Vector(0, 0, 6),
		}
	},
	volumefunction = function( L, W, H )
		local volume = (1 / 3) * PI * (L / 2) * (W / 2) * H
		return volume
	end
})
