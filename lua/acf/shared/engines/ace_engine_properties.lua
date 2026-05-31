--Fuel Density
ACF.FuelDensity = { --kg/liter
	Diesel = 0.832,
	Petrol = 0.745,
	Electric = 1.35, -- li-ion --WAS 3.1
	Oil = 0.88,      -- crude oil: refinery input only, not an engine fuel
	Universal = 0.745, -- typeless tank: assigns to whatever first fills it (density placeholder; real type takes over on fill)
}

ACF.Efficiency = { --how efficient various engine types are, higher is worse
	GenericPetrol = 0.203, --kg per kw hr
	GenericDiesel = 0.162, --up to 0.274
	Turbine = 0.25, -- previously 0.231
	Wankel = 0.223,
	Radial = 0.267, -- 0.38 to 0.53
	Electric = 0.6 --percent efficiency converting chemical kw into mechanical kw WAS 0.85
}

ACF.TorqueScale = { --how fast damage drops torque, lower loses more % torque
	GenericPetrol = 0.25,
	GenericDiesel = 0.35,
	Turbine = 0.2,
	Wankel = 0.2,
	Radial = 0.3,
	Electric = 0.3 --WAS 0.5
}

ACF.EngineHPMult = { --health multiplier for engines
	GenericPetrol = 0.2,
	GenericDiesel = 0.5,
	Turbine = 0.125,
	Wankel = 0.125,
	Radial = 0.3,
	Electric = 0.75
}

--Use this to help design torque curves https://gist.github.com/CheezusChrust/7ccce5f5196d3adc95ab9573009f735a
ACF.GenericTorqueCurves = { --Default curves for engines that don't have one defined
	GenericPetrol = {0.3, 0.55, 0.7, 0.85, 1, 0.9, 0.7},
	GenericDiesel = {0.3, 0.9, 0.97, 1, 0.95, 0.9, 0.8, 0.65},
	Turbine = {0.8, 1, 0.9, 0.8, 0.6, 0.4, 0.2, 0.1},
	Wankel = {0.35, 0.7, 0.85, 0.95, 1, 0.9, 0.7},
	Radial = {0.6, 0.75, 0.85, 0.95, 0.98, 0.6},
	Electric = {1, 0.99, 0.95, 0.6, 0.2}
}
