return {
	groupName = "ACE points and manufacturing models",
	cases = {
		{
			name = "loads the public model API",
			func = function()
				expect(ACE.PointsModel).to.exist()
				expect(ACE.ManuCost).to.exist()
				expect(ACE.Points_Gate).to.beA("function")
				expect(ACE.Manu_RoundCost).to.beA("function")
			end
		},
		{
			name = "uses a continuous zero-based penetration gate",
			func = function()
				expect(ACE.Points_Gate(0)).to.equal(0)
				expect(ACE.Points_Gate(ACE.PointsModel.P50)).to.aboutEqual(0.5)
				expect(ACE.Points_Gate(1)).to.beLessThan(0.2)
			end
		},
		{
			name = "keeps utility rounds harmless but non-free",
			func = function()
				local utility = { Type = "SM", maxPen = 0, FrArea = 0, blastMass = 0 }
				expect(ACE.Points_PostPenMult(utility)).to.equal(0)
				expect(ACE.Points_BaseRoundCost(utility)).to.equal(1)
			end
		},
		{
			name = "prices HE and HESH through their intended blast channels",
			func = function()
				local he = { Type = "HE", maxPen = 10, FrArea = 0, blastMass = 6 }
				local hesh = { Type = "HESH", maxPen = 10, FrArea = 0, blastMass = 6 }
				expect(ACE.Points_GatePen(he)).to.beGreaterThan(10)
				expect(ACE.Points_GatePen(hesh)).to.beGreaterThan(10)
				expect(ACE.Points_IntrinsicValueMul(he)).to.equal(1.5)
				expect(ACE.Points_IntrinsicValueMul(hesh)).to.equal(1)
			end
		},
		{
			name = "applies the same delivery-rate floor to guns and racks",
			func = function()
				local round = { Type = "AP", maxPen = 3000, FrArea = math.pi * 5 ^ 2, blastMass = 0 }
				local score = ACE.Points_BaseRoundCost(round) * ACE.Points_Gate(ACE.Points_GatePen(round))
				local floor = ACE.Points_RateFloor()
				expect(floor).to.aboutEqual(1 / 30)
				expect(ACE.Points_GunCost(floor, score, 1)).to.aboutEqual(ACE.Points_GunCost(1 / 300, score, 1))
				expect(ACE.Points_RackCostFromRate(floor, score)).to.aboutEqual(ACE.Points_RackCostFromRate(1 / 300, score))
			end
		},
		{
			name = "keeps identical weapons additive",
			func = function()
				local round = { Type = "AP", maxPen = 500, FrArea = math.pi * 5 ^ 2, blastMass = 0 }
				local base = ACE.Points_BaseRoundCost(round)
				local threat = ACE.Points_Gate(ACE.Points_GatePen(round))
				local one = ACE.Points_GunCost(1, base, threat)
				expect(ACE.Points_GunCost(2, base, threat)).to.aboutEqual(2 * one)
			end
		},
		{
			name = "keeps refill ammunition free in manufacturing cost",
			func = function()
				expect(ACE.Manu_RoundCost({ Type = "Refill", ProjMass = 10 })).to.equal(0)
				expect(ACE.Manu_RoundCost({ Type = "AP", ProjMass = 10 })).to.equal(800)
			end
		},
		{
			name = "prices gun caliber quadratically and class modifiers explicitly",
			func = function()
				local base = ACE.Manu_GunCost(100, "MG")
				expect(base).to.equal(48 * 100 ^ 2 * 1.5)
				expect(ACE.Manu_GunCost(200, "MG")).to.aboutEqual(4 * base)
			end
		}
	}
}
