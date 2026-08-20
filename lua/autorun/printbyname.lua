local function mixedcompare(a, b)
	if type(a) == type(b) then return a < b end

	local ca = tonumber(a)
	if not ca then return tostring(a) < tostring(b) end

	local cb = tonumber(b)
	if not cb then return tostring(a) < tostring(b) end

	return ca < cb
end



function ACE.PairsByKeys(t, f)
	if not t then
		return function() end
	end

	local a = {}

	for n in pairs(t) do
		table.insert(a, n)
	end

	table.sort(a, f or mixedcompare)

	local i = 0	-- iterator variable
	local iter = function ()	-- iterator function
		i = i + 1
		if a[i] == nil then
			return nil
		else
			return a[i], t[a[i]]
		end
	end

	return iter
end


pairsByName = ACE.PairsByKeys



function ACE.PrintByName(tbl)
	for k, v in ACE.PairsByKeys(tbl) do
		Msg(tostring(k), "\t", "\t", tostring(v), "\n")
	end

	plst = tbl -- reference!

	if pbnTrace then
		debug.Trace()
	end
end

pbn = ACE.PrintByName



function ACE.PrintByNameTable(tbl, name)
	local typ = nil
	local typ2 = nil
	local vstr = nil

	for k, v in ACE.PairsByKeys(tbl) do
		typ = type(k)
		typ2 = type(v)
		vstr = typ2 == "string" and "\"" .. v .. "\"" or tostring(v)

		if typ == "string" then
			Msg(name, "[\"", tostring(k), "\"]\t\t\t= ", vstr, "\n")
		elseif typ == "number" then
			Msg(name, "[", tostring(k), "]\t\t\t= ", vstr, "\n")
		else -- can't really do these
			Msg(name, ": ", tostring(k), "\t\t\t= ", vstr, "\n")
		end
	end

	plst = tbl -- reference!
end

pbnt = ACE.PrintByNameTable
