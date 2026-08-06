
local cat = ((ACE.CustomToolCategory and ACE.CustomToolCategory:GetBool()) and "ACF" or "Construction");

TOOL.Category	= cat
TOOL.Name	= "#tool.acearmorprop.name"
TOOL.Command	= nil
TOOL.ConfigName = ""

TOOL.ClientConVar["thickness"]  = 1
TOOL.ClientConVar["ductility"]  = 0
TOOL.ClientConVar["material"]	= "RHA"

if CLIENT then
	TOOL.Information = {
		{ name = "left" },
		{ name = "right" },
		{ name = "reloadhint" },
		{ name = "reloadfull" }
	}

	language.Add("tool.acearmorprop.reloadhint", "Reload: Get information about contraption")
	language.Add("tool.acearmorprop.reloadfull", "Shift + Reload: Get full point readout")
end

-- Shared panel state used across panel rebuilds to keep UI controls stable.
local ToolPanel = ToolPanel or {}

CreateClientConVar( "acearmorprop_area", 0, false, true ) -- Transient area cache; do not persist.

-- Compute mass, armor, and health from prop area, ductility, thickness, and material.
local function CalcArmor( Area, Ductility, Thickness, Mat )

	Mat = Mat or "RHA"

	local MatData	= ACE_GetMaterialData( Mat )
	local MassMod	= MatData.massMod

	local mass		= Area * ( 1 + Ductility ) ^ 0.5 * Thickness * 0.00078 * MassMod
	local armor		= ACE_CalcArmor( Area, Ductility, mass / MassMod )
	local health		= ( Area + Area * Ductility ) / ACE.Threshold

	return mass, armor, health

end


-- Apply tool settings to a prop and store duplicator metadata.
local function ApplySettings( _, ent, data )

	if not SERVER then return end


	if data.Mass then
		local phys = ent:GetPhysicsObject()
		if IsValid( phys ) then phys:SetMass( data.Mass ) end
		duplicator.StoreEntityModifier( ent, "mass", { Mass = data.Mass } )
	end

	if data.Ductility then
		ent.ACF = ent.ACF or {}
		ent.ACF.Ductility = data.Ductility / 100
		duplicator.StoreEntityModifier( ent, "acfsettings", { Ductility = data.Ductility } )
	end

	local con = ent:CFW_GetContraption()

	if data.Material then
		ent.ACF = ent.ACF or {}
		ent.ACF.Material = data.Material
		duplicator.StoreEntityModifier( ent, "acfsettings", { Material = data.Material } )
	end

	ACE_MarkArmorDirty(con, ent, "armor-tool")

end

duplicator.RegisterEntityModifier( "acfsettings", ApplySettings )
duplicator.RegisterEntityModifier( "mass", ApplySettings )

-- Left-click applies the current tool settings to the targeted prop.
function TOOL:LeftClick( trace )

	local ent = trace.Entity

	if not IsValid( ent ) or ent:IsPlayer() then return false end
	if CLIENT then return true end
	if not ACE_Check( ent ) then return false end

	local ply		= self:GetOwner()

	local ductility = math.Clamp( self:GetClientNumber( "ductility" ), -80, 80 )
	local thickness = math.Clamp( self:GetClientNumber( "thickness" ), 0.1, 50000 )
	local material  = self:GetClientInfo( "material" ) or "RHA"

	local mass		= CalcArmor( ent.ACF.Area, ductility / 100, thickness , material)

	ApplySettings( ply, ent, { Mass = mass , Ductility = ductility, Material = material} )

	-- Clear cached target to force a fresh network update of armor values.
	self.AimEntity = nil

	return true

end

-- Right-click copies the targeted prop settings into the tool.
function TOOL:RightClick( trace )

	local ent = trace.Entity

	if not IsValid( ent ) or ent:IsPlayer() then return false end
	if CLIENT then return true end
	if not ACE_Check( ent ) then return false end

	local ply = self:GetOwner()

	ply:ConCommand( "acearmorprop_ductility " .. (ent.ACF.Ductility or 0) * 100 )
	ply:ConCommand( "acearmorprop_thickness " .. ent.ACF.MaxArmour )
	ply:ConCommand( "acearmorprop_material " .. (ent.ACF.Material or "RHA") )

	-- Clear cached target to force a fresh network update of armor values.
	self.AimEntity = nil

	return true

end

do
	-- Allow read-only armor inspection even when CanTool would block edits.
	ACE.OldHookCall = ACE.OldHookCall or hook.Call

	-- Armor tool hook override for safe reloads.
	function hook.Call(Name, Gamemode, Player, Entity, Tool, ...)
		if Name == "CanTool" and Tool == "acearmorprop" and Player:KeyPressed(IN_RELOAD) then
			return true
		end

		return ACE.OldHookCall(Name, Gamemode, Player, Entity, Tool, ...)
	end
end

-- Reload aggregates mass across constrained entities.
function TOOL:Reload( trace )

	local ent = trace.Entity

	if not IsValid( ent ) or ent:IsPlayer() then return false end
	if CLIENT then return true end

	-- Coerce numeric values and guard NaN/inf.
	local function safeNumber(value)
		value = tonumber(value) or 0
		if value ~= value or value == math.huge or value == -math.huge then
			return 0
		end
		return value
	end

	local ply = self:GetOwner()
	local fullReadout = ply:KeyDown(IN_SPEED)
	local data		= ACE_CalcMassRatio(ent, true) or {}

	local total		= tonumber(ent.acftotal) or 0
	local phystotal	= tonumber(ent.acfphystotal) or 0
	local parenttotal	= total - phystotal
	local physratio	= total > 0 and (100 * phystotal / total) or 0

	local power		= tonumber(data.Power) or 0

	local Contraption = ent:CFW_GetContraption() or nil
	if Contraption and ACE_EnsureContraptionPoints then
		ACE_EnsureContraptionPoints(Contraption, ent, false)
	end

	local PointVal		= 0

	local PtsArmor = 0
	local PtsEngine = 0
	local PtsFirepower = 0
	local PtsCrew = 0
	local PtsElectronics = 0
	local FirepowerCount = 0
	local ArmorInitMissing = false

	if Contraption ~= nil then
		local pointsPerType = Contraption.ACEPointsPerType or {}
		PointVal		= safeNumber(Contraption.ACEPoints or ACE_GetEntPoints(ent))
		PtsArmor = safeNumber(pointsPerType.Armor)
		PtsEngine = safeNumber(pointsPerType.Engines)
		PtsFirepower = safeNumber(pointsPerType.Firepower)
		PtsCrew = safeNumber(pointsPerType.Crew)
		PtsElectronics = safeNumber(pointsPerType.Electronics)
		ArmorInitMissing = not Contraption.ACEArmorCalculated

		if ACE_GetContraptionEntities and ACE_GetPtsType then
			for _, candidate in ipairs(ACE_GetContraptionEntities(Contraption, ent)) do
				if IsValid(candidate) and ACE_GetPtsType(candidate:GetClass()) == "Firepower" then
					FirepowerCount = FirepowerCount + 1
				end
			end
		end
	else
		PointVal = safeNumber(ACE_GetEntPoints(ent))
	end

	local GeneralTb	= { data.MaterialMass or {}, data.MaterialPercent or {} }
	local ToJSON		= util.TableToJSON( GeneralTb )
	local Compressed	= util.Compress(ToJSON) or ""

	net.Start("ACE_ArmorSummary")
		net.WriteFloat(total)
		net.WriteFloat(phystotal)
		net.WriteFloat(parenttotal)
		net.WriteFloat(physratio)
		net.WriteFloat(power)
		net.WriteFloat(PointVal)
		net.WriteFloat(PtsArmor)
		net.WriteBool(ArmorInitMissing)
		net.WriteBool(fullReadout)
		net.WriteFloat(PtsEngine)
		net.WriteFloat(PtsFirepower)
		net.WriteUInt(math.min(FirepowerCount, 65535), 16)
		net.WriteFloat(PtsCrew)
		net.WriteFloat(PtsElectronics)

		net.WriteUInt(#Compressed, 16)
		net.WriteData(Compressed, #Compressed)

	net.Send(ply)

end


-- Popup point label helpers.
local ArmorPointClasses = {
	prop_physics = true,
	primitive_shape = true,
	primitive_airfoil = true,
	primitive_rail_slider = true,
	primitive_slider = true,
	primitive_ladder = true
}

local PointClassToType = {
	acf_engine = "Engines",
	acf_gearbox = "Electronics",   -- priced by ACEPoints lookup, bucketed with Electronics
	acf_fueltank = "Ignore",
	acf_ammo = "Ignore",           -- ammo is free: no point cost
	acf_gun = "Firepower",
	acf_rack = "Firepower",
	ace_explosive = "Firepower",
	ace_explosive_prebuilt = "Firepower",
	ace_bomb_satchel = "Firepower",
	ace_bomb_aerial = "Firepower",
	ace_bomb_barrel = "Firepower",
	ace_crewseat_gunner = "Crew",
	ace_crewseat_loader = "Crew",
	ace_crewseat_driver = "Crew",
	ace_rwr_dir = "Electronics",
	ace_rwr_sphere = "Electronics",
	acf_missileradar = "Electronics",
	acf_opticalcomputer = "Electronics",
	ace_ecm = "Electronics",
	ace_trackingradar = "Electronics",
	ace_searchradar = "Electronics",
	ace_irst = "Electronics",
	ace_sonar = "Electronics",
	ace_gforce_meter = "Electronics",
	ace_vheat_source = "Electronics",
	ace_wind_sensor = "Electronics"
}

local function formatPoints(points)
	return string.format("%.1fpts", math.Round(tonumber(points) or 0, 1))
end

-- Use compact millions while preserving exact thousands below $1M.
local function formatMoney(dollars)
	dollars = tonumber(dollars) or 0
	if dollars >= 1e6 then
		return string.format("$%.1fM", dollars / 1e6)
	end
	return "$" .. string.Comma(math.Round(dollars))
end

local CostLabelByCategory = {
	Engines = "Mobility Cost",
	Firepower = "Firepower",
	Crew = "Crew Cost",
	Electronics = "Electronics Cost"
}

-- Resolve point category for a class.
local function getPointsCategory(ent)
	if not IsValid(ent) then return nil end

	local cls = ent:GetClass()
	if (ACE.ArmorClasses and ACE.ArmorClasses[cls]) or ArmorPointClasses[cls] then return "Armor" end

	return PointClassToType[cls]
end

local function getPopupPoints(ent)
	if not IsValid(ent) then return 0, "Entity Cost", "" end

	local cls = ent:GetClass()
	local con = ent:CFW_GetContraption()
	local armorPoints = ACE_GetArmorPoints and ACE_GetArmorPoints(ent) or 0
	local componentPoints = 0
	local componentLabel
	local lines = {}

	if cls == "acf_engine" then
		componentPoints = ACE_GetEntPoints and ACE_GetEntPoints(ent) or 0
		componentLabel = CostLabelByCategory.Engines
	elseif cls == "acf_gun" or cls == "acf_rack" then
		local conEnts = (con and ACE_GetContraptionEntities) and ACE_GetContraptionEntities(con, ent) or nil
		local readout = ACE_GetGunFirepowerReadout and ACE_GetGunFirepowerReadout(ent, conEnts)
		componentPoints = readout and readout.Points
			or (ACE_GetGunFirepowerPointsFor and ACE_GetGunFirepowerPointsFor(ent, conEnts))
			or (ACE_GetGunFirepowerPoints and ACE_GetGunFirepowerPoints(ent)) or 0
		componentLabel = CostLabelByCategory.Firepower

		if readout then
			local pricing = ACE_GetGunFirepowerPricingLine and ACE_GetGunFirepowerPricingLine(readout, true)
			if pricing then lines[#lines + 1] = pricing end
			if readout.MinimumApplied then
				lines[#lines + 1] = "Weapon Minimum Applied: " .. formatPoints(readout.Points)
			end
			local gunnerLine = ACE_GetGunnerMultiplierLine and ACE_GetGunnerMultiplierLine(readout)
			if gunnerLine then lines[#lines + 1] = gunnerLine end
			local floorLine = ACE_GetRateFloorLine and ACE_GetRateFloorLine(readout, true)
			if floorLine then lines[#lines + 1] = floorLine end
			local roundLine = readout.Round and ACE_GetRoundLethalityLine and ACE_GetRoundLethalityLine(readout.Round, true)
			if roundLine then lines[#lines + 1] = "Best Round: " .. roundLine end
		end
	elseif cls == "acf_ammo" then
		componentPoints = 0
		if ACE.Points.RoundFromBullet and ACE.Points.BaseRoundCost and istable(ent.BulletData) then
			local round = ACE.Points.RoundFromBullet(ent.BulletData)
			if round then
				local roundLine = ACE_GetRoundLethalityLine and ACE_GetRoundLethalityLine(round, true)
				lines[#lines + 1] = "Crate Inventory Points: 0"
				if roundLine then lines[#lines + 1] = "Best Round: " .. roundLine end
				lines[#lines + 1] = "Base Round Cost: "
					.. string.format("%.1f", ACE.Points.BaseRoundCost(round))
			end
		end
	else
		local category = getPointsCategory(ent)
		if category == "Crew" and ACE_GetCrewSeatPointCost then
			componentPoints = ACE_GetCrewSeatPointCost(ent)
		else
			componentPoints = ACE_GetEntPoints and ACE_GetEntPoints(ent) or 0
		end
		if componentPoints > 0 and category and category ~= "Armor" and category ~= "Ignore" then
			componentLabel = CostLabelByCategory[category] or (category .. " Cost")
		end
	end

	if armorPoints > 0 and componentPoints > 0 then
		table.insert(lines, 1, (componentLabel or "Component Cost") .. ": " .. formatPoints(componentPoints))
		table.insert(lines, 1, "Armor Cost: " .. formatPoints(armorPoints))
	end

	-- Manufacturing values are computed on read and are not part of combat points.
	if ACE.Manufacturing.EntCost then
		local mfgCost = ACE.Manufacturing.EntCost(ent)
		if mfgCost and mfgCost > 0 then
			lines[#lines + 1] = "Mfg. Cost: " .. formatMoney(mfgCost)
		end
	end
	local total = armorPoints + componentPoints
	-- Point-free entities may still have manufacturing lines.
	if total <= 0 and #lines == 0 then
		return 0, "Entity Cost", "", 0
	end

	local pointLabel = "Entity Cost"
	if armorPoints > 0 and componentPoints <= 0 then
		pointLabel = "Armor Cost"
	elseif componentPoints > 0 and armorPoints <= 0 then
		pointLabel = componentLabel or pointLabel
	end

	return total, pointLabel, table.concat(lines, "\n"), componentPoints
end

-- Update hover popup data for the active tool.
function TOOL:Think()
	if CLIENT then return end

	local ply	= self:GetOwner()

	local tr	= util.GetPlayerTrace(ply)
	tr.mins	= Vector(0,0,0)
	tr.maxs	= tr.mins
	local trace = util.TraceHull(tr)

	local ent = trace.Entity
	-- Primitive can expose a transient non-ACF state while it rebuilds. Do not cache that failed
	-- observation forever: the client preview divides its zero area by zero and displays "nan".
	if ent == self.AimEntity and self.AimEntityArmorReady then
		local acf = ent.ACF
		local phys = ent:GetPhysicsObject()

		if istable(acf) and IsValid(phys)
			and self.AimEntityPhysics == phys
			and self.AimEntityMass == phys:GetMass()
			and self.AimEntityArea == acf.Area
			and self.AimEntityArmor == acf.Armour
			and self.AimEntityMaxArmor == acf.MaxArmour
			and self.AimEntityHealth == acf.Health
			and self.AimEntityMaxHealth == acf.MaxHealth
			and self.AimEntityMaterial == acf.Material then
			return
		end
	end

	if ACE_Check( ent ) then

		local Mat = ent.ACF.Material or "RHA"
		local MatData = ACE_GetMaterialData( Mat )
		local AcePts, pointsLabel, pointBreakdown, componentCost = getPopupPoints(ent)

		if not MatData then return end

		ply:ConCommand( "acearmorprop_area " .. ent.ACF.Area )
		self.Weapon:SetNWFloat( "WeightMass", ent:GetPhysicsObject():GetMass() )
		self.Weapon:SetNWFloat( "HP", ent.ACF.Health )
		self.Weapon:SetNWFloat( "Armour", ent.ACF.Armour )
		self.Weapon:SetNWFloat( "MaxHP", ent.ACF.MaxHealth )
		self.Weapon:SetNWFloat( "MaxArmour", ent.ACF.MaxArmour )
		self.Weapon:SetNWString( "Material", MatData.sname or "RHA")
		self.Weapon:SetNWString( "PointCostLabel", pointsLabel )
		self.Weapon:SetNWFloat( "PointCost", AcePts )
		self.Weapon:SetNWFloat( "PointCostNonArmor", componentCost or 0 )
		self.Weapon:SetNWString( "PointCostBreakdown", pointBreakdown or "" )
		self.AimEntityPhysics = ent:GetPhysicsObject()
		self.AimEntityMass = self.AimEntityPhysics:GetMass()
		self.AimEntityArea = ent.ACF.Area
		self.AimEntityArmor = ent.ACF.Armour
		self.AimEntityMaxArmor = ent.ACF.MaxArmour
		self.AimEntityHealth = ent.ACF.Health
		self.AimEntityMaxHealth = ent.ACF.MaxHealth
		self.AimEntityMaterial = ent.ACF.Material
		self.AimEntityArmorReady = true

	else

		ply:ConCommand( "acearmorprop_area 0" )
		self.Weapon:SetNWFloat( "WeightMass", 0 )
		self.Weapon:SetNWFloat( "HP", 0 )
		self.Weapon:SetNWFloat( "Armour", 0 )
		self.Weapon:SetNWFloat( "MaxHP", 0 )
		self.Weapon:SetNWFloat( "MaxArmour", 0 )
		self.Weapon:SetNWString( "Material", "RHA" )
		self.Weapon:SetNWString( "PointCostLabel", "Entity Cost" )
		self.Weapon:SetNWFloat( "PointCost", 0 )
		self.Weapon:SetNWFloat( "PointCostNonArmor", 0 )
		self.Weapon:SetNWString( "PointCostBreakdown", "" )
		self.AimEntityPhysics = nil
		self.AimEntityMass = nil
		self.AimEntityArea = nil
		self.AimEntityArmor = nil
		self.AimEntityMaxArmor = nil
		self.AimEntityHealth = nil
		self.AimEntityMaxHealth = nil
		self.AimEntityMaterial = nil
		-- Only Primitive is known to transition from a temporary failed ACF check to a valid
		-- armor state without the player changing target. Cache all other failed targets normally.
		self.AimEntityArmorReady = not ent.IsPrimitive
	end

	self.AimEntity = ent

end

if CLIENT then
	surface.CreateFont( "Torchfont", { size = 40, weight = 1000, font = "arial" } )

	local getPhrase = language.GetPhrase

	-- Use the server pricing weights; unknown materials fall back to live material data.
	local function getArmorPointPreview(armor, health, mat, matData)
		if not ACE.Points.EffectiveMm or not ACE.Points.ArmorProp then return 0 end

		local effKE, effCHEM
		if ACE.Points.MaterialEff then
			effKE, effCHEM = ACE.Points.MaterialEff(mat)
		end
		if not effKE then
			if not matData then return 0 end
			effKE = tonumber(matData.effectiveness) or 1
			effCHEM = tonumber(matData.HEATeffectiveness or matData.effectiveness) or effKE
		end
		local curve = (matData and tonumber(matData.curve)) or 1
		local massMod = (matData and tonumber(matData.massMod)) or 1
		local threatRHAe = armor ^ curve * (0.7 * effKE + 0.3 * effCHEM)
		local hp = tonumber(health) or 0

		if threatRHAe <= 0 or hp <= 0 then return 0 end

		local massEfficiency = threatRHAe / (armor * massMod)
		return ACE.Points.ArmorProp(threatRHAe, hp, massEfficiency)
	end

	-- Helper to add centered help text; mirrors PANEL:CPanelText for this file.
	local function ArmorPanelText( name, panel, desc, font )

		if not PanelTxt then PanelTxt = {} end

		if not IsValid(PanelTxt[name .. "_aText"]) then
			PanelTxt[name .. "_aText"] = panel:Help(desc)
			PanelTxt[name .. "_aText"]:SetContentAlignment( TEXT_ALIGN_CENTER )
			PanelTxt[name .. "_aText"]:SetAutoStretchVertical(true)
			if font then PanelTxt[name .. "_aText"]:SetFont( font ) end
			PanelTxt[name .. "_aText"]:SizeToContents()

			panel:AddItem(PanelTxt[name .. "_aText"])

		end

		PanelTxt[name .. "_aText"]:SetText( desc )
		PanelTxt[name .. "_aText"]:SetSize( panel:GetWide(), 10 )
		PanelTxt[name .. "_aText"]:SizeToContentsY()

	end

	local function ArmorSpecText( material )
		local spec = material.ArmorSpec or {}
		local fields = {
			"densityKgM3", "hardnessHB", "fractureToughnessMPaSqrtM", "ductility", "kineticRHAe",
			"chemicalRHAe", "heRHAe", "kineticResilience", "chemicalResilience", "heResilience", "curve",
			"overmatchRatio", "penetrationDamageMultiplier", "multiHitRetention", "spallProduction",
			"spallResistance", "spallCapture", "shockTransmission", "residualDamageMultiplier", "tileMassKgM2",
			"singleUse", "degradation"
		}
		local values = {}

		for _, field in ipairs(fields) do
			local value = spec[field]
			if value ~= nil then
				local info = ACE.ArmorSpecFields and ACE.ArmorSpecFields[field]
				local label = info and info.label or field
				local unit = info and (" " .. info.unit) or ""
				if type(value) == "number" then value = math.Round(value, 3) end
				values[#values + 1] = label .. ": " .. tostring(value) .. unit
			end
		end

		return #values > 0 and table.concat(values, " | ") or "No physical test spec declared"
	end

	local function ArmorBehaviorConfigText( material )
		local values = {}

		for _, behaviorId in ipairs(material.BehaviorModules or {}) do
			local parameters = material.BehaviorConfig and material.BehaviorConfig[behaviorId]
			local keys = {}
			for key in pairs(parameters or {}) do keys[#keys + 1] = key end
			table.sort(keys)

			for _, key in ipairs(keys) do
				local value = parameters[key]
				if type(value) == "number" then value = math.Round(value, 3) end
				local behavior = ACE.ArmorBehaviorModules and ACE.ArmorBehaviorModules[behaviorId]
				local field = ACE.ArmorSpecFields and ACE.ArmorSpecFields[key]
				local label = (behavior and behavior.label or behaviorId) .. " / " .. (field and field.label or key)
				local unit = field and (" " .. field.unit) or ""
				values[#values + 1] = label .. "=" .. tostring(value) .. unit
			end
		end

		return #values > 0 and table.concat(values, " | ") or "No behavior overrides"
	end

	local function ArmorBehaviorText( material )
		local values = {}

		for _, behaviorId in ipairs(material.BehaviorModules or {}) do
			local behavior = ACE.ArmorBehaviorModules and ACE.ArmorBehaviorModules[behaviorId]
			if behavior then
				values[#values + 1] = behavior.label .. ": " .. behavior.description
			end
		end

		return #values > 0 and table.concat(values, "\n") or "No behavior modules declared"
	end

	-- Build or refresh the material combo box.
	local function MaterialTable( panel )

		local MaterialTypes = ACE.ArmorTypes
		if not MaterialTypes then return end

		local Material = GetConVar("acearmorprop_material"):GetString()
		local MaterialData  = MaterialTypes[Material] or MaterialTypes["RHA"]

		ArmorPanelText( "ComboBox", panel, "Material" )

		if not IsValid(ToolPanel.ComboMat) then

			ToolPanel.panel = panel

			ToolPanel.ComboMat = vgui.Create( "DComboBox" )
			ToolPanel.ComboMat:SetPos( 5, 30 )
			ToolPanel.ComboMat:SetSize( 100, 20 )
			ToolPanel.panel:AddItem(ToolPanel.ComboMat)
		else
			ToolPanel.ComboMat:Clear()
		end

		-- Rebuild the list each time to avoid stale entries.
		for _, Mat  in pairs(MaterialTypes) do
			local year = Mat.year or 0
			if (ACE.Year or 0) >= year then
				ToolPanel.ComboMat:AddChoice(Mat.sname, Mat.id )
			end
		end

		ToolPanel.ComboMat:SetValue( MaterialData.sname )

		ArmorPanelText( "ComboTitle", ToolPanel.panel, MaterialData.name , "DermaDefaultBold" )
		ArmorPanelText( "ComboDesc" , ToolPanel.panel, MaterialData.desc .. "\n" )

		ArmorPanelText( "ComboCurve", ToolPanel.panel, getPhrase("tool.acearmorprop.curve") .. ": " .. MaterialData.curve )
		ArmorPanelText( "ComboMass" , ToolPanel.panel, getPhrase("tool.acearmorprop.mass") .. ": " .. MaterialData.massMod .. "x RHA" )
		ArmorPanelText( "ComboKE"	, ToolPanel.panel, getPhrase("tool.acearmorprop.keprot") .. ": " .. MaterialData.effectiveness .. "x RHA" )
		ArmorPanelText( "ComboCHE"  , ToolPanel.panel, getPhrase("tool.acearmorprop.chemprot") .. ": " .. (MaterialData.HEATeffectiveness or MaterialData.effectiveness) .. "x RHA" )
		ArmorPanelText( "ComboYear" , ToolPanel.panel, getPhrase("tool.acearmorprop.year") .. ": " .. (MaterialData.year or "unknown") )
		ArmorPanelText( "ComboBehavior", ToolPanel.panel, "Behavior modules:\n" .. ArmorBehaviorText(MaterialData) )
		ArmorPanelText( "ComboResolver", ToolPanel.panel, "Resolver: " .. (MaterialData.ArmorResolver == "modular" and "modular with legacy-compatible tuning" or "legacy") )
		ArmorPanelText( "ComboBehaviorConfig", ToolPanel.panel, "Behavior parameters: " .. ArmorBehaviorConfigText(MaterialData) )
		ArmorPanelText( "ComboSpec", ToolPanel.panel, "Physical/test spec: " .. ArmorSpecText(MaterialData) )

		-- Update material selection from UI.
		function ToolPanel.ComboMat:OnSelect(_, value, data)
			-- Use provided material id when available; fallback to display value.
			local matId = tostring(data or value)
			RunConsoleCommand("acearmorprop_material", matId)
			self:SetValue(value)
		end
	end

	-- Build the tool control panel.
	function TOOL.BuildCPanel( panel )
		local Presets = vgui.Create( "ControlPresets" )

		Presets:AddConVar( "acearmorprop_thickness" )
		Presets:AddConVar( "acearmorprop_ductility" )
		Presets:AddConVar( "acearmorprop_material" )
		Presets:SetPreset( "acearmorprop" )

		panel:AddItem( Presets )

		panel:NumSlider( "#tool.acearmorprop.thickness", "acearmorprop_thickness", 1, 5000 )
		panel:ControlHelp( "#tool.acearmorprop.thicknessdesc" )

		panel:NumSlider( "#tool.acearmorprop.ductility", "acearmorprop_ductility", -80, 80 )
		panel:ControlHelp( "#tool.acearmorprop.ductilitydesc" )

		MaterialTable(panel)

	end

	-- When ductility changes, adjust thickness to keep mass within bounds.
	cvars.RemoveChangeCallback( "acearmorprop_ductility", "acearmorprop_ductility" ) -- Clear any prior callback so reloads do not stack.
	cvars.AddChangeCallback( "acearmorprop_ductility", function( _, _, value )

		local area = GetConVar( "acearmorprop_area" ):GetFloat()

		-- Skip if no valid area has been sampled.
		if area == 0 then return end

		local ductility = math.Clamp( ( tonumber( value ) or 0 ) / 100, -0.8, 0.8 )
		local thickness = math.Clamp( GetConVar( "acearmorprop_thickness" ):GetFloat(), 0.1, 5000 )
		local material  = GetConVar( "acearmorprop_material" ):GetString() or "RHA"

		local mass		= CalcArmor( area, ductility, thickness , material )

		if mass > 50000 then
			mass = 50000
		elseif mass < 0.1 then
			mass = 0.1
		else
			return
		end

		thickness = mass * 1000 / ( area + area * ductility ) / 0.78
		RunConsoleCommand( "acearmorprop_thickness", thickness )

	end, "acearmorprop_ductility")

	-- When thickness changes, adjust ductility to keep mass within bounds.
	cvars.RemoveChangeCallback( "acearmorprop_thickness", "acearmorprop_thickness" )
	cvars.AddChangeCallback( "acearmorprop_thickness", function( _, _, value )

		local area = GetConVar( "acearmorprop_area" ):GetFloat()

		-- Skip if no valid area has been sampled.
		if area == 0 then return end

		local thickness = math.Clamp( tonumber( value ) or 0, 0.1, 5000 )
		local ductility = math.Clamp( GetConVar( "acearmorprop_ductility" ):GetFloat() / 100, -0.8, 0.8 )
		local material  = GetConVar( "acearmorprop_material" ):GetString() or "RHA"

		local mass		= CalcArmor( area, ductility, thickness , material )

		if mass > 50000 then
			mass = 50000
		elseif mass < 0.1 then
			mass = 0.1
		else
			return
		end

		ductility = -( 39 * area * thickness - mass * 50000 ) / ( 39 * area * thickness )
		RunConsoleCommand( "acearmorprop_ductility", math.Clamp( ductility * 100, -80, 80 ) )

	end, "acearmorprop_thickness")

	-- Update material details when selection changes.
	cvars.RemoveChangeCallback( "acearmorprop_material", "acearmorprop_material" )
	cvars.AddChangeCallback( "acearmorprop_material", function( _, _, value )

			if IsValid(ToolPanel.panel) then

				local MatData = ACE_GetMaterialData( value )

				-- Fallback to RHA if the selected material is invalid.
				if not MatData then RunConsoleCommand( "acearmorprop_material", "RHA" ) return end

				-- Ensure the combo box reflects updates triggered from props.
				ToolPanel.ComboMat:SetText(MatData.sname)

				ArmorPanelText( "ComboTitle", ToolPanel.panel, MatData.name , "DermaDefaultBold" )
				ArmorPanelText( "ComboDesc" , ToolPanel.panel, MatData.desc .. "\n" )

				ArmorPanelText( "ComboCurve", ToolPanel.panel, getPhrase("tool.acearmorprop.curve") .. ": " .. MatData.curve )
				ArmorPanelText( "ComboMass" , ToolPanel.panel, getPhrase("tool.acearmorprop.mass_scale") .. ": " .. MatData.massMod .. "x RHA")
				ArmorPanelText( "ComboKE"	, ToolPanel.panel, getPhrase("tool.acearmorprop.keprot") .. " : " .. MatData.effectiveness .. "x RHA" )
				ArmorPanelText( "ComboCHE"  , ToolPanel.panel, getPhrase("tool.acearmorprop.chemprot") .. ": " .. (MatData.HEATeffectiveness or MatData.effectiveness) .. "x RHA" )
				ArmorPanelText( "ComboYear" , ToolPanel.panel, getPhrase("tool.acearmorprop.year") .. ": " .. (MatData.year or "unknown") )
				ArmorPanelText( "ComboBehavior", ToolPanel.panel, "Behavior modules:\n" .. ArmorBehaviorText(MatData) )
				ArmorPanelText( "ComboResolver", ToolPanel.panel, "Resolver: " .. (MatData.ArmorResolver == "modular" and "modular with legacy-compatible tuning" or "legacy") )
				ArmorPanelText( "ComboBehaviorConfig", ToolPanel.panel, "Behavior parameters: " .. ArmorBehaviorConfigText(MatData) )
				ArmorPanelText( "ComboSpec", ToolPanel.panel, "Physical/test spec: " .. ArmorSpecText(MatData) )

			end
	end, "acearmorprop_material")

	net.Receive("ACE_ArmorSummary", function()

		local Color1 = Color(175,0,0)
		local Color2 = Color(255,191,0)
		local Color3 = Color(255,255,100)
		local Color4 = Color(255,191,0)

		local total = math.Round( net.ReadFloat(), 1 )
		local phystotal = math.Round( net.ReadFloat(), 1 )
		local parenttotal = math.Round( net.ReadFloat(), 1 )
		local physratio = math.Round( net.ReadFloat(), 1 )
		local power = net.ReadFloat() -- Preserve precision for hp/ton calculation.

		local PointVal	= math.Round( net.ReadFloat(), 1 )
		local PtsArmor = math.Round( net.ReadFloat(), 1 )

		local ArmorInitMissing = net.ReadBool()
		local FullReadout = net.ReadBool()
		local PtsEngine = math.Round( net.ReadFloat(), 1 )
		local PtsFirepower = math.Round( net.ReadFloat(), 1 )
		local FirepowerCount = net.ReadUInt(16)
		local PtsCrew = math.Round( net.ReadFloat(), 1 )
		local PtsElectronics = math.Round( net.ReadFloat(), 1 )

		local compressedLen = net.ReadUInt(16)
		local Compressed = compressedLen > 0 and net.ReadData(compressedLen) or nil
		local Decompress = Compressed and util.Decompress(Compressed) or nil
		local FromJSON = Decompress and util.JSONToTable(Decompress) or nil
		FromJSON = istable(FromJSON) and FromJSON or { {}, {} }

	local Sep = "\n"

	local Tabletxt	= {}
	local hpton = total > 0 and math.Round(power / (total / 1000), 1) or 0

	local function addPointsLine(label, points)
		if points <= 0 then return end
		table.Add(Tabletxt, { Color4, label .. ": ", Color3, points .. "pts" .. Sep })
	end

	if FullReadout then
		table.Add(Tabletxt, { Color2, "<|", Color1, "|============|", Color2, "[- Cost Breakdown -]", Color1, "|============|", Color2, "|>" .. Sep })
		addPointsLine("Points", PointVal)
		addPointsLine("Armor Cost", PtsArmor)
		addPointsLine("Mobility Cost", PtsEngine)
		local firepowerLabel = FirepowerCount > 0 and ("Firepower (" .. FirepowerCount .. " items)") or "Firepower"
		addPointsLine(firepowerLabel, PtsFirepower)
		addPointsLine("Crew Cost", PtsCrew)
		addPointsLine("Electronics Cost", PtsElectronics)
		table.Add(Tabletxt, { Color2, "<|", Color1, "|==========================================|", Color2, "|>" .. Sep })
	else
		table.Add(Tabletxt, { Color2, "<|", Color1, "|============|", Color2, "[- Contraption Summary -]", Color1, "|============|", Color2, "|>" .. Sep })
		table.Add(Tabletxt, {
			Color4, "-Mass Ratio: ", Color3, "" .. phystotal .. "kg",
			Color4, " physical, ", Color3, "" .. parenttotal .. "kg",
			Color4, " parented / ", Color3, physratio .. "%", Color4, " physical )" .. Sep
		})

		local count = 0
		for material, _ in pairs(FromJSON[1]) do
			local percent = math.Round((FromJSON[2][material] or 0) * 100, 1)
			count = count + 1
			table.Add(Tabletxt, { Color4, material .. ": ", Color3, math.Round(percent, 0) .. "%  " .. (count > 7 and Sep or "") })
			if count > 7 then count = 0 end
		end

		table.Add(Tabletxt, { Color4, Sep })

		count = 0
		for material, mass in pairs(FromJSON[1]) do
			count = count + 1
			table.Add(Tabletxt, { Color4, material .. ": ", Color3, math.Round(mass, 1) .. "kg  " .. (count >= 3 and Sep or "") })
			if count >= 3 then count = 0 end
		end

		table.Add(Tabletxt, { Color3, Sep })

		if total > ACE.MaxWeight then
			table.Add(Tabletxt, {
				Color4, "-Total Mass: ", Color1, "" .. math.Truncate(total / 1000, 1) .. " tons",
				Color4, " / ", Color1, "" .. total .. "kg",
				Color2, "  -  ", Color1, math.Round(total - ACE.MaxWeight, 1) .. " kg over" .. Sep
			})
		else
			table.Add(Tabletxt, {
				Color4, "-Total Mass: ", Color3, "" .. math.Truncate(total / 1000, 1) .. " tons",
				Color4, " / ", Color3, "" .. total .. "kg" .. Sep
			})
		end

		table.Add(Tabletxt, {
			Color4, "-Total Power: ", Color3, "" .. math.Round(power, 1),
			Color4, " hp -> ", Color3, "" .. hpton, Color4, " hp/ton" .. Sep
		})

		local pointsColor = PointVal > ACE.PointsLimit and Color1 or Color3
		table.Add(Tabletxt, { Color4, "-Total Point Cost: ", pointsColor, PointVal .. "pts" })
		if PointVal > ACE.PointsLimit then
			table.Add(Tabletxt, { Color2, "  -  ", Color1, math.Round(PointVal - ACE.PointsLimit, 1) .. " pts over" })
		end

		table.Add(Tabletxt, { Color2, "\n<|", Color1, "|===============================================|", Color2, "|>" .. Sep })
	end

	if ArmorInitMissing then
		table.Add(Tabletxt, { Color1, Sep .. "[!] ARMOR POINTS NOT INITIALIZED. ", Color2, "Unfreeze or enter vehicle." })
	end

		chat.AddText(unpack(Tabletxt))

	end)

	local overlayTextFormat = getPhrase("tool.acearmorprop.current") .. ":\n" ..
		getPhrase("tool.acearmorprop.mass") .. ": %s\n" ..
		getPhrase("tool.acearmorprop.armor") .. ": %s\n" ..
		getPhrase("tool.acearmorprop.health") .. ": %s\n" ..
		getPhrase("tool.acearmorprop.material") .. ": %s\n" ..
		getPhrase("tool.acearmorprop.after") .. ":\n" ..
		getPhrase("tool.acearmorprop.mass") .. ": %s\n" ..
		getPhrase("tool.acearmorprop.armor") .. ": %s\n" ..
		getPhrase("tool.acearmorprop.health") .. ": %s\n" ..
		getPhrase("tool.acearmorprop.material") .. ": %s\n" ..
		"Entity Cost: %s\n\n" ..
		"%s"

	-- Draw the hover tooltip and popup text.
	function TOOL:DrawHUD()
		local ent = self:GetOwner():GetEyeTrace().Entity
		if not IsValid( ent ) or ent:IsPlayer() then return end

		local curmass	= self.Weapon:GetNWFloat( "WeightMass" )
		local curarmor	= self.Weapon:GetNWFloat( "MaxArmour" )
		local curhealth	= self.Weapon:GetNWFloat( "MaxHP" )
		local material	= self.Weapon:GetNWString( "Material" )
		local pointLabel		= self.Weapon:GetNWString( "PointCostLabel", "Entity Cost" )
		local acepointcost	= self.Weapon:GetNWFloat( "PointCost" )
		local nonArmorCost	= self.Weapon:GetNWFloat( "PointCostNonArmor", 0 )
		local pointBreakdown = self.Weapon:GetNWString( "PointCostBreakdown", "" )

		local area		= GetConVar( "acearmorprop_area" ):GetFloat()
		local ductility	= GetConVar( "acearmorprop_ductility" ):GetFloat()
		local thickness	= GetConVar( "acearmorprop_thickness" ):GetFloat()
		local mat		= GetConVar( "acearmorprop_material" ):GetString() or "RHA"

		local MatData	= ACE_GetMaterialData( mat )

		local mass, armor, health = CalcArmor( area, ductility / 100, thickness , mat)
		mass = math.min( mass, 50000 )
		-- Preserve non-armor component cost when previewing an armor change.
		local afterCost = getArmorPointPreview(armor, health, mat, MatData) + nonArmorCost

		local pointLine = ""
		if acepointcost > 0 then
			pointLine = string.format("%s: %s\n", pointLabel, formatPoints(acepointcost))
		end
		-- Point-free entities may still have manufacturing lines.
		if pointBreakdown ~= "" then
			pointLine = pointLine .. pointBreakdown .. "\n"
		end

		local text = string.format(overlayTextFormat,
			math.Round(curmass, 2),
			math.Round(curarmor, 2),
			math.Round(curhealth, 2),
			material,
			math.Round(mass, 2),
			math.Round(armor, 2),
			math.Round(health, 2),
			MatData.sname,
			formatPoints(afterCost),
			pointLine
		)

		local pos = ent:WorldSpaceCenter()
		AddWorldTip( nil, text, nil, pos, nil )

	end

	-- Draw the tool screen HUD.
	function TOOL:DrawToolScreen()

		local Health	= math.Round( self.Weapon:GetNWFloat( "HP", 0 ), 2 )
		local MaxHealth = math.Round( self.Weapon:GetNWFloat( "MaxHP", 0 ), 2 )
		local Armour	= math.Round( self.Weapon:GetNWFloat( "Armour", 0 ), 2 )
		local MaxArmour = math.Round( self.Weapon:GetNWFloat( "MaxArmour", 0 ), 2 )

		local HealthTxt = Health .. "/" .. MaxHealth
		local ArmourTxt = Armour .. "/" .. MaxArmour

		cam.Start2D()
			render.Clear( 0, 0, 0, 0 )

			surface.SetMaterial( Material( "models/props_combine/combine_interface_disp" ) )
			surface.SetDrawColor( color_white )
			surface.DrawTexturedRect( 0, 0, 256, 256 )
			surface.SetFont( "Torchfont" )

			-- Screen title.
			draw.SimpleTextOutlined( "#tool.acearmorprop.armorinfo", "Torchfont", 128, 30, Color( 224, 224, 255, 255 ), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 4, color_black )

			-- Armor progress bar.
			draw.RoundedBox( 6, 10, 83, 236, 64, Color( 200, 200, 200, 255 ) )
			if Armour ~= 0 and MaxArmour ~= 0 then
				draw.RoundedBox( 6, 15, 88, Armour / MaxArmour * 226, 54, Color( 0, 0, 200, 255 ) )
			end

			draw.SimpleTextOutlined( "#tool.acearmorprop.armor", "Torchfont", 128, 100, Color( 224, 224, 255, 255 ), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 4, color_black )
			draw.SimpleTextOutlined( ArmourTxt, "Torchfont", 128, 130, Color( 224, 224, 255, 255 ), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 4, color_black )

			-- Health progress bar.
			draw.RoundedBox( 6, 10, 183, 236, 64, Color( 200, 200, 200, 255 ) )
			if Health ~= 0 and MaxHealth ~= 0 then
				draw.RoundedBox( 6, 15, 188, Health / MaxHealth * 226, 54, Color( 200, 0, 0, 255 ) )
			end

			draw.SimpleTextOutlined( "#tool.acearmorprop.health", "Torchfont", 128, 200, Color( 224, 224, 255, 255 ), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 4, color_black )
			draw.SimpleTextOutlined( HealthTxt, "Torchfont", 128, 230, Color( 224, 224, 255, 255 ), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 4, color_black )
		cam.End2D()

	end
end
