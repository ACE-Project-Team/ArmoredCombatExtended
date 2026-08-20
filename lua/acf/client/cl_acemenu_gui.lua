--[[------------------------
	1.- This is the file that displays the main menu, such as guns, ammo, mobility and subfolders.

	2.- Almost everything here has been documented, you should find the responsible function easily.

	3.- If you are going to do changes, please not to be a shitnuckle and write a note alongside the code that you´ve changed/edited. This should avoid issues with future developers.

]]--------------------------

local Classes = ACE.Classes
local ACFEnts = ACE.Weapons

local radarClasses    = Classes.Radar
local radars          = ACFEnts.Radars

local MainMenuIcon = "icon16/world.png"
local ItemIcon = "icon16/brick.png"
local ItemIcon2 = "icon16/newspaper.png"

local function AmmoBuildList( ParentNode, NodeName, AmmoTable )

	local AmmoNode = ParentNode:AddNode( NodeName, ItemIcon )

	table.sort(AmmoTable, function(a,b) return a.id < b.id end )

	for _,AmmoTable in pairs(AmmoTable) do

		local EndNode = AmmoNode:AddNode( AmmoTable.name or "No Name" )
		EndNode.mytable = AmmoTable

		function EndNode:DoClick()
			RunConsoleCommand( "acemenu_type", self.mytable.type )
			acemenupanel:UpdateDisplay( self.mytable )
		end

		EndNode.Icon:SetImage( ItemIcon2 )

	end
end

function PANEL:Init( )

	acemenupanel = self.Panel

	-- -- height
	self:SetTall( ScrH() - 150 )

	-- --Weapon Select
	local TreePanel = vgui.Create( "DTree", self )

--[[=========================
	Table distribution
]]--=========================

	self.GunClasses		= {}
	self.MisClasses		= {}
	self.ModClasses		= {}

	local FinalContainer = {}

	for ID,Table in pairs(Classes) do

		self.GunClasses[ID] = {}
		self.MisClasses[ID] = {}
		self.ModClasses[ID] = {}

		for ClassID,Class in pairs(Table) do

			Class.id = ClassID

			--Table content for Guns folder
			if Class.type == "Gun" then

				--print("Gun detected!")
				table.insert(self.GunClasses[ID], Class)

			--Table content for Missiles folder
			elseif Class.type == "missile" then

				--print("Missile detected!")
				table.insert(self.MisClasses[ID], Class)

			else

				--print("Modded Gun detected!")
				table.insert(self.ModClasses[ID], Class)

			end

		end

		table.sort(self.GunClasses[ID], function(a,b) return a.id < b.id end )
		table.sort(self.MisClasses[ID], function(a,b) return a.id < b.id end )
		table.sort(self.ModClasses[ID], function(a,b) return a.id < b.id end )

	end

	for ID,Table in pairs(ACFEnts) do

		FinalContainer[ID] = {}

		for _,Data in pairs(Table) do
			table.insert( FinalContainer[ID], Data )
		end

		if ID == "Guns" then
			table.sort(FinalContainer[ID], function(a,b) if a.gunclass == b.gunclass then return a.caliber < b.caliber else return a.gunclass < b.gunclass end end)
		else
			table.sort(FinalContainer[ID], function(a,b) return a.id < b.id end )
		end

	end


	------------------- ACE information folder -------------------


	HomeNode = TreePanel:AddNode( "ACE Main Menu" , MainMenuIcon ) --Main Menu folder
	HomeNode:SetExpanded(true)
	HomeNode.mytable = {}
	HomeNode.mytable.guicreate = (function( _, Table ) ACE.HomeGUICreate( Table ) end or nil)
	HomeNode.mytable.guiupdate = (function( _, Table ) ACE.HomeGUIUpdate( Table ) end or nil)

	function HomeNode:DoClick()
		acemenupanel:UpdateDisplay(self.mytable)
	end

	------------------- Guns folder -------------------

	local Guns = HomeNode:AddNode( "Guns" , "icon16/attach.png" ) --Guns folder

	for _,Class in pairs(self.GunClasses["GunClass"]) do

		local SubNode = Guns:AddNode( Class.name or "No Name" , ItemIcon )

		for _, Ent in pairs(FinalContainer["Guns"]) do
			if Ent.gunclass == Class.id then

				local EndNode = SubNode:AddNode( Ent.name or "No Name")
				EndNode.mytable = Ent

				function EndNode:DoClick()
					RunConsoleCommand( "acemenu_type", self.mytable.type )
					acemenupanel:UpdateDisplay( self.mytable )
				end

				EndNode.Icon:SetImage( "icon16/newspaper.png" )
			end
		end
	end

	------------------- Missiles folder -------------------

	local Missiles = HomeNode:AddNode( "Missiles" , "icon16/wand.png" ) --Missiles folder

	for _,Class in pairs(self.MisClasses["GunClass"]) do

		local SubNode = Missiles:AddNode( Class.name or "No Name" , ItemIcon )

		for _, Ent in pairs(FinalContainer["Guns"]) do
			if Ent.gunclass == Class.id then

				local EndNode = SubNode:AddNode( Ent.name or "No Name")
				EndNode.mytable = Ent

				function EndNode:DoClick()
				RunConsoleCommand( "acemenu_type", self.mytable.type )
				acemenupanel:UpdateDisplay( self.mytable )
				end
				EndNode.Icon:SetImage( "icon16/newspaper.png" )
			end
		end
	end


	------------------- Ammo folder -------------------

	local Ammo = HomeNode:AddNode( "Ammo" , "icon16/box.png" ) --Ammo folder

	AmmoBuildList( Ammo, "Armor Piercing Rounds", list.Get("APRoundTypes") ) -- AP Content
	AmmoBuildList( Ammo, "High Explosive Rounds", list.Get("HERoundTypes") )	-- HE/HEAT Content
	AmmoBuildList( Ammo, "Special Purpose Rounds", list.Get("SPECSRoundTypes") ) -- Special Content

	-- Explosives live under Ammo. One entry ("Explosives") that opens the scalable
	-- charge config directly - shape/size are chosen inside the menu, no extra leaf.
	for _, Data in pairs(FinalContainer["Explosives"] or {}) do
		local ExploNode = Ammo:AddNode("Explosives", "icon16/bomb.png")
		ExploNode.mytable = Data
		function ExploNode:DoClick()
			RunConsoleCommand("acemenu_type", self.mytable.type)
			acemenupanel:UpdateDisplay(self.mytable)
		end
		break
	end

	do
		--[[==================================================
							Mobility folder
		]]--==================================================

		local Mobility    = HomeNode:AddNode( "Mobility" , "icon16/car.png" )	--Mobility folder
		local Engines     = Mobility:AddNode( "Engines" , ItemIcon )
		local Gearboxes   = Mobility:AddNode( "Gearboxes" , ItemIcon  )
		local FuelTanks   = Mobility:AddNode( "Fuel Tanks" , ItemIcon  )

		local EngineCatNodes    = {} --Stores all Engine Cats Nodes (V12, V8, I4, etc)
		local GearboxCatNodes   = {} --Stores all Gearbox Cats Nodes (CVT, Transfer, etc)

		-------------------- Engine folder --------------------

		--TODO: Do a menu like fueltanks to engines & gearboxes? Would be cleaner.

		--Creates the engine category
		for _, EngineData in pairs(FinalContainer["Engines"]) do

			local category = EngineData.category or "Missing Cat?"

			if not EngineCatNodes[category] then

				local Node = Engines:AddNode(category , ItemIcon)

				EngineCatNodes[category] = Node

			end
		end

		--Populates engine categories
		for _, EngineData in pairs(FinalContainer["Engines"]) do

			local name = EngineData.name or "Missing Name"
			local category = EngineData.category or ""

			if EngineCatNodes[category] then
				local Item = EngineCatNodes[category]:AddNode( name, ItemIcon )

				function Item:DoClick()
				RunConsoleCommand( "acemenu_type", EngineData.type )
				acemenupanel:UpdateDisplay( EngineData )
				end
			end
		end

		-------------------- Gearbox folder --------------------

		--Creates the gearbox category
		for _, GearboxData in pairs(FinalContainer["Gearboxes"]) do

			local category = GearboxData.category

			if not GearboxCatNodes[category] then

				local Node = Gearboxes:AddNode(category or "Missing?" , ItemIcon)

				GearboxCatNodes[category] = Node

			end
		end

		--Populates gearbox categories
		for _, GearboxData in pairs(FinalContainer["Gearboxes"]) do

			local name = GearboxData.name or "Missing Name"
			local category = GearboxData.category or ""

			if GearboxCatNodes[category] then
				local Item = GearboxCatNodes[category]:AddNode( name, ItemIcon )

				function Item:DoClick()
				RunConsoleCommand( "acemenu_type", GearboxData.type )
				acemenupanel:UpdateDisplay( GearboxData )
				end
			end
		end

		-------------------- FuelTank folder --------------------

		--Creates the only button to access to fueltank config menu.
		for _, FuelTankData in pairs(FinalContainer["FuelTanks"]) do

			function FuelTanks:DoClick()
				RunConsoleCommand( "acemenu_type", FuelTankData.type )
				acemenupanel:UpdateDisplay( FuelTankData )
			end

			break
		end
	end
	do
		--[[==================================================
							Sensor folder
		]]--==================================================

		local sensors	= HomeNode:AddNode("Sensors" , "icon16/transmit.png") --Sensor folder name

		local antimissile = sensors:AddNode("Anti-Missile Radar" , ItemIcon  )
		local tracking	= sensors:AddNode("Tracking Radar", ItemIcon)
		local search	= sensors:AddNode("Search Radar", ItemIcon)
		local sonar		= sensors:AddNode("Sonar Array", ItemIcon)
		local irst		= sensors:AddNode("IRST", ItemIcon)

		local nods = {}

		if radarClasses then
			for k, v in pairs(radarClasses) do  --calls subfolders
				if v.type == "Anti-missile" then
					nods[k] = antimissile:AddNode( v.name or "No Name" , ItemIcon	)
				elseif v.type == "Tracking-Radar" then
					nods[k] = tracking
				elseif v.type == "Search-Radar" then
					nods[k] = search
				elseif v.type == "Sonar" then
					nods[k] = sonar
				elseif v.type == "IRST" then
					nods[k] = irst
				end
			end

			--calls subfolders content
			for _, Ent in pairs(radars) do

				local curNode = nods[Ent.class]

				if curNode then

					local EndNode = curNode:AddNode( Ent.name or "No Name" )
					EndNode.mytable = Ent

					function EndNode:DoClick()
						RunConsoleCommand( "acemenu_type", self.mytable.type )
						acemenupanel:UpdateDisplay( self.mytable )
					end
					EndNode.Icon:SetImage( "icon16/newspaper.png" )
				end
			end --end radar folder
		end

	end
	do
	--[[==================================================
						Tools folder
	]]--==================================================

	local toolsNode	= HomeNode:AddNode("Tools" , "icon16/plugin.png") --Tools folder name

		for _, ToolData in pairs(FinalContainer["Tools"]) do
			local ItemNode = toolsNode:AddNode( ToolData.name or "No Name" , ItemIcon2 )
			function ItemNode:DoClick()
				RunConsoleCommand( "acemenu_type", ToolData.type )
				acemenupanel:UpdateDisplay( ToolData )
			end
		end

	end
	do
	--[[==================================================
						Crew folder
	]]--==================================================

		local CrewNode = HomeNode:AddNode("Crew", "icon16/user.png")

		CrewNode.mytable = {
			-- IMPORTANT: default to a valid crewseat so left-click spawns something even if user doesn't touch UI
			type = "Crewseats",
			id = "Crewseat_Driver",
			guicreate = function(_, Table) ACE.CrewMenuGUICreate(Table) end,
			guiupdate = function() return end
		}

		function CrewNode:DoClick()
			acemenupanel:UpdateDisplay(self.mytable)
		end
	end
	do
	--[[==================================================
						Extras folder
	]]--==================================================

		local extrasNode = HomeNode:AddNode("Extras", "icon16/bricks.png")

		for _, ExtrasData in pairs(FinalContainer["Extras"] or {}) do
			local ItemNode = extrasNode:AddNode(ExtrasData.name or "No Name", ItemIcon2)
			ItemNode.mytable = ExtrasData

			function ItemNode:DoClick()
				RunConsoleCommand("acemenu_type", self.mytable.type)
				acemenupanel:UpdateDisplay(self.mytable)
			end
		end
	end
	do

	--[[==================================================
						Settings folder
	]]--==================================================

	local OptionsNode = TreePanel:AddNode( "Settings" ) --Options folder

	local CLNod	= OptionsNode:AddNode("Client" , "icon16/user.png") --Client folder
	local SVNod	= OptionsNode:AddNode("Server", "icon16/cog.png")  --Server folder

	CLNod.mytable  = {}
	SVNod.mytable  = {}

	CLNod.mytable.guicreate = (function( _, Table ) ACE.CLGUICreate( Table ) end or nil)
	SVNod.mytable.guicreate = (function( _, Table ) ACE.SVGUICreate( Table ) end or nil)

	function CLNod:DoClick()
		acemenupanel:UpdateDisplay(self.mytable)
	end
	function SVNod:DoClick()
		acemenupanel:UpdateDisplay(self.mytable)
	end
	OptionsNode.Icon:SetImage( "icon16/wrench_orange.png" )

	end

	do

	--[[==================================================
					Contact & Support folder
	]]--==================================================

	local Contact =  TreePanel:AddNode( "Contact Us" , "icon16/feed.png" ) --Options folder
	Contact.mytable = {}

	Contact.mytable.guicreate = (function( _, Table ) ACE.ContactGUICreate( Table ) end or nil)

	function Contact:DoClick()
		acemenupanel:UpdateDisplay(self.mytable)
	end

	end

	self.WeaponSelect = TreePanel

end

function PANEL:UpdateRoundCostPreview()

	local DisplayTable = self.ActiveDisplayTable
	if not istable(DisplayTable) or DisplayTable.type ~= "Ammo" or DisplayTable.Type == "Refill" then return end
	if not ACE.GetRoundFromCVars or not ACE.Points.RoundFromBullet or not ACE.Points.BaseRoundCost then return end
	if not IsValid(self.CustomDisplay) then return end

	local RoundType = ACE.RoundTypes[DisplayTable.Type or ""]
	if not RoundType or not isfunction(RoundType.convert) then return end

	local RawData = ACE.GetRoundFromCVars()
	local Success, BulletData = pcall(RoundType.convert, self, RawData)
	if not Success or not istable(BulletData) then return end
	BulletData.Id = RawData.Id
	BulletData.Type = DisplayTable.Type or RawData.Type
	BulletData.Data7 = RawData.Data7

	local Round = ACE.Points.RoundFromBullet(BulletData)
	if not Round then return end

	local Cost = string.Comma(math.Round(ACE.Points.BaseRoundCost(Round)))
	self:CPanelText("ACEBaseRoundCost", "Base Round Cost: " .. Cost .. "\nCrate Inventory Points: 0", "DermaDefaultBold")
	self.CustomDisplay:PerformLayout()

end

function PANEL:QueueRoundCostPreview()

	local DisplayTable = self.ActiveDisplayTable
	self.RoundCostPreviewToken = (self.RoundCostPreviewToken or 0) + 1
	local Token = self.RoundCostPreviewToken
	timer.Simple(0, function()
		if not IsValid(self) or self.ActiveDisplayTable ~= DisplayTable or self.RoundCostPreviewToken ~= Token then return end
		self:UpdateRoundCostPreview()
	end)

end

function PANEL:UpdateDisplay( Table )

	RunConsoleCommand( "acemenu_id", Table.id or 0 )

	--If a previous display exists, erase it
	if ( acemenupanel.CustomDisplay ) then
	acemenupanel.CustomDisplay:Clear(true)
	acemenupanel.CustomDisplay = nil
	acemenupanel.CData = nil
	end
	--Create the space to display the custom data
	acemenupanel.CustomDisplay = vgui.Create( "DPanelList", acemenupanel )
	acemenupanel.CustomDisplay:SetSpacing( 10 )
	acemenupanel.CustomDisplay:EnableHorizontal( false )
	acemenupanel.CustomDisplay:EnableVerticalScrollbar( false )
	acemenupanel.CustomDisplay:SetSize( acemenupanel:GetWide(), acemenupanel:GetTall() )

	if not acemenupanel["CData"] then
	--Create a table for the display to store data
	acemenupanel["CData"] = {}
	end

	acemenupanel.ActiveDisplayTable = Table
	acemenupanel.CreateAttribs = Table.guicreate

	local UpdateAttribs = Table.guiupdate
	if Table.type == "Ammo" and isfunction(UpdateAttribs) then
		acemenupanel.UpdateAttribs = function(Panel, ...)
			local Result = UpdateAttribs(Panel, ...)
			Panel:QueueRoundCostPreview()
			return Result
		end
	else
		acemenupanel.UpdateAttribs = UpdateAttribs
	end

	acemenupanel:CreateAttribs( Table )
	acemenupanel:QueueRoundCostPreview()

	acemenupanel:PerformLayout()

end

function PANEL:PerformLayout()

	--Starting positions
	local vspacing = 10
	local ypos = 0

	--Selection Tree panel
	acemenupanel.WeaponSelect:SetPos( 0, ypos )
	acemenupanel.WeaponSelect:SetSize( acemenupanel:GetWide(), ScrH() * 0.4 )
	ypos = acemenupanel.WeaponSelect.Y + acemenupanel.WeaponSelect:GetTall() + vspacing

	if acemenupanel.CustomDisplay then
	--Custom panel
	acemenupanel.CustomDisplay:SetPos( 0, ypos )
	acemenupanel.CustomDisplay:SetSize( acemenupanel:GetWide(), acemenupanel:GetTall() - acemenupanel.WeaponSelect:GetTall() - 10 )
	ypos = acemenupanel.CustomDisplay.Y + acemenupanel.CustomDisplay:GetTall() + vspacing
	end

end

--[[=========================
	ACE information folder content
]]--=========================
function ACE.HomeGUICreate()

	if not acemenupanel.CustomDisplay then return end

	local versionstring

	if ACE.CurrentVersion and ACE.CurrentVersion > 0 then
	if ACE.Version >= ACE.CurrentVersion then
		versionstring = "Up To Date"
		color = Color(0,225,0,255)
	else
		versionstring = "Out Of Date"
		color = Color(225,0,0,255)

	end
	else
	versionstring = "No internet Connection available!"
	color = Color(225,0,0,255)
	end

	local versiontext = "GitHub Version: " .. ACE.CurrentVersion .. "\nCurrent Version: " .. ACE.Version

	acemenupanel["CData"]["VersionInit"] = vgui.Create( "DLabel" )
	acemenupanel["CData"]["VersionInit"]:SetText(versiontext)
	acemenupanel["CData"]["VersionInit"]:SetDark( true )
	acemenupanel["CData"]["VersionInit"]:SizeToContents()
	acemenupanel.CustomDisplay:AddItem( acemenupanel["CData"]["VersionInit"] )


	acemenupanel["CData"]["VersionText"] = vgui.Create( "DLabel" )

	acemenupanel["CData"]["VersionText"]:SetFont("Trebuchet18")
	acemenupanel["CData"]["VersionText"]:SetText("ACE Is " .. versionstring .. "!\n\n")
	acemenupanel["CData"]["VersionText"]:SetDark( true )
	acemenupanel["CData"]["VersionText"]:SizeToContents()

	acemenupanel.CustomDisplay:AddItem( acemenupanel["CData"]["VersionText"] )
	-- end version

	acemenupanel:CPanelText("Header", "Changelog")  --changelog screen

--[[=========================
	Changelog table maker
]]--=========================

	if acemenupanel.Changelog then
	acemenupanel["CData"]["Changelist"] = vgui.Create( "DTree" )

	for i = 0, table.maxn(acemenupanel.Changelog) - 100 do

		local k = table.maxn(acemenupanel.Changelog) - i

		local Node = acemenupanel["CData"]["Changelist"]:AddNode( "Rev " .. k )
			Node.mytable = {}
			Node.mytable["rev"] = k
				function Node:DoClick()

				acemenupanel:UpdateAttribs( Node.mytable )

			end
		Node.Icon:SetImage( "icon16/newspaper.png" )

	end

	acemenupanel.CData.Changelist:SetSize( acemenupanel.CustomDisplay:GetWide(), 60 )

	acemenupanel.CustomDisplay:AddItem( acemenupanel["CData"]["Changelist"] )

	acemenupanel.CustomDisplay:PerformLayout()

	acemenupanel:UpdateAttribs( {rev = table.maxn(acemenupanel.Changelog)} )
	end

end

--[[=========================
	ACE information folder content updater
]]--=========================
function ACE.HomeGUIUpdate( Table )

	acemenupanel:CPanelText("Changelog", acemenupanel.Changelog[Table["rev"]])
	acemenupanel.CustomDisplay:PerformLayout()

	local color
	local versionstring

	if ACE.CurrentVersion > 0 then
		if ACE.Version >= ACE.CurrentVersion then
			versionstring = "Up To Date"
			color = Color(0,225,0,255)
		else
			versionstring = "Out Of Date"
			color = Color(225,0,0,255)
		end
	else
		versionstring = "No internet Connection available!"
		color = Color(225,0,0,255)
	end

	local txt

	if ACE.CurrentVersion > 0 then
		txt = "ACE Is " .. versionstring .. "!\n\n"
	else
		txt = versionstring
	end

	acemenupanel["CData"]["VersionText"]:SetText(txt)
	acemenupanel["CData"]["VersionText"]:SetDark( true )
	acemenupanel["CData"]["VersionText"]:SetColor(color)
	acemenupanel["CData"]["VersionText"]:SizeToContents()

end

--[[=========================
	Changelog.txt
]]--=========================

function ACE.ChangelogHTTPCallBack(contents)
	local Temp = string.Explode( "*", contents )

	acemenupanel.Changelog = {}  --changelog table
	for _,String in pairs(Temp) do
		acemenupanel.Changelog[tonumber(string.sub(String,2,4))] = string.Trim(string.sub(String, 5))
	end

	table.SortByKey(acemenupanel.Changelog,true)

	local Table = {}
	Table.guicreate = (function( _, Table ) ACE.HomeGUICreate( Table ) end or nil)
	Table.guiupdate = (function( _, Table ) ACE.HomeGUIUpdate( Table ) end or nil)
	acemenupanel:UpdateDisplay( Table )

end

http.Fetch("http://raw.github.com/ACE-Project-Team/ArmoredCombatExtended/master/changelog.txt", ACE.ChangelogHTTPCallBack, function() end)

--[[=========================
	Clientside folder content
]]--=========================
function ACE.CLGUICreate()

	local Client = acemenupanel["CData"]["Options"]

	Client = vgui.Create( "DLabel" )
	Client:SetPos( 0, 0 )
	Client:SetColor( Color(10,10,10) )
	Client:SetText("ACE - Client Side Control Panel")
	Client:SetFont("DermaDefaultBold")
	Client:SizeToContents()
	acemenupanel.CustomDisplay:AddItem( Client )

	local Sub = vgui.Create( "DLabel" )
	Sub:SetPos( 0, 0 )
	Sub:SetColor( Color(10,10,10) )
	Sub:SetText("Client Side parameters can be adjusted here.")
	Sub:SizeToContents()
	acemenupanel.CustomDisplay:AddItem( Sub )

	local Sounds = vgui.Create( "DForm" )
	Sounds:SetName("Sounds")

	Sounds:CheckBox("Allow Tinnitus Noise", "ace_tinnitus")
	Sounds:ControlHelp( "Allows the ear tinnitus effect to be applied when an explosive was detonated too close to your position, improving the inmersion during combat." )

	Sounds:NumSlider( "Ambient overall sounds", "ace_sound_volume", 0, 100, 0 )
	Sounds:ControlHelp( "Adjusts the volume of ACE sounds like explosions, penetrations, ricochets, etc. Engines and some mechanic sounds are not affected yet." )

	acemenupanel.CustomDisplay:AddItem( Sounds )

	local Effects = vgui.Create( "DForm" )
	Effects:SetName("Rendering")

	Effects:CheckBox("Allow lighting rendering", "ace_enable_lighting")
	Effects:ControlHelp( "Enables lighting for explosions, muzzle flashes and rocket motors, increasing the inmersion during combat, however, may impact heavily the performance and it's possible it doesn't render properly in certain map surfaces." )

	Effects:CheckBox("Draw Mobility rope links", "ace_mobility_rope_links")
	Effects:ControlHelp( "Allow you to see the links between engines and gearboxes (requires dupe restart)" )

	acemenupanel.CustomDisplay:AddItem( Effects )

	local DupeSection = vgui.Create( "DForm" )
	DupeSection:SetName("Dupe Loader")

	DupeSection:Help( "If for some reason, your ace dupe folder was damaged or deleted, you can restore them here." )
	DupeSection:Button("Restore ace dupe folders", "ace_dupes_remount" )

	acemenupanel.CustomDisplay:AddItem( DupeSection )

end

-- i'm not touching the rest of the menu code, it's going to be redone eventually anyways
-- throwing some helpers here for now
local function updateSetting(setting, value)
	net.Start("ACE_SettingsSync")
	net.WriteString(setting)
	net.WriteFloat(value)
	net.SendToServer()
end

local function addHelpText(text, parent)
	local label = vgui.Create("DLabel", parent)
	label:SetText(text)
	label:SetFont("DermaDefault")
	label:SetWrap(true)
	label:SetAutoStretchVertical(true)
	label:DockMargin(34, 0, 34, 0)
	label:SetColor(Color(47, 149, 241))
	label:Dock(TOP)

	return label
end

local function addCheckbox(text, setting, parent)
	local checkbox = vgui.Create("DCheckBoxLabel", parent)
	checkbox:SetText(text)
	checkbox:DockMargin(10, 10, 10, 0)
	checkbox:Dock(TOP)
	checkbox:SetDark(true)

	function checkbox:OnChange(value)
		if self.suppressOnChange then return end

		updateSetting(setting, value and 1 or 0)
	end

	function checkbox:SetValueNoSync(value)
		self.suppressOnChange = true
		self:SetChecked(value > 0)
		self.suppressOnChange = false
	end

	return checkbox
end

local function addSlider(text, min, max, decimals, default, setting, parent)
	local slider = vgui.Create("DNumSlider", parent)
	slider:SetText(text)
	slider:SetDark(true)
	slider:SetMin(min)
	slider:SetMax(max)
	slider:SetDecimals(decimals)
	slider:DockMargin(10, 0, 10, -5)
	slider:Dock(TOP)

	function slider:OnValueChanged(value)
		if self.suppressOnChange then return end

		timer.Create("ACE_DebounceSettingUpdate_" .. setting, 0.25, 1, function()
			updateSetting(setting, math.Round(value, decimals))
		end)
	end

	slider:SetDefaultValue(default)

	function slider:SetValueNoSync(value)
		self.suppressOnChange = true
		self:SetValue(value)
		self.suppressOnChange = false
	end

	return slider
end


--[[=========================
	Serverside folder content
]]--=========================
function ACE.SVGUICreate()	--Serverside folder content
	local ply = LocalPlayer()
	if not IsValid(ply) then return end
	if not ply:IsSuperAdmin() then
		local Note = vgui.Create( "DLabel" )
		Note:SetPos( 0, 0 )
		Note:SetColor( Color(10,10,10) )
		Note:SetText("Only superadmins can view and access this menu")
		Note:SizeToContents()
		acemenupanel.CustomDisplay:AddItem( Note )

		return
	end

	local Server = acemenupanel["CData"]["Options"]

	Server = vgui.Create( "DLabel" )
	Server:SetPos( 0, 0 )
	Server:SetColor( Color(10,10,10) )
	Server:SetText("ACE - Serverside Control Panel")
	Server:SetFont("DermaDefaultBold")
	Server:SizeToContents()
	acemenupanel.CustomDisplay:AddItem( Server )

	local Sub = vgui.Create( "DLabel" )
	Sub:SetPos( 0, 0 )
	Sub:SetColor( Color(10,10,10) )
	Sub:SetText("Serverside parameters can be adjusted here")
	Sub:SizeToContents()
	acemenupanel.CustomDisplay:AddItem( Sub )

	local settings = {}

	-- General settings
	local general = vgui.Create("DCollapsibleCategory")
	general:SetLabel("General")
	general:SetExpanded(false)

	settings.ace_gunfire = addCheckbox("Enable gunfire", "ace_gunfire", general)
	addHelpText("Master switch to enable or disable the firing of ACE weaponry.", general)

	settings.ace_hepush = addCheckbox("Enable HE push", "ace_hepush", general)
	addHelpText("Large explosions will push contraptions.", general)

	settings.ace_kepush = addCheckbox("Enable KE push", "ace_kepush", general)
	addHelpText("Kinetic impacts will push contraptions.", general)

	settings.ace_recoilpush = addCheckbox("Enable recoil force", "ace_recoilpush", general)
	addHelpText("Gun recoil will push contraptions.", general)

	settings.ace_legacyrecoil = addCheckbox("Enable legacy recoil", "ace_legacyrecoil", general)
	addHelpText("Applies recoil as a straight force at the baseplate's center of mass, with no torque/tipping effect (legacy behavior).", general)

	settings.ace_wind = addSlider("Wind strength", 0, 2000, 0, 600, "ace_wind", general)
	addHelpText("Global wind speed in u/s. 0 to disable.", general)

	acemenupanel.CustomDisplay:AddItem(general)

	local damageScaling = vgui.Create("DCollapsibleCategory")
	damageScaling:SetLabel("Damage Scaling")
	damageScaling:SetExpanded(false)

	settings.ace_healthmod = addSlider("Health multiplier", 0.1, 10, 2, 1, "ace_healthmod", damageScaling)
	addHelpText("Global health multiplier.", damageScaling)

	settings.ace_armormod = addSlider("Armor multiplier", 0.1, 10, 2, 1, "ace_armormod", damageScaling)
	addHelpText("Global armor multiplier.", damageScaling)

	acemenupanel.CustomDisplay:AddItem(damageScaling)

	local debrisSpalling = vgui.Create("DCollapsibleCategory")
	debrisSpalling:SetLabel("Debris & Spalling")
	debrisSpalling:SetExpanded(false)

	settings.ace_debris_lifetime = addSlider("Debris lifetime", 0, 60, 0, 30, "ace_debris_lifetime", debrisSpalling)
	addHelpText("How many seconds debris will remain on the map before being deleted (0 means never).", debrisSpalling)

	settings.ace_debris_children = addSlider("Child debris chance", 0, 1, 2, 1, "ace_debris_children", debrisSpalling)
	addHelpText("Adjusts the chance of creating debris when a contraption's base has been destroyed.", debrisSpalling)

	settings.ace_spalling = addCheckbox("Enable spalling", "ace_spalling", debrisSpalling)
	addHelpText("Enables the creation of spall fragments from armor penetrations. Moderately performance intensive.", debrisSpalling)

	settings.ace_spalling_multiplier = addSlider("Spalling multiplier", 0.1, 1, 2, 1, "ace_spalling_multiplier", debrisSpalling)
	addHelpText("Multiplier for how much spalling is generated during impacts.", debrisSpalling)

	acemenupanel.CustomDisplay:AddItem(debrisSpalling)

	local cookingOff = vgui.Create("DCollapsibleCategory")
	cookingOff:SetLabel("Cooking Off / Scaled Explosions")
	cookingOff:SetExpanded(false)

	settings.ace_explosions_scaled_he_max = addSlider("Max HE per explosion", 50, 1000, 0, 100, "ace_explosions_scaled_he_max", cookingOff)
	addHelpText("The maximum amount of HE weight (kg) to detonate at once.", cookingOff)

	settings.ace_explosions_scaled_ents_max = addSlider("Max ents per explosion", 1, 20, 0, 5, "ace_explosions_scaled_ents_max", cookingOff)
	addHelpText("The maximum amount of entities to detonate in one scaled explosion.", cookingOff)

	acemenupanel.CustomDisplay:AddItem(cookingOff)

	local legality = vgui.Create("DCollapsibleCategory")
	legality:SetLabel("Vehicle Legality")
	legality:SetExpanded(false)

	settings.ace_legalcheck = addCheckbox("Enable legality checks", "ace_legalcheck", legality)
	addHelpText("Master switch for enabling legality checks in ACE.", legality)

	settings.ace_legality_enginesrequirefuel = addCheckbox("Engines require fuel", "ace_legality_enginesrequirefuel", legality)
	addHelpText("Engines require fuel to run.", legality)

	settings.ace_legality_largeenginesneeddriver = addCheckbox("Large engines need driver", "ace_legality_largeenginesneeddriver", legality)
	addHelpText("Large engines require a linked driver crew entity to operate.", legality)

	settings.ace_legality_largeenginethreshold = addSlider("Threshold", 0, 1000, 0, 100, "ace_legality_largeenginethreshold", legality)
	settings.ace_legality_largeenginethreshold:DockMargin(34, 0, 34, -5)
	addHelpText("HP threshold defining a 'large' engine.", legality)

	settings.ace_legality_largegunsneedgunner = addCheckbox("Large guns need gunner", "ace_legality_largegunsneedgunner", legality)
	addHelpText("Large guns require a linked gunner crew entity to operate.", legality)

	settings.ace_legality_largegunthreshold = addSlider("Threshold", 0, 200, 0, 40, "ace_legality_largegunthreshold", legality)
	settings.ace_legality_largegunthreshold:DockMargin(34, 0, 34, -5)
	addHelpText("Caliber (mm) threshold defining a 'large' gun.", legality)

	settings.ace_legal_ignore_model = addCheckbox("Allow any model", "ace_legal_ignore_model", legality)
	addHelpText("Allow ACE entities to use any model.", legality)

	settings.ace_legal_ignore_solid = addCheckbox("Allow not solid", "ace_legal_ignore_solid", legality)
	addHelpText("Allow ACE entities to be non-solid.", legality)

	settings.ace_legal_ignore_mass = addCheckbox("Allow any mass", "ace_legal_ignore_mass", legality)
	addHelpText("Allow ACE entities to have any mass.", legality)

	settings.ace_legal_ignore_material = addCheckbox("Allow any material", "ace_legal_ignore_material", legality)
	addHelpText("Allow ACE entities to use any armor material.", legality)

	settings.ace_legal_ignore_inertia = addCheckbox("Allow any inertia", "ace_legal_ignore_inertia", legality)
	addHelpText("Allow ACE entities to have any inertia.", legality)

	settings.ace_legal_ignore_makesphere = addCheckbox("Allow makesphere", "ace_legal_ignore_makesphere", legality)
	addHelpText("Allow ACE entities to be made spherical.", legality)

	settings.ace_legal_ignore_visclip = addCheckbox("Allow visclip", "ace_legal_ignore_visclip", legality)
	addHelpText("Allow ACE entities to be visclipped.", legality)

	acemenupanel.CustomDisplay:AddItem(legality)

	local propProtection = vgui.Create("DCollapsibleCategory")
	propProtection:SetLabel("Prop Protection")
	propProtection:SetExpanded(false)

	settings.ace_enable_dp = addCheckbox("Enable Damage Protection", "ace_enable_dp", propProtection)
	addHelpText("Enable ACE's built-in damage protection.", propProtection)

	settings.ace_restrictinfo = addCheckbox("Restrict ACE info", "ace_restrictinfo", propProtection)
	addHelpText("Restricts information gathering of ACE entities via E2/Starfall.", propProtection)
	addHelpText("Enabling this will only allow you to gather information on ACE entities owned by you.", propProtection)

	acemenupanel.CustomDisplay:AddItem(propProtection)

	net.Start("ACE_SettingsSync")
	net.WriteString("_request")
	net.SendToServer()

	net.Receive("ACE_SettingsSync", function()
		local size = net.ReadUInt(16)
		local receivedSettings = util.JSONToTable(util.Decompress(net.ReadData(size)))

		for convar, value in pairs(receivedSettings) do
			if settings[convar] then
				settings[convar]:SetValueNoSync(value)
			end
		end
	end)
end

--[[=========================
	Contact folder content
]]--=========================
function ACE.ContactGUICreate()

	acemenupanel["CData"]["Contact"] = vgui.Create( "DLabel" )
	acemenupanel["CData"]["Contact"]:SetPos( 0, 0 )
	acemenupanel["CData"]["Contact"]:SetColor( Color(10,10,10) )
	acemenupanel["CData"]["Contact"]:SetText("Contact Us")
	acemenupanel["CData"]["Contact"]:SetFont("Trebuchet24")
	acemenupanel["CData"]["Contact"]:SizeToContents()
	acemenupanel.CustomDisplay:AddItem( acemenupanel["CData"]["Contact"] )

	acemenupanel:CPanelText("desc1","If you want to contribute to ACE by providing us feedback, report bugs or tell us suggestions about new stuff to be added, our discord is a good place.")
	acemenupanel:CPanelText("desc2","Don't forget to check out our wiki, contains valuable information about how to use this addon. It's on WIP, but expect more content in future.")

	local Discord = vgui.Create("DButton")
	Discord:SetText( "Join our Discord!" )
	Discord:SetPos(0,0)
	Discord:SetSize(250,30)
	Discord.DoClick = function()
	gui.OpenURL("https://discord.gg/Y8aEYU6")
	end
	acemenupanel.CustomDisplay:AddItem( Discord )

	local Wiki = vgui.Create("DButton")
	Wiki:SetText( "Open Wiki" )
	Wiki:SetPos(0,0)
	Wiki:SetSize(250,30)
	Wiki.DoClick = function()
	gui.OpenURL("https://github.com/ACE-Project-Team/ArmoredCombatExtended/wiki")
	end
	acemenupanel.CustomDisplay:AddItem( Wiki )

	local Guide = vgui.Create("DButton")
	Guide:SetText( "ACE guidelines" )
	Guide:SetPos(0,0)
	Guide:SetSize(250,30)
	Guide.DoClick = function()
	gui.OpenURL("https://docs.google.com/document/d/1yaHq4Lfjad4KKa0Jg9s-5lCpPVjV7FE4HXoGaKpi4Fs/edit")
	end
	acemenupanel.CustomDisplay:AddItem( Guide )

end

--===========================================================================================
-----Ammo & Gun selection content
--===========================================================================================

do

	local function CreateIdForCrate( self )

		if not acemenupanel.AmmoPanelConfig["LegacyAmmos"] then

			local X = math.Round( acemenupanel.AmmoPanelConfig["Crate_Length"], 1 )
			local Y = math.Round(acemenupanel.AmmoPanelConfig["Crate_Width"], 1 )
			local Z = math.Round(acemenupanel.AmmoPanelConfig["Crate_Height"], 1)

			local Id = X .. ":" .. Y .. ":" .. Z

			acemenupanel.AmmoData["Id"] = Id
			RunConsoleCommand( "acemenu_id", Id )

		end

		self:UpdateAttribs()

	end

	function PANEL:AmmoSelect( Blacklist )

	if not acemenupanel.CustomDisplay then return end
	if not Blacklist then Blacklist = {} end

	if not acemenupanel.AmmoData then

		acemenupanel.AmmoData               = {}
		acemenupanel.AmmoData["Id"]         = "10:10:10"  --default Ammo dimension on list
		acemenupanel.AmmoData["IdLegacy"]   = "Shell100mm"
		acemenupanel.AmmoData["Type"]       = "Ammo"
		acemenupanel.AmmoData["Classname"]  = Classes.GunClass["MG"]["name"]
		acemenupanel.AmmoData["ClassData"]  = Classes.GunClass["MG"]["id"]
		acemenupanel.AmmoData["Data"]       = ACFEnts["Guns"]["12.7mmMG"]["round"]
	end

	if not acemenupanel.AmmoPanelConfig then

		acemenupanel.AmmoPanelConfig = {}
		acemenupanel.AmmoPanelConfig["ExpandedCatNew"] = true
		acemenupanel.AmmoPanelConfig["ExpandedCatOld"] = false
		acemenupanel.AmmoPanelConfig["LegacyAmmos"]	= false
		acemenupanel.AmmoPanelConfig["Crate_Length"]  = 10
		acemenupanel.AmmoPanelConfig["Crate_Width"]	= 10
		acemenupanel.AmmoPanelConfig["Crate_Height"]  = 10

	end

	local MainPanel = self
	local CrateNewCat = vgui.Create( "DCollapsibleCategory" )	-- Create a collapsible category
	acemenupanel.CustomDisplay:AddItem(CrateNewCat)
	CrateNewCat:SetLabel( "Crate Config" )						-- Set the name ( label )
	CrateNewCat:SetPos( 25, 50 )		-- Set position
	CrateNewCat:SetSize( 250, 100 )	-- Set size
	CrateNewCat:SetExpanded( acemenupanel.AmmoPanelConfig["ExpandedCatNew"] )

	function CrateNewCat:OnToggle( bool )
		acemenupanel.AmmoPanelConfig["ExpandedCatNew"] = bool
	end

	local CrateNewPanel = vgui.Create( "DPanelList" )
	CrateNewPanel:SetSpacing( 10 )
	CrateNewPanel:EnableHorizontal( false )
	CrateNewPanel:EnableVerticalScrollbar( true )
	CrateNewPanel:SetPaintBackground( false )
	CrateNewCat:SetContents( CrateNewPanel )

	local CrateOldCat = vgui.Create( "DCollapsibleCategory" )
	acemenupanel.CustomDisplay:AddItem(CrateOldCat)
	CrateOldCat:SetLabel( "Crate Config (legacy)" )
	CrateOldCat:SetPos( 25, 50 )
	CrateOldCat:SetSize( 250, 100 )
	CrateOldCat:SetExpanded( acemenupanel.AmmoPanelConfig["ExpandedCatOld"] )

	function CrateOldCat:OnToggle( bool )
		acemenupanel.AmmoPanelConfig["ExpandedCatOld"] = bool
	end

	local CrateOldPanel = vgui.Create( "DPanelList" )
	CrateOldPanel:SetSpacing( 10 )
	CrateOldPanel:EnableHorizontal( false )
	CrateOldPanel:EnableVerticalScrollbar( true )
	CrateOldPanel:SetPaintBackground( false )
	CrateOldCat:SetContents( CrateOldPanel )

	--===========================================================================================
	-----Creating the ammo crate selection
	--===========================================================================================

	--------------- NEW CONFIG ---------------
	do

		local MinCrateSize = ACE.CrateMinimumSize
		local MaxCrateSize = ACE.CrateMaximumSize

		acemenupanel:CPanelText("Crate_desc_new", "\nAdjust the dimensions for your crate. In inches.", nil, CrateNewPanel)

		local LengthSlider = vgui.Create( "DNumSlider" )
		LengthSlider:SetText( "Length" )
		LengthSlider:SetDark( true )
		LengthSlider:SetMin( MinCrateSize )
		LengthSlider:SetMax( MaxCrateSize )
		LengthSlider:SetValue( acemenupanel.AmmoPanelConfig["Crate_Length"] or 10 )
		LengthSlider:SetDecimals( 1 )

		function LengthSlider:OnValueChanged( value )
			acemenupanel.AmmoPanelConfig["Crate_Length"] = value
			CreateIdForCrate( MainPanel )
		end
		CrateNewPanel:AddItem(LengthSlider)

		local WidthSlider = vgui.Create( "DNumSlider" )
		WidthSlider:SetText( "Width" )
		WidthSlider:SetDark( true )
		WidthSlider:SetMin( MinCrateSize )
		WidthSlider:SetMax( MaxCrateSize )
		WidthSlider:SetValue( acemenupanel.AmmoPanelConfig["Crate_Width"] or 10 )
		WidthSlider:SetDecimals( 1 )

		function WidthSlider:OnValueChanged( value )
			acemenupanel.AmmoPanelConfig["Crate_Width"] = value
			CreateIdForCrate( MainPanel )
		end
		CrateNewPanel:AddItem(WidthSlider)

		local HeightSlider = vgui.Create( "DNumSlider" )
		HeightSlider:SetText( "Height" )
		HeightSlider:SetDark( true )
		HeightSlider:SetMin( MinCrateSize )
		HeightSlider:SetMax( MaxCrateSize )
		HeightSlider:SetValue( acemenupanel.AmmoPanelConfig["Crate_Height"] or 10 )
		HeightSlider:SetDecimals( 1 )

		function HeightSlider:OnValueChanged( value )
			acemenupanel.AmmoPanelConfig["Crate_Height"] = value
			CreateIdForCrate( MainPanel )
		end
		CrateNewPanel:AddItem(HeightSlider)

	end

	--------------- OLD CONFIG ---------------
	do

		acemenupanel:CPanelText("Crate_desc_legacy", "\nChoose a crate in the legacy way. Remember to enable the checkbox below to do so.", nil, CrateOldPanel)
		acemenupanel:CPanelText("Crate_desc_legacy2", "DISCLAIMER: These crates are deprecated and dont't follow any proper format like the capacity or size. Don't trust on these crates, apart they might be removed in a future!", nil, CrateOldPanel)

		local LegacyCheck = vgui.Create( "DCheckBoxLabel" ) -- Create the checkbox
		LegacyCheck:SetPos( 25, 50 )							-- Set the position
		LegacyCheck:SetText("Use Legacy Mode")					-- Set the text next to the box
		LegacyCheck:SetDark( true )
		LegacyCheck:SetChecked( acemenupanel.AmmoPanelConfig["LegacyAmmos"] or false )						-- Initial value
		LegacyCheck:SizeToContents()							-- Make its size the same as the contents

		function LegacyCheck:OnChange( val )
			acemenupanel.AmmoPanelConfig["LegacyAmmos"] = val
			if val then
				acemenupanel.AmmoData["Id"] =  acemenupanel.AmmoData["IdLegacy"]
				RunConsoleCommand( "acemenu_id", acemenupanel.AmmoData["Id"] )
			else
				CreateIdForCrate( MainPanel )
			end

			MainPanel:UpdateAttribs()

		end

		CrateOldPanel:AddItem(LegacyCheck)

		local AmmoComboBox = vgui.Create( "DComboBox", CrateOldPanel )	--Every display and slider is placed in the Round table so it gets trashed when selecting a new round type
		AmmoComboBox:SetSize(acemenupanel.CustomDisplay:GetWide(), 30)

		for Key, Value in pairs( ACFEnts.Ammo ) do

			AmmoComboBox:AddChoice( Value.id , Key ) --Creates the list

		end

		AmmoComboBox.OnSelect = function( _ , _ , data )	-- calls the ID of the list
			if acemenupanel.AmmoPanelConfig["LegacyAmmos"] then
			RunConsoleCommand( "acemenu_id", data )
			acemenupanel.AmmoData["Id"] = data
			end

			acemenupanel.AmmoData["IdLegacy"] = data

			if acemenupanel.CData.CrateDisplay then

			local cratemodel = ACFEnts.Ammo[acemenupanel.AmmoData["IdLegacy"]].model
			acemenupanel.CData.CrateDisplay:SetModel(cratemodel)
			acemenupanel:CPanelText("CrateDesc", ACFEnts.Ammo[acemenupanel.AmmoData["IdLegacy"]].desc, nil, CrateOldPanel)

			end

			MainPanel:UpdateAttribs()

		end

		AmmoComboBox:SetText(acemenupanel.AmmoData["IdLegacy"])
		RunConsoleCommand( "acemenu_id", acemenupanel.AmmoData["Id"] )

		CrateOldPanel:AddItem(AmmoComboBox)

	--===========================================================================================
	-----Creating the Model display
	--===========================================================================================

		--Used to create the general model display
		if not acemenupanel.CData.CrateDisplay then

			acemenupanel:CPanelText("CrateDesc", ACFEnts.Ammo[acemenupanel.AmmoData["IdLegacy"]].desc, nil, CrateOldPanel)

			acemenupanel.CData.CrateDisplay = vgui.Create( "DModelPanel", CrateOldPanel )
			acemenupanel.CData.CrateDisplay:SetSize(acemenupanel.CustomDisplay:GetWide(),acemenupanel.CustomDisplay:GetWide() / 2)
			acemenupanel.CData.CrateDisplay:SetCamPos( Vector( 250, 500, 250 ) )
			acemenupanel.CData.CrateDisplay:SetLookAt( Vector( 0, 0, 0 ) )
			acemenupanel.CData.CrateDisplay:SetFOV( 10 )
			acemenupanel.CData.CrateDisplay:SetModel(ACFEnts.Ammo[acemenupanel.AmmoData["IdLegacy"]].model)
			acemenupanel.CData.CrateDisplay.LayoutEntity = function() end

			CrateOldPanel:AddItem(acemenupanel.CData.CrateDisplay)

		end

	end

	--===========================================================================================
	-----Creating the gun Class display
	--===========================================================================================

	acemenupanel.CData.ClassSelect = vgui.Create( "DComboBox", acemenupanel.CustomDisplay)
	acemenupanel.CData.ClassSelect:SetSize(100, 30)

	local DComboList = {}

	for _, GunTable in pairs( Classes.GunClass ) do

		if not table.HasValue( Blacklist, GunTable.id ) then
			acemenupanel.CData.ClassSelect:AddChoice( GunTable.name , GunTable.id )
			DComboList[GunTable.id] = true

		end
	end

	acemenupanel.CData.ClassSelect:SetText( acemenupanel.AmmoData["Classname"] .. (not DComboList[acemenupanel.AmmoData["ClassData"]] and " - update caliber!" or "" ))
	acemenupanel.CData.ClassSelect:SetColor( not DComboList[acemenupanel.AmmoData["ClassData"]] and Color(255,0,0) or Color(0,0,0) )

	acemenupanel.CData.ClassSelect.OnSelect = function( _ , index , data )

		data = acemenupanel.CData.ClassSelect:GetOptionData(index) -- Why?

		acemenupanel.AmmoData["Classname"] = Classes.GunClass[data]["name"]
		acemenupanel.AmmoData["ClassData"] = Classes.GunClass[data]["id"]

		acemenupanel.CData.ClassSelect:SetColor( Color(0,0,0) )

		acemenupanel.CData.CaliberSelect:Clear()

		for Key, Value in pairs( ACFEnts.Guns ) do

			if acemenupanel.AmmoData["ClassData"] == Value.gunclass then
			acemenupanel.CData.CaliberSelect:AddChoice( Value.id , Key )
			end

		end

		MainPanel:UpdateAttribs()
		MainPanel:UpdateAttribs() --Note : this is intentional
	end

	acemenupanel.CustomDisplay:AddItem( acemenupanel.CData.ClassSelect )

	--===========================================================================================
	-----Creating the caliber selection display
	--===========================================================================================

	acemenupanel.CData.CaliberSelect = vgui.Create( "DComboBox", acemenupanel.CustomDisplay )
	acemenupanel.CData.CaliberSelect:SetSize(100, 30)

	acemenupanel.CData.CaliberSelect:SetText(acemenupanel.AmmoData["Data"]["id"]  )

	for Key, Value in pairs( ACFEnts.Guns ) do

		if acemenupanel.AmmoData["ClassData"] == Value.gunclass then
			acemenupanel.CData.CaliberSelect:AddChoice( Value.id , Key )
		end

	end

	acemenupanel.CData.CaliberSelect.OnSelect = function( _ , _ , gun )

		acemenupanel.AmmoData["Data"] = ACFEnts["Guns"][gun]["round"]
		MainPanel:UpdateAttribs()
		MainPanel:UpdateAttribs() --Note : this is intentional

	end

	acemenupanel.CustomDisplay:AddItem( acemenupanel.CData.CaliberSelect )

	end
end

function PANEL:AmmoSlider(Name, Value, Min, Max, Decimals, Title, Desc) --Variable name in the table, Value, Min value, Max Value, slider text title, slider decimeals, description text below slider

	if not acemenupanel["CData"][Name] then

	acemenupanel["CData"][Name] = vgui.Create( "DNumSlider", acemenupanel.CustomDisplay )
	acemenupanel["CData"][Name].Label:SetSize( 0 )  --Note : this is intentional
	acemenupanel["CData"][Name]:SetTall( 50 )	-- make the slider taller to fit the new label
	acemenupanel["CData"][Name]:SetMin( 0 )
	acemenupanel["CData"][Name]:SetMax( 1000 )
	acemenupanel["CData"][Name]:SetDark( true )
	acemenupanel["CData"][Name]:SetDecimals( Decimals )

	acemenupanel["CData"][Name .. "_label"] = vgui.Create( "DLabel", acemenupanel["CData"][Name]) -- recreating the label
	acemenupanel["CData"][Name .. "_label"]:SetPos( 0, 0)
	acemenupanel["CData"][Name .. "_label"]:SetText( Title )
	acemenupanel["CData"][Name .. "_label"]:SizeToContents()
	acemenupanel["CData"][Name .. "_label"]:SetDark( true )

	if acemenupanel.AmmoData[Name] then
			acemenupanel["CData"][Name]:SetValue(acemenupanel.AmmoData[Name])
	end

	acemenupanel["CData"][Name].OnValueChanged = function( _, val )

	--Programmatic SetMin/SetMax/SetValue (below) fire DNumSlider:ValueChanged, which calls
	--this handler. Record the value so AmmoData tracks what the slider shows, but don't call
	--UpdateAttribs from here or it recurses into a client stack overflow.
	--Coupled sliders (propellant/projectile clamped against MaxTotalLength) rely on this write:
	--without it guiupdate re-reads a stale AmmoData next drag and the clamp never commits.
	if acemenupanel["CData"][Name].ACEProgrammatic then
		acemenupanel.AmmoData[Name] = val

		return
	end

	if acemenupanel.AmmoData[Name] ~= val then

		acemenupanel.AmmoData[Name] = val
			self:UpdateAttribs( Name )
		end

	end

	acemenupanel.CustomDisplay:AddItem( acemenupanel["CData"][Name] )

	end

	acemenupanel["CData"][Name].ACEProgrammatic = true
	acemenupanel["CData"][Name]:SetMin( Min )
	acemenupanel["CData"][Name]:SetMax( Max )
	acemenupanel["CData"][Name]:SetValue( Value )
	acemenupanel["CData"][Name].ACEProgrammatic = false

	if not acemenupanel["CData"][Name .. "_text"] and Desc then

	acemenupanel["CData"][Name .. "_text"] = vgui.Create( "DLabel" )
	acemenupanel["CData"][Name .. "_text"]:SetText( Desc or "" )
	acemenupanel["CData"][Name .. "_text"]:SetDark( true )
	acemenupanel["CData"][Name .. "_text"]:SetTall( 20 )
	acemenupanel.CustomDisplay:AddItem( acemenupanel["CData"][Name .. "_text"] )

	end

	acemenupanel["CData"][Name .. "_text"]:SetText( Desc )
	acemenupanel["CData"][Name .. "_text"]:SetSize( acemenupanel.CustomDisplay:GetWide(), 14 )
	acemenupanel["CData"][Name .. "_text"]:SizeToContentsX()

end

-- Variable name in the table, slider text title, slider decimeals, description text below slider
function PANEL:AmmoCheckbox(Name, Title, Desc, Tooltip )

	if not acemenupanel["CData"][Name] then

	acemenupanel["CData"][Name] = vgui.Create( "DCheckBoxLabel" )
	acemenupanel["CData"][Name]:SetText( Title or "" )
	acemenupanel["CData"][Name]:SetDark( true )
	acemenupanel["CData"][Name]:SizeToContents()
	acemenupanel["CData"][Name]:SetChecked(acemenupanel.AmmoData[Name] or false)

	acemenupanel["CData"][Name].OnChange = function( _, bval )

		bval = bval and 1 or 0 -- converting to number since booleans sucks in this duty

		acemenupanel.AmmoData[Name] = tonumber(bval) --print(isstring(acemenupanel.AmmoData[Name]))

		self:UpdateAttribs()

	end

	if Tooltip and Tooltip ~= "" then
		acemenupanel["CData"][Name]:SetTooltip( Tooltip )
	end

	acemenupanel.CustomDisplay:AddItem( acemenupanel["CData"][Name] )

	end

	acemenupanel["CData"][Name]:SetText( Title )

	if not acemenupanel["CData"][Name .. "_text"] and Desc then

	acemenupanel["CData"][Name .. "_text"] = acemenupanel["CData"][Name .. "_text"]
	acemenupanel["CData"][Name .. "_text"] = vgui.Create( "DLabel" )
	acemenupanel["CData"][Name .. "_text"]:SetText( Desc or "" )
	acemenupanel["CData"][Name .. "_text"]:SetDark( true )
	acemenupanel.CustomDisplay:AddItem( acemenupanel["CData"][Name .. "_text"] )

	end

	acemenupanel["CData"][Name .. "_text"]:SetText( Desc )
	acemenupanel["CData"][Name .. "_text"]:SetSize( acemenupanel.CustomDisplay:GetWide(), 10 )
	acemenupanel["CData"][Name .. "_text"]:SizeToContentsX()

end

--[[-------------------------------------
	PANEL:CPanelText(Name, Desc, Font)

	1-Name: Identifier of this text
	2-Desc: The content of this text
	3-Font: The font to be used in this text. Leave it empty or nil to use the default one
	4-
]]---------------------------------------
function PANEL:CPanelText(Name, Desc, Font, Panel)

	if not acemenupanel["CData"][Name .. "_text"] then

	acemenupanel["CData"][Name .. "_text"] = vgui.Create( "DLabel" )

	acemenupanel["CData"][Name .. "_text"]:SetText( Desc or "" )
	acemenupanel["CData"][Name .. "_text"]:SetDark( true )

	if Font then acemenupanel["CData"][Name .. "_text"]:SetFont( Font ) end

	acemenupanel["CData"][Name .. "_text"]:SetWrap(true)
	acemenupanel["CData"][Name .. "_text"]:SetAutoStretchVertical( true )

	if IsValid(Panel) then
		if Panel.AddItem then
			Panel:AddItem( acemenupanel["CData"][Name .. "_text"] )
		end
	else
		acemenupanel.CustomDisplay:AddItem( acemenupanel["CData"][Name .. "_text"] )
	end
	end

	acemenupanel["CData"][Name .. "_text"]:SetText( Desc )
	acemenupanel["CData"][Name .. "_text"]:SetSize( acemenupanel.CustomDisplay:GetWide(), 10 )
	acemenupanel["CData"][Name .. "_text"]:SizeToContentsY()

end

--[[=========================
	Crew unified menu GUI
	NOTE: Added for the "single Crew menu" workflow:
	- Clicking "Crew" opens this panel
	- Role + Pose are selected here
	- Spawning still uses the 3 existing entities (Driver/Gunner/Loader), so no builds/dupes break.
]]--=========================
function ACE.CrewMenuGUICreate(Table)
	-- Enable scrolling for this page
	if acemenupanel.CustomDisplay and acemenupanel.CustomDisplay.EnableVerticalScrollbar then
		acemenupanel.CustomDisplay:EnableVerticalScrollbar(true)
	end

	local CrewDefs = (ACF and ACE.Weapons and ACE.Weapons.Crewseats) or {}
	if table.IsEmpty(CrewDefs) then
		acemenupanel:CPanelText("CrewMissing", "No crewseat definitions loaded (ACE.Weapons.Crewseats is empty).")
		acemenupanel.CustomDisplay:PerformLayout()
		return
	end

	local RoleToId = {
		Driver = "Crewseat_Driver",
		Gunner = "Crewseat_Gunner",
		Loader = "Crewseat_Loader",
	}

	local function GetRoleFromId(id)
		if id == RoleToId.Gunner then return "Gunner" end
		if id == RoleToId.Loader then return "Loader" end
		return "Driver"
	end

	local function GetDefaultPoseForId(id)
		local def = CrewDefs[id]
		return (def and def.defaultModel) or "Sitting"
	end

	local function GetModelFor(id, pose)
		local def = CrewDefs[id]
		if not def then return nil end

		if ACE and ACE.CrewseatModels and pose and ACE.CrewseatModels[pose] then
			return ACE.CrewseatModels[pose]
		end

		return def.model
	end

	-- Camera presets per pose type
	local CameraPresets = {
		-- Standing poses
		Standing = {
			pos = Vector(207, 207, 98),
			lookat = Vector(0, 0, 40),
			fov = 18
		},
		-- Sitting poses
		Sitting = {
			pos = Vector(138, 138, 58),
			lookat = Vector(0, 0, 20),
			fov = 20
		},
	}

	-- Default fallback
	CameraPresets.Default = CameraPresets.Sitting

	local function GetCameraForPose(poseName)
		-- Check if it's a standing pose
		if ACE.IsStandingPose and ACE.IsStandingPose(poseName) then
			return CameraPresets.Standing
		end

		-- Manual check if function doesn't exist
		if poseName and string.find(string.lower(poseName), "stand") then
			return CameraPresets.Standing
		end

		return CameraPresets.Sitting
	end

	RunConsoleCommand("acemenu_type", "Crewseats")

	local currentId = (Table and Table.id) or RoleToId.Driver
	if not CrewDefs[currentId] then currentId = RoleToId.Driver end

	local currentPose = GetDefaultPoseForId(currentId)

	RunConsoleCommand("acemenu_id", currentId)
	RunConsoleCommand("acemenu_entitydata", currentPose)

	-- Header
	acemenupanel:CPanelText("Crew_Title", "Crew", "DermaDefaultBold")

	-- Role dropdown
	acemenupanel:CPanelText("Crew_RoleLabel", "\nRole:")

	local RoleSelect = vgui.Create("DComboBox", acemenupanel.CustomDisplay)
	RoleSelect:SetSize(acemenupanel.CustomDisplay:GetWide(), 30)
	RoleSelect:AddChoice("Driver")
	RoleSelect:AddChoice("Gunner")
	RoleSelect:AddChoice("Loader")
	RoleSelect:SetValue(GetRoleFromId(currentId))
	acemenupanel.CustomDisplay:AddItem(RoleSelect)

	-- Pose dropdown
	acemenupanel:CPanelText("Crew_PoseLabel", "\nPose Model:")

	local PoseSelect = vgui.Create("DComboBox", acemenupanel.CustomDisplay)
	PoseSelect:SetSize(acemenupanel.CustomDisplay:GetWide(), 30)

	if ACE and ACE.CrewseatModelList then
		for _, modelName in ipairs(ACE.CrewseatModelList) do
			PoseSelect:AddChoice(modelName, modelName)
		end
	end

	PoseSelect:SetValue(currentPose)
	acemenupanel.CustomDisplay:AddItem(PoseSelect)

	-- Model preview
	local DisplayModel = vgui.Create("DModelPanel", acemenupanel.CustomDisplay)
	DisplayModel:SetSize(acemenupanel.CustomDisplay:GetWide(), acemenupanel.CustomDisplay:GetWide() * 0.75)
	DisplayModel.LayoutEntity = function() end
	acemenupanel.CustomDisplay:AddItem(DisplayModel)

	-- Description label
	local DescLabel = vgui.Create("DLabel")
	DescLabel:SetDark(true)
	DescLabel:SetWrap(true)
	DescLabel:SetAutoStretchVertical(true)
	DescLabel:SetText("")
	DescLabel:SetSize(acemenupanel.CustomDisplay:GetWide() - 10, 20)
	DescLabel:SetContentAlignment(7)
	acemenupanel.CustomDisplay:AddItem(DescLabel)

	-- Spacer
	local Spacer = vgui.Create("DPanel")
	Spacer:SetSize(acemenupanel.CustomDisplay:GetWide(), 8)
	Spacer:SetPaintBackground(false)
	acemenupanel.CustomDisplay:AddItem(Spacer)

	-- Weight label
	local WeightLabel = vgui.Create("DLabel")
	WeightLabel:SetDark(true)
	WeightLabel:SetText("")
	WeightLabel:SetSize(acemenupanel.CustomDisplay:GetWide(), 20)
	acemenupanel.CustomDisplay:AddItem(WeightLabel)

	local function Refresh()
		local def = CrewDefs[currentId]
		if not def then return end

		local mdl = GetModelFor(currentId, currentPose) or def.model
		if mdl then
			DisplayModel:SetModel(mdl)

			-- Apply pose-specific camera settings
			local cam = GetCameraForPose(currentPose)
			DisplayModel:SetCamPos(cam.pos)
			DisplayModel:SetLookAt(cam.lookat)
			DisplayModel:SetFOV(cam.fov)
		end

		DescLabel:SetText(def.desc or "")
		DescLabel:SizeToContentsY()

		if def.weight then
			WeightLabel:SetText("Weight: " .. tostring(def.weight) .. " kg")
		else
			WeightLabel:SetText("")
		end
		WeightLabel:SizeToContentsY()
	end

	Refresh()

	RoleSelect.OnSelect = function(_, _, roleName)
		currentId = RoleToId[roleName] or RoleToId.Driver
		if not CrewDefs[currentId] then currentId = RoleToId.Driver end

		currentPose = GetDefaultPoseForId(currentId)

		RunConsoleCommand("acemenu_id", currentId)
		RunConsoleCommand("acemenu_entitydata", currentPose)

		PoseSelect:SetValue(currentPose)
		Refresh()
	end

	PoseSelect.OnSelect = function(_, _, poseName)
		currentPose = poseName or "Sitting"
		RunConsoleCommand("acemenu_entitydata", currentPose)
		Refresh()
	end

	acemenupanel.CustomDisplay:PerformLayout()
end

--[[=========================
	Extras GUI (Wind Sensor, G-Force Meter, etc.)
]]--=========================
function ACE.ExtrasGUICreate(Table)
	acemenupanel:CPanelText("Name", Table.name, "DermaDefaultBold")

	if Table.model then
		acemenupanel.CData.DisplayModel = vgui.Create("DModelPanel", acemenupanel.CustomDisplay)
		acemenupanel.CData.DisplayModel:SetModel(Table.model)

		-- Adjust camera based on entity type
		if Table.ent == "ace_gforce_meter" then
			acemenupanel.CData.DisplayModel:SetCamPos(Vector(25, 25, 15))
			acemenupanel.CData.DisplayModel:SetLookAt(Vector(0, 0, 5))
			acemenupanel.CData.DisplayModel:SetFOV(50)
		elseif Table.ent == "ace_wind_sensor" then
			acemenupanel.CData.DisplayModel:SetCamPos(Vector(50, 50, 25))
			acemenupanel.CData.DisplayModel:SetLookAt(Vector(0, 0, 5))
			acemenupanel.CData.DisplayModel:SetFOV(35)
		else
			acemenupanel.CData.DisplayModel:SetCamPos(Vector(50, 50, 40))
			acemenupanel.CData.DisplayModel:SetLookAt(Vector(0, 0, 10))
			acemenupanel.CData.DisplayModel:SetFOV(35)
		end

		acemenupanel.CData.DisplayModel:SetSize(acemenupanel:GetWide(), acemenupanel:GetWide() * 0.5)
		acemenupanel.CData.DisplayModel.LayoutEntity = function() end
		acemenupanel.CustomDisplay:AddItem(acemenupanel.CData.DisplayModel)
	end

	-- Clear entity data for non-crew entities
	RunConsoleCommand("acemenu_entitydata", "")

	acemenupanel:CPanelText("Desc", "\n" .. Table.desc)

	if Table.weight then
		acemenupanel:CPanelText("Weight", "\nWeight: " .. Table.weight .. " kg")
	end

	acemenupanel.CustomDisplay:PerformLayout()
end

--[[=================================================================
	Scalable ACE-entity GUI (shared)

	Scalable ACE entities (the explosive charge) share the same shape + L/W/H
	size config; only the allowed shapes and the stats readout differ.
	ACE_BuildScalableConfig draws the shared widgets, filters the shape list through
	the definition's AllowedShapes/BlacklistShapes, keeps the chosen size in
	acemenupanel.ScalableCfg[class], writes acemenu_data1 ("L:W:H") +
	acemenu_data2 (shape), and calls statsFn to render the panel.
]]--==================================================================
do
	local function getCfg(Table)
		acemenupanel.ScalableCfg = acemenupanel.ScalableCfg or {}
		local key = Table.ent or Table.id or "scalable"
		local cfg = acemenupanel.ScalableCfg[key]
		if not cfg then
			local d = Table.MenuDefault or {}
			cfg = {
				L = d.L or 30, W = d.W or 30, H = d.H or 30,
				Shape = d.Shape or "Box", Expanded = true,
			}
			acemenupanel.ScalableCfg[key] = cfg
		end
		return cfg
	end

	-- Shapes this definition permits, in ACE.ModelData order.
	local function allowedShapes(Table)
		local out, seen = {}, {}
		for _, v in pairs(ACE.ModelData) do
			if v.volumefunction and v.Shape and not seen[v.Shape]
				and ACE.Scalable.ShapeAllowed(v.Shape, Table) then
				seen[v.Shape] = true
				out[#out + 1] = v.Shape
			end
		end
		table.sort(out)
		return out
	end

	function ACE.BuildScalableConfig(Table, statsFn)
		if not acemenupanel.CustomDisplay then return end
		local MainPanel = acemenupanel.CustomDisplay
		local cfg = getCfg(Table)

		acemenupanel:CPanelText("Name", Table.name, "DermaDefaultBold")
		acemenupanel:CPanelText("Desc", Table.desc)

		local statsKey = (Table.ent or "scalable") .. "Stats"

		local function refresh()
			local md = ACE.ModelData[cfg.Shape]
			if not md then return end
			local vol = md.volumefunction(cfg.L, cfg.W, cfg.H)
			acemenupanel:CPanelText(statsKey, "\n" .. statsFn(cfg, vol))
		end

		local function pushId()
			local Id = math.Round(cfg.L, 1) .. ":" .. math.Round(cfg.W, 1) .. ":" .. math.Round(cfg.H, 1)
			RunConsoleCommand("acemenu_data1", Id)
			RunConsoleCommand("acemenu_data2", cfg.Shape)
			refresh()
		end

		local Cat = vgui.Create("DCollapsibleCategory")
		MainPanel:AddItem(Cat)
		Cat:SetLabel("Size & Shape")
		Cat:SetExpanded(cfg.Expanded)
		function Cat:OnToggle(b) cfg.Expanded = b end

		local List = vgui.Create("DPanelList")
		List:SetSpacing(8)
		List:EnableHorizontal(false)
		List:EnableVerticalScrollbar(true)
		List:SetPaintBackground(false)
		Cat:SetContents(List)

		local shapes = allowedShapes(Table)
		if not ACE.Scalable.ShapeAllowed(cfg.Shape, Table) then
			cfg.Shape = shapes[1] or "Box"
		end

		-- Only show the shape selector when there's a real choice.
		if #shapes > 1 then
			local Combo = vgui.Create("DComboBox")
			Combo:SetSize(100, 30)
			for _, s in ipairs(shapes) do Combo:AddChoice(s) end
			Combo:SetText(cfg.Shape)
			Combo.OnSelect = function(_, _, data) cfg.Shape = data pushId() end
			List:AddItem(Combo)
		end

		local minS = ACE.ScalableMinimumSize or ACE.CrateMinimumSize or 5
		-- A definition may cap its size below the global crate limit (explosive
		-- charges do); the server re-clamps in ParseScale, this just matches the UI.
		local maxS = math.min(Table.MaxSize or math.huge, ACE.CrateMaximumSize or 250)

		local function slider(label, field)
			local S = vgui.Create("DNumSlider")
			S:SetText(label)
			S:SetDark(true)
			S:SetMin(minS)
			S:SetMax(maxS)
			S:SetDecimals(1)
			S:SetValue(cfg[field])
			function S:OnValueChanged(v) cfg[field] = v pushId() end
			List:AddItem(S)
		end

		slider("Length", "L")
		slider("Width", "W")
		-- Some entities are inherently flat slabs - their thickness doesn't change
		-- behaviour, so we lock it to a fixed value and hide the slider instead of
		-- letting the player waste a dimension on it.
		if Table.LockH then
			cfg.H = Table.MenuDefault and Table.MenuDefault.H or minS
		else
			slider("Height/Thickness", "H")
		end

		pushId()
		MainPanel:PerformLayout()
	end
end

--[[=========================  Explosive Charge  ===================]]--
-- Scalable charge: pick a shape and size; the filler is read from the resulting
-- physical volume (same HE maths as shells). Pre-built model charges live in the
-- Q spawnmenu instead.
function ACE.ExplosiveGUICreate(Table)
	ACE.BuildScalableConfig(Table, function(_cfg, vol)
		local CM3 = 16.387
		local f   = Table.FillerFraction or 0.65
		local fillerMass = vol * CM3 * f * (ACE.HEDensity or 1.65) / 1000 * (ACE.ExplosiveHEMul or 0.12)
		local fragMass   = vol * CM3 * (1 - f) * 7.9 / 1000
		local physMass   = fillerMass + fragMass * (ACE.ExplosiveCasingMul or 0.08)
		local radius     = fillerMass ^ 0.33 * 8
		local points = ACE.Points.ChargeCost and math.Round(ACE.Points.ChargeCost(fillerMass), 1) or 0
		return "HE Filler: " .. math.Round(fillerMass, 2) .. " kg"
			.. "\nBlast Radius: " .. math.Round(radius, 1) .. " m"
			.. "\nBlast Energy: " .. math.Round(fillerMass * (ACE.HEPower or 8000), 0) .. " KJ"
			.. "\nMass: " .. math.Round(physMass, 1) .. " kg"
			.. "\nPoints: " .. points .. " (mounted ordnance)"
	end)
end
function ACE.ExplosiveGUIUpdate() end

if not ACE then ACE = {} end
if not ACE.ChatMessageReceiver then
	ACE.ChatMessageReceiver = true
	net.Receive( "ACE_ColorChatMessage", function( _, _ ) --Wooo colored chat
		chat.AddText( net.ReadColor(), net.ReadString() )
	end )
end
