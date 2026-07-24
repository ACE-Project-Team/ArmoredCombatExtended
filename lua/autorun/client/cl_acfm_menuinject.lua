--TODO: merge this file with cl_acemenu_gui.lua since having 2 files for the same function is irrevelant. Little transition has been made though

include("acf/client/cl_acemenu_missileui.lua")

if not ACE then ACE = {} end
if not ACE.ChatMessageReceiver then
	ACE.ChatMessageReceiver = true
	net.Receive("ACE_ColorChatMessage", function()
		chat.AddText(net.ReadColor(), net.ReadString())
	end)
end


local ACFEnts = ACE.Weapons

local function FormatWithCommas(Value, Decimals)
	local Number = tonumber(Value)
	if not Number then return tostring(Value or 0) end

	if Decimals and Decimals > 0 then
		local Format = "%." .. Decimals .. "f"
		local Text = string.format(Format, Number)
		local Whole, Fraction = Text:match("^(%-?%d+)%.(%d+)$")

		if Whole and Fraction then
			return string.Comma(tonumber(Whole) or 0) .. "." .. Fraction
		end

		return Text
	end

	return string.Comma(math.floor(Number + 0.5))
end

local function SetMissileGUIEnabled(_, enabled, gundata)

	if enabled then

		-- Create guidance selection combobox + description label

		if not acemenupanel.CData.MissileSpacer then
			local spacer = vgui.Create("DPanel")
			spacer:SetSize(24, 24)
			spacer.Paint = function() end
			acemenupanel.CData.MissileSpacer = spacer

			acemenupanel.CustomDisplay:AddItem(spacer)
		end

		local default = "Dumb"	-- Dumb is the only acceptable default
		if not acemenupanel.CData.GuidanceSelect then
			acemenupanel.CData.GuidanceSelect = vgui.Create( "DComboBox", acemenupanel.CustomDisplay )	--Every display and slider is placed in the Round table so it gets trashed when selecting a new round type
			acemenupanel.CData.GuidanceSelect:SetSize(100, 30)

			acemenupanel.CData.GuidanceSelect.OnSelect = function( _ , _ , data )
				RunConsoleCommand( "acemenu_data7", data )
				if acemenupanel.QueueRoundCostPreview then acemenupanel:QueueRoundCostPreview() end

				local gun = {}

				local gunId = acemenupanel.CData.CaliberSelect:GetValue()
				if gunId then
					local guns = ACE.Weapons.Guns
					gun = guns[gunId]
				end

				local guidance = ACE.Guidance[data]
				if guidance and guidance.desc then
					acemenupanel:CPanelText("GuidanceDesc", guidance.desc .. "\n")

					local configPanel = ACE.Missiles_CreateMenuConfiguration(guidance, acemenupanel.CData.GuidanceSelect, "acemenu_data7", acemenupanel.CData.GuidanceSelect.ConfigPanel, gun)
					acemenupanel.CData.GuidanceSelect.ConfigPanel = configPanel
				else
					acemenupanel:CPanelText("GuidanceDesc", "Missiles and bombs can be given a guidance package to steer them during flight.\n")
				end
			end

			acemenupanel.CustomDisplay:AddItem( acemenupanel.CData.GuidanceSelect )

			acemenupanel:CPanelText("GuidanceDesc", "Missiles and bombs can be given a guidance package to steer them during flight.\n")

			local configPanel = vgui.Create("DScrollPanel")
			acemenupanel.CData.GuidanceSelect.ConfigPanel = configPanel
			acemenupanel.CustomDisplay:AddItem( configPanel )

		else
			--acemenupanel.CData.GuidanceSelect:SetSize(100, 30)
			default = acemenupanel.CData.GuidanceSelect:GetValue()
			acemenupanel.CData.GuidanceSelect:SetVisible(true)
		end

		acemenupanel.CData.GuidanceSelect:Clear()
		for _, Value in pairs( gundata.guidance or {} ) do
			acemenupanel.CData.GuidanceSelect:AddChoice( Value, Value, Value == default )
		end


		-- Create fuse selection combobox + description label

		default = "Contact"  -- Contact is the only acceptable default
		if not acemenupanel.CData.FuseSelect then
			acemenupanel.CData.FuseSelect = vgui.Create( "DComboBox", acemenupanel.CustomDisplay )	--Every display and slider is placed in the Round table so it gets trashed when selecting a new round type
			acemenupanel.CData.FuseSelect:SetSize(100, 30)

			acemenupanel.CData.FuseSelect.OnSelect = function( _ , _ , data )

				local gun = {}

				local gunId = acemenupanel.CData.CaliberSelect:GetValue()
				if gunId then
					local guns = ACE.Weapons.Guns
					gun = guns[gunId]
				end

				local fuse = ACE.Fuse[data]

				if fuse and fuse.desc then
					acemenupanel:CPanelText("FuseDesc", fuse.desc .. "\n")

					local configPanel = ACE.Missiles_CreateMenuConfiguration(fuse, acemenupanel.CData.FuseSelect, "acemenu_data8", acemenupanel.CData.FuseSelect.ConfigPanel, gun)
					acemenupanel.CData.FuseSelect.ConfigPanel = configPanel
				else
					acemenupanel:CPanelText("FuseDesc", "Missiles and bombs can be given a fuse to control when they detonate.\n")
				end

				ACE.Missiles_SetCommand(acemenupanel.CData.FuseSelect, acemenupanel.CData.FuseSelect.ControlGroup, "acemenu_data8")
			end

			acemenupanel.CustomDisplay:AddItem( acemenupanel.CData.FuseSelect )

			acemenupanel:CPanelText("FuseDesc", "Missiles and bombs can be given a fuse to control when they detonate.\n")

			local configPanel = vgui.Create("DScrollPanel")
			configPanel:SetTall(0)
			acemenupanel.CData.FuseSelect.ConfigPanel = configPanel
			acemenupanel.CustomDisplay:AddItem( configPanel )
		else
			--acemenupanel.CData.FuseSelect:SetSize(100, 30)
			default = acemenupanel.CData.FuseSelect:GetValue()
			acemenupanel.CData.FuseSelect:SetVisible(true)
		end

		acemenupanel.CData.FuseSelect:Clear()
		for _, Value in pairs( gundata.fuses or {} ) do
			acemenupanel.CData.FuseSelect:AddChoice( Value, Value, Value == default ) -- Contact is the only acceptable default
		end

	else

		-- Delete everything!  Tried just making them invisible but they seem to break.

		if acemenupanel.CData.MissileSpacer then
			acemenupanel.CData.MissileSpacer:Remove()
			acemenupanel.CData.MissileSpacer = nil
		end


		if acemenupanel.CData.GuidanceSelect then

			if acemenupanel.CData.GuidanceSelect.ConfigPanel then
				acemenupanel.CData.GuidanceSelect.ConfigPanel:Remove()
				acemenupanel.CData.GuidanceSelect.ConfigPanel = nil
			end

			acemenupanel.CData.GuidanceSelect:Remove()
			acemenupanel.CData.GuidanceSelect = nil
		end

		if acemenupanel.CData.GuidanceDesc_text then
			acemenupanel.CData.GuidanceDesc_text:Remove()
			acemenupanel.CData.GuidanceDesc_text = nil
		end


		if acemenupanel.CData.FuseSelect then

			if acemenupanel.CData.FuseSelect.ConfigPanel then
				acemenupanel.CData.FuseSelect.ConfigPanel:Remove()
				acemenupanel.CData.FuseSelect.ConfigPanel = nil
			end

			acemenupanel.CData.FuseSelect:Remove()
			acemenupanel.CData.FuseSelect = nil
		end

		if acemenupanel.CData.FuseDesc_text then
			acemenupanel.CData.FuseDesc_text:Remove()
			acemenupanel.CData.FuseDesc_text = nil
		end

	end

end




local function CreateRackSelectGUI(node)

	if not acemenupanel.CData.MissileSpacer then
		local spacer = vgui.Create("DPanel")
		spacer:SetSize(24, 24)
		spacer.Paint = function() end
		acemenupanel.CData.MissileSpacer = spacer

		acemenupanel.CustomDisplay:AddItem(spacer)
	end

	if not acemenupanel.CData.RackSelect then

		acemenupanel:CPanelText("RackChooseMsg", "Choose the desired rack below")

		--Every display and slider is placed in the Round table so it gets trashed when selecting a new round type
		acemenupanel.CData.RackSelect = vgui.Create( "DComboBox", acemenupanel.CustomDisplay )
		acemenupanel.CData.RackSelect:SetSize(100, 30)

		acemenupanel.CData.RackSelect.OnSelect = function( panel, index, _, data )
			data = data or panel:GetOptionData(index)
			RunConsoleCommand( "acemenu_data9", data )

			local rack = ACE.Weapons.Racks[data]

			if rack then

				if not acemenupanel.CData.RackModel then
					acemenupanel.CData.RackModel = vgui.Create( "DModelPanel", acemenupanel.CustomDisplay )
					acemenupanel.CData.RackModel:SetModel( rack.model or "models/props_c17/FurnitureToilet001a.mdl" )
					acemenupanel.CData.RackModel:SetCamPos( Vector( 250, 500, 250 ) )
					acemenupanel.CData.RackModel:SetLookAt( Vector( 0, 0, 0 ) )
					acemenupanel.CData.RackModel:SetFOV( 20 )
					acemenupanel.CData.RackModel:SetSize(acemenupanel:GetWide() / 3,acemenupanel:GetWide() / 3)
					acemenupanel.CData.RackModel.LayoutEntity = function() end
					acemenupanel.CustomDisplay:AddItem( acemenupanel.CData.RackModel )
				else
					acemenupanel.CData.RackModel:SetModel( rack.model )
				end

				acemenupanel:CPanelText("RackTitle", rack.name or "Missing Name","DermaDefaultBold")
				acemenupanel:CPanelText("RackDesc", (rack.desc or "Missing Desc") .. "\n")

				local EmptyWeight = tonumber(rack.weight) or 0
				local FullWeight = EmptyWeight + (table.Count(rack.mountpoints) * (tonumber(node.mytable.weight) or 0))

				acemenupanel:CPanelText("RackEweight", "Weight when empty : " .. FormatWithCommas(EmptyWeight, 1) .. "kg")
				acemenupanel:CPanelText("RackFweight", "Weight when fully loaded : " .. FormatWithCommas(FullWeight, 1) .. "kg")
				acemenupanel:CPanelText("Rack_Year", "Year : " .. rack.year .. "\n")
			end
		end

		acemenupanel.CustomDisplay:AddItem( acemenupanel.CData.RackSelect )

		local configPanel = vgui.Create("DScrollPanel")
		acemenupanel.CData.RackSelect.ConfigPanel = configPanel
		acemenupanel.CustomDisplay:AddItem( configPanel )

	else
		acemenupanel.CData.RackSelect:SetVisible(true)
	end

	acemenupanel.CData.RackSelect:Clear()

	local default = node.mytable.rack
	for _, Value in pairs( ACE.GetCompatibleRacks(node.mytable.id) ) do
		local Display = Value
		local Rack = ACE.Weapons.Racks[Value]
		if Rack then
			local RackWeight = tonumber(Rack.weight) or 0
			Display = string.format("%s (%skg)", Value, FormatWithCommas(RackWeight, 1))
		end

		acemenupanel.CData.RackSelect:AddChoice( Display, Value, Value == default )
	end


end




local OldAmmoSelect

local function ModifyACEMenu(panel)

	OldAmmoSelect = OldAmmoSelect or panel.AmmoSelect

	panel.AmmoSelect = function(panel, blacklist)

		OldAmmoSelect(panel, blacklist)

		acemenupanel.CData.CaliberSelect.OnSelect = function( _ , _ , data )
			acemenupanel.AmmoData["Data"] = ACFEnts["Guns"][data]["round"]
			acemenupanel:UpdateAttribs()
			acemenupanel:UpdateAttribs()	--Note : this is intentional

			local gunTbl = ACFEnts["Guns"][data]
			local class = gunTbl.gunclass

			local Classes = ACE.Classes
			timer.Simple(0.01, function() SetMissileGUIEnabled( acemenupanel, Classes.GunClass[class].type == "missile", gunTbl ) end)
		end

		local data = acemenupanel.CData.CaliberSelect:GetValue()
		if data then
			local gunTbl = ACFEnts["Guns"][data]
			local class = gunTbl.gunclass

			local Classes = ACE.Classes
			timer.Simple(0.01, function() SetMissileGUIEnabled( acemenupanel, Classes.GunClass[class].type == "missile", gunTbl) end)
		end

	end

	local rootNodes = HomeNode and HomeNode.ChildNodes and HomeNode.ChildNodes:GetChildren()  -- lets find all our folders inside the main menu
	if not rootNodes then return false end

	local gunsNode

	for _, node in pairs(rootNodes) do -- iterating though found folders

		if node:GetText() == "Missiles" then	--Missile folder is the one that we need
			gunsNode = node
			break
		end
	end

	if not (gunsNode and gunsNode.ChildNodes) then return false end

	local classNodes = gunsNode.ChildNodes:GetChildren()
	local gunClasses = ACE.Classes.GunClass
	local foundAnyChildren = false
	local patchedAny = false
	local foundAnyMissileEntries = false

	for _, node in pairs(classNodes) do
		local gunNodeElement = node.ChildNodes
		if not gunNodeElement then continue end

		local gunNodes = gunNodeElement:GetChildren()
		if #gunNodes > 0 then
			foundAnyChildren = true
		end

		for _, gun in pairs(gunNodes) do
			if not (gun.mytable and gun.mytable.gunclass) then continue end

			local class = gunClasses[gun.mytable.gunclass]

			if class and class.type == "missile" then
				foundAnyMissileEntries = true

				if not gun.ACE_MenuOverridden then
					local oldclick = gun.DoClick

					gun.DoClick = function(self)
						oldclick(self)
						CreateRackSelectGUI(self)
					end

					gun.ACE_MenuOverridden = true
					patchedAny = true
				end
			end
		end
	end

	return foundAnyChildren and (patchedAny or foundAnyMissileEntries)

end

local function FindACEMenuPanel()
	if acemenupanel and ModifyACEMenu(acemenupanel) then
		timer.Remove("FindACEMenuPanel")
	end
end




timer.Create("FindACEMenuPanel", 0.1, 0, FindACEMenuPanel)
