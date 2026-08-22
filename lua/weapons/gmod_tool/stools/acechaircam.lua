TOOL.Category = "Render"
TOOL.Name = "#tool.acechaircam.name"

if CLIENT then

	TOOL.Information = {

		{ name = "left", icon = "gui/lmb.png"},
		{ name = "reload", icon = "gui/r.png" },

	}

end

do

	local function SendBoolToClient( _, seat, bool )

		net.Start("ACE_CamOverride")
			net.WriteEntity( seat )
			net.WriteBool(bool or false)
		net.Broadcast() -- we need to make sure all clients (including the owner) can have the override

	end

	do

		local function ApplyOverride( ply, seat, data )
			local aceData = data.ACE or {}
			local camOverride = aceData.CamOverride
			if camOverride == nil then camOverride = data.ACE_CamOverride end

			timer.Simple(0.1, function()
				if not IsValid(seat) then return end

				local class = seat:GetClass()
				if not string.StartWith(class, "prop_vehicle_") then return end

				SendBoolToClient( ply, seat, camOverride )

			end)

			if SERVER then
				local Data = { ACE = { CamOverride = camOverride } }
				duplicator.StoreEntityModifier( seat , "ACECamOverride", Data )
			end

		end

		duplicator.RegisterEntityModifier( "ACECamOverride", ApplyOverride )

	end

	--=========== MAIN ===========--
	do

		function TOOL:LeftClick( trace )

			if CLIENT then return true end

			if not IsValid(trace.Entity) then return false end
			local class = trace.Entity:GetClass()
			if not string.StartWith(class, "prop_vehicle_") then return false end

			local seat = trace.Entity

			SendBoolToClient( self:GetOwner(), seat, true )

			local data = { ACE = { CamOverride = true } }
			duplicator.StoreEntityModifier( seat , "ACECamOverride", data )

			return true
		end

		function TOOL:RightClick()
			if CLIENT then return false end

			return false
		end

		function TOOL:Reload( trace )

			if CLIENT then return true end

			if not IsValid(trace.Entity) then return false end
			local class = trace.Entity:GetClass()
			if not string.StartWith(class, "prop_vehicle_") then return false end

			local seat = trace.Entity

			SendBoolToClient( self:GetOwner(), seat, false )

			duplicator.ClearEntityModifier( seat, "ACECamOverride" )

			return true
		end

	end

	if CLIENT then

		local function ReceiveBoolFromServer()

			local seat = net.ReadEntity()
			local bool = net.ReadBool() or false

			if not IsValid(seat) then return end

			seat.ACE_CamOverride = bool

		end

		net.Receive("ACE_CamOverride", ReceiveBoolFromServer)

		function TOOL:DrawHUD()

			if not CLIENT then return end

			local seat = self:GetOwner():GetEyeTrace().Entity

			if not IsValid(seat) then return end
			local class = seat:GetClass()
			if not string.StartWith(class, "prop_vehicle_") then return false end

			local text = "Override: " .. (seat.ACE_CamOverride and "Yes" or "No")
			local pos = seat:WorldSpaceCenter()

			AddWorldTip( nil, text, nil, pos, nil )

		end

		function TOOL.BuildCPanel( panel )

			panel:Help( "#tool.acechaircam.desc" )

		end
	end
end
