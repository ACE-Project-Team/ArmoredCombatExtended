
local ClassName = "Overshoot"


ACF = ACF or {}
ACF.Fuse = ACF.Fuse or {}

local this = ACF.Fuse[ClassName] or inherit.NewSubOf(ACF.Fuse.Contact)
ACF.Fuse[ClassName] = this

---



this.Name = ClassName

-- The entity to measure distance to.
this.Target = nil

-- the fuse may trigger at some point under this range - unless it's travelling so fast that it steps right on through.
this.Distance = 2000

this.fuseArmed = false --Arms the fuse once it gets below the target distance. Allows missiles without memory to fuse after losing sight of the target.


this.desc = "Once the arming distance has been reached. Detonates when the missile loses the target which is assumed to be at the closest point.\n NOT reccomended for missiles without inertial guidance.\nDistance in inches."


-- Configuration information for things like acfmenu.
this.Configurable = table.Copy(this:super().Configurable)

local configs = this.Configurable

configs[#configs + 1] =
{
	Name = "Distance",		-- name of the variable to change
	DisplayName = "Distance",	-- name displayed to the user
	CommandName = "Ds",		-- shorthand name used in console commands

	Type = "number",			-- lua type of the configurable variable
	Min = 0,					-- number specific: minimum value
	Max = 10000				-- number specific: maximum value

	-- in future if needed: min/max getter function based on munition type.  useful for modifying radar cones?
}

do

	--Question: Should radio fuze be limited to detect props in front of the missile only? Its weird it detonates by detecting something behind it.
	function this:GetDetonate(missile)

		if not self:IsArmed() then return false end

		--if (missile.IsDecoyed or false) then return false end

		local missilePos = missile:GetPos()
		local missileTarget = missile.TargetPos

		if not missileTarget then --Target Lost
			
			if not self.fuseArmed then
				return false 
			else --The fuse was armed but we lost sight of the target. Detonate.
				return true 				
			end
		end

		local CurDist = missileTarget:DistToSqr( missilePos )

		if CurDist < self.Distance^2 then
			self.fuseArmed = true
			--print("isarmed")
		end

		if self.fuseArmed and (missileTarget:DistToSqr( missilePos ) < missileTarget:DistToSqr( missilePos + missile.Flight )) then
			

			return true

		end

		return false
	end
end


function this:GetDisplayConfig()
	return
	{
		["Arming delay"] = math.Round(self.Primer, 3) .. " s",
		["Ignition Delay"] = math.Round(self.StartDelay, 3) .. " s",
		["Distance"] = math.Round(self.Distance / 39.37, 1) .. " m"
	}
end
