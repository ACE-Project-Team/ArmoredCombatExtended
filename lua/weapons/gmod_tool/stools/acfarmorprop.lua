
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
		{ name = "reloadhint" }
	}

	language.Add("tool.acfarmorprop.reloadhint", "Get information about contraption (double-tap R for preview values)")
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

	local ply = self:GetOwner()
	local now = CurTime()
	local lastReload = ply.ACE_ArmorReloadLast or 0
	local doubleTapWindow = ACE.ArmorPreviewTapWindow or 0.35
	local doubleTap = (now - lastReload) <= doubleTapWindow
	ply.ACE_ArmorReloadLast = now

	-- Coerce numeric values and guard NaN/inf.
	local function safeNumber(value)
		value = tonumber(value) or 0
		if value ~= value or value == math.huge or value == -math.huge then
			return 0
		end
		return value
	end

	local function normalizePointDetails(rawDetails)
		local source = istable(rawDetails) and rawDetails or {}
		local details = {
			Items = istable(source.Items) and source.Items or {},
			AmmoLines = {},
			ArmorLines = {}
		}

		return details
	end

	local data		= ACF_CalcMassRatio(ent, true) or {}

	local total		= tonumber(ent.acftotal) or 0
	local phystotal	= tonumber(ent.acfphystotal) or 0
	local parenttotal	= total - phystotal
	local physratio	= total > 0 and (100 * phystotal / total) or 0

	local power		= tonumber(data.Power) or 0

	local Contraption = ent:CFW_GetContraption() or nil
	local details = Contraption and Contraption.ACEPointsDetails or nil
	local PointVal		= 0

	local PtsArmor = 0
	local PtsEngine = 0
	local PtsFirepower = 0
	local PtsAmmo = 0
	local PtsAmmoReady = 0
	local PtsAmmoBackup = 0
	local AmmoReadyRounds = 0
	local AmmoBackupRounds = 0
	local PtsCrew = 0
	local PtsElectronics = 0
	local ArmorDirty = false
	local ArmorInitMissing = false
	local HypoUsed = false
	local HypoFront = 0
	local HypoSide = 0
	local HypoPts = 0
	local HypoRequested = doubleTap
	local LegacyCost = 0

	if Contraption ~= nil then
		local pointsPerType = Contraption.ACEPointsPerType or {}
		PointVal		= safeNumber(Contraption.ACEPoints or ACE_GetEntPoints(ent))
		PtsArmor = safeNumber(pointsPerType.Armor)
		PtsEngine = safeNumber(pointsPerType.Engines)
		PtsFirepower = safeNumber(pointsPerType.Firepower)
		PtsAmmo = safeNumber(pointsPerType.Ammo)
		PtsAmmoReady = safeNumber(pointsPerType.AmmoReady)
		PtsAmmoBackup = safeNumber(pointsPerType.AmmoBackup)
		AmmoReadyRounds = safeNumber(pointsPerType.AmmoReadyRounds)
		AmmoBackupRounds = safeNumber(pointsPerType.AmmoBackupRounds)
		PtsCrew = safeNumber(pointsPerType.Crew)
		PtsElectronics = safeNumber(pointsPerType.Electronics)
		ArmorDirty = Contraption.ACEArmorDirty and Contraption.ACEArmorCalculated
		ArmorInitMissing = not Contraption.ACEArmorCalculated
	else
		PointVal = safeNumber(ACE_GetEntPoints(ent))
	end

	if Contraption ~= nil then
		LegacyCost = safeNumber(ACE_CalcContraptionLegacyCost and ACE_CalcContraptionLegacyCost(Contraption, ent) or 0)
	else
		LegacyCost = safeNumber(ACE_GetEntLegacyCost and ACE_GetEntLegacyCost(ent) or 0)
	end

	local frontArm, sideArm = 0, 0
	if Contraption ~= nil and Contraption.ACEArmorCalculated then
		frontArm = safeNumber(Contraption.ACEArmorFront)
		sideArm = safeNumber(Contraption.ACEArmorSide)
	elseif Contraption == nil and ACE_GetArmorScan then
		frontArm, sideArm = ACE_GetArmorScan(ent)
		frontArm = safeNumber(frontArm)
		sideArm = safeNumber(sideArm)
	end

	if doubleTap and ACE_GetArmorScan then
		local nextAllowed = ply.ACE_ArmorHypoNext or 0
		if now < nextAllowed then
			local wait = math.max(0, nextAllowed - now)
			ply:ChatPrint(string.format("[ACE] Armor preview is on cooldown (%.1fs).", wait))
		else
			local scanEnt = ent
			if Contraption and Contraption.GetACEBaseplate then
				local base = Contraption:GetACEBaseplate()
				if IsValid(base) then
					scanEnt = base
				end
			end
			HypoFront, HypoSide = ACE_GetArmorScan(scanEnt)
			HypoFront = safeNumber(HypoFront)
			HypoSide = safeNumber(HypoSide)
			HypoPts = safeNumber(ACE_CalcArmorPoints(HypoFront, HypoSide))
			HypoUsed = true
			if ACE_CalcNonArmorPoints and Contraption then
				local nonArmor, totals, hypoDetails = ACE_CalcNonArmorPoints(Contraption, scanEnt)
				PointVal = safeNumber(nonArmor + HypoPts)
				PtsArmor = safeNumber(HypoPts)
				PtsEngine = safeNumber(totals.Engines)
				PtsFirepower = safeNumber(totals.Firepower)
				PtsAmmo = safeNumber(totals.Ammo)
				PtsAmmoReady = safeNumber(totals.AmmoReady)
				PtsAmmoBackup = safeNumber(totals.AmmoBackup)
				AmmoReadyRounds = safeNumber(totals.AmmoReadyRounds)
				AmmoBackupRounds = safeNumber(totals.AmmoBackupRounds)
				PtsCrew = safeNumber(totals.Crew)
				PtsElectronics = safeNumber(totals.Electronics)
				details = hypoDetails
			end
			local cooldown = ACE.ArmorPreviewCooldown or 5
			ply.ACE_ArmorHypoNext = now + cooldown
		end
	end

	if HypoUsed then
		frontArm = HypoFront
		sideArm = HypoSide
	end

	local netDetails = normalizePointDetails(details)

	local GeneralTb	= { data.MaterialMass or {}, data.MaterialPercent or {}, netDetails }
	local ToJSON		= util.TableToJSON( GeneralTb )
	local Compressed	= util.Compress(ToJSON) or ""

	net.Start("ACE_ArmorSummary")
		net.WriteFloat(total)
		net.WriteFloat(phystotal)
		net.WriteFloat(parenttotal)
		net.WriteFloat(physratio)
		net.WriteFloat(power)
		net.WriteFloat(LegacyCost)
		net.WriteFloat(PointVal)
		net.WriteFloat(PtsArmor)
		net.WriteFloat(PtsEngine)
		net.WriteFloat(PtsFirepower)
		net.WriteFloat(PtsAmmo)
		net.WriteFloat(PtsAmmoReady)
		net.WriteFloat(PtsAmmoBackup)
		net.WriteFloat(AmmoReadyRounds)
		net.WriteFloat(AmmoBackupRounds)
		net.WriteFloat(PtsCrew)
		net.WriteFloat(PtsElectronics)
		net.WriteFloat(frontArm)
		net.WriteFloat(sideArm)
		net.WriteBool(ArmorDirty)
		net.WriteBool(ArmorInitMissing)
		net.WriteBool(HypoRequested)
		net.WriteBool(HypoUsed)
		net.WriteFloat(HypoFront)
		net.WriteFloat(HypoSide)
		net.WriteFloat(HypoPts)

		net.WriteUInt(#Compressed, 16)
		net.WriteData(Compressed, #Compressed)

	net.Send(self:GetOwner())

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

-- Resolve ammo caliber in millimeters.
local function ACE_GetAmmoCaliberMm(bdata)
	if not bdata then return 0 end

	local best = math.max(
		bdata.Caliber or 0,
		bdata.SlugCaliber or 0,
		bdata.SlugCaliber2 or 0,
		bdata.JetCaliber or 0
	)

	if best <= 0 and bdata.Id then
		best = ACF_GetGunValue(bdata.Id, "caliber") or 0
	end

	return best * 10
end

-- Resolve gun caliber in millimeters.
local function ACE_GetGunCaliberMm(ent)
	if not IsValid(ent) then return 0 end

	local cal = ent.Caliber or 0
	if cal <= 0 and ent.Id then
		cal = ACF_GetGunValue(ent.Id, "caliber") or 0
	end

	return cal * 10
end

-- Sum ammo points for a given caliber.
local function ACE_GetAmmoCostForCaliber(con, caliberMm)
	if not con or not con.ents or caliberMm <= 0 then return 0 end

	local target = math.floor(caliberMm + 0.5)
	local total = 0
	-- Sum ammo crate points that match the gun caliber.

	for ent in pairs(con.ents) do
		if IsValid(ent) and ent:GetClass() == "acf_ammo" then
			local cal = ACE_GetAmmoCaliberMm(ent.BulletData)
			if cal > 0 and math.floor(cal + 0.5) == target then
				total = total + (ACE_GetAmmoCratePointsForContraption(ent, con, ent) or 0)
			end
		end
	end

	return total
end

-- Sum ammo points for crates compatible with a rack.
local function ACE_GetAmmoCostForRack(con, rack)
	if not con or not con.ents or not IsValid(rack) then return 0 end
	if not ACF_CanLinkRack or not rack.Id then return 0 end

	local total = 0

	for ent in pairs(con.ents) do
		if IsValid(ent) and ent:GetClass() == "acf_ammo" then
			local bdata = ent.BulletData
			if istable(bdata) and ACF_CanLinkRack(rack.Id, bdata.Id, bdata, rack) then
				total = total + (ACE_GetAmmoCratePointsForContraption(ent, con, ent) or 0)
			end
		end
	end

	return total
end

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
	if not IsValid(ent) then return 0, "Entity Cost" end

	local cls = ent:GetClass()
	local points = 0

	if cls == "acf_ammo" and ACE_GetAmmoCratePointsForContraption then
		local con = ent:CFW_GetContraption()
		points = ACE_GetAmmoCratePointsForContraption(ent, con, ent) or 0
	elseif ACE_GetEntPoints then
		points = ACE_GetEntPoints(ent) or 0
	end

	local label = "Entity Cost"
	if points ~= 0 then return points, label end

	local con = ent:CFW_GetContraption()

	-- Guns fall back to the ammo cost for their own caliber.
	if cls == "acf_gun" then
		local gunCal = ACE_GetGunCaliberMm(ent)
		local ammoCost = ACE_GetAmmoCostForCaliber(con, gunCal)
		if ammoCost > 0 then
			points = ammoCost
			if gunCal > 0 then
				label = string.format("Total Ammo Cost (%dmm)", math.floor(gunCal + 0.5))
			else
				label = "Total Ammo Cost"
			end

			return points, label
		end
	end

	-- Racks fall back to the ammo cost of crates compatible with this rack.
	if cls == "acf_rack" then
		local ammoCost = ACE_GetAmmoCostForRack(con, ent)
		if ammoCost > 0 then
			return ammoCost, "Total Rack Ammo Cost"
		end
	end

	if con and ACE_EnsureArmor then
		ACE_EnsureArmor(con, ent, false)
	end

	local pointsPerType = con and con.ACEPointsPerType or nil
	local category = pointsPerType and ACE_GetPointsCategory(ent) or nil

	-- Armor props should use only their per-entity contribution from the armor detail table.
	if category == "Armor" then
		local matchedRow = nil
		if con and istable(con.ACEArmorDetails) then
			local idx = ent:EntIndex()
			for _, row in ipairs(con.ACEArmorDetails) do
				if istable(row) and row.EntIndex == idx then
					matchedRow = row
					local armorPts = tonumber(row.Points) or 0
					ACE_DebugArmorPopup(ply, ent, con, matchedRow)
					return armorPts, "Entity Armor Cost"
				end
			end
		end

		ACE_DebugArmorPopup(ply, ent, con, matchedRow)
		-- Never fall back armor entities to total armor category in popup.
		return 0, "Entity Armor Cost"
	end

	local categoryPts = category and pointsPerType[category] or 0
	categoryPts = tonumber(categoryPts) or 0
	if categoryPts > 0 then
		points = categoryPts
		label = "Total " .. category .. " Cost"
	end

	return points, label
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
		local AcePts, pointsLabel = ACE_GetPopupPoints(ent, ply)

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
		self.Weapon:SetNWFloat( "CostValue", ACE_GetEntLegacyCost and ACE_GetEntLegacyCost(ent) or 0 )

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
		self.Weapon:SetNWFloat( "CostValue", 0 )
	end

	self.AimEntity = ent

end

if CLIENT then
	surface.CreateFont( "Torchfont", { size = 40, weight = 1000, font = "arial" } )

	local getPhrase = language.GetPhrase

	-- Normalize legacy material values stored in client convars.
	local function ACE_MaterialCheck( Material )

		-- Map legacy numeric ids to string ids.
		local BackCompMat = {
			"RHA",
			"CHA",
			"Cer",
			"Rub",
			"ERA",
			"Alum",
			"Texto"
		}

		-- If the convar holds a legacy id, replace it with the modern id.
		if isnumber(tonumber(Material)) then

			local Mat_ID = math.Clamp(Material + 1, 1,7)
			Material = BackCompMat[Mat_ID]

			-- Write back the normalized material id.
			RunConsoleCommand( "acfarmorprop_material", Material )
		end
	end

	-- Delay normalization to allow client convars to initialize.
	timer.Simple(0.1, function()
		ACE_MaterialCheck( GetConVar("acfarmorprop_material"):GetString() )
	end )

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

		panel:CheckBox( "Show full points readout", "acf_armor_readout_full" )
		panel:ControlHelp( "Toggle the extended points readout shown on reload." )

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

		local total		= math.Round( net.ReadFloat(), 1 )
		local phystotal	= math.Round( net.ReadFloat(), 1 )
		local parenttotal	= math.Round( net.ReadFloat(), 1 )
		local physratio	= math.Round( net.ReadFloat(), 1 )
		local power		= net.ReadFloat() -- Preserve precision for hp/ton calculation.
		local LegacyCost	= math.Round( net.ReadFloat(), 1 )
		local CostDisplay	= math.Round( LegacyCost * 100, 0 )
		local CostDisplayText = string.Comma(math.max(math.floor(CostDisplay), 0))


		local hpton		= math.Round( power / (total / 1000), 1 )

		local PointVal	= math.Round( net.ReadFloat(), 1 )
		local PtsArmor = math.Round( net.ReadFloat(), 1 )
		local PtsEngine = math.Round( net.ReadFloat(), 1 )
		local PtsFirepower = math.Round( net.ReadFloat(), 1 )
		local PtsAmmo = math.Round( net.ReadFloat(), 1 )
		local PtsAmmoReady = math.Round( net.ReadFloat(), 1 )
		local PtsAmmoBackup = math.Round( net.ReadFloat(), 1 )
		net.ReadFloat()
		local _ = math.Round( net.ReadFloat(), 0 )
		local PtsCrew = math.Round( net.ReadFloat(), 1 )
		local PtsElectronics = math.Round( net.ReadFloat(), 1 )

		local quantStep = (ACE and ACE.ArmorScanConfig and ACE.ArmorScanConfig.ResultQuantizeMm) or 0
		local armDigits = 2
		if quantStep >= 1 then
			armDigits = 0
		elseif quantStep >= 0.1 then
			armDigits = 1
		end

		local FrontArm = math.Round( net.ReadFloat(), armDigits )
		local SideArm = math.Round( net.ReadFloat(), armDigits )
		local ArmorDirty = net.ReadBool()
		local ArmorInitMissing = net.ReadBool()
		local HypoRequested = net.ReadBool()
		local HypoUsed = net.ReadBool()
		net.ReadFloat()
		net.ReadFloat()
		net.ReadFloat()

		local compressedLen = net.ReadUInt(16)
		local Compressed = compressedLen > 0 and net.ReadData(compressedLen) or nil
		local Decompress = Compressed and util.Decompress(Compressed) or nil
		local FromJSON = Decompress and util.JSONToTable(Decompress) or nil

	local Sep = "\n"

	local Tabletxt	= {}

	-- Format ammo line items for the readout.
	local function formatAmmoLines(lines)
		if not istable(lines) then return {} end

		local hideBackup = false
		if ACE and ACE.AmmoCostConfig then
			hideBackup = (tonumber(ACE.AmmoCostConfig.StowFactor) or 0) == 0
		end

		local entries = {}
		for _, entry in ipairs(lines) do
			local count = tonumber(entry.Count or entry.count or 0) or 0
			local state = tostring(entry.State or entry.state or "")
			if not (hideBackup and state == "BACKUP") and count > 0 then
				entries[#entries + 1] = {
					count = math.floor(count + 0.5),
					caliber = tonumber(entry.Caliber or entry.caliber or 0) or 0,
					atype = tostring(entry.Type or entry.type or "Ammo"),
					state = state,
				points = tonumber(entry.Points or entry.points or 0) or 0
				}
			end
		end

		table.sort(entries, function(a, b)
			if a.points == b.points then
				if a.caliber == b.caliber then
					if a.atype == b.atype then
						if a.state == b.state then
							return a.count > b.count
						end
						return a.state == "READY"
					end
					return a.atype < b.atype
				end
				return a.caliber > b.caliber
			end
			return a.points > b.points
		end)

		local formatted = {}
		for _, entry in ipairs(entries) do
			local calText = entry.caliber > 0 and string.format("%dmm", entry.caliber) or "0mm"
			local stateLabel = entry.state
			if hideBackup and entry.state == "READY" then
				stateLabel = ""
			end

			local costText = ""
			if entry.state == "READY" and entry.points > 0 then
				costText = string.format(" - %.1fpts", entry.points)
			end

			formatted[#formatted + 1] = string.format("%dx%s %s%s%s", entry.count, calText, entry.atype, stateLabel ~= "" and " " .. stateLabel or "", costText)
		end

		return formatted
	end

	-- Percent helper for readout lines.
	local function pct(part, total)
		if total <= 0 then return 0 end
		return math.Round(part / total * 100, 0)
	end

	local function getMaxReadoutLines()
		return 3
	end

	-- Prebuild readout labels and summary rows.
	local PTBreakdownHeader = { Color2, "<|", Color1, "|============|", Color2, "[- Cost Breakdown -]", Color1, "|============|", Color2, "|>" .. Sep }

	local Title = { Color2, "<|", Color1, "|============|", Color2, "[- Contraption Summary -]", Color1, "|============|", Color2, "|>" .. Sep }
	local SummaryPoints
	if PointVal > ACF.PointsLimit then
		local OverPoints = PointVal - ACF.PointsLimit
		SummaryPoints = { Color4, "-Points Cost: ", Color1, "" .. PointVal .. "pts", Color2, "  -  ", Color1, OverPoints .. " pts over" .. Sep }
	else
		SummaryPoints = { Color4, "-Points Cost: ", Color3, "" .. PointVal .. "pts" .. Sep }
	end

	local SummaryCost = { Color4, "-Manufacturing Cost: ", Color3, "$" .. CostDisplayText .. Sep }
	local TMass2 = {
		Color4, "-Mass Ratio: ", Color3, "" .. phystotal .. "kg",
		Color4, " physical, ", Color3, "" .. parenttotal .. "kg",
		Color4, " parented / ", Color3, physratio .. "%", Color4, " physical )" .. Sep
	}

	local Engine = {
		Color4, "-Total Power: ", Color3, "" .. math.Round(power, 1),
		Color4, " hp -> ", Color3, "" .. hpton, Color4, " hp/ton" .. Sep
	}

	local function formatArmorLines(lines)
		if not istable(lines) then return {} end

		local entries = {}
		for _, entry in ipairs(lines) do
			if istable(entry) then
				entries[#entries + 1] = {
					label = tostring(entry.Label or entry.label or "Armor Segment"),
					points = tonumber(entry.Points or entry.points) or 0,
				}
			end
		end

		table.sort(entries, function(a, b)
			if a.points == b.points then
				return a.label < b.label
			end
			return a.points > b.points
		end)

		local formatted = {}
		for _, entry in ipairs(entries) do
			formatted[#formatted + 1] = string.format("%s: %.1f pts", entry.label, entry.points)
		end

		return formatted
	end

	local function normalizeDecodedDetails(raw)
		if not istable(raw) then
			return { Items = {}, AmmoLines = {}, ArmorLines = {} }
		end
		return {
			Items = istable(raw.Items) and raw.Items or {},
			AmmoLines = istable(raw.AmmoLines) and raw.AmmoLines or {},
			ArmorLines = istable(raw.ArmorLines) and raw.ArmorLines or {}
		}
	end

	local Details = normalizeDecodedDetails(FromJSON and FromJSON[3] or nil)
	local ammoLines = formatAmmoLines(Details.AmmoLines)
	local armorLines = formatArmorLines(Details.ArmorLines)

	-- Full readout is optional; collapsed mode only shows warnings and cost.
	local showBreakdown = not (ArmorInitMissing and not HypoUsed)
	local fullReadout = true
	local fullReadoutCvar = GetConVar( "acf_armor_readout_full" )
	if fullReadoutCvar then
		fullReadout = fullReadoutCvar:GetBool()
	end

	if not fullReadout then
		showBreakdown = false
	end
	-- Condensed mode shows warnings and core totals only.
	if not showBreakdown then
		if ArmorDirty then
			table.Add(Tabletxt, { Color1, "[!] Armor cost dirty; respawn to recalc." .. Sep })
		elseif ArmorInitMissing and not HypoUsed and not HypoRequested then
			table.Add(Tabletxt, {
				Color1,
				"[!] ARMOR COST NOT INITIALIZED. ",
				Color2,
				"Something terrible has happened. Please forward this to the devs. Frankly I don't even know how you got here." .. Sep
			})
		end
		if not ArmorInitMissing and fullReadout then
			table.Add(Tabletxt, { Color4, "Manufacturing Cost: ", Color3, "$" .. CostDisplayText .. Sep })
		end
	else
		Tabletxt = table.Add(Tabletxt, PTBreakdownHeader)
		if HypoUsed then
			table.Add(Tabletxt, { Color2, "[i] Preview mode (no points applied). Respawn to apply." .. Sep })
		end

		local TPoints = {}
		local totalLabel = HypoUsed and "Points Cost (preview): " or "Points Cost: "
		if PointVal > ACF.PointsLimit then
			local OverPoints = PointVal - ACF.PointsLimit
			TPoints = {
				Color4, totalLabel, Color1, "" .. PointVal .. "pts",
				Color2, "  -  ", Color1, OverPoints .. " pts over" .. Sep
			}
		else
			TPoints = { Color4, totalLabel, Color3, "" .. PointVal .. "pts" .. Sep }
		end
		table.Add(Tabletxt, TPoints)
		table.Add(Tabletxt, { Color4, "Manufacturing Cost: ", Color3, "$" .. CostDisplayText .. Sep })
		if ArmorDirty then
			table.Add(Tabletxt, { Color1, "[!] Armor cost dirty; respawn to recalc." .. Sep })
		elseif ArmorInitMissing and not HypoUsed then
			table.Add(Tabletxt, { Color1, "[!] ARMOR COST NOT INITIALIZED. ", Color2, "Unfreeze or enter vehicle." .. Sep })
		end

		local FractionalPts = "/" .. PointVal
		local armFmt = string.format("front=%%.%dfmm  side=%%.%dfmm", armDigits, armDigits)
		table.Add(Tabletxt, {
			Color4, "Armor scan: ", Color3, string.format(armFmt, FrontArm, SideArm) .. Sep
		})
		table.Add(Tabletxt, { Color4, "Armor: ", Color3, "(" .. pct(PtsArmor, PointVal) .. "%) - ", PtsArmor .. FractionalPts .. Sep })
		if #armorLines > 0 then
			local maxArmorLines = getMaxReadoutLines()
			for i, line in ipairs(armorLines) do
				if i > maxArmorLines then
					table.Add(Tabletxt, { Color3, "    ..." .. (#armorLines - maxArmorLines) .. " more" .. Sep })
					break
				end
				table.Add(Tabletxt, { Color3, "    " .. line .. Sep })
			end
		end
		table.Add(Tabletxt, { Color4, "Engines: ", Color3, "(" .. pct(PtsEngine, PointVal) .. "%) - ", PtsEngine .. FractionalPts .. Sep })
		if PtsFirepower > 0 then
			table.Add(Tabletxt, {
				Color4, "Firepower: ", Color3,
				"(" .. pct(PtsFirepower, PointVal) .. "%) - ", PtsFirepower .. FractionalPts .. Sep
			})
		end
		if PtsAmmo > 0 or #ammoLines > 0 or PtsAmmoReady > 0 or PtsAmmoBackup > 0 then
			table.Add(Tabletxt, { Color4, "Ammo: ", Color3, "(" .. pct(PtsAmmo, PointVal) .. "%) - ", PtsAmmo .. FractionalPts .. Sep })
			if #ammoLines > 0 then
				local maxAmmoLines = getMaxReadoutLines()
				for i, line in ipairs(ammoLines) do
					if i > maxAmmoLines then
						table.Add(Tabletxt, { Color3, "    ..." .. (#ammoLines - maxAmmoLines) .. " more" .. Sep })
						break
					end
					table.Add(Tabletxt, { Color3, "    " .. line .. Sep })
				end
			end
		end
		table.Add(Tabletxt, { Color4, "Crew: ", Color3, "(" .. pct(PtsCrew, PointVal) .. "%) - ", PtsCrew .. FractionalPts .. Sep })
		table.Add(Tabletxt, {
			Color4, "Electronics: ", Color3,
			"(" .. pct(PtsElectronics, PointVal) .. "%) - ", PtsElectronics .. FractionalPts .. Sep
		})
	end

	Tabletxt = table.Add(Tabletxt, Title)
	if not fullReadout then
		Tabletxt = table.Add(Tabletxt, SummaryPoints)
		Tabletxt = table.Add(Tabletxt, SummaryCost)
	end
	Tabletxt = table.Add(Tabletxt, TMass2)


	local Count = 0
	for material, _ in pairs(FromJSON[1]) do
		local Percent = math.Round(FromJSON[2][material] * 100, 1)
		local MatText = material .. ": "
		local MassText = math.Round(Percent, 0) .. "%  "

		Count = Count + 1
			if Count > 7 then
				Count = 0
				table.Add(Tabletxt,{ Color4, MatText})
				table.Add(Tabletxt,{ Color3, MassText .. Sep})
			else
				table.Add(Tabletxt,{ Color4, MatText})
				table.Add(Tabletxt,{ Color3, MassText})
			end

		end

		table.Add(Tabletxt,{ Color4, Sep})

		Count = 0
		for material, mass in pairs( FromJSON[1] ) do
			local MatText = material .. ": "
			local MassText = math.Round(mass,1) .. "kg  "

			Count = Count + 1
			if Count >= 3 then
				Count = 0
				table.Add(Tabletxt,{ Color4, MatText})
				table.Add(Tabletxt,{ Color3, MassText .. Sep})
			else
				table.Add(Tabletxt,{ Color4, MatText})
				table.Add(Tabletxt,{ Color3, MassText})
			end

		end


		table.Add(Tabletxt,{Color3,Sep})

		Tabletxt = table.Add(Tabletxt,TbStr)

		local TMass = {}
		if total > ACF.MaxWeight then
			local OverTons = total - ACF.MaxWeight
			TMass		= { Color4, "-Total Mass: ", Color1, "" .. math.Truncate(total / 1000,1) .. " tons", Color4, " / ", Color1, "" .. total .. "kg", Color2, "  -  ", Color1, OverTons .. " kg over" .. Sep }
		else
			TMass		= { Color4, "-Total Mass: ", Color3, "" .. math.Truncate(total / 1000,1) .. " tons", Color4, " / ", Color3, "" .. total .. "kg" .. Sep }
		end

		Tabletxt = table.Add(Tabletxt,TMass)
		Tabletxt = table.Add(Tabletxt,Engine)

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
		getPhrase("tool.acfarmorprop.material") .. ": %s\n\n" ..
		"%s" ..
		"Manufacturing Cost: $%s"

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
		local acecost		= self.Weapon:GetNWFloat( "CostValue", 0 )

		local area		= GetConVar( "acfarmorprop_area" ):GetFloat()
		local ductility	= GetConVar( "acfarmorprop_ductility" ):GetFloat()
		local thickness	= GetConVar( "acfarmorprop_thickness" ):GetFloat()
		local mat		= GetConVar( "acfarmorprop_material" ):GetString() or "RHA"

		local MatData	= ACE_GetMaterialData( mat )

		local mass, armor, health = CalcArmor( area, ductility / 100, thickness , mat)
		mass = math.min( mass, 50000 )

		local pointLine = ""
		if acepointcost > 0 then
			local roundedPoints = math.Round(acepointcost, 1)
			local whole = math.floor(roundedPoints)
			local frac = math.floor((roundedPoints - whole) * 10 + 0.5)
			local pointText = string.Comma(whole)
			if frac > 0 then
				pointText = pointText .. "." .. frac
			end
			pointLine = string.format("%s: %spts\n", pointLabel, pointText)
		end

		local costText = string.Comma(math.max(math.Round(acecost * 100, 0), 0))

		local text = string.format(overlayTextFormat,
			math.Round(curmass, 2),
			math.Round(curarmor, 2),
			math.Round(curhealth, 2),
			material,
			math.Round(mass, 2),
			math.Round(armor, 2),
			math.Round(health, 2),
			MatData.sname,
			pointLine,
			costText
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





