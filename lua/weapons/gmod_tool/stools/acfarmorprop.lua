
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

	-- Rebuild contraption points when material changes to keep totals consistent.
	if con then ACE_RemPts(con, ent) end

	if data.Material then
		ent.ACF = ent.ACF or {}
		ent.ACF.Material = data.Material
		duplicator.StoreEntityModifier( ent, "acfsettings", { Material = data.Material } )
	end

	if ACE_ClearArmorPointCache then
		ACE_ClearArmorPointCache(ent)
	end

	if con then ACE_AddPts(con, ent) end

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
	local PtsAmmo = 0
	local PtsCrew = 0
	local PtsElectronics = 0
	local ArmorInitMissing = false

	if Contraption ~= nil then
		local pointsPerType = Contraption.ACEPointsPerType or {}
		PointVal		= safeNumber(Contraption.ACEPoints or ACE_GetEntPoints(ent))
		PtsArmor = safeNumber(pointsPerType.Armor)
		PtsEngine = safeNumber(pointsPerType.Engines)
		PtsFirepower = safeNumber(pointsPerType.Firepower)
		PtsAmmo = safeNumber(pointsPerType.Ammo)
		PtsCrew = safeNumber(pointsPerType.Crew)
		PtsElectronics = safeNumber(pointsPerType.Electronics)
		ArmorInitMissing = not Contraption.ACEArmorCalculated
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
		net.WriteFloat(PtsAmmo)
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
	acf_gearbox = "Engines",
	acf_fueltank = "Ignore",
	acf_ammo = "Ammo",
	acf_gun = "Firepower",
	acf_rack = "Firepower",
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

local function ACE_GetDPSCostByTypeForGun(con, gun)
	local breakdown = {}
	if not con or not con.ents or not IsValid(gun) then return breakdown end

	local totalFirepower = ACE_GetGunFirepowerPoints and ACE_GetGunFirepowerPoints(gun) or 0
	if totalFirepower <= 0 then return breakdown end

	local weights = {}
	local totalWeight = 0
	for ent in pairs(con.ents) do
		if IsValid(ent) and ent:GetClass() == "acf_ammo" then
			local bdata = ent.BulletData
			if istable(bdata) and bdata.Id == gun.Id then
				local _, detail = ACE_GetAmmoCratePointsForContraption(ent, con, ent)
				local weight = (detail and detail.RawAmmoCost) or 0
				local ammoType = (bdata and bdata.Type) or "Ammo"
				ammoType = ammoType ~= "" and ammoType or "Ammo"
				if weight > 0 then
					weights[ammoType] = (weights[ammoType] or 0) + weight
					totalWeight = totalWeight + weight
				end
			end
		end
	end

	if totalWeight <= 0 then return breakdown end

	local totalDPS = math.max(totalFirepower - totalWeight, 0)
	if totalDPS <= 0 then return breakdown end

	for ammoType, weight in pairs(weights) do
		breakdown[ammoType] = totalDPS * (weight / totalWeight)
	end

	return breakdown
end

-- Cost of the missiles currently sitting in this rack's tubes, broken down by
-- ammo type. The cost itself is already paid through the feeding crate's
-- RawAmmoCost (rack reserve adds rounds to readyCount in ACE_BuildRackReserveAlloc),
-- so this is purely informational for the rack popup -- it tells the user
-- "your rack carries X pts of Y missiles in its tubes" without re-summing into
-- the rack's own componentPoints, which would double-count against the crate.
local function ACE_GetRackReserveCostByType(con, rack)
	local breakdown = {}
	if not con or not IsValid(rack) then return breakdown end
	if not ACE_GetRackPreloadAlloc or not ACE_GetAmmoCratePointsForContraption then return breakdown end

	local alloc = ACE_GetRackPreloadAlloc(rack, con, rack)
	if not alloc then return breakdown end

	for crate, share in pairs(alloc) do
		if IsValid(crate) and share > 0 then
			local _, detail = ACE_GetAmmoCratePointsForContraption(crate, con, crate)
			if detail then
				local readyCount = detail.ReadyCount or 0
				local cost = detail.RawAmmoCost or 0
				if readyCount > 0 and cost > 0 then
					local perMissile = cost / readyCount
					local ammoType = detail.Type
					ammoType = (ammoType and ammoType ~= "") and ammoType or "Ammo"
					breakdown[ammoType] = (breakdown[ammoType] or 0) + perMissile * share
				end
			end
		end
	end

	return breakdown
end

local function ACE_GetAmmoCostByTypeForRack(con, rack)
	local breakdown = {}
	if not con or not con.ents or not IsValid(rack) then return breakdown end
	if not ACF_CanLinkRack or not rack.Id then return breakdown end

	local totalFirepower = ACE_GetGunFirepowerPoints and ACE_GetGunFirepowerPoints(rack) or 0
	if totalFirepower <= 0 then return breakdown end

	local weights = {}
	local totalWeight = 0
	for ent in pairs(con.ents) do
		if IsValid(ent) and ent:GetClass() == "acf_ammo" then
			local bdata = ent.BulletData
			if istable(bdata) and ACF_CanLinkRack(rack.Id, bdata.Id, bdata, rack) then
				local _, detail = ACE_GetAmmoCratePointsForContraption(ent, con, ent)
				local weight = (detail and detail.RawAmmoCost) or 0
				local ammoType = bdata.Type or "Ammo"
				ammoType = ammoType ~= "" and ammoType or "Ammo"
				if weight > 0 then
					weights[ammoType] = (weights[ammoType] or 0) + weight
					totalWeight = totalWeight + weight
				end
			end
		end
	end

	if totalWeight <= 0 then return breakdown end

	local totalDPS = math.max(totalFirepower - totalWeight, 0)
	if totalDPS <= 0 then return breakdown end

	for ammoType, weight in pairs(weights) do
		breakdown[ammoType] = totalDPS * (weight / totalWeight)
	end

	return breakdown
end

local function ACE_FormatPoints(points)
	points = math.Round(tonumber(points) or 0, 1)
	local whole = math.floor(points)
	local frac = math.floor((points - whole) * 10 + 0.5)
	local text = string.Comma(whole)
	if frac > 0 then text = text .. "." .. frac end
	return text .. "pts"
end

local function ACE_FormatTypeBreakdown(breakdown)
	local entries = {}

	for ammoType, points in pairs(breakdown or {}) do
		if points > 0 then
			entries[#entries + 1] = tostring(ammoType) .. " " .. ACE_FormatPoints(points)
		end
	end

	table.sort(entries)
	return table.concat(entries, ", ")
end

local CostLabelByCategory = {
	Engines = "Mobility Cost",
	Firepower = "DPS Cost",
	Ammo = "Raw Ammo Cost",
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

-- Compute popup points and label for an entity.
-- Order: entity points, gun-caliber ammo total, then category total.
local ArmorPopupDebug = SERVER and CreateConVar("acf_debug_armor_popup", "0", FCVAR_ARCHIVE, "Debug armor popup per-entity contribution lookup.", 0, 1) or nil
local ArmorPopupDebugLast = {}

local function ACE_DebugArmorPopup(ply, ent, con, matchedRow)
	if not SERVER then return end
	if not ArmorPopupDebug or not ArmorPopupDebug:GetBool() then return end
	if not IsValid(ply) or not IsValid(ent) then return end

	local key = tostring(ply:EntIndex()) .. ":" .. tostring(ent:EntIndex())
	local now = CurTime()
	if (ArmorPopupDebugLast[key] or 0) + 1 > now then return end
	ArmorPopupDebugLast[key] = now

	local detailsCount = (con and istable(con.ACEArmorDetails) and #con.ACEArmorDetails) or 0
	local msg = string.format("[ACE popup dbg] ent=%s[#%d] class=%s details=%d matched=%s pts=%s", tostring(ent:GetNWString("WireName", ent:GetClass())), ent:EntIndex(), ent:GetClass(), detailsCount, tostring(matchedRow ~= nil), tostring(matchedRow and matchedRow.Points or 0))
	print(msg)
	ply:PrintMessage(HUD_PRINTCONSOLE, msg)
end

local function ACE_GetPopupPoints(ent, ply)
	if not IsValid(ent) then return 0, "Entity Cost", "" end

	local cls = ent:GetClass()
	local con = ent:CFW_GetContraption()
	local armorPoints = ACE_GetArmorPoints and ACE_GetArmorPoints(ent) or 0
	local componentPoints = 0
	local lines = {}

	if armorPoints > 0 then
		lines[#lines + 1] = "Armor Cost: " .. ACE_FormatPoints(armorPoints)
	end

	if cls == "acf_engine" or cls == "acf_gearbox" then
		componentPoints = ACE_GetEntPoints and ACE_GetEntPoints(ent) or 0
		if componentPoints > 0 then
			lines[#lines + 1] = CostLabelByCategory.Engines .. ": " .. ACE_FormatPoints(componentPoints)
		end
	elseif cls == "acf_gun" then
		local ammoByType = ACE_GetDPSCostByTypeForGun(con, ent)
		local text = ACE_FormatTypeBreakdown(ammoByType)

		for _, points in pairs(ammoByType) do
			componentPoints = componentPoints + points
		end

		if text ~= "" then
			lines[#lines + 1] = CostLabelByCategory.Firepower .. ": " .. text
		end
	elseif cls == "acf_rack" then
		local ammoByType = ACE_GetAmmoCostByTypeForRack(con, ent)
		local text = ACE_FormatTypeBreakdown(ammoByType)

		for _, points in pairs(ammoByType) do
			componentPoints = componentPoints + points
		end

		if text ~= "" then
			lines[#lines + 1] = CostLabelByCategory.Firepower .. ": " .. text
		end

		local reserveByType = ACE_GetRackReserveCostByType(con, ent)
		local reserveText = ACE_FormatTypeBreakdown(reserveByType)
		if reserveText ~= "" then
			-- Informational: the cost shown here is already paid through the
			-- linked crate's RawAmmoCost, so it is NOT added to componentPoints.
			lines[#lines + 1] = "Loaded Missiles (on crates): " .. reserveText
		end
	elseif cls == "acf_ammo" and ACE_GetAmmoCratePointsForContraption then
		local _, detail = ACE_GetAmmoCratePointsForContraption(ent, con, ent)
		componentPoints = (detail and detail.RawAmmoCost) or 0
		if componentPoints > 0 then
			lines[#lines + 1] = CostLabelByCategory.Ammo .. ": " .. ACE_FormatPoints(componentPoints)
		end
	else
		local category = ACE_GetPointsCategory(ent)
		if category == "Crew" and ACE_GetCrewSeatPointCost then
			componentPoints = ACE_GetCrewSeatPointCost(ent)
		else
			componentPoints = ACE_GetEntPoints and ACE_GetEntPoints(ent) or 0
		end
		if componentPoints > 0 and category and category ~= "Armor" and category ~= "Ignore" then
			local label = CostLabelByCategory[category] or (category .. " Cost")
			lines[#lines + 1] = label .. ": " .. ACE_FormatPoints(componentPoints)
		end
	end

	local total = armorPoints + componentPoints
	if total <= 0 then
		return 0, "Entity Cost", "", 0
	end

	ACE_DebugArmorPopup(ply, ent, con, nil)
	-- 4th return is the non-armor component cost; the HUD adds it to the
	-- armor preview so the "after change" estimate reflects what the entity
	-- will actually cost (e.g. ammo + new armor), not just the new armor.
	return total, "Entity Cost", table.concat(lines, "\n"), componentPoints
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
		local AcePts, pointsLabel, pointBreakdown, componentCost = ACE_GetPopupPoints(ent, ply)

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

	-- Estimate the selected armor settings with the same formula used for armor cost.
	local function ACE_GetArmorPointPreview(armor, health, matData)
		if not matData or not ACE_GetArmorPointConfig then return 0 end

		local cfg = ACE_GetArmorPointConfig()
		local curve = tonumber(matData.curve) or 1
		local effKE = tonumber(matData.effectiveness) or 1
		local effCHEM = tonumber(matData.HEATeffectiveness or matData.effectiveness) or effKE
		local weightedEff = effKE * cfg.KEWeight + effCHEM * cfg.ChemWeight
		local armorMod = ACF.ArmorMod or 1
		local effectiveMm = ((tonumber(armor) or 0) ^ curve) * weightedEff / math.max(armorMod, 0.001)
		local hp = tonumber(health) or 0

		if effectiveMm <= 0 or hp <= 0 then return 0 end

		return cfg.SurvivabilityScale * cfg.ArmorCostMultiplier
			* ((effectiveMm / math.max(cfg.DamageReferenceMm, 1)) ^ cfg.SurvivabilityArmorExponent)
			* ((hp / math.max(cfg.SurvivabilityHPReference, 1)) ^ cfg.SurvivabilityHPExponent)
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
		local PtsAmmo = math.Round( net.ReadFloat(), 1 )
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
		addPointsLine("Raw Ammo Cost", PtsAmmo)
		addPointsLine("DPS Cost", PtsFirepower)
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
		-- Future entity cost is the new armor preview plus whatever the entity
		-- already pays for non-armor reasons (ammo cost on a crate, firepower
		-- contribution on a gun/rack, crew flat, etc.). Without this, ammo
		-- crates and racks would preview their new cost as armor-only.
		local afterCost = ACE_GetArmorPointPreview(armor, health, MatData) + nonArmorCost

		local pointLine = ""
		if acepointcost > 0 then
			pointLine = string.format("%s: %s\n", pointLabel, ACE_FormatPoints(acepointcost))
			if pointBreakdown ~= "" then
				pointLine = pointLine .. pointBreakdown .. "\n"
			end
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





