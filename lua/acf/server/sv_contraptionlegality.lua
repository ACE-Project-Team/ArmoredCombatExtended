ACE = ACE or {}

include("acf/shared/sh_ace_functions.lua")
include("acf/server/sv_pointshandling.lua")


local ACE_ConVarHelp = ACE_ConVarHelp
local IsEnt = ACE_IsEnt
local ACE_GetPtsType = ACE_GetPtsType
ACE.CacheVersion = ACE.CacheVersion or 1

-- ------------------------------------------------------------
-- Legal check throttle (prevents chat spam)
-- ------------------------------------------------------------

-- Run a legality scan for a contraption.
function ACE_DoContraptionLegalCheck(checkEnt)
	checkEnt.CanLegalCheck = checkEnt.CanLegalCheck or false
	if not checkEnt.CanLegalCheck then return end

	checkEnt.CanLegalCheck = false
	timer.Simple(3, function()
		if IsEnt(checkEnt) then checkEnt.CanLegalCheck = true end
	end)

	local con = checkEnt:GetContraption() or {}
	if table.IsEmpty(con) then return end

	ACE_CheckLegalCont(con)
end

-- ------------------------------------------------------------
-- Player warnings (over points, overweight, and dirty armor)
-- ------------------------------------------------------------

-- Evaluate legality for a contraption.
function ACE_CheckLegalCont(con)
	con.OTWarnings = con.OTWarnings or {}

	if con.ACEArmorDirty then
		ACE_NotifyContraptionModified(con)
	end

	if con.ACEPoints > ACF.PointsLimit and not con.OTWarnings.WarnedOverPoints then
		local name  = ACE_GetOwnerName(ACE_GetContraptionOwner(con))
		local above = con.ACEPoints - ACF.PointsLimit
		chatMessageGlobal(
			"[ACE] " .. name .. " has a vehicle [" .. math.ceil(above) .. "pts] over the limit costing [" ..
				math.ceil(con.ACEPoints) .. "pts / " .. math.ceil(ACF.PointsLimit) .. "pts]",
			Color(255, 234, 0)
		)
		con.OTWarnings.WarnedOverPoints = true
	end

	if con.totalMass > ACF.MaxWeight and not con.OTWarnings.WarnedOverWeight then
		local name  = ACE_GetOwnerName(ACE_GetContraptionOwner(con))
		local above = con.totalMass - ACF.MaxWeight
		chatMessageGlobal(
			"[ACE] " .. name .. " has a vehicle [" .. math.ceil(above) .. "kg] over the limit, weighing [" ..
				math.ceil(con.totalMass) .. "kg / " .. math.ceil(ACF.MaxWeight) .. "kg]",
			Color(255, 234, 0)
		)
		con.OTWarnings.WarnedOverWeight = true
	end
end

-- ------------------------------------------------------------
-- Contraption init and point bookkeeping hooks
-- ------------------------------------------------------------

do
	-- Sync per-contraption cache version and invalidate stale local caches.
	function ACE_EnsureCacheVersion(con)
		if not con then return false end

		if con.ACECacheVersion == nil then
			con.ACECacheVersion = ACE.CacheVersion
			return false
		end

		if con.ACECacheVersion == ACE.CacheVersion then return false end

		con.ACECacheVersion = ACE.CacheVersion

		con.ACEArmorCachedData = nil
		con.ACEArmorCacheKey = nil
		con.ACEArmorCalculated = false
		con.ACEArmorLastCalc = 0

		con.ACENonArmorDirty = true
		con.ACEAmmoCache = nil
		con.ACESubsystemCache = {}
		con.ACESubsystemDirty = {
			Ammo = true,
			Engines = true,
			Firepower = true,
			Crew = true,
			Electronics = true
		}
		con.ACEDupeSubsystemKeys = nil
		con.ACEPointsDetails = nil

		return true
	end

	-- Initialize per-contraption points state.
	local function ACE_InitPts(con)
		if con.ACEInitDone then return end
		con.ACEInitDone = true

		con.ACECacheVersion = ACE.CacheVersion
		con.ACEPoints = 0
		con.ACEPointsNonArmor = 0

		con.ACEArmorPoints = 0
		con.ACEArmorDirty = false
		con.ACEArmorCalculated = false
		con.ACEArmorLastCalc = 0

		con.ACENonArmorDirty = true
		con.ACEAmmoCache = nil
		con.ACESubsystemCache = {}
		con.ACESubsystemDirty = {
			Ammo = true,
			Engines = true,
			Firepower = true,
			Crew = true,
			Electronics = true
		}
		con.ACEDupeSubsystemKeys = nil

		con.ACEPointsPerType = {}
		for _, k in ipairs({
			"Armor",
			"Engines",
			"Firepower",
			"Ammo",
			"AmmoReady",
			"AmmoBackup",
			"AmmoReadyRounds",
			"AmmoBackupRounds",
			"Crew",
			"Electronics"
		}) do
			con.ACEPointsPerType[k] = 0
		end
	end

	-- Mark a subsystem as dirty and clear related caches.
	function ACE_MarkSubsystemDirty(con, subsystem)
		if not con or not subsystem then return end

		con.ACESubsystemDirty = con.ACESubsystemDirty or {}
		con.ACESubsystemDirty[subsystem] = true
		con.ACENonArmorDirty = true

		if con.ACEDupeSubsystemKeys then
			con.ACEDupeSubsystemKeys[subsystem] = nil
		end

		if con.ACESubsystemCache then
			con.ACESubsystemCache[subsystem] = nil
		end

		if subsystem == "Ammo" then
			con.ACEAmmoCache = nil
		end
	end

	-- Initialize point tracking when a contraption is created.
	hook.Add("cfw.contraption.created", "ACE_InitPoints", ACE_InitPts)
	-- Initialize point tracking when a family is created.
	hook.Add("cfw.family.created", "ACE_InitPoints", ACE_InitPts)

	-- Flag contraptions that are being removed to suppress dirty warnings.
	hook.Add("cfw.contraption.removed", "ACE_ContraptionRemoving", function(con)
		if not con then return end
		con.ACERemoving = true
		if con.OTWarnings then con.OTWarnings.WarnedModified = true end
	end)

	-- Handle entity addition and update point totals.
	function ACE_AddPts(con, ent)
		if not IsEnt(ent) then return end

		local cls = ent:GetClass()
		local eclass = ACE_GetPtsType(cls)

		if eclass ~= "Ignore" and eclass ~= "Armor" then
			ACE_MarkSubsystemDirty(con, eclass)
		end

		if cls == "acf_gun" or cls == "acf_rack" then
			ACE_MarkSubsystemDirty(con, "Ammo")
		end

		local newPts = ACE_GetEntPoints(ent)
		local oldPts = ent._AcePts or 0

		if eclass == "Ignore" then
			if ent._ACEPointsConRef and ent._ACEPointsConRef ~= con then
				ACE_RemPts(ent._ACEPointsConRef, ent)
			end

			ent._ACEPointsConRef = con
			ent._ACEPointsConKey = ACE_GetContraptionIndex and ACE_GetContraptionIndex(con) or nil
			ent._AcePts = 0
			return
		end

		if ent._ACEPointsConRef == con then
			if eclass == "Armor" then
				ACE_MarkArmorDirty(con, ent, "addpts-existing")
			else
				local delta = newPts - oldPts
				if delta ~= 0 then
					con.ACEPoints = (con.ACEPoints or 0) + delta
					con.ACEPointsNonArmor = (con.ACEPointsNonArmor or 0) + delta
					con.ACEPointsPerType = con.ACEPointsPerType or {}
					con.ACEPointsPerType[eclass] = (con.ACEPointsPerType[eclass] or 0) + delta
					ACE_NotifyContraptionModified(con)
				end
			end

			ent._AcePts = newPts
			return
		end

		if ent._ACEPointsConRef and ent._ACEPointsConRef ~= con then
			ACE_RemPts(ent._ACEPointsConRef, ent)
		end

		ent._ACEPointsConRef = con
		ent._ACEPointsConKey = ACE_GetContraptionIndex and ACE_GetContraptionIndex(con) or nil
		ent._AcePts = newPts

		if eclass == "Armor" then
			ACE_MarkArmorDirty(con, ent, "addpts-new")
		else
			con.ACEPoints = (con.ACEPoints or 0) + newPts
			con.ACEPointsNonArmor = (con.ACEPointsNonArmor or 0) + newPts
			con.ACEPointsPerType = con.ACEPointsPerType or {}
			con.ACEPointsPerType[eclass] = (con.ACEPointsPerType[eclass] or 0) + newPts
		end
	end

	-- Handle entity removal and update point totals.
	function ACE_RemPts(con, ent)
		if not IsEnt(ent) then return end
		if ent.IsBeingRemoved and ent:IsBeingRemoved() then return end
		if ent._ACEPointsConRef and ent._ACEPointsConRef ~= con then return end

		ent._ACEPointsConKey = nil
		ent._ACEPointsConRef = nil

		local cls = ent:GetClass()
		local eclass = ACE_GetPtsType(cls)

		if eclass ~= "Ignore" and eclass ~= "Armor" then
			ACE_MarkSubsystemDirty(con, eclass)
		end

		if cls == "acf_gun" or cls == "acf_rack" then
			ACE_MarkSubsystemDirty(con, "Ammo")
		end

		if eclass == "Ignore" then return end

		if eclass == "Armor" then
			ACE_MarkArmorDirty(con, ent, "rempts")
			return
		end

		local pts = ent._AcePts or 0
		con.ACEPoints = (con.ACEPoints or 0) - pts
		con.ACEPointsNonArmor = (con.ACEPointsNonArmor or 0) - pts
		con.ACEPointsPerType = con.ACEPointsPerType or {}
		con.ACEPointsPerType[eclass] = (con.ACEPointsPerType[eclass] or 0) - pts

		ACE_NotifyContraptionModified(con)
	end

	-- Track point totals when entities are added.
	hook.Add("cfw.contraption.entityAdded", "ACE_AddPoints", ACE_AddPts)
	-- Track point totals when entities are added to a family.
	hook.Add("cfw.family.added", "ACE_AddPoints", ACE_AddPts)

	-- Track point totals when entities are removed.
	hook.Add("cfw.contraption.entityRemoved", "ACE_RemPoints", ACE_RemPts)
	-- Track point totals when entities are removed from a family.
	hook.Add("cfw.family.subbed", "ACE_RemPoints", ACE_RemPts)
end

-- ------------------------------------------------------------
-- Hook PhysObj:SetMass (delegates armor marking to ARMOR wrapper)
-- ------------------------------------------------------------

do
	local PHYS = FindMetaTable("PhysObj")

	ACE._OldPhysSetMass = ACE._OldPhysSetMass or PHYS.SetMass
	local OldSetMass = ACE._OldPhysSetMass

	-- Override PhysObj:SetMass to mark armor dirty when needed.
	function PHYS:SetMass(mass)
		local ent = self:GetEntity()
		if not IsEnt(ent) then
			return OldSetMass(self, mass)
		end

		local currentMass = self:GetMass()
		if math.abs(mass - currentMass) < 0.01 then
			return OldSetMass(self, mass)
		end

		local oldPts = ent._AcePts or 0
		ent._AcePts = ACE_GetEntPoints(ent)

		OldSetMass(self, mass)

		local con = ent.GetContraption and ent:GetContraption()
		if not con then return end

		local delta = (ent._AcePts or 0) - oldPts
		local cls = ent:GetClass()
		local eclass = ACE_GetPtsType(cls)

		if eclass == "Ignore" then return end

		if eclass == "Armor" then
			if delta ~= 0 then
				ACE_MarkArmorDirty(con, ent, "setmass")
			end
			return
		end

		if delta == 0 then return end

		ACE_MarkSubsystemDirty(con, eclass)
		if cls == "acf_gun" or cls == "acf_rack" then
			ACE_MarkSubsystemDirty(con, "Ammo")
		end

		con.ACEPoints = (con.ACEPoints or 0) + delta
		con.ACEPointsNonArmor = (con.ACEPointsNonArmor or 0) + delta
		con.ACEPointsPerType = con.ACEPointsPerType or {}
		con.ACEPointsPerType[eclass] = (con.ACEPointsPerType[eclass] or 0) + delta

		ACE_NotifyContraptionModified(con)
	end
end

-- ============================================================
-- SECTION 2: ARMOR ONLY
-- Dirty tracking, dupe caching, scan scheduling, scan math use
-- ============================================================

-- ------------------------------------------------------------
-- Simple ignore rules
-- Limited parent-chain logic
-- ------------------------------------------------------------


-- Ignore dirty events for safe/non-armor entities.
local function ACE_ShouldIgnoreDirtyEnt(ent)
	if not IsEnt(ent) then return true end

	if ACE_IsMissileEntity(ent) then return true end

	-- Walk a few levels up the parent chain to ignore missile attachments only
	local p = ent:GetParent()
	local depth = 0
	while IsEnt(p) and depth < 4 do
		if ACE_IsMissileEntity(p) then return true end

		p = p:GetParent()
		depth = depth + 1
	end

	return false
end

-- ------------------------------------------------------------
-- Armor init and dirty rules
-- ------------------------------------------------------------

-- Check whether armor has been initialized.
function ACE_HasArmorInit(con)
	if not con then return false end
	if con.ACEArmorCalculated then return true end
	return (con.ACEArmorLastCalc or 0) > 0
end

-- Dirty ignore check (stub before ARMOR section).
function ACE_ShouldIgnoreDirty(con)
	if not con then return true end
	if con.ACERemoving then return true end
	if not ACE_HasArmorInit(con) then return true end
	return false
end

-- ------------------------------------------------------------
-- Debug logging 
-- ------------------------------------------------------------

ACE.ArmorDebugCvar = ACE.ArmorDebugCvar or CreateConVar("acf_armor_debug",
	"0",
	FCVAR_ARCHIVE,
	ACE_ConVarHelp("Enable stored armor dirty logging (no live console spam).")
)

local armorDebugCvar = ACE.ArmorDebugCvar

local armorDirtyLogLimit = CreateConVar("acf_armor_dirty_log_limit",
	"120",
	FCVAR_ARCHIVE,
	ACE_ConVarHelp("How many stored dirty entries to keep.")
)

local armorDirtyLog = armorDirtyLog or {}


local function ACE_ShortCacheKey(key)
	if not key then return "nil" end
	local hash = tostring(key):match(":([%x]+)$") or tostring(key)
	if #hash > 8 then
		return hash:sub(1, 8)
	end
	return hash
end

-- Store a compact dirty-log entry.
local function ACE_PushDirtyLog(entry)
	local limit = math.max(10, armorDirtyLogLimit:GetInt() or 120)
	armorDirtyLog[#armorDirtyLog + 1] = entry
	while #armorDirtyLog > limit do
		table.remove(armorDirtyLog, 1)
	end
end

-- Emit debug logs for armor dirty events.
function ACE_DebugDirty(con, reason, ent, extra, action)
	if not armorDebugCvar:GetBool() then return end
	if not ACE_HasArmorInit(con) then return end

	local conId = (ACE_GetContraptionIndex and ACE_GetContraptionIndex(con)) or tostring(con)
	local entClass = IsEnt(ent) and ent:GetClass() or "?"
	local entIndex = IsEnt(ent) and ent:EntIndex() or 0

	local chain = ACE_GetEntChainSummary(ent, 5)
	local entIsMissile = IsEnt(ent) and ACE_IsMissileEntity(ent) or false
	local parent = IsEnt(ent) and ent:GetParent() or nil
	local parentIsMissile = IsEnt(parent) and ACE_IsMissileEntity(parent) or false
	local parentIsRack = IsEnt(parent) and (parent:GetClass() == "acf_rack" or parent:GetClass() == "acf_gun") or false
	local parentIsWire = IsEnt(parent) and ACE_IsWireEntity(parent) or false

	ACE_PushDirtyLog({
		t = CurTime(),
		reason = tostring(reason),
		action = tostring(action or "?"),
		conId = tostring(conId),
		entClass = tostring(entClass),
		entIndex = entIndex,
		wasDirty = con and con.ACEArmorDirty or false,
		extra = extra,
		chain = chain,
		entMissile = entIsMissile,
		parentMissile = parentIsMissile,
		parentRack = parentIsRack,
		parentWire = parentIsWire
	})

-- Emit debug logs for cache decisions.
function ACE_DebugCache(con, reason, ent, extra, action)
	if not armorDebugCvar:GetBool() then return end

	local conId = (ACE_GetContraptionIndex and ACE_GetContraptionIndex(con)) or tostring(con)
	local entClass = IsEnt(ent) and ent:GetClass() or "?"
	local entIndex = IsEnt(ent) and ent:EntIndex() or 0

	local chain = ACE_GetEntChainSummary(ent, 3)

	ACE_PushDirtyLog({
		t = CurTime(),
		reason = tostring(reason),
		action = tostring(action or "Cache"),
		conId = tostring(conId),
		entClass = tostring(entClass),
		entIndex = entIndex,
		wasDirty = con and con.ACEArmorDirty or false,
		extra = extra,
		chain = chain
	})
end

end

concommand.Add("acf_armor_dirty_log_dump", function(_, _, args)
	if not armorDebugCvar:GetBool() then
		print("[ACE] ace_armor_debug is 0")
		return
	end

	local n = tonumber(args[1] or "") or 30
	n = math.Clamp(n, 1, 200)

	print(string.format("[ACE] Dumping last %d stored armor entries", n))

	for i = math.max(1, #armorDirtyLog - n + 1), #armorDirtyLog do
		local e = armorDirtyLog[i]
		print(string.format(
			"[ACE ArmorDirty] %s action=%s id=%s ent=%s idx=%s dirty=%s extra=%s chain=%s missile=%s parentMissile=%s parentRack=%s parentWire=%s",
			tostring(e.reason),
			tostring(e.action),
			tostring(e.conId),
			tostring(e.entClass),
			tostring(e.entIndex),
			tostring(e.wasDirty),
			tostring(e.extra or ""),
			tostring(e.chain or ""),
			tostring(e.entMissile),
			tostring(e.parentMissile),
			tostring(e.parentRack),
			tostring(e.parentWire)
		))
	end
end)

concommand.Add("acf_armor_dirty_log_clear", function()
	armorDirtyLog = {}
	print("[ACE] Cleared stored armor log")
end)

-- ------------------------------------------------------------
-- Player warning when armor was made dirty after init
-- ------------------------------------------------------------

-- Broadcast the dirty notification to players.
function ACE_NotifyContraptionModified(con)
	if not ACE_HasArmorInit(con) then return end
	if con.ACERemoving then return end
	if not con.ACEArmorDirty then return end

	local base = con.GetACEBaseplate and con:GetACEBaseplate()
	if not IsEnt(base) or (base.IsBeingRemoved and base:IsBeingRemoved()) then return end
	if con.ents and next(con.ents) == nil then return end

	con.OTWarnings = con.OTWarnings or {}
	if con.OTWarnings.WarnedModified then return end

	local name = ACE_GetOwnerName(ACE_GetContraptionOwner(con))
	chatMessageGlobal(
		"[ACE] " .. name .. " modified a vehicle after cost initialization. Armor cost marked dirty.",
		Color(255, 200, 0)
	)

	con.OTWarnings.WarnedModified = true
	ACE_DebugDirty(con, "notify-sent", base, nil, "Notify")
end

-- ------------------------------------------------------------
-- Armor dirty wrapper
-- ------------------------------------------------------------

local ArmorDirtyReasonPolicy = {
	rempts = false,
	setmass = true,
	["addpts-existing"] = true,
	["addpts-new"] = true
}

-- Mark armor as dirty and capture context.
function ACE_MarkArmorDirty(con, ent, reason)
	if not con then return end
	if ACE_ShouldIgnoreDirty(con) then return end
	if ACE_ShouldIgnoreDirtyEnt(ent) then return end

	local policy = ArmorDirtyReasonPolicy[reason]
	if policy == false then
		ACE_DebugDirty(con, "skip-reason:" .. tostring(reason), ent, nil, "MarkDirty")
		return
	end

	local cls = IsEnt(ent) and ent:GetClass() or ""
	if cls == "primitive_shape" and not ent.ACEArmorDirtySeen then
		ent.ACEArmorDirtySeen = true
		ACE_DebugDirty(con, "skip-first-primitive-shape", ent, nil, "MarkDirty")
		return
	end

	if con.ACEArmorDirty then
		return
	end

	con.ACEArmorDirty = true
	ACE_DebugDirty(con, "mark-dirty:" .. tostring(reason or "unknown"), ent, nil, "MarkDirty")
	ACE_NotifyContraptionModified(con)
end

-- ============================================================
-- Dupe armor cache + AdvDupe trigger
-- ============================================================

ACE.DupeArmorCache = ACE.DupeArmorCache or {}
ACE.DupeSubsystemCache = ACE.DupeSubsystemCache or {}
ACE.DupeArmorCacheVersion = ACE.DupeArmorCacheVersion or 1
ACE.DupeArmorCacheLastClear = ACE.DupeArmorCacheLastClear or CurTime()
ACE.DupeSubsystemCacheLastClear = ACE.DupeSubsystemCacheLastClear or CurTime()

local DupeArmorCacheTtl = CreateConVar("acf_dupe_armor_cache_ttl",
	"1800",
	FCVAR_ARCHIVE,
	ACE_ConVarHelp("Seconds between clearing the dupe armor cache (0 disables).")
)

timer.Create("ACE_DupeArmorCacheGC", 60, 0, function()
	local ttl = DupeArmorCacheTtl:GetFloat()
	if ttl <= 0 then return end

	local now = CurTime()
	local last = ACE.DupeArmorCacheLastClear or now
	if now - last < ttl then return end

	ACE.DupeArmorCache = {}
	ACE.DupeSubsystemCache = {}
	ACE.DupeArmorCacheLastClear = now
	ACE.DupeSubsystemCacheLastClear = now
end)

local function ACE_ClearAllCaches()
	ACE.DupeArmorCache = {}
	ACE.DupeSubsystemCache = {}
	ACE.DupeArmorCacheLastClear = CurTime()
	ACE.DupeSubsystemCacheLastClear = CurTime()
	ACE.CacheVersion = (ACE.CacheVersion or 1) + 1
end

concommand.Add("acf_cache_clear_all", function()
	ACE_ClearAllCaches()
end)

-- Initialize armor caches after AdvDupe paste.
hook.Add("AdvDupe_FinishPasting", "ACE_ArmorInitOnDupePaste_Trimmed", function(...)
	local dupe, created = ACE_ParseAdvDupeArgs(...)
	if not istable(created) then return end

	local baseKey = ACE_GetDupeSignature(dupe, created)

	local cons = {}
	local conEnts = {}
	for _, ent in pairs(created) do
		if IsValid(ent) then
			local con = ACE_GetContraptionFromEntity(ent)
			if con then
				cons[con] = true
				conEnts[con] = conEnts[con] or {}
				conEnts[con][#conEnts[con] + 1] = ent
			end
		end
	end

	timer.Simple(0.05, function()
		for con in pairs(cons) do
			local baseEnt = con.GetACEBaseplate and con:GetACEBaseplate() or nil
			local ents = conEnts[con]

			local createdKey
			local createdInfo
			local cacheKey
			if ents and ACE_GetCreatedSignature then
				createdKey = ACE_GetCreatedSignature(ents, baseEnt)
				cacheKey = createdKey
			end
			if not cacheKey then
				cacheKey = baseKey
			end

			local cached = (cacheKey and ACE.DupeArmorCache and ACE.DupeArmorCache[cacheKey]) or nil
			if ACE_DebugCache then
				if ents and ACE_GetCreatedSignatureInfo then
					local _, infoTable = ACE_GetCreatedSignatureInfo(ents, baseEnt)
					createdInfo = infoTable
				end

				local info = string.format("base=%s created=%s chosen=%s hit=%s count=%s ref=%s",
					ACE_ShortCacheKey(baseKey),
					ACE_ShortCacheKey(createdKey),
					ACE_ShortCacheKey(cacheKey),
					tostring(cached ~= nil),
					tostring(createdInfo and createdInfo.count or "?"),
					createdInfo and tostring(createdInfo.ref or "") or ""
				)
				ACE_DebugCache(con, "cache-key", baseEnt or con, info, "CacheInit")
			end

			if cacheKey then con.ACEArmorCacheKey = cacheKey end
			if cached then con.ACEArmorCachedData = cached end

			if ents then
				con.ACEDupeSubsystemKeys = ACE_GetSubsystemSignaturesFromEnts(ents)
			end

			ACE_EnsureArmor(con, baseEnt, true)
		end
	end)
end)


-- Armor scan and rebuild logic live in sv_pointshandling.lua










