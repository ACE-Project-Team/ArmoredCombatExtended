-- The hook runs before Primitive restores physics properties, so restore the preserved mass
-- before recalculating ACF state. Per-entity cache invalidation also covers orphan primitives.
hook.Add("Primitive_PostRebuildPhysics", "ACE_PrimitiveArmorRecalc", function(ent, properties)
	if not IsValid(ent) or not ent.ACF then return end

	local phys = ent:GetPhysicsObject()
	if IsValid(phys) and istable(properties) and isnumber(properties.mass) then
		phys:SetMass(properties.mass)
	end

	ent.ACF.Area = nil
	ent.ACF.PhysObj = nil
	if ACF_Activate then ACF_Activate(ent, true) end
	if ACE_ClearArmorPointCache then ACE_ClearArmorPointCache(ent) end

	local con = ent.CFW_GetContraption and ent:CFW_GetContraption()
	if con and ACE_MarkArmorDirty then ACE_MarkArmorDirty(con, ent) end
end)
