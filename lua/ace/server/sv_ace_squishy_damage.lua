-- Damage to players, NPCs and seat drivers.
-- A hit is decided in two steps. Body armor layers (from the ACE_GetBodyArmor hook) are ACE armor plates of their
-- material and thickness, resolved the same way as a prop hit: line of sight thickness at the angle the bullet meets
-- them, the material's effectiveness and the penetration roll. Whatever gets through tears flesh: a wound that
-- scales with caliber plus the kinetic energy left in the flesh. A stopped bullet still hurts through blunt trauma,
-- set by the material's BluntTransfer.

ACE.Flesh = ACE.Flesh or {}
local Flesh = ACE.Flesh

Flesh.EnergyDamage = 10 -- HP per kJ of kinetic energy left in the flesh by a bullet that got through
Flesh.BluntDamage  = 25 -- HP per kJ that reaches the body behind armor that stopped the bullet
Flesh.WoundDamage  = 1  -- Multiplier on the caliber-based wound
Flesh.ArmorPerJ    = 40 -- HL2 suit armor points lost per J the suit absorbs

local DMG_STOPPED = bit.bor(DMG_CLUB, DMG_PREVENT_PHYSICS_FORCE)

--- Hitgroup layout. Bone is the thickness in mm RHA (skull, ribs) a bullet must get through before it wounds what's behind it.
--- Mul scales the damage and WoundCap limits the wound to that share of max health on non-vital parts.
Flesh.Hitgroups = {
	[HITGROUP_HEAD]     = { Bone = 3.6, Mul = 2.5 },
	[HITGROUP_GENERIC]  = { Bone = 2,   Mul = 1 },
	[HITGROUP_CHEST]    = { Bone = 2,   Mul = 1 },
	[HITGROUP_STOMACH]  = { Bone = 2,   Mul = 1 },
	[HITGROUP_LEFTARM]  = { Bone = 0,   Mul = 0.5, WoundCap = 0.2 },
	[HITGROUP_RIGHTARM] = { Bone = 0,   Mul = 0.5, WoundCap = 0.2 },
	[HITGROUP_LEFTLEG]  = { Bone = 0,   Mul = 0.7, WoundCap = 0.3 },
	[HITGROUP_RIGHTLEG] = { Bone = 0,   Mul = 0.7, WoundCap = 0.3 },
	[HITGROUP_GEAR]     = { Bone = 0,   Mul = 0.7, WoundCap = 0.1 },
}

-- These materials' resolvers need a real prop: DU looks up its owner and position, ERA detonates and removes itself
local PropOnlyMaterials = { DU = true, ERA = true }

local function GetCaliber(FrArea)
	return 20 * (FrArea ^ (1 / ACE.PenAreaMod) / 3.1416) ^ 0.5
end

-- Stands in for a prop when a layer is resolved. Sounds the material makes (ceramic shattering) come from the wearer.
local Plate = { ACE = { Ductility = 0 } }

function Plate:EmitSound(...)
	if IsValid(self.Wearer) then self.Wearer:EmitSound(...) end
end

--- Resolves a bullet against one plate of armor that isn't a prop, the way ACE resolves a hit on an armor prop.
-- @param Wearer Entity Who the armor is on, for sounds
-- @param Material string ACE material id
-- @param Armour number Thickness in mm
-- @param Energy table Bullet energy
-- @param Angle number Degrees from the plate's normal
-- @param Type string|nil Round type
-- @return table HitRes from the material
-- @return table Post-penetration from ACE.GetPostPenetration
function ACE.ResolveArmorLayer(Wearer, Material, Armour, Energy, FrArea, Angle, Type)
	if PropOnlyMaterials[Material] or not ACE.ArmorTypes[Material] then Material = "RHA" end

	Plate.Wearer = Wearer
	Plate.ACE.Armour = Armour
	Plate.ACE.Material = Material

	local HitRes = ACE.CalcDamage(Plate, Energy, FrArea, Angle or 0, Type)
	Plate.Wearer = nil

	return HitRes, ACE.GetPostPenetration(HitRes, Energy)
end

--- Runs a bullet through the body armor layers that cover a hitgroup, outermost first.
-- Layers come from the ACE_GetBodyArmor hook as { Material, Armour, Normal, Coverage, OnHit(ent, absorbedJ) }:
-- an ACE material id, the thickness in mm, and the armor's outward surface normal where the bullet crosses it.
-- Without a normal the bullet meets it square on. The hook also gets where the bullet hit and its flight direction,
-- when known, so a layer can check whether the bullet's path crosses the armor instead of rolling its Coverage.
-- @param Energy table Bullet energy, as from ACE.Kinetic
-- @param Type string|nil Round type
-- @param HitPos Vector|nil Where the bullet hit the hitbox
-- @param Dir Vector|nil Bullet flight direction
-- @return table|nil Energy left after the armor, nil if a layer stopped the bullet
-- @return number|nil Blunt energy in J if a layer stopped the bullet
-- @return table|nil The layer that stopped it
function ACE.ResolveBodyArmor(Entity, Hitgroup, Energy, FrArea, Type, HitPos, Dir)
	local Layers = {}
	hook.Run("ACE_GetBodyArmor", Entity, Hitgroup, Layers, HitPos, Dir)

	Energy = { Kinetic = Energy.Kinetic or 0, Momentum = Energy.Momentum or 0, Penetration = Energy.Penetration or 0 }

	for _, Layer in ipairs(Layers) do
		if (Layer.Armour or 0) > 0 and math.random() <= (Layer.Coverage or 1) then
			local Normal = Layer.Normal
			-- Face the normal into the bullet; a ricochet reflects off it
			if Normal and Dir and Normal:Dot(Dir) > 0 then
				Normal = -Normal
				Layer.Normal = Normal
			end

			local Angle = Normal and Dir and ACE.GetHitAngle(Normal, Dir) or 0
			local _, Post = ACE.ResolveArmorLayer(Entity, Layer.Material, Layer.Armour, Energy, FrArea, Angle, Type)

			if Layer.OnHit then Layer.OnHit(Entity, Post.SpentKinetic * 1000) end

			if not Post.Continue then
				local MatData = ACE.GetMaterialData(Layer.Material)
				return nil, Energy.Kinetic * 1000 * (MatData.BluntTransfer or 0.15), Layer
			end

			if not Layer.Suit then Energy.Armored = true end

			Energy.Kinetic = Post.RemainingKinetic
			Energy.Penetration = Post.RemainingPenetration
			Energy.Momentum = Energy.Momentum * Post.Remaining
		end
	end

	return Energy
end

local function ApplyDamage(Entity, Damage, DmgType, Inflictor, Gun, HitPos, Dir, MinDamage)
	if Damage <= 0 or Damage < (MinDamage or 0) then return end

	local Info = DamageInfo()
	Info:SetDamage(Damage)
	Info:SetDamageType(DmgType)
	Info:SetAttacker(IsValid(Inflictor) and Inflictor or game.GetWorld())
	Info:SetInflictor(IsValid(Gun) and Gun or Info:GetAttacker())
	-- Gamemodes with their own organ systems (ZCity) trace from the hit point along the force to find the organ.
	Info:SetDamagePosition(HitPos or Entity:WorldSpaceCenter())
	if Dir then Info:SetDamageForce(Dir:GetNormalized() * Damage * 300) end

	-- ACE already ran the suit armor as a body armor layer. Hiding it stops the engine from absorbing the same hit again.
	local SuitArmor = Entity:IsPlayer() and Entity:Armor() or 0
	if SuitArmor > 0 then Entity:SetArmor(0) end

	Entity:TakeDamageInfo(Info)

	if SuitArmor > 0 and IsValid(Entity) then Entity:SetArmor(SuitArmor) end
end

--- Deals blunt trauma, for a bullet that armor stopped.
-- @param BluntJ number Energy in J that reaches the body
-- @param HitPos Vector|nil Where the bullet hit, for organ traces
-- @param Dir Vector|nil Bullet flight direction
-- @param MinDamage number|nil Damage below this applies nothing at all
function ACE.FleshBlunt(Entity, BluntJ, Hitgroup, Inflictor, Gun, HitPos, Dir, MinDamage)
	local Group = Flesh.Hitgroups[Hitgroup] or Flesh.Hitgroups[HITGROUP_GENERIC]

	ApplyDamage(Entity, BluntJ / 1000 * Flesh.BluntDamage * Group.Mul, DMG_STOPPED, Inflictor, Gun, HitPos, Dir, MinDamage)
end

--- Deals the damage of a bullet that hit flesh, after any armor in front of the body.
-- @param EnergyJ number Kinetic energy in J the bullet still carries
-- @param Pen number Penetration in mm RHA the bullet still has
-- @param Caliber number Bullet diameter in mm
-- @param MinDamage number|nil Damage below this applies nothing at all
-- @return number Thickness in mm RHA the body counts as, for the bullet's exit
function ACE.FleshHit(Entity, EnergyJ, Pen, Caliber, Hitgroup, Inflictor, Gun, HitPos, Dir, MinDamage)
	local Group = Flesh.Hitgroups[Hitgroup] or Flesh.Hitgroups[HITGROUP_GENERIC]

	local Phys = Entity:GetPhysicsObject()
	local MassRatio = (IsValid(Phys) and Phys:GetMass() or 90) / 90 -- Bigger creatures are harder to kill
	local Bone = Group.Bone * MassRatio
	local FleshThickness = 5 * MassRatio -- Flesh past the bone, in mm RHA, for a full wound

	if Pen <= Bone then
		-- Bone stopped it. The bullet leaves all its energy in the body, but makes no wound.
		ApplyDamage(Entity, EnergyJ / 1000 * Flesh.EnergyDamage * Group.Mul, DMG_STOPPED, Inflictor, Gun, HitPos, Dir, MinDamage)
		return Bone + FleshThickness
	end

	local FleshPen = Pen - Bone
	local WoundFraction = math.min(FleshPen / FleshThickness, 1)
	-- A bullet that keeps a lot of pen past the flesh leaves through the other side with most of its energy.
	local Deposited = EnergyJ * math.Clamp(FleshThickness / FleshPen, 0.35, 1)

	local Wound = WoundFraction * Caliber * (4 + 0.1 * Caliber) * Flesh.WoundDamage * Group.Mul
	if Group.WoundCap then Wound = math.min(Wound, Entity:GetMaxHealth() * Group.WoundCap) end

	ApplyDamage(Entity, Wound + Deposited / 1000 * Flesh.EnergyDamage * Group.Mul, DMG_BULLET, Inflictor, Gun, HitPos, Dir, MinDamage)

	return Bone + FleshThickness
end

local MinDamageConVar
local function GetMinDamage()
	-- Cached lazily: the convar is created in acf_globals.lua, which may still be running.
	MinDamageConVar = MinDamageConVar or (GetConVar and GetConVar("ace_bodyarmor_min_damage"))
	return MinDamageConVar and MinDamageConVar:GetFloat() or 0
end

--- Resolves a bullet hit on a squishy target: body armor, then flesh.
-- @param Type string|nil Round type
-- @return number|nil Thickness in mm RHA for the bullet's exit, nil if armor stopped the bullet
-- @return table|nil The armor layer that stopped it
function ACE.FleshDamage(Entity, Energy, FrArea, Inflictor, Hitgroup, Gun, HitPos, Dir, Type)
	if (Energy.Kinetic or 0) <= 0 then return end

	local Left, BluntJ, Layer = ACE.ResolveBodyArmor(Entity, Hitgroup, Energy, FrArea, Type, HitPos, Dir)

	-- Hits the body armor dealt with or weakened deal nothing under ace_bodyarmor_min_damage.
	-- The HL2 suit isn't real armor, so suit-protected hits keep their full scratch damage.
	local Armored = Left and Left.Armored or (Layer and not Layer.Suit)
	local MinDamage = Armored and GetMinDamage() or 0

	if not Left then
		ACE.FleshBlunt(Entity, BluntJ, Hitgroup, Inflictor, Gun, HitPos, Dir, MinDamage)
		return nil, Layer
	end

	return ACE.FleshHit(Entity, Left.Kinetic * 1000, ACE.CalcPenetration(Left, FrArea), GetCaliber(FrArea), Hitgroup, Inflictor, Gun, HitPos, Dir, MinDamage)
end

-- HL2 suit armor counts as a soft aramid vest, 7 mm at 100 points. Above 75 it also covers the head, above 50 the
-- limbs at a quarter of the thickness, like the old thresholds. The suit loses points for the energy it absorbs.
local SuitLimbs = {
	[HITGROUP_LEFTARM] = true, [HITGROUP_RIGHTARM] = true,
	[HITGROUP_LEFTLEG] = true, [HITGROUP_RIGHTLEG] = true,
}

local function SuitOnHit(Ply, AbsorbedJ)
	if not IsValid(Ply) then return end

	Ply:SetArmor(math.max(Ply:Armor() - AbsorbedJ / Flesh.ArmorPerJ, 0))
end

hook.Add("ACE_GetBodyArmor", "ACE_SuitArmor", function(Entity, Hitgroup, Layers)
	if not Entity:IsPlayer() then return end

	local Suit = Entity:Armor()
	if Suit <= 0 then return end

	local Armour = 7 * math.Clamp(Suit / 100, 0.25, 2)

	if Hitgroup == HITGROUP_HEAD then
		if Suit > 75 then Layers[#Layers + 1] = { Material = "Aramid", Armour = Armour, Suit = true, OnHit = SuitOnHit } end
	elseif SuitLimbs[Hitgroup] then
		if Suit > 50 then Layers[#Layers + 1] = { Material = "Aramid", Armour = Armour * 0.25, Suit = true, OnHit = SuitOnHit } end
	else
		Layers[#Layers + 1] = { Material = "Aramid", Armour = Armour, Suit = true, OnHit = SuitOnHit }
	end
end)
