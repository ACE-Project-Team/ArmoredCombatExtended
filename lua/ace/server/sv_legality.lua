
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

ACE.Legal.IsActivated		= math.max(GetConVar("ace_legalcheck"):GetInt(), 0)

ACE.Legal.Ignore.Solid	= math.max(GetConVar("ace_legal_ignore_solid"):GetInt(), 0)
ACE.Legal.Ignore.Model	= math.max(GetConVar("ace_legal_ignore_model"):GetInt(), 0)
ACE.Legal.Ignore.Mass		= math.max(GetConVar("ace_legal_ignore_mass"):GetInt(), 0)
ACE.Legal.Ignore.Material	= math.max(GetConVar("ace_legal_ignore_material"):GetInt(), 0)
ACE.Legal.Ignore.Inertia	= math.max(GetConVar("ace_legal_ignore_inertia"):GetInt(), 0)
ACE.Legal.Ignore.makesphere  = math.max(GetConVar("ace_legal_ignore_makesphere"):GetInt(), 0)
ACE.Legal.Ignore.visclip	= math.max(GetConVar("ace_legal_ignore_visclip"):GetInt(), 0)
ACE.Legal.Ignore.Parent	= math.max(GetConVar("ace_legal_ignore_parent"):GetInt(), 0)

function ACE.LegalityCallBack()

	ACE.Legal.IsActivated		= math.max(GetConVar("ace_legalcheck"):GetInt(), 0)

	ACE.Legal.Ignore.Solid	= math.max(GetConVar("ace_legal_ignore_solid"):GetInt(), 0)
	ACE.Legal.Ignore.Model	= math.max(GetConVar("ace_legal_ignore_model"):GetInt(), 0)
	ACE.Legal.Ignore.Mass		= math.max(GetConVar("ace_legal_ignore_mass"):GetInt(), 0)
	ACE.Legal.Ignore.Material	= math.max(GetConVar("ace_legal_ignore_material"):GetInt(), 0)
	ACE.Legal.Ignore.Inertia	= math.max(GetConVar("ace_legal_ignore_inertia"):GetInt(), 0)
	ACE.Legal.Ignore.makesphere  = math.max(GetConVar("ace_legal_ignore_makesphere"):GetInt(), 0)
	ACE.Legal.Ignore.visclip	= math.max(GetConVar("ace_legal_ignore_visclip"):GetInt(), 0)
	ACE.Legal.Ignore.Parent	= math.max(GetConVar("ace_legal_ignore_parent"):GetInt(), 0)

end

cvars.AddChangeCallback("ace_legalcheck",ACE.LegalityCallBack)
cvars.AddChangeCallback("ace_legal_ignore_solid",ACE.LegalityCallBack)
cvars.AddChangeCallback("ace_legal_ignore_model",ACE.LegalityCallBack)
cvars.AddChangeCallback("ace_legal_ignore_mass",ACE.LegalityCallBack)
cvars.AddChangeCallback("ace_legal_ignore_material",ACE.LegalityCallBack)
cvars.AddChangeCallback("ace_legal_ignore_inertia",ACE.LegalityCallBack)
cvars.AddChangeCallback("ace_legal_ignore_makesphere",ACE.LegalityCallBack)
cvars.AddChangeCallback("ace_legal_ignore_visclip",ACE.LegalityCallBack)
cvars.AddChangeCallback("ace_legal_ignore_parent",ACE.LegalityCallBack)




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
	function ACE.CheckLegal(Ent, Model, MinMass, MinInertia, _, CanVisclip )

	local problems = {} --problems table definition
	if ACE.Legal.IsActivated == 0 then return #problems == 0, table.concat(problems, ", ") end

	-- check it exists
	if not ACE.Check( Ent ) then return { Legal = false, Problems = {"Invalid Ent"} } end

	local physobj = Ent:GetPhysicsObject()

	-- check if physics is valid
	if not IsValid(physobj) then return { Legal = false, Problems = {"Invalid Physics"} } end


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
		local CMass = math.Round(physobj:GetMass(),2)

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
		local inertia = physobj:GetInertia() / physobj:GetMass()
		if (inertia.x < MinInertia.x) or (inertia.y < MinInertia.y) or (inertia.z < MinInertia.z) then
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

	-- legal if number of problems is 0
	return #problems == 0, table.concat(problems, ", ")

	end
end
