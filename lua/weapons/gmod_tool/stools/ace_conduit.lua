-- ACE Conduit tool
--
-- Lays and inspects the sustainability networks (power lines & fuel pipes).
--
--   * Spawn ONE segment from the ACE menu first (choose its gauge/length there).
--   * LEFT-CLICK that segment to pick it up as a template; every following
--     LEFT-CLICK lays a fresh copy at your aim, turned to follow the run and
--     auto-linked to the previous one - so you can quickly stack a line/pipeline.
--   * RIGHT-CLICK a segment to shove it underground by the Depth setting (click
--     again to pull it back up - e.g. to expose a section).
--   * RELOAD ends the current chain.
--
-- It does NOT link arbitrary existing entities together - that is the ACE menu
-- link tool's job. The conduit tool only chains the segments you lay. It also
-- draws a live overlay: per-node readouts and links coloured by load (green
-- light -> amber near capacity -> orange overload -> red broken -> grey dead),
-- with an animated pulse along live links so you can see where power is flowing.

ACF = ACF or {}

local cat = ((ACF.CustomToolCategory and ACF.CustomToolCategory:GetBool()) and "ACF" or "Construction")

TOOL.Category   = cat
TOOL.Name       = "#tool.ace_conduit.name"
TOOL.Command    = nil
TOOL.ConfigName = ""

TOOL.ClientConVar["depth"] = "72"     -- bury depth (units)
TOOL.ClientConVar["range"] = "2500"   -- overlay range (units)
TOOL.ClientConVar["show"]  = "2"      -- 0 electric, 1 fuel, 2 both

-- Segment types the tool can lay (and their global Make function).
local LAYABLE = {
	ace_power_line = { make = "MakeACE_PowerLine", defId = "ACE Power Line" },
	ace_fuel_pipe  = { make = "MakeACE_FuelPipe",  defId = "ACE Fuel Pipe"  },
}

-- Electric grid entities (publish Ace* NW values + GL* topology).
local GRID = {
	ace_transfer_station = true,
	ace_transformer      = true,
	ace_power_line       = true,
	ace_power_collector  = true,
	ace_capacitor        = true,
}
-- Fuel-network entities (PL* topology).
local FUEL = {
	ace_fuel_pipe = true, ace_fuel_pump = true, ace_fuel_socket = true,
	ace_fuel_plug = true, ace_refinery = true, ace_field_generator = true,
	ace_fuel_synth = true, acf_fueltank = true,
}

local function canTouch(ply, ent)
	if not IsValid(ent) then return false end
	if not ent.CPPIGetOwner then return true end
	local owner = ent:CPPIGetOwner()
	return owner == ply or (IsValid(ply) and ply:IsAdmin())
end

-- Orient a segment so its long (Z) axis points along `dir`.
local function lengthAngle(dir)
	if dir:LengthSqr() < 1e-6 then return Angle(0, 0, 0) end
	local ang = dir:Angle()
	ang:RotateAroundAxis(ang:Right(), -90)   -- map local Up (length) onto dir
	return ang
end

-- The length (longest dimension) a segment will have, from its "L:W:H" SizeId,
-- so we can lay copies END-TO-END instead of overlapping their centres.
local function segLength(sizeId)
	local sv = ACE.Sustain.ParseScale(sizeId)
	if not sv then return 24 end
	local d = { sv.x, sv.y, sv.z }
	table.sort(d)
	return math.max(d[3], 1)
end

function TOOL:LeftClick(trace)
	local ent = trace.Entity

	-- Start / continue a chain only from a layable segment.
	if IsValid(ent) and LAYABLE[ent:GetClass()] then
		if CLIENT then return true end
		if not canTouch(self:GetOwner(), ent) then self:GetOwner():ChatPrint("[ACE Conduit] You don't own that.") return true end

		-- If we already have an active chain and click a DIFFERENT existing segment
		-- of the same kind, JOIN the two runs (link the current anchor to it) before
		-- continuing from it - so you can tie a new line into an existing one.
		if IsValid(self.ChainAnchor) and self.ChainAnchor ~= ent
			and ent:GetClass() == self.ChainClass and self.ChainAnchor.Link then
			local ok, msg = self.ChainAnchor:Link(ent)
			self:GetOwner():ChatPrint(ok and "[ACE Conduit] Joined into the existing run."
				or ("[ACE Conduit] Couldn't join: " .. (msg or "?")))
		end

		self.ChainAnchor = ent
		self.ChainClass  = ent:GetClass()
		self.ChainSizeId = ent.SizeId
		self.ChainShape  = ent.Shape
		self.ChainDefId  = ent.Id or LAYABLE[ent:GetClass()].defId
		self:GetOwner():ChatPrint("[ACE Conduit] Picked up " .. ent:GetClass() .. " - left-click to lay copies, RELOAD to finish.")
		return true
	end

	-- Otherwise lay a new copy at the aim, continuing the chain.
	if not trace.Hit then return false end
	if CLIENT then return self.ChainAnchor ~= nil end
	if not IsValid(self.ChainAnchor) or not LAYABLE[self.ChainClass or ""] then
		self:GetOwner():ChatPrint("[ACE Conduit] Left-click an existing power line / fuel pipe first to pick it up.")
		return true
	end

	local ply  = self:GetOwner()
	local mk   = _G[LAYABLE[self.ChainClass].make]
	if not isfunction(mk) then return true end

	-- Snap END-TO-END: aim a direction from the anchor toward where you're looking,
	-- then place the new segment so its near end meets the anchor's far end (so a
	-- chain reads as one continuous run instead of segments piled on each other).
	local anchor   = self.ChainAnchor
	local aimPos   = trace.HitPos + trace.HitNormal * 4
	local dir      = aimPos - anchor:GetPos()
	if dir:LengthSqr() < 1e-6 then dir = anchor:GetForward() end
	dir:Normalize()

	local anchorLen = anchor.Length or segLength(anchor.SizeId)
	local segLen    = segLength(self.ChainSizeId)
	local anchorEnd = anchor:GetPos() + dir * (anchorLen * 0.5)
	local pos       = anchorEnd + dir * (segLen * 0.5)
	local ang       = lengthAngle(dir)

	local seg = mk(ply, pos, ang, self.ChainDefId, self.ChainSizeId, self.ChainShape)
	if not IsValid(seg) then self:GetOwner():ChatPrint("[ACE Conduit] Couldn't spawn (limit reached?).") return true end

	-- Make the lay Ctrl-Z-able and cleanup-tracked, like a normal spawn.
	undo.Create("ACE Conduit segment")
		undo.AddEntity(seg)
		undo.SetPlayer(ply)
	undo.Finish()
	ply:AddCleanup("acfmenu", seg)

	if anchor.Link then
		local ok, msg = anchor:Link(seg)
		if not ok then ply:ChatPrint("[ACE Conduit] Placed, but not linked: " .. (msg or "?")) end
	end
	self.ChainAnchor = seg   -- continue from the new segment
	return true
end

-- Move one segment up/down by `depth`. raise=true pulls a buried one back up.
local function shift(ent, depth, raise)
	if raise then
		if not ent.AceBuried then return false end
		ent:SetPos(ent:GetPos() + Vector(0, 0, ent.AceBuried))
		ent.AceBuried = nil
	else
		ent:SetPos(ent:GetPos() - Vector(0, 0, depth))
		ent.AceBuried = (ent.AceBuried or 0) + depth
	end
	local phys = ent:GetPhysicsObject()
	if IsValid(phys) then phys:EnableMotion(false) phys:Wake() end
	return true
end

-- Bury / raise the aimed segment by the Depth setting. If you aren't aiming at a
-- segment (because it's already underground), RMB raises the nearest BURIED
-- segment you own near where you're looking - so you never need to noclip down to
-- dig one back up.
function TOOL:RightClick(trace)
	if CLIENT then return true end
	local ply  = self:GetOwner()
	local ent  = trace.Entity
	local depth = math.Clamp(self:GetClientNumber("depth", 72), 0, 4096)

	if IsValid(ent) and (GRID[ent:GetClass()] or FUEL[ent:GetClass()]) then
		if not canTouch(ply, ent) then return true end
		shift(ent, depth, ent.AceBuried ~= nil)
		return true
	end

	-- Nothing aimed at: find the closest buried segment we own near the aim point.
	if not trace.Hit then return false end
	local best, bestD
	for _, e in ipairs(ents.FindInSphere(trace.HitPos, 300)) do
		if e.AceBuried and (GRID[e:GetClass()] or FUEL[e:GetClass()]) and canTouch(ply, e) then
			local d = e:GetPos():DistToSqr(trace.HitPos)
			if not bestD or d < bestD then best, bestD = e, d end
		end
	end
	if IsValid(best) then
		shift(best, depth, true)
		ply:ChatPrint("[ACE Conduit] Raised a buried segment.")
	end
	return true
end

function TOOL:Reload()
	if SERVER and self.ChainAnchor then
		self.ChainAnchor = nil
		self:GetOwner():ChatPrint("[ACE Conduit] Chain finished.")
	end
	return false
end

if CLIENT then
	language.Add("tool.ace_conduit.name", "ACE Conduit (lay & inspect wires/pipes)")
	language.Add("tool.ace_conduit.desc", "Lay power lines and fuel pipes by stacking segments, bury them, and see live grid/fuel readouts.")
	language.Add("tool.ace_conduit.left", "Pick up a segment / lay the next copy")
	language.Add("tool.ace_conduit.right", "Bury / raise the aimed segment")
	language.Add("tool.ace_conduit.reload", "Finish the current chain")

	TOOL.Information = {
		{ name = "left",   icon = "gui/lmb.png" },
		{ name = "right",  icon = "gui/rmb.png" },
		{ name = "reload", icon = "gui/r.png" },
	}

	local function fmtKW(kw)
		if math.abs(kw) >= 1000 then return string.format("%.1f MW", kw / 1000) end
		return string.format("%.0f kW", kw)
	end

	local C_DEAD, C_BROKEN, C_OVER = Color(120, 120, 120), Color(255, 60, 60), Color(255, 130, 0)
	local function flowColor(state, live, kw, cap)
		if state == 2 then return C_BROKEN end
		if state == 1 then return C_OVER end
		if not live then return C_DEAD end
		local frac = (cap > 0) and math.Clamp(kw / cap, 0, 1) or 0
		return Color(80 + frac * 175, 220 - frac * 150, 60)
	end

	local function drawLabel(scr, lines, col)
		local pad, lh = 4, 14
		surface.SetFont("DermaDefault")
		local w = 0
		for _, l in ipairs(lines) do local tw = surface.GetTextSize(l) if tw > w then w = tw end end
		local h = #lines * lh + pad * 2
		local x, y = scr.x - w / 2 - pad, scr.y - h - 8
		surface.SetDrawColor(0, 0, 0, 200) surface.DrawRect(x, y, w + pad * 2, h)
		surface.SetDrawColor(col.r, col.g, col.b, 255) surface.DrawOutlinedRect(x, y, w + pad * 2, h)
		for i, l in ipairs(lines) do
			draw.SimpleText(l, "DermaDefault", scr.x, y + pad + (i - 1) * lh, color_white, TEXT_ALIGN_CENTER)
		end
	end

	-- Draw links a node networked under GL/PL, once per pair. Live links get an
	-- animated pulse that travels in the ACTUAL direction power is flowing (read
	-- from AceFlowTo, set by the grid solver), so you can see which way it goes.
	local function drawLinks(ent, prefix, col)
		local n = ent:GetNWInt(prefix .. "N", 0)
		if n <= 0 then return end
		local ei = ent:EntIndex()
		local ac = ent:WorldSpaceCenter()
		local a  = ac:ToScreen()
		for i = 1, n do
			local other = ent:GetNWEntity(prefix .. i)
			if IsValid(other) and ei < other:EntIndex() then
				local bc = other:WorldSpaceCenter()
				local b  = bc:ToScreen()
				if a.visible and b.visible then
					surface.SetDrawColor(col.r, col.g, col.b, 220)
					surface.DrawLine(a.x, a.y, b.x, b.y)

					-- Flow direction (from sender -> receiver), if any.
					local fromC, toC
					if ent:GetNWInt("AceFlowTo", 0) == other:EntIndex() then fromC, toC = ac, bc
					elseif other:GetNWInt("AceFlowTo", 0) == ei then fromC, toC = bc, ac end
					if fromC then
						local t = (CurTime() * 0.6) % 1
						for k = 0, 2 do
							local f = (t + k / 3) % 1
							local p = (fromC + (toC - fromC) * f):ToScreen()
							if p.visible then
								surface.SetDrawColor(255, 255, 180, 255)
								surface.DrawRect(p.x - 2, p.y - 2, 4, 4)
							end
						end
					end
				end
			end
		end
	end

	-- Draw a device's AUXILIARY links (device -> tank / battery), published under the
	-- AX prefix by Sustain.NetworkAux. These aren't part of the grid/pipe graph, so
	-- they're drawn dashed and labelled (oil / power / out / battery) to complete the
	-- picture - e.g. station -> battery, refinery -> its three tanks.
	local C_AUX = Color(255, 190, 90)
	local function drawAux(ent)
		local n = ent:GetNWInt("AXN", 0)
		if n <= 0 then return end
		local ac = ent:WorldSpaceCenter()
		local a  = ac:ToScreen()
		if not a.visible then return end
		for i = 1, n do
			local other = ent:GetNWEntity("AX" .. i)
			if IsValid(other) then
				local b = other:WorldSpaceCenter():ToScreen()
				if b.visible then
					-- Dashed line so aux links read differently from graph links.
					local dx, dy = b.x - a.x, b.y - a.y
					local len = math.max(math.sqrt(dx * dx + dy * dy), 1)
					local steps = math.Clamp(math.floor(len / 12), 1, 64)
					surface.SetDrawColor(C_AUX.r, C_AUX.g, C_AUX.b, 220)
					for s = 0, steps - 1, 2 do
						local f1, f2 = s / steps, (s + 1) / steps
						surface.DrawLine(a.x + dx * f1, a.y + dy * f1, a.x + dx * f2, a.y + dy * f2)
					end
					local lbl = ent:GetNWString("AX" .. i .. "L", "")
					if lbl ~= "" then
						draw.SimpleText(lbl, "DermaDefault", a.x + dx * 0.5, a.y + dy * 0.5,
							C_AUX, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
					end
				end
			end
		end
	end

	-- Draw an entity's FRONT (and TOP) axes so builders can orient direction-
	-- sensitive parts (fuel plug/socket connect faces, which way a solar panel
	-- looks, the live face of a station, etc.) without guessing.
	local function drawFront(ent)
		if not IsValid(ent) then return end
		local c   = ent:WorldSpaceCenter()
		-- Length scales with the entity so the arrow is readable on big and small ents.
		local r   = ent:BoundingRadius()
		local len = math.Clamp(r * 1.1, 16, 256)

		local function axis(dir, col, label)
			local tip  = c + dir * len
			local a, b = c:ToScreen(), tip:ToScreen()
			if not (a.visible and b.visible) then return end
			surface.SetDrawColor(col.r, col.g, col.b, 255)
			surface.DrawLine(a.x, a.y, b.x, b.y)
			-- simple arrowhead
			surface.DrawLine(b.x, b.y, b.x - (b.x - a.x) * 0.12 - (b.y - a.y) * 0.12, b.y - (b.y - a.y) * 0.12 + (b.x - a.x) * 0.12)
			surface.DrawLine(b.x, b.y, b.x - (b.x - a.x) * 0.12 + (b.y - a.y) * 0.12, b.y - (b.y - a.y) * 0.12 - (b.x - a.x) * 0.12)
			draw.SimpleText(label, "DermaDefaultBold", b.x, b.y, col, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
		end

		axis(ent:GetForward(),  Color(255, 80, 80),  "FRONT")
		axis(ent:GetUp(),       Color(120, 160, 255), "TOP")
	end

	function TOOL:DrawHUD()
		local ply = LocalPlayer()
		if not IsValid(ply) then return end

		-- Always show the front/top axes of whatever ACE part you're aiming at.
		local aim = ply:GetEyeTrace().Entity
		if IsValid(aim) and (GRID[aim:GetClass()] or FUEL[aim:GetClass()]) then
			drawFront(aim)
		end
		local range = math.Clamp(self:GetClientNumber("range", 2500), 256, 16384)
		local show  = self:GetClientNumber("show", 2)
		local elec, fuel = (show == 0 or show == 2), (show == 1 or show == 2)

		for _, ent in ipairs(ents.FindInSphere(ply:GetPos(), range)) do
			if not IsValid(ent) then continue end
			local cls = ent:GetClass()

			if elec and GRID[cls] then
				local live  = ent:GetNWBool("AceLive", false)
				local state = ent:GetNWInt("AceState", 0)
				local kw    = ent:GetNWFloat("AceKW", 0)
				local avg   = ent:GetNWFloat("AceKWAvg", kw)
				local cap   = ent:GetNWFloat("AceCap", 0)
				local role  = ent:GetNWString("AceRole", "")
				local col   = flowColor(state, live, kw, cap)
				drawLinks(ent, "GL", col)
				drawAux(ent)

				local scr = ent:WorldSpaceCenter():ToScreen()
				if scr.visible then
					local lines
					if cls == "ace_power_collector" then
						local dist = ent:GetNWFloat("AceDist", -1)
						lines = { "Collector", live and ("PICKING UP " .. fmtKW(kw)) or "no pickup",
							(dist >= 0) and ("wire " .. math.Round(dist, 0) .. "u") or "" }
					else
						-- Status line names WHY a node looks the way it does: its role
						-- (source / buffer / relay / sink / wire / off) plus fault state.
						local status = (state == 2 and "BROKEN") or (state == 1 and "OVERLOAD")
							or (live and "live" or "no power")
						if role ~= "" then status = status .. " - " .. role end
						lines = {
							ent:GetNWString("WireName", cls),
							status,
							ent:GetNWFloat("AceV", 0) .. " V   " .. fmtKW(kw) .. " / " .. fmtKW(cap),
							"avg " .. fmtKW(avg) .. "   " .. ent:GetNWFloat("AceHeat", 0) .. " C",
						}
					end
					drawLabel(scr, lines, col)
				end
			elseif fuel and FUEL[cls] then
				drawLinks(ent, "PL", Color(120, 180, 255))
				drawAux(ent)
				local scr = ent:WorldSpaceCenter():ToScreen()
				if scr.visible then
					local col   = Color(120, 180, 255)
					local lines = { ent:GetNWString("WireName", cls) }
					-- Show live refuel activity so you can see fuel/charge actually moving.
					if cls == "ace_fuel_socket" then
						if ent:GetNWBool("AceConnected", false) then
							local f = ent:GetNWFloat("AceFlow", 0)
							local elec = ent:GetNWBool("AceElectric", false)
							lines[#lines + 1] = "PLUGGED IN"
							lines[#lines + 1] = elec and (fmtKW(f)) or (math.Round(f, 1) .. " L/s")
							col = Color(120, 230, 140)
						else
							lines[#lines + 1] = "no plug"
						end
					elseif cls == "ace_fuel_pipe" then
						local f = ent:GetNWFloat("AceFlow", 0)
						if f > 0.01 then
							lines[#lines + 1] = math.Round(f, 1) .. " L/s"
							col = Color(120, 230, 140)
						end
					elseif cls == "acf_fueltank" and ent:GetNWBool("AceSupplying", false) then
						lines[#lines + 1] = "SUPPLYING (wireless)"
						col = Color(120, 230, 140)
					end
					drawLabel(scr, lines, col)
				end
			end
		end

		draw.SimpleText("ACE Conduit - LMB: pick up / lay segment   RMB: bury/raise   R: finish chain   (aim at a part to see its FRONT/TOP)",
			"DermaDefault", ScrW() * 0.5, ScrH() - 40, color_white, TEXT_ALIGN_CENTER)
	end

	function TOOL.BuildCPanel(panel)
		panel:AddControl("Header", { Text = "ACE Conduit", Description = "Spawn a power line / fuel pipe from the ACE menu, then left-click it and stack copies. Right-click buries a segment by the depth below." })
		panel:AddControl("ComboBox", {
			Label = "Overlay",
			Options = {
				["Both"]     = { ace_conduit_show = "2" },
				["Electric"] = { ace_conduit_show = "0" },
				["Fuel"]     = { ace_conduit_show = "1" },
			},
		})
		panel:AddControl("Slider", { Label = "Bury depth", Command = "ace_conduit_depth", Type = "Float", Min = "0", Max = "512" })
		panel:AddControl("Slider", { Label = "Overlay range", Command = "ace_conduit_range", Type = "Float", Min = "512", Max = "8000" })
	end
end
