--[[------------------------
	1.- This is the file that displays the main menu, such as guns, ammo, mobility and subfolders.

	2.- Almost everything here has been documented, you should find the responsible function easily.

	3.- If you are going to do changes, please not to be a shitnuckle and write a note alongside the code that you´ve changed/edited. This should avoid issues with future developers.

]]--------------------------

local Classes = ACF.Classes
local ACFEnts = ACF.Weapons

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
			RunConsoleCommand( "acfmenu_type", self.mytable.type )
			acfmenupanel:UpdateDisplay( self.mytable )
		end

		EndNode.Icon:SetImage( ItemIcon2 )

	end
end

function PANEL:Init( )

	acfmenupanel = self.Panel

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
	HomeNode.mytable.guicreate = (function( _, Table ) ACFHomeGUICreate( Table ) end or nil)
	HomeNode.mytable.guiupdate = (function( _, Table ) ACFHomeGUIUpdate( Table ) end or nil)

	function HomeNode:DoClick()
		acfmenupanel:UpdateDisplay(self.mytable)
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
					RunConsoleCommand( "acfmenu_type", self.mytable.type )
					acfmenupanel:UpdateDisplay( self.mytable )
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
				RunConsoleCommand( "acfmenu_type", self.mytable.type )
				acfmenupanel:UpdateDisplay( self.mytable )
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
			RunConsoleCommand("acfmenu_type", self.mytable.type)
			acfmenupanel:UpdateDisplay(self.mytable)
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
				RunConsoleCommand( "acfmenu_type", EngineData.type )
				acfmenupanel:UpdateDisplay( EngineData )
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
				RunConsoleCommand( "acfmenu_type", GearboxData.type )
				acfmenupanel:UpdateDisplay( GearboxData )
				end
			end
		end

		-------------------- FuelTank folder --------------------

		--Creates the only button to access to fueltank config menu.
		for _, FuelTankData in pairs(FinalContainer["FuelTanks"]) do

			function FuelTanks:DoClick()
				RunConsoleCommand( "acfmenu_type", FuelTankData.type )
				acfmenupanel:UpdateDisplay( FuelTankData )
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
						RunConsoleCommand( "acfmenu_type", self.mytable.type )
						acfmenupanel:UpdateDisplay( self.mytable )
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
				RunConsoleCommand( "acfmenu_type", ToolData.type )
				acfmenupanel:UpdateDisplay( ToolData )
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
			guicreate = function(_, Table) ACFCrewMenuGUICreate(Table) end,
			guiupdate = function() return end
		}

		function CrewNode:DoClick()
			acfmenupanel:UpdateDisplay(self.mytable)
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
				RunConsoleCommand("acfmenu_type", self.mytable.type)
				acfmenupanel:UpdateDisplay(self.mytable)
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

	CLNod.mytable.guicreate = (function( _, Table ) ACFCLGUICreate( Table ) end or nil)
	SVNod.mytable.guicreate = (function( _, Table ) ACFSVGUICreate( Table ) end or nil)

	function CLNod:DoClick()
		acfmenupanel:UpdateDisplay(self.mytable)
	end
	function SVNod:DoClick()
		acfmenupanel:UpdateDisplay(self.mytable)
	end
	OptionsNode.Icon:SetImage( "icon16/wrench_orange.png" )

	end

	do

	--[[==================================================
					Contact & Support folder
	]]--==================================================

	local Contact =  TreePanel:AddNode( "Contact Us" , "icon16/feed.png" ) --Options folder
	Contact.mytable = {}

	Contact.mytable.guicreate = (function( _, Table ) ContactGUICreate( Table ) end or nil)

	function Contact:DoClick()
		acfmenupanel:UpdateDisplay(self.mytable)
	end

	end

	self.WeaponSelect = TreePanel

end

function PANEL:UpdateRoundCostPreview()

	local DisplayTable = self.ActiveDisplayTable
	if not istable(DisplayTable) or DisplayTable.type ~= "Ammo" or DisplayTable.Type == "Refill" then return end
	if not ACF_GetRoundFromCVars or not ACE.Points_RoundFromBullet or not ACE.Points_BaseRoundCost then return end
	if not IsValid(self.CustomDisplay) then return end

	local RoundType = ACF.RoundTypes[DisplayTable.Type or ""]
	if not RoundType or not isfunction(RoundType.convert) then return end

	local RawData = ACF_GetRoundFromCVars()
	local Success, BulletData = pcall(RoundType.convert, self, RawData)
	if not Success or not istable(BulletData) then return end
	BulletData.Id = RawData.Id
	BulletData.Type = DisplayTable.Type or RawData.Type
	BulletData.Data7 = RawData.Data7

	local Round = ACE.Points_RoundFromBullet(BulletData)
	if not Round then return end

	local Cost = string.Comma(math.Round(ACE.Points_BaseRoundCost(Round)))
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

	RunConsoleCommand( "acfmenu_id", Table.id or 0 )

	--If a previous display exists, erase it
	if ( acfmenupanel.CustomDisplay ) then
	acfmenupanel.CustomDisplay:Clear(true)
	acfmenupanel.CustomDisplay = nil
	acfmenupanel.CData = nil
	end
	--Create the space to display the custom data
	acfmenupanel.CustomDisplay = vgui.Create( "DPanelList", acfmenupanel )
	acfmenupanel.CustomDisplay:SetSpacing( 10 )
	acfmenupanel.CustomDisplay:EnableHorizontal( false )
	acfmenupanel.CustomDisplay:EnableVerticalScrollbar( false )
	acfmenupanel.CustomDisplay:SetSize( acfmenupanel:GetWide(), acfmenupanel:GetTall() )

	if not acfmenupanel["CData"] then
	--Create a table for the display to store data
	acfmenupanel["CData"] = {}
	end

	acfmenupanel.ActiveDisplayTable = Table
	acfmenupanel.CreateAttribs = Table.guicreate

	local UpdateAttribs = Table.guiupdate
	if Table.type == "Ammo" and isfunction(UpdateAttribs) then
		acfmenupanel.UpdateAttribs = function(Panel, ...)
			local Result = UpdateAttribs(Panel, ...)
			Panel:QueueRoundCostPreview()
			return Result
		end
	else
		acfmenupanel.UpdateAttribs = UpdateAttribs
	end

	acfmenupanel:CreateAttribs( Table )
	acfmenupanel:QueueRoundCostPreview()

	acfmenupanel:PerformLayout()

end

function PANEL:PerformLayout()

	--Starting positions
	local vspacing = 10
	local ypos = 0

	--Selection Tree panel
	acfmenupanel.WeaponSelect:SetPos( 0, ypos )
	acfmenupanel.WeaponSelect:SetSize( acfmenupanel:GetWide(), ScrH() * 0.4 )
	ypos = acfmenupanel.WeaponSelect.Y + acfmenupanel.WeaponSelect:GetTall() + vspacing

	if acfmenupanel.CustomDisplay then
	--Custom panel
	acfmenupanel.CustomDisplay:SetPos( 0, ypos )
	acfmenupanel.CustomDisplay:SetSize( acfmenupanel:GetWide(), acfmenupanel:GetTall() - acfmenupanel.WeaponSelect:GetTall() - 10 )
	ypos = acfmenupanel.CustomDisplay.Y + acfmenupanel.CustomDisplay:GetTall() + vspacing
	end

end

--[[=========================
	ACE information folder content
]]--=========================
function ACFHomeGUICreate()

	if not acfmenupanel.CustomDisplay then return end

	local versionstring

	if ACF.CurrentVersion and ACF.CurrentVersion > 0 then
	if ACF.Version >= ACF.CurrentVersion then
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

	local versiontext = "GitHub Version: " .. ACF.CurrentVersion .. "\nCurrent Version: " .. ACF.Version

	acfmenupanel["CData"]["VersionInit"] = vgui.Create( "DLabel" )
	acfmenupanel["CData"]["VersionInit"]:SetText(versiontext)
	acfmenupanel["CData"]["VersionInit"]:SetDark( true )
	acfmenupanel["CData"]["VersionInit"]:SizeToContents()
	acfmenupanel.CustomDisplay:AddItem( acfmenupanel["CData"]["VersionInit"] )


	acfmenupanel["CData"]["VersionText"] = vgui.Create( "DLabel" )

	acfmenupanel["CData"]["VersionText"]:SetFont("Trebuchet18")
	acfmenupanel["CData"]["VersionText"]:SetText("ACE Is " .. versionstring .. "!\n\n")
	acfmenupanel["CData"]["VersionText"]:SetDark( true )
	acfmenupanel["CData"]["VersionText"]:SizeToContents()

	acfmenupanel.CustomDisplay:AddItem( acfmenupanel["CData"]["VersionText"] )
	-- end version

	acfmenupanel:CPanelText("Header", "Changelog")  --changelog screen

--[[=========================
	Changelog table maker
]]--=========================

	if acfmenupanel.Changelog then
	acfmenupanel["CData"]["Changelist"] = vgui.Create( "DTree" )

	for i = 0, table.maxn(acfmenupanel.Changelog) - 100 do

		local k = table.maxn(acfmenupanel.Changelog) - i

		local Node = acfmenupanel["CData"]["Changelist"]:AddNode( "Rev " .. k )
			Node.mytable = {}
			Node.mytable["rev"] = k
				function Node:DoClick()

				acfmenupanel:UpdateAttribs( Node.mytable )

			end
		Node.Icon:SetImage( "icon16/newspaper.png" )

	end

	acfmenupanel.CData.Changelist:SetSize( acfmenupanel.CustomDisplay:GetWide(), 60 )

	acfmenupanel.CustomDisplay:AddItem( acfmenupanel["CData"]["Changelist"] )

	acfmenupanel.CustomDisplay:PerformLayout()

	acfmenupanel:UpdateAttribs( {rev = table.maxn(acfmenupanel.Changelog)} )
	end

end

--[[=========================
	ACE information folder content updater
]]--=========================
function ACFHomeGUIUpdate( Table )

	acfmenupanel:CPanelText("Changelog", acfmenupanel.Changelog[Table["rev"]])
	acfmenupanel.CustomDisplay:PerformLayout()

	local color
	local versionstring

	if ACF.CurrentVersion > 0 then
		if ACF.Version >= ACF.CurrentVersion then
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

	if ACF.CurrentVersion > 0 then
		txt = "ACE Is " .. versionstring .. "!\n\n"
	else
		txt = versionstring
	end

	acfmenupanel["CData"]["VersionText"]:SetText(txt)
	acfmenupanel["CData"]["VersionText"]:SetDark( true )
	acfmenupanel["CData"]["VersionText"]:SetColor(color)
	acfmenupanel["CData"]["VersionText"]:SizeToContents()

end

--[[=========================
	Changelog.txt
]]--=========================

function ACFChangelogHTTPCallBack(contents)
	local Temp = string.Explode( "*", contents )

	acfmenupanel.Changelog = {}  --changelog table
	for _,String in pairs(Temp) do
		acfmenupanel.Changelog[tonumber(string.sub(String,2,4))] = string.Trim(string.sub(String, 5))
	end

	table.SortByKey(acfmenupanel.Changelog,true)

	local Table = {}
	Table.guicreate = (function( _, Table ) ACFHomeGUICreate( Table ) end or nil)
	Table.guiupdate = (function( _, Table ) ACFHomeGUIUpdate( Table ) end or nil)
	acfmenupanel:UpdateDisplay( Table )

end

http.Fetch("http://raw.github.com/ACE-Project-Team/ArmoredCombatExtended/master/changelog.txt", ACFChangelogHTTPCallBack, function() end)

--[[=========================
	Clientside folder content
]]--=========================
function ACFCLGUICreate()

	local Client = acfmenupanel["CData"]["Options"]

	Client = vgui.Create( "DLabel" )
	Client:SetPos( 0, 0 )
	Client:SetColor( Color(10,10,10) )
	Client:SetText("ACE - Client Side Control Panel")
	Client:SetFont("DermaDefaultBold")
	Client:SizeToContents()
	acfmenupanel.CustomDisplay:AddItem( Client )

	local Sub = vgui.Create( "DLabel" )
	Sub:SetPos( 0, 0 )
	Sub:SetColor( Color(10,10,10) )
	Sub:SetText("Client Side parameters can be adjusted here.")
	Sub:SizeToContents()
	acfmenupanel.CustomDisplay:AddItem( Sub )

	local Sounds = vgui.Create( "DForm" )
	Sounds:SetName("Sounds")

	Sounds:CheckBox("Allow Tinnitus Noise", "acf_tinnitus")
	Sounds:ControlHelp( "Allows the ear tinnitus effect to be applied when an explosive was detonated too close to your position, improving the inmersion during combat." )

	Sounds:NumSlider( "Ambient overall sounds", "acf_sound_volume", 0, 100, 0 )
	Sounds:ControlHelp( "Adjusts the volume of ACE sounds like explosions, penetrations, ricochets, etc. Engines and some mechanic sounds are not affected yet." )

	acfmenupanel.CustomDisplay:AddItem( Sounds )

	local Effects = vgui.Create( "DForm" )
	Effects:SetName("Rendering")

	Effects:CheckBox("Allow lighting rendering", "acf_enable_lighting")
	Effects:ControlHelp( "Enables lighting for explosions, muzzle flashes and rocket motors, increasing the inmersion during combat, however, may impact heavily the performance and it's possible it doesn't render properly in certain map surfaces." )

	Effects:CheckBox("Draw Mobility rope links", "ACF_MobilityRopeLinks")
	Effects:ControlHelp( "Allow you to see the links between engines and gearboxes (requires dupe restart)" )

	acfmenupanel.CustomDisplay:AddItem( Effects )

	local DupeSection = vgui.Create( "DForm" )
	DupeSection:SetName("Dupe Loader")

	DupeSection:Help( "If for some reason, your ace dupe folder was damaged or deleted, you can restore them here." )
	DupeSection:Button("Restore ace dupe folders", "ace_dupes_remount" )

	acfmenupanel.CustomDisplay:AddItem( DupeSection )

end

local function MenuNotifyError()

	local Note = vgui.Create( "DLabel" )
	Note:SetPos( 0, 0 )
	Note:SetColor( Color(10,10,10) )
	Note:SetText("Not available in this moment")
	Note:SizeToContents()
	acfmenupanel.CustomDisplay:AddItem( Note )

end


--[[=========================
	Serverside folder content
]]--=========================
function ACFSVGUICreate()	--Serverside folder content

	local ply = LocalPlayer()
	if not IsValid(ply) then return end
	if not ply:IsSuperAdmin() then return end
	if game.IsDedicated() then MenuNotifyError() return end

	local Server = acfmenupanel["CData"]["Options"]

	Server = vgui.Create( "DLabel" )
	Server:SetPos( 0, 0 )
	Server:SetColor( Color(10,10,10) )
	Server:SetText("ACE - Server Side Control Panel")
	Server:SetFont("DermaDefaultBold")
	Server:SizeToContents()
	acfmenupanel.CustomDisplay:AddItem( Server )

	local Sub = vgui.Create( "DLabel" )
	Sub:SetPos( 0, 0 )
	Sub:SetColor( Color(10,10,10) )
	Sub:SetText("Server Side parameters can be adjusted here")
	Sub:SizeToContents()
	acfmenupanel.CustomDisplay:AddItem( Sub )

	local General = vgui.Create( "DForm" )
	General:SetName("General")

	General:CheckBox("Enable HE push", "acf_hepush")
	General:ControlHelp( "Allow HE to push contraptions away" )

	General:CheckBox("Enable Recoil force", "acf_recoilpush")
	General:ControlHelp( "Gun's recoil will push the contraption back when firing" )

	General:NumSlider( "Debris Life Time", "acf_debris_lifetime", 0, 60, 2 )
	General:ControlHelp( "How many seconds debris will stand on the map before being deleted (0 means never)." )

	General:NumSlider( "Child debris chance", "acf_debris_children", 0, 1, 2 )
	General:ControlHelp( "Adjusts the chance of create debris when a contraption's gate have been destroyed" )

	--General:NumSlider( "Year", "acf_year", 1900, 2021, 0 )
	--General:ControlHelp( "Changes the year. This will affect the available weaponry (requires restart)." )

	acfmenupanel.CustomDisplay:AddItem( General )

	local Spall = vgui.Create( "DForm" )
	Spall:SetName("Spalling")

	Spall:CheckBox("Enable Spalling", "acf_spalling")
	Spall:ControlHelp( "Enable additional spalling to be created during penetrations. Disable this to have better performance." )

	Spall:NumSlider( "Spalling Multipler", "acf_spalling_multipler", 1, 5, 0 )
	Spall:ControlHelp( "How much Spalling will be created during impacts? Applies for spalling created by impacts" )

	acfmenupanel.CustomDisplay:AddItem( Spall )

	local Scaled = vgui.Create( "DForm" )
	Scaled:SetName("Cooking off")

	Scaled:NumSlider( "Max HE per explosion", "acf_explosions_scaled_he_max", 50, 1000, 0 )
	Scaled:ControlHelp( "The maximum amount of HE weight to detonate at once." )

	Scaled:NumSlider( "Max entities per explosion", "acf_explosions_scaled_ents_max", 1, 20, 0 )
	Scaled:ControlHelp( "The maximum amount of entities to detonate at once." )

	acfmenupanel.CustomDisplay:AddItem( Scaled )

	local Legal = vgui.Create( "DForm" )
	Legal:SetName("Legality")

	Legal:CheckBox("Enable Legality checks", "acf_legalcheck")
	Legal:ControlHelp( "Enable the legality checks, which will punish with a lock time any stuff considered illegal." )

	Legal:CheckBox( "Allow not solid", "acf_legal_ignore_solid" )
	Legal:ControlHelp( "allow to use not solid" )

	Legal:CheckBox( "Allow any model", "acf_legal_ignore_model" )
	Legal:ControlHelp( "Allow ace ents to use any model" )

	Legal:CheckBox( "Allow any mass", "acf_legal_ignore_mass" )
	Legal:ControlHelp( "Allow ace ents to use any weight" )

	Legal:CheckBox( "Allow any material", "acf_legal_ignore_material" )
	Legal:ControlHelp( "Allow ace ents to use any material type" )

	Legal:CheckBox( "Allow any inertia", "acf_legal_ignore_inertia" )
	Legal:ControlHelp( "Allow ace ents to have any inertia in it" )

	Legal:CheckBox("Allow makesphere", "acf_legal_ignore_makesphere")
	Legal:ControlHelp( "Allow ace ents to have makesphere" )

	Legal:CheckBox( "Allow visclip", "acf_legal_ignore_visclip" )
	Legal:ControlHelp( "ace ents can have visclip at any case" )

	acfmenupanel.CustomDisplay:AddItem( Legal )

end

--[[=========================
	Contact folder content
]]--=========================
function ContactGUICreate()

	acfmenupanel["CData"]["Contact"] = vgui.Create( "DLabel" )
	acfmenupanel["CData"]["Contact"]:SetPos( 0, 0 )
	acfmenupanel["CData"]["Contact"]:SetColor( Color(10,10,10) )
	acfmenupanel["CData"]["Contact"]:SetText("Contact Us")
	acfmenupanel["CData"]["Contact"]:SetFont("Trebuchet24")
	acfmenupanel["CData"]["Contact"]:SizeToContents()
	acfmenupanel.CustomDisplay:AddItem( acfmenupanel["CData"]["Contact"] )

	acfmenupanel:CPanelText("desc1","If you want to contribute to ACE by providing us feedback, report bugs or tell us suggestions about new stuff to be added, our discord is a good place.")
	acfmenupanel:CPanelText("desc2","Don't forget to check out our wiki, contains valuable information about how to use this addon. It's on WIP, but expect more content in future.")

	local Discord = vgui.Create("DButton")
	Discord:SetText( "Join our Discord!" )
	Discord:SetPos(0,0)
	Discord:SetSize(250,30)
	Discord.DoClick = function()
	gui.OpenURL("https://discord.gg/Y8aEYU6")
	end
	acfmenupanel.CustomDisplay:AddItem( Discord )

	local Wiki = vgui.Create("DButton")
	Wiki:SetText( "Open Wiki" )
	Wiki:SetPos(0,0)
	Wiki:SetSize(250,30)
	Wiki.DoClick = function()
	gui.OpenURL("https://github.com/ACE-Project-Team/ArmoredCombatExtended/wiki")
	end
	acfmenupanel.CustomDisplay:AddItem( Wiki )

	local Guide = vgui.Create("DButton")
	Guide:SetText( "ACE guidelines" )
	Guide:SetPos(0,0)
	Guide:SetSize(250,30)
	Guide.DoClick = function()
	gui.OpenURL("https://docs.google.com/document/d/1yaHq4Lfjad4KKa0Jg9s-5lCpPVjV7FE4HXoGaKpi4Fs/edit")
	end
	acfmenupanel.CustomDisplay:AddItem( Guide )

end

--===========================================================================================
-----Ammo & Gun selection content
--===========================================================================================

do

	local function CreateIdForCrate( self )

		if not acfmenupanel.AmmoPanelConfig["LegacyAmmos"] then

			local X = math.Round( acfmenupanel.AmmoPanelConfig["Crate_Length"], 1 )
			local Y = math.Round(acfmenupanel.AmmoPanelConfig["Crate_Width"], 1 )
			local Z = math.Round(acfmenupanel.AmmoPanelConfig["Crate_Height"], 1)

			local Id = X .. ":" .. Y .. ":" .. Z

			acfmenupanel.AmmoData["Id"] = Id
			RunConsoleCommand( "acfmenu_id", Id )

		end

		self:UpdateAttribs()

	end

	function PANEL:AmmoSelect( Blacklist )

	if not acfmenupanel.CustomDisplay then return end
	if not Blacklist then Blacklist = {} end

	if not acfmenupanel.AmmoData then

		acfmenupanel.AmmoData               = {}
		acfmenupanel.AmmoData["Id"]         = "10:10:10"  --default Ammo dimension on list
		acfmenupanel.AmmoData["IdLegacy"]   = "Shell100mm"
		acfmenupanel.AmmoData["Type"]       = "Ammo"
		acfmenupanel.AmmoData["Classname"]  = Classes.GunClass["MG"]["name"]
		acfmenupanel.AmmoData["ClassData"]  = Classes.GunClass["MG"]["id"]
		acfmenupanel.AmmoData["Data"]       = ACFEnts["Guns"]["12.7mmMG"]["round"]
	end

	if not acfmenupanel.AmmoPanelConfig then

		acfmenupanel.AmmoPanelConfig = {}
		acfmenupanel.AmmoPanelConfig["ExpandedCatNew"] = true
		acfmenupanel.AmmoPanelConfig["ExpandedCatOld"] = false
		acfmenupanel.AmmoPanelConfig["LegacyAmmos"]	= false
		acfmenupanel.AmmoPanelConfig["Crate_Length"]  = 10
		acfmenupanel.AmmoPanelConfig["Crate_Width"]	= 10
		acfmenupanel.AmmoPanelConfig["Crate_Height"]  = 10

	end

	local MainPanel = self
	local CrateNewCat = vgui.Create( "DCollapsibleCategory" )	-- Create a collapsible category
	acfmenupanel.CustomDisplay:AddItem(CrateNewCat)
	CrateNewCat:SetLabel( "Crate Config" )						-- Set the name ( label )
	CrateNewCat:SetPos( 25, 50 )		-- Set position
	CrateNewCat:SetSize( 250, 100 )	-- Set size
	CrateNewCat:SetExpanded( acfmenupanel.AmmoPanelConfig["ExpandedCatNew"] )

	function CrateNewCat:OnToggle( bool )
		acfmenupanel.AmmoPanelConfig["ExpandedCatNew"] = bool
	end

	local CrateNewPanel = vgui.Create( "DPanelList" )
	CrateNewPanel:SetSpacing( 10 )
	CrateNewPanel:EnableHorizontal( false )
	CrateNewPanel:EnableVerticalScrollbar( true )
	CrateNewPanel:SetPaintBackground( false )
	CrateNewCat:SetContents( CrateNewPanel )

	local CrateOldCat = vgui.Create( "DCollapsibleCategory" )
	acfmenupanel.CustomDisplay:AddItem(CrateOldCat)
	CrateOldCat:SetLabel( "Crate Config (legacy)" )
	CrateOldCat:SetPos( 25, 50 )
	CrateOldCat:SetSize( 250, 100 )
	CrateOldCat:SetExpanded( acfmenupanel.AmmoPanelConfig["ExpandedCatOld"] )

	function CrateOldCat:OnToggle( bool )
		acfmenupanel.AmmoPanelConfig["ExpandedCatOld"] = bool
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

		local MinCrateSize = ACF.CrateMinimumSize
		local MaxCrateSize = ACF.CrateMaximumSize

		acfmenupanel:CPanelText("Crate_desc_new", "\nAdjust the dimensions for your crate. In inches.", nil, CrateNewPanel)

		local LengthSlider = vgui.Create( "DNumSlider" )
		LengthSlider:SetText( "Length" )
		LengthSlider:SetDark( true )
		LengthSlider:SetMin( MinCrateSize )
		LengthSlider:SetMax( MaxCrateSize )
		LengthSlider:SetValue( acfmenupanel.AmmoPanelConfig["Crate_Length"] or 10 )
		LengthSlider:SetDecimals( 1 )

		function LengthSlider:OnValueChanged( value )
			acfmenupanel.AmmoPanelConfig["Crate_Length"] = value
			CreateIdForCrate( MainPanel )
		end
		CrateNewPanel:AddItem(LengthSlider)

		local WidthSlider = vgui.Create( "DNumSlider" )
		WidthSlider:SetText( "Width" )
		WidthSlider:SetDark( true )
		WidthSlider:SetMin( MinCrateSize )
		WidthSlider:SetMax( MaxCrateSize )
		WidthSlider:SetValue( acfmenupanel.AmmoPanelConfig["Crate_Width"] or 10 )
		WidthSlider:SetDecimals( 1 )

		function WidthSlider:OnValueChanged( value )
			acfmenupanel.AmmoPanelConfig["Crate_Width"] = value
			CreateIdForCrate( MainPanel )
		end
		CrateNewPanel:AddItem(WidthSlider)

		local HeightSlider = vgui.Create( "DNumSlider" )
		HeightSlider:SetText( "Height" )
		HeightSlider:SetDark( true )
		HeightSlider:SetMin( MinCrateSize )
		HeightSlider:SetMax( MaxCrateSize )
		HeightSlider:SetValue( acfmenupanel.AmmoPanelConfig["Crate_Height"] or 10 )
		HeightSlider:SetDecimals( 1 )

		function HeightSlider:OnValueChanged( value )
			acfmenupanel.AmmoPanelConfig["Crate_Height"] = value
			CreateIdForCrate( MainPanel )
		end
		CrateNewPanel:AddItem(HeightSlider)

	end

	--------------- OLD CONFIG ---------------
	do

		acfmenupanel:CPanelText("Crate_desc_legacy", "\nChoose a crate in the legacy way. Remember to enable the checkbox below to do so.", nil, CrateOldPanel)
		acfmenupanel:CPanelText("Crate_desc_legacy2", "DISCLAIMER: These crates are deprecated and dont't follow any proper format like the capacity or size. Don't trust on these crates, apart they might be removed in a future!", nil, CrateOldPanel)

		local LegacyCheck = vgui.Create( "DCheckBoxLabel" ) -- Create the checkbox
		LegacyCheck:SetPos( 25, 50 )							-- Set the position
		LegacyCheck:SetText("Use Legacy Mode")					-- Set the text next to the box
		LegacyCheck:SetDark( true )
		LegacyCheck:SetChecked( acfmenupanel.AmmoPanelConfig["LegacyAmmos"] or false )						-- Initial value
		LegacyCheck:SizeToContents()							-- Make its size the same as the contents

		function LegacyCheck:OnChange( val )
			acfmenupanel.AmmoPanelConfig["LegacyAmmos"] = val
			if val then
				acfmenupanel.AmmoData["Id"] =  acfmenupanel.AmmoData["IdLegacy"]
				RunConsoleCommand( "acfmenu_id", acfmenupanel.AmmoData["Id"] )
			else
				CreateIdForCrate( MainPanel )
			end

			MainPanel:UpdateAttribs()

		end

		CrateOldPanel:AddItem(LegacyCheck)

		local AmmoComboBox = vgui.Create( "DComboBox", CrateOldPanel )	--Every display and slider is placed in the Round table so it gets trashed when selecting a new round type
		AmmoComboBox:SetSize(acfmenupanel.CustomDisplay:GetWide(), 30)

		for Key, Value in pairs( ACFEnts.Ammo ) do

			AmmoComboBox:AddChoice( Value.id , Key ) --Creates the list

		end

		AmmoComboBox.OnSelect = function( _ , _ , data )	-- calls the ID of the list
			if acfmenupanel.AmmoPanelConfig["LegacyAmmos"] then
			RunConsoleCommand( "acfmenu_id", data )
			acfmenupanel.AmmoData["Id"] = data
			end

			acfmenupanel.AmmoData["IdLegacy"] = data

			if acfmenupanel.CData.CrateDisplay then

			local cratemodel = ACFEnts.Ammo[acfmenupanel.AmmoData["IdLegacy"]].model
			acfmenupanel.CData.CrateDisplay:SetModel(cratemodel)
			acfmenupanel:CPanelText("CrateDesc", ACFEnts.Ammo[acfmenupanel.AmmoData["IdLegacy"]].desc, nil, CrateOldPanel)

			end

			MainPanel:UpdateAttribs()

		end

		AmmoComboBox:SetText(acfmenupanel.AmmoData["IdLegacy"])
		RunConsoleCommand( "acfmenu_id", acfmenupanel.AmmoData["Id"] )

		CrateOldPanel:AddItem(AmmoComboBox)

	--===========================================================================================
	-----Creating the Model display
	--===========================================================================================

		--Used to create the general model display
		if not acfmenupanel.CData.CrateDisplay then

			acfmenupanel:CPanelText("CrateDesc", ACFEnts.Ammo[acfmenupanel.AmmoData["IdLegacy"]].desc, nil, CrateOldPanel)

			acfmenupanel.CData.CrateDisplay = vgui.Create( "DModelPanel", CrateOldPanel )
			acfmenupanel.CData.CrateDisplay:SetSize(acfmenupanel.CustomDisplay:GetWide(),acfmenupanel.CustomDisplay:GetWide() / 2)
			acfmenupanel.CData.CrateDisplay:SetCamPos( Vector( 250, 500, 250 ) )
			acfmenupanel.CData.CrateDisplay:SetLookAt( Vector( 0, 0, 0 ) )
			acfmenupanel.CData.CrateDisplay:SetFOV( 10 )
			acfmenupanel.CData.CrateDisplay:SetModel(ACFEnts.Ammo[acfmenupanel.AmmoData["IdLegacy"]].model)
			acfmenupanel.CData.CrateDisplay.LayoutEntity = function() end

			CrateOldPanel:AddItem(acfmenupanel.CData.CrateDisplay)

		end

	end

	--===========================================================================================
	-----Creating the gun Class display
	--===========================================================================================

	acfmenupanel.CData.ClassSelect = vgui.Create( "DComboBox", acfmenupanel.CustomDisplay)
	acfmenupanel.CData.ClassSelect:SetSize(100, 30)

	local DComboList = {}

	for _, GunTable in pairs( Classes.GunClass ) do

		if not table.HasValue( Blacklist, GunTable.id ) then
			acfmenupanel.CData.ClassSelect:AddChoice( GunTable.name , GunTable.id )
			DComboList[GunTable.id] = true

		end
	end

	acfmenupanel.CData.ClassSelect:SetText( acfmenupanel.AmmoData["Classname"] .. (not DComboList[acfmenupanel.AmmoData["ClassData"]] and " - update caliber!" or "" ))
	acfmenupanel.CData.ClassSelect:SetColor( not DComboList[acfmenupanel.AmmoData["ClassData"]] and Color(255,0,0) or Color(0,0,0) )

	acfmenupanel.CData.ClassSelect.OnSelect = function( _ , index , data )

		data = acfmenupanel.CData.ClassSelect:GetOptionData(index) -- Why?

		acfmenupanel.AmmoData["Classname"] = Classes.GunClass[data]["name"]
		acfmenupanel.AmmoData["ClassData"] = Classes.GunClass[data]["id"]

		acfmenupanel.CData.ClassSelect:SetColor( Color(0,0,0) )

		acfmenupanel.CData.CaliberSelect:Clear()

		for Key, Value in pairs( ACFEnts.Guns ) do

			if acfmenupanel.AmmoData["ClassData"] == Value.gunclass then
			acfmenupanel.CData.CaliberSelect:AddChoice( Value.id , Key )
			end

		end

		MainPanel:UpdateAttribs()
		MainPanel:UpdateAttribs() --Note : this is intentional
	end

	acfmenupanel.CustomDisplay:AddItem( acfmenupanel.CData.ClassSelect )

	--===========================================================================================
	-----Creating the caliber selection display
	--===========================================================================================

	acfmenupanel.CData.CaliberSelect = vgui.Create( "DComboBox", acfmenupanel.CustomDisplay )
	acfmenupanel.CData.CaliberSelect:SetSize(100, 30)

	acfmenupanel.CData.CaliberSelect:SetText(acfmenupanel.AmmoData["Data"]["id"]  )

	for Key, Value in pairs( ACFEnts.Guns ) do

		if acfmenupanel.AmmoData["ClassData"] == Value.gunclass then
			acfmenupanel.CData.CaliberSelect:AddChoice( Value.id , Key )
		end

	end

	acfmenupanel.CData.CaliberSelect.OnSelect = function( _ , _ , gun )

		acfmenupanel.AmmoData["Data"] = ACFEnts["Guns"][gun]["round"]
		MainPanel:UpdateAttribs()
		MainPanel:UpdateAttribs() --Note : this is intentional

	end

	acfmenupanel.CustomDisplay:AddItem( acfmenupanel.CData.CaliberSelect )

	end
end

function PANEL:AmmoSlider(Name, Value, Min, Max, Decimals, Title, Desc) --Variable name in the table, Value, Min value, Max Value, slider text title, slider decimeals, description text below slider

	if not acfmenupanel["CData"][Name] then

	acfmenupanel["CData"][Name] = vgui.Create( "DNumSlider", acfmenupanel.CustomDisplay )
	acfmenupanel["CData"][Name].Label:SetSize( 0 )  --Note : this is intentional
	acfmenupanel["CData"][Name]:SetTall( 50 )	-- make the slider taller to fit the new label
	acfmenupanel["CData"][Name]:SetMin( 0 )
	acfmenupanel["CData"][Name]:SetMax( 1000 )
	acfmenupanel["CData"][Name]:SetDark( true )
	acfmenupanel["CData"][Name]:SetDecimals( Decimals )

	acfmenupanel["CData"][Name .. "_label"] = vgui.Create( "DLabel", acfmenupanel["CData"][Name]) -- recreating the label
	acfmenupanel["CData"][Name .. "_label"]:SetPos( 0, 0)
	acfmenupanel["CData"][Name .. "_label"]:SetText( Title )
	acfmenupanel["CData"][Name .. "_label"]:SizeToContents()
	acfmenupanel["CData"][Name .. "_label"]:SetDark( true )

	if acfmenupanel.AmmoData[Name] then
			acfmenupanel["CData"][Name]:SetValue(acfmenupanel.AmmoData[Name])
	end

	acfmenupanel["CData"][Name].OnValueChanged = function( _, val )

	--Programmatic SetMin/SetMax/SetValue (below) fire DNumSlider:ValueChanged, which calls
	--this handler; skip re-entry during those so UpdateAttribs can't recurse into a stack overflow.
	if acfmenupanel["CData"][Name].ACEProgrammatic then return end

	if acfmenupanel.AmmoData[Name] ~= val then

		acfmenupanel.AmmoData[Name] = val
			self:UpdateAttribs( Name )
		end

	end

	acfmenupanel.CustomDisplay:AddItem( acfmenupanel["CData"][Name] )

	end

	acfmenupanel["CData"][Name].ACEProgrammatic = true
	acfmenupanel["CData"][Name]:SetMin( Min )
	acfmenupanel["CData"][Name]:SetMax( Max )
	acfmenupanel["CData"][Name]:SetValue( Value )
	acfmenupanel["CData"][Name].ACEProgrammatic = false

	if not acfmenupanel["CData"][Name .. "_text"] and Desc then

	acfmenupanel["CData"][Name .. "_text"] = vgui.Create( "DLabel" )
	acfmenupanel["CData"][Name .. "_text"]:SetText( Desc or "" )
	acfmenupanel["CData"][Name .. "_text"]:SetDark( true )
	acfmenupanel["CData"][Name .. "_text"]:SetTall( 20 )
	acfmenupanel.CustomDisplay:AddItem( acfmenupanel["CData"][Name .. "_text"] )

	end

	acfmenupanel["CData"][Name .. "_text"]:SetText( Desc )
	acfmenupanel["CData"][Name .. "_text"]:SetSize( acfmenupanel.CustomDisplay:GetWide(), 14 )
	acfmenupanel["CData"][Name .. "_text"]:SizeToContentsX()

end

-- Variable name in the table, slider text title, slider decimeals, description text below slider
function PANEL:AmmoCheckbox(Name, Title, Desc, Tooltip )

	if not acfmenupanel["CData"][Name] then

	acfmenupanel["CData"][Name] = vgui.Create( "DCheckBoxLabel" )
	acfmenupanel["CData"][Name]:SetText( Title or "" )
	acfmenupanel["CData"][Name]:SetDark( true )
	acfmenupanel["CData"][Name]:SizeToContents()
	acfmenupanel["CData"][Name]:SetChecked(acfmenupanel.AmmoData[Name] or false)

	acfmenupanel["CData"][Name].OnChange = function( _, bval )

		bval = bval and 1 or 0 -- converting to number since booleans sucks in this duty

		acfmenupanel.AmmoData[Name] = tonumber(bval) --print(isstring(acfmenupanel.AmmoData[Name]))

		self:UpdateAttribs()

	end

	if Tooltip and Tooltip ~= "" then
		acfmenupanel["CData"][Name]:SetTooltip( Tooltip )
	end

	acfmenupanel.CustomDisplay:AddItem( acfmenupanel["CData"][Name] )

	end

	acfmenupanel["CData"][Name]:SetText( Title )

	if not acfmenupanel["CData"][Name .. "_text"] and Desc then

	acfmenupanel["CData"][Name .. "_text"] = acfmenupanel["CData"][Name .. "_text"]
	acfmenupanel["CData"][Name .. "_text"] = vgui.Create( "DLabel" )
	acfmenupanel["CData"][Name .. "_text"]:SetText( Desc or "" )
	acfmenupanel["CData"][Name .. "_text"]:SetDark( true )
	acfmenupanel.CustomDisplay:AddItem( acfmenupanel["CData"][Name .. "_text"] )

	end

	acfmenupanel["CData"][Name .. "_text"]:SetText( Desc )
	acfmenupanel["CData"][Name .. "_text"]:SetSize( acfmenupanel.CustomDisplay:GetWide(), 10 )
	acfmenupanel["CData"][Name .. "_text"]:SizeToContentsX()

end

--[[-------------------------------------
	PANEL:CPanelText(Name, Desc, Font)

	1-Name: Identifier of this text
	2-Desc: The content of this text
	3-Font: The font to be used in this text. Leave it empty or nil to use the default one
	4-
]]---------------------------------------
function PANEL:CPanelText(Name, Desc, Font, Panel)

	if not acfmenupanel["CData"][Name .. "_text"] then

	acfmenupanel["CData"][Name .. "_text"] = vgui.Create( "DLabel" )

	acfmenupanel["CData"][Name .. "_text"]:SetText( Desc or "" )
	acfmenupanel["CData"][Name .. "_text"]:SetDark( true )

	if Font then acfmenupanel["CData"][Name .. "_text"]:SetFont( Font ) end

	acfmenupanel["CData"][Name .. "_text"]:SetWrap(true)
	acfmenupanel["CData"][Name .. "_text"]:SetAutoStretchVertical( true )

	if IsValid(Panel) then
		if Panel.AddItem then
			Panel:AddItem( acfmenupanel["CData"][Name .. "_text"] )
		end
	else
		acfmenupanel.CustomDisplay:AddItem( acfmenupanel["CData"][Name .. "_text"] )
	end
	end

	acfmenupanel["CData"][Name .. "_text"]:SetText( Desc )
	acfmenupanel["CData"][Name .. "_text"]:SetSize( acfmenupanel.CustomDisplay:GetWide(), 10 )
	acfmenupanel["CData"][Name .. "_text"]:SizeToContentsY()

end

--[[=========================
	Crew unified menu GUI
	NOTE: Added for the "single Crew menu" workflow:
	- Clicking "Crew" opens this panel
	- Role + Pose are selected here
	- Spawning still uses the 3 existing entities (Driver/Gunner/Loader), so no builds/dupes break.
]]--=========================
function ACFCrewMenuGUICreate(Table)
	-- Enable scrolling for this page
	if acfmenupanel.CustomDisplay and acfmenupanel.CustomDisplay.EnableVerticalScrollbar then
		acfmenupanel.CustomDisplay:EnableVerticalScrollbar(true)
	end

	local CrewDefs = (ACF and ACF.Weapons and ACF.Weapons.Crewseats) or {}
	if table.IsEmpty(CrewDefs) then
		acfmenupanel:CPanelText("CrewMissing", "No crewseat definitions loaded (ACF.Weapons.Crewseats is empty).")
		acfmenupanel.CustomDisplay:PerformLayout()
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

	RunConsoleCommand("acfmenu_type", "Crewseats")

	local currentId = (Table and Table.id) or RoleToId.Driver
	if not CrewDefs[currentId] then currentId = RoleToId.Driver end

	local currentPose = GetDefaultPoseForId(currentId)

	RunConsoleCommand("acfmenu_id", currentId)
	RunConsoleCommand("acfmenu_entitydata", currentPose)

	-- Header
	acfmenupanel:CPanelText("Crew_Title", "Crew", "DermaDefaultBold")

	-- Role dropdown
	acfmenupanel:CPanelText("Crew_RoleLabel", "\nRole:")

	local RoleSelect = vgui.Create("DComboBox", acfmenupanel.CustomDisplay)
	RoleSelect:SetSize(acfmenupanel.CustomDisplay:GetWide(), 30)
	RoleSelect:AddChoice("Driver")
	RoleSelect:AddChoice("Gunner")
	RoleSelect:AddChoice("Loader")
	RoleSelect:SetValue(GetRoleFromId(currentId))
	acfmenupanel.CustomDisplay:AddItem(RoleSelect)

	-- Pose dropdown
	acfmenupanel:CPanelText("Crew_PoseLabel", "\nPose Model:")

	local PoseSelect = vgui.Create("DComboBox", acfmenupanel.CustomDisplay)
	PoseSelect:SetSize(acfmenupanel.CustomDisplay:GetWide(), 30)

	if ACE and ACE.CrewseatModelList then
		for _, modelName in ipairs(ACE.CrewseatModelList) do
			PoseSelect:AddChoice(modelName, modelName)
		end
	end

	PoseSelect:SetValue(currentPose)
	acfmenupanel.CustomDisplay:AddItem(PoseSelect)

	-- Model preview
	local DisplayModel = vgui.Create("DModelPanel", acfmenupanel.CustomDisplay)
	DisplayModel:SetSize(acfmenupanel.CustomDisplay:GetWide(), acfmenupanel.CustomDisplay:GetWide() * 0.75)
	DisplayModel.LayoutEntity = function() end
	acfmenupanel.CustomDisplay:AddItem(DisplayModel)

	-- Description label
	local DescLabel = vgui.Create("DLabel")
	DescLabel:SetDark(true)
	DescLabel:SetWrap(true)
	DescLabel:SetAutoStretchVertical(true)
	DescLabel:SetText("")
	DescLabel:SetSize(acfmenupanel.CustomDisplay:GetWide() - 10, 20)
	DescLabel:SetContentAlignment(7)
	acfmenupanel.CustomDisplay:AddItem(DescLabel)

	-- Spacer
	local Spacer = vgui.Create("DPanel")
	Spacer:SetSize(acfmenupanel.CustomDisplay:GetWide(), 8)
	Spacer:SetPaintBackground(false)
	acfmenupanel.CustomDisplay:AddItem(Spacer)

	-- Weight label
	local WeightLabel = vgui.Create("DLabel")
	WeightLabel:SetDark(true)
	WeightLabel:SetText("")
	WeightLabel:SetSize(acfmenupanel.CustomDisplay:GetWide(), 20)
	acfmenupanel.CustomDisplay:AddItem(WeightLabel)

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

		RunConsoleCommand("acfmenu_id", currentId)
		RunConsoleCommand("acfmenu_entitydata", currentPose)

		PoseSelect:SetValue(currentPose)
		Refresh()
	end

	PoseSelect.OnSelect = function(_, _, poseName)
		currentPose = poseName or "Sitting"
		RunConsoleCommand("acfmenu_entitydata", currentPose)
		Refresh()
	end

	acfmenupanel.CustomDisplay:PerformLayout()
end

--[[=========================
	Extras GUI (Wind Sensor, G-Force Meter, etc.)
]]--=========================
function ACEExtrasGUICreate(Table)
	acfmenupanel:CPanelText("Name", Table.name, "DermaDefaultBold")

	if Table.model then
		acfmenupanel.CData.DisplayModel = vgui.Create("DModelPanel", acfmenupanel.CustomDisplay)
		acfmenupanel.CData.DisplayModel:SetModel(Table.model)

		-- Adjust camera based on entity type
		if Table.ent == "ace_gforce_meter" then
			acfmenupanel.CData.DisplayModel:SetCamPos(Vector(25, 25, 15))
			acfmenupanel.CData.DisplayModel:SetLookAt(Vector(0, 0, 5))
			acfmenupanel.CData.DisplayModel:SetFOV(50)
		elseif Table.ent == "ace_wind_sensor" then
			acfmenupanel.CData.DisplayModel:SetCamPos(Vector(50, 50, 25))
			acfmenupanel.CData.DisplayModel:SetLookAt(Vector(0, 0, 5))
			acfmenupanel.CData.DisplayModel:SetFOV(35)
		else
			acfmenupanel.CData.DisplayModel:SetCamPos(Vector(50, 50, 40))
			acfmenupanel.CData.DisplayModel:SetLookAt(Vector(0, 0, 10))
			acfmenupanel.CData.DisplayModel:SetFOV(35)
		end

		acfmenupanel.CData.DisplayModel:SetSize(acfmenupanel:GetWide(), acfmenupanel:GetWide() * 0.5)
		acfmenupanel.CData.DisplayModel.LayoutEntity = function() end
		acfmenupanel.CustomDisplay:AddItem(acfmenupanel.CData.DisplayModel)
	end

	-- Clear entity data for non-crew entities
	RunConsoleCommand("acfmenu_entitydata", "")

	acfmenupanel:CPanelText("Desc", "\n" .. Table.desc)

	if Table.weight then
		acfmenupanel:CPanelText("Weight", "\nWeight: " .. Table.weight .. " kg")
	end

	acfmenupanel.CustomDisplay:PerformLayout()
end

--[[=================================================================
	Scalable ACE-entity GUI (shared)

	Scalable ACE entities (the explosive charge) share the same shape + L/W/H
	size config; only the allowed shapes and the stats readout differ.
	BuildScalableConfig draws the shared widgets, filters the shape list through
	the definition's AllowedShapes/BlacklistShapes, keeps the chosen size in
	acfmenupanel.ScalableCfg[class], writes acfmenu_data1 ("L:W:H") +
	acfmenu_data2 (shape), and calls statsFn to render the panel.
]]--==================================================================
do
	local function getCfg(Table)
		acfmenupanel.ScalableCfg = acfmenupanel.ScalableCfg or {}
		local key = Table.ent or Table.id or "scalable"
		local cfg = acfmenupanel.ScalableCfg[key]
		if not cfg then
			local d = Table.MenuDefault or {}
			cfg = {
				L = d.L or 30, W = d.W or 30, H = d.H or 30,
				Shape = d.Shape or "Box", Expanded = true,
			}
			acfmenupanel.ScalableCfg[key] = cfg
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

	function BuildScalableConfig(Table, statsFn)
		if not acfmenupanel.CustomDisplay then return end
		local MainPanel = acfmenupanel.CustomDisplay
		local cfg = getCfg(Table)

		acfmenupanel:CPanelText("Name", Table.name, "DermaDefaultBold")
		acfmenupanel:CPanelText("Desc", Table.desc)

		local statsKey = (Table.ent or "scalable") .. "Stats"

		local function refresh()
			local md = ACE.ModelData[cfg.Shape]
			if not md then return end
			local vol = md.volumefunction(cfg.L, cfg.W, cfg.H)
			acfmenupanel:CPanelText(statsKey, "\n" .. statsFn(cfg, vol))
		end

		local function pushId()
			local Id = math.Round(cfg.L, 1) .. ":" .. math.Round(cfg.W, 1) .. ":" .. math.Round(cfg.H, 1)
			RunConsoleCommand("acfmenu_data1", Id)
			RunConsoleCommand("acfmenu_data2", cfg.Shape)
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

		local minS = ACF.ScalableMinimumSize or ACF.CrateMinimumSize or 5
		-- A definition may cap its size below the global crate limit (explosive
		-- charges do); the server re-clamps in ParseScale, this just matches the UI.
		local maxS = math.min(Table.MaxSize or math.huge, ACF.CrateMaximumSize or 250)

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
function ACEExplosiveGUICreate(Table)
	BuildScalableConfig(Table, function(_cfg, vol)
		local CM3 = 16.387
		local f   = Table.FillerFraction or 0.65
		local fillerMass = vol * CM3 * f * (ACF.HEDensity or 1.65) / 1000 * (ACF.ExplosiveHEMul or 0.12)
		local fragMass   = vol * CM3 * (1 - f) * 7.9 / 1000
		local physMass   = fillerMass + fragMass * (ACF.ExplosiveCasingMul or 0.08)
		local radius     = fillerMass ^ 0.33 * 8
		local points = ACE.Points_ChargeCost and math.Round(ACE.Points_ChargeCost(fillerMass), 1) or 0
		return "HE Filler: " .. math.Round(fillerMass, 2) .. " kg"
			.. "\nBlast Radius: " .. math.Round(radius, 1) .. " m"
			.. "\nBlast Energy: " .. math.Round(fillerMass * (ACF.HEPower or 8000), 0) .. " KJ"
			.. "\nMass: " .. math.Round(physMass, 1) .. " kg"
			.. "\nPoints: " .. points .. " (mounted ordnance)"
	end)
end
function ACEExplosiveGUIUpdate() end

if not ACF then ACF = {} end
if not ACF.ChatMessageReceiver then
	ACF.ChatMessageReceiver = true
	net.Receive( "colorchatmessage", function( _, _ ) --Wooo colored chat
		chat.AddText( net.ReadColor(), net.ReadString() )
	end )
end

