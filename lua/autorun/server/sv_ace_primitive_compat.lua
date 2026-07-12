-- Primitive-addon entities rebuild their physics object after spawn/paste; ACF caches
-- ent.ACF.Area once and never recomputes it, so armor evaluated against the pre-rebuild
-- placeholder stays wrong forever (armor is inversely proportional to cached area).
-- Recompute ACF state from the real mesh whenever a primitive finishes rebuilding.
hook.Add("Primitive_PostRebuildPhysics", "ACE_PrimitiveArmorRecalc", function(ent)
	if not IsValid(ent) or not ent.ACF then return end

	ent.ACF.Area = nil
	ent.ACF.PhysObj = nil
	if ACF_Activate then ACF_Activate(ent, true) end

	local con = ent.CFW_GetContraption and ent:CFW_GetContraption()
	if con and ACE_MarkArmorDirty then ACE_MarkArmorDirty(con, ent) end
end)
