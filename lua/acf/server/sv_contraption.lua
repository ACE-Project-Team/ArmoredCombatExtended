--i'll leave almost everything ready so they can be exported to acf-3 in some near future
--print("[ACE | INFO]- Loading Contraption System. . .")
--ACE               = ACE or {}



ACE.contraptionEnts   = {} --table which will have all registered ents








ACE.critEnts          = {} --List of all critical entities in ACE. Used for HE penetration calculations.

ACE.contraptionEnts   = {} --table which will have all registered ents
ACE.radarEntities     = {} --for tracking radar usage
ACE.radarIDs          = {} --ID radar purpose
ACE.ECMPods           = {} --ECM usage
ACE.Opticals          = {} --GLATGM optical computers
ACE.Explosives        = {} --Explosive entities like ammocrates & fueltanks go here
ACE.Debris            = {} --Debris count
ACE.Crewseats         = {}
ACE.Mines             = ACE.Mines or {}
ACE.MineOwners  	  = ACE.MineOwners or {} -- We want to develop without losing any data inside of this.
ACE.ScalableEnts      = ACE.ScalableEnts or {}

--list of classname ents which should be added to the contraption ents.
local AllowedEnts = {
	["acf_rack"]                  = true,
	["prop_vehicle_prisoner_pod"] = true,
	["ace_crewseat_gunner"]       = true,
	["ace_crewseat_loader"]       = true,
	["ace_crewseat_driver"]       = true,
	["ace_rwr_dir"]               = true,
	["ace_rwr_sphere"]            = true,
	["acf_missileradar"]          = true,
	["acf_opticalcomputer"]       = true,
	["gmod_wire_expression2"]     = true,
	["gmod_wire_gate"]            = true,
	["prop_physics"]              = true,
	["ace_ecm"]                   = true,
	["ace_trackingradar"]         = true,
	["ace_searchradar"]           = true,
	["ace_irst"]                  = true,
	["ace_vheat_source"]          = true,
	["ace_gforce_meter"]          = true,
	["ace_wind_sensor"]           = true,
	["acf_gun"]                   = true,
	["acf_ammo"]                  = true,
	["acf_engine"]                = true,
	["acf_fueltank"]              = true,
	["acf_gearbox"]               = true,
	["primitive_shape"]           = true,
	["primitive_airfoil"]         = true,
	["primitive_rail_slider"]     = true,
	["primitive_slider"]          = true,
	["primitive_ladder"]          = true
}

local CritEnts = {
	["acf_rack"]                  = true,
	["prop_vehicle_prisoner_pod"] = true,
	["ace_crewseat_gunner"]       = true,
	["ace_crewseat_loader"]       = true,
	["ace_crewseat_driver"]       = true,
	["ace_rwr_dir"]               = true,
	["ace_rwr_sphere"]            = true,
	["acf_missileradar"]          = true,
	["acf_opticalcomputer"]       = true,
	["ace_ecm"]                   = true,
	["ace_trackingradar"]         = true,
	["ace_searchradar"]           = true,
	["ace_irst"]                  = true,
	--["acf_gun"]                   = true,
	["acf_ammo"]                  = true,
	["acf_engine"]                = true,
	["acf_fueltank"]              = true,
	["acf_gearbox"]               = true
}

--used mostly by contraption. Put here any entity which contains IsExplosive boolean
ACE.ExplosiveEnts = {
	["acf_ammo"]     = true,
	["acf_fueltank"] = true
}

-- whitelist for things that can be turned into debris
ACF.Debris = {
	["acf_gun"]                   = true,
	["acf_rack"]                  = true,
	["acf_gearbox"]               = true,
	["acf_engine"]                = true,
	["prop_physics"]              = true,
	["prop_vehicle_prisoner_pod"] = true
}

-- insert any new entity to the Contraption List
-- Maybe in a future: Change if-else chains by tables
hook.Add("OnEntityCreated", "ACE_EntRegister", function(Ent)
	timer.Simple(0, function()
		if not IsValid(Ent) then return end

		local Eclass = Ent:GetClass()
		--print(Eclass)
		-- check if ent class is in whitelist
		if CritEnts[Eclass] then
			table.insert(ACE.critEnts, Ent)
			--print("Adding - Count: " .. #ACE.critEnts)
		end

		-- check if ent class is in whitelist
		if AllowedEnts[Eclass] then
			-- include any ECM to this table
			if Eclass == "ace_ecm" then
				table.insert(ACE.ECMPods, Ent) --print('[ACE | INFO]- ECM registered count: ' .. table.Count( ACE.ECMPods ))
				-- include any Tracking Radar to this table
			elseif Eclass == "ace_trackingradar" or Eclass == "acf_missileradar" or Eclass == "ace_searchradar" then
				table.insert(ACE.radarEntities, Ent) --print('[ACE | INFO]- Tracking radar registered count: ' .. table.Count( ACE.radarEntities ))

				for id, ent in pairs(ACE.radarEntities) do
					ACE.radarIDs[ent] = id
				end
			elseif Eclass == "acf_opticalcomputer" then
				--Optical Computers go here
				table.insert(ACE.Opticals, Ent) --print('[ACE | INFO]- GLATGM optical computer registered count: ' .. table.Count( ACE.Opticals ))
			elseif ACE.ExplosiveEnts[Eclass] then
				--Insert Ammocrates and other explosive stuff here
				table.insert(ACE.Explosives, Ent) --print('[ACE | INFO]- Explosive registered count: ' .. table.Count( ACE.Explosives ))
			elseif Eclass == "ace_crewseat_gunner" or Eclass == "ace_crewseat_loader" or Eclass == "ace_crewseat_driver" then
				table.insert(ACE.Crewseats, Ent) --print('[ACE | INFO]- Tracking radar registered count: ' .. table.Count( ACE.radarEntities ))
			end

			if Ent.IsScalable then
				table.insert( ACE.ScalableEnts, Ent)
			end

			-- Finally, include the whitelisted entity to the main table ( contraptionEnts )
			if not IsValid(Ent:GetParent()) then
				table.insert(ACE.contraptionEnts, Ent)
				--print("[ACE | INFO]- an entity ' .. Eclass .. ' has been registered!")
				--print('Total Ents registered count: ' .. table.Count( ACE.contraptionEnts ))
			end
		elseif Eclass == "ace_debris" then
			table.insert(ACE.Debris, Ent) --print('Adding - Count: ' .. #ACE.Debris)
		elseif Eclass == "ace_mine" then
			table.insert(ACE.Mines, Ent) --print("Adding - Count: " .. #ACE.Mines)
		elseif string.StartsWith(Eclass, "npc") then
			--print("NPC Registered")
			Ent.DamageOwner = true
		end
	end)
end)

-- Remove any entity of the Contraption List that has been removed from map
hook.Add("EntityRemoved", "ACE_EntRemoval", function(Ent)

	local Eclass = Ent:GetClass()

	-- check if ent class is in whitelist
	if CritEnts[Eclass] then

		for i, critent in ipairs(ACE.critEnts) do
			if IsValid(critent) and critent == Ent then
				table.remove(ACE.critEnts, i)
				--print("Removing critent")
				--print("Removing - Count: " .. #ACE.critEnts)
				break
			end
		end

	end

	--Assuming that our table has whitelisted ents
	if AllowedEnts[Eclass] then

		for i, ent in ipairs(ACE.contraptionEnts) do
			if not IsValid(ent) or not IsValid(Ent) then continue end

			-- Remove this ECM from list if deleted
			if Eclass == "ace_ecm" then

				for i, ecm in ipairs(ACE.ECMPods) do

					if IsValid(ecm) and ecm == Ent then
						table.remove(ACE.ECMPods, i)
						--print("ECM registered count: " .. #ACE.ECMPods)
						break
					end
				end
			-- Remove this Tracking Radar from list if deleted
			elseif Eclass == "ace_trackingradar" or Eclass == "acf_missileradar" then

				for i, radar in ipairs(ACE.radarEntities) do
					if IsValid(radar) and radar == Ent then

						ACE.radarIDs[Ent] = nil

						table.remove(ACE.radarEntities, i)
						--print("Tracking radar registered count: " .. #ACE.radarEntities)
						break
					end
				end
			-- Remove this GLATGM optical Computer from list if deleted
			elseif Eclass == "acf_opticalcomputer" then

				for i, optical in ipairs(ACE.Opticals) do
					if IsValid(optical) and optical == Ent then
						table.remove(ACE.Opticals, i)
						--print("Opticals registered count: " .. #ACE.Opticals)
						break
					end
				end

			elseif ACE.ExplosiveEnts[Eclass] then

				for i, explosive in ipairs(ACE.Explosives) do
					if IsValid(explosive) and explosive == Ent then
						table.remove(ACE.Explosives, i)
						--print("Explosive registered count: " .. #ACE.Explosives)
						break
					end
				end
			elseif Eclass == "ace_crewseat_gunner" or Eclass == "ace_crewseat_loader" or Eclass == "ace_crewseat_driver" then
				for i, crewseat in ipairs(ACE.radarEntities) do
					if IsValid(crewseat) and crewseat == Ent then

						table.remove(ACE.Crewseats, i)
						--print("Tracking radar registered count: " .. #ACE.radarEntities)
						break
					end
				end
			end

			if Ent.IsScalable then

				for i, scalable in ipairs(ACE.ScalableEnts) do
					if IsValid(scalable) and scalable == Ent then
						table.remove(ACE.ScalableEnts, i)
						break
					end
				end
			end

			-- Finally, remove this Entity from the main list
			if ent == Ent then
				table.remove(ACE.contraptionEnts, i)
				--print("Global registered count: " .. #ACE.contraptionEnts )
				return
			end
		end

	elseif Eclass == "ace_debris" then
		for i, debris in ipairs(ACE.Debris) do
			if IsValid(debris) and debris == Ent then
				table.remove(ACE.Debris, i)
				--print("Debris registered count: " .. #ACE.Debris )
			end
		end
	elseif Eclass == "ace_mine" then

		local Owner = Ent.DamageOwner

		for i, mine in ipairs(ACE.MineOwners[Owner]) do
			if IsValid(mine) and mine == Ent then
				table.remove(ACE.MineOwners[Owner], i)
				--print("Mine registered count to player " .. Owner:Nick() .. ": " .. #ACE.MineOwners[Owner] )
			end
		end

		for i, mine in ipairs(ACE.Mines) do
			if IsValid(mine) and mine == Ent then
				table.remove(ACE.Mines, i)
				--print("Mine registered count: " .. #ACE.Mines )
			end
		end
	end
end)

-- Optimization resource, this will try to clean the main table just to reduce Ent count
function ACE_refreshdata(Data)
	--Not really perfect, but better than nothing. Cframepls
	if istable(Data) and not table.IsEmpty(Data) then
		local Entities = Data[1].CreatedEntities --wtf wire
		local ContrId = math.random(1, 10000)

		for _, ent in pairs(Entities) do
			if not IsValid(ent) then continue end
			ent.ACF = ent.ACF or {}
			ent.ACF.ContraptionId = ContrId --Id is always changing.
		end
	end

	--print("[ACE | INFO]- Starting Refreshing. . .")
	for index, Ent in ipairs(ACE.contraptionEnts) do
		-- check if the entity is valid
		if not IsValid(Ent) then --Clean up the nullentities
			--print("Delete")
			--print(Ent)
			table.remove(ACE.contraptionEnts, index)
			continue
		end

		-- check if it has parent
		-- if parented, check if it's not a Heat emitter
		if Ent:GetParent():IsValid() and not Ent.Heat then --(not Ent.Heat and not AllowedEnts[Eclass])
			-- if not, remove it. Removing most of parented props will decrease cost of guidances
			--print("[ACE | INFO]- Parented prop! removing. . .")
			table.remove(ACE.contraptionEnts, index)
			continue
		end
	end
	--print("[ACE | INFO]- Finished refreshing!")
	--print('Total Ents registered count: ' .. table.Count( ACE.contraptionEnts ))
end

timer.Create( "PeriodicCleanup", 3, 0, ACE_refreshdata )

hook.Add("AdvDupe_FinishPasting", "ACE_refresh", ACE_refreshdata)
