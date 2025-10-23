--Fuel Density
ACF.FuelDensity = { --kg/liter
	Diesel = 0.832,
	Petrol = 0.745,
	Electric = 1.35 -- li-ion --WAS 3.1
}
ACF.FuelPowerDensity = { --KJ/liter
	Diesel = 38.6,
	Petrol = 33.6,
	Electric = 1 --TODO: Find conversion units. Fine for now. Electric doesn't generate too much heat to be of concern.
}



ACF.PerFuelRelativeEfficiency = { --Efficiency multipliers when using various fuels
	Diesel = 1.375, --42% more fuel efficicient but slightly less(1.02x) kg efficient for a unit of fuel.
	Petrol = 1,
	Electric = 1 --TODO: Find conversion units. Fine for now. Electric doesn't generate too much heat to be of concern.
}

--Power density of fuel. They're close enough so we'll use the density of gasoline to give engines the benefit of the doubt. 
--This way we score efficiency more on the type of engine and less so fuel which will be seperated. Especially as we're scoring their efficiency as a type.
--local BasePetrol = 1/13 --13kWh per kg gasoline. or ~0.077 kg per kw hr
--local BaseDiesel = 1/12.6 --12.6kWh per kg Diesel. Or ~0.079 kg per kw hr

local BaseFuel = 1/13 --13kWh per kg or ~0.077 kg per kw hr. The fuel density of gasoline. Diesel is 12.6kWh per kg or ~0.079 kg per kw hr.

ACF.Efficiency = { --how efficient various engine types are, Final units are in kg/kWhr
	GenericPetrol = (BaseFuel / 0.35), --Divide by % efficiency. Was 38%. Needs to be kept for other legacy engines.
	GenericDiesel = (BaseFuel / 0.5), --Was 49% efficient. Was 38%. Needs to be kept for other legacy engines.

	Single = (BaseFuel / 0.4), --Divide by % efficiency. Was 38%
	I2 = (BaseFuel / 0.395), --Divide by % efficiency. Was 38%
	I3 = (BaseFuel / 0.39), --Divide by % efficiency. Was 38%
	I4 = (BaseFuel / 0.385), --Divide by % efficiency. Was 38%
	I5 = (BaseFuel / 0.38), --Divide by % efficiency. Was 38%
	I6 = (BaseFuel / 0.375), --Divide by % efficiency. Was 38%

	B4 = (BaseFuel / 0.365), --Divide by % efficiency. Was 38%
	B6 = (BaseFuel / 0.36), --Divide by % efficiency. Was 38%

	V2 = (BaseFuel / 0.35), --Divide by % efficiency. Was 38%
	V4 = (BaseFuel / 0.345), --Divide by % efficiency. Was 38%
	V6 = (BaseFuel / 0.34), --Divide by % efficiency. Was 38%
	V8 = (BaseFuel / 0.335), --Divide by % efficiency. Was 38%
	V10 = (BaseFuel / 0.33), --Divide by % efficiency. Was 38%
	V12 = (BaseFuel / 0.325), --Divide by % efficiency. Was 38%

	Turbine = (BaseFuel / 0.35), --Was 32% efficient. Somewhere between a turboshaft and turbofan.
	--Turbofan = (BaseFuel / 0.4), --Was 32% efficient.
	GroundTurbine = (BaseFuel / 0.3), --Was 32% efficient.
	Wankel = (BaseFuel / 0.25), --Was 34%. Almost on par with regular petrol. Get. Outta. Here.
	Radial = (BaseFuel / 0.28), --Was 30% efficient.

	Racing = (BaseFuel / 0.2), --Racing duty engines meant for absurd speeds. Inefficient but power dense as hell.

	Electric = 0.85 --percent efficiency converting chemical kw into mechanical kw WAS 0.85
}

ACF.TorqueScale = { --how fast damage drops torque, lower loses more % torque
	GenericPetrol = 0.25,
	GenericDiesel = 0.5,

	Single = 0.25,
	I2 = 0.25,
	I3 = 0.275,
	I4 = 0.3,
	I5 = 0.325,
	I6 = 0.35,

	B4 = 0.3,
	B6 = 0.325,

	V2 = 0.25,
	V4 = 0.275,
	V6 = 0.3,
	V8 = 0.3,
	V10 = 0.325,
	V12 = 0.35,

	Turbine = 0.15,
	GroundTurbine = 0.2,
	Wankel = 0.2,
	Radial = 0.3,

	Racing = 0.1,

	Electric = 0.2
}

ACF.EngineHPMult = { --health multiplier for engines

	GenericPetrol = 0.15,
	GenericDiesel = 0.2,

	Single = 0.1,
	I2 = 0.1,
	I3 = 0.125,
	I4 = 0.15,
	I5 = 0.175,
	I6 = 0.2,

	B4 = 0.125,
	B6 = 0.15,

	V2 = 0.1,
	V4 = 0.1,
	V6 = 0.125,
	V8 = 0.15,
	V10 = 0.175,
	V12 = 0.2,

	Turbine = 0.05,
	GroundTurbine = 0.05,
	Wankel = 0.1,
	Radial = 0.2,

	Racing = 0.1,

	Electric = 0.1
}


ACF.PerFuelTorqueCurveMul = { --Efficiency multipliers when using various fuels
	Diesel = {1,1.64,1.43,1.12,0.9,0.89,0.93},
	Petrol = {1,1,1,1,1,1,1},
	Electric = {1,1,1,1,1,1,1}
}

--Use this to help design torque curves https://gist.github.com/CheezusChrust/7ccce5f5196d3adc95ab9573009f735a
ACF.GenericTorqueCurves = { --Default curves for engines that don't have one defined

	GenericPetrol = {0.3, 0.55, 0.7, 0.85, 1, 0.9, 0.7},
	GenericDiesel = {0.3, 0.55, 0.7, 0.85, 1, 0.9, 0.7}, --Needed for legacy and extra engines. It's set the same as petrol because the diesel engines are modified to a diesel torque curve by the fueltype curve. True values = {0.3, 0.97, 1, 0.95, 0.9, 0.8, 0.65}

	Single = {0.4, 0.65, 0.96, 1.0, 0.93, 0.8, 0.71},
	I2 = {0.4, 0.65, 0.96, 1.0, 0.93, 0.8, 0.71}, --Inlines are similar to V-Block engines except with excellent low end torque and a generally more stable powerband. Made up for by being less energy dense.
	I3 = {0.4, 0.62, 0.88, 1.0, 0.95, 0.82, 0.73},
	I4 = {0.4, 0.52, 0.74, 0.95, 1.0, 0.85, 0.75},
	I5 = {0.4, 0.49, 0.65, 0.82, 1, 0.92, 0.7},
	I6 = {0.4, 0.48, 0.6, 0.76, 0.95, 1.0, 0.875},

	B4 = {0.3, 0.48, 0.76, 1, 0.94, 0.74, 0.67}, --Boxer types have a wide torquey band with a narrow peak they produce peak power at.
	B6 = {0.35, 0.49, 0.67, 0.87, 1, 0.85, 0.73},

	V2 = {0.3, 0.65, 0.95, 1.0, 0.91, 0.8, 0.68},
	V4 = {0.3, 0.65, 0.95, 1.0, 0.91, 0.8, 0.68}, --Excellent low end torque and torque over a wide range. But the least peak HP
	V6 = {0.35, 0.6, 0.84, 1.0, 0.95, 0.81, 0.7}, --Good torque over a wide range but less high range power
	V8 = {0.35, 0.52, 0.72, 0.92, 1.0, 0.85, 0.72}, --Good torque at the upper mid range and a relatively wide range. Results in good horsepower.
	V10 = {0.35, 0.49, 0.65, 0.82, 1, 0.92, 0.66}, --A wide but narrower torque band than the V8. Geared slightly more towards peak horsepower.
	V12 = {0.3, 0.4, 0.55, 0.72, 0.9, 1.0, 0.875}, --Trades instantaneous torque for higher RPM torque. Best for peak horsepower in the upper range.

	Turbine = {1, 0.9, 0.8, 0.6, 0.4, 0.2, 0.1},
	GroundTurbine = {1, 0.59, 0.58, 0.65, 0.72, 0.66, 0.57}, --Turbine with internal reduction gearing producing instantaneous torque. Reduced from true values because of the fueltype curve. True Values = {1, 0.97, 0.84, 0.73, 0.65, 0.59, 0.529}
	Wankel = {0.35, 0.7, 0.85, 0.95, 1, 0.9, 0.7},
	Radial = {0.4, 0.5, 0.65, 0.75, 0.95, 1, 0.5},

	Racing = {0.3, 0.4, 0.55, 0.72, 0.9, 1.0, 0.875}, --Significantly power dense engines designed for peak power output at the cost of longevity.

	Electric = {1, 0.99, 0.95, 0.6, 0.2}
}
