local MaxVisclips = 50

return function(StartPos, EndPos, Filter)
	local TraceData = {
		start = StartPos,
		endpos = EndPos,
		filter = Filter
	}
	local TraceResult
	local VisclipCount = 0

	repeat
		TraceResult = util.TraceLine(TraceData)

		if not ACE.CheckClips(TraceResult.Entity, TraceResult.HitPos) then break end

		TraceData.filter[#TraceData.filter + 1] = TraceResult.Entity
		VisclipCount = VisclipCount + 1
	until VisclipCount >= MaxVisclips

	return TraceResult
end
