-- Damage decals, applied with util.DecalEx. Each key in DecalFor has 4 seed
-- variants (_v1.._v4, same morphology) under materials/ace/damage/.
-- DecalK constants are derived from real feature sizes; see SCALE.md in the
-- decal workspace for the derivation.
ACE.DecalK = {
	-- steel, penetrated
	ap_pen      = 0.1312,   -- hole == 1.00x caliber
	apcr_pen    = 0.1312,   -- outer dent == 1.35x caliber
	ricochet    = 0.1312,
	he          = 0.1312,   -- splash == 2.55x caliber   (he_pen / he_nopen)
	heat_pen    = 0.20,     -- pinhole == 0.22x caliber
	apfsds      = 0.229,    -- pass ROD caliber; hole == 1.00x rod

	-- steel, failed to penetrate
	ap_nopen    = 0.252,    -- dished dent == 1.10x caliber
	aphe_pen    = 0.194,    -- burst hole == 1.60x caliber
	heat_nopen  = 0.264,    -- crater == 1.00x caliber
	he_rico     = 0.165,    -- scour == 2.80x caliber

	-- other surfaces
	glass_pen   = 0.730,    -- hole == 1.00x caliber (pattern == 18.5x)
	glass_crack = 0.386,    -- impact pit == 1.00x caliber
	wood_pen    = 0.630,    -- hole == 1.00x caliber
	wood_nopen  = 0.305,    -- gouge width == 1.00x caliber
}

ACE.DecalFor = {
	ap_pen      = "ace_ap_pen",
	ap_nopen    = "ace_ap_nopen",
	apcr_pen    = "ace_apcr_pen",
	apfsds_fins = "ace_apfsds_pen_fins",   -- thin plate: fins cut through
	apfsds_rod  = "ace_apfsds_pen_rod",    -- thick plate: indents only
	aphe_pen    = "ace_aphe_pen",
	heat_pen    = "ace_heat_pen",
	heat_nopen  = "ace_heat_nopen",
	he_pen      = "ace_he_pen",
	he_nopen    = "ace_he_nopen",
	he_rico     = "ace_he_rico",
	ricochet    = "ace_ricochet",
	glass_pen   = "ace_glass_pen",
	glass_crack = "ace_glass_crack",
	wood_pen    = "ace_wood_pen",
	wood_nopen  = "ace_wood_nopen",
}

local DecalMaterials = {}
local LastVariant = {}

--- Material handle for a decal key, picking one of the 4 seed variants and
--- avoiding the same variant twice in a row for that key.
-- @param Key string Decal key, e.g. "ap_pen"
-- @param World boolean|nil Target is the world or a brush entity
-- @return IMaterial|nil
function ACE.DecalMaterial( Key, World )
	local Base = ACE.DecalFor[Key]
	if not Base then return nil end

	local V = math.random( 1, 4 )
	if V == LastVariant[Key] then
		V = ( V % 4 ) + 1
	end
	LastVariant[Key] = V

	local Name = "ace/damage/" .. Base .. "_v" .. V
	if not World then
		DecalMaterials[Name] = DecalMaterials[Name] or Material( Name )
		return DecalMaterials[Name]
	end

	local WName = Name .. "#world"
	DecalMaterials[WName] = DecalMaterials[WName] or CreateMaterial( "ace_decal_world_" .. Base .. "_v" .. V, "LightmappedGeneric", {
		["$basetexture"] = Name,
		["$decal"] = 1,
		["$decalscale"] = 0.05,
		["$translucent"] = 1,
	} )
	return DecalMaterials[WName]
end

-- Nominal decal size in world units for a 256px texture at $decalscale 0.05.
-- DecalEx w/h are a multiplier over this nominal, not absolute units.
ACE.DecalNominal = 12.8

--- Width to hand to util.DecalEx, in w/h multiplier units.
-- @param Key string Decal key
-- @param CaliberCm number ACE caliber, in centimetres (0.556 for 5.56mm)
-- @return number
function ACE.DecalSize( Key, CaliberCm )
	local K = ACE.DecalK[Key]
		or ( string.StartWith( Key, "apfsds" ) and ACE.DecalK.apfsds )
		or ACE.DecalK.ap_pen

	return K * ( CaliberCm * 10 ) / ACE.DecalNominal
end

--- Caliber a decal is sized from: the rod for APFSDS marks, the bore otherwise.
-- @param Key string Decal key
-- @param Crate Entity Ammo crate
-- @param CaliberCm number Bore caliber in cm
-- @return number
function ACE.DecalCaliber( Key, Crate, CaliberCm )
	if not string.StartWith( Key, "apfsds" ) then return CaliberCm end

	return CaliberCm * ( IsValid( Crate ) and Crate:GetNWFloat( "SCalMult", 0.18 ) or 0.18 )
end

--- Stamp a damage decal at a hit position.
-- @param Key string Decal key, e.g. "ap_pen"
-- @param Ent Entity Surface entity (may be the worldspawn)
-- @param Pos Vector Hit position
-- @param Normal Vector Hit normal
-- @param CaliberCm number ACE caliber in cm; APFSDS takes the rod caliber (ACE.DecalCaliber)
-- @param Stretch number|nil Optional x-stretch for ricochets (default 1)
function ACE.PlaceDecal( Key, Ent, Pos, Normal, CaliberCm, Stretch )
	local World = not IsValid( Ent ) or string.sub( Ent:GetModel() or "", 1, 1 ) == "*"
	local Mat = ACE.DecalMaterial( Key, World )
	if not Mat then return end

	local Size = ACE.DecalSize( Key, CaliberCm )

	local W, H = Size, Size
	if Stretch and Stretch ~= 1 then
		-- ricochets are dragged along the bounce; the scuff has no baked
		-- direction so stretching it any way is safe
		W, H = Size * Stretch, Size / math.sqrt( Stretch )
	end

	util.DecalEx( Mat, Ent, Pos, Normal, color_white, W, H )
end

--- Stamp the damage decal for a clientside bullet at its current position.
-- @param Bullet table Clientside bullet data
-- @param Penetrated boolean Whether the round went through
function ACE.BulletDecal( Bullet, Penetrated )
	local Dir = Bullet.SimFlight:GetNormalized()
	local Tr = util.TraceLine( { start = Bullet.SimPos - Dir * 10, endpos = Bullet.SimPos + Dir * 50 } )
	if not Tr.Hit then return end

	local MatVal = ACE.GetMaterialName( Tr.MatType )
	if MatVal == "Flesh" then return end

	ACE.PlaceDecal( ACE.GetDamageDecal( Bullet.AmmoType, Penetrated, false, MatVal ), Tr.Entity, Tr.HitPos, Tr.HitNormal, Bullet.Caliber )
end

local DefaultDecals = { pen = "ap_pen", nopen = "ap_nopen", rico = "ricochet" }

local function RoundDecals( Id )
	local Round = ACE.RoundTypes[Id]

	return Round and Round.decals or DefaultDecals
end

-- Surface-material overrides trump the ammo key; a bullet through a wooden
-- crate leaves a wood hole, not an AP crater.
local MatPenKeys = { Wood = "wood_pen", Glass = "glass_pen" }
local MatNoPenKeys = { Wood = "wood_nopen", Glass = "glass_crack" }
local MatRicoKeys = { Wood = "wood_nopen", Glass = "glass_crack" }

--- Damage decal key for a hit, or nil to fall back to the generic decal.
-- @param Id string Ammo type id as networked on the ammo crate
-- @param Penetrated boolean Whether the round went through
-- @param FinsCut boolean|nil Plate thin enough for APFSDS fins to cut through
-- @param MatVal string|nil Surface material name from ACE.GetMaterialName
-- @return string|nil Decal key
function ACE.GetDamageDecal( Id, Penetrated, FinsCut, MatVal )
	local MatKeys = Penetrated and MatPenKeys or MatNoPenKeys
	if MatVal and MatKeys[MatVal] then return MatKeys[MatVal] end

	local Decals = RoundDecals( Id )
	if not Penetrated then return Decals.nopen or DefaultDecals.nopen end

	return FinsCut and Decals.thin or Decals.pen or DefaultDecals.pen
end

--- Ricochet decal key for an ammo id.
-- @param Id string Ammo type id
-- @param MatVal string|nil Surface material name from ACE.GetMaterialName
-- @return string Decal key
function ACE.GetRicochetDecal( Id, MatVal )
	if MatVal and MatRicoKeys[MatVal] then return MatRicoKeys[MatVal] end
	return RoundDecals( Id ).rico or DefaultDecals.rico
end
