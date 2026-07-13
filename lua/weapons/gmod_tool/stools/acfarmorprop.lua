
local cat = ((ACF.CustomToolCategory and ACF.CustomToolCategory:GetBool()) and "ACF" or "Construction");

TOOL.Category	= cat
TOOL.Name	= "#tool.acfarmorprop.name"
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

	language.Add("tool.acfarmorprop.reloadhint", "Reload: Get information about contraption")
	language.Add("tool.acfarmorprop.reloadfull", "Shift + Reload: Get full point readout")
end

-- Shared panel state used across panel rebuilds to keep UI controls stable.
local ToolPanel = ToolPanel or {}

CreateClientConVar( "acfarmorprop_area", 0, false, true ) -- Transient area cache; do not persist.

-- Compute mass, armor, and health from prop area, ductility, thickness, and material.
local function CalcArmor( Area, Ductility, Thickness, Mat )

	Mat = Mat or "RHA"

	local MatData	= ACE_GetMaterialData( Mat )
	local MassMod	= MatData.massMod

	local mass		= Area * ( 1 + Ductility ) ^ 0.5 * Thickness * 0.00078 * MassMod
	local armor		= ACF_CalcArmor( Area, Ductility, mass / MassMod )
	local health		= ( Area + Area * Ductility ) / ACF.Threshold

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

	ACE_MarkArmorDirty(con, ent)

end

duplicator.RegisterEntityModifier( "acfsettings", ApplySettings )
duplicator.RegisterEntityModifier( "mass", ApplySettings )

-- Left-click applies the current tool settings to the targeted prop.
function TOOL:LeftClick( trace )

	local ent = trace.Entity

	if not IsValid( ent ) or ent:IsPlayer() then return false end
	if CLIENT then return true end
	if not ACF_Check( ent ) then return false end

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
	if not ACF_Check( ent ) then return false end

	local ply = self:GetOwner()

	ply:ConCommand( "acfarmorprop_ductility " .. (ent.ACF.Ductility or 0) * 100 )
	ply:ConCommand( "acfarmorprop_thickness " .. ent.ACF.MaxArmour )
	ply:ConCommand( "acfarmorprop_material " .. (ent.ACF.Material or "RHA") )

	-- Clear cached target to force a fresh network update of armor values.
	self.AimEntity = nil

	return true

end

do
	-- Allow read-only armor inspection even when CanTool would block edits.
	ACE_OldHookCall = ACE_OldHookCall or hook.Call

	-- Armor tool hook override for safe reloads.
	function hook.Call(Name, Gamemode, Player, Entity, Tool, ...)
		if Name == "CanTool" and Tool == "acfarmorprop" and Player:KeyPressed(IN_RELOAD) then
			return true
		end

		return ACE_OldHookCall(Name, Gamemode, Player, Entity, Tool, ...)
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
	local data		= ACF_CalcMassRatio(ent, true) or {}

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

local function ACE_FormatPoints(points)
	points = math.Round(tonumber(points) or 0, 1)
	local whole = math.floor(points)
	local frac = math.floor((points - whole) * 10 + 0.5)
	local text = string.Comma(whole)
	if frac > 0 then text = text .. "." .. frac end
	return text .. "pts"
end

-- Use compact millions while preserving exact thousands below $1M.
local function ACE_FormatMoney(dollars)
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
local function ACE_GetPointsCategory(ent)
	if not IsValid(ent) then return nil end

	local cls = ent:GetClass()
	if (ACE.ArmorClasses and ACE.ArmorClasses[cls]) or ArmorPointClasses[cls] then return "Armor" end

	return PointClassToType[cls]
end

local function ACE_GetPopupPoints(ent)
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
			local pricing = ACE_GetGunFirepowerPricingLine and ACE_GetGunFirepowerPricingLine(readout)
			if pricing then lines[#lines + 1] = "Pricing: " .. pricing end
			if readout.MinimumApplied then
				lines[#lines + 1] = "Weapon Minimum Applied: " .. ACE_FormatPoints(readout.Points)
			end
			local roundLine = readout.Round and ACE_GetRoundLethalityLine and ACE_GetRoundLethalityLine(readout.Round)
			if roundLine then lines[#lines + 1] = "Round: " .. roundLine end
		end
	elseif cls == "acf_ammo" then
		componentPoints = 0
		if ACE_Points_RoundFromBullet and ACE_Points_BaseRoundCost and istable(ent.BulletData) then
			local round = ACE_Points_RoundFromBullet(ent.BulletData)
			if round then
				local roundLine = ACE_GetRoundLethalityLine and ACE_GetRoundLethalityLine(round)
				lines[#lines + 1] = "Crate Inventory Points: 0"
				if roundLine then lines[#lines + 1] = "Round: " .. roundLine end
				lines[#lines + 1] = "Base Round Cost: "
					.. string.Comma(math.Round(ACE_Points_BaseRoundCost(round)))
			end
		end
	else
		local category = ACE_GetPointsCategory(ent)
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
		table.insert(lines, 1, (componentLabel or "Component Cost") .. ": " .. ACE_FormatPoints(componentPoints))
		table.insert(lines, 1, "Armor Cost: " .. ACE_FormatPoints(armorPoints))
	end

	-- Manufacturing values are computed on read and are not part of combat points.
	if ACE_Manu_EntCost then
		local mfgCost = ACE_Manu_EntCost(ent)
		if mfgCost and mfgCost > 0 then
			lines[#lines + 1] = "Mfg. Cost: " .. ACE_FormatMoney(mfgCost)
		end
	end
	if con and ACE_GetContraptionEntities and ACE_Manu_ContraptionCost then
		local conMfg = ACE_Manu_ContraptionCost(ACE_GetContraptionEntities(con, ent))
		if conMfg and conMfg.Total > 0 then
			lines[#lines + 1] = "Contraption Mfg: " .. ACE_FormatMoney(conMfg.Total)
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
	if ent == self.AimEntity then return end

	if ACF_Check( ent ) then

		local Mat = ent.ACF.Material or "RHA"
		local MatData = ACE_GetMaterialData( Mat )
		local AcePts, pointsLabel, pointBreakdown, componentCost = ACE_GetPopupPoints(ent)

		if not MatData then return end

		ply:ConCommand( "acfarmorprop_area " .. ent.ACF.Area )
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

	else

		ply:ConCommand( "acfarmorprop_area 0" )
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
	end

	self.AimEntity = ent

end

if CLIENT then
	surface.CreateFont( "Torchfont", { size = 40, weight = 1000, font = "arial" } )

	local getPhrase = language.GetPhrase

	-- Use the server pricing weights; unknown materials fall back to live material data.
	local function ACE_GetArmorPointPreview(armor, health, mat, matData)
		if not ACE_Points_EffectiveMm or not ACE_Points_ArmorProp then return 0 end

		local effKE, effCHEM
		if ACE_Points_MaterialEff then
			effKE, effCHEM = ACE_Points_MaterialEff(mat)
		end
		if not effKE then
			if not matData then return 0 end
			effKE = tonumber(matData.effectiveness) or 1
			effCHEM = tonumber(matData.HEATeffectiveness or matData.effectiveness) or effKE
		end
		local effMm = ACE_Points_EffectiveMm(armor, effKE, effCHEM)
		local hp = tonumber(health) or 0

		if effMm <= 0 or hp <= 0 then return 0 end

		return ACE_Points_ArmorProp(effMm, hp)
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

	-- Build or refresh the material combo box.
	local function MaterialTable( panel )

		local MaterialTypes = ACE.ArmorTypes
		if not MaterialTypes then return end

		local Material = GetConVar("acfarmorprop_material"):GetString()
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
			if (ACF.Year or 0) >= year then
				ToolPanel.ComboMat:AddChoice(Mat.sname, Mat.id )
			end
		end

		ToolPanel.ComboMat:SetValue( MaterialData.sname )

		ArmorPanelText( "ComboTitle", ToolPanel.panel, MaterialData.name , "DermaDefaultBold" )
		ArmorPanelText( "ComboDesc" , ToolPanel.panel, MaterialData.desc .. "\n" )

		ArmorPanelText( "ComboCurve", ToolPanel.panel, getPhrase("tool.acfarmorprop.curve") .. ": " .. MaterialData.curve )
		ArmorPanelText( "ComboMass" , ToolPanel.panel, getPhrase("tool.acfarmorprop.mass") .. ": " .. MaterialData.massMod .. "x RHA" )
		ArmorPanelText( "ComboKE"	, ToolPanel.panel, getPhrase("tool.acfarmorprop.keprot") .. ": " .. MaterialData.effectiveness .. "x RHA" )
		ArmorPanelText( "ComboCHE"  , ToolPanel.panel, getPhrase("tool.acfarmorprop.chemprot") .. ": " .. (MaterialData.HEATeffectiveness or MaterialData.effectiveness) .. "x RHA" )
		ArmorPanelText( "ComboYear" , ToolPanel.panel, getPhrase("tool.acfarmorprop.year") .. ": " .. (MaterialData.year or "unknown") )

		-- Update material selection from UI.
		function ToolPanel.ComboMat:OnSelect(_, value, data)
			-- Use provided material id when available; fallback to display value.
			local matId = tostring(data or value)
			RunConsoleCommand("acfarmorprop_material", matId)
			self:SetValue(value)
		end
	end

	-- Build the tool control panel.
	function TOOL.BuildCPanel( panel )
		local Presets = vgui.Create( "ControlPresets" )

		Presets:AddConVar( "acfarmorprop_thickness" )
		Presets:AddConVar( "acfarmorprop_ductility" )
		Presets:AddConVar( "acfarmorprop_material" )
		Presets:SetPreset( "acfarmorprop" )

		panel:AddItem( Presets )

		panel:NumSlider( "#tool.acfarmorprop.thickness", "acfarmorprop_thickness", 1, 5000 )
		panel:ControlHelp( "#tool.acfarmorprop.thicknessdesc" )

		panel:NumSlider( "#tool.acfarmorprop.ductility", "acfarmorprop_ductility", -80, 80 )
		panel:ControlHelp( "#tool.acfarmorprop.ductilitydesc" )

		MaterialTable(panel)

	end

	-- When ductility changes, adjust thickness to keep mass within bounds.
	cvars.RemoveChangeCallback( "acfarmorprop_ductility", "acfarmorprop_ductility" ) -- Clear any prior callback so reloads do not stack.
	cvars.AddChangeCallback( "acfarmorprop_ductility", function( _, _, value )

		local area = GetConVar( "acfarmorprop_area" ):GetFloat()

		-- Skip if no valid area has been sampled.
		if area == 0 then return end

		local ductility = math.Clamp( ( tonumber( value ) or 0 ) / 100, -0.8, 0.8 )
		local thickness = math.Clamp( GetConVar( "acfarmorprop_thickness" ):GetFloat(), 0.1, 5000 )
		local material  = GetConVar( "acfarmorprop_material" ):GetString() or "RHA"

		local mass		= CalcArmor( area, ductility, thickness , material )

		if mass > 50000 then
			mass = 50000
		elseif mass < 0.1 then
			mass = 0.1
		else
			return
		end

		thickness = mass * 1000 / ( area + area * ductility ) / 0.78
		RunConsoleCommand( "acfarmorprop_thickness", thickness )

	end, "acfarmorprop_ductility")

	-- When thickness changes, adjust ductility to keep mass within bounds.
	cvars.RemoveChangeCallback( "acfarmorprop_thickness", "acfarmorprop_thickness" )
	cvars.AddChangeCallback( "acfarmorprop_thickness", function( _, _, value )

		local area = GetConVar( "acfarmorprop_area" ):GetFloat()

		-- Skip if no valid area has been sampled.
		if area == 0 then return end

		local thickness = math.Clamp( tonumber( value ) or 0, 0.1, 5000 )
		local ductility = math.Clamp( GetConVar( "acfarmorprop_ductility" ):GetFloat() / 100, -0.8, 0.8 )
		local material  = GetConVar( "acfarmorprop_material" ):GetString() or "RHA"

		local mass		= CalcArmor( area, ductility, thickness , material )

		if mass > 50000 then
			mass = 50000
		elseif mass < 0.1 then
			mass = 0.1
		else
			return
		end

		ductility = -( 39 * area * thickness - mass * 50000 ) / ( 39 * area * thickness )
		RunConsoleCommand( "acfarmorprop_ductility", math.Clamp( ductility * 100, -80, 80 ) )

	end, "acfarmorprop_thickness")

	-- Update material details when selection changes.
	cvars.RemoveChangeCallback( "acfarmorprop_material", "acfarmorprop_material" )
	cvars.AddChangeCallback( "acfarmorprop_material", function( _, _, value )

			if IsValid(ToolPanel.panel) then

				local MatData = ACE_GetMaterialData( value )

				-- Fallback to RHA if the selected material is invalid.
				if not MatData then RunConsoleCommand( "acfarmorprop_material", "RHA" ) return end

				-- Ensure the combo box reflects updates triggered from props.
				ToolPanel.ComboMat:SetText(MatData.sname)

				ArmorPanelText( "ComboTitle", ToolPanel.panel, MatData.name , "DermaDefaultBold" )
				ArmorPanelText( "ComboDesc" , ToolPanel.panel, MatData.desc .. "\n" )

				ArmorPanelText( "ComboCurve", ToolPanel.panel, getPhrase("tool.acfarmorprop.curve") .. ": " .. MatData.curve )
				ArmorPanelText( "ComboMass" , ToolPanel.panel, getPhrase("tool.acfarmorprop.mass_scale") .. ": " .. MatData.massMod .. "x RHA")
				ArmorPanelText( "ComboKE"	, ToolPanel.panel, getPhrase("tool.acfarmorprop.keprot") .. " : " .. MatData.effectiveness .. "x RHA" )
				ArmorPanelText( "ComboCHE"  , ToolPanel.panel, getPhrase("tool.acfarmorprop.chemprot") .. ": " .. (MatData.HEATeffectiveness or MatData.effectiveness) .. "x RHA" )
				ArmorPanelText( "ComboYear" , ToolPanel.panel, getPhrase("tool.acfarmorprop.year") .. ": " .. (MatData.year or "unknown") )

			end
	end, "acfarmorprop_material")

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

		if total > ACF.MaxWeight then
			table.Add(Tabletxt, {
				Color4, "-Total Mass: ", Color1, "" .. math.Truncate(total / 1000, 1) .. " tons",
				Color4, " / ", Color1, "" .. total .. "kg",
				Color2, "  -  ", Color1, math.Round(total - ACF.MaxWeight, 1) .. " kg over" .. Sep
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

		local pointsColor = PointVal > ACF.PointsLimit and Color1 or Color3
		table.Add(Tabletxt, { Color4, "-Total Point Cost: ", pointsColor, PointVal .. "pts" })
		if PointVal > ACF.PointsLimit then
			table.Add(Tabletxt, { Color2, "  -  ", Color1, math.Round(PointVal - ACF.PointsLimit, 1) .. " pts over" })
		end

		table.Add(Tabletxt, { Color2, "\n<|", Color1, "|===============================================|", Color2, "|>" .. Sep })
	end

	if ArmorInitMissing then
		table.Add(Tabletxt, { Color1, Sep .. "[!] ARMOR POINTS NOT INITIALIZED. ", Color2, "Unfreeze or enter vehicle." })
	end

		chat.AddText(unpack(Tabletxt))

	end)

	local overlayTextFormat = getPhrase("tool.acfarmorprop.current") .. ":\n" ..
		getPhrase("tool.acfarmorprop.mass") .. ": %s\n" ..
		getPhrase("tool.acfarmorprop.armor") .. ": %s\n" ..
		getPhrase("tool.acfarmorprop.health") .. ": %s\n" ..
		getPhrase("tool.acfarmorprop.material") .. ": %s\n" ..
		getPhrase("tool.acfarmorprop.after") .. ":\n" ..
		getPhrase("tool.acfarmorprop.mass") .. ": %s\n" ..
		getPhrase("tool.acfarmorprop.armor") .. ": %s\n" ..
		getPhrase("tool.acfarmorprop.health") .. ": %s\n" ..
		getPhrase("tool.acfarmorprop.material") .. ": %s\n" ..
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

		local area		= GetConVar( "acfarmorprop_area" ):GetFloat()
		local ductility	= GetConVar( "acfarmorprop_ductility" ):GetFloat()
		local thickness	= GetConVar( "acfarmorprop_thickness" ):GetFloat()
		local mat		= GetConVar( "acfarmorprop_material" ):GetString() or "RHA"

		local MatData	= ACE_GetMaterialData( mat )

		local mass, armor, health = CalcArmor( area, ductility / 100, thickness , mat)
		mass = math.min( mass, 50000 )
		-- Preserve non-armor component cost when previewing an armor change.
		local afterCost = ACE_GetArmorPointPreview(armor, health, mat, MatData) + nonArmorCost

		local pointLine = ""
		if acepointcost > 0 then
			pointLine = string.format("%s: %s\n", pointLabel, ACE_FormatPoints(acepointcost))
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
			ACE_FormatPoints(afterCost),
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
			draw.SimpleTextOutlined( "#tool.acfarmorprop.armorinfo", "Torchfont", 128, 30, Color( 224, 224, 255, 255 ), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 4, color_black )

			-- Armor progress bar.
			draw.RoundedBox( 6, 10, 83, 236, 64, Color( 200, 200, 200, 255 ) )
			if Armour ~= 0 and MaxArmour ~= 0 then
				draw.RoundedBox( 6, 15, 88, Armour / MaxArmour * 226, 54, Color( 0, 0, 200, 255 ) )
			end

			draw.SimpleTextOutlined( "#tool.acfarmorprop.armor", "Torchfont", 128, 100, Color( 224, 224, 255, 255 ), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 4, color_black )
			draw.SimpleTextOutlined( ArmourTxt, "Torchfont", 128, 130, Color( 224, 224, 255, 255 ), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 4, color_black )

			-- Health progress bar.
			draw.RoundedBox( 6, 10, 183, 236, 64, Color( 200, 200, 200, 255 ) )
			if Health ~= 0 and MaxHealth ~= 0 then
				draw.RoundedBox( 6, 15, 188, Health / MaxHealth * 226, 54, Color( 200, 0, 0, 255 ) )
			end

			draw.SimpleTextOutlined( "#tool.acfarmorprop.health", "Torchfont", 128, 200, Color( 224, 224, 255, 255 ), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 4, color_black )
			draw.SimpleTextOutlined( HealthTxt, "Torchfont", 128, 230, Color( 224, 224, 255, 255 ), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 4, color_black )
		cam.End2D()

	end
end





