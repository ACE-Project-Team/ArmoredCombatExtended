-- ACE entity legality.
--
-- This follows ACF's validation contract: legality is a pure check of the
-- entity's current state, failed checks disable the entity for a real timeout,
-- and a later timer re-checks it.  Point limits and point-cache state are not
-- part of entity legality; they are contraption accounting and warnings.

ACE = ACE or {}
ACE.Legal = ACE.Legal or {}
ACE.Legal.Ignore = ACE.Legal.Ignore or {}
ACE.Legal.Contracts = ACE.Legal.Contracts or {}
ACE.Legal.MutationDepth = ACE.Legal.MutationDepth or setmetatable({}, { __mode = "k" })

local function BumpOperationalVersion()
	if ACE.Points and ACE.Points.BumpOperationalVersion then
		return ACE.Points.BumpOperationalVersion()
	end

	ACE.PointsOperationalVersion = (ACE.PointsOperationalVersion or 0) + 1
	return ACE.PointsOperationalVersion
end

local function ReadLegalCvars()
	local function Read(name)
		local cvar = GetConVar(name)
		return cvar and math.max(cvar:GetInt(), 0) or 0
	end

	ACE.Legal.IsActivated = Read("ace_legalcheck")
	ACE.Legal.Ignore.Solid = Read("ace_legal_ignore_solid")
	ACE.Legal.Ignore.Model = Read("ace_legal_ignore_model")
	ACE.Legal.Ignore.Mass = Read("ace_legal_ignore_mass")
	ACE.Legal.Ignore.Material = Read("ace_legal_ignore_material")
	ACE.Legal.Ignore.Inertia = Read("ace_legal_ignore_inertia")
	ACE.Legal.Ignore.makesphere = Read("ace_legal_ignore_makesphere")
	ACE.Legal.Ignore.visclip = Read("ace_legal_ignore_visclip")
	ACE.Legal.Ignore.Parent = Read("ace_legal_ignore_parent")
end

ReadLegalCvars()

-- These names are kept for the existing entity Think loops.  The second
-- parameter is optional because older ACE callers use both dot and colon
-- forms; accepting both prevents the old "disabled for 0s" failure.
ACE.Legal.Min = 5
ACE.Legal.Max = 25
ACE.Legal.Lockout = 35
function ACE.Legal.NextCheck(first, second)
	local legal = second
	if legal == nil then legal = first end

	local delay = legal and math.random(ACE.Legal.Min, ACE.Legal.Max) or ACE.Legal.Lockout
	return CurTime() + delay
end

function ACE_LegalityCallBack()
	ReadLegalCvars()
	BumpOperationalVersion()

	-- A policy change must be checked against the live state, but does not
	-- directly mutate physics or point totals while entities are spawning.
	for _, ent in ipairs(ents.GetAll()) do
		if IsValid(ent) and ent.ACE_LegalArgs then
			ent.NextLegalCheck = CurTime()
		end
	end
end

for _, name in ipairs({
	"ace_legalcheck", "ace_legal_ignore_solid", "ace_legal_ignore_model",
	"ace_legal_ignore_mass", "ace_legal_ignore_material", "ace_legal_ignore_inertia",
	"ace_legal_ignore_makesphere", "ace_legal_ignore_visclip", "ace_legal_ignore_parent"
}) do
	cvars.AddChangeCallback(name, ACE_LegalityCallBack, "ACE_RefreshLegality")
end

local function Contract(model, mass, inertia, requiresParent)
	return function(ent)
		local modelValue = model and ent[model] or nil
		local massValue = mass and ent[mass] or nil
		return modelValue, massValue and math.Round(massValue, 2) or nil,
			inertia and ent[inertia] or nil, requiresParent, true
	end
end

ACE.Legal.Contracts["acf_gun"] = Contract("Model", "Mass", "ModelInertia", false)
ACE.Legal.Contracts["acf_rack"] = Contract(nil, "Mass", "ModelInertia", false)
ACE.Legal.Contracts["acf_ammo"] = function(ent)
	return ent.Model, math.Round(ent.EmptyMass or 0, 2), nil, true, true
end
ACE.Legal.Contracts["acf_engine"] = Contract("Model", "Weight", "ModelInertia", true)
ACE.Legal.Contracts["acf_fueltank"] = Contract("Model", "EmptyMass", nil, true)
ACE.Legal.Contracts["acf_gearbox"] = Contract("Model", "Mass", "ModelInertia", true)
ACE.Legal.Contracts["acf_missileradar"] = Contract("Model", "Weight", nil, true)
ACE.Legal.Contracts["ace_ecm"] = Contract("Model", "Weight", nil, true)
ACE.Legal.Contracts["ace_irst"] = Contract("Model", "Weight", nil, true)
ACE.Legal.Contracts["ace_rwr_dir"] = Contract("Model", "Weight", nil, true)
ACE.Legal.Contracts["ace_rwr_sphere"] = Contract("Model", "Weight", nil, true)
ACE.Legal.Contracts["ace_searchradar"] = Contract("Model", "Weight", nil, true)
ACE.Legal.Contracts["ace_trackingradar"] = Contract("Model", "Weight", nil, true)
ACE.Legal.Contracts["ace_sonar"] = Contract(nil, "Weight", nil, true)
ACE.Legal.Contracts["ace_crewseat_driver"] = Contract("Model", "Weight", nil, true)
ACE.Legal.Contracts["ace_crewseat_gunner"] = Contract("Model", "Weight", nil, true)
ACE.Legal.Contracts["ace_crewseat_loader"] = Contract("Model", "Weight", nil, true)

local function GenericContract(ent)
	local mass = ent.Mass or ent.Weight or ent.EmptyMass
	return ent:GetModel(), mass and math.Round(mass, 2) or nil, nil, true, false
end

for _, class in ipairs({
	"ace_bomb_aerial", "ace_bomb_barrel", "ace_bomb_satchel", "ace_explosive",
	"ace_explosive_prebuilt", "ace_flare", "ace_gforce_meter", "ace_grenade",
	"ace_mine", "ace_missile", "ace_scalability", "ace_slammine", "ace_smokegrenade",
	"ace_vheat_source", "ace_wind_sensor", "acf_explosive", "acf_fakecrate2",
	"acf_missile_to_rack", "acf_opticalcomputer"
}) do
	ACE.Legal.Contracts[class] = ACE.Legal.Contracts[class] or GenericContract
end

local ValidCollisionGroups = {
	[COLLISION_GROUP_NONE] = true,
	[COLLISION_GROUP_WORLD] = true,
	[COLLISION_GROUP_VEHICLE] = true,
}

local function IsFinite(value)
	return isnumber(value) and value == value and value ~= math.huge and value ~= -math.huge
end

local function IsManaged(ent)
	if not IsValid(ent) or not ent.GetClass or not ent.ACE_LegalArgs then return false end
	local class = ent:GetClass()
	return class:sub(1, 4) == "acf_" or class:sub(1, 4) == "ace_"
end

-- Pure current-state legality check.  This intentionally does not inspect
-- points, CFW membership, parent identity, or an old fingerprint.  Those are
-- transient gameplay/accounting state and ACF does not use them to validate an
-- entity's physics contract.
function ACE.IsLegal(ent, model, minMass, minInertia, _, canVisclip)
	if ACE.Legal.IsActivated == 0 then return true end
	if not IsValid(ent) then return false, "Invalid Ent" end
	if ent.ACE_IsNotLegalityChecked then return true end

	local phys = ent:GetPhysicsObject()
	if not IsValid(phys) then return false, "Invalid Physics" end

	local problems = {}
	if ACE.Legal.Ignore.Solid <= 0 and not ent:IsSolid() then
		problems[#problems + 1] = "Not solid"
	end

	if model ~= nil and ACE.Legal.Ignore.Model <= 0 and ent:GetModel() ~= model then
		problems[#problems + 1] = "Wrong model"
	end

	if ACE.Legal.Ignore.Mass <= 0 then
		local mass = phys:GetMass()
		if not IsFinite(mass) or mass <= 0 then
			problems[#problems + 1] = "Invalid mass"
		elseif minMass ~= nil and math.Round(mass, 2) < minMass then
			problems[#problems + 1] = "Under min mass"
		end
	end

	if ACE.Legal.Ignore.Inertia <= 0 and minInertia ~= nil then
		local mass = phys:GetMass()
		local raw = phys:GetInertia()
		local inertia = mass > 0 and raw / mass or Vector(math.huge, math.huge, math.huge)
		if not IsFinite(inertia.x) or not IsFinite(inertia.y) or not IsFinite(inertia.z)
			or inertia.x < minInertia.x or inertia.y < minInertia.y or inertia.z < minInertia.z then
			problems[#problems + 1] = "Under min inertia"
		end
	end

	if ACE.Legal.Ignore.makesphere <= 0 and phys:GetVolume() == nil then
		problems[#problems + 1] = "Has makesphere"
	end

	if ACE.Legal.Ignore.visclip <= 0 and not canVisclip and ent.ClipData and #ent.ClipData > 0 then
		problems[#problems + 1] = "Has visclip"
	end

	if ACE.Legal.Ignore.Solid <= 0 and not ValidCollisionGroups[ent:GetCollisionGroup()] then
		problems[#problems + 1] = "Bad collision group"
	end

	local class = ent:GetClass()
	if class == "acf_gun" and not ACE.GunfireEnabled then
		problems[#problems + 1] = "Cannot fire"
	elseif class == "acf_rack" and ACE.RacksCanFire == false then
		problems[#problems + 1] = "Cannot fire"
	end

	if #problems > 0 then return false, table.concat(problems, ", ") end
	return true, ""
end

-- Keep the historical global entry point used throughout ACE.
function ACE_CheckLegal(ent, model, minMass, minInertia, requiresParent, canVisclip)
	return ACE.IsLegal(ent, model, minMass, minInertia, requiresParent, canVisclip)
end

function ACE.WithMutationScope(ent, _, callback)
	if not IsValid(ent) then return false, "Invalid Ent" end
	local depths = ACE.Legal.MutationDepth
	depths[ent] = (depths[ent] or 0) + 1
	local ok, result, extra = xpcall(callback, debug.traceback)
	depths[ent] = depths[ent] - 1
	if depths[ent] <= 0 then depths[ent] = nil end
	if not ok then error(result, 0) end
	return result, extra
end

function ACE.IsMutationScoped(ent)
	return IsValid(ent) and (ACE.Legal.MutationDepth[ent] or 0) > 0
end

local function DisableEntity(ent, reason, message, timeout)
	if not IsValid(ent) then return end

	local delay = math.max(tonumber(timeout) or ACE.Legal.Lockout, 1)
	local untilTime = CurTime() + delay
	local disabled = ent.Disabled
	if not disabled or disabled.Reason ~= reason then
		ent.Disabled = { Reason = reason, Message = message or reason, Until = untilTime }
	else
		-- Preserve the original disable timestamp while the same failure persists.
		untilTime = math.max(disabled.Until or 0, untilTime)
		disabled.Until = untilTime
	end

	ent.Legal = false
	ent.LegalIssues = message or reason or "Not legal"
	ent.NextLegalCheck = untilTime
	if ent.Active and ent.SetActive then ent:SetActive(false) end
	if ent.UpdateOverlayText then ent:UpdateOverlayText() end

	local timerName = "ACE_LegalRecheck_" .. ent:EntIndex()
	timer.Create(timerName, math.max(untilTime - CurTime(), 1), 1, function()
		if not IsValid(ent) then return end
		local legal = ACE.CheckLegal(ent)
		if not legal then return end
		ent.Disabled = nil
		if ent.UpdateOverlayText then ent:UpdateOverlayText(true) end
	end)
end

ACE.DisableEntity = DisableEntity

function ACE.InvalidateLegal(ent, reason)
	if not IsValid(ent) then return end
	BumpOperationalVersion()
	DisableEntity(ent, reason or "Legality invalidated", reason, ACE.Legal.Lockout)
end

function ACE.CheckLegal(ent)
	if not IsValid(ent) then return false, "Invalid Ent" end

	local args = ent.ACE_LegalArgs
	local legal, issues = ACE.IsLegal(ent, args and unpack(args) or nil)
	if not legal then
		DisableEntity(ent, issues, issues)
		return false, issues
	end

	local wasIllegal = ent.Legal == false
	ent.Legal = true
	ent.LegalIssues = ""
	ent.Disabled = nil
	if wasIllegal or not ent.NextLegalCheck or ent.NextLegalCheck <= CurTime() then
		ent.NextLegalCheck = ACE.Legal.NextCheck(true)
	end

	return true, ""
end

function ACE.RequireLegal(ent, model, minMass, minInertia, requiresParent, canVisclip)
	if not IsValid(ent) then return false, "Invalid Ent" end

	ent.ACE_LegalArgs = { model, minMass, minInertia, requiresParent, canVisclip }
	local legal, issues = ACE.IsLegal(ent, model, minMass, minInertia, requiresParent, canVisclip)
	if not legal then
		DisableEntity(ent, issues, issues)
		return false, issues
	end

	local changed = ent.Legal ~= true
	ent.Legal = true
	ent.LegalIssues = ""
	ent.Disabled = nil
	if changed or not ent.NextLegalCheck or ent.NextLegalCheck <= CurTime() then
		ent.NextLegalCheck = ACE.Legal.NextCheck(true)
	end

	return true, ""
end

-- Operational callers always get a current-state check.  A failed ACF-style
-- disable remains inert until its real retry time; it never participates in
-- point accounting and never mutates linked ammo/fuel state.
function ACE.RequireEntityLegal(ent)
	if not IsValid(ent) then return false, "Invalid Ent" end

	local disabled = ent.Disabled
	if disabled and CurTime() < (disabled.Until or ent.NextLegalCheck or 0) then
		return false, ent.LegalIssues or disabled.Message or "Not legal"
	end

	local args = ent.ACE_LegalArgs
	if not args then
		local contract = ACE.Legal.Contracts[ent:GetClass()] or GenericContract
		args = { contract(ent) }
	end

	local legal, issues = ACE.IsLegal(ent, unpack(args))
	if not legal then
		DisableEntity(ent, issues, issues)
		return false, issues
	end

	if ent.Legal ~= true then
		ent.Legal = true
		ent.LegalIssues = ""
		ent.Disabled = nil
		ent.NextLegalCheck = ACE.Legal.NextCheck(true)
	end

	return true, ""
end

-- ACF-style guardrails: block only the operations that create an invalid
-- physics state.  Normal initialization, parenting, and lifecycle writes are
-- allowed to complete; the following legality check observes their final state.
do
	local ENTITY = FindMetaTable("Entity")
	local function Install(name, check, allow)
		local oldName = "_ACE_LegalOld_" .. name
		ACE[oldName] = ACE[oldName] or ENTITY[name]
		local old = ACE[oldName]
		if not old then return end

		ENTITY[name] = function(self, ...)
			if IsManaged(self) and ACE.Legal.IsActivated > 0 and not ACE.IsMutationScoped(self)
				and not allow(self, ...) then
				ACE.CheckLegal(self)
				return false
			end
			if check then check(self, ...) end
			return old(self, ...)
		end
	end

	Install("PhysicsInitSphere", nil, function() return false end)
	Install("SetCollisionBounds", nil, function() return false end)
	Install("SetNoDraw", nil, function(self, value) return not tobool(value) end)
	Install("SetCollisionGroup", nil, function(self, group)
		return ValidCollisionGroups[group] or group == COLLISION_GROUP_IN_VEHICLE
	end)
	Install("SetNotSolid", function(self)
		if timer then timer.Simple(0, function()
			if IsValid(self) then ACE.CheckLegal(self) end
		end) end
	end, function() return true end)
end

-- AdvDupe parent restoration is intentionally a repair hook, not a legality
-- detour.  SetParent must be allowed through the paste queue so guns, engines,
-- crews, and ammo remain attached while CFW settles its contraption.
local function RestoreAdvDupeParents(dupe, restoreAllParents)
	if not istable(dupe) or not istable(dupe.EntityList) or not istable(dupe.CreatedEntities) then return end

	for sourceId, source in pairs(dupe.EntityList) do
		local parentId = istable(source) and source.BuildDupeInfo and source.BuildDupeInfo.DupeParentID
		local child = dupe.CreatedEntities[sourceId] or dupe.CreatedEntities[tostring(sourceId)]
		local parent = parentId and (dupe.CreatedEntities[parentId] or dupe.CreatedEntities[tostring(parentId)])
		local class = IsValid(child) and child:GetClass() or ""
		local isACE = class:sub(1, 4) == "acf_" or class:sub(1, 4) == "ace_"
		if parentId and (restoreAllParents or isACE) and IsValid(child) and IsValid(parent)
			and child:GetParent() ~= parent then
			child:SetParent(parent)
			if CFW and CFW.connect and child.GetCFWLink and not child:GetCFWLink(parent) then
				CFW.connect(child, parent)
			end
		end
	end
end

hook.Add("AdvDupe_FinishPasting", "ACE Restore Enforced Parents", function(data)
	local dupe = istable(data) and (data[1] or data) or nil
	if not istable(dupe) then return end

	local player = dupe.Player
	local restoreParents = true
	if IsValid(player) and player.GetInfo then
		local setting = player:GetInfo("advdupe2_paste_parents")
		if setting ~= nil and setting ~= "" and not tobool(setting) then restoreParents = false end
	end

	RestoreAdvDupeParents(dupe, restoreParents)
	timer.Simple(0, function()
		RestoreAdvDupeParents(dupe, restoreParents)
		hook.Run("ACE_AdvDupeParentsRestored", dupe)
	end)
	timer.Simple(0.1, function() RestoreAdvDupeParents(dupe, restoreParents) end)
end)

-- AdvDupe2 can replay a saved non-solid state after an ammo crate has run its
-- constructor.  Restore the crate's physical contract without touching its
-- round count or Load flag; the normal current-state check then decides when
-- it may be used.
local function RestoreAmmoPastePhysics(dupe)
	if not istable(dupe) or not istable(dupe.CreatedEntities) then return end

	for _, ent in pairs(dupe.CreatedEntities) do
		if IsValid(ent) and ent:GetClass() == "acf_ammo" and not ent:IsSolid() then
			ACE.WithMutationScope(ent, "ammo-paste-physics", function()
				ent:SetSolid(SOLID_VPHYSICS)
				ent:SetNotSolid(false)
			end)
			ent.Legal = false
			ent.LegalIssues = "Awaiting legality validation"
			ent.NextLegalCheck = CurTime()
		end
	end
end

hook.Add("AdvDupe_FinishPasting", "ACE Restore Ammo Paste Physics", function(data)
	local dupe = istable(data) and (data[1] or data) or nil
	if not istable(dupe) then return end

	RestoreAmmoPastePhysics(dupe)
	timer.Simple(0, function() RestoreAmmoPastePhysics(dupe) end)
	timer.Simple(0.1, function() RestoreAmmoPastePhysics(dupe) end)
end)
