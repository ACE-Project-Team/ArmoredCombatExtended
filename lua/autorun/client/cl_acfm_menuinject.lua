--TODO: merge this file with cl_acfmenu_gui.lua since having 2 files for the same function is irrevelant. Little transition has been made though

include("acf/client/cl_acfmenu_missileui.lua")

if not ACF then ACF = {} end
if not ACF.ChatMessageReceiver then
	ACF.ChatMessageReceiver = true
	net.Receive("colorchatmessage", function()
		chat.AddText(net.ReadColor(), net.ReadString())
	end)
end


local ACFEnts = ACF.Weapons

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

		if not acfmenupanel.CData.MissileSpacer then
			local spacer = vgui.Create("DPanel")
			spacer:SetSize(24, 24)
			spacer.Paint = function() end
			acfmenupanel.CData.MissileSpacer = spacer

			acfmenupanel.CustomDisplay:AddItem(spacer)
		end

		local default = "Dumb"	-- Dumb is the only acceptable default
		if not acfmenupanel.CData.GuidanceSelect then
			acfmenupanel.CData.GuidanceSelect = vgui.Create( "DComboBox", acfmenupanel.CustomDisplay )	--Every display and slider is placed in the Round table so it gets trashed when selecting a new round type
			acfmenupanel.CData.GuidanceSelect:SetSize(100, 30)

			acfmenupanel.CData.GuidanceSelect.OnSelect = function( _ , _ , data )
				RunConsoleCommand( "acfmenu_data7", data )
				if acfmenupanel.QueueRoundCostPreview then acfmenupanel:QueueRoundCostPreview() end

				local gun = {}

				local gunId = acfmenupanel.CData.CaliberSelect:GetValue()
				if gunId then
					local guns = ACF.Weapons.Guns
					gun = guns[gunId]
				end

				local guidance = ACF.Guidance[data]
				if guidance and guidance.desc then
					acfmenupanel:CPanelText("GuidanceDesc", guidance.desc .. "\n")

					local configPanel = ACE.Missiles_CreateMenuConfiguration(guidance, acfmenupanel.CData.GuidanceSelect, "acfmenu_data7", acfmenupanel.CData.GuidanceSelect.ConfigPanel, gun)
					acfmenupanel.CData.GuidanceSelect.ConfigPanel = configPanel
				else
					acfmenupanel:CPanelText("GuidanceDesc", "Missiles and bombs can be given a guidance package to steer them during flight.\n")
				end
			end

			acfmenupanel.CustomDisplay:AddItem( acfmenupanel.CData.GuidanceSelect )

			acfmenupanel:CPanelText("GuidanceDesc", "Missiles and bombs can be given a guidance package to steer them during flight.\n")

			local configPanel = vgui.Create("DScrollPanel")
			acfmenupanel.CData.GuidanceSelect.ConfigPanel = configPanel
			acfmenupanel.CustomDisplay:AddItem( configPanel )

		else
			--acfmenupanel.CData.GuidanceSelect:SetSize(100, 30)
			default = acfmenupanel.CData.GuidanceSelect:GetValue()
			acfmenupanel.CData.GuidanceSelect:SetVisible(true)
		end

		acfmenupanel.CData.GuidanceSelect:Clear()
		for _, Value in pairs( gundata.guidance or {} ) do
			acfmenupanel.CData.GuidanceSelect:AddChoice( Value, Value, Value == default )
		end


		-- Create fuse selection combobox + description label

		default = "Contact"  -- Contact is the only acceptable default
		if not acfmenupanel.CData.FuseSelect then
			acfmenupanel.CData.FuseSelect = vgui.Create( "DComboBox", acfmenupanel.CustomDisplay )	--Every display and slider is placed in the Round table so it gets trashed when selecting a new round type
			acfmenupanel.CData.FuseSelect:SetSize(100, 30)

			acfmenupanel.CData.FuseSelect.OnSelect = function( _ , _ , data )

				local gun = {}

				local gunId = acfmenupanel.CData.CaliberSelect:GetValue()
				if gunId then
					local guns = ACF.Weapons.Guns
					gun = guns[gunId]
				end

				local fuse = ACF.Fuse[data]

				if fuse and fuse.desc then
					acfmenupanel:CPanelText("FuseDesc", fuse.desc .. "\n")

					local configPanel = ACE.Missiles_CreateMenuConfiguration(fuse, acfmenupanel.CData.FuseSelect, "acfmenu_data8", acfmenupanel.CData.FuseSelect.ConfigPanel, gun)
					acfmenupanel.CData.FuseSelect.ConfigPanel = configPanel
				else
					acfmenupanel:CPanelText("FuseDesc", "Missiles and bombs can be given a fuse to control when they detonate.\n")
				end

				ACE.Missiles_SetCommand(acfmenupanel.CData.FuseSelect, acfmenupanel.CData.FuseSelect.ControlGroup, "acfmenu_data8")
			end

			acfmenupanel.CustomDisplay:AddItem( acfmenupanel.CData.FuseSelect )

			acfmenupanel:CPanelText("FuseDesc", "Missiles and bombs can be given a fuse to control when they detonate.\n")

			local configPanel = vgui.Create("DScrollPanel")
			configPanel:SetTall(0)
			acfmenupanel.CData.FuseSelect.ConfigPanel = configPanel
			acfmenupanel.CustomDisplay:AddItem( configPanel )
		else
			--acfmenupanel.CData.FuseSelect:SetSize(100, 30)
			default = acfmenupanel.CData.FuseSelect:GetValue()
			acfmenupanel.CData.FuseSelect:SetVisible(true)
		end

		acfmenupanel.CData.FuseSelect:Clear()
		for _, Value in pairs( gundata.fuses or {} ) do
			acfmenupanel.CData.FuseSelect:AddChoice( Value, Value, Value == default ) -- Contact is the only acceptable default
		end

	else

		-- Delete everything!  Tried just making them invisible but they seem to break.

		if acfmenupanel.CData.MissileSpacer then
			acfmenupanel.CData.MissileSpacer:Remove()
			acfmenupanel.CData.MissileSpacer = nil
		end


		if acfmenupanel.CData.GuidanceSelect then

			if acfmenupanel.CData.GuidanceSelect.ConfigPanel then
				acfmenupanel.CData.GuidanceSelect.ConfigPanel:Remove()
				acfmenupanel.CData.GuidanceSelect.ConfigPanel = nil
			end

			acfmenupanel.CData.GuidanceSelect:Remove()
			acfmenupanel.CData.GuidanceSelect = nil
		end

		if acfmenupanel.CData.GuidanceDesc_text then
			acfmenupanel.CData.GuidanceDesc_text:Remove()
			acfmenupanel.CData.GuidanceDesc_text = nil
		end


		if acfmenupanel.CData.FuseSelect then

			if acfmenupanel.CData.FuseSelect.ConfigPanel then
				acfmenupanel.CData.FuseSelect.ConfigPanel:Remove()
				acfmenupanel.CData.FuseSelect.ConfigPanel = nil
			end

			acfmenupanel.CData.FuseSelect:Remove()
			acfmenupanel.CData.FuseSelect = nil
		end

		if acfmenupanel.CData.FuseDesc_text then
			acfmenupanel.CData.FuseDesc_text:Remove()
			acfmenupanel.CData.FuseDesc_text = nil
		end

	end

end




local function CreateRackSelectGUI(node)

	if not acfmenupanel.CData.MissileSpacer then
		local spacer = vgui.Create("DPanel")
		spacer:SetSize(24, 24)
		spacer.Paint = function() end
		acfmenupanel.CData.MissileSpacer = spacer

		acfmenupanel.CustomDisplay:AddItem(spacer)
	end

	if not acfmenupanel.CData.RackSelect then

		acfmenupanel:CPanelText("RackChooseMsg", "Choose the desired rack below")

		--Every display and slider is placed in the Round table so it gets trashed when selecting a new round type
		acfmenupanel.CData.RackSelect = vgui.Create( "DComboBox", acfmenupanel.CustomDisplay )
		acfmenupanel.CData.RackSelect:SetSize(100, 30)

		acfmenupanel.CData.RackSelect.OnSelect = function( panel, index, _, data )
			data = data or panel:GetOptionData(index)
			RunConsoleCommand( "acfmenu_data9", data )

			local rack = ACF.Weapons.Racks[data]

			if rack then

				if not acfmenupanel.CData.RackModel then
					acfmenupanel.CData.RackModel = vgui.Create( "DModelPanel", acfmenupanel.CustomDisplay )
					acfmenupanel.CData.RackModel:SetModel( rack.model or "models/props_c17/FurnitureToilet001a.mdl" )
					acfmenupanel.CData.RackModel:SetCamPos( Vector( 250, 500, 250 ) )
					acfmenupanel.CData.RackModel:SetLookAt( Vector( 0, 0, 0 ) )
					acfmenupanel.CData.RackModel:SetFOV( 20 )
					acfmenupanel.CData.RackModel:SetSize(acfmenupanel:GetWide() / 3,acfmenupanel:GetWide() / 3)
					acfmenupanel.CData.RackModel.LayoutEntity = function() end
					acfmenupanel.CustomDisplay:AddItem( acfmenupanel.CData.RackModel )
				else
					acfmenupanel.CData.RackModel:SetModel( rack.model )
				end

				acfmenupanel:CPanelText("RackTitle", rack.name or "Missing Name","DermaDefaultBold")
				acfmenupanel:CPanelText("RackDesc", (rack.desc or "Missing Desc") .. "\n")

				local EmptyWeight = tonumber(rack.weight) or 0
				local FullWeight = EmptyWeight + (table.Count(rack.mountpoints) * (tonumber(node.mytable.weight) or 0))

				acfmenupanel:CPanelText("RackEweight", "Weight when empty : " .. FormatWithCommas(EmptyWeight, 1) .. "kg")
				acfmenupanel:CPanelText("RackFweight", "Weight when fully loaded : " .. FormatWithCommas(FullWeight, 1) .. "kg")
				acfmenupanel:CPanelText("Rack_Year", "Year : " .. rack.year .. "\n")
			end
		end

		acfmenupanel.CustomDisplay:AddItem( acfmenupanel.CData.RackSelect )

		local configPanel = vgui.Create("DScrollPanel")
		acfmenupanel.CData.RackSelect.ConfigPanel = configPanel
		acfmenupanel.CustomDisplay:AddItem( configPanel )

	else
		acfmenupanel.CData.RackSelect:SetVisible(true)
	end

	acfmenupanel.CData.RackSelect:Clear()

	local default = node.mytable.rack
	for _, Value in pairs( ACE.GetCompatibleRacks(node.mytable.id) ) do
		local Display = Value
		local Rack = ACF.Weapons.Racks[Value]
		if Rack then
			local RackWeight = tonumber(Rack.weight) or 0
			Display = string.format("%s (%skg)", Value, FormatWithCommas(RackWeight, 1))
		end

		acfmenupanel.CData.RackSelect:AddChoice( Display, Value, Value == default )
	end


end




local OldAmmoSelect

local function ModifyACFMenu(panel)

	OldAmmoSelect = OldAmmoSelect or panel.AmmoSelect

	panel.AmmoSelect = function(panel, blacklist)

		OldAmmoSelect(panel, blacklist)

		acfmenupanel.CData.CaliberSelect.OnSelect = function( _ , _ , data )
			acfmenupanel.AmmoData["Data"] = ACFEnts["Guns"][data]["round"]
			acfmenupanel:UpdateAttribs()
			acfmenupanel:UpdateAttribs()	--Note : this is intentional

			local gunTbl = ACFEnts["Guns"][data]
			local class = gunTbl.gunclass

			local Classes = ACF.Classes
			timer.Simple(0.01, function() SetMissileGUIEnabled( acfmenupanel, Classes.GunClass[class].type == "missile", gunTbl ) end)
		end

		local data = acfmenupanel.CData.CaliberSelect:GetValue()
		if data then
			local gunTbl = ACFEnts["Guns"][data]
			local class = gunTbl.gunclass

			local Classes = ACF.Classes
			timer.Simple(0.01, function() SetMissileGUIEnabled( acfmenupanel, Classes.GunClass[class].type == "missile", gunTbl) end)
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
	local gunClasses = ACF.Classes.GunClass
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

				if not gun.ACFMOverridden then
					local oldclick = gun.DoClick

					gun.DoClick = function(self)
						oldclick(self)
						CreateRackSelectGUI(self)
					end

					gun.ACFMOverridden = true
					patchedAny = true
				end
			end
		end
	end

	return foundAnyChildren and (patchedAny or foundAnyMissileEntries)

end

local function FindACFMenuPanel()
	if acfmenupanel and ModifyACFMenu(acfmenupanel) then
		timer.Remove("FindACFMenuPanel")
	end
end




timer.Create("FindACFMenuPanel", 0.1, 0, FindACFMenuPanel)
