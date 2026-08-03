
local ClassName = "Dumb"


ACE = ACE or {}
ACE.Guidance = ACE.Guidance or {}

local this = ACE.Guidance[ClassName] or inherit.NewBaseClass()
ACE.Guidance[ClassName] = this

---

this.Name = ClassName

this.desc = "This guidance package is empty and provides no control."

-- an object containing an obj:GetGuidanceOverride(missile, guidance) function
this.Override = nil

this.AppliedSpawnCountermeasures = false


function this:Init()
end

function this:Configure()
end


function this:GetGuidance(missile)

	self:PreGuidance(missile)
	return self:ApplyOverride(missile) or {}
end

function this:PreGuidance(_) --missile

end


function this:ApplyOverride()
end


function this:GetDisplayConfig()
	return {}
end
