include("shared.lua")

function ENT:Draw()
	self:DoNormalDraw(false, false)
	Wire_Render(self)
end

hook.Add("PostDrawHalos", "ACE_APSNetworkHalos", function()
	local trace = LocalPlayer():GetEyeTrace()
	local entity = trace.Entity
	if not IsValid(entity) then return end

	local encoded = entity:GetNW2String("ACEAPSNetworkEntities", "")
	if encoded == "" then return end

	local highlighted = {}
	for id in string.gmatch(encoded, "%d+") do
		local target = Entity(tonumber(id))
		if IsValid(target) then
			highlighted[#highlighted + 1] = target
		end
	end

	if #highlighted > 0 then
		halo.Add(highlighted, Color(0, 255, 128), 2, 2, 1, true, true)
	end
end)
