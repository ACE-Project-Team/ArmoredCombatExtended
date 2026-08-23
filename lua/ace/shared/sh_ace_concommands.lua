AddCSLuaFile()

if SERVER then

	concommand.Add( "ace_debris_clear", function(ply)

		if IsValid(ply) and not ply:IsAdmin() then return end

		if not table.IsEmpty(ACE.Debris) then
			for _, debris in ipairs(ACE.Debris) do
				if IsValid(debris) then
					debris:Remove()
				end
			end
		end

	end)

	concommand.Add( "ace_mines_clear", function(ply)

		if IsValid(ply) and not ply:IsAdmin() then return end

		if next(ACE.Mines) then
			for _, mine in ipairs(ACE.Mines) do
				if IsValid(mine) then
					mine:Remove()
				end
			end
		end

	end)

	concommand.Add( "ace_mines_explode_all", function(ply)

		if IsValid(ply) and not ply:IsSuperAdmin() then return end

		if next(ACE.Mines) then
			for _, mine in ipairs(ACE.Mines) do
				if IsValid(mine) then
					mine:Detonate()
				end
			end
		end

	end)
end

