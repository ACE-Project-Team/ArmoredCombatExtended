
ACFTranslation = {}
ACFTranslation.ArmorPropertiesText = {
	----------/Tool Display description--------/--

	"ACE Armor Properties",--Name (1)
	"Sets the weight of a prop by desired armor thickness, ductility, and material.",--Description 1 (2)
	"Left click to apply settings.  Right click to copy settings.  Reload to get the total mass of an object and all constrained objects.",--Description 2 (3)

	----------/Menu Panel--------/--

	-- * IMPORTANT* MAKE SURE TO PRESERVE THE \n's they tell the reader to move to the next line.

	"Thickness",--Armor Thickness Slider Name (4)
	"Set the desired armor thickness (in mm) and the mass will be adjusted accordingly.",--Armor Thickness Slider Desc (5)
	"Ductility",--Armor Ductility Slider Name (6)
	"Set the desired armor ductility (thickness-vs-health bias).\n\nA ductile prop can survive more damage but is penetrated more easily (slider > 0).\n\nA non-ductile prop is brittle - hardened against penetration, but more easily shattered by bullets and explosions (slider < 0).",--Armor Ductility Slider Desc (7)
	"Material",--Armor Material Slider Name (8)
	"Not for the faint of heart. If your a beginner leave this at 0.\n\nSets the material of a prop to the following:\n(0)RHA\nRolled Steel that does not have any special traits, your standard ACF armor\n(1)Cast\nHeavier and softer than RHA but takes less damage\n(2)Ceramic\nLight plate that is lighter and more resiliant to penetration but is very brittle and hates being penetrated\n(3)Rubber\nRubber is effective vs heat jets and spall but does almost nothing to kinetic rounds\n(4)ERA\nERA is heavier than RHA,when penetrated it explodes damaging nearby props and the shell that hit it\n(5)Aluminum\nLighter than steel but very vulnerable to HEAT and spalling\n(6)Textolite\nFiberglass like material that isn't effective vs kinetic but is good vs HEAT and HE\n\nThe value is rounded so there are no mixed values. Remember 9 million mm of rubber is not equivalent to 9 million mm of steel.\n", --Armor Material Description (9)

	----------/Reload Information--------/--
	"with fuel", --Hp with fuel text (10)
	"Total mass is ", --Total mass text (11)
	"physical", --The word physical (12)
	"parented", --The word parented (13)

	----------/Armor Update Display Text--------/--

	-- * IMPORTANT* MAKE SURE TO PRESERVE THE \n's they tell the reader to move to the next line.

	"Current:\nMass: ", --Mass display (14)
	"\nArmor: ", --Armor display (15)
	"\nHealth: ", -- Health display (16)
	"\nMaterial: ", --Material Display (17)

	"\nAfter:\nMass: ", --After Mass Display (18)

	----------/Toolgun Display Text--------/--

	"ACE Stats", --ACF Stats (19)
	"Armour", --Armor (20)
	"Health" --Hitpoints (21)

}

ACFTranslation.CopyToolText = {
	----------/Tool Display description--------/--

	"ACE Copy Tool", --Tool Name (1)
	"Armored Combat Extended", -- ACE Modification Name (2)
	"Copy ammo or gearbox data from one object to another", -- Description 1 (3)
	"Left click to paste data, Right click to copy data",  -- Description 2 (4)

	----------/Notifications--------/--

	"Gearbox copied successfully!", --Copied gearbox succesfully (5)
	"Ammo copied successfully!" --Copied gearbox succesfully (6)


}

--[[
ACFTranslation.SoundToolText = {
	----------/Tool Display description--------/--

	"ACE Sound Replacer", --Tool Name (1)
	"Change sound of guns/engines.", -- Description 1 (2)
	"Left click to apply sound. Right click to copy sound. Reload to set default sound. Use an empty sound path to disable sound.",  -- Description 2 (3)

	----------/Notifications--------/--

	" is not supported by the sound tool!", --Not supported text (4)
	"Only ACE entities are supported by the ACE sound tool!", --Only supported (5)
	"Works only for engines" --Engines only (6)

}

ACFTranslation.ACFMenuTool = {

	"ACE Menu", -- Tool Name (1)
	"Armored Combat Extended", -- ACE Modification Text (2)
	"Spawn the Armored Combat Extended weapons and ammo", -- Description 1 (3)
	"Left click to spawn the entity of your choice, Right click to link an entity to another (+Use to unlink)", --Description 2 (4)
	"Right click to link the selected sensor to a pod", --Description 3 (5)
	"Undone ACE Entity",-- Undo entity (6)
	"Undone ACE Engine",--Undo Engine (7)
	"Undone ACE Gearbox",--Undo Gearbox (8)
	"Undone ACE Ammo",--Undo Ammo (9)
	"Undone ACE Gun",--Undo Gun (10)
	"You've reached the ACE Guns limit!",--Gun limit (11)
	"You've reached the ACE Launchers limit!",--Launcher Limit (12)
	"You've reached the ACE Explosives limit!",--Explosive Limit (13)
	"You've reached the ACE Sensors limit!",--Sensor Limit (14)
	"Couldn't create entity.",--Could not create entity error (15)
	"Didn't find entity duplicator records", -- No duplicator record error (16)

}

ACFTranslation.ACFCuttingTorch = {

	"ACE Cutting torch", --Tool Name (1)
	"Used to clear baricades and repair vehicles.",--Description 1 (2)
	"Primary to repair.\nSecondary to damage."-- Description 2 (3)

}
--]]

ACFTranslation.GunClasses = {

	"Anti Tank rifles fire stupidly fast small bullets to penetrate light armor. Built to fire HVAP out of these. Using placeholder models ATM. Extremely accurate.", --AT rifle description (1)
	"Autocannons have a rather high weight and bulk for the ammo they fire, but they can fire it extremely fast. Don't fire too long or your ACs will overheat.",--AC description (2)
	"A cannon with attached autoloading mechanism.  While it allows for several quick shots, the mechanism adds considerable bulk, weight, and magazine reload time.",--AL description (3)
	"High velocity guns that can fire very powerful ammunition, but are rather slow to reload.",--Cannon description (4)
	"Flare Launchers can fire flares much more rapidly than other launchers, but can't load any other ammo types.", --Flare Launcher (5)
	"Grenade Launchers can fire shells with relatively large payloads at a fast rate, but with very limited velocities and poor accuracy.", --GL Description(6)
	"Designed as autocannons for aircraft, HMGs are rapid firing, lightweight, and compact but sacrifice accuracy, magazine size, and reload times.  They excel at strafing and dogfighting.\nBecause of their long reload times and high rate of fire, it is best to aim BEFORE pushing the almighty fire switch.", --HMG (7)
	"Howitzers are limited to rather mediocre muzzle velocities, but can fire extremely heavy projectiles with large useful payload capacities.", --HW (8)
	"Machineguns are light guns that fire equally light bullets at a fast rate.",--MG (9)
	"Mortars are able to fire shells with usefull payloads from a light weight gun, at the price of limited velocities.",--MO (10)
	"Rotary Autocannons sacrifice weight, bulk and accuracy over classic Autocannons to get the highest rate of fire possible. Don't fire too long or your RAC will overheat.",--RAC (11)
	"Semiautomatic cannons offer better payloads than autocannons and less weight at the cost of rate of fire.", --SAC (12)
	"Short cannons trade muzzle velocity and accuracy for lighter weight and smaller size, with more penetration than howitzers and lighter than cannons.",--SC (13)
	"Smoke launcher to block an attacker's line of sight.",--SL (14)
	"High velocity guns that Fire slower and are heavier due to more reinforced cannon barrels than their counterparts."--SBC (15)

}

ACFTranslation.MissileClasses = {

	"Missiles specialized for air-to-air flight.  They have varying range, but are agile, can be radar-guided, and withstand difficult launch angles well.", --AAM (1)
	"Artillery rockets provide massive HE delivery over a broad area, with arcing ballistic trajectories and limited guidance. Best equipped with a seeker head, fired up at an angle, then guided toward a stationary target.", --Arty (2)
	"Missiles specialized for air-to-surface operation. These missiles are heavier than air-to-air missiles and may only be wire or laser guided.", --ASM (3)
	"Missiles specialized for destroying surface vehicles, especially tanks.", --ATGM (4)
	"Free-falling bombs.  Despite their lack of guidance and sophistication, they are exceptionally destructive on impact relative to their weight.", --Bomb (5)
	"Guided Bomb Unit.  Similar to a regular bomb, but able to be guided in flight to a vector coordinate.  Most useful versus hard, unmoving targets.", --GBU (6)
	"Small rockets which fit in tubes or pods.  Rapid-firing and versatile.", --FFAR (7)
	"Missiles specialized for surface-to-air operation, and well suited to lower altitude operation against ground attack aircraft.", --SAM (8)
	"Rockets which fit in racks. Usefull in rocket artillery. Slower fire-rate than FFAR but bigger 'boom'" --UAR (9)
}

ACFTranslation.FuelTanks = {
	"A fuel tank containing high grade fuel." --FuelDesc
}

ACFTranslation.Radar = {
	--Directional
	"A radar with unlimited range but a limited view cone.  Only detects launched missiles.",--DIR RadarClass (1)
	"A lightweight directional radar with a smaller view cone.", --SMDir (2)
	"A directional radar with a regular view cone.", --MedDir (3)
	"A heavy directional radar with a large view cone.",--LDir (4)

	--Spherical
	"A missile radar with full 360-degree detection but a limited range.  Only detects launched missiles.",--Spherical RadarClass (5)
	"A lightweight omni-directional radar with a smaller range.", --S (6)
	"A omni-directional radar with a regular range.",--M (7)
	"A heavy omni-directional radar with a large range." --L (8)

}

ACFTranslation.Sonar = {
	--Hull Array
	"Hull sonar array capable of tracking targets in water. Has both passive and active modes. Can emit sonar in all directions or a stronger directional ping at a specific bearing.\n WARNING: Range will vary on environmental conditions like shallower water or position relative to thermal layers.",--Sonar Array (1)
	"Small sonar that you might find on frigates and patrol boats. Has limited range but is practical for smaller platforms.", --Small Sonar (2)
	"Medium size sonar found on frigates and destroyers alike. Has a very practical range and despite not being the largest sonar it makes up for it in precision.", --Medium Sonar (3)
	"Massive sonar array found on a handful of vessels. Has the longest range by far ensonifying entire regions and obliterating the fish population. Though is less precise than its medium counterpart.",--Large Sonar (4)
	"TINY sonar useful for helicopter dipping sonars. The only SONAR that can see 360 degrees. While the range is quite insignificant compared to other sonars it is remarkably light and tiny.",--Tiny Sonar (6)

}

ACFTranslation.ShellAP = {
	"Armour Piercing", --AmmoName (1)
	"A shell made out of a solid piece of steel, meant to penetrate armour. Does the most damage out of the AP round types." --Desc (2)

}

ACFTranslation.ShellAPBC = {
	"Armour Piercing Ballistic Capped", --AmmoName (1)
	"A shell made out of a solid piece of steel, meant to penetrate armour. Has a ballistic cap and has better drag performance than its uncapped counterpart." --Desc (2)


}

ACFTranslation.ShellAPC = {
	"Armour Piercing Capped", --AmmoName (1)
	"A shell made out of a solid piece of steel, meant to penetrate armour. Has a cap that helps it deal with sloped armor." --Desc (2)

}

ACFTranslation.ShellAPCBC = {
	"Armour Piercing Capped Ballistic Capped", --AmmoName (1)
	"A shell made out of a solid piece of steel, meant to penetrate armour. A mix of APC and APBC that deals with sloped armor and drag but has the worst damage out of the AP rounds." --Desc (2)

}

ACFTranslation.ShellAPHE = {
	"Armour Piercing High Explosive", --AmmoName (1)
	"An armour piercing round with a cavity for High explosives. Less capable of defeating armour than plain Armour Piercing, but will explode after penetration." --Desc (2)

}

ACFTranslation.ShellAPHECBC = {
	"Armour Piercing High Explosive Capped Ballistic Capped", --AmmoName (1)
	"A shell made out of a solid piece of steel, meant to penetrate armour. Has a cap that helps it deal with sloped armor." --Desc (2)

}

ACFTranslation.ShellAPDS = {
	"Armour Piercing Discarding Sabot", --AmmoName (1)
	"A shell that contains a subcaliber round, dedicated to penetrating heavy armour."

}


ACFTranslation.ShellAPFSDS = {
	"Armour Piercing Fin-Stabilized Discarding Sabot", --AmmoName (1)
	"A shell that contains a subcaliber round, dedicated to penetrating heavy armour. Uses fin stabilizers."

}

ACFTranslation.ShellFL = {
	"Flechette", --AmmoName (1)
	"Flechette rounds contain several long thin steel spikes, functioning as a shotgun shell for cannons.\n\nWhile it seems like the spikes would penetrate well, they tend to tumble in flight and impact at less than ideal angles, causing only minor penetration and structural damage.\n\nThey are best used against infantry or lightly armored mobile targets such as aircraft or light tanks, since flechettes trade brute damage for a better chance to hit." --Desc (2)

}


ACFTranslation.ShellFLR = {
	"Flare", --AmmoName (1)
	"A flare designed to confuse guided munitions." --Desc (2)

}

ACFTranslation.ShellGLGM = {
	"Gun-Launched Anti-Tank Missile", --AmmoName (1)
	"A missile fired from a gun. While slower than a traditional shell it makes up for that with guidance." --Desc (2)

}

ACFTranslation.ShellHE = {
	"High Explosive", --AmmoName (1)
	"A shell filled with explosives, fragments when detonating on impact. " --Desc (2)

}

ACFTranslation.ShellHEAT = {
	"High Explosive Anti-Tank", --AmmoName (1)
	"A shell with a shaped charge.  When the round detonates, the explosive energy is focused into driving a small molten metal penetrator into the victim with extreme force, though this results in reduced damage from the explosion itself.  Multiple layers of armor will dissipate the penetrator quickly." --Desc (2)

}

ACFTranslation.ShellHEATFS = {
	"High Explosive Anti-Tank Fin-Stabilized", --AmmoName (1)
	"A shell with a shaped charge.  When the round detonates, the explosive energy is focused into driving a small molten metal penetrator into the victim with extreme force, though this results in reduced damage from the explosion itself.  Multiple layers of armor will dissipate the penetrator quickly." --Desc (2)

}

ACFTranslation.ShellHEFS = {
	"High Explosive Fin-Stabilized", --AmmoName (1)
	"A shell filled with explosives, fragments when detonating on impact.Uses fin stabilizers." --Desc (2)

}

ACFTranslation.ShellHESH = {
	"High Explosive Squash Head", --AmmoName (1)
	"A shell filled with explosives, that flattens and detonates on impact creating spall. Weaker blast than HE.\n\nThis ammo can be countered with a spall liner" --Desc (2)

}

ACFTranslation.HP = {
	"Hollow Point", --AmmoName (1)
	"A solid shell with a soft point, meant to flatten against armour" --Desc (2)

}

ACFTranslation.ShellAPCR = {
	"Armor-Piercing Composite Rigid", --AmmoName (1)
	"A soft projectile that contains a heavy tungsten core, penetrates and does a lot more damage than APDS or APFSDS, but has horrible drag characteristics and is not meant against sloped armor." --Desc (2)

}

ACFTranslation.ShellRef = {
	"Refill", --AmmoName (1)
	"Refills other ammo crates. Ignore the gun type since this crate can refill any weapon. Not linkeable" --Desc (2)

}

ACFTranslation.ShellSm = {
	"Smoke", --AmmoName (1)
	"A shell filled white phosporous, detonating on impact. Smoke filler produces a long lasting cloud but takes a while to be effective, whereas WP filler quickly creates a cloud that also dissipates quickly." --Desc (2)

}

ACFTranslation.THEAT = {
	"Tandem High Explosive Anti-Tank", --AmmoName (1)
	"A shell with multiple shaped charges. Similar to HEAT the explosive charge accelerates a molten jet to penetrate armor, unlike typical HEAT when the jet fails to penetrate a second charge will detonate and finish the job. This makes this form of ammo exceptional against special armor types like ERA" --Desc (2)

}

ACFTranslation.THEATFS = {
	"Tandem High Explosive Anti-Tank Fin-Stabilized", --AmmoName (1)
	"A shell with multiple shaped charges. Similar to HEAT the explosive charge accelerates a molten jet to penetrate armor, unlike typical HEAT when the jet fails to penetrate a second charge will detonate and finish the job. This makes this form of ammo exceptional against special armor types like ERA. Uses fin stabilizers." --Desc (2)

}

ACFTranslation.VHeatSource = {
	"Virtual Heat Source", --Name (1)
	"Allows to create a heat source to match with your contraption." --Desc (2)
}
