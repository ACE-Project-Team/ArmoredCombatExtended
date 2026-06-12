--[[
	ACE Sustainability — module loader (GMod side)

	Loads the pure-logic modules and exposes them under ACE.Sustain so the
	entity files can grab them without caring about include paths. The logic
	files themselves stay GMod-free so they can be unit-tested with plain lua

	WHO DOES WHAT — the sustainability cast, so nobody has to reverse-engineer
	roles from the Think functions:

	  MAKE POWER     ace_solarpanel   sun -> battery
	                 ace_alternator   engine shaft -> battery
	  STORE POWER    acf_fueltank (Electric)  the battery everything charges/draws
	                 ace_capacitor    grid-side buffer (recharges from REAL sources only)
	  MOVE POWER     ace_transfer_station  grid hub: sources from / sinks to its battery
	                 ace_power_line   conductor segment (ampacity-limited)
	                 ace_transformer  voltage step between grid sections
	                 ace_power_breaker     overcurrent cutout protecting a station
	                 ace_power_collector   tram pickup: overhead wire -> onboard battery
	  USE POWER      ace_power_consumer    appliance / dump load: burns kW, makes nothing
	  OIL CHAIN      ace_oil_pump     thumper derrick: ELECTRICITY IN, crude oil out
	                                  of the ground (only while grounded)
	                 ace_fuel_pipe / ace_fuel_pump   liquid transport (pumps extend range)
	                 ace_refinery     crude + electricity -> petrol OR diesel
	  FUEL, NO OIL   ace_fuel_synth   electricity -> petrol AND diesel at once; an
	                                  unvented product backs up and cooks off the reactor
	  BURN FUEL      ace_burner       flare: destroys unwanted liquid fuel (e.g. the synth
	                                  product you don't need); outputs NOTHING, just fire
	  REFUEL         ace_fuel_socket / ace_fuel_plug  dock-and-transfer connectors
	  EXPLOSIVES     ace_explosive    scalable wire-detonated charge (size-capped)
	                 ace_explosive_prebuilt   satchel / aerial bomb / barrel props

	The commonly-confused pairs: the OIL PUMP consumes electricity (it extracts
	crude, it generates nothing), and the BURNER is fuel *disposal*, not a fuel
	user or a power source. The SYNTH is the only thing that turns electricity
	into fuel; the REFINERY needs crude as well.
]]--

ACE = ACE or {}

local PATH = "acf/shared/sustainability/"

local MODULES = {
	"logic_scale",
	"logic_heat",
	"logic_alternator",
	"logic_solar",
	"logic_battery",
	"logic_synth",
	"logic_pipe",
	"logic_grid",
	"logic_power",
	"logic_fault",
	"logic_gridsolve",
}

if SERVER then
	for _, name in ipairs(MODULES) do
		AddCSLuaFile(PATH .. name .. ".lua")
	end
end

local Sustain = {}

Sustain.Scale      = include(PATH .. "logic_scale.lua")
Sustain.Heat       = include(PATH .. "logic_heat.lua")
Sustain.Alternator = include(PATH .. "logic_alternator.lua")
Sustain.Solar      = include(PATH .. "logic_solar.lua")
Sustain.Battery    = include(PATH .. "logic_battery.lua")
Sustain.Synth      = include(PATH .. "logic_synth.lua")
Sustain.Pipe       = include(PATH .. "logic_pipe.lua")
Sustain.Grid       = include(PATH .. "logic_grid.lua")
Sustain.Power      = include(PATH .. "logic_power.lua")
Sustain.Fault      = include(PATH .. "logic_fault.lua")
Sustain.GridSolve  = include(PATH .. "logic_gridsolve.lua")

ACE.Sustain = Sustain

------------------------------------------------------------------
-- Map sun direction + ambient brightness (SERVER-authoritative).
--
-- Read straight from the map's own entities on the server (env_sun for the sun
-- direction, light_environment for the baked sky brightness) - exactly how
-- wiremod's E2 sunDirection() does it. We deliberately do NOT take this from
-- clients: util.GetSunInfo() is client-only, but trusting a client to forward
-- it would let a malicious player spam bogus values every tick and grief
-- everyone's solar output. Map entities are static and un-spoofable, so the
-- server reads them itself at load.
------------------------------------------------------------------
ACE.SunDir        = ACE.SunDir or Vector(0, 0, 1)   -- world unit vector toward the sun
ACE.SunLastSync   = ACE.SunLastSync or nil          -- CurTime of last good read (nil = none yet -> convar fallback)
ACE.MapBrightness = ACE.MapBrightness or 1          -- 0..1 baked sky luminance (1 = bright; lower on dark/night maps)

if SERVER then
	-- Pull the sun direction + sky brightness from the map entities. Safe to call
	-- repeatedly; only writes ACE.* when it actually finds valid data, so a map
	-- with no env_sun simply leaves the convar-sun fallback in charge.
	function ACE.RefreshMapSun()
		local sunEnt = ents.FindByClass("env_sun")[1]
		if IsValid(sunEnt) then
			local kv  = sunEnt:GetKeyValues()
			local dir = kv and kv.sun_dir
			if isstring(dir) then dir = Vector(dir) end   -- some builds hand it back as "x y z"
			if isvector(dir) and dir:LengthSqr() > 0.01 then
				dir = dir:GetNormalized()
				if dir.z < 0 then dir = -dir end          -- keep it pointing skyward
				ACE.SunDir      = dir
				ACE.SunLastSync = CurTime()
			end
		end

		local lightEnt = ents.FindByClass("light_environment")[1]
		if IsValid(lightEnt) then
			local kv  = lightEnt:GetKeyValues()
			local lit = kv and kv._light                  -- "R G B brightness"
			if isstring(lit) then
				local r, g, b = lit:match("^(%d+)%s+(%d+)%s+(%d+)")
				if r then
					-- Grayscale luminance of the sky colour (0..1). Coarser than the
					-- old client lightmap sample, but server-side and un-spoofable.
					local lum = (0.299 * r + 0.587 * g + 0.114 * b) / 255
					ACE.MapBrightness = math.Clamp(lum, 0, 1)
				end
			end
		end
	end

	hook.Add("InitPostEntity", "ace_refresh_map_sun", ACE.RefreshMapSun)
	-- If the addon (re)loads after the map entities already exist - e.g. a mid-
	-- session lua refresh - InitPostEntity won't fire again, so read once more
	-- on the next tick to be safe. Map sun is static, so no ongoing polling.
	timer.Simple(1, ACE.RefreshMapSun)
end

------------------------------------------------------------------
-- Server-side engine glue shared by the scalable power entities.
-- Kept here (not in the pure modules) because it touches Entity/ACF.
------------------------------------------------------------------
if SERVER then

	local SCALE_PATTERN = "^%d+%.?%d*:%d+%.?%d*:%d+%.?%d*$"

	-- Parse an "L:W:H" size string into a clamped Vector (crate size limits).
	-- Accepts a Vector unchanged. Returns nil if the string is malformed.
	-- maxSize (optional) tightens the upper clamp for entities whose definition
	-- caps them below the global crate limit (e.g. explosive charges), and is
	-- re-applied here so an edited dupe can't smuggle in an oversized one.
	function Sustain.ParseScale(str, maxSize)
		if isvector(str) then return str end
		if not isstring(str) or not string.match(str, SCALE_PATTERN) then return end

		local parts = string.Explode(":", str)
		local v = Vector(tonumber(parts[1]) or 0, tonumber(parts[2]) or 0, tonumber(parts[3]) or 0)

		local mn = ACF.SustainMinimumSize or ACF.CrateMinimumSize or 5
		local mx = ACF.CrateMaximumSize or 250
		if maxSize then mx = math.min(mx, maxSize) end
		v.x = math.Clamp(math.Round(v.x, 1), mn, mx)
		v.y = math.Clamp(math.Round(v.y, 1), mn, mx)
		v.z = math.Clamp(math.Round(v.z, 1), mn, mx)
		return v
	end

	-- Apply a ModelData shape at the given dimensions to a scalable entity,
	-- re-validating the shape against the definition's allow/block list so a
	-- hand-edited dupe can't smuggle in a disallowed shape.
	-- Returns { dims = Vector, volume = number, area = number } or nil.
	function Sustain.ApplyShape(ent, scaleVec, shape, def)
		if not Sustain.Scale.ShapeAllowed(shape, def or {}) then return end

		local md = ACE.ModelData[shape]
		if not md then return end

		local L, W, H = scaleVec.x, scaleVec.y, scaleVec.z
		local entScale = Vector(L / md.DefaultSize, W / md.DefaultSize, H / md.DefaultSize)

		ent:SetModel(md.Model)
		ent:PhysicsInit(SOLID_VPHYSICS)
		ent:SetMoveType(MOVETYPE_VPHYSICS)
		ent:SetSolid(SOLID_VPHYSICS)

		ent.ScaleData = {
			Mesh     = md.CustomMesh,
			Scale    = entScale,
			Size     = md.DefaultSize,
			Material = md.physMaterial,
		}
		ent.IsScalable = true
		ent:ACE_SetScale(ent.ScaleData)

		return {
			dims   = Vector(L, W, H),
			volume = md.volumefunction(L, W, H),
			area   = L * W,
		}
	end

	-- Build a sandbox-spawnmenu SpawnFunction for a scalable (size:shape) ent.
	-- It picks the first definition for the given ACF.Weapons key and spawns it
	-- at the player's aim with the definition's MenuDefault size/shape. The ACF
	-- tool menu remains the way to spawn a custom-sized one.
	function Sustain.ScalableSpawn(makeFn, weaponsKey)
		return function(_, ply, tr)
			if not tr or not tr.Hit then return end
			local tbl = ACF.Weapons[weaponsKey]
			local id = tbl and next(tbl)
			if not id then return end

			local d     = tbl[id].MenuDefault or {}
			local size  = (d.L or 20) .. ":" .. (d.W or 20) .. ":" .. (d.H or 20)
			local shape = d.Shape or "Box"
			local pos   = tr.HitPos + tr.HitNormal * ((d.H or 20) * 0.6)
			local ang   = Angle(0, IsValid(ply) and ply:EyeAngles().yaw - 180 or 0, 0)

			return makeFn(ply, pos, ang, id, size, shape)
		end
	end

	------------------------------------------------------------------
	-- Gridless electric network traversal.
	--
	-- Stations link directly to each other (ent.GridStations). Power flows from a
	-- Source station, through any number of Relay stations, to a demander (a Sink
	-- station or a Consumer). Loss accrues per hop from logic_grid using the
	-- voltage of the upstream (source-side) node, and each Relay re-boosts to its
	-- own voltage for the next leg. We DFS outward from the demander's entry
	-- station to the best-delivering Source that still has charge.
	------------------------------------------------------------------

	-- Build the OPTS table the pure solver (logic_gridsolve) needs to operate on
	-- live entities: it injects the GMod-specific geometry/validity, the pure
	-- module owns the Dijkstra / merit-order / path-voltage maths. `hopEff` is the
	-- only place real positions enter the solve - a physical wire's own resistance
	-- (length / cross-section / temp / carried voltage, computed in its Think ->
	-- ConductorEff) accounts for the whole run, so we use that directly; abstract
	-- station/transformer links instead lose to the node-to-node distance.
	local function solveOpts(ignoreEntrySource, maxTier)
		return {
			conv              = Sustain.Grid.ConvLoss or 0.04,
			maxHops           = ACF.GridMaxHops or 20,
			battChargeEff     = ACF.BatteryChargeEff or 0.95,
			valid             = IsValid,
			ignoreEntrySource = ignoreEntrySource,
			maxTier           = maxTier,
			hopEff = function(a, b)
				if b.IsConductor and b:IsConductor() then
					return b.ConductorEff or 1
				end
				return 1 - Sustain.Grid.LineLoss(a:GetPos():Distance(b:GetPos()), b.Voltage or 1, true)
			end,
		}
	end

	-- Pull up to wantKWh (this tick) through the grid into the demander. `entry`
	-- is the node the demander is attached to. The load is SHARED across every
	-- reachable source in merit order (most-efficient path first), so several
	-- generators/batteries on one grid all contribute - and a shared wire/relay
	-- can't be over-committed because per-node capacity used this tick is tracked.
	-- Returns (deliveredKWh, deliveredVoltage). The voltage is PATH-BASED - the
	-- source/transformer voltage actually carried to the load end (the pure solver
	-- computes it) - then sagged below that when the grid can't meet the demanded
	-- power, which lets a Consumer/Collector enforce a minimum-voltage requirement.
	function Sustain.GridPull(entry, wantKWh, dt, ignoreEntrySource, maxTier)
		if not IsValid(entry) or wantKWh <= 0 then return 0, 0 end

		local hr   = dt / 3600
		local opts = solveOpts(ignoreEntrySource, maxTier)
		opts.now = CurTime()
		opts.hr  = hr
		-- DrawEnergy needs dt; the pure module only passes (source, need).
		opts.draw = function(src, need)
			return IsValid(src) and src:DrawEnergy(need, dt) or 0
		end
		-- Per-node side effects the GMod layer still owns: rolling throughput, the
		-- flow-direction hint for the overlay, and the carried voltage stamped on
		-- each conductor (for its capacity / display). `prevN` is the source-side
		-- node feeding `n`, so it is the one sending power TO `n`.
		opts.onFlow = function(n, prevN, pkw, carryV)
			n.ThroughputAccum = (n.ThroughputAccum or 0) + pkw
			if IsValid(prevN) then prevN.FlowToAccum = n end
			-- A conductor on several paths takes the highest voltage put on it; the
			-- consumer (power line) reads + clears _carryV in its own Think.
			if carryV and carryV > (n._carryV or 0) then n._carryV = carryV end
		end

		local total, entryVolt = Sustain.GridSolve.Pull(entry, wantKWh, opts)
		if total <= 0 then return 0, 0 end

		local powerKW  = total / math.max(hr, 1e-9)
		local demandKW = wantKWh / math.max(hr, 1e-9)
		local volts    = Sustain.Power.Delivered(entryVolt > 0 and entryVolt or (entry.Voltage or 1), powerKW, demandKW).voltage
		return total, volts
	end

	-- True if an energised source is reachable from `entry` through the grid.
	-- Collectors use it to decide a nearby station/wire is a live pickup point.
	function Sustain.GridHasSource(entry)
		if not IsValid(entry) then return false end
		return #Sustain.GridSolve.FindSources(entry, solveOpts(false)) > 0
	end

	-- Highest PATH voltage that reaches `entry` (the voltage a connected-but-idle
	-- conductor would carry), so a live wire can show its voltage even when no load
	-- is currently pulling power through it. 0 when no source is reachable.
	function Sustain.GridVoltage(entry)
		if not IsValid(entry) then return 0 end
		local list = Sustain.GridSolve.FindSources(entry, solveOpts(false))
		local best = 0
		for _, s in ipairs(list) do
			if (s.entryVolt or 0) > best then best = s.entryVolt end
		end
		return best
	end

	------------------------------------------------------------------
	-- Electrical fault manager (player arc / electrocution damage).
	--
	-- Event-driven and cheap: an electrical entity adds itself to ActiveFaults
	-- ONLY while it is actually hazardous (overloaded / broken-and-live), which
	-- its own Think already computes. A single timer - created lazily and removed
	-- the moment the set empties - iterates just those entities and checks
	-- player.GetAll() with a squared-distance test (cheaper than FindInSphere for
	-- the usual small player count). A healthy grid spawns no timer at all.
	------------------------------------------------------------------
	Sustain.ActiveFaults = Sustain.ActiveFaults or {}
	local FAULT_INTERVAL = 0.3

	local function faultTick()
		local any = false
		for ent in pairs(Sustain.ActiveFaults) do
			if not IsValid(ent) or not ent.FaultArc then
				Sustain.ActiveFaults[ent] = nil
			else
				any = true
				local arc    = ent.FaultArc
				local origin = ent:WorldSpaceCenter()
				local r2     = arc.radius * arc.radius
				local attacker = IsValid(ent.FaultOwner) and ent.FaultOwner or ent

				for _, ply in ipairs(player.GetAll()) do
					if ply:Alive() and ply:WorldSpaceCenter():DistToSqr(origin) <= r2 then
						local dmg = DamageInfo()
						dmg:SetDamage(arc.damagePerSec * FAULT_INTERVAL)
						dmg:SetDamageType(DMG_SHOCK)
						dmg:SetAttacker(attacker)
						dmg:SetInflictor(ent)
						ply:TakeDamageInfo(dmg)
					end
				end

				-- Cheap throttled spark at the fault.
				if CurTime() > (ent.NextFaultSpark or 0) then
					local fx = EffectData()
					fx:SetOrigin(origin)
					fx:SetMagnitude(2) fx:SetScale(1) fx:SetRadius(10)
					util.Effect("Sparks", fx)
					ent:EmitSound("ambient/energy/zap" .. math.random(1, 9) .. ".wav", 75, math.random(90, 110), 0.6)
					ent.NextFaultSpark = CurTime() + math.Rand(0.4, 0.9)
				end
			end
		end
		if not any then
			timer.Remove("ace_fault_manager")
			Sustain.FaultTimerRunning = false
		end
	end

	-- Mark `ent` hazardous with the given arc {radius, damagePerSec}.
	function Sustain.RegisterFault(ent, arc)
		if not IsValid(ent) then return end
		ent.FaultArc   = arc
		ent.FaultOwner = ent.CPPIGetOwner and ent:CPPIGetOwner() or nil
		Sustain.ActiveFaults[ent] = true
		if not Sustain.FaultTimerRunning then
			Sustain.FaultTimerRunning = true
			timer.Create("ace_fault_manager", FAULT_INTERVAL, 0, faultTick)
		end
	end

	function Sustain.ClearFault(ent)
		if not ent or not ent.FaultArc then return end
		ent.FaultArc = nil
		Sustain.ActiveFaults[ent] = nil
	end

	-- Convenience: compute the hazard from a state table and register/clear.
	-- (See logic_fault for the state fields.)
	function Sustain.UpdateFault(ent, state)
		if Sustain.Fault.IsHazard(state) then
			Sustain.RegisterFault(ent, Sustain.Fault.Arc(state))
		else
			Sustain.ClearFault(ent)
		end
	end

	-- Walk the grid graph outward from `entry` and trip any breaker protecting a
	-- node in that chain. This is what a short circuit (or any catastrophic fault)
	-- uses to open the protection and de-energise the run. Bounded by GridMaxHops.
	function Sustain.TripChainBreakers(entry)
		if not IsValid(entry) then return false end
		local maxHops = ACF.GridMaxHops or 10
		local seen, stack, tripped = { [entry] = true }, { entry }, false
		local hops = 0
		while #stack > 0 and hops < maxHops * 4 do
			local node = table.remove(stack)
			hops = hops + 1
			if IsValid(node.Breaker) and node.Breaker.SetTripped and not node.Breaker.Tripped then
				node.Breaker:SetTripped(true)
				tripped = true
			end
			for _, N in ipairs(node.GridStations or {}) do
				if IsValid(N) and not seen[N] then seen[N] = true stack[#stack + 1] = N end
			end
		end
		return tripped
	end

	------------------------------------------------------------------
	-- Visualization networking. Grid entities publish a few rounded NW values so
	-- the client-side Engineer tool can draw live readouts and flow-coloured links
	-- without a custom net protocol. NW vars only send on change, and rounding
	-- keeps the churn tiny (far less than the overlay-text these ents already send).
	-- state: 0 = ok, 1 = overloaded, 2 = broken/tripped.
	------------------------------------------------------------------
	-- Node role, derived centrally from the role methods every grid node implements,
	-- so the overlay can label what each part is DOING (and the buffer is obviously a
	-- buffer, not a primary source) without each entity having to report it.
	local function vizRole(ent)
		if ent.Offline and ent:Offline() then
			return (ent.Tripped or (ent.GetNWInt and ent:GetNWInt("AceState", 0) == 2)) and "broken" or "off"
		end
		if ent.IsConductor and ent:IsConductor() then return "wire" end
		if ent.IsSink and ent:IsSink() then return "sink" end
		if ent.IsSource and ent:IsSource() then
			return (ent.GridSourcePriority and ent:GridSourcePriority() > 0) and "buffer" or "source"
		end
		if ent.IsRelay and ent:IsRelay() then return "relay" end
		return "idle"
	end

	function Sustain.NetworkViz(ent, d)
		ent:SetNWFloat("AceV",    math.Round(d.v or 0, 0))
		ent:SetNWFloat("AceKW",   math.Round(d.kw or 0, 1))
		ent:SetNWFloat("AceCap",  math.Round(d.cap or 0, 0))
		ent:SetNWFloat("AceHeat", math.Round(d.heat or 0, 0))
		ent:SetNWFloat("AceDist", math.Round(d.dist or -1, 0))
		ent:SetNWBool("AceLive",  d.live and true or false)
		ent:SetNWInt("AceState",  d.state or 0)

		-- Rolling average (EMA) of throughput alongside the instantaneous value, so a
		-- jittery transient reads as a steady number. ~3 s time-constant.
		local kw  = d.kw or 0
		local a   = ent._kwAvg or kw
		ent._kwAvg = a + (kw - a) * 0.08
		ent:SetNWFloat("AceKWAvg", math.Round(ent._kwAvg, 1))

		-- What this node is doing right now (source / buffer / relay / sink / wire / off).
		ent:SetNWString("AceRole", (d.role or vizRole(ent)))

		-- Which linked node this one is currently sending power TO (0 = none).
		-- Set by Sustain.GridPull each tick and consumed (reset) here.
		ent:SetNWInt("AceFlowTo", IsValid(ent.FlowToAccum) and ent.FlowToAccum:EntIndex() or 0)
		ent.FlowToAccum = nil
	end

	-- Publish a device's AUXILIARY links (the device -> tank/battery links that are
	-- NOT part of the homogeneous grid/pipe graph), so the Conduit overlay can draw
	-- the WHOLE chain - e.g. a Transfer Station to its battery, or a Refinery to its
	-- oil/power/output tanks. `links` is an array of
	-- { ent = <ent>, label = <string>, into = <bool> }, where `into` marks links
	-- that FEED the device (other -> device), so the overlay's flow pulse animates
	-- in the real direction (default: device -> other, e.g. storing into a tank).
	function Sustain.NetworkAux(ent, links)
		local n = 0
		for _, l in ipairs(links or {}) do
			if l and IsValid(l.ent) then
				n = n + 1
				ent:SetNWEntity("AX" .. n, l.ent)
				ent:SetNWString("AX" .. n .. "L", l.label or "")
				ent:SetNWBool("AX" .. n .. "I", l.into or false)
			end
		end
		ent:SetNWInt("AXN", n)
	end

	------------------------------------------------------------------
	-- Pipe-graph traversal (fuel network).
	--
	-- Pipes (and Pump nodes) link to each other and to tanks. Friction (bore +
	-- distance) spends down a pressure budget the supply provides; each Pump adds
	-- budget, so pumps extend range - the fuel analogue of relay stations.
	-- Direction is set by Refuel Duty: a tank with SupplyFuel gives, others take.
	------------------------------------------------------------------

	-- From a receiver-side pipe, find the cheapest reachable supply tank.
	-- Returns { supply, flowCap, pipes, cost } or nil.
	--
	-- Best-first (Dijkstra) search over the pipe/pump graph by cumulative friction
	-- `cost`: each pipe/pump node is SETTLED once, by the lowest cost to reach it,
	-- so a looped/meshed pipe network costs O(V^2) instead of the FACTORIAL blow-up
	-- of the old all-paths backtracking walk (which froze the server on a ring of
	-- pipes). Pumps and flowCap are tracked along that cheapest path; a supply is
	-- reachable when the cost to its feeding node is within the pressure budget the
	-- pumps on the way provide.
	function Sustain.PipeFindSupply(startPipe, receiver)
		if not IsValid(startPipe) or not IsValid(receiver) then return nil end
		local PipeLogic    = Sustain.Pipe
		local maxHops      = ACF.PipeMaxHops or 14
		local basePressure = ACF.PipeBasePressure or 1
		local pumpPressure = ACF.PipePumpPressure or 1
		local best

		local function canSupply(tank)
			return IsValid(tank) and tank ~= receiver and tank:GetClass() == "acf_fueltank"
				and tank.SupplyFuel and (tank.Fuel or 0) > 0 and tank.FuelType ~= "Electric"
				and receiver.CanReceiveFuel and receiver:CanReceiveFuel(tank.FuelType)
		end

		-- Per-node frame: cheapest cumulative friction to reach it, plus the pumps /
		-- flowCap / pipe list accumulated along that cheapest route.
		local frames = {}
		frames[startPipe] = {
			cost = 0, pumps = 0, flowCap = startPipe.FlowCap or math.huge,
			depth = 0, pipes = { startPipe }, settled = false,
		}

		while true do
			-- Settle the unsettled frame reachable with the LOWEST friction.
			local node, rec
			for n, r in pairs(frames) do
				if not r.settled and (not rec or r.cost < rec.cost) then node, rec = n, r end
			end
			if not node then break end
			rec.settled = true

			-- A supply tank fed by this node is usable if reaching this node stayed
			-- within the pressure budget its pumps provide.
			for _, L in ipairs(node.PipeLinks or {}) do
				if canSupply(L) and rec.cost <= basePressure + rec.pumps * pumpPressure
					and (not best or rec.cost < best.cost) then
					best = { supply = L, flowCap = rec.flowCap, pipes = rec.pipes, cost = rec.cost }
				end
			end

			if rec.depth < maxHops then
				for _, L in ipairs(node.PipeLinks or {}) do
					if IsValid(L) then
						local cls = L:GetClass()
						if cls == "ace_fuel_pipe" or cls == "ace_fuel_pump" then
							local blocked = cls == "ace_fuel_pipe" and L.Condition and L:Condition() <= 0
							if not blocked then
								local hopCost = PipeLogic.HopFriction(node:GetPos():Distance(L:GetPos()), L.BoreArea or 100)
								local newCost = rec.cost + hopCost
								local f = frames[L]
								if not f or (not f.settled and newCost < f.cost) then
									local pipes2 = { unpack(rec.pipes) }
									pipes2[#pipes2 + 1] = L
									frames[L] = {
										cost    = newCost,
										pumps   = rec.pumps + (cls == "ace_fuel_pump" and 1 or 0),
										flowCap = math.min(rec.flowCap, L.FlowCap or rec.flowCap),
										depth   = rec.depth + 1,
										pipes   = pipes2,
										settled = false,
									}
								end
							end
						end
					end
				end
			end
		end

		return best
	end

	-- Break links that have been stretched past `range` (x ACF.LinkStretchMul),
	-- the way ACF drivetrain links snap when pulled apart. `links` is the node's
	-- neighbour list (e.g. GridStations); each over-stretched entry is unlinked
	-- BOTH ways via the entity's own Unlink so the graph + networking stay
	-- consistent, and the owner gets a chat notice. Returns true if anything broke.
	-- Cheap: a DistToSqr per link, called from the node's Think.
	function Sustain.PruneStretchedLinks(ent, links, range, label)
		if not IsValid(ent) or not links or not range or range <= 0 then return false end
		local maxD2 = (range * (ACF.LinkStretchMul or 1.5)) ^ 2
		local pos   = ent:GetPos()
		local broke = false
		for k = #links, 1, -1 do
			local L = links[k]
			if IsValid(L) and pos:DistToSqr(L:GetPos()) > maxD2 then
				if ent.Unlink then ent:Unlink(L) else table.remove(links, k) end
				broke = true
				local owner = ent.CPPIGetOwner and ent:CPPIGetOwner()
				if IsValid(owner) then
					owner:ChatPrint("ACE: a " .. (label or "link") .. " snapped - the nodes were dragged too far apart.")
				end
			end
		end
		return broke
	end

	-- Common spawn boilerplate: limit check + ownership + cleanup + overlay.
	-- factoryCheck is the "_class" string used for CheckLimit/AddCount.
	function Sustain.FinishSpawn(ent, owner, countKey, wireName)
		local phys = ent:GetPhysicsObject()
		if IsValid(phys) then
			phys:EnableMotion(true)
			phys:SetMass(ent.Mass or 50)
		end

		ent:CPPISetOwner(owner)
		ent:SetNWString("WireName", wireName)
		ent:UpdateOverlayText()

		owner:AddCount(countKey, ent)
		owner:AddCleanup("acfmenu", ent)
	end
end

return Sustain
