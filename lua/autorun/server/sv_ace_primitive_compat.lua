-- Reconcile Primitive armor from its lifecycle callbacks, not delayed timers.
local collisionGroups = setmetatable({}, { __mode = "k" })

local function IsFiniteNumber(value)
	return isnumber(value) and value == value and value > -math.huge and value < math.huge
end

local function CopyArmorValues(acf)
	if not istable(acf) then return end
	if not IsFiniteNumber(acf.Area) or acf.Area <= 0 then return end
	if not IsFiniteNumber(acf.Armour) or acf.Armour <= 0 then return end
	if not IsFiniteNumber(acf.MaxArmour) or acf.MaxArmour <= 0 then return end
	if not IsFiniteNumber(acf.Health) or acf.Health < 0 then return end
	if not IsFiniteNumber(acf.MaxHealth) or acf.MaxHealth <= 0 then return end
	if not IsFiniteNumber(acf.Ductility or 0) then return end

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
	local saved = CopyArmorValues(ent.ACE_PrimitiveSavedArmor)
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

local function HasPendingPhysicsClip(ent)
	if not ent.Clipped or not istable(ent.ClipData) then return false end

	for _, clip in pairs(ent.ClipData) do
		if istable(clip) and clip.physics then return true end
	end

	return false
end

local function ClearPrimitiveArmorState(ent)
	ent.ACE_PrimitiveArmorPending = nil
	ent.ACE_PrimitivePropertiesPending = nil
	ent.ACE_PrimitiveClippingHandled = nil
	ent.ACE_PrimitiveRestoreSavedArmor = nil
	ent.ACE_PrimitiveSavedArmor = nil
end

local function MarkPrimitiveArmorDirty(ent, reason)
	if ACE_ClearArmorPointCache then ACE_ClearArmorPointCache(ent) end

	local con = ent.CFW_GetContraption and ent:CFW_GetContraption()
	if ACE_MarkArmorDirty then ACE_MarkArmorDirty(con, ent, reason) end
end

local function ClearInvalidLiveArmorValues(acf)
	acf.Area = nil
	acf.PhysObj = nil

	if not IsFiniteNumber(acf.Ductility or 0) then
		acf.Ductility = nil
	end

	if not IsFiniteNumber(acf.Health) or acf.Health < 0
		or not IsFiniteNumber(acf.MaxHealth) or acf.MaxHealth <= 0 then
		acf.Health = nil
		acf.MaxHealth = nil
	end
end

local function ApplyPrimitiveArmor(ent, phys)
	CapturePendingPrimitiveArmor(ent)
	local collisionGroup = collisionGroups[ent]
	if collisionGroup ~= nil and ent:GetCollisionGroup() ~= collisionGroup then
		ent:SetCollisionGroup(collisionGroup)
	end

	if RestoreSavedArmor(ent, phys) then return true end

	if ent.ACF then
		ClearInvalidLiveArmorValues(ent.ACF)
	end

	return false
end

local function FinalizePrimitiveArmor(ent)
	if not IsValid(ent) or ent.ACE_PrimitiveFinalizing then return end

	ent.ACE_PrimitiveFinalizing = true

	local phys = ent:GetPhysicsObject()
	if not IsValid(phys) then
		ent.ACE_PrimitiveFinalizing = nil
		return
	end

	if not ApplyPrimitiveArmor(ent, phys) and ACE_Activate then
		ACE_Activate(ent, true)
	end

	MarkPrimitiveArmorDirty(ent, "primitive-physics-rebuilt")
	ClearPrimitiveArmorState(ent)
	ent.ACE_PrimitiveFinalizing = nil
end

local function ReconcilePrimitiveArmor(ent)
	if not IsValid(ent) then return end

	local phys = ent:GetPhysicsObject()
	if not IsValid(phys) then return end

	ApplyPrimitiveArmor(ent, phys)
	MarkPrimitiveArmorDirty(ent, "primitive-physics-rebuilt")
end

-- Primitive_PostRebuildPhysics fires before Primitive restores its serialized mass/material props.
-- The PhysObj:SetMass wrapper lets ACE finalize its mass-dependent armor state without a timer;
-- ACE restores the serialized material in the same finalization path.
function ACE_PrimitivePropertiesApplied(ent)
	if not IsValid(ent) or ent.ACE_PrimitiveFinalizing or not ent.ACE_PrimitivePropertiesPending then return end
	if HasPendingPhysicsClip(ent) and not ent.ACE_PrimitiveClippingHandled then return end

	FinalizePrimitiveArmor(ent)
end


hook.Add("Primitive_PreRebuildPhysics", "ACE_RememberPrimitiveCollisionGroup", function(ent)
	RememberCollisionGroup(ent)
	CapturePendingPrimitiveArmor(ent)
	ent.ACE_PrimitiveArmorPending = true
	ent.ACE_PrimitivePropertiesPending = nil
	ent.ACE_PrimitiveClippingHandled = nil
end)


hook.Add("Primitive_PostRebuildPhysics", "ACE_PrimitiveArmorRecalc", function(ent, props)
	if not IsValid(ent) then return end

	ent.ACE_PrimitiveArmorPending = true
	ent.ACE_PrimitivePropertiesPending = true
	ReconcilePrimitiveArmor(ent)

	-- Primitive's current source always supplies a numeric mass. This branch keeps the callback
	-- contract total if a future Primitive version omits it and there is no physics clip callback.
	if not isnumber(props and props.mass)
		and (ent.ACE_PrimitiveClippingHandled or not HasPendingPhysicsClip(ent)) then
		FinalizePrimitiveArmor(ent)
	end
end)

local function ReconcileProperClippingArmor(ent)
	if not IsValid(ent) then return end

	local wasPrimitiveRebuild = ent.ACE_PrimitivePropertiesPending or ent.ACE_PrimitiveRestoreSavedArmor
	ent.ACE_PrimitiveClippingHandled = true
	ent.ACE_PrimitiveArmorPending = true
	ReconcilePrimitiveArmor(ent)

	-- A pasted Primitive still has a later Primitive_PostRebuildPhysics callback to identify the
	-- final property write. Standalone clipping has already applied its own physics data here.
	if not wasPrimitiveRebuild then
		FinalizePrimitiveArmor(ent)
	end
end

hook.Add("ProperClippingClipAdded", "ACE_RememberClipCollisionGroup", RememberCollisionGroup)
hook.Add("ProperClippingPhysicsClipped", "ACE_PhysicsClippedArmorRecalc", ReconcileProperClippingArmor)
hook.Add("ProperClippingPhysicsReset", "ACE_PhysicsResetArmorRecalc", ReconcileProperClippingArmor)

hook.Add("AdvDupe_FinishPasting", "ACE_CapturePrimitiveArmor", function(data)
	if not istable(data) or not istable(data[1]) then return end

	local paste = data[1]
	for sourceId, ent in pairs(paste.CreatedEntities or {}) do
		if IsValid(ent) and ent.IsPrimitive then
			ent.ACE_PrimitiveRestoreSavedArmor = true
			local source = paste.EntityList and paste.EntityList[sourceId]
			ent.ACE_PrimitiveSavedArmor = CopyArmorValues(source and source.ACF)
			if not ent.ACE_PrimitiveSavedArmor then CaptureSavedArmor(ent) end
		end
	end
end)

hook.Add("EntityRemoved", "ACE_ClearPrimitiveArmorState", function(ent)
	collisionGroups[ent] = nil
	if ent.IsPrimitive then ClearPrimitiveArmorState(ent) end
end)
