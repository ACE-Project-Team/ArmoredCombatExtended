-- Physics rebuild hooks can run before Primitive and Proper Clipping finish restoring properties.
-- Defer and coalesce recalculation until the final physics object is ready.
local collisionGroups = setmetatable({}, { __mode = "k" })

local function RememberCollisionGroup(ent)
	if not IsValid(ent) or collisionGroups[ent] ~= nil then return end

	collisionGroups[ent] = ent:GetCollisionGroup()
end

local function QueueArmorRecalculation(ent)
	if not IsValid(ent) then return end
	if ent.ACE_PrimitiveArmorRecalcQueued then return end

	ent.ACE_PrimitiveArmorRecalcQueued = true
	timer.Simple(0, function()
		if not IsValid(ent) then return end

		ent.ACE_PrimitiveArmorRecalcQueued = nil
		local phys = ent:GetPhysicsObject()
		if not IsValid(phys) then return end
		local collisionGroup = collisionGroups[ent]
		if collisionGroup ~= nil and ent:GetCollisionGroup() ~= collisionGroup then
			ent:SetCollisionGroup(collisionGroup)
		end

		if ent.ACF then
			ent.ACF.Area = nil
			ent.ACF.PhysObj = nil
		end
		if ACF_Activate then ACF_Activate(ent, true) end
		if ACE_ClearArmorPointCache then ACE_ClearArmorPointCache(ent) end

		local con = ent.CFW_GetContraption and ent:CFW_GetContraption()
		if ACE_MarkArmorDirty then ACE_MarkArmorDirty(con, ent) end
	end)
end

hook.Add("Primitive_PostRebuildPhysics", "ACE_PrimitiveArmorRecalc", QueueArmorRecalculation)
hook.Add("Primitive_PreRebuildPhysics", "ACE_RememberPrimitiveCollisionGroup", RememberCollisionGroup)
hook.Add("ProperClippingClipAdded", "ACE_RememberClipCollisionGroup", RememberCollisionGroup)
hook.Add("ProperClippingPhysicsClipped", "ACE_PhysicsClippedArmorRecalc", QueueArmorRecalculation)
hook.Add("ProperClippingPhysicsReset", "ACE_PhysicsResetArmorRecalc", QueueArmorRecalculation)
