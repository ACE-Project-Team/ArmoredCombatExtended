
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
		{ name = "reload" }
	}
end

--Used by the panel. If i can to use the TOOL itself for this, i would be really appreciated
local ToolPanel = ToolPanel or {}

CreateClientConVar( "acfarmorprop_area", 0, false, true ) -- we don't want this one to save

-- Calculates mass, armor, and health given prop area and desired ductility and thickness.
local function CalcArmor( Area, Ductility, Thickness, Mat )

	Mat = Mat or "RHA"

	local MatData	= ACE_GetMaterialData( Mat )
	local MassMod	= MatData.massMod

	local mass		= Area * ( 1 + Ductility ) ^ 0.5 * Thickness * 0.00078 * MassMod
	local armor		= ACF_CalcArmor( Area, Ductility, mass / MassMod )
	local health		= ( Area + Area * Ductility ) / ACF.Threshold

	return mass, armor, health

end


-- Apply settings to prop and store dupe info
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

	local con = ent:GetContraption()

	if con then ACE_RemPts(con, ent) end --Stupid roundabout fix. But only executed when the mat is changed. Hey if it works.

	if data.Material then
		ent.ACF = ent.ACF or {}
		ent.ACF.Material = data.Material
		duplicator.StoreEntityModifier( ent, "acfsettings", { Material = data.Material } )
	end

	if con then ACE_AddPts(con, ent) end

end

duplicator.RegisterEntityModifier( "acfsettings", ApplySettings )
duplicator.RegisterEntityModifier( "mass", ApplySettings )

-- Apply settings to prop
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

	-- this invalidates the entity and forces a refresh of networked armor values
	self.AimEntity = nil

	return true

end

-- Suck settings from prop
function TOOL:RightClick( trace )

	local ent = trace.Entity

	if not IsValid( ent ) or ent:IsPlayer() then return false end
	if CLIENT then return true end
	if not ACF_Check( ent ) then return false end

	local ply = self:GetOwner()

	ply:ConCommand( "acfarmorprop_ductility " .. (ent.ACF.Ductility or 0) * 100 )
	ply:ConCommand( "acfarmorprop_thickness " .. ent.ACF.MaxArmour )
	ply:ConCommand( "acfarmorprop_material " .. (ent.ACF.Material or "RHA") )

	-- this invalidates the entity and forces a refresh of networked armor values
	self.AimEntity = nil

	return true

end

do -- Allowing everyone to read contraptions
	ACE_OldHookCall = ACE_OldHookCall or hook.Call

	function hook.Call(Name, Gamemode, Player, Entity, Tool, ...)
		if Name == "CanTool" and Tool == "acfarmorprop" and Player:KeyPressed(IN_RELOAD) then
			return true
		end

		return ACE_OldHookCall(Name, Gamemode, Player, Entity, Tool, ...)
	end
end

-- Total up mass of constrained ents
function TOOL:Reload( trace )

	local ent = trace.Entity

	if not IsValid( ent ) or ent:IsPlayer() then return false end
	if CLIENT then return true end

	local data		= ACF_CalcMassRatio(ent, true)

	local total		= ent.acftotal
	local phystotal	= ent.acfphystotal
	local parenttotal	= ent.acftotal - ent.acfphystotal
	local physratio	= 100 * ent.acfphystotal / ent.acftotal

	local power		= data.Power

	local GeneralTb	= { data.MaterialMass, data.MaterialPercent }
	local ToJSON		= util.TableToJSON( GeneralTb )
	local Compressed	= util.Compress(ToJSON)

	local Contraption = ent:GetContraption() or nil
	local PointVal		= 0

	local PtsArmor = 0
	local PtsEngine = 0
	local PtsFirepower = 0
	local PtsFuel = 0
	local PtsAmmo = 0
	local PtsCrew = 0
	local PtsElectronics = 0

		if Contraption ~= nil then
			if ACE_EnsureArmor then
				local base = ent
				if Contraption.GetACEBaseplate then
					base = Contraption:GetACEBaseplate() or ent
				end
				ACE_EnsureArmor(Contraption, base)
			end
		PointVal		= Contraption.ACEPoints or ACE_GetEntPoints(ent) or 0
		PtsArmor = Contraption.ACEPointsPerType.Armor
		PtsEngine = Contraption.ACEPointsPerType.Engines
		PtsFirepower = Contraption.ACEPointsPerType.Firepower
		PtsFuel = Contraption.ACEPointsPerType.Fuel
		PtsAmmo = Contraption.ACEPointsPerType.Ammo
		PtsCrew = Contraption.ACEPointsPerType.Crew
		PtsElectronics = Contraption.ACEPointsPerType.Electronics
	else
		PointVal = ACE_GetEntPoints(ent)
	end

	local frontArm, sideArm = 0, 0
	if ACE_GetArmorScan then
		frontArm, sideArm = ACE_GetArmorScan(ent)
	end

	net.Start("ACE_ArmorSummary")
		net.WriteFloat(total)
		net.WriteFloat(phystotal)
		net.WriteFloat(parenttotal)
		net.WriteFloat(physratio)
		net.WriteFloat(power)
		net.WriteFloat(PointVal)
		net.WriteFloat(PtsArmor)
		net.WriteFloat(PtsEngine)
		net.WriteFloat(PtsFirepower)
		net.WriteFloat(PtsFuel)
		net.WriteFloat(PtsAmmo)
		net.WriteFloat(PtsCrew)
		net.WriteFloat(PtsElectronics)
		net.WriteFloat(frontArm)
		net.WriteFloat(sideArm)

		net.WriteData(Compressed)

	net.Send(self:GetOwner())

end

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
		local MatData =  ACE_GetMaterialData( Mat )
		local AcePts = ACE_GetEntPoints(ent)

		if not MatData then return end

		ply:ConCommand( "acfarmorprop_area " .. ent.ACF.Area )
		self.Weapon:SetNWFloat( "WeightMass", ent:GetPhysicsObject():GetMass() )
		self.Weapon:SetNWFloat( "HP", ent.ACF.Health )
		self.Weapon:SetNWFloat( "Armour", ent.ACF.Armour )
		self.Weapon:SetNWFloat( "MaxHP", ent.ACF.MaxHealth )
		self.Weapon:SetNWFloat( "MaxArmour", ent.ACF.MaxArmour )
		self.Weapon:SetNWString( "Material", MatData.sname or "RHA")
		self.Weapon:SetNWFloat( "PointCost", AcePts )

	else

		ply:ConCommand( "acfarmorprop_area 0" )
		self.Weapon:SetNWFloat( "WeightMass", 0 )
		self.Weapon:SetNWFloat( "HP", 0 )
		self.Weapon:SetNWFloat( "Armour", 0 )
		self.Weapon:SetNWFloat( "MaxHP", 0 )
		self.Weapon:SetNWFloat( "MaxArmour", 0 )
		self.Weapon:SetNWString( "Material", "RHA" )
		self.Weapon:SetNWFloat( "PointCost", 0 )
	end

	self.AimEntity = ent

end

if CLIENT then
	surface.CreateFont( "Torchfont", { size = 40, weight = 1000, font = "arial" } )

	local getPhrase = language.GetPhrase

	--Required in order to update material data inserted in client convars
	local function ACE_MaterialCheck( Material )

		--Convert old numeric IDs to the new string IDs
		local BackCompMat = {
			"RHA",
			"CHA",
			"Cer",
			"Rub",
			"ERA",
			"Alum",
			"Texto"
		}

		--Refreshing the data, so we can replace non valid data with the callback.
		if isnumber(tonumber(Material)) then

			local Mat_ID = math.Clamp(Material + 1, 1,7)
			Material = BackCompMat[Mat_ID]

			--Updates the convar with the proper material
			RunConsoleCommand( "acfarmorprop_material", Material )
		end
	end

	--Looks like client convars are not initialized very quickly, so we will wait a bit until they become valid.
	timer.Simple(0.1, function()
		ACE_MaterialCheck( GetConVar("acfarmorprop_material"):GetString() )
	end )

	--Replicated from PANEL:CPanelText(Name, Desc, Font). No idea why this doesnt work with this function out of this file
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

	-- Material ComboBox creation
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

		-- (Re)populate choices every time to avoid stale lists
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

		function ToolPanel.ComboMat:OnSelect(self, index, value, data)
			-- data carries the real material id; fallback to value if missing
			local matId = tostring(data or value)
			RunConsoleCommand("acfarmorprop_material", matId)
			self:SetValue(value)
		end
	end

	--Main menu building
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

	-- clamp thickness if the change in ductility puts mass out of range
	cvars.RemoveChangeCallback( "acfarmorprop_ductility", "acfarmorprop_ductility" ) -- Reload support
	cvars.AddChangeCallback( "acfarmorprop_ductility", function( _, _, value )

		local area = GetConVar( "acfarmorprop_area" ):GetFloat()

		-- don't bother recalculating if we don't have a valid ent
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

	-- clamp ductility if the change in thickness puts mass out of range
	cvars.RemoveChangeCallback( "acfarmorprop_thickness", "acfarmorprop_thickness" )
	cvars.AddChangeCallback( "acfarmorprop_thickness", function( _, _, value )

		local area = GetConVar( "acfarmorprop_area" ):GetFloat()

		-- don't bother recalculating if we don't have a valid ent
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

	-- Refresh Armor material info on menu
	cvars.RemoveChangeCallback( "acfarmorprop_material", "acfarmorprop_material" )
	cvars.AddChangeCallback( "acfarmorprop_material", function( _, _, value )

			if IsValid(ToolPanel.panel) then

				local MatData = ACE_GetMaterialData( value )

				--Use RHA if the choosen material is invalid or doesnt exist
				if not MatData then RunConsoleCommand( "acfarmorprop_material", "RHA" ) return end

				--Too redundant, ik, but looks like the unique way to have it working even when right clicking a prop
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
		local power		= net.ReadFloat() -- Note: intentional


		local hpton		= math.Round( power / (total / 1000), 1 )

		local PointVal	= math.Round( net.ReadFloat(), 1 )
		local PtsArmor = math.Round( net.ReadFloat(), 1 )
		local PtsEngine = math.Round( net.ReadFloat(), 1 )
		local PtsFirepower = math.Round( net.ReadFloat(), 1 )
		local PtsFuel = math.Round( net.ReadFloat(), 1 )
		local PtsAmmo = math.Round( net.ReadFloat(), 1 )
		local PtsCrew = math.Round( net.ReadFloat(), 1 )
		local PtsElectronics = math.Round( net.ReadFloat(), 1 )
		local FrontArm = math.Round( net.ReadFloat(), 2 )
		local SideArm = math.Round( net.ReadFloat(), 2 )

		local Compressed	= net.ReadData(640)
		local Decompress	= util.Decompress(Compressed)
		local FromJSON	= util.JSONToTable( Decompress )

		local Sep = "\n"

		local Tabletxt	= {}

		local PTBreakdownHeader		= { Color2, "<|",Color1, "|============|", Color2, "[- Cost Breakdown -]", Color1, "|============|",Color2, "|>" .. Sep }


		local Title		= { Color2, "<|",Color1, "|============|", Color2, "[- Contraption Summary -]", Color1, "|============|",Color2, "|>" .. Sep }
		--local ArmorComp1	= { Color4, "- Armor composition: " .. Sep }
		local TMass2		= { Color4, "-Mass Ratio: ",Color3, "" .. phystotal .. "kg", Color4, " physical, ", Color3, "" .. parenttotal .. "kg", Color4, " parented / ", Color3, physratio .. "%", Color4, " physical )" .. Sep }

		local Engine		= { Color4, "-Total Power: ", Color3, "" .. math.Round(power, 1), Color4," hp -> ",Color3, "" .. hpton, Color4, " hp/ton" .. Sep }


		--PointVal

		Tabletxt = table.Add(Tabletxt, PTBreakdownHeader)

		local TPoints = {}
		if PointVal > ACF.PointsLimit then
			local OverPoints = PointVal - ACF.PointsLimit
			TPoints		= { Color4, "Total Cost: ", Color1, "" .. PointVal .. "pts", Color2, "  -  ", Color1, OverPoints .. " pts over" .. Sep }
		else
			TPoints		= { Color4, "Total Cost: ", Color3, "" .. PointVal .. "pts" .. Sep }
		end
		table.Add(Tabletxt,TPoints)

		local FractionalPts = "/" .. PointVal
		local sideWeighted = SideArm * 2
		local cost = (FrontArm + sideWeighted) * 4
		table.Add(Tabletxt,{ Color4, "Armor scan: "})
		table.Add(Tabletxt,{ Color3, string.format("front=%.2f  side=%.2f", FrontArm, SideArm) .. Sep})
		table.Add(Tabletxt,{ Color4, "Armor: "})
		table.Add(Tabletxt,{ Color3, "(" .. math.Round(PtsArmor / PointVal * 100,0) .. "%) - " .. PtsArmor .. FractionalPts ..  Sep})
		table.Add(Tabletxt,{ Color4, "Engines: "})
		table.Add(Tabletxt,{ Color3, "(" .. math.Round(PtsEngine / PointVal * 100,0) .. "%) - " .. PtsEngine .. FractionalPts ..  Sep})
		table.Add(Tabletxt,{ Color4, "Firepower: "})
		table.Add(Tabletxt,{ Color3, "(" .. math.Round(PtsFirepower / PointVal * 100,0) .. "%) - " .. PtsFirepower .. FractionalPts ..  Sep})
		table.Add(Tabletxt,{ Color4, "Fuel: "})
		table.Add(Tabletxt,{ Color3, "(" .. math.Round(PtsFuel / PointVal * 100,0) .. "%) - " .. PtsFuel .. FractionalPts ..  Sep})
		table.Add(Tabletxt,{ Color4, "Ammo: "})
		table.Add(Tabletxt,{ Color3, "(" .. math.Round(PtsAmmo / PointVal * 100,0) .. "%) - " .. PtsAmmo .. FractionalPts ..  Sep})
		table.Add(Tabletxt,{ Color4, "Crew: "})
		table.Add(Tabletxt,{ Color3, "(" .. math.Round(PtsCrew / PointVal * 100,0) .. "%) - " .. PtsCrew .. FractionalPts ..  Sep})
		table.Add(Tabletxt,{ Color4, "Electronics: "})
		table.Add(Tabletxt,{ Color3, "(" .. math.Round(PtsElectronics / PointVal * 100,0) .. "%) - " .. PtsElectronics .. FractionalPts .. Sep})

		Tabletxt = table.Add(Tabletxt, Title)
		Tabletxt = table.Add(Tabletxt,TMass2)
		--Tabletxt = table.Add(Tabletxt,ArmorComp1)


		local Count = 0
		for material, _ in pairs( FromJSON[1] ) do
			local Percent	=  math.Round( FromJSON[2][material] * 100 ,1)
			local MatText = material .. ": "
			local MassText = math.Round(Percent,0) .. "%  "

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
		getPhrase("tool.acfarmorprop.acepoints") .. ": %s"

	function TOOL:DrawHUD()

		local ent = self:GetOwner():GetEyeTrace().Entity
		if not IsValid( ent ) or ent:IsPlayer() then return end

		local curmass	= self.Weapon:GetNWFloat( "WeightMass" )
		local curarmor	= self.Weapon:GetNWFloat( "MaxArmour" )
		local curhealth	= self.Weapon:GetNWFloat( "MaxHP" )
		local material	= self.Weapon:GetNWString( "Material" )
		local acepointcost	= self.Weapon:GetNWFloat( "PointCost" )

		local area		= GetConVar( "acfarmorprop_area" ):GetFloat()
		local ductility	= GetConVar( "acfarmorprop_ductility" ):GetFloat()
		local thickness	= GetConVar( "acfarmorprop_thickness" ):GetFloat()
		local mat		= GetConVar( "acfarmorprop_material" ):GetString() or "RHA"

		local MatData	= ACE_GetMaterialData( mat )

		local mass, armor, health = CalcArmor( area, ductility / 100, thickness , mat)
		mass = math.min( mass, 50000 )

		local text = string.format(overlayTextFormat,
			math.Round(curmass, 2),
			math.Round(curarmor, 2),
			math.Round(curhealth, 2),
			material,
			math.Round(mass, 2),
			math.Round(armor, 2),
			math.Round(health, 2),
			MatData.sname,
			math.Round(acepointcost, 1)
		)

		local pos = ent:WorldSpaceCenter()
		AddWorldTip( nil, text, nil, pos, nil )

	end

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

			-- header
			draw.SimpleTextOutlined( "#tool.acfarmorprop.armorinfo", "Torchfont", 128, 30, Color( 224, 224, 255, 255 ), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 4, color_black )

			-- armor bar
			draw.RoundedBox( 6, 10, 83, 236, 64, Color( 200, 200, 200, 255 ) )
			if Armour ~= 0 and MaxArmour ~= 0 then
				draw.RoundedBox( 6, 15, 88, Armour / MaxArmour * 226, 54, Color( 0, 0, 200, 255 ) )
			end

			draw.SimpleTextOutlined( "#tool.acfarmorprop.armor", "Torchfont", 128, 100, Color( 224, 224, 255, 255 ), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 4, color_black )
			draw.SimpleTextOutlined( ArmourTxt, "Torchfont", 128, 130, Color( 224, 224, 255, 255 ), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 4, color_black )

			-- health bar
			draw.RoundedBox( 6, 10, 183, 236, 64, Color( 200, 200, 200, 255 ) )
			if Health ~= 0 and MaxHealth ~= 0 then
				draw.RoundedBox( 6, 15, 188, Health / MaxHealth * 226, 54, Color( 200, 0, 0, 255 ) )
			end

			draw.SimpleTextOutlined( "#tool.acfarmorprop.health", "Torchfont", 128, 200, Color( 224, 224, 255, 255 ), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 4, color_black )
			draw.SimpleTextOutlined( HealthTxt, "Torchfont", 128, 230, Color( 224, 224, 255, 255 ), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 4, color_black )
		cam.End2D()

	end
end
