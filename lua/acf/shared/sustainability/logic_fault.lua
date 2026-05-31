--- ACE Sustainability - Electrical fault logic (pure, no GMod globals).
--
-- Decides when a high-voltage node is a shock hazard and how bad its arc is.
-- A healthy, in-spec line is safe to stand near; danger is the consequence of
-- OVERLOAD (carrying more than its ampacity) or BATTLE/HEAT DAMAGE (a broken
-- node that is still connected to a live grid), or running a conductor above its
-- voltage rating. The entity layer feeds it a small state table and registers
-- the result with the (single, event-driven) fault manager - this module does
-- only the maths so it can be unit-tested.
-- @module logic_fault

local Fault = {}

local function clamp(v, lo, hi)
	if v < lo then return lo elseif v > hi then return hi end
	return v
end

Fault.ArcVoltage  = 20      -- below this voltage a fault is harmless to players
Fault.RadiusPerV  = 1.2     -- arc reach (source units) per volt above the threshold
Fault.MinRadius   = 16      -- a live fault always at least reaches touching range
Fault.MaxRadius   = 220
Fault.DamagePerV  = 0.45    -- damage/sec contribution per volt
Fault.DamagePerKW = 0.20    -- damage/sec contribution per kW of fault current
Fault.MinDamage   = 6
Fault.MaxDamage   = 90

-- Short circuit: a near-resistanceless fault current. Two ways it happens here:
--  1) A conductor bridges two energised nodes whose VOLTAGES differ by more than
--     ShortVoltageDiff (paralleling mismatched sources - a big potential across a
--     tiny wire resistance drives an enormous current), or
--  2) the current carried exceeds the node's ampacity by ShortFactor (a dead
--     short downstream).
-- A short dumps ShortHeatJPerKW joules per kW of fault current per second into the
-- conductor (so it heats almost instantly) and should trip any breaker in the path.
Fault.ShortVoltageDiff = 8      -- volts of spread across one conductor that counts as a short
Fault.ShortFactor      = 3      -- current above ampacity*this = a short
Fault.ShortHeatJPerKW  = 240    -- heat (J/s) per kW of fault current while shorted
Fault.ShortMaxCurrentX = 12     -- fault current is capped at ampacity*this (avoid runaway numbers)

--- Is this node currently a shock hazard?
-- @param s table { voltage, broken, energized, overCurrent, breakdown }
--   voltage     - operating/carried voltage
--   broken      - true if the node is damaged/tripped
--   energized   - true if a live source is reachable through the grid
--   overCurrent - kW carried ABOVE capacity (>0 = overloaded)
--   breakdown   - over-voltage stress (>0 = run above its voltage rating)
-- @return boolean
function Fault.IsHazard(s)
	if (s.voltage or 0) < Fault.ArcVoltage then return false end
	if s.broken and s.energized then return true end          -- damaged live line arcs
	if (s.overCurrent or 0) > 0 and s.energized then return true end  -- overloaded
	if (s.breakdown or 0) > 0 and s.energized then return true end    -- over its voltage rating
	return false
end

--- Arc reach and damage/sec for a hazardous node.
-- @param s table same state as IsHazard (voltage + currentKW)
-- @return table { radius, damagePerSec }
function Fault.Arc(s)
	local v   = math.max(s.voltage or 0, 0)
	local cur = math.max(s.currentKW or 0, 0)

	local radius = clamp((v - Fault.ArcVoltage) * Fault.RadiusPerV, 0, Fault.MaxRadius)
	if radius < Fault.MinRadius then radius = Fault.MinRadius end

	-- High voltage is dangerous on its own; more current carried = nastier arc.
	-- Over-current and breakdown amplify it.
	local dmg = v * Fault.DamagePerV + cur * Fault.DamagePerKW
	if (s.overCurrent or 0) > 0 then dmg = dmg + (s.overCurrent or 0) * Fault.DamagePerKW end
	if (s.breakdown or 0) > 0 then dmg = dmg * (1 + (s.breakdown or 0)) end
	dmg = clamp(dmg, Fault.MinDamage, Fault.MaxDamage)

	return { radius = radius, damagePerSec = dmg }
end

--- Detect a short circuit across a conductor.
-- @param s table {
--   energized    - true if any neighbour is live,
--   voltageSpread- max neighbour voltage minus min neighbour voltage,
--   capacityKW   - the conductor's power capacity (ampacity*voltage),
--   currentKW    - power actually being driven through it }
-- @return boolean shorted, number faultCurrentKW (the runaway current), number heatJPerSec,
--   string cause ("volt" = bolted potential-mismatch fault, trip instantly;
--   "amp" = over-current overload, protection time-delays it; nil = no short)
function Fault.Short(s)
	if not s.energized then return false, 0, 0, nil end
	local spread = s.voltageSpread or 0
	local cap    = s.capacityKW or 0
	local cur    = math.max(s.currentKW or 0, 0)

	local byVolt = spread >= Fault.ShortVoltageDiff
	local byAmp  = cap > 0 and cur > cap * Fault.ShortFactor
	if not (byVolt or byAmp) then return false, 0, 0, nil end

	-- Fault current: a voltage-spread short is driven by the potential difference
	-- across the wire's (small) resistance; we approximate it as a large multiple
	-- of capacity, capped so the numbers stay sane.
	local faultKW = math.max(cur, cap * Fault.ShortFactor)
	if byVolt then faultKW = math.max(faultKW, cap * Fault.ShortFactor, cap + spread) end
	if cap > 0 then faultKW = math.min(faultKW, cap * Fault.ShortMaxCurrentX) end

	-- A bolted (voltage-mismatch) fault is the worst kind - report it as the cause
	-- so the protection trips instantly; a pure over-current is delayed (inverse-time).
	return true, faultKW, faultKW * Fault.ShortHeatJPerKW, byVolt and "volt" or "amp"
end

return Fault
