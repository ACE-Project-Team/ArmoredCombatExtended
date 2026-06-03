--- Connection tests for the pure grid solver (logic_gridsolve).
--
-- These are the headline deliverable: they pin down HOW power gets from a source
-- to a load through the conductor/relay graph - the behaviour the in-game bugs
-- were about (false shorts, stuck/flickering voltage, "transferred without being
-- active"). Pure Lua, no GMod; run with `luajit tests/run.lua`.

local H  = dofile((_G.ACE_TEST_DIR or "./") .. "helpers.lua")
local GS = H.load("logic_gridsolve")

-- Loss-free opts so capacity/voltage assertions are exact (geometry/efficiency is
-- injected, so a test that wants no loss simply leaves hopEff at its default 1).
local function opts(extra)
	local o = { conv = 0, battChargeEff = 1, now = 1, hr = 1 }
	for k, v in pairs(extra or {}) do o[k] = v end
	return o
end

----------------------------------------------------------------------
suite("single source -> conductor -> load")
do
	-- S (100 V, huge cap) --- W1 (ampacity 1 -> 100 kW cap) === entry
	local S  = H.node{ source = true, voltage = 100, capacity = 1e9, energy = 1000, sourceEff = 1 }
	local W1 = H.node{ conductor = true, ampacity = 1 }
	H.link(W1, S)

	local got, volt = GS.Pull(W1, 500, opts())
	near(got, 100, "delivery is capped by the conductor (ampacity*V = 100 kW)")
	near(volt, 100, "load sees the source voltage")

	-- An isolated load reaches no source.
	local lone = H.node{ conductor = true, ampacity = 1 }
	local g2 = GS.Pull(lone, 500, opts())
	near(g2, 0, "no source in reach -> nothing delivered")
end

----------------------------------------------------------------------
suite("multi-source load sharing")
do
	-- Two independent feeders into one station sum their capacity.
	local E  = H.node{ capacity = 1e9 }                 -- entry station (huge cap)
	local W1 = H.node{ conductor = true, ampacity = 0.3, voltage = 100 } -- 30 kW
	local W2 = H.node{ conductor = true, ampacity = 0.3, voltage = 100 } -- 30 kW
	local S1 = H.node{ source = true, voltage = 100, capacity = 1e9, energy = 1000, sourceEff = 1 }
	local S2 = H.node{ source = true, voltage = 100, capacity = 1e9, energy = 1000, sourceEff = 1 }
	H.link(E, W1); H.link(W1, S1)
	H.link(E, W2); H.link(W2, S2)

	local got = GS.Pull(E, 100, opts())
	near(got, 60, "two 30 kW feeders sum to 60 kW")

	-- Shared conductor: a single wire feeding two sources can't be over-committed.
	local E2 = H.node{ conductor = true, ampacity = 0.5, voltage = 100 } -- 50 kW shared
	local A  = H.node{ source = true, voltage = 100, capacity = 1e9, energy = 1000, sourceEff = 1 }
	local B  = H.node{ source = true, voltage = 100, capacity = 1e9, energy = 1000, sourceEff = 1 }
	H.link(E2, A); H.link(E2, B)
	local got2 = GS.Pull(E2, 500, opts())
	near(got2, 50, "shared conductor caps total at its own 50 kW, not 100")
end

----------------------------------------------------------------------
suite("merit order (real source before buffer)")
do
	-- S (tier 0) and CAP (tier 1 buffer). A small load the primary can meet must
	-- leave the buffer untouched.
	local E   = H.node{ capacity = 1e9 }
	local S   = H.node{ source = true, voltage = 100, capacity = 1e9, energy = 1000, sourceEff = 1, priority = 0 }
	local CAP = H.node{ source = true, voltage = 100, capacity = 1e9, energy = 1000, sourceEff = 1, priority = 1 }
	H.link(E, S); H.link(E, CAP)

	GS.Pull(E, 20, opts())
	near(CAP.Energy, 1000, "buffer is untouched while the primary can cover the load")
	near(S.Energy, 980, "primary supplies the whole 20 kWh")
end

----------------------------------------------------------------------
suite("relay extends reach (hop budget resets)")
do
	-- maxHops = 2. Source sits 3 conductor hops out; only a relay in the middle
	-- (which resets the budget) lets the solve reach it.
	local function chain(midRelay)
		local W0 = H.node{ conductor = true, ampacity = 1, voltage = 100 }
		local W1 = H.node{ conductor = true, ampacity = 1, voltage = 100 }
		local X  = midRelay
			and H.node{ relay = true, voltage = 100, capacity = 1e9 }
			or  H.node{ conductor = true, ampacity = 1, voltage = 100 }
		local W3 = H.node{ conductor = true, ampacity = 1, voltage = 100 }
		local S  = H.node{ source = true, voltage = 100, capacity = 1e9, energy = 1000, sourceEff = 1 }
		H.link(W0, W1); H.link(W1, X); H.link(X, W3); H.link(W3, S)
		return W0
	end

	local plain = GS.Pull(chain(false), 50, opts{ maxHops = 2 })
	near(plain, 0, "without a relay the source is beyond the hop budget")

	local relayed = GS.Pull(chain(true), 50, opts{ maxHops = 2 })
	check(relayed > 0, "a mid-path relay resets the budget and reaches the source")
end

----------------------------------------------------------------------
suite("offline node passes no power")
do
	-- An offline transformer reports none of the three traversable roles (not a
	-- conductor, not a relay, not a source), so it is neither tapped nor crossed -
	-- this is the "transferred power without being active" report.
	local E   = H.node{ conductor = true, ampacity = 1, voltage = 100 }
	local OFF = H.node{ capacity = 1e9 }   -- all role flags false = offline
	local W2  = H.node{ conductor = true, ampacity = 1, voltage = 100 }
	local S   = H.node{ source = true, voltage = 100, capacity = 1e9, energy = 1000, sourceEff = 1 }
	H.link(E, OFF); H.link(OFF, W2); H.link(W2, S)

	local got = GS.Pull(E, 50, opts())
	near(got, 0, "a source behind an offline transformer is unreachable")
end

----------------------------------------------------------------------
suite("path voltage through a transformer")
do
	-- S (100 V) --- W2 === T (step up to 200 V) --- W (load side)
	-- The load-side wire carries 200 V; the source-side wire carries 100 V.
	local W  = H.node{ conductor = true, ampacity = 1 }
	local T  = H.node{ relay = true, voltage = 200, capacity = 1e9 }
	local W2 = H.node{ conductor = true, ampacity = 1 }
	local S  = H.node{ source = true, voltage = 100, capacity = 1e9, energy = 1000, sourceEff = 1 }
	H.link(W, T); H.link(T, W2); H.link(W2, S)

	local list = GS.FindSources(W, opts())
	check(#list == 1, "exactly one source reachable")
	local rec = list[1]
	near(rec.entryVolt, 200, "load end carries the transformer's output voltage")
	near(rec.carryV[W],  200, "load-side wire is at 200 V")
	near(rec.carryV[W2], 100, "source-side wire is still at 100 V")

	local _, volt = GS.Pull(W, 10, opts())
	near(volt, 200, "Pull reports the transformed load-end voltage")
end
