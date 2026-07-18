
--[[
	set up to provide a random, fairly low cost legality check that discourages trying to game legality checking
	with a hard to predict check time and punishing lockout time
	usage:
	Ent.Legal, Ent.LegalIssues = ACE.CheckLegal(Ent, Model, MinMass, MinInertia, NeedsGateParent, CanVisclip )
	Ent.NextLegalCheck = ACF.LegalSettings:NextCheck(Ent.Legal)
]]

ACF = ACF or {}

ACF.Legal = {}
ACF.Legal.Ignore = {}

ACF.Legal.IsActivated		= math.max(GetConVar("ace_legalcheck"):GetInt(), 0)

ACF.Legal.Ignore.Solid	= math.max(GetConVar("ace_legal_ignore_solid"):GetInt(), 0)
ACF.Legal.Ignore.Model	= math.max(GetConVar("ace_legal_ignore_model"):GetInt(), 0)
ACF.Legal.Ignore.Mass		= math.max(GetConVar("ace_legal_ignore_mass"):GetInt(), 0)
ACF.Legal.Ignore.Material	= math.max(GetConVar("ace_legal_ignore_material"):GetInt(), 0)
ACF.Legal.Ignore.Inertia	= math.max(GetConVar("ace_legal_ignore_inertia"):GetInt(), 0)
ACF.Legal.Ignore.makesphere  = math.max(GetConVar("ace_legal_ignore_makesphere"):GetInt(), 0)
ACF.Legal.Ignore.visclip	= math.max(GetConVar("ace_legal_ignore_visclip"):GetInt(), 0)
ACF.Legal.Ignore.Parent	= math.max(GetConVar("ace_legal_ignore_parent"):GetInt(), 0)

function ACE.LegalityCallBack()

	ACF.Legal.IsActivated		= math.max(GetConVar("ace_legalcheck"):GetInt(), 0)

	ACF.Legal.Ignore.Solid	= math.max(GetConVar("ace_legal_ignore_solid"):GetInt(), 0)
	ACF.Legal.Ignore.Model	= math.max(GetConVar("ace_legal_ignore_model"):GetInt(), 0)
	ACF.Legal.Ignore.Mass		= math.max(GetConVar("ace_legal_ignore_mass"):GetInt(), 0)
	ACF.Legal.Ignore.Material	= math.max(GetConVar("ace_legal_ignore_material"):GetInt(), 0)
	ACF.Legal.Ignore.Inertia	= math.max(GetConVar("ace_legal_ignore_inertia"):GetInt(), 0)
	ACF.Legal.Ignore.makesphere  = math.max(GetConVar("ace_legal_ignore_makesphere"):GetInt(), 0)
	ACF.Legal.Ignore.visclip	= math.max(GetConVar("ace_legal_ignore_visclip"):GetInt(), 0)
	ACF.Legal.Ignore.Parent	= math.max(GetConVar("ace_legal_ignore_parent"):GetInt(), 0)

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




ACF.Legal.Min		= 5	-- min seconds between checks --5
ACF.Legal.Max		= 25	-- max seconds between checks --25
ACF.Legal.Lockout	= 35	-- lockout time on not legal  --35
ACF.Legal.NextCheck  = function(_, Legal) return ACF.CurTime + (Legal and math.random(ACF.Legal.Min, ACF.Legal.Max) or ACF.Legal.Lockout) end


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
	if ACF.Legal.IsActivated == 0 then return #problems == 0, table.concat(problems, ", ") end

	-- check it exists
	if not ACE.Check( Ent ) then return { Legal = false, Problems = {"Invalid Ent"} } end

	local physobj = Ent:GetPhysicsObject()

	-- check if physics is valid
	if not IsValid(physobj) then return { Legal = false, Problems = {"Invalid Physics"} } end


	-- make sure traces can hit it (fade door, propnotsolid)
	if ACF.Legal.Ignore.Solid <= 0  and not Ent:IsSolid() then
		table.insert(problems,"Not solid")
	end

	-- check if the model matches
	if Model ~= nil and ACF.Legal.Ignore.Model <= 0 and Ent:GetModel() ~= Model then
		table.insert(problems,"Wrong model")
	end

	-- check mass
	if ACF.Legal.Ignore.Mass <= 0 then

		--Lets assume that input minmass is also rounded like here.
		local CMass = math.Round(physobj:GetMass(),2)

		if MinMass ~= nil and CMass < MinMass then
			table.insert(problems,"Under min mass")
		end

	end

	-- check material
	-- Allowed materials: rha, cast and aluminum
	if ACF.Legal.Ignore.Material <= 0 then

		local material = Ent.ACF.Material or "RHA"

		if not AllowedMaterials[material] then
			table.insert(problems,"Material not legal")
		end
	end

	-- check inertia components
	if ACF.Legal.Ignore.Inertia <= 0 and MinInertia ~= nil then
		local inertia = physobj:GetInertia() / physobj:GetMass()
		if (inertia.x < MinInertia.x) or (inertia.y < MinInertia.y) or (inertia.z < MinInertia.z) then
			table.insert(problems,"Under min inertia")
		end
	end

	-- check makesphere
	if ACF.Legal.Ignore.makesphere <= 0 and physobj:GetVolume() == nil then
		table.insert(problems,"Has makesphere")
	end

	-- check for clips
	if ACF.Legal.Ignore.visclip <= 0 and not CanVisclip and (Ent.ClipData ~= nil) and (#Ent.ClipData > 0) then
		table.insert(problems,"Has visclip")
	end

	-- check for bad collision groups
	if ACF.Legal.Ignore.Solid <= 0 and not ValidCollisionGroups[Ent:GetCollisionGroup()] then
		table.insert(problems, "Bad collision group")
	end

	-- legal if number of problems is 0
	return #problems == 0, table.concat(problems, ", ")

	end
end
