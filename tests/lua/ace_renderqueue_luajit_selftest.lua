local root = assert(arg[1], "usage: ace_renderqueue_luajit_selftest.lua <ACE repo>")
root = root:gsub("\\\\", "/"):gsub("/$", "")

CLIENT = false
local now = 0
local hooks = {}
local broadcasts = 0

hook = {
	Add = function(name, identifier, callback)
		hooks[name] = hooks[name] or {}
		hooks[name][identifier] = callback
	end,
	Remove = function(name, identifier)
		if hooks[name] then hooks[name][identifier] = nil end
	end,
}

function CurTime() return now end
function IsValid(entity) return entity and entity.valid == true end

net = {
	Start = function() end,
	WriteUInt = function() end,
	WriteFloat = function() end,
	Broadcast = function() broadcasts = broadcasts + 1 end,
}

dofile(root .. "/lua/ace/server/sv_ace_renderqueue.lua")
assert(ACE.SchedulerAdapterDefinitions["ACE.RenderPropDamage"], "render adapter was not retained before scheduler load")
assert(ACE.UpdateVisualHealth == ACE_UpdateVisualHealth, "ACE visual-health entry point was not preserved")
assert(ACE.SendVisualDamage == ACE_SendVisualDamage, "ACE visual-damage entry point was not preserved")
dofile(root .. "/lua/ace/server/sv_ace_scheduler.lua")
local scheduler = ACE.Scheduler
assert(scheduler.Adapters["ACE.RenderPropDamage"], "render adapter was not registered after scheduler load")

local function entity(id)
	local value = { id = id, valid = true, ACF = { MaxHealth = 100, Health = 50 } }
	function value:IsValid() return self.valid end
	function value:EntIndex() return self.id end
	return value
end

local first = entity(1)
local second = entity(2)

ACE_UpdateVisualHealth(first)
assert(scheduler.GetNode("ACE.RenderPropDamage") == nil, "disabled scheduler attached render work")
assert(hooks.Think.ACE_RenderPropDamage, "legacy render hook was not retained while disabled")
hooks.Think.ACE_RenderPropDamage()
assert(broadcasts == 1 and first.ACF.OnRenderQueue == nil, "legacy render path did not dispatch")

scheduler.Enable()
assert(not hooks.Think.ACE_RenderPropDamage, "legacy render hook remained after scheduler enable")
now = 0.001
ACE_UpdateVisualHealth(first)
ACE_UpdateVisualHealth(first)
ACE_UpdateVisualHealth(second)
assert(scheduler.GetSize() == 1, "render queue did not coalesce to one heap node")
assert(scheduler.Run(now).Ran == 1 and broadcasts == 2, "first scheduled render dispatch failed")
assert(scheduler.GetNode("ACE.RenderPropDamage") ~= nil, "remaining render work was not rescheduled")
now = 0.0015
assert(scheduler.Run(now).Ran == 0 and broadcasts == 2, "render cadence ran early")
now = 0.002
assert(scheduler.Run(now).Ran == 1 and broadcasts == 3, "render cadence did not dispatch the next entity")
assert(first.ACF.OnRenderQueue == nil and second.ACF.OnRenderQueue == nil, "render queue flags were not retired")
assert(scheduler.GetNode("ACE.RenderPropDamage") == nil, "empty render queue left stale heap work")

local invalid = entity(3)
invalid.valid = false
ACE_UpdateVisualHealth(invalid)
assert(scheduler.GetSize() == 1, "invalid render work did not attach a due node")
now = 0.003
assert(scheduler.Run(now).Ran == 1 and broadcasts == 3, "invalid render work emitted a packet")
assert(scheduler.GetNode("ACE.RenderPropDamage") == nil, "invalid render work left stale node")

scheduler.Disable()
assert(hooks.Think.ACE_RenderPropDamage, "legacy render hook was not restored on disable")

scheduler.Enable()
dofile(root .. "/lua/ace/server/sv_ace_renderqueue.lua")
assert(not hooks.Think.ACE_RenderPropDamage, "reload while enabled restored the legacy render hook")
scheduler.Disable()
assert(hooks.Think.ACE_RenderPropDamage, "legacy render hook was not restored after enabled reload")

scheduler.Enable()
local inFlight = entity(4)
local postReload = entity(5)
ACE_UpdateVisualHealth(inFlight)
dofile(root .. "/lua/ace/server/sv_ace_renderqueue.lua")
ACE_UpdateVisualHealth(postReload)
assert(scheduler.GetNode("ACE.RenderPropDamage") ~= nil, "reload stranded an in-flight render node")
now = now + 0.001
assert(scheduler.Run(now).Ran == 1 and broadcasts == 4, "reloaded render callback did not dispatch in-flight work")
now = now + 0.001
assert(scheduler.Run(now).Ran == 1 and broadcasts == 5, "post-reload render work was stranded")
assert(inFlight.ACF.OnRenderQueue == nil and postReload.ACF.OnRenderQueue == nil, "reloaded render flags were not retired")
scheduler.Disable()
assert(hooks.Think.ACE_RenderPropDamage, "legacy render hook was not restored after in-flight reload")
print("ACE render queue LuaJIT self-test: PASS")
