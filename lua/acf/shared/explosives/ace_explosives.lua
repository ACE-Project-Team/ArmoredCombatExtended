-- Scalable command-detonated HE charge for the ACF menu. You pick a shape and
-- size; the filler is derived from the resulting physical volume using the same
-- HE maths as HE shells, so the blast performance matches an equivalent payload.
-- It cooks off if shot or destroyed.
--
-- Pre-built, model-based charges (satchel / aerial bomb / barrel) live in the
-- spawn (Q) menu under "ACE - Explosives" instead - those are fixed-size props.

ACE_DefineExplosive("ACE Explosive Charge", {
	name = "Explosive Charge",
	ent  = "ace_explosive",
	category = "Explosives",
	fillerFraction = 0.65,
	-- A charge can be a slab, a cylinder, a sphere etc - but not an aero wedge.
	AllowedShapes = { Box = true, Cylinder = true, Sphere = true, Prism = true },
	MenuDefault = { L = 12, W = 12, H = 12, Shape = "Box" },
	desc = "A scalable demolition charge. Choose a shape and size; its HE filler is read straight from the physical volume, so what you build is what it packs.\n\nHow to use:\n1. Pick a shape and dial in the size - bigger means more filler and a steeper score cost.\n2. Wire its Detonate input - any non-zero value sets it off. It also cooks off if shot or destroyed.\n\nUses the same HE maths as HE shells.\n\nInputs:\n- Detonate (Number): any non-zero value detonates\nOutputs:\n- Filler Mass (Number): kg of HE\n- Blast Radius (Number): metres",
})
