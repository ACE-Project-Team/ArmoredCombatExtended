
AddCSLuaFile()

local GunsTable = ACE.Weapons.Guns

function ACE.GetGunValue(bdata, val)

	bdata = (type(bdata) == "table" and bdata.Id) or bdata

	local guns = GunsTable
	local class = guns[bdata]

	if class then
		local ret

		if class.round then
			ret = class.round[val]
		end

		if ret == nil then
			ret = class[val]
		end

		if ret ~= nil then
			return ret
		else
			local classes = ACE.Classes.GunClass
			class = classes[class.gunclass]

			if class then
				return class[val]
			end
		end
	end

end





function ACE.GetRackValue(rdata, val)

	rdata = (type(rdata) == "table" and rdata.Id) or rdata

	local guns = ACE.Weapons.Racks
	local class = guns[rdata]

	if class then
		if class[val] ~= nil then
			return class[val]
		else
			local classes = ACE.Classes.Rack
			class = classes[class.gunclass]

			if class then
				return class[val]
			end
		end
	end

end




function ACE.RackCanLoadCaliber(rackId, cal)

	local rack = ACE.Weapons.Racks[rackId]
	if not rack then return false, "Rack '" .. tostring(rackId) .. "' does not exist." end

	if rack.caliber then
		local ret = (rack.caliber == cal)
		if ret then return true, ""
		else return false, "Only " .. math.Round(rack.caliber * 10, 2) .. "mm rounds can fit in this gun." end
	end

	if rack.mincaliber and cal < rack.mincaliber then
		return false, "Rounds must be at least " .. math.Round(rack.mincaliber * 10, 2) .. "mm to fit in this gun."
	end

	if rack.maxcaliber and cal > rack.maxcaliber then
		return false, "Rounds cannot be more than " .. math.Round(rack.maxcaliber * 10, 2) .. "mm to fit in this gun."
	end

	return true

end




function ACE.CanLinkRack(rackId, ammoId, bdata, rack)

	local rack = ACE.Weapons.Racks[rackId]
	if not rack then return false, "Rack '" .. tostring(rackId) .. "' does not exist." end

	local gun = GunsTable[ammoId]
	if not rack then return false, "Ammo '" .. tostring(ammoId) .. "' does not exist." end


	local rackAllow = ACE.GetGunValue(ammoId, "racks")

	local rackAllowed = true
	local allowType = type(rackAllow)

	if rackAllow == nil and rack.whitelistonly then
		rackAllowed = false
	elseif allowType == "table" then
		rackAllowed = rackAllow[rackId]
	elseif allowType == "function" then
		rackAllowed = rackAllow(bdata or ammoId, rack or rackId)
	end

	if not rackAllowed then
		return false, ammoId .. " rounds are not compatible with a " .. tostring(rackId) .. "!"
	end


	local canCaliber, calMsg = ACE.RackCanLoadCaliber(rackId, gun.caliber)
	if not canCaliber then
		return false, calMsg
	end

	local Classes = ACE.Classes.GunClass
	if "missile" ~= Classes[gun.gunclass].type then
		return false, "Racks cannot be linked to ammo crates of type '" .. tostring(ammoId) .. "'!"
	end

	return true

end




function ACE.GetCompatibleRacks(ammoId)

	local ret = {}

	for rackId in pairs(ACE.Weapons.Racks) do
		if ACE.CanLinkRack(rackId, ammoId) then
			ret[#ret + 1] = rackId
		end
	end

	return ret

end




function ACE.GetRoundFromCVars()

	local round = {}

	round.Id = GetConVar("acemenu_data1"):GetString()
	round.Type = GetConVar("acemenu_data2"):GetString()
	round.PropLength = GetConVar("acemenu_data3"):GetFloat()
	round.ProjLength = GetConVar("acemenu_data4"):GetFloat()
	round.Data5 = GetConVar("acemenu_data5"):GetFloat()
	round.Data6 = GetConVar("acemenu_data6"):GetFloat()
	round.Data7 = GetConVar("acemenu_data7"):GetString()
	round.Data8 = GetConVar("acemenu_data8"):GetString()
	round.Data9 = GetConVar("acemenu_data9"):GetString()
	round.Data10 = GetConVar("acemenu_data10"):GetFloat()
	round.Data11 = GetConVar("acemenu_data11"):GetFloat()
	round.Data12 = GetConVar("acemenu_data12"):GetFloat()
	round.Data13 = GetConVar("acemenu_data13"):GetFloat()
	round.Data14 = GetConVar("acemenu_data14"):GetFloat()
	round.Data15 = GetConVar("acemenu_data15"):GetFloat()

	return round

end
