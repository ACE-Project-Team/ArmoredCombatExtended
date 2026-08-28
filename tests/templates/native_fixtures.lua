-- Shared native fixture prototype for ACE GLuaTest groups.
-- The mounted implementation lives in lua/ace/test_fixtures.lua so the DSL runtime can load it.
local Fixtures = {}

function Fixtures.Entity(State, className, configure)
	local entity = ents.Create(className)
	assert(IsValid(entity), "could not create " .. className)

	entity:SetPos(Vector(0, 0, 64))
	if configure then configure(entity) end
	entity:Spawn()

	State.Entities = State.Entities or {}
	State.Entities[#State.Entities + 1] = entity
	return entity
end

function Fixtures.Contraption(State, create)
	local contraption = create()
	assert(contraption, "contraption fixture did not return a contraption")

	State.Contraptions = State.Contraptions or {}
	State.Contraptions[#State.Contraptions + 1] = contraption
	return contraption
end

function Fixtures.Cleanup(State)
	for _, contraption in ipairs(State.Contraptions or {}) do
		if contraption.Remove then contraption:Remove() end
	end

	for _, entity in ipairs(State.Entities or {}) do
		if IsValid(entity) then entity:Remove() end
	end
end

return Fixtures
