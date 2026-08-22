ACE = ACE or {}

-- ACE owns entity state. Keep the legacy ACF field as a live compatibility alias while
-- consumers migrate, so old dupes and external integrations cannot silently fork state.
function ACE.GetEntityState(Entity, Create)
    if not Entity then return end

    local state = Entity.ACE
    local legacy = Entity.ACF

    if not istable(state) and istable(legacy) then
        state = legacy
        Entity.ACE = state
    elseif istable(state) and legacy ~= state then
        Entity.ACF = state
    elseif not state and Create then
        state = {}
        Entity.ACE = state
        Entity.ACF = state
    end

    return state
end

function ACE.SetEntityState(Entity, State)
    if not Entity then return end
    if State ~= nil and not istable(State) then return end

    Entity.ACE = State
    Entity.ACF = State
    return State
end
