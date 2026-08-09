
--[[
	set up to provide a random, fairly low cost legality check that discourages trying to game legality checking
	with a hard to predict check time and punishing lockout time
	usage:
	Ent.Legal, Ent.LegalIssues = ACE_CheckLegal(Ent, Model, MinMass, MinInertia, NeedsGateParent, CanVisclip )
	Ent.NextLegalCheck = ACE.LegalSettings:NextCheck(Ent.Legal)
]]

ACE = ACE or {}

ACE.Legal = {}
ACE.Legal.Ignore = {}
ACE.Legal.MutationDepth = ACE.Legal.MutationDepth or setmetatable({}, { __mode = "k" })
ACE.Legal.Contracts = ACE.Legal.Contracts or {}

local function BumpOperationalVersion()
	if ACE.Points and ACE.Points.BumpOperationalVersion then
		return ACE.Points.BumpOperationalVersion()
	end
	ACE.PointsOperationalVersion = (ACE.PointsOperationalVersion or 0) + 1
	return ACE.PointsOperationalVersion
end

ACE.Legal.IsActivated		= math.max(GetConVar("ace_legalcheck"):GetInt(), 0)

ACE.Legal.Ignore.Solid	= math.max(GetConVar("ace_legal_ignore_solid"):GetInt(), 0)
ACE.Legal.Ignore.Model	= math.max(GetConVar("ace_legal_ignore_model"):GetInt(), 0)
ACE.Legal.Ignore.Mass		= math.max(GetConVar("ace_legal_ignore_mass"):GetInt(), 0)
ACE.Legal.Ignore.Material	= math.max(GetConVar("ace_legal_ignore_material"):GetInt(), 0)
ACE.Legal.Ignore.Inertia	= math.max(GetConVar("ace_legal_ignore_inertia"):GetInt(), 0)
ACE.Legal.Ignore.makesphere  = math.max(GetConVar("ace_legal_ignore_makesphere"):GetInt(), 0)
ACE.Legal.Ignore.visclip	= math.max(GetConVar("ace_legal_ignore_visclip"):GetInt(), 0)
ACE.Legal.Ignore.Parent	= math.max(GetConVar("ace_legal_ignore_parent"):GetInt(), 0)

function ACE_LegalityCallBack()
	BumpOperationalVersion()

	ACE.Legal.IsActivated		= math.max(GetConVar("ace_legalcheck"):GetInt(), 0)

	ACE.Legal.Ignore.Solid	= math.max(GetConVar("ace_legal_ignore_solid"):GetInt(), 0)
	ACE.Legal.Ignore.Model	= math.max(GetConVar("ace_legal_ignore_model"):GetInt(), 0)
	ACE.Legal.Ignore.Mass		= math.max(GetConVar("ace_legal_ignore_mass"):GetInt(), 0)
	ACE.Legal.Ignore.Material	= math.max(GetConVar("ace_legal_ignore_material"):GetInt(), 0)
	ACE.Legal.Ignore.Inertia	= math.max(GetConVar("ace_legal_ignore_inertia"):GetInt(), 0)
	ACE.Legal.Ignore.makesphere  = math.max(GetConVar("ace_legal_ignore_makesphere"):GetInt(), 0)
	ACE.Legal.Ignore.visclip	= math.max(GetConVar("ace_legal_ignore_visclip"):GetInt(), 0)
	ACE.Legal.Ignore.Parent	= math.max(GetConVar("ace_legal_ignore_parent"):GetInt(), 0)

	for _, ent in ipairs(ents.GetAll()) do
		if IsValid(ent) and ent.ACE_LegalArgs then
			ent.Legal = false
			ent.LegalIssues = "Legality policy changed"
			ent.NextLegalCheck = ACE.CurTime
		end
	end

end

cvars.AddChangeCallback("ace_legalcheck",ACE_LegalityCallBack)
cvars.AddChangeCallback("ace_legal_ignore_solid",ACE_LegalityCallBack)
cvars.AddChangeCallback("ace_legal_ignore_model",ACE_LegalityCallBack)
cvars.AddChangeCallback("ace_legal_ignore_mass",ACE_LegalityCallBack)
cvars.AddChangeCallback("ace_legal_ignore_material",ACE_LegalityCallBack)
cvars.AddChangeCallback("ace_legal_ignore_inertia",ACE_LegalityCallBack)
cvars.AddChangeCallback("ace_legal_ignore_makesphere",ACE_LegalityCallBack)
cvars.AddChangeCallback("ace_legal_ignore_visclip",ACE_LegalityCallBack)
cvars.AddChangeCallback("ace_legal_ignore_parent",ACE_LegalityCallBack)




ACE.Legal.Min		= 5	-- min seconds between checks --5
ACE.Legal.Max		= 25	-- max seconds between checks --25
ACE.Legal.Lockout	= 35	-- lockout time on not legal  --35
ACE.Legal.NextCheck  = function(_, Legal) return ACE.CurTime + (Legal and math.random(ACE.Legal.Min, ACE.Legal.Max) or ACE.Legal.Lockout) end

local function Contract(model, mass, inertia, parent)
	return function(ent)
		local modelValue = model and ent[model] or nil
		local massValue = mass and ent[mass] or nil
		return modelValue, massValue and math.Round(massValue, 2), inertia and ent[inertia] or nil, parent, true
	end
end

ACE.Legal.Contracts["acf_gun"] = Contract("Model", "Mass", "ModelInertia", false)
ACE.Legal.Contracts["acf_rack"] = Contract(nil, "Mass", "ModelInertia", false)
ACE.Legal.Contracts["acf_ammo"] = function(ent)
		-- EmptyMass is the real empty-crate requirement. Do not clamp it to the old
		-- 50,000 kg warning ceiling: that value is a limit, not an entity mass.
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

-- Every ACE/ACF entity has a declared fallback contract. Specialized entities above
-- override this with their exact configured mass/inertia/parent requirements.
local GenericContract = function(entity)
	local mass = entity.Mass or entity.Weight or entity.EmptyMass
	return entity:GetModel(), mass and math.Round(mass, 2) or nil, nil, true, false
end
for _, class in ipairs({
	"ace_bomb_aerial", "ace_bomb_barrel", "ace_bomb_satchel", "ace_explosive", "ace_explosive_prebuilt",
	"ace_flare", "ace_gforce_meter", "ace_grenade", "ace_mine", "ace_missile", "ace_scalability",
	"ace_slammine", "ace_smokegrenade", "ace_vheat_source", "ace_wind_sensor", "acf_explosive",
	"acf_fakecrate2", "acf_missile_to_rack", "acf_opticalcomputer"
}) do
	ACE.Legal.Contracts[class] = ACE.Legal.Contracts[class] or GenericContract
end


--[[
	checks if an ent meets the given requirements for legality
	MinInertia needs to be mass normalized (normalized=inertia/mass)
	ballistics doesn't check visclips on anything except prop_physics, so no need to check on acf ents
]]--

do

	local AllowedMaterials = {
	RHA = true,
	CHA = true,
	Alum = true
	}

	local ValidCollisionGroups = {
	[COLLISION_GROUP_NONE] = true,
	[COLLISION_GROUP_WORLD] = true,
	[COLLISION_GROUP_VEHICLE] = true
	}

	--TODO: remove unused functions
function ACE_CheckLegal(Ent, Model, MinMass, MinInertia, _, CanVisclip )

	local problems = {} --problems table definition
	if ACE.Legal.IsActivated == 0 then return #problems == 0, table.concat(problems, ", ") end

	-- check it exists
	if not ACE.Check( Ent ) then return false, "Invalid Ent" end

	local physobj = Ent:GetPhysicsObject()

	-- check if physics is valid
	if not IsValid(physobj) then return false, "Invalid Physics" end


	-- make sure traces can hit it (fade door, propnotsolid)
	if ACE.Legal.Ignore.Solid <= 0  and not Ent:IsSolid() then
		table.insert(problems,"Not solid")
	end

	-- check if the model matches
	if Model ~= nil and ACE.Legal.Ignore.Model <= 0 and Ent:GetModel() ~= Model then
		table.insert(problems,"Wrong model")
	end

	-- check mass
	if ACE.Legal.Ignore.Mass <= 0 then

		--Lets assume that input minmass is also rounded like here.
		local rawMass = tonumber(physobj:GetMass()) or 0
		if rawMass <= 0 or rawMass ~= rawMass or rawMass == math.huge or rawMass == -math.huge then
			table.insert(problems, "Invalid mass")
			rawMass = 1
		end
		local CMass = math.Round(rawMass, 2)

		if MinMass ~= nil and CMass < MinMass then
			table.insert(problems,"Under min mass")
		end

	end

	-- check material
	-- Allowed materials: rha, cast and aluminum
	if ACE.Legal.Ignore.Material <= 0 then

		local material = Ent.ACF.Material or "RHA"

		if not AllowedMaterials[material] then
			table.insert(problems,"Material not legal")
		end
	end

	-- check inertia components
	if ACE.Legal.Ignore.Inertia <= 0 and MinInertia ~= nil then
		local mass = tonumber(physobj:GetMass()) or 0
		local rawInertia = physobj:GetInertia()
		local inertia = mass > 0 and rawInertia / mass or Vector(math.huge, math.huge, math.huge)
		if inertia.x ~= inertia.x or inertia.y ~= inertia.y or inertia.z ~= inertia.z
			or (inertia.x < MinInertia.x) or (inertia.y < MinInertia.y) or (inertia.z < MinInertia.z) then
			table.insert(problems,"Under min inertia")
		end
	end

	-- check makesphere
	if ACE.Legal.Ignore.makesphere <= 0 and physobj:GetVolume() == nil then
		table.insert(problems,"Has makesphere")
	end

	-- check for clips
	if ACE.Legal.Ignore.visclip <= 0 and not CanVisclip and (Ent.ClipData ~= nil) and (#Ent.ClipData > 0) then
		table.insert(problems,"Has visclip")
	end

	-- check for bad collision groups
	if ACE.Legal.Ignore.Solid <= 0 and not ValidCollisionGroups[Ent:GetCollisionGroup()] then
		table.insert(problems, "Bad collision group")
	end

	-- A parent is optional for a root build, but a present physical parent must be legal.
	if ACE.Legal.Ignore.Parent <= 0 and _ then
		local parent = ACE_GetPhysicalParent and ACE_GetPhysicalParent(Ent, true)
		if Ent.ACEPhysicalParentIssue then
			table.insert(problems, Ent.ACEPhysicalParentIssue)
		elseif IsValid(parent) and parent ~= Ent and parent.Legal == false then
			table.insert(problems, "Illegal physical parent")
		end
	end

	-- legal if number of problems is 0
	return #problems == 0, table.concat(problems, ", ")

	end
end

function ACE.InvalidateLegal(ent, reason)
	if not IsValid(ent) then return end
	ent.Legal = false
	ent.LegalIssues = reason or "Legality invalidated"
	ent.NextLegalCheck = ACE.CurTime
	BumpOperationalVersion()
end

function ACE.WithMutationScope(ent, reason, callback)
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

local function IsManagedLegalEntity(ent)
	if not IsValid(ent) or not ent.ACE_LegalArgs then return false end
	local class = ent:GetClass() or ""
	return class:sub(1, 4) == "acf_" or class:sub(1, 4) == "ace_"
end

do
	local ENTITY = FindMetaTable("Entity")
	ACE._OldEntitySetModel = ACE._OldEntitySetModel or ENTITY.SetModel
	local OldSetModel = ACE._OldEntitySetModel
	function ENTITY:SetModel(model)
		if IsManagedLegalEntity(self) and not ACE.IsMutationScoped(self) and self.Model and model ~= self.Model then
			ACE.InvalidateLegal(self, "External model change rejected")
			return false
		end
		local previousModel = self:GetModel()
		local result = OldSetModel(self, model)
		if IsManagedLegalEntity(self) and not ACE.IsMutationScoped(self) and previousModel ~= model then
			ACE.InvalidateLegal(self, "Model changed")
		end
		return result
	end
end

do
	local ENTITY = FindMetaTable("Entity")
	local function InstallMutationDetour(name, reason)
		local oldName = "_OldEntity" .. name
		ACE[oldName] = ACE[oldName] or ENTITY[name]
		local old = ACE[oldName]
		if not old then return end

		ENTITY[name] = function(self, ...)
			local value = ...
			-- Repeating an already-applied state during entity initialization or paste
			-- is not an external legality mutation.
			if IsManagedLegalEntity(self) and name == "SetSolid" and self.GetSolid
				and self:GetSolid() == value then
				return true
			end
			if IsManagedLegalEntity(self) and name == "SetNotSolid" and not self:IsSolid() then
				return true
			end
			if IsManagedLegalEntity(self) and name == "SetParent" and self:GetParent() == value then
				return true
			end
			if IsManagedLegalEntity(self) and not ACE.IsMutationScoped(self) then
				ACE.InvalidateLegal(self, reason .. " rejected")
				return false
			end
			local result = old(self, ...)
			return result
		end
	end

	InstallMutationDetour("PhysicsInit", "Physics rebuilt")
	InstallMutationDetour("PhysicsInitSphere", "Spherical physics changed")
	InstallMutationDetour("PhysicsInitMultiConvex", "Convex physics changed")
	InstallMutationDetour("SetCollisionBounds", "Collision bounds changed")
	InstallMutationDetour("SetNotSolid", "Solidity changed")
	InstallMutationDetour("SetSolid", "Solidity changed")
	InstallMutationDetour("SetNoDraw", "Visibility changed")
InstallMutationDetour("SetParent", "Physical parent changed")
end

-- AdvDupe2 applies saved parents directly during its paste queue. Fully-enforced legality
-- correctly rejects that external-looking mutation, but the result is a partially parented
-- dupe: ACE/ACF children can be left at their paste position in the sky. Repair every saved
-- parent link after the queue completes through the same narrowly-scoped ACE mutation gate.
local function RestoreAdvDupeParents(dupe)
	if not istable(dupe) or not istable(dupe.EntityList) or not istable(dupe.CreatedEntities) then return end

	for sourceId, source in pairs(dupe.EntityList) do
		local parentId = istable(source) and source.BuildDupeInfo and source.BuildDupeInfo.DupeParentID
		local child = dupe.CreatedEntities[sourceId] or dupe.CreatedEntities[tostring(sourceId)]
		local parent = parentId and (dupe.CreatedEntities[parentId] or dupe.CreatedEntities[tostring(parentId)])
		if parentId and IsValid(child) and IsValid(parent) and child:GetParent() ~= parent then
			ACE.WithMutationScope(child, "advdupe-parent-restore", function()
				child:SetParent(parent)
			end)
		end
	end
end

hook.Add("AdvDupe_FinishPasting", "ACE Restore Enforced Parents", function(data)
	local dupe = istable(data) and (data[1] or data) or nil
	if not istable(dupe) then return end

	local player = dupe.Player
	if IsValid(player) and player.GetInfo then
		local setting = player:GetInfo("advdupe2_paste_parents")
		if setting ~= nil and setting ~= "" and not tobool(setting) then return end
	end

	-- AdvDupe can finish entity callbacks after this hook. Retry once on the next
	-- tick so gun/rack children are present before the enforced SetParent call.
	RestoreAdvDupeParents(dupe)
	timer.Simple(0, function()
		RestoreAdvDupeParents(dupe)
		hook.Run("ACE_AdvDupeParentsRestored", dupe)
	end)
end)

do
	local ENTITY = FindMetaTable("Entity")
	ACE._OldEntitySetCollisionGroup = ACE._OldEntitySetCollisionGroup or ENTITY.SetCollisionGroup
	local OldSetCollisionGroup = ACE._OldEntitySetCollisionGroup
	local AllowedGroups = {
		[COLLISION_GROUP_NONE] = true,
		[COLLISION_GROUP_WORLD] = true,
		[COLLISION_GROUP_VEHICLE] = true,
	}
	function ENTITY:SetCollisionGroup(group)
		if IsManagedLegalEntity(self) and not ACE.IsMutationScoped(self) and not AllowedGroups[group] then
			ACE.InvalidateLegal(self, "External collision group change rejected")
			return false
		end
		local result = OldSetCollisionGroup(self, group)
		return result
	end
end

-- Authoritative use-site gate. Periodic checks keep overlays current, but weapon activation
-- must re-check the live entity so a mutation cannot fire during the scan interval.
function ACE.RequireLegal(ent, model, minMass, minInertia, requiresParent, canVisclip)
	if IsValid(ent) then
		ent.ACE_LegalArgs = { model, minMass, minInertia, requiresParent, canVisclip }
	end

	local legal, issues = ACE_CheckLegal(ent, model, minMass, minInertia, requiresParent, canVisclip)
	if istable(legal) then
		local result = legal
		legal = false
		issues = table.concat(result.Problems or { "Invalid legality result" }, ", ")
	end

	legal = legal == true
	if IsValid(ent) then
		if ent.Legal ~= legal then
			BumpOperationalVersion()
		end
		ent.Legal = legal
		ent.LegalIssues = issues or ""
		ent.NextLegalCheck = ACE.Legal.NextCheck(legal)
		if legal then
			local phys = ent:GetPhysicsObject()
			ent.ACE_LegalFingerprint = {
				model = ent:GetModel(), material = ent.ACF and ent.ACF.Material,
				mass = IsValid(phys) and phys:GetMass() or nil, solid = ent:IsSolid(),
				collision = ent:GetCollisionGroup(), clips = ent.ClipData and #ent.ClipData or 0,
				parent = ACE_GetPhysicalParent and ACE_GetPhysicalParent(ent, true) or nil,
				parentLegal = ent.acfphysparent and ent.acfphysparent.Legal,
				parentIssue = ent.ACEPhysicalParentIssue
			}
		else
			ent.ACE_LegalFingerprint = nil
		end
		if not legal and ent.Active and ent.SetActive then ent:SetActive(false) end
	end

	return legal, issues or ""
end

-- Revalidate an entity at an operational boundary using the same contract as its last check.
-- The fallback covers entities that are active before their first periodic Think.
function ACE.RequireEntityLegal(ent)
	if not IsValid(ent) then return false, "Invalid Ent" end

	-- Points limits are operational restrictions, not advisory chat output. Resolve the current
	-- contraption total at the same boundary that gates firing/activation so a stale periodic
	-- legality scan cannot be used to operate an over-limit entity.
	local pointVersion = ACE.PointsOperationalVersion or 0
	local pointsLimitEnforced = ACE.PointsLimitEnforced ~= false
	local pointCache = ent.ACEPointsOperationalCache
	local pointIssue
	if pointCache and pointCache.Version == pointVersion and pointCache.Limit == ACE.PointsLimit
		and pointCache.Enforced == pointsLimitEnforced then
		pointIssue = pointCache.Issue
	elseif not pointsLimitEnforced then
		-- Keep the point model and advisory warnings active, but allow servers to
		-- opt out of making the points limit an operational gate.
		ent.ACEPointsOperationalCache = {
			Version = pointVersion, Limit = ACE.PointsLimit,
			Enforced = false, Issue = nil
		}
	else
		local pointCons = {}
		local pointQueue = {}
		local pointSeen = {}
		local pointMemberQueue = {}
		local pointMemberSeen = {}
		local function addPointCon(con)
			if not con or pointSeen[con] then return end
			pointSeen[con] = true
			pointQueue[#pointQueue + 1] = con
		end
		local function addPointEntity(entity)
			if not IsValid(entity) then return end
			if not pointMemberSeen[entity] then
				pointMemberSeen[entity] = true
				pointMemberQueue[#pointMemberQueue + 1] = entity
			end
			addPointCon(ACE.GetContraptionFromEntity and ACE.GetContraptionFromEntity(entity))
			addPointCon(ACE.GetWeaponAnchorContraption and ACE.GetWeaponAnchorContraption(entity))
		end

		addPointEntity(ent)
		local conIndex = 1
		local memberIndex = 1
		while conIndex <= #pointQueue do
			local con = pointQueue[conIndex]
			conIndex = conIndex + 1
			pointCons[#pointCons + 1] = con
			if ACE.EnsureContraptionPoints then ACE.EnsureContraptionPoints(con, nil, false) end

			for key, value in pairs(con.ents or {}) do
				local member = value == true and key or value
				if IsValid(member) then
					addPointEntity(member)
				end
			end

			while memberIndex <= #pointMemberQueue do
				local member = pointMemberQueue[memberIndex]
				memberIndex = memberIndex + 1
				local class = member:GetClass()
				if class == "acf_gun" or class == "acf_rack" then
					for _, crate in pairs(member.AmmoLink or {}) do addPointEntity(crate) end
					for _, crew in pairs(member.CrewLink or {}) do addPointEntity(crew) end
				elseif class == "acf_ammo" or class == "ace_crewseat_gunner" or class == "ace_crewseat_loader" then
					for _, linked in pairs(member.Master or {}) do addPointEntity(linked) end
				end
			end
		end

		if #pointCons > 0 then
			local limit = tonumber(ACE.PointsLimit) or math.huge
			local points = 0
			for _, con in ipairs(pointCons) do points = points + (tonumber(con.ACEPoints) or 0) end
			if points > limit then
				pointIssue = string.format("Linked contraption group over points limit (%d / %d)", math.ceil(points), math.ceil(limit))
			end
		end
		ent.ACEPointsOperationalCache = {
			Version = pointVersion, Limit = ACE.PointsLimit,
			Enforced = true, Issue = pointIssue
		}
	end

	if pointIssue then return false, pointIssue end

	local args = ent.ACE_LegalArgs
	if args then
		if ent.Legal == true and ACE.CurTime < (ent.NextLegalCheck or 0) then
			local fingerprint = ent.ACE_LegalFingerprint
			local phys = ent:GetPhysicsObject()
			local unchanged = fingerprint and fingerprint.model == ent:GetModel()
				and fingerprint.material == (ent.ACF and ent.ACF.Material)
				and fingerprint.mass == (IsValid(phys) and phys:GetMass() or nil)
				and fingerprint.solid == ent:IsSolid()
				and fingerprint.collision == ent:GetCollisionGroup()
				and fingerprint.clips == (ent.ClipData and #ent.ClipData or 0)
				and fingerprint.parent == (ACE_GetPhysicalParent and ACE_GetPhysicalParent(ent, true) or nil)
				and fingerprint.parentLegal == (ent.acfphysparent and ent.acfphysparent.Legal)
				and fingerprint.parentIssue == ent.ACEPhysicalParentIssue
			if unchanged then return true, ent.LegalIssues or "" end
			ACE.InvalidateLegal(ent, "Legality state changed")
		end
		if ent.Legal == false and ACE.CurTime < (ent.NextLegalCheck or 0) then return false, ent.LegalIssues or "Legality lockout" end
		return ACE.RequireLegal(ent, unpack(args))
	end

	local class = ent:GetClass()
	local contract = ACE.Legal.Contracts[class]
	if not contract then
		contract = GenericContract
	end
	local legal, issues = ACE.RequireLegal(ent, contract(ent))
	if not legal and ent.SetActive and ent.Active then ent:SetActive(false) end
	return legal, issues
end
