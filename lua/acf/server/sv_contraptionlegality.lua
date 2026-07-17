ACE = ACE or {}

include("acf/shared/sh_ace_functions.lua")
include("acf/server/sv_pointshandling.lua")


local IsEnt = ACE.IsEnt
ACE.CacheVersion = ACE.CacheVersion or 1
ACE.PointsEventId = ACE.PointsEventId or 0
ACE.PointContraptions = ACE.PointContraptions or {}
local POINTS_STATE_VERSION = 2
ACE.PointsStateVersion = POINTS_STATE_VERSION

-- CFW's mass extension assumes its aggregate was initialized before a physics rebuild or
-- membership transition reaches SetMass/entityAdded/entityRemoved. Reconstruct a missing
-- aggregate from CFW's own per-entity mass ledger at the ACE lifecycle boundary.
local function ACE_GetCFWEntityMass(ent, initializeLedger)
	local mass = ent._mass
	if mass == nil and ent.GetPhysicsObject then
		local phys = ent:GetPhysicsObject()
		mass = IsValid(phys) and phys:GetMass() or 0
		if initializeLedger then ent._mass = mass end
	end

	return mass or 0
end

local function ACE_EnsureCFWMassTotal(class, members, include, exclude, excludeMass)
	if not class or class.totalMass ~= nil then return end

	local total = 0
	for key, value in pairs(members or {}) do
		local member = value == true and key or value
		if IsValid(member) and member ~= exclude then
			total = total + ACE_GetCFWEntityMass(member, true)
		end
	end

	-- SetMass can be nested inside CFW's wrapper after CFW has already written the new
	-- entity ledger value. Reinsert the pre-change physical mass so CFW's delta applies once.
	if IsValid(exclude) and members and members[exclude] and isnumber(excludeMass) then
		total = total + excludeMass
	end

	-- entityAdded fires after the entity is inserted; entityRemoved fires after it
	-- is removed. Include/exclude the transition entity so a late aggregate
	-- recovery does not double-count either hook's pending mass update.
	if IsValid(include) and (not members or not members[include]) then
		total = total + ACE_GetCFWEntityMass(include, true)
	end

	class.totalMass = total
end

local function ACE_EnsureCFWMassState(ent, currentMass)
	local con = ent.CFW_GetContraption and ent:CFW_GetContraption()
	ACE_EnsureCFWMassTotal(con, con and con.ents, nil, ent, currentMass)

	local family = ent.GetFamily and ent:GetFamily()
	ACE_EnsureCFWMassTotal(family, family and family.ents, nil, ent, currentMass)
end

-- ------------------------------------------------------------
-- Legal check throttle (prevents chat spam)
-- ------------------------------------------------------------

-- Run a legality scan for a contraption.
function ACE.DoContraptionLegalCheck(checkEnt)
	checkEnt.CanLegalCheck = checkEnt.CanLegalCheck or false
	if not checkEnt.CanLegalCheck then return end

	checkEnt.CanLegalCheck = false
	timer.Simple(3, function()
		if IsEnt(checkEnt) then checkEnt.CanLegalCheck = true end
	end)

	local con = checkEnt:CFW_GetContraption() or {}
	if table.IsEmpty(con) then return end

	ACE.CheckLegalCont(con)
end

-- ------------------------------------------------------------
-- Player warnings (over points, overweight, and dirty armor)
-- ------------------------------------------------------------

-- Evaluate legality for a contraption.
function ACE.CheckLegalCont(con)
	con.OTWarnings = con.OTWarnings or {}

	if ACE.EnsureContraptionPoints then
		ACE.EnsureContraptionPoints(con, nil, false)
	end

	local points = con.ACEPoints or 0
	local pointsLimit = ACF.PointsLimit or math.huge
	if points > pointsLimit and not con.OTWarnings.WarnedOverPoints then
		local name  = ACE.GetOwnerName(ACE.GetContraptionOwner(con))
		local above = points - pointsLimit
		chatMessageGlobal(
			"[ACE] " .. name .. " has a vehicle [" .. math.ceil(above) .. "pts] over the limit costing [" ..
				math.ceil(points) .. "pts / " .. math.ceil(pointsLimit) .. "pts]",
			Color(255, 234, 0)
		)
		con.OTWarnings.WarnedOverPoints = true
	end

	local maxWeight = ACF.MaxWeight or math.huge
	if (con.totalMass or 0) > maxWeight and not con.OTWarnings.WarnedOverWeight then
		local name  = ACE.GetOwnerName(ACE.GetContraptionOwner(con))
		local above = con.totalMass - maxWeight
		chatMessageGlobal(
			"[ACE] " .. name .. " has a vehicle [" .. math.ceil(above) .. "kg] over the limit, weighing [" ..
				math.ceil(con.totalMass) .. "kg / " .. math.ceil(maxWeight) .. "kg]",
			Color(255, 234, 0)
		)
		con.OTWarnings.WarnedOverWeight = true
	end

	con.ACEWarningsDirty = false
	con.ACEWarningsGeneration = con.ACEWarningGeneration or con.ACEWarningsGeneration or 0
end

-- ------------------------------------------------------------
-- Contraption init and point bookkeeping hooks
-- ------------------------------------------------------------

do
	-- Sync per-contraption cache version and invalidate stale local caches.
	function ACE.EnsureCacheVersion(con)
		if not con then return false end

		if con.ACECacheVersion == ACE.CacheVersion then return false end

		con.ACECacheVersion = ACE.CacheVersion
		ACE.MarkContraptionPointsDirty(con, nil, true, true, "cache-version-changed")

		return true
	end

	local function ACE_IsContraption(value)
		return value and type(value) == "table" and value.valid == nil
	end

	local function ACE_AddAffectedContraption(affected, seen, con)
		if not ACE_IsContraption(con) or seen[con] then return end

		seen[con] = true
		affected[#affected + 1] = con
	end

	-- CFW split/merge emits entity membership hooks for the intermediate state and
	-- then emits one structural hook. Hold those intermediate transitions so the
	-- structural hook remains the sole invalidation event for that operation.
	local ACE_PendingContraptionTransitions = {}
	local ACE_PendingRemovalGenerations = {}
	local PENDING_TRANSITION = 1
	local PENDING_REMOVAL_NOTIFIED = 2

	local function ACE_ClearContraptionTransition(con)
		ACE_PendingContraptionTransitions[con] = nil
		ACE_PendingRemovalGenerations[con] = nil
	end

	local function ACE_DeferContraptionTransition(con)
		if not ACE_IsContraption(con) then return end
		if ACE_PendingContraptionTransitions[con] == PENDING_REMOVAL_NOTIFIED then
			if ACE_PendingRemovalGenerations[con] == con.ACEPointsGeneration then return end
			ACE_ClearContraptionTransition(con)
		end
		ACE_PendingContraptionTransitions[con] = PENDING_TRANSITION
	end

	local function ACE_MarkContraptionRemovalNotified(con)
		if ACE_IsContraption(con) and not ACE_PendingContraptionTransitions[con] then
			ACE_PendingContraptionTransitions[con] = PENDING_REMOVAL_NOTIFIED
			ACE_PendingRemovalGenerations[con] = con.ACEPointsGeneration
		end
	end

	local function ACE_GetPointContraption(ent)
		if ACE_IsContraption(ent) then return ent end
		if not ent then return end

		local con
		if ACE.GetContraptionFromEntity and IsEnt(ent) then
			con = ACE.GetContraptionFromEntity(ent)
		end
		if not con and ent.CFW_GetContraption and IsEnt(ent) then
			con = ent:CFW_GetContraption()
		end

		if not con and IsEnt(ent) and ACE.GetWeaponAnchorContraption then
			con = ACE.GetWeaponAnchorContraption(ent)
		end
		if not con then con = ent._ACEPointsConRef or ent._ACEPointsOwnerConRef end

		return con
	end

	local function ACE_NormalizePointCategories(categories, armorDirty, nonArmorDirty)
		if type(categories) == "table" then
			return {
				Armor = categories.Armor and true or false,
				Ammo = categories.Ammo and true or false,
				Firepower = categories.Firepower and true or false,
				ReadyRack = categories.ReadyRack and true or false,
				Warning = categories.Warning ~= false,
			}
		end

		local nonArmor = nonArmorDirty ~= false
		return {
			Armor = armorDirty ~= false,
			Ammo = nonArmor,
			Firepower = nonArmor,
			ReadyRack = nonArmor,
			Warning = true,
		}
	end

	local function ACE_ApplyPointInvalidation(con, ent, reason, categories, event)
		if not con then return end

		local generation = (con.ACEPointsGeneration or con.ACEPointsRevision or 0) + 1
		con.ACEPointsGeneration = generation
		con.ACECacheGeneration = generation

		if categories.Armor then
			con.ACEPointsDirty = true
			con.ACEArmorDirty = true
			con.ACEArmorCalculated = false
			con.ACEArmorGeneration = generation
		end

		if categories.Ammo then
			con.ACEAmmoGeneration = generation
		end

		if categories.Firepower then
			con.ACEFirepowerGeneration = generation
		end

		if categories.ReadyRack then
			con.ACEReadyRackGeneration = generation
		end

		if categories.Warning then
			con.ACEWarningGeneration = generation
			con.ACEWarningsDirty = true
		end

		local nonArmorDirty = categories.Ammo or categories.Firepower or categories.ReadyRack
		if nonArmorDirty then
			con.ACEPointsDirty = true
			con.ACENonArmorDirty = true
		end

		if categories.Armor and ACE.ClearArmorPointCache and IsEnt(ent) then
			ACE.ClearArmorPointCache(ent)
		end

	end

	-- The only entry point for point-input mutations. A single call may name both
	-- endpoints of a link or several linked weapons. Contraptions are deduplicated
	-- before their generations advance, so one logical mutation produces one rebuild
	-- revision per affected contraption, including cross-contraption link anchors.
	function ACE.NotifyPointsInvalidated(sources, reason, categories, explicitContraptions)
		local sourceList
		if type(sources) == "table" and next(sources) == nil then
			sourceList = {}
		elseif type(sources) == "table" and sources[1] ~= nil then
			sourceList = sources
		else
			sourceList = { sources }
		end
		local affected = {}
		local seen = {}

		for _, source in ipairs(sourceList) do
			ACE_AddAffectedContraption(affected, seen, ACE_GetPointContraption(source))
		end

		for _, con in ipairs(explicitContraptions or {}) do
			ACE_AddAffectedContraption(affected, seen, con)
		end

		if #affected == 0 then return end

		ACE.PointsEventId = ACE.PointsEventId + 1
		local event = {
			EventId = ACE.PointsEventId,
			Reason = reason or "entity-updated",
			Entity = sourceList[1],
			Categories = ACE_NormalizePointCategories(categories),
			AffectedContraptions = affected,
			CacheGenerations = {},
		}

		for _, con in ipairs(affected) do
			ACE_ApplyPointInvalidation(con, event.Entity, event.Reason, event.Categories, event)
			event.CacheGenerations[con] = {
				Points = con.ACEPointsGeneration or 0,
				Cache = con.ACECacheGeneration or 0,
				Armor = con.ACEArmorGeneration or 0,
				Ammo = con.ACEAmmoGeneration or 0,
				Firepower = con.ACEFirepowerGeneration or 0,
				ReadyRack = con.ACEReadyRackGeneration or 0,
				Warning = con.ACEWarningGeneration or 0,
			}
		end

		-- Compatibility listeners receive the complete event, including every
		-- affected contraption's post-invalidation cache generation.
		if ACE.NotifyContraptionPointsInvalidated then
			for _, con in ipairs(affected) do
				local nonArmorDirty = event.Categories.Ammo or event.Categories.Firepower or event.Categories.ReadyRack
				ACE.NotifyContraptionPointsInvalidated(
					con,
					event.Entity,
					event.Reason,
					event.Categories.Armor,
					nonArmorDirty,
					event
				)
			end
		end

		if hook and hook.Run then hook.Run("ACE_OnContraptionsPointsInvalidated", event) end

		-- Warning state is a derived consumer of the same event. Rebuild once per
		-- affected contraption while the event's generations are still in scope.
		if ACE.CheckLegalCont then
			for _, con in ipairs(affected) do
				if con.ents and not con.ACERemoving and not con._ACEPointsEnsuring then
					if (con.ACEPointsDirty or con.ACEArmorDirty or con.ACENonArmorDirty)
						and ACE.EnsureContraptionPoints then
						ACE.EnsureContraptionPoints(con, nil, false)
					end

					if con.ACEWarningsDirty and not con._ACEWarningChecking then
						con._ACEWarningChecking = true
						ACE.CheckLegalCont(con)
						con._ACEWarningChecking = nil
					end
				end
			end
		end

		return event
	end

	_G.ACE.NotifyPointsInvalidated = ACE.NotifyPointsInvalidated

	-- Initialize per-contraption points state.
	function ACE.EnsurePointsState(con)
		if not con then return false end
		if con.ACEInitDone and con.ACEPointsStateVersion == POINTS_STATE_VERSION then return false end

		con.ACEInitDone = true
		con.ACEPointsStateVersion = POINTS_STATE_VERSION
		ACE_EnsureCFWMassTotal(con, con.ents)

		con.ACECacheVersion = ACE.CacheVersion
		con.ACEPoints = 0
		con.ACEPointsNonArmor = 0

		con.ACEArmorPoints = 0
		con.ACEPointsDirty = true
		con.ACEArmorDirty = false
		con.ACEArmorCalculated = false

		con.ACENonArmorDirty = true

		con.ACEPointsPerType = {}
		for _, k in ipairs({
			"Armor",
			"Engines",
			"Firepower",
			"Crew",
			"Electronics"
		}) do
			con.ACEPointsPerType[k] = 0
		end

		con.ACEPointsRevision = 0
		con.ACEPointsGeneration = 0
		con.ACECacheGeneration = ACE.CacheVersion
		con.ACEArmorGeneration = 0
		con.ACEAmmoGeneration = 0
		con.ACEFirepowerGeneration = 0
		con.ACEReadyRackGeneration = 0
		con.ACEWarningGeneration = 0
		con.ACEWarningsDirty = true
		ACE.PointContraptions[con] = true

		return true
	end

	local function ACE_WrapCFWDefuse()
		if not CFW or not CFW.Classes or not CFW.Classes.Contraption then return end
		local class = CFW.Classes.Contraption
		if not class.Defuse or (ACE._ACEWrappedDefuse and ACE._ACEWrappedDefuseClass == class) then return end

		local oldDefuse = class.Defuse
		class.Defuse = function(self, ...)
			self._ACEPointsDefusing = true
			local result = { pcall(oldDefuse, self, ...) }
			self._ACEPointsDefusing = nil
			if not result[1] then error(result[2], 0) end
			return unpack(result, 2)
		end
		ACE._ACEWrappedDefuse = true
		ACE._ACEWrappedDefuseClass = class
	end

	local function ACE_InitPts(con)
		ACE_WrapCFWDefuse()
		return ACE.EnsurePointsState(con)
	end

	-- Compatibility wrapper for callers that already resolved a contraption.
	function ACE.MarkContraptionPointsDirty(con, ent, armorDirty, nonArmorDirty, reason)
		if not con then return end

		if armorDirty == nil then armorDirty = true end
		if nonArmorDirty == nil then nonArmorDirty = true end

		ACE.NotifyPointsInvalidated(ent or con, reason, {
			Armor = armorDirty,
			Ammo = nonArmorDirty,
			Firepower = nonArmorDirty,
			ReadyRack = nonArmorDirty,
			Warning = true,
		}, { con })
	end

	-- Orphan weapons invalidate the link-anchor contraption that owns their cost.
	function ACE.PointsInputChanged(sources, reason, categories, explicitContraptions)
		local sourceList
		if type(sources) == "table" and next(sources) == nil then
			sourceList = {}
		elseif type(sources) == "table" and sources[1] ~= nil then
			sourceList = sources
		else
			sourceList = { sources }
		end
		local explicit = {}
		local primaryCurrent
		local primaryPrevious
		if ACE_IsContraption(sourceList[1]) then primaryCurrent = sourceList[1] end

		for index, ent in ipairs(sourceList) do
			if IsEnt(ent) then
				local previous = ent._ACEPointsOwnerConRef
				local current = ACE_GetPointContraption(ent)
				if index == 1 then
					primaryCurrent = current
					primaryPrevious = previous
				end
				ent._ACEPointsOwnerConRef = current

				if previous and previous ~= current then explicit[#explicit + 1] = previous end
			end
		end
		for _, con in ipairs(explicitContraptions or {}) do explicit[#explicit + 1] = con end

		if not categories then
			local structural = reason and (
				string.find(reason, "removed", 1, true)
				or string.find(reason, "freeze", 1, true)
				or string.find(reason, "pasted", 1, true)
			)
			categories = {
				Armor = structural and true or false,
				Ammo = true,
				Firepower = true,
				ReadyRack = true,
				Warning = true,
			}
		end

		local event = ACE.NotifyPointsInvalidated(sourceList, reason, categories, explicit)
		if event and reason and string.find(reason, "removed", 1, true) then
			local ent = sourceList[1]
			if IsEnt(ent) then ent._ACEPointsRemovalNotified = true end
			ACE_MarkContraptionRemovalNotified(primaryCurrent or primaryPrevious)
		end
		return event
	end

	-- Initialize point tracking when a contraption is created.
	hook.Add("cfw.contraption.created", "ACE_InitPoints", ACE_InitPts)
	hook.Add("cfw.family.created", "ACE_InitFamilyMass", function(family)
		ACE_EnsureCFWMassTotal(family, family.ents)
	end)
	hook.Add("cfw.family.added", "ACE_RecoverFamilyMassOnAdd", function(family, ent)
		ACE_EnsureCFWMassTotal(family, family.ents, ent)
	end)
	hook.Add("cfw.family.subbed", "ACE_RecoverFamilyMassOnRemove", function(family, ent)
		ACE_EnsureCFWMassTotal(family, family.ents, ent)
	end)

	-- Damage can split a warned vehicle into a fresh CFW contraption. Preserve the one-time
	-- point warning across that split so debris and detached sections cannot repeat it.
	local function ACE_InheritPointWarning(parent, child)
		if not parent or not child then return end
		if not parent.OTWarnings or not parent.OTWarnings.WarnedOverPoints then return end

		child.OTWarnings = child.OTWarnings or {}
		child.OTWarnings.WarnedOverPoints = true
	end

	hook.Add("cfw.contraption.split", "ACE_InheritPointWarning", function(parent, child)
		local parentAlreadyNotified = ACE_PendingContraptionTransitions[parent] == PENDING_REMOVAL_NOTIFIED
			and ACE_PendingRemovalGenerations[parent] == parent.ACEPointsGeneration
		ACE_ClearContraptionTransition(parent)
		ACE_ClearContraptionTransition(child)
		ACE_InheritPointWarning(parent, child)
		ACE.PointContraptions[parent] = true
		ACE.PointContraptions[child] = true
		if parentAlreadyNotified then
			ACE.NotifyPointsInvalidated(child, "contraption-split")
		else
			ACE.NotifyPointsInvalidated({ parent, child }, "contraption-split")
		end
	end)

	hook.Add("cfw.contraption.merged", "ACE_InvalidateMergedContraptions", function(merged, target)
		ACE_ClearContraptionTransition(merged)
		ACE_ClearContraptionTransition(target)
		merged.ACERemoving = true
		if merged.OTWarnings then merged.OTWarnings.WarnedModified = true end
		ACE.PointContraptions[merged] = nil
		if target then ACE.PointContraptions[target] = true end
		ACE.NotifyPointsInvalidated({ merged, target }, "contraption-merged")
	end)

	-- Flag contraptions that are being removed to suppress dirty warnings.
	hook.Add("cfw.contraption.removed", "ACE_ContraptionRemoving", function(con)
		if not con then return end
		local pending = ACE_PendingContraptionTransitions[con]
		if pending == PENDING_TRANSITION and next(con.ents or {}) then
			-- CFW's Defuse can finish with a direct Remove after mutating its
			-- entity set. That is final removal, not a split precursor.
			ACE_ClearContraptionTransition(con)
			pending = nil
		end
		if pending == PENDING_TRANSITION then
			ACE_ClearContraptionTransition(con)
			if not con._ACEPointsDefusing then
				ACE.PointContraptions[con] = nil
				return
			end
			pending = nil
		end
		if pending == PENDING_REMOVAL_NOTIFIED
			and ACE_PendingRemovalGenerations[con] ~= con.ACEPointsGeneration then
			ACE_ClearContraptionTransition(con)
			pending = nil
		end
		if pending == PENDING_REMOVAL_NOTIFIED and next(con.ents or {}) then
			ACE_ClearContraptionTransition(con)
			pending = nil
		end
		con.ACERemoving = true
		if con.OTWarnings then con.OTWarnings.WarnedModified = true end
		if pending ~= PENDING_REMOVAL_NOTIFIED then
			ACE.NotifyPointsInvalidated(con, "contraption-removed")
		end
		ACE_ClearContraptionTransition(con)
		ACE.PointContraptions[con] = nil
	end)

	-- Refresh orphan-weapon ownership after a linked crate changes contraptions.
	function ACE.NotifyCrateWeapons(ent, reason)
		if not ent or not ent.GetClass or ent:GetClass() ~= "acf_ammo" then return end
		if type(ent.Master) ~= "table" then return end

		local sources = { ent }
		for _, weapon in pairs(ent.Master or {}) do
			if IsEnt(weapon) then sources[#sources + 1] = weapon end
		end

		ACE.PointsInputChanged(sources, reason or "linked-crate-moved")
	end

	-- Handle entity addition and update point totals.
	function ACE.AddPts(con, ent)
		if not IsEnt(ent) then return end
		ACE_EnsureCFWMassTotal(con, con.ents, nil, ent)
		ACE.PointContraptions[con] = true

		local previous = ent._ACEPointsConRef
		local previousOwner = ent._ACEPointsOwnerConRef

		local movedContraptions = {}
		if previous and previous ~= con then movedContraptions[#movedContraptions + 1] = previous end
		if previousOwner and previousOwner ~= con and previousOwner ~= previous then
			movedContraptions[#movedContraptions + 1] = previousOwner
		end

		if previous and previous ~= con then
			ACE_DeferContraptionTransition(previous)
			ACE_DeferContraptionTransition(con)
			ent._ACEPointsConRef = con
			ent._ACEPointsOwnerConRef = con
			return
		end

		ent._ACEPointsConRef = con
		ent._ACEPointsOwnerConRef = con
		local sources = { ent, con }
		if ent:GetClass() == "acf_ammo" then
			for _, weapon in pairs(ent.Master or {}) do
				if IsEnt(weapon) then sources[#sources + 1] = weapon end
			end
		end

		ACE.PointsInputChanged(sources, "entity-added", {
			Armor = true,
			Ammo = true,
			Firepower = true,
			ReadyRack = true,
			Warning = true,
		}, movedContraptions)
	end

	-- Handle entity removal and update point totals.
	function ACE.RemPts(con, ent)
		if not con then return end
		ACE_EnsureCFWMassTotal(con, con.ents, ent)
		ACE.PointContraptions[con] = true

		if ent and ent._ACEPointsRemovalNotified then
			ent._ACEPointsRemovalNotified = nil
			if ent._ACEPointsConRef == con then ent._ACEPointsConRef = nil end
			if ent._ACEPointsOwnerConRef == con then ent._ACEPointsOwnerConRef = nil end
			return
		end

		local valid = IsEnt(ent)
		local previous = valid and ent._ACEPointsOwnerConRef
		local beingRemoved = valid and (
			(ent.IsMarkedForDeletion and ent:IsMarkedForDeletion())
			or (ent.IsBeingRemoved and ent:IsBeingRemoved())
		)

		if valid and not beingRemoved and ent._ACEPointsConRef == con and next(con.ents or {}) then
			ACE_DeferContraptionTransition(con)
			ACE_DeferContraptionTransition(previous)
			return
		end

		if valid and ent._ACEPointsConRef == con then ent._ACEPointsConRef = nil end
		if valid and previous == con then ent._ACEPointsOwnerConRef = nil end

		local movedContraptions = {}
		if previous and previous ~= con then movedContraptions[#movedContraptions + 1] = previous end

		local sources = { ent, con }
		if ent and ent.GetClass and ent:GetClass() == "acf_ammo" then
			for _, weapon in pairs(ent.Master or {}) do
				if IsEnt(weapon) then sources[#sources + 1] = weapon end
			end
		end

		ACE.PointsInputChanged(sources, "entity-removed", {
			Armor = true,
			Ammo = true,
			Firepower = true,
			ReadyRack = true,
			Warning = true,
		}, movedContraptions)
		if ent and ent._ACEPointsRemovalNotified then ent._ACEPointsRemovalNotified = nil end
	end

	-- Track point totals when entities are added.
	hook.Add("cfw.contraption.entityAdded", "ACE_AddPoints", ACE.AddPts)

	-- Track point totals when entities are removed.
	hook.Add("cfw.contraption.entityRemoved", "ACE_RemPoints", ACE.RemPts)
end

-- ------------------------------------------------------------
-- Hook PhysObj:SetMass so mass edits rebuild points on demand.
-- ------------------------------------------------------------

do
	local PHYS = FindMetaTable("PhysObj")

	ACE._OldPhysSetMass = ACE._OldPhysSetMass or PHYS.SetMass
	local OldSetMass = ACE._OldPhysSetMass

	-- Override PhysObj:SetMass to mark armor dirty when needed.
	function PHYS:SetMass(mass)
		local ent = self:GetEntity()
		local currentMass = self:GetMass()
		if IsEnt(ent) then
			-- Initialize the ledger before an inner CFW wrapper calculates its delta. An outer
			-- CFW wrapper has already captured its old ledger value and will overwrite this
			-- field again after the nested call.
			if ent._mass == nil then ent._mass = currentMass end
			ACE_EnsureCFWMassState(ent, currentMass)
		end

		local result = OldSetMass(self, mass)

		if not IsEnt(ent) then
			return result
		end

		if ent.IsPrimitive and ACE.PrimitivePropertiesApplied then
			ACE.PrimitivePropertiesApplied(ent)
		end

		if math.abs(mass - currentMass) < 0.01 then
			return result
		end

		if ent:GetClass() ~= "prop_physics" and not ent.IsPrimitive then return result end

		local con = ACE.GetContraptionFromEntity and ACE.GetContraptionFromEntity(ent)
		ACE.MarkArmorDirty(con, ent, "mass-changed")

		return result
	end
end

-- ------------------------------------------------------------
-- Cache reset and armor dirty handling
-- ------------------------------------------------------------

-- Clear derived point caches globally; contraptions rebuild on demand.
local function ACE_ClearAllCaches()
	ACE.ArmorPointCache = {}
	ACE.CacheVersion = (ACE.CacheVersion or 1) + 1

	if ACE.NotifyPointsInvalidated then
		local contraptions = {}
		for con in pairs(ACE.PointContraptions or {}) do
			if con and not con.ACERemoving then
				con.ACECacheVersion = ACE.CacheVersion
				contraptions[#contraptions + 1] = con
			end
		end

		ACE.NotifyPointsInvalidated(contraptions, "cache-reset", {
			Armor = true,
			Ammo = true,
			Firepower = true,
			ReadyRack = true,
			Warning = true,
		})
	end
end

concommand.Add("ace_cache_clear_all", function()
	ACE_ClearAllCaches()
end)

-- Mark armor points dirty for callers that know only armor changed.
function ACE.MarkArmorDirty(con, ent, reason)
	if not con then
		if ACE.ClearArmorPointCache and IsEnt(ent) then ACE.ClearArmorPointCache(ent) end
		return
	end

	ACE.NotifyPointsInvalidated(ent or con, reason or "armor-updated", {
		Armor = true,
		Warning = true,
	}, { con })
end

-- Reprice clipped armor after Proper Clipping replaces its physics object.
local function ACE_ProperClippingPhysicsChanged(ent)
	if not IsEnt(ent) then return end

	local con = ACE.GetContraptionFromEntity and ACE.GetContraptionFromEntity(ent)
	ACE.MarkArmorDirty(con, ent, "armor-clipped")
end

hook.Add("ProperClippingPhysicsClipped", "ACE_ProperClippingArmorChanged", ACE_ProperClippingPhysicsChanged)
hook.Add("ProperClippingPhysicsReset", "ACE_ProperClippingArmorReset", ACE_ProperClippingPhysicsChanged)

-- Freeze transitions do not change the pricing formula, but they are lifecycle
-- boundaries where armor, legality, and readout state are commonly initialized.
-- Route them through the same event so no consumer has to infer a rebuild from
-- a transient physics state.
local function ACE_NotifyPhysicsTransition(ent, reason, frozen)
	if not IsEnt(ent) then return end

	if frozen then
		if ent._ACEPointsFrozen then return end
		ent._ACEPointsFrozen = true
	else
		if not ent._ACEPointsFrozen then return end
		ent._ACEPointsFrozen = false
	end

	ACE.PointsInputChanged(ent, reason)
end

hook.Add("OnPhysgunFreeze", "ACE_PointsFreezeInvalidation", function(_, _, ent)
	ACE_NotifyPhysicsTransition(ent, "freeze", true)
end)

hook.Add("PhysgunDrop", "ACE_PointsUnfreezeInvalidation", function(_, ent)
	ACE_NotifyPhysicsTransition(ent, "unfreeze", false)
end)

hook.Add("PlayerEnteredVehicle", "ACE_PointsVehicleUnfreezeInvalidation", function(_, vehicle)
	if IsEnt(vehicle) and vehicle.CFW_GetContraption then
		local con = vehicle:CFW_GetContraption()
		if con and vehicle._ACEPointsFrozen then
			vehicle._ACEPointsFrozen = false
			ACE.NotifyPointsInvalidated(con, "unfreeze-on-entry")
		end
	end
end)

