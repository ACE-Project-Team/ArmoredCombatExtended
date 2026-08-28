-- Reusable native fixture helpers for ACE GLuaTest groups.
-- Keep real GMod setup here; individual tests should only name the fixture they need.
local Fixtures = {}
local factoryArgs
local HeadlessOwnershipShims = {
	CPPISetOwner = function(entity, owner) entity._TestCPPIOwner = owner end,
	CPPIGetOwner = function(entity) return entity._TestCPPIOwner end,
	UniqueID = function(entity) return "ACE_HEADLESS_" .. entity:EntIndex() end,
	CheckLimit = function() return true end,
	AddCount = function() end,
	AddCleanup = function() end,
	GetInfo = function() return "0" end,
	GetInfoNum = function(_, _, default) return default or 0 end,
	Nick = function() return "ACE headless owner" end,
	SteamID64 = function() return "0" end,
}

local function append(State, Name, Value)
	State[Name] = State[Name] or {}
	State[Name][#State[Name] + 1] = Value
	return Value
end

local function sorted(list)
	table.sort(list)
	return list
end

local function firstKey(registry)
	local keys = {}
	for key in pairs(registry or {}) do keys[#keys + 1] = key end
	return sorted(keys)[1]
end

function Fixtures.Entity(State, className, configure)
	local entity = ents.Create(className)
	assert(IsValid(entity), "could not create " .. className)

	entity:SetPos(Vector(0, 0, 64))
	if configure then configure(entity) end
	entity:Spawn()

	append(State, "Entities", entity)
	return entity
end

function Fixtures.EnsureHeadlessOwnership(State)
	local entityMeta = FindMetaTable("Entity")
	-- Dedicated servers do not have a CPPI provider. Keep this shim test-local so
	-- factory paths exercise their real ownership calls without requiring an addon.
	-- Factory owners are real Entity userdata on a dedicated server, so methods
	-- assigned to one instance are not reliable across all server builds. Supply
	-- only the missing player/toolgun surface needed by the test owner.
	if not entityMeta then return end
	if State then State.HeadlessOwnershipInstalled = State.HeadlessOwnershipInstalled or {} end
	for Name, Shim in pairs(HeadlessOwnershipShims) do
		if not entityMeta[Name] then
			entityMeta[Name] = Shim
			if State then State.HeadlessOwnershipInstalled[Name] = true end
		end
	end
end

function Fixtures.RestoreHeadlessOwnership(State)
	if not State or not State.HeadlessOwnershipInstalled then return end

	local entityMeta = FindMetaTable("Entity")
	if entityMeta then
		for Name in pairs(State.HeadlessOwnershipInstalled) do entityMeta[Name] = nil end
	end

	State.HeadlessOwnershipInstalled = nil
end

function Fixtures.Owner(State)
	Fixtures.EnsureHeadlessOwnership(State)

	local owner = Fixtures.Entity(State, "prop_physics", function(entity)
		entity:SetModel("models/props_c17/oildrum001.mdl")
	end)

	return owner
end

function Fixtures.EntityClasses()
	local _, folders = file.Find("entities/*", "LUA")
	local classes = {}

	for _, className in ipairs(folders) do
		if className:match("^ace_") or className:match("^acf_") then
			classes[#classes + 1] = className
		end
	end

	return sorted(classes)
end

function Fixtures.StoredEntity(className)
	local stored = scripted_ents.GetStored(className)
	assert(istable(stored) and istable(stored.t), "missing scripted entity " .. className)
	return stored
end

function Fixtures.EntityMethods(className)
	local methods = {}
	local seen = {}
	local stored = Fixtures.StoredEntity(className)

	while istable(stored) and not seen[stored] do
		seen[stored] = true
		for name, value in pairs(stored.t or {}) do
			if isfunction(value) and not table.HasValue(methods, name) then methods[#methods + 1] = name end
		end

		local base = stored.Base or stored.BaseClass
		stored = isstring(base) and scripted_ents.GetStored(base) or base
	end

	return sorted(methods)
end

function Fixtures.RegisteredDupeClasses()
	local registrations = {}

	for _, className in ipairs(Fixtures.EntityClasses()) do
		local registration = duplicator.FindEntityClass(className)
		if registration then
			registrations[#registrations + 1] = {
				class = className,
				factory = registration.Func,
			}
		end
	end

	return registrations
end

function Fixtures.SpawnAll(State)
	local report = {}
	local origin = Vector(0, 0, 64)
	local owner = State.FullModOwner
	if not IsValid(owner) then error("full-mod fixture owner is invalid", 0) end

	for index, className in ipairs(Fixtures.EntityClasses()) do
		local row = { class = className, methods = Fixtures.EntityMethods(className) }
		local registration = duplicator.FindEntityClass(className)
		local created, entity
		local factorySpawned = false

		if className == "ace_missile" then
			row.skipped = true
			row.skip_reason = "projectile is created by a rack launch"
		elseif className == "ace_mine" then
			created, entity = pcall(function()
				-- Entity init files are lazy-loaded by ents.Create on dedicated servers;
				-- preload the class before resolving its server-side factory.
				if not isfunction(ACE.CreateMine) then
					local preload = ents.Create(className)
					if IsValid(preload) then
						preload:Spawn()
						preload:Remove()
					end
				end
				if not isfunction(ACE.InitializePlayerMineCounter) or not isfunction(ACE.CreateMine) then
					error("mine factory is unavailable", 0)
				end

				ACE.InitializePlayerMineCounter(owner)
				return ACE.CreateMine(firstKey(ACE.MineData), origin + Vector(index * 32, 0, 0), Angle(0, 0, 0), owner)
			end)
			row.created = created and IsValid(entity)
			row.spawn_mode = "factory"
			factorySpawned = true
		elseif registration then
			created, entity = pcall(function()
				local args = factoryArgs(className)
				return registration.Func(owner, origin + Vector(index * 32, 0, 0), Angle(0, 0, 0), unpack(args))
			end)
			row.created = created and IsValid(entity)
			row.spawn_mode = "factory"
		else
			created, entity = pcall(ents.Create, className)
			row.created = created and IsValid(entity)
		end

		if row.created then
			if IsValid(entity) then
				append(State, "Entities", entity)
				if not registration and not factorySpawned then
					entity:SetPos(origin + Vector(index * 32, 0, 0))
					local spawned, spawnError = pcall(entity.Spawn, entity)
					row.spawned = spawned
					row.spawn_error = spawned and nil or tostring(spawnError)
					if spawned then
						local activated, activateError = pcall(entity.Activate, entity)
						row.activated = activated
						row.activate_error = activated and nil or tostring(activateError)
					end
				end
			end
		elseif not row.skipped then
			row.spawn_error = tostring(entity)
		end

		report[#report + 1] = row
	end

	return report
end

-- These are the entity methods whose contracts are meaningful with only a live entity.
-- Methods requiring gameplay-specific values remain visible in the report until an adapter is
-- added; the fixture never calls them with invented nil arguments.
function Fixtures.SafeLifecycleMethods(className)
	-- Think and dupe callbacks are not universally safe on a bare entity. Many ACE
	-- entities require factory-populated model, weapon, or radar data before those
	-- callbacks can run. Keep the full method inventory visible, and only invoke
	-- callbacks for entities with a valid adapter here.
	if className == "ace_scalability" then
		return {
			OnDuplicated = function(entity) return entity:OnDuplicated({}) end,
		}
	end

	return {}
end

function Fixtures.ExerciseSafeMethods(State, report)
	local exercised = {}
	local uncovered = {}

	for _, row in ipairs(report) do
		local entity
		for _, candidate in ipairs(State.Entities) do
			if IsValid(candidate) and candidate:GetClass() == row.class then
				entity = candidate
				break
			end
		end

		local adapters = Fixtures.SafeLifecycleMethods(row.class)
		for _, methodName in ipairs(row.methods) do
			local adapter = adapters[methodName]
			if adapter and IsValid(entity) then
				local ok, errorMessage = pcall(adapter, entity)
				row[methodName] = { called = true, ok = ok, error = ok and nil or tostring(errorMessage) }
				exercised[#exercised + 1] = row.class .. ":" .. methodName
			elseif not adapter then
				uncovered[#uncovered + 1] = row.class .. ":" .. methodName
			end
		end
	end

	return { exercised = exercised, uncovered = uncovered }
end

local function registryId(registry, className)
	for id, definition in pairs(registry or {}) do
		if definition.ent == className then return id end
	end
end

factoryArgs = function(className)
	if className == "ace_bomb_aerial" or className == "ace_bomb_barrel" or className == "ace_bomb_satchel" then return {} end
	if className == "ace_crewseat_driver" then return { "Crewseat_Driver", "Sitting" } end
	if className == "ace_crewseat_gunner" then return { "Crewseat_Gunner", "Sitting" } end
	if className == "ace_crewseat_loader" then return { "Crewseat_Loader", "Sitting" } end
	if className == "acf_engine" then return { "0.8L-I2" } end
	if className == "acf_gearbox" then return { "1Gear-T-S", 0.1, 0.2, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8, 0.9, 0.5 } end
	if className == "acf_fueltank" then return { "Tank_4x4x2", "Tank_4x4x2", "Petrol", "Box" } end
	if className == "acf_gun" then return { "100mmC" } end
	if className == "acf_ammo" then return { "Shell100mm", "100mmC", "AP", 10, 15 } end
	if className == "acf_rack" then return { "1x BGM-71E" } end
	if className == "acf_missileradar" then return { "SmallDIR-AM" } end
	if className == "acf_missile_to_rack" then return { "BGM-71E ASM", "1x BGM-71E" } end
	if className == "ace_searchradar" then return { "Small-SEARCH" } end
	if className == "ace_trackingradar" then return { "Small-TRACK" } end
	if className == "ace_irst" then return { "Small-IRST" } end
	if className == "ace_sonar" then return { "Tiny-Sonar" } end
	if className == "ace_wind_sensor" then return { "WindSensor" } end
	if className == "ace_gforce_meter" then return { "GForceMeter" } end
	if className == "ace_vheat_source" then return { registryId(ACE.Weapons and ACE.Weapons.Tools, className) } end
	if className == "ace_explosive" then return { firstKey(ACE.Weapons and ACE.Weapons.Explosives), "5:5:5", "Box" } end
	if className == "acf_explosive" then
		return { "100mmC", "AP", 10, 15, 0, 0, 0, 0, 0, 0, "models/props_c17/oildrum001.mdl" }
	end
	return {}
end

function Fixtures.FullMod(State)
	local Coverage = { schema = 1, entity_classes = Fixtures.EntityClasses() }
	ACE_FullModFixtureCoverage = Coverage

	for _, className in ipairs(Coverage.entity_classes) do
		Fixtures.StoredEntity(className)
	end

	local owner = Fixtures.Owner(State)
	Coverage.owner_valid = IsValid(owner)
	if not Coverage.owner_valid then error("full-mod fixture owner is invalid", 0) end
	State.FullModOwner = owner
	Coverage.spawn_report = Fixtures.SpawnAll(State)
	for _, row in ipairs(Coverage.spawn_report) do
		if not row.skipped and (not row.created or (row.spawn_mode ~= "factory" and (not row.spawned or not row.activated))) then
			error("entity " .. row.class .. " lifecycle failed: " .. tostring(row.spawn_error or row.activate_error), 0)
		end
	end

	Coverage.method_report = Fixtures.ExerciseSafeMethods(State, Coverage.spawn_report)
	for _, row in ipairs(Coverage.spawn_report) do
		for methodName, result in pairs(row) do
			if istable(result) and result.called and not result.ok then
				error("entity " .. row.class .. " method " .. methodName .. " failed: " .. tostring(result.error), 0)
			end
		end
	end

	Coverage.dupe_classes = {}
	for index, registration in ipairs(Fixtures.RegisteredDupeClasses()) do
		local args = factoryArgs(registration.class)
		local called, entity = pcall(registration.factory, owner, Vector(index * 32, 128, 64), Angle(0, 0, 0), unpack(args))
		if not (called and IsValid(entity)) then
			error("dupe factory " .. registration.class .. " failed: " .. tostring(entity), 0)
		end
		Coverage.dupe_classes[#Coverage.dupe_classes + 1] = registration.class
		append(State, "Entities", entity)
	end

	Coverage.ok = #Coverage.entity_classes > 0 and #Coverage.spawn_report == #Coverage.entity_classes
		and #Coverage.dupe_classes > 0 and #Coverage.method_report.exercised > 0
	return Coverage
end

function Fixtures.Contraption(State, create)
	local contraption = create()
	assert(contraption, "contraption fixture did not return a contraption")

	State.Contraptions = State.Contraptions or {}
	State.Contraptions[#State.Contraptions + 1] = contraption
	return contraption
end

function Fixtures.Cleanup(State)
	for _, entity in ipairs(State.Entities or {}) do
		if IsValid(entity) then entity:Remove() end
	end

	for _, contraption in ipairs(State.Contraptions or {}) do
		if contraption.Remove and not contraption._removed then contraption:Remove() end
	end
end

return Fixtures
