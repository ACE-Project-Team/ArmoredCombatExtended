local root = assert(arg[1], "usage: ace_bullet_filter_selftest.lua <ACE repo>")

CLIENT = false
CFW = { Classes = { Contraption = {} } }
util = { TraceLine = function() end }

local hooks = {}
hook = {
    Add = function(name, identifier, callback)
        hooks[name] = hooks[name] or {}
        hooks[name][identifier] = callback
    end
}

function IsValid(entity)
    return entity ~= nil and entity.valid ~= false
end

local function entity(class)
    return { class = class, GetClass = function(self) return self.class end }
end

dofile(root .. "/lua/cfw/extensions/ace_sv.lua")

local contraption = {}
hooks["cfw.contraption.created"].CFW_ACE_BulletFilter(contraption)

local hull = entity("prop_physics")
local gun = entity("acf_gun")
hooks["cfw.contraption.entityAdded"].CFW_ACE_Entities(contraption, hull)
hooks["cfw.contraption.entityAdded"].CFW_ACE_Entities(contraption, gun)

assert(contraption.BulletFilter[1] == hull)
assert(contraption.BulletFilter[2] == gun)

local shotFilter = {}
for index, value in ipairs(contraption.BulletFilter) do
    shotFilter[index] = value
end

hooks["cfw.contraption.entityRemoved"].CFW_ACE_BulletFilter(contraption, hull)
assert(#contraption.BulletFilter == 1)
assert(contraption.BulletFilter[1] == gun)
assert(shotFilter[1] == hull)
assert(shotFilter[2] == gun)

print("ACE bullet filter LuaJIT self-test: PASS")
