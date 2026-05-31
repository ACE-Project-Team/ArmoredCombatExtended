--- ACE Sustainability - Pipe wear logic (pure, no GMod globals).
--
-- A pipe links two fuel sockets and moves fuel/charge between their tanks over
-- any distance. It wears very slowly while in use: as its condition (0..1)
-- drops, throughput falls, then it starts leaking, and finally it breaks and
-- stops carrying anything until repaired (with the ACE torch, which restores
-- the underlying ACF health this condition is derived from).
-- @module logic_pipe

local Pipe = {}

local function clamp(v, lo, hi)
	if v < lo then return lo elseif v > hi then return hi end
	return v
end

Pipe.FullFlowAbove = 0.5    -- condition at/above which flow is unimpeded
Pipe.LeakBelow     = 0.30   -- condition under which it starts leaking
Pipe.MaxLeak       = 0.5    -- worst-case fraction of throughput lost to leaks

-- Bore (cross-section) sets capacity and friction, IRL-style: a wider pipe
-- carries more and resists less per unit length.
Pipe.FlowPerArea   = 0.04   -- L/s carried per square-inch of bore cross-section
Pipe.FrictionK     = 0.01   -- friction tuning: loss-per-unit-distance = FrictionK / boreArea
Pipe.MaxFriction   = 0.85   -- a single hop can never lose more than this to friction

--- Flow capacity and per-unit friction for a pipe of a given bore area.
-- @param boreArea number cross-section in square inches (W*H of the segment)
-- @return table { flowCap = L/s, frictionPerUnit = fraction lost per source unit }
function Pipe.Bore(boreArea)
	boreArea = math.max(boreArea or 1, 1)
	return {
		flowCap         = boreArea * Pipe.FlowPerArea,
		frictionPerUnit = Pipe.FrictionK / boreArea,
	}
end

--- Friction loss over one hop of a given distance through a given bore.
-- @return number 0..MaxFriction
function Pipe.HopFriction(distance, boreArea)
	local b = Pipe.Bore(boreArea)
	return clamp(b.frictionPerUnit * math.max(distance or 0, 0), 0, Pipe.MaxFriction)
end

--- Operating state for a given condition.
-- @param condition number 0..1 (1 = pristine, 0 = broken)
-- @return table { flowMult = 0..1, leakFrac = 0..1, broken = bool }
function Pipe.State(condition)
	condition = clamp(condition or 0, 0, 1)

	local broken = condition <= 0
	local flowMult = clamp(condition / Pipe.FullFlowAbove, 0, 1)

	local leakFrac = 0
	if condition < Pipe.LeakBelow then
		leakFrac = (Pipe.LeakBelow - condition) / Pipe.LeakBelow * Pipe.MaxLeak
	end

	return { flowMult = flowMult, leakFrac = leakFrac, broken = broken }
end

--- Advance condition by wear. Pipes only age while actually carrying flow, and
-- very slowly, so they last a long time before needing a torch.
-- @param condition number current condition (0..1)
-- @param decayPerSec number condition lost per second while active
-- @param dt number timestep (s)
-- @param active boolean whether the pipe is transferring this step
-- @return number new condition, clamped to >= 0
function Pipe.Decay(condition, decayPerSec, dt, active)
	condition = condition or 1
	if not active then return condition end
	return math.max(0, condition - (decayPerSec or 0) * (dt or 0))
end

return Pipe
