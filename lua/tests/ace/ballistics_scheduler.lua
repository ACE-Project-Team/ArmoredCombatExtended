return {
	groupName = "ACE ballistics scheduler behavior",
	cases = {
		{
			name = "registers, removes, and advances each active bullet once per frame",
			func = function()
				local oldCalc = ACE_CalcBulletFlight
				local calls = {}
				local indices = { 901, 902, 903 }

				local function removeAll()
					for _, index in ipairs(indices) do
						ACE_RemoveBullet(index)
					end
				end

				local ok, message = xpcall(function()
					ACE_CalcBulletFlight = function(index)
						calls[index] = (calls[index] or 0) + 1
					end

					ACE_RegisterBullet(indices[1], { HandlesOwnIteration = false, ActiveFrame = -1 })
					ACE_RegisterBullet(indices[2], { HandlesOwnIteration = false, ActiveFrame = -1 })
					ACE_ManageBullets()

					expect(calls[indices[1]]).to.equal(1)
					expect(calls[indices[2]]).to.equal(1)

					ACE_RemoveBullet(indices[1])
					ACE_RegisterBullet(indices[3], { HandlesOwnIteration = false, ActiveFrame = -1 })
					ACE_ManageBullets()

					expect(calls[indices[1]]).to.equal(1)
					expect(calls[indices[2]]).to.equal(2)
					expect(calls[indices[3]]).to.equal(1)
				end, debug.traceback)

				removeAll()
				ACE_CalcBulletFlight = oldCalc
				if not ok then error(message, 0) end
			end,
		},
		{
			name = "does not advance self-managed bullets",
			func = function()
				local oldCalc = ACE_CalcBulletFlight
				local index = 904
				local called = false

				local ok, message = xpcall(function()
					ACE_CalcBulletFlight = function()
						called = true
					end

					ACE_RegisterBullet(index, { HandlesOwnIteration = true, ActiveFrame = -1 })
					ACE_ManageBullets()

					expect(called).to.equal(false)
				end, debug.traceback)

				ACE_RemoveBullet(index)
				ACE_CalcBulletFlight = oldCalc
				if not ok then error(message, 0) end
			end,
		},
	},
}
