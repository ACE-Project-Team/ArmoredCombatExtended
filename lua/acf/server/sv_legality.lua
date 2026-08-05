
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
		local parent = ACE_GetPhysicalParent and ACE_GetPhysicalParent(Ent)
		if IsValid(parent) and parent ~= Ent and parent.Legal == false then
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
		if IsManagedLegalEntity(self) and not ACE.IsMutationScoped(self) then
			ACE.InvalidateLegal(self, "Collision group changed")
		end
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
		legal = false
		issues = table.concat(legal.Problems or { "Invalid legality result" }, ", ")
	end

	legal = legal == true
	if IsValid(ent) then
		ent.Legal = legal
		ent.LegalIssues = issues or ""
		ent.NextLegalCheck = ACE.Legal.NextCheck(legal)
		if not legal and ent.Active and ent.SetActive then ent:SetActive(false) end
	end

	return legal, issues or ""
end

-- Revalidate an entity at an operational boundary using the same contract as its last check.
-- The fallback covers entities that are active before their first periodic Think.
function ACE.RequireEntityLegal(ent)
	if not IsValid(ent) then return false, "Invalid Ent" end

	local args = ent.ACE_LegalArgs
	if args then
		return ACE.RequireLegal(ent, unpack(args))
	end

	local class = ent:GetClass()
	local model = ent.Model
	local mass = ent.Weight or ent.EmptyMass or ent.Mass
	local inertia = ent.ModelInertia
	if class == "acf_ammo" and mass then mass = math.min(math.Round(mass, 2), 50000) end
	local requiresParent = class ~= "acf_gun" and class ~= "acf_rack"

	local legal, issues = ACE.RequireLegal(ent, model, mass and math.Round(mass, 2) or nil, inertia, requiresParent, true)
	if not legal and ent.SetActive and ent.Active then ent:SetActive(false) end
	return legal, issues
end
