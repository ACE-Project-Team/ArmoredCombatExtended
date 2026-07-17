return {
	groupName = "ACE points invalidation hook contracts",
	cases = {
		{
			name = "loads the central invalidation and recalculation APIs",
			func = function()
				expect(ACE_NotifyPointsInvalidated).to.beA("function")
				expect(ACE_PointsInputChanged).to.beA("function")
				expect(ACE_NotifyContraptionPointsInvalidated).to.beA("function")
				expect(ACE_EnsureContraptionPoints).to.beA("function")
			end,
		},
		{
			name = "registers every lifecycle hook used by the invalidation boundary",
			func = function()
				local registered = hook.GetTable()
				for _, name in ipairs({
					"cfw.contraption.created",
					"cfw.contraption.entityAdded",
					"cfw.contraption.entityRemoved",
					"cfw.contraption.split",
					"cfw.contraption.merged",
					"cfw.contraption.removed",
					"PlayerFrozeObject",
					"PlayerUnfrozeObject",
					"PlayerEnteredVehicle",
					"ProperClippingPhysicsClipped",
					"ProperClippingPhysicsReset",
				}) do
					expect(registered[name]).to.exist()
				end
			end,
		},
		{
			name = "records one cross-contraption event with complete generations",
			func = function()
				local first = { ents = {}, totalMass = 0 }
				local second = { ents = {}, totalMass = 0 }
				ACE_EnsurePointsState(first)
				ACE_EnsurePointsState(second)
				local batches = 0
				local compatibility = 0
				local recalculations = 0
				local hookName = "ACE_GLuaTest_Invalidation_" .. tostring(SysTime())

				hook.Add("ACE_OnContraptionsPointsInvalidated", hookName, function(event)
					batches = batches + 1
					expect(event.Reason).to.equal("native-cross-link")
					expect(#event.AffectedContraptions).to.equal(2)
					expect(event.CacheGenerations[first].Points).to.equal(first.ACEPointsGeneration)
					expect(event.CacheGenerations[second].Points).to.equal(second.ACEPointsGeneration)
				end)
				hook.Add("ACE_OnContraptionPointsInvalidated", hookName .. "_compat", function()
					compatibility = compatibility + 1
				end)
				hook.Add("ACE_OnContraptionPointsRecalculated", hookName .. "_recalc", function()
					recalculations = recalculations + 1
				end)

				local event = ACE_NotifyPointsInvalidated({ first, second }, "native-cross-link", {
					Ammo = true,
					Firepower = true,
					ReadyRack = true,
					Warning = true,
				})

				expect(event).to.exist()
				expect(event.EventId).to.beA("number")
				expect(first.ACEPointsGeneration).to.equal(1)
				expect(second.ACEPointsGeneration).to.equal(1)
				expect(batches).to.equal(1)
				expect(compatibility).to.equal(2)
				expect(recalculations).to.equal(2)

				hook.Remove("ACE_OnContraptionsPointsInvalidated", hookName)
				hook.Remove("ACE_OnContraptionPointsInvalidated", hookName .. "_compat")
				hook.Remove("ACE_OnContraptionPointsRecalculated", hookName .. "_recalc")
			end,
		},
		{
			name = "deduplicates repeated endpoints before generation advance",
			func = function()
				local con = { ents = {}, totalMass = 0 }
				ACE_EnsurePointsState(con)
				local event = ACE_NotifyPointsInvalidated({ con, con, con }, "native-duplicate", {
					Warning = true,
				})

				expect(event).to.exist()
				expect(#event.AffectedContraptions).to.equal(1)
				expect(con.ACEPointsGeneration).to.equal(1)
			end,
		},
		{
			name = "covers real CFW final defuse removal ordering",
			func = function()
				local first = ents.Create("prop_physics")
				local second = ents.Create("prop_physics")
				expect(first).to.exist()
				expect(second).to.exist()
				first:SetModel("models/props_junk/wood_crate001a.mdl")
				second:SetModel("models/props_junk/wood_crate001a.mdl")
				first:Spawn()
				second:Spawn()

				local con = CFW.createContraption()
				expect(ACE._ACEWrappedDefuse).to.equal(true)
				local batches = 0
				local hookName = "ACE_GLuaTest_Defuse_" .. tostring(SysTime())
				hook.Add("ACE_OnContraptionsPointsInvalidated", hookName, function(event)
					if event.Reason == "entity-removed" or event.Reason == "contraption-removed" then
						batches = batches + 1
					end
				end)

				con:Add(first)
				con:Add(second)
				con:Defuse()
				expect(con._removed).to.equal(true)
				expect(batches).to.equal(1)
				expect(ACE.PointContraptions[con]).to.equal(nil)

				hook.Remove("ACE_OnContraptionsPointsInvalidated", hookName)
				if IsValid(first) then first:Remove() end
				if IsValid(second) then second:Remove() end
			end,
		},
		{
			name = "covers real CFW merge cleanup and one structural event",
			func = function()
				local first = ents.Create("prop_physics")
				local second = ents.Create("prop_physics")
				expect(first).to.exist()
				expect(second).to.exist()
				first:SetModel("models/props_junk/wood_crate001a.mdl")
				second:SetModel("models/props_junk/wood_crate001a.mdl")
				first:Spawn()
				second:Spawn()

				local target = CFW.createContraption()
				local merged = CFW.createContraption()
				target:Add(first)
				merged:Add(second)
				local structuralEvents = 0
				local hookName = "ACE_GLuaTest_Merge_" .. tostring(SysTime())
				hook.Add("ACE_OnContraptionsPointsInvalidated", hookName, function(event)
					if event.Reason == "contraption-merged" then structuralEvents = structuralEvents + 1 end
				end)

				target:Merge(merged)
				expect(merged.ACERemoving).to.equal(true)
				expect(ACE.PointContraptions[merged]).to.equal(nil)
				expect(structuralEvents).to.equal(1)

				hook.Remove("ACE_OnContraptionsPointsInvalidated", hookName)
				target:Defuse()
				if IsValid(first) then first:Remove() end
				if IsValid(second) then second:Remove() end
			end,
		},
	}
}
