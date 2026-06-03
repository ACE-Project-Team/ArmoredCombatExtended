--- Test helpers for the pure ACE sustainability logic.
--
-- Loads a pure logic module by name from the addon's sustainability folder, and
-- provides a tiny mock-node factory so the grid solver can be exercised with
-- plain Lua tables (no GMod). A "node" duck-types what logic_gridsolve expects:
-- GridStations + the role methods + Voltage/Ampacity/GridCapacity + DrawEnergy.

local H = {}

local MODULE_DIR = _G.ACE_MODULE_DIR or "../lua/acf/shared/sustainability/"

--- dofile a pure logic module by bare name (e.g. "logic_gridsolve").
function H.load(name)
	local chunk, err = loadfile(MODULE_DIR .. name .. ".lua")
	if not chunk then error("could not load module '" .. name .. "': " .. tostring(err)) end
	return chunk()
end

-- Mock-node prototype. Flags/numbers come from the spec; the methods read them.
local Node = {}
Node.__index = Node

function Node:Offline()       return self._offline == true end   -- offline relays/transformers can't conduct
function Node:IsConductor()   return self._conductor == true end
function Node:IsSource()      return self._source == true end
function Node:IsRelay()       return self._relay == true end
function Node:GridHasEnergy() return (self.Energy or 0) > 0 end
function Node:GridCapacity()  return self._capacity or 0 end
function Node:GridSourcePriority() return self._priority or 0 end

-- Draw up to `need` kWh from this source's store, applying its discharge eff the
-- way the real battery does (the grid grosses the request up to compensate).
function Node:DrawEnergy(need)
	local avail = self.Energy or 0
	local give  = math.min(need, avail / (self.GridSourceEff or 1))
	if give <= 0 then return 0 end
	self.Energy = avail - give * (self.GridSourceEff or 1)
	return give
end

local _id = 0

--- Build a mock node. spec keys:
--   conductor/source/relay (bool roles), voltage, ampacity (conductor cap=amp*V),
--   capacity (non-conductor kW cap), energy (source store kWh), priority (tier),
--   sourceEff (discharge eff). name is for readable assertion messages.
function H.node(spec)
	spec = spec or {}
	_id = _id + 1
	return setmetatable({
		name          = spec.name or ("n" .. _id),
		id            = _id,
		GridStations  = {},
		_offline      = spec.offline or false,
		_conductor    = spec.conductor or false,
		_source       = spec.source or false,
		_relay        = spec.relay or false,
		_capacity     = spec.capacity,
		_priority     = spec.priority,
		Voltage       = spec.voltage,
		Ampacity      = spec.ampacity,
		Energy        = spec.energy,
		GridSourceEff = spec.sourceEff,
	}, Node)
end

--- Undirected link between two nodes (each appears in the other's GridStations).
function H.link(a, b)
	a.GridStations[#a.GridStations + 1] = b
	b.GridStations[#b.GridStations + 1] = a
end

return H
