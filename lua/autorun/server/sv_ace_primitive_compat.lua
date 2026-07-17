-- Physics rebuild hooks can run before Primitive and Proper Clipping finish restoring properties.
-- Defer and coalesce recalculation until the final physics object is ready.
local collisionGroups = setmetatable({}, { __mode = "k" })

local function CopyArmorValues(acf)
	if not istable(acf) then return end
	if not isnumber(acf.Area) or acf.Area <= 0 then return end
	if not isnumber(acf.MaxArmour) or acf.MaxArmour <= 0 then return end
	if not isnumber(acf.MaxHealth) or acf.MaxHealth <= 0 then return end

	return {
		Area = acf.Area,
		Armour = acf.Armour,
		MaxArmour = acf.MaxArmour,
		Health = acf.Health,
		MaxHealth = acf.MaxHealth,
		Material = acf.Material,
		Ductility = acf.Ductility,
	}
end

local function CaptureSavedArmor(ent)
	if not IsValid(ent) or ent.ACE_PrimitiveSavedArmor then return end

	ent.ACE_PrimitiveSavedArmor = CopyArmorValues(ent.ACF)
end

local function RestoreSavedArmor(ent, phys)
	local saved = ent.ACE_PrimitiveSavedArmor
	if not saved or not istable(ent.ACF) then return false end

	local acf = ent.ACF
	acf.Area = saved.Area
	acf.Armour = saved.Armour
	acf.MaxArmour = saved.MaxArmour
	acf.Health = saved.Health
	acf.MaxHealth = saved.MaxHealth
	acf.Material = saved.Material
	acf.Ductility = saved.Ductility
	acf.PhysObj = phys
	acf.Mass = phys:GetMass()

	return true
end

local function RememberCollisionGroup(ent)
	if not IsValid(ent) then return end

	collisionGroups[ent] = ent:GetCollisionGroup()
end

local function CapturePendingPrimitiveArmor(ent)
	if not IsValid(ent) or not ent.ACE_PrimitiveRestoreSavedArmor then return end

	CaptureSavedArmor(ent)
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
		CapturePendingPrimitiveArmor(ent)
		local collisionGroup = collisionGroups[ent]
		if collisionGroup ~= nil and ent:GetCollisionGroup() ~= collisionGroup then
			ent:SetCollisionGroup(collisionGroup)
		end

		if not RestoreSavedArmor(ent, phys) then
			if ent.ACF then
				ent.ACF.Area = nil
				ent.ACF.PhysObj = nil
			end
			if ACF_Activate then ACF_Activate(ent, true) end
		end
		if ACE_ClearArmorPointCache then ACE_ClearArmorPointCache(ent) end

		local con = ent.CFW_GetContraption and ent:CFW_GetContraption()
		if ACE_MarkArmorDirty then ACE_MarkArmorDirty(con, ent) end
	end)
end

hook.Add("Primitive_PostRebuildPhysics", "ACE_PrimitiveArmorRecalc", QueueArmorRecalculation)
hook.Add("Primitive_PreRebuildPhysics", "ACE_RememberPrimitiveCollisionGroup", function(ent)
	RememberCollisionGroup(ent)
	CapturePendingPrimitiveArmor(ent)
end)
hook.Add("ProperClippingClipAdded", "ACE_RememberClipCollisionGroup", RememberCollisionGroup)
hook.Add("ProperClippingPhysicsClipped", "ACE_PhysicsClippedArmorRecalc", QueueArmorRecalculation)
hook.Add("ProperClippingPhysicsReset", "ACE_PhysicsResetArmorRecalc", QueueArmorRecalculation)

hook.Add("AdvDupe_FinishPasting", "ACE_CapturePrimitiveArmor", function(data)
	if not istable(data) or not istable(data[1]) then return end

	local paste = data[1]
	for sourceId, ent in pairs(paste.CreatedEntities or {}) do
		if IsValid(ent) and ent.IsPrimitive then
			ent.ACE_PrimitiveRestoreSavedArmor = true
			local source = paste.EntityList and paste.EntityList[sourceId]
			ent.ACE_PrimitiveSavedArmor = CopyArmorValues(source and source.ACF)
			if not ent.ACE_PrimitiveSavedArmor then CaptureSavedArmor(ent) end

			-- Primitive delays pasted reconstruction by one second; retain the source snapshot
			-- through that rebuild and any same-paste Proper Clipping physics replacement.
			local cleanupDeadline = CurTime() + 10
			local function ClearSavedArmor()
				if not IsValid(ent) then return end
				local primitive = ent.primitive
				if CurTime() < cleanupDeadline
					and (ent.ACE_PrimitiveArmorRecalcQueued
					or (istable(primitive) and (primitive.init or primitive.thread))) then
					timer.Simple(1, ClearSavedArmor)
					return
				end

				ent.ACE_PrimitiveRestoreSavedArmor = nil
				ent.ACE_PrimitiveSavedArmor = nil
			end

			timer.Simple(3, ClearSavedArmor)
		end
	end
end)
