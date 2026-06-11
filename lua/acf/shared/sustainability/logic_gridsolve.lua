--- ACE Sustainability - Electric grid SOLVER (pure, no GMod globals).
--
-- The "how does power get from a source to a load" core, lifted out of the GMod
-- layer so it can be unit-tested with plain Lua mock nodes. It operates on
-- duck-typed NODE tables; the GMod side (sh_sustain) wraps real entities and
-- injects geometry through callbacks, so this file never touches Entity/CurTime.
--
-- A NODE provides:
--   .GridStations         array of neighbour nodes (the undirected graph)
--   :IsConductor()        true = a wire (carries power, no DC<->AC conversion)
--   :IsRelay()            true = re-references the line to its own .Voltage (a
--                         transformer when online, or a relay-mode station)
--   :IsSource()           true = a tappable source (leaf; never expanded through)
--   :GridHasEnergy()      true = that source currently has energy to give
--   :GridCapacity()       kW a NON-conductor node can carry (station/transformer)
--   .Ampacity             a conductor's current rating (its kW cap = Ampacity*V)
--   .Voltage              voltage a source/relay DEFINES (conductors don't define)
--   .GridSourceEff        a source's own (dis)charge efficiency (optional)
--   :GridSourcePriority() merit-order tier (0 = real source, >0 = buffer)
--
-- OPTS:
--   conv          per DC<->AC conversion loss (default 0.04)
--   maxHops       relay-to-relay conductor hop budget (default 20)
--   hopEff(a,b)   efficiency of traversing edge a->b (geometry/resistance; default 1)
--   valid(n)      node-still-valid predicate (default: non-nil)
--   battChargeEff fallback source efficiency (default 0.95)
--   ignoreEntrySource  don't tap the entry node itself (capacitor self-recharge)
--   maxTier       only tap sources with GridSourcePriority <= this (default all).
--                 A buffer recharging itself passes 0 so it only sips from REAL
--                 sources - otherwise two idle capacitors would endlessly shuttle
--                 charge into each other's conversion losses until both are empty
--
-- VOLTAGE is path-based: a conductor has NO intrinsic voltage; it carries the
-- voltage established by the source/relay that energises it, re-referenced at each
-- relay/transformer. We compute that per path (so a conductor's capacity is
-- Ampacity * the voltage actually on it) and report it back for display.
-- @module logic_gridsolve

local GridSolve = {}

local HUGE = math.huge

-- Can power flow THROUGH this node (vs. it being a dead end)? A conductor always
-- conducts; a relay / transformer / station conducts only while online. Used to
-- stop a load wired straight onto an OFFLINE transformer (which becomes the entry
-- node, the one frame that isn't otherwise screened) from drawing through it.
local function conducts(n)
	if n.IsConductor and n:IsConductor() then return true end
	if n.Offline and n:Offline() then return false end
	return true
end

-- Capacities + carried voltage for one source path. `nodes` is load-first
-- ([entry ... source]); we walk it source->load tracking the segment voltage,
-- which starts at the source's voltage and switches whenever we pass a relay /
-- transformer (its output voltage applies to everything downstream of it).
local function pathInfo(source, nodes)
	local caps, carryV = {}, {}
	local segV = (source and source.Voltage) or 1
	local bottleneck = HUGE

	for i = #nodes, 1, -1 do
		local n = nodes[i]
		local cap
		if n.IsConductor and n:IsConductor() then
			carryV[n] = segV
			cap = (n.Ampacity or 0) * segV
		else
			cap = (n.GridCapacity and n:GridCapacity()) or 0
		end
		caps[n] = cap
		if cap < bottleneck then bottleneck = cap end

		-- A relay/transformer (not the source itself) re-references the voltage
		-- carried toward the load to its own output voltage.
		if n ~= source and n.Voltage and n.IsRelay and n:IsRelay() then
			segV = n.Voltage
		end
	end

	if bottleneck == HUGE then bottleneck = 0 end
	return caps, carryV, bottleneck, segV   -- segV here = voltage at the load end
end

--- Best path PER reachable source from `entry`, sorted best-first.
-- Returns an array of records:
--   { source, eff, capacity, caps, carryV, entryVolt, srcEff, tier, nodes }
-- where `caps`/`carryV` are node-keyed tables for that path (used by Pull).
function GridSolve.FindSources(entry, opts)
	opts = opts or {}
	if not entry then return {} end
	local conv       = opts.conv or 0.04
	local convFactor = 1 - conv
	local maxHops    = opts.maxHops or 20
	local hopEff     = opts.hopEff or function() return 1 end
	local valid      = opts.valid or function(n) return n ~= nil end
	local battEff    = opts.battChargeEff or 0.95
	local maxTier    = opts.maxTier or HUGE

	local bySource = {}

	local function consider(source, eff, nodes)
		local tier = (source.GridSourcePriority and source:GridSourcePriority()) or 0
		if tier > maxTier then return end
		local caps, carryV, bottleneck, entryVolt = pathInfo(source, nodes)
		local prev = bySource[source]
		if not prev or eff > prev.eff then
			bySource[source] = {
				source    = source,
				eff       = eff,
				capacity  = bottleneck,
				caps      = caps,
				carryV    = carryV,
				entryVolt = entryVolt,
				srcEff    = (source.GridSourceEff) or battEff,
				tier      = tier,
				nodes     = nodes,
			}
		end
	end

	local frames = {}
	frames[entry] = { v = 1, depth = 0, nodes = { entry }, settled = false }

	-- Zero-hop: the entry node may itself be the source.
	if not opts.ignoreEntrySource and entry.IsSource and entry:IsSource()
		and entry.GridHasEnergy and entry:GridHasEnergy() then
		consider(entry, convFactor * convFactor, { entry })
	end

	while true do
		local node, rec
		for n, r in pairs(frames) do
			if not r.settled and (not rec or r.v > rec.v) then node, rec = n, r end
		end
		if not node then break end
		rec.settled = true

		-- The entry node is the only frame not pre-screened for conduction (every
		-- other frame is a conductor or an online relay by construction). If the
		-- entry itself is an OFFLINE relay/transformer - a load wired straight onto a
		-- switched-off transformer - it can't pass power from its neighbours, so skip
		-- expanding it (it may still have been tapped as a zero-hop source above).
		for _, N in ipairs((node == entry and not conducts(node)) and {} or (node.GridStations or {})) do
			if valid(N) then
				local isCond  = N.IsConductor and N:IsConductor()
				local reachV  = rec.v * (hopEff(node, N) or 1)

				if N.IsSource and N:IsSource() and N.GridHasEnergy and N:GridHasEnergy() then
					local nodes2 = { unpack(rec.nodes) }
					nodes2[#nodes2 + 1] = N
					consider(N, convFactor * convFactor * reachV, nodes2)
				elseif rec.depth < maxHops and (isCond or (N.IsRelay and N:IsRelay())) then
					-- Conductor: no conversion, costs one hop. Relay: re-boost (one
					-- conversion) and RESET the hop budget (acts as a repeater).
					local nextV     = isCond and reachV or (reachV * convFactor)
					local nextDepth = isCond and (rec.depth + 1) or 0
					local f = frames[N]
					if not f or (not f.settled and nextV > f.v) then
						local nodes2 = { unpack(rec.nodes) }
						nodes2[#nodes2 + 1] = N
						frames[N] = { v = nextV, depth = nextDepth, nodes = nodes2, settled = false }
					end
				end
			end
		end
	end

	local list = {}
	for _, s in pairs(bySource) do list[#list + 1] = s end
	table.sort(list, function(a, b)
		if a.tier ~= b.tier then return a.tier < b.tier end
		return a.eff > b.eff
	end)
	return list
end

--- Share `wantKWh` (this tick) across the reachable sources in merit order.
-- Pure: capacity-sharing is tracked on node fields (`_gridUsed`/`_gridUsedT`,
-- stamped with opts.now so it self-resets each tick); per-node throughput and the
-- carried voltage are written back via the provided callbacks so the GMod layer
-- can keep its Entity-specific bookkeeping. Returns (deliveredKWh, entryVoltage).
--
-- opts (in addition to FindSources opts): now (tick stamp), hr (dt/3600),
--   draw(source, needKWh) -> kWh actually drawn,
--   onFlow(node, prevNode, powerKW, carryV) optional per-node side effect.
function GridSolve.Pull(entry, wantKWh, opts)
	opts = opts or {}
	if not entry or wantKWh <= 0 then return 0, 0 end
	local sources = GridSolve.FindSources(entry, opts)
	if #sources == 0 then return 0, 0 end

	local now  = opts.now or 0
	local hr   = opts.hr or 1
	local draw = opts.draw or function(src, need) return src.DrawEnergy and src:DrawEnergy(need) or 0 end
	local onFlow = opts.onFlow

	local function committed(n)
		return (n._gridUsedT == now) and (n._gridUsed or 0) or 0
	end
	local function commit(n, kw)
		if n._gridUsedT ~= now then n._gridUsedT = now; n._gridUsed = 0 end
		n._gridUsed = n._gridUsed + kw
	end

	local remaining = wantKWh
	local total     = 0
	local entryVolt = 0

	for _, s in ipairs(sources) do
		if remaining <= 1e-12 then break end
		local pathCap = HUGE
		for _, n in ipairs(s.nodes) do
			pathCap = math.min(pathCap, (s.caps[n] or 0) - committed(n))
		end
		if pathCap > 0 then
			local takeKWh = math.min(remaining, pathCap * hr)
			local need    = takeKWh / math.max(s.eff * (s.srcEff or 1), 0.01)
			local drawn   = draw(s.source, need) or 0
			local delivered = drawn * s.eff
			if delivered > 0 then
				local pkw = delivered / math.max(hr, 1e-9)
				local nodes = s.nodes
				for i = 1, #nodes do
					local n = nodes[i]
					commit(n, pkw)
					if onFlow then onFlow(n, nodes[i + 1], pkw, s.carryV[n]) end
				end
				total     = total + delivered
				remaining = remaining - delivered
				if s.entryVolt > entryVolt then entryVolt = s.entryVolt end
			end
		end
	end

	return total, entryVolt
end

return GridSolve
