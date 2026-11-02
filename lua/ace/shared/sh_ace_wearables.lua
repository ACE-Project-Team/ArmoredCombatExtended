-- ACE wearable armor: a helmet and a plate carrier, bonemerged onto any playermodel with the ValveBiped skeleton.
-- Wearing one adds body armor layers to ACE's ACE_GetBodyArmor hook, so ACE bullets resolve against it.
-- Each wearable wears down by the energy it absorbs, gets weaker as it wears, and breaks off when it runs out.
-- Test command (admins): ace_wear helmet | vest | all | none

AddCSLuaFile()

ACE = ACE or {}
ACE.Wearables = ACE.Wearables or {}
local Wearables = ACE.Wearables

--- Wearable slots. Bone is the ValveBiped bone the model is skinned to, used to skip playermodels without it.
--- Fit names the bones that are stretched to the wearer's build, and how: "Torso" or "Head".
--- Layers are the armor it puts over each hitgroup: ACE armor plates { Material, Armour (mm) }, outermost first, which
--- ACE resolves like prop armor at the angle the bullet meets the wearable's surface.
--- Shape is what a bullet's path is checked against ("Plates" or "Shell"); Coverage is only the chance it is hit
--- when ACE doesn't say where the bullet hit (a driver shot through a seat).
--- Durability is the energy in J it absorbs before it breaks, from stopped bullets and from ones it only slowed.
Wearables.Slots = {
	helmet = {
		Model = "models/ace/wearables/helmet.mdl",
		Bone  = "ValveBiped.Bip01_Head1",
		Fit   = { ["ValveBiped.Bip01_Head1"] = "Head" },
		Shape = "Shell",
		-- About six stopped pistol rounds, or a handful of rifle rounds punching through
		Durability = 3000,
		BreakSound = "physics/plastic/plastic_box_break2.wav",
		Layers = {
			-- Aramid shell, about 5.4 mm RHA square on: stops pistol rounds, not rifle rounds unless they glance.
			-- The face and the high cut over the ears are open.
			[HITGROUP_HEAD] = { Coverage = 0.7, { Material = "Aramid", Armour = 10 } },
		},
	},
	vest = {
		Model = "models/ace/wearables/vest.mdl",
		Bone  = "ValveBiped.Bip01_Spine4",
		Fit   = { ["ValveBiped.Bip01_Spine2"] = "Torso", ["ValveBiped.Bip01_Spine4"] = "Torso" },
		Shape = "Plates",
		-- Stops about five 5.56 rounds before it is too worn to; a 12.7 that gets through takes most of it in one hit
		Durability = 15000,
		BreakSound = "physics/concrete/concrete_break2.wav",
		Layers = {
			-- Medium SAPI plates front and back: a ceramic strike face on an aramid backer, about 9.3 mm RHA square
			-- on, which stops rifle ball up to 7.62x51 but not 7.62x54R or .338. They cover most of the chest; the
			-- cummerbund leaves the sides soft.
			[HITGROUP_CHEST]   = { Coverage = 0.8, { Material = "Cer", Armour = 3.5 }, { Material = "Aramid", Armour = 4 } },
			-- The plates end above the navel
			[HITGROUP_STOMACH] = { Coverage = 0.45, { Material = "Cer", Armour = 3.5 }, { Material = "Aramid", Armour = 4 } },
		},
	},
}

local function NWKey(Slot)
	return "ACE_Wear_" .. Slot
end

local function NWSkinKey(Slot)
	return "ACE_WearSkin_" .. Slot
end

local function NWColorKey(Slot)
	return "ACE_WearColor_" .. Slot
end

local function NWBodygroupsKey(Slot)
	return "ACE_WearBodygroups_" .. Slot
end

local function NWHealthKey(Slot)
	return "ACE_WearHealth_" .. Slot
end

--- Whether a player is wearing the wearable in a slot.
-- @param Ply Player
-- @param Slot string Slot id from ACE.Wearables.Slots
-- @return boolean
function Wearables.IsWearing(Ply, Slot)
	return Ply:GetNW2Bool(NWKey(Slot), false)
end

--- How much of a worn wearable's durability is left.
-- @param Ply Player
-- @param Slot string Slot id from ACE.Wearables.Slots
-- @return number 0-1, 0 when it is not worn
function Wearables.GetHealth(Ply, Slot)
	if not Wearables.IsWearing(Ply, Slot) then return 0 end
	return Ply:GetNW2Float(NWHealthKey(Slot), 1)
end

--- Share of its thickness a wearable keeps at a health, by ACE's rule for a damaged armor plate: 75% at half health,
-- 50% just before it breaks.
-- @param Health number 0-1
-- @return number
function Wearables.ProtectionScale(Health)
	return 0.5 + Health / 2
end

-- Fitting to the wearer's build. The models are made on male_07, so every other playermodel is measured from its
-- mesh and the fitted bones are stretched until the armor sits on it the way it sits on male_07.
local RefModel   = "models/player/group01/male_07.mdl"
local TorsoBones = {
	["ValveBiped.Bip01_Pelvis"] = true,
	["ValveBiped.Bip01_Spine"]  = true,
	["ValveBiped.Bip01_Spine1"] = true,
	["ValveBiped.Bip01_Spine2"] = true,
	["ValveBiped.Bip01_Spine4"] = true,
}
local Meshes   = {} -- [Model] = { Verts = { { Pos, Bone } }, Binds = { [Bone] = Matrix } } or false
local FitCache = {} -- [Model .. Slot] = { [Bone] = Matrix }

local function BoneNames(Model)
	local Ent = CLIENT and ClientsideModel(Model) or ents.Create("prop_dynamic")
	if not IsValid(Ent) then return end
	if SERVER then Ent:SetModel(Model) end

	local Names = {}
	for I = 0, Ent:GetBoneCount() - 1 do
		Names[I] = Ent:GetBoneName(I)
	end

	Ent:Remove()
	return Names
end

-- A model's vertices with the bone each is mostly skinned to, and each bone's bind pose (model to bone space)
local function LoadMesh(Model)
	if Meshes[Model] ~= nil then return Meshes[Model] end

	local Parts, Binds = util.GetModelMeshes(Model)
	local Names = Parts and Binds and BoneNames(Model)
	if not Names then
		Meshes[Model] = false
		return false
	end

	local Verts = {}
	for _, Part in ipairs(Parts) do
		for _, Vert in ipairs(Part.verticies) do
			local Bone, Weight = nil, 0
			for _, Link in ipairs(Vert.weights) do
				if Link.weight > Weight then Bone, Weight = Link.bone, Link.weight end
			end
			if Bone then Verts[#Verts + 1] = { Pos = Vert.pos, Bone = Names[Bone] } end
		end
	end

	local BindsByName = {}
	for I, Name in pairs(Names) do
		if Binds[I] then BindsByName[Name] = Binds[I].matrix end
	end

	Meshes[Model] = { Verts = Verts, Binds = BindsByName }
	return Meshes[Model]
end

-- Positions in one bone's frame of the vertices skinned to a bone in Keep. x runs along the bone and z to the side;
-- y points to the front on the spine and to the back on the head.
local function LocalVerts(Mesh, BoneName, Keep)
	local Bind, Out = Mesh.Binds[BoneName], {}
	if not Bind then return Out end

	for _, Vert in ipairs(Mesh.Verts) do
		if Keep[Vert.Bone] then Out[#Out + 1] = Bind * Vert.Pos end
	end

	return Out
end

-- Percentiles cut off stray vertices (a buckle, a strap end) that would otherwise set the size
local function Percentile(Points, Axis, P)
	local Values = {}
	for I, Point in ipairs(Points) do
		Values[I] = Point[Axis]
	end
	table.sort(Values)

	return Values[math.Clamp(math.Round(#Values * P), 1, #Values)]
end

-- Size of a body where the wearable covers it. Nil when too little of the mesh is there to measure.
local function Measure(Body, Wear, BoneName, Kind)
	local Own = LocalVerts(Wear, BoneName, { [BoneName] = true })
	if #Own == 0 then return end

	local Points = {}
	if Kind == "Torso" then
		-- The slice of the chest the plates cover on this bone
		local Lo, Hi = Percentile(Own, "x", 0.02), Percentile(Own, "x", 0.98)
		for _, Point in ipairs(LocalVerts(Body, BoneName, TorsoBones)) do
			if Point.x >= Lo and Point.x <= Hi then Points[#Points + 1] = Point end
		end
	else
		-- The head above the helmet's rim
		local Rim = Percentile(Own, "x", 0)
		for _, Point in ipairs(LocalVerts(Body, BoneName, { [BoneName] = true })) do
			if Point.x >= Rim then Points[#Points + 1] = Point end
		end
		Points.Rim = Rim
	end
	if #Points < 20 then return end

	return {
		Rim = Points.Rim,
		Top = Percentile(Points, "x", 0.98),
		YLo = Percentile(Points, "y", 0.02), YHi = Percentile(Points, "y", 0.98),
		ZLo = Percentile(Points, "z", 0.02), ZHi = Percentile(Points, "z", 0.98),
	}
end

-- Bone space stretch: Offset + Scale * position
local function FitMatrix(Scale, Offset)
	local Fit = Matrix()
	Fit:SetTranslation(Offset)
	Fit:Scale(Scale)
	return Fit
end

local function FitBone(Ref, Body, Kind)
	-- Side to side it is centered on the body, the same on both
	local SZ = math.Clamp((Body.ZHi - Body.ZLo) / (Ref.ZHi - Ref.ZLo), 0.85, 1.5)
	local OZ = (Body.ZHi + Body.ZLo - SZ * (Ref.ZHi + Ref.ZLo)) / 2

	if Kind == "Torso" then
		-- The front plate rides on the chest. The back plate follows the back, but not out over a backpack.
		local Back = math.max(Body.YLo, Ref.YLo - 1.5)
		local SY = math.Clamp((Body.YHi - Back) / (Ref.YHi - Ref.YLo), 0.85, 1.5)
		return FitMatrix(Vector(1, SY, SZ), Vector(0, Body.YHi - SY * Ref.YHi, OZ))
	end

	-- The rim stays where it is and the crown grows to the top of the head. The brow stays and the back grows
	-- to the back of the head, so masks and visors in front of the face don't push the helmet forward.
	local SX = math.Clamp((Body.Top - Ref.Rim) / (Ref.Top - Ref.Rim), 0.9, 1.5)
	local SY = math.Clamp((Body.YHi - Ref.YLo) / (Ref.YHi - Ref.YLo), 0.9, 1.5)
	return FitMatrix(Vector(SX, SY, SZ), Vector(Ref.Rim * (1 - SX), Ref.YLo * (1 - SY), OZ))
end

--- Bone space stretch for each fitted bone of a wearable on a playermodel. Bones without one are worn as they are.
-- @param Model string Playermodel path
-- @param Slot string Slot id from ACE.Wearables.Slots
-- @return table { [bone name] = Matrix }, empty for male_07 and for models it can't measure
function Wearables.GetFit(Model, Slot)
	local Key = Model .. Slot
	if FitCache[Key] then return FitCache[Key] end

	local Data, Fits = Wearables.Slots[Slot], {}
	FitCache[Key] = Fits
	if Model == RefModel then return Fits end

	local Ref, Body, Wear = LoadMesh(RefModel), LoadMesh(Model), LoadMesh(Data.Model)
	if not (Ref and Body and Wear) then return Fits end

	for BoneName, Kind in pairs(Data.Fit) do
		local RefSize, BodySize = Measure(Ref, Wear, BoneName, Kind), Measure(Body, Wear, BoneName, Kind)
		if RefSize and BodySize then Fits[BoneName] = FitBone(RefSize, BodySize, Kind) end
	end

	return Fits
end

if SERVER then
	--- Puts a wearable on or takes it off.
	-- @param Ply Player
	-- @param Slot string Slot id from ACE.Wearables.Slots
	-- @param Worn boolean
	-- @param Skin number|nil Model skin, 0 is olive and 1 is white for tinting
	-- @param Tint Color|nil Color the model is drawn with, like the Color tool sets on the pickup
	-- @param Bodygroups string|nil One digit per bodygroup, as Entity:SetBodyGroups takes (the vest's magazines)
	function Wearables.SetWearing(Ply, Slot, Worn, Skin, Tint, Bodygroups)
		if not Wearables.Slots[Slot] then return end

		Ply:SetNW2Bool(NWKey(Slot), Worn and true or false)
		Ply:SetNW2Int(NWSkinKey(Slot), Skin or 0)
		Ply:SetNW2Vector(NWColorKey(Slot), Tint and Vector(Tint.r, Tint.g, Tint.b) / 255 or Vector(1, 1, 1))
		Ply:SetNW2String(NWBodygroupsKey(Slot), Bodygroups or "")
		Ply:SetNW2Float(NWHealthKey(Slot), 1)
	end

	--- Wears a worn wearable down by the energy it absorbed, and breaks it off when it runs out.
	-- @param Ply Player
	-- @param Slot string Slot id from ACE.Wearables.Slots
	-- @param AbsorbedJ number Energy in J the wearable took from the bullet
	function Wearables.Damage(Ply, Slot, AbsorbedJ)
		if not Wearables.IsWearing(Ply, Slot) then return end

		local Data = Wearables.Slots[Slot]
		local Health = Wearables.GetHealth(Ply, Slot) - AbsorbedJ / Data.Durability

		if Health > 0 then
			Ply:SetNW2Float(NWHealthKey(Slot), Health)
			return
		end

		Wearables.SetWearing(Ply, Slot, false)
		Ply:EmitSound(Data.BreakSound)
		ACE.SendMsg(Ply, Color(255, 0, 0), "Your " .. Slot .. " broke.")
	end

	local function StripAll(Ply)
		for Slot in pairs(Wearables.Slots) do
			Wearables.SetWearing(Ply, Slot, false)
		end
	end

	hook.Add("PlayerSpawn", "ACE_Wearables", StripAll)
	hook.Add("PlayerDeath", "ACE_Wearables", StripAll)

	-- Where the armor is, to check a bullet's path against. The plates come from the model build, the helmet shell
	-- is measured from its mesh; both are posed on the wearer's bones with the same fit the client draws.
	local PlateOutlines = include("ace/server/sv_ace_wearable_plates.lua")
	local Spine2, Spine4, Head = "ValveBiped.Bip01_Spine2", "ValveBiped.Bip01_Spine4", "ValveBiped.Bip01_Head1"
	local Shapes = {} -- [Slot] = prepared shape, false if the model can't be read

	local function Smoothstep(A, B, X)
		local T = math.Clamp((X - A) / (B - A), 0, 1)
		return T * T * (3 - 2 * T)
	end

	-- Each plate as points in the Spine2 and Spine4 frames plus the Spine4 weight, skinned like the vest mesh
	-- (build_models.py vest_weights blends the two from 49 to 55 units up). Long edges are split so each part
	-- bends with its own bone.
	local function PreparePlates(Wear)
		local Bind2, Bind4 = Wear.Binds[Spine2], Wear.Binds[Spine4]
		if not Bind2 or not Bind4 then return false end

		local Plates = {}
		for _, Outline in SortedPairs(PlateOutlines) do
			local Points = {}

			for I, A in ipairs(Outline) do
				local B = Outline[I % #Outline + 1]
				local Steps = math.ceil(A:Distance(B) / 2)

				for S = 0, Steps - 1 do
					local P = LerpVector(S / Steps, A, B)
					Points[#Points + 1] = { Bind2 * P, Bind4 * P, Smoothstep(49, 55, P.z) }
				end
			end

			Plates[#Plates + 1] = Points
		end

		return Plates
	end

	-- The helmet as an ellipsoid in the Head1 frame plus the height of its rim all the way round, since the cut is
	-- high over the ears and low at the nape. Bins are angles around the bone, from atan2(z, y).
	local RimBins = 24

	local function RimBin(Point, Center)
		local Angle = math.atan2(Point.z - Center.z, Point.y - Center.y)
		return math.floor((Angle + math.pi) / (2 * math.pi) * RimBins) % RimBins + 1
	end

	local function PrepareShell(Wear)
		local Points = LocalVerts(Wear, Head, { [Head] = true })
		if #Points == 0 then return false end

		local Lo, Hi = Vector(Points[1]), Vector(Points[1])
		for _, P in ipairs(Points) do
			Lo.x, Lo.y, Lo.z = math.min(Lo.x, P.x), math.min(Lo.y, P.y), math.min(Lo.z, P.z)
			Hi.x, Hi.y, Hi.z = math.max(Hi.x, P.x), math.max(Hi.y, P.y), math.max(Hi.z, P.z)
		end

		local Center = Vector(0, (Lo.y + Hi.y) / 2, (Lo.z + Hi.z) / 2)
		local Rim = {}
		for _, P in ipairs(Points) do
			local Bin = RimBin(P, Center)
			Rim[Bin] = math.min(Rim[Bin] or math.huge, P.x)
		end

		-- The dome's widest part is at the rim's average height
		local Sum = 0
		for Bin = 1, RimBins do
			Rim[Bin] = Rim[Bin] or Lo.x
			Sum = Sum + Rim[Bin]
		end
		Center.x = Sum / RimBins

		return { Center = Center, Radii = Vector(Hi.x - Center.x, (Hi.y - Lo.y) / 2, (Hi.z - Lo.z) / 2), Rim = Rim }
	end

	local function GetShape(Slot, Data)
		if Shapes[Slot] == nil then
			local Wear = LoadMesh(Data.Model)
			Shapes[Slot] = Wear and (Data.Shape == "Plates" and PreparePlates or PrepareShell)(Wear) or false
		end

		return Shapes[Slot]
	end

	local function FittedBone(Ply, Fits, Name)
		local Bone = Ply:LookupBone(Name)
		local Matrix = Bone and Ply:GetBoneMatrix(Bone)
		if not Matrix then return end

		return Fits[Name] and Matrix * Fits[Name] or Matrix
	end

	-- Moller-Trumbore: distance along Dir to the triangle, nil if the ray misses it
	local function RayTriangle(Origin, Dir, A, B, C)
		local E1, E2 = B - A, C - A
		local P = Dir:Cross(E2)
		local Det = E1:Dot(P)
		if math.abs(Det) < 1e-6 then return end

		local T = Origin - A
		local U = T:Dot(P) / Det
		if U < 0 or U > 1 then return end

		local Q = T:Cross(E1)
		local V = Dir:Dot(Q) / Det
		if V < 0 or U + V > 1 then return end

		return E2:Dot(Q) / Det
	end

	-- Whether a bullet's path crosses a plate from outside. The hitbox is only a box, so the whole line through the
	-- hit counts, not the hit point: from well in front of it to well past it. Also returns the plate's normal there.
	local function HitsPlates(Ply, Plates, Fits, HitPos, Dir)
		local M2, M4 = FittedBone(Ply, Fits, Spine2), FittedBone(Ply, Fits, Spine4)
		if not M2 or not M4 then return end

		local Posed, Center = {}, Vector()
		for I, Plate in ipairs(Plates) do
			local World, Mid = {}, Vector()
			for J, P in ipairs(Plate) do
				World[J] = LerpVector(P[3], M2 * P[1], M4 * P[2])
				Mid:Add(World[J])
			end
			Mid:Div(#World)
			Posed[I] = { World = World, Mid = Mid }
			Center:Add(Mid)
		end
		Center:Div(#Posed)

		local Origin = HitPos - Dir * 40
		for _, Plate in ipairs(Posed) do
			-- A bullet already inside the body doesn't hit the other plate from behind
			if Dir:Dot(Plate.Mid - Center) < 0 then
				local World = Plate.World
				for I = 1, #World do
					local A, B, C = Plate.Mid, World[I], World[I % #World + 1]
					local Dist = RayTriangle(Origin, Dir, A, B, C)
					if Dist and Dist >= 0 and Dist <= 60 then return true, (B - A):Cross(C - A):GetNormalized() end
				end
			end
		end

		return false
	end

	-- Whether a bullet's path enters the helmet above its rim, and the helmet's surface normal where it does
	local function HitsShell(Ply, Shell, Fits, HitPos, Dir)
		local Matrix = FittedBone(Ply, Fits, Head)
		if not Matrix then return end

		local Inverse = Matrix:GetInverse()
		if not Inverse then return end

		-- Into the head's frame, then squashed so the ellipsoid is a unit sphere
		local From = Inverse * (HitPos - Dir * 40)
		local Along = Inverse * (HitPos + Dir * 20) - From
		local R = Shell.Radii
		local O = From - Shell.Center
		O = Vector(O.x / R.x, O.y / R.y, O.z / R.z)
		local D = Vector(Along.x / R.x, Along.y / R.y, Along.z / R.z)

		local A, B, C = D:Dot(D), 2 * O:Dot(D), O:Dot(O) - 1
		local Disc = B * B - 4 * A * C
		if Disc < 0 then return false end

		local T = (-B - math.sqrt(Disc)) / (2 * A)
		if T < 0 or T > 1 then return false end

		local Entry = From + Along * T
		if Entry.x < Shell.Rim[RimBin(Entry, Shell.Center)] then return false end

		-- The ellipsoid's normal at the entry, back out to the world
		local S = O + D * T
		local Local = Vector(S.x / R.x, S.y / R.y, S.z / R.z)
		return true, (Matrix * (Entry + Local) - Matrix * Entry):GetNormalized()
	end

	--- Whether a bullet's path crosses a worn wearable's armor.
	-- @param Ply Player
	-- @param Slot string Slot id from ACE.Wearables.Slots
	-- @param HitPos Vector Where the bullet hit the hitbox
	-- @param Dir Vector Bullet flight direction
	-- @return boolean|nil Nil when it can't tell (no bones, unreadable model)
	-- @return Vector|nil The armor's surface normal where the path crosses it, either way round
	function Wearables.Covers(Ply, Slot, HitPos, Dir)
		local Data = Wearables.Slots[Slot]
		local Shape = GetShape(Slot, Data)
		if not Shape then return end

		local Fits = Wearables.GetFit(Ply:GetModel(), Slot)
		Dir = Dir:GetNormalized()

		if Data.Shape == "Plates" then return HitsPlates(Ply, Shape, Fits, HitPos, Dir) end
		return HitsShell(Ply, Shape, Fits, HitPos, Dir)
	end

	hook.Add("ACE_GetBodyArmor", "ACE_Wearables", function(Entity, Hitgroup, Layers, HitPos, Dir)
		if not Entity:IsPlayer() then return end

		for Slot, Data in pairs(Wearables.Slots) do
			local Plates = Data.Layers[Hitgroup]

			if Plates and Wearables.IsWearing(Entity, Slot) then
				local Covered, Normal
				if HitPos and Dir then Covered, Normal = Wearables.Covers(Entity, Slot, HitPos, Dir) end

				-- Without a known path, one Coverage roll decides the whole stack, not each plate in it
				if Covered or (Covered == nil and math.random() <= (Plates.Coverage or 1)) then
					local Scale = Wearables.ProtectionScale(Wearables.GetHealth(Entity, Slot))
					local OnHit = function(Ply, AbsorbedJ) Wearables.Damage(Ply, Slot, AbsorbedJ) end

					for _, Plate in ipairs(Plates) do
						Layers[#Layers + 1] = { Material = Plate.Material, Armour = Plate.Armour * Scale, Normal = Normal, OnHit = OnHit }
					end
				end
			end
		end
	end)

	concommand.Add("ace_wear", function(Ply, _, Args)
		if not IsValid(Ply) then return end
		if not Ply:IsAdmin() then
			ACE.SendMsg(Ply, Color(255, 0, 0), "ace_wear is admin only.")
			return
		end

		local What = string.lower(Args[1] or "")

		if What == "all" or What == "none" then
			for Slot in pairs(Wearables.Slots) do
				Wearables.SetWearing(Ply, Slot, What == "all")
			end
		elseif Wearables.Slots[What] then
			Wearables.SetWearing(Ply, What, not Wearables.IsWearing(Ply, What))
		else
			ACE.SendMsg(Ply, Color(255, 255, 255), "Usage: ace_wear helmet | vest | all | none")
		end
	end)

	return
end

-- Client: one model per worn slot, its bones copied from the player's like a bonemerge, with the fitted ones
-- stretched to the playermodel's build (a real bonemerge would overwrite the stretch). It draws itself rather than
-- from a player draw hook, because drawing a child redraws its parent, and a hook on that recurses (PAC3's editor
-- preview hits it).
local Worn = {} -- [Player] = { [Slot] = ClientsideModel }

local function ShouldDraw(Ply)
	if not IsValid(Ply) or not Ply:Alive() or Ply:GetNoDraw() then return false end

	local Me = LocalPlayer()
	if Ply == Me then return Ply:ShouldDrawLocalPlayer() end

	-- Spectating this player from their own eyes
	return not (Me:GetObserverMode() == OBS_MODE_IN_EYE and Me:GetObserverTarget() == Ply)
end

-- Bonemerge has already copied the player's bones when this runs; stretch the fitted ones for the playermodel
local function FitBones(Ent)
	if not Ent.ACE_Fit then return end

	for I, Fit in pairs(Ent.ACE_Fit) do
		local Bone = Ent:GetBoneMatrix(I)
		if Bone then Ent:SetBoneMatrix(I, Bone * Fit) end
	end
end

local function RenderWearable(Ent)
	local Ply = Ent:GetParent()
	if not ShouldDraw(Ply) then return end

	local Tint = Ply:GetNW2Vector(NWColorKey(Ent.ACE_Slot), Vector(1, 1, 1))
	render.SetColorModulation(Tint.x, Tint.y, Tint.z)
	Ent:DrawModel()
	render.SetColorModulation(1, 1, 1)
end

local function RemoveModel(Ply, Slot)
	local Models = Worn[Ply]
	if not Models or not Models[Slot] then return end

	if IsValid(Models[Slot]) then Models[Slot]:Remove() end
	Models[Slot] = nil
end

local function Attach(Ent, Ply)
	Ent:SetParent(Ply)
	Ent:SetLocalPos(vector_origin)
	Ent:SetLocalAngles(angle_zero)
	Ent:AddEffects(EF_BONEMERGE)
end

-- Picks up the fit for the playermodel, by the model's bone index
local function FitModel(Ent, Ply)
	local Model = Ply:GetModel()
	local Fits = Wearables.GetFit(Model, Ent.ACE_Slot)

	Ent.ACE_Fit = {}
	for I = 0, Ent:GetBoneCount() - 1 do
		Ent.ACE_Fit[I] = Fits[Ent:GetBoneName(I)]
	end

	Ent.ACE_FitModel = Model
end

local function CreateModel(Ply, Slot, Data)
	local Ent = ClientsideModel(Data.Model, RENDERGROUP_OPAQUE)
	if not IsValid(Ent) then return end

	Ent.ACE_Slot = Slot
	Attach(Ent, Ply)
	-- The bones follow the player, not the model's own bounds, so cull by the player's
	Ent:SetRenderBounds(Vector(-48, -48, -16), Vector(48, 48, 80))
	Ent.RenderOverride = RenderWearable
	Ent:AddCallback("BuildBonePositions", FitBones)
	FitModel(Ent, Ply)

	Worn[Ply] = Worn[Ply] or {}
	Worn[Ply][Slot] = Ent
end

hook.Add("Think", "ACE_Wearables", function()
	for Ply, Models in pairs(Worn) do
		if not IsValid(Ply) then
			for _, Ent in pairs(Models) do
				if IsValid(Ent) then Ent:Remove() end
			end
			Worn[Ply] = nil
		end
	end

	for _, Ply in player.Iterator() do
		for Slot, Data in pairs(Wearables.Slots) do
			local Wants = Wearables.IsWearing(Ply, Slot) and Ply:Alive() and Ply:LookupBone(Data.Bone) ~= nil
			local Ent = Worn[Ply] and Worn[Ply][Slot]

			if Wants and not IsValid(Ent) then
				CreateModel(Ply, Slot, Data)
			elseif not Wants and Ent then
				RemoveModel(Ply, Slot)
			elseif Wants then
				-- Clientside models lose their parent when the player goes dormant and comes back
				if Ent:GetParent() ~= Ply then Attach(Ent, Ply) end
				if Ent.ACE_FitModel ~= Ply:GetModel() then FitModel(Ent, Ply) end

				local Skin = Ply:GetNW2Int(NWSkinKey(Slot), 0)
				if Ent:GetSkin() ~= Skin then Ent:SetSkin(Skin) end

				local Bodygroups = Ply:GetNW2String(NWBodygroupsKey(Slot), "")
				if Ent.ACE_Bodygroups ~= Bodygroups then
					Ent:SetBodyGroups(Bodygroups)
					Ent.ACE_Bodygroups = Bodygroups
				end
			end
		end
	end
end)
