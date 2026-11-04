if SERVER then
	util.AddNetworkString("ACE_SWEPSounds")
	util.AddNetworkString("ACE_SWEPPrecache")

	-- Clients load a weapon's fire sounds when it spawns, not on its first shot: a far NPC's weapon never reaches them, so they would otherwise first hear of it mid-fight.
	local announcedSounds = {}

	local function SendPrecache(sounds, targets)
		net.Start("ACE_SWEPPrecache")
		net.WriteUInt(#sounds, 16)
		for _, snd in ipairs(sounds) do
			net.WriteString(snd)
		end
		net.Send(targets)
	end

	hook.Add("OnEntityCreated", "ACE_SWEPPrecache", function(ent)
		if not ent:IsWeapon() then return end

		-- The weapon's table is filled in after this hook
		timer.Simple(0, function()
			if not IsValid(ent) or not ent.Primary then return end

			local snd = ent.Primary.Sound
			if not snd or announcedSounds[snd] or not ACE.GSounds.GunFire[snd] then return end

			announcedSounds[snd] = true
			SendPrecache({ snd }, player.GetHumans())
		end)
	end)

	-- A joining client asks once it can receive, for the weapons spawned before it arrived
	net.Receive("ACE_SWEPPrecache", function(_, ply)
		if ply.ACE_SWEPPrecacheSent then return end
		ply.ACE_SWEPPrecacheSent = true

		SendPrecache(table.GetKeys(announcedSounds), ply)
	end)

	-- The shooter's position and sound go along with the weapon: a client far away has no copy of an NPC or its weapon, so it cannot read them from the entity.
	local function SendFireSound(ent, propmass, targets)
		local owner = ent:GetOwner()
		local shooter = IsValid(owner) and owner or ent

		net.Start("ACE_SWEPSounds", true)
		net.WriteEntity(ent)
		net.WriteFloat(propmass)
		net.WriteVector(shooter:GetPos())
		net.WriteString(ent.Primary.Sound or "")
		net.Send(targets)
	end

	function ACE.NetworkSPEffects(ent, propmass)
		SendFireSound(ent, propmass, ent:GetOwner())
	end

	-- The previous networking function. Removed owner from vars since ent (the swep) already has the owner and sounds networked in it.
	-- propmass is serverside so we must include it into client.
	function ACE.NetworkMPEffects(sourcePly, ent, propmass)
		local targets = {}

		for _, v in ipairs(player.GetAll()) do
			if v ~= sourcePly then
				table.insert(targets, v)
			end
		end

		SendFireSound(ent, propmass, targets)
	end

else
	local precachedSounds = {}

	net.Receive("ACE_SWEPPrecache", function()
		for _ = 1, net.ReadUInt(16) do
			local snd = net.ReadString()
			local data = ACE.GSounds.GunFire[snd]

			if data and not precachedSounds[snd] then
				precachedSounds[snd] = true

				for _, distanced in pairs(data) do
					if istable(distanced) and distanced.Package then
						for _, path in ipairs(distanced.Package) do
							util.PrecacheSound(path)
						end
					end
				end
			end
		end
	end)

	hook.Add("InitPostEntity", "ACE_SWEPPrecache", function()
		net.Start("ACE_SWEPPrecache")
		net.SendToServer()
	end)

	-- We receive data from server. In singleplayer our own shots are not predicted, so the server tells us to play them here.
	-- Everyone else's shots, NPCs included, go through the distance-based gunfire sound.
	net.Receive("ACE_SWEPSounds", function()

		local swep = net.ReadEntity()
		local propmass = net.ReadFloat()
		local origin = net.ReadVector()
		local sound = net.ReadString()
		local owner = IsValid(swep) and swep:GetOwner()

		if owner == LocalPlayer() then
			swep.ACEPropmass = propmass
			swep:DoSPClientEffects()
		else
			ACE.SGunFire(owner, sound, 1, propmass, origin)
		end
	end)
end

--ak47mm gunfire
ACE.DefineGunFireSound( "ace_weapons/sweps/multi_sound/ak47_multi.mp3",
	{
		main = {
			Volume	= 1,
			Pitch	= 100,
			Package = {
				"ace_weapons/sweps/multi_sound/content/ak47/close/close1.mp3",
				"ace_weapons/sweps/multi_sound/content/ak47/close/close2.mp3",
				"ace_weapons/sweps/multi_sound/content/ak47/close/close3.mp3",
				"ace_weapons/sweps/multi_sound/content/ak47/close/close4.mp3",
				"ace_weapons/sweps/multi_sound/content/ak47/close/close5.mp3",
				"ace_weapons/sweps/multi_sound/content/ak47/close/close6.mp3",
				"ace_weapons/sweps/multi_sound/content/ak47/close/close7.mp3",
				"ace_weapons/sweps/multi_sound/content/ak47/close/close8.mp3",
				"ace_weapons/sweps/multi_sound/content/ak47/close/close9.mp3",
				"ace_weapons/sweps/multi_sound/content/ak47/close/close10.mp3",

			}
		},
		mid = {
			Volume	= 1,
			Pitch	= 100,
			Package = {
				"ace_weapons/sweps/multi_sound/content/ak47/mid/mid.mp3",
				"ace_weapons/sweps/multi_sound/content/ak47/mid/mid1.mp3",
				"ace_weapons/sweps/multi_sound/content/ak47/mid/mid2.mp3",
				"ace_weapons/sweps/multi_sound/content/ak47/mid/mid3.mp3",
				"ace_weapons/sweps/multi_sound/content/ak47/mid/mid4.mp3",
				"ace_weapons/sweps/multi_sound/content/ak47/mid/mid5.mp3",
				"ace_weapons/sweps/multi_sound/content/ak47/mid/mid6.mp3",
				"ace_weapons/sweps/multi_sound/content/ak47/mid/mid7.mp3",
				"ace_weapons/sweps/multi_sound/content/ak47/mid/mid8.mp3",
				"ace_weapons/sweps/multi_sound/content/ak47/mid/mid9.mp3",
				"ace_weapons/sweps/multi_sound/content/ak47/mid/mid10.mp3",
			}

		},
		far = {
			Volume	= 1,
			Pitch	= 100,
			Package = {
				"ace_weapons/sweps/multi_sound/content/ak47/far/far.mp3",
				"ace_weapons/sweps/multi_sound/content/ak47/far/far1.mp3",
				"ace_weapons/sweps/multi_sound/content/ak47/far/far2.mp3",
				"ace_weapons/sweps/multi_sound/content/ak47/far/far3.mp3",
				"ace_weapons/sweps/multi_sound/content/ak47/far/far4.mp3",
				"ace_weapons/sweps/multi_sound/content/ak47/far/far5.mp3",
				"ace_weapons/sweps/multi_sound/content/ak47/far/far6.mp3",
				"ace_weapons/sweps/multi_sound/content/ak47/far/far7.mp3",
				"ace_weapons/sweps/multi_sound/content/ak47/far/far8.mp3",
				"ace_weapons/sweps/multi_sound/content/ak47/far/far9.mp3",
				"ace_weapons/sweps/multi_sound/content/ak47/far/far10.mp3",
			}
		}
	}
)


--amr
ACE.DefineGunFireSound( "ace_weapons/sweps/multi_sound/amr_multi.mp3",
	{
		main = {
			Volume	= 1,
			Pitch	= 100,
			Package = {
				"ace_weapons/sweps/multi_sound/content/amr/close/close1.mp3",
				"ace_weapons/sweps/multi_sound/content/amr/close/close2.mp3",
				"ace_weapons/sweps/multi_sound/content/amr/close/close3.mp3",
				"ace_weapons/sweps/multi_sound/content/amr/close/close4.mp3",
			}
		},
		mid = {
			Volume	= 1,
			Pitch	= 100,
			Package = {
				"ace_weapons/sweps/multi_sound/content/at4/mid/mid1.mp3",
				"ace_weapons/sweps/multi_sound/content/at4/mid/mid2.mp3",
				"ace_weapons/sweps/multi_sound/content/at4/mid/mid3.mp3",
				"ace_weapons/sweps/multi_sound/content/at4/mid/mid4.mp3",
			}

		},
		far = {
			Volume	= 1,
			Pitch	= 100,
			Package = {
				"ace_weapons/sweps/multi_sound/content/at4/far/far1.mp3",
				"ace_weapons/sweps/multi_sound/content/at4/far/far2.mp3",
				"ace_weapons/sweps/multi_sound/content/at4/far/far3.mp3",
			}
		}
	}
)




--at4 Anti Tank
ACE.DefineGunFireSound( "ace_weapons/sweps/multi_sound/at4_multi.mp3",
	{
		main = {
			Volume	= 1,
			Pitch	= 100,
			Package = {
				"ace_weapons/sweps/multi_sound/content/at4/close/close1.mp3",
				"ace_weapons/sweps/multi_sound/content/at4/close/close2.mp3",
				"ace_weapons/sweps/multi_sound/content/at4/close/close3.mp3",
				"ace_weapons/sweps/multi_sound/content/at4/close/close4.mp3"
			}
		},
		mid = {
			Volume	= 1,
			Pitch	= 100,
			Package = {
				"ace_weapons/sweps/multi_sound/content/at4/mid/mid1.mp3",
				"ace_weapons/sweps/multi_sound/content/at4/mid/mid2.mp3",
				"ace_weapons/sweps/multi_sound/content/at4/mid/mid3.mp3",
				"ace_weapons/sweps/multi_sound/content/at4/mid/mid4.mp3"
			}

		},
		far = {
			Volume	= 1,
			Pitch	= 100,
			Package = {
				"ace_weapons/sweps/multi_sound/content/at4/far/far1.mp3",
				"ace_weapons/sweps/multi_sound/content/at4/far/far2.mp3",
				"ace_weapons/sweps/multi_sound/content/at4/far/far3.mp3",
				"ace_weapons/sweps/multi_sound/content/at4/far/far4.mp3",
			}
		}
	}
)




--at4P Anti Tank Proto
ACE.DefineGunFireSound( "ace_weapons/sweps/multi_sound/at4p_multi.mp3",
	{
		main = {
			Volume	= 1,
			Pitch	= 100,
			Package = {
				"ace_weapons/sweps/multi_sound/content/at4p/close/close1.mp3",
				"ace_weapons/sweps/multi_sound/content/at4p/close/close2.mp3",
				"ace_weapons/sweps/multi_sound/content/at4p/close/close3.mp3",
				"ace_weapons/sweps/multi_sound/content/at4p/close/close4.mp3"
			}
		},
		mid = {
			Volume	= 1,
			Pitch	= 100,
			Package = {
				"ace_weapons/sweps/multi_sound/content/at4p/mid/mid1.mp3",
				"ace_weapons/sweps/multi_sound/content/at4p/mid/mid2.mp3",
				"ace_weapons/sweps/multi_sound/content/at4p/mid/mid3.mp3",
			}

		},
		far = {
			Volume	= 1,
			Pitch	= 100,
			Package = {
				"ace_weapons/sweps/multi_sound/content/at4p/far/far1.mp3",
				"ace_weapons/sweps/multi_sound/content/at4p/far/far2.mp3",
				"ace_weapons/sweps/multi_sound/content/at4p/far/far3.mp3",
				"ace_weapons/sweps/multi_sound/content/at4p/far/far4.mp3",
			}
		}
	}
)

--aug
ACE.DefineGunFireSound( "ace_weapons/sweps/multi_sound/aug_multi.mp3",
	{
		main = {
			Volume	= 1,
			Pitch	= 100,
			Package = {
				"ace_weapons/sweps/multi_sound/content/aug/close/close1.mp3",
				"ace_weapons/sweps/multi_sound/content/aug/close/close2.mp3",
				"ace_weapons/sweps/multi_sound/content/aug/close/close3.mp3",
				"ace_weapons/sweps/multi_sound/content/aug/close/close4.mp3",
				"ace_weapons/sweps/multi_sound/content/aug/close/close5.mp3",
				"ace_weapons/sweps/multi_sound/content/aug/close/close6.mp3",
				"ace_weapons/sweps/multi_sound/content/aug/close/close7.mp3",
				"ace_weapons/sweps/multi_sound/content/aug/close/close8.mp3",
				"ace_weapons/sweps/multi_sound/content/aug/close/close9.mp3",
				"ace_weapons/sweps/multi_sound/content/aug/close/close10.mp3",
			}
		},
		mid = {
			Volume	= 1,
			Pitch	= 100,
			Package = {
				"ace_weapons/sweps/multi_sound/content/aug/mid/mid1.mp3",
				"ace_weapons/sweps/multi_sound/content/aug/mid/mid2.mp3",
				"ace_weapons/sweps/multi_sound/content/aug/mid/mid3.mp3",
				"ace_weapons/sweps/multi_sound/content/aug/mid/mid4.mp3",
				"ace_weapons/sweps/multi_sound/content/aug/mid/mid5.mp3",
				"ace_weapons/sweps/multi_sound/content/aug/mid/mid6.mp3",
				"ace_weapons/sweps/multi_sound/content/aug/mid/mid7.mp3",
				"ace_weapons/sweps/multi_sound/content/aug/mid/mid8.mp3",
				"ace_weapons/sweps/multi_sound/content/aug/mid/mid9.mp3",
				"ace_weapons/sweps/multi_sound/content/aug/mid/mid10.mp3",
			}

		},
		far = {
			Volume	= 1,
			Pitch	= 100,
			Package = {
				"ace_weapons/sweps/multi_sound/content/aug/far/far1.mp3",
				"ace_weapons/sweps/multi_sound/content/aug/far/far2.mp3",
				"ace_weapons/sweps/multi_sound/content/aug/far/far3.mp3",
				"ace_weapons/sweps/multi_sound/content/aug/far/far4.mp3",
				"ace_weapons/sweps/multi_sound/content/aug/far/far5.mp3",
				"ace_weapons/sweps/multi_sound/content/aug/far/far6.mp3",
				"ace_weapons/sweps/multi_sound/content/aug/far/far7.mp3",
				"ace_weapons/sweps/multi_sound/content/aug/far/far8.mp3",
				"ace_weapons/sweps/multi_sound/content/aug/far/far9.mp3",
				"ace_weapons/sweps/multi_sound/content/aug/far/far10.mp3",
			}
		}
	}
)

--awp
ACE.DefineGunFireSound( "ace_weapons/sweps/multi_sound/awp_multi.mp3",
{
	main = {
		Volume	= 1,
		Pitch	= 100,
		Package = {
			"ace_weapons/sweps/multi_sound/content/awp/close/close1.mp3",
			"ace_weapons/sweps/multi_sound/content/awp/close/close2.mp3",
			"ace_weapons/sweps/multi_sound/content/awp/close/close3.mp3",
			"ace_weapons/sweps/multi_sound/content/awp/close/close4.mp3",
			"ace_weapons/sweps/multi_sound/content/awp/close/close5.mp3",
		}
	},
	mid = {
		Volume	= 1,
		Pitch	= 100,
		Package = {
			"ace_weapons/sweps/multi_sound/content/awp/mid/mid1.mp3",
			"ace_weapons/sweps/multi_sound/content/awp/mid/mid2.mp3",
			"ace_weapons/sweps/multi_sound/content/awp/mid/mid3.mp3",
			"ace_weapons/sweps/multi_sound/content/awp/mid/mid4.mp3",
			"ace_weapons/sweps/multi_sound/content/awp/mid/mid5.mp3",
		}

	},
	far = {
		Volume	= 1,
		Pitch	= 100,
		Package = {
			"ace_weapons/sweps/multi_sound/content/awp/far/far1.mp3",
			"ace_weapons/sweps/multi_sound/content/awp/far/far2.mp3",
			"ace_weapons/sweps/multi_sound/content/awp/far/far3.mp3",
			"ace_weapons/sweps/multi_sound/content/awp/far/far4.mp3",
			"ace_weapons/sweps/multi_sound/content/awp/far/far5.mp3",
		}
	}
}
)

--deagle
ACE.DefineGunFireSound( "ace_weapons/sweps/multi_sound/deagle_multi.mp3",
{
	main = {
		Volume	= 1,
		Pitch	= 100,
		Package = {
			"ace_weapons/sweps/multi_sound/content/deagle/close/close1.mp3",
			"ace_weapons/sweps/multi_sound/content/deagle/close/close2.mp3",
			"ace_weapons/sweps/multi_sound/content/deagle/close/close3.mp3",
			"ace_weapons/sweps/multi_sound/content/deagle/close/close4.mp3",
		}
	}
}
)


--deagle
ACE.DefineGunFireSound( "ace_weapons/sweps/multi_sound/elite_multi.mp3",
{
	main = {
		Volume	= 1,
		Pitch	= 100,
		Package = {
			"ace_weapons/sweps/multi_sound/content/elite/close/close1.mp3",
			"ace_weapons/sweps/multi_sound/content/elite/close/close2.mp3",
			"ace_weapons/sweps/multi_sound/content/elite/close/close3.mp3",
			"ace_weapons/sweps/multi_sound/content/elite/close/close4.mp3",
		}
	}
}
)

--famas
ACE.DefineGunFireSound( "ace_weapons/sweps/multi_sound/famas_multi.mp3",
{
	main = {
		Volume	= 1,
		Pitch	= 100,
		Package = {
			"ace_weapons/sweps/multi_sound/content/famas/close/close1.mp3",
			"ace_weapons/sweps/multi_sound/content/famas/close/close2.mp3",
			"ace_weapons/sweps/multi_sound/content/famas/close/close3.mp3",
			"ace_weapons/sweps/multi_sound/content/famas/close/close4.mp3",
			"ace_weapons/sweps/multi_sound/content/famas/close/close5.mp3",
			"ace_weapons/sweps/multi_sound/content/famas/close/close6.mp3",
			"ace_weapons/sweps/multi_sound/content/famas/close/close7.mp3",
			"ace_weapons/sweps/multi_sound/content/famas/close/close8.mp3",
			"ace_weapons/sweps/multi_sound/content/famas/close/close9.mp3",
			"ace_weapons/sweps/multi_sound/content/famas/close/close10.mp3",
		}
	},
	mid = {
		Volume	= 1,
		Pitch	= 100,
		Package = {
			"ace_weapons/sweps/multi_sound/content/famas/mid/mid1.mp3",
			"ace_weapons/sweps/multi_sound/content/famas/mid/mid2.mp3",
			"ace_weapons/sweps/multi_sound/content/famas/mid/mid3.mp3",
			"ace_weapons/sweps/multi_sound/content/famas/mid/mid4.mp3",
			"ace_weapons/sweps/multi_sound/content/famas/mid/mid5.mp3",
			"ace_weapons/sweps/multi_sound/content/famas/mid/mid6.mp3",
			"ace_weapons/sweps/multi_sound/content/famas/mid/mid7.mp3",
			"ace_weapons/sweps/multi_sound/content/famas/mid/mid8.mp3",
			"ace_weapons/sweps/multi_sound/content/famas/mid/mid9.mp3",
			"ace_weapons/sweps/multi_sound/content/famas/mid/mid10.mp3",
		}

	},
	far = {
		Volume	= 1,
		Pitch	= 100,
		Package = {
			"ace_weapons/sweps/multi_sound/content/famas/far/far1.mp3",
			"ace_weapons/sweps/multi_sound/content/famas/far/far2.mp3",
			"ace_weapons/sweps/multi_sound/content/famas/far/far3.mp3",
			"ace_weapons/sweps/multi_sound/content/famas/far/far4.mp3",
			"ace_weapons/sweps/multi_sound/content/famas/far/far5.mp3",
			"ace_weapons/sweps/multi_sound/content/famas/far/far6.mp3",
			"ace_weapons/sweps/multi_sound/content/famas/far/far7.mp3",
			"ace_weapons/sweps/multi_sound/content/famas/far/far8.mp3",
			"ace_weapons/sweps/multi_sound/content/famas/far/far9.mp3",
			"ace_weapons/sweps/multi_sound/content/famas/far/far10.mp3",
		}
	}
}
)

--fiveseven
ACE.DefineGunFireSound( "ace_weapons/sweps/multi_sound/fiveseven_multi.mp3",
{
	main = {
		Volume	= 1,
		Pitch	= 100,
		Package = {
			"ace_weapons/sweps/multi_sound/content/fiveseven/close/close1.mp3",
			"ace_weapons/sweps/multi_sound/content/fiveseven/close/close2.mp3",
			"ace_weapons/sweps/multi_sound/content/fiveseven/close/close3.mp3",
			"ace_weapons/sweps/multi_sound/content/fiveseven/close/close4.mp3",
			"ace_weapons/sweps/multi_sound/content/fiveseven/close/close5.mp3",
			"ace_weapons/sweps/multi_sound/content/fiveseven/close/close6.mp3",
			"ace_weapons/sweps/multi_sound/content/fiveseven/close/close7.mp3",
		}
	}
}
)

--galil
ACE.DefineGunFireSound( "ace_weapons/sweps/multi_sound/galil_multi.mp3",
{
	main = {
		Volume	= 1,
		Pitch	= 100,
		Package = {
			"ace_weapons/sweps/multi_sound/content/galil/close/close1.mp3",
			"ace_weapons/sweps/multi_sound/content/galil/close/close2.mp3",
			"ace_weapons/sweps/multi_sound/content/galil/close/close3.mp3",
			"ace_weapons/sweps/multi_sound/content/galil/close/close4.mp3",
			"ace_weapons/sweps/multi_sound/content/galil/close/close5.mp3",
			"ace_weapons/sweps/multi_sound/content/galil/close/close6.mp3",
			"ace_weapons/sweps/multi_sound/content/galil/close/close7.mp3",
			"ace_weapons/sweps/multi_sound/content/galil/close/close8.mp3",
			"ace_weapons/sweps/multi_sound/content/galil/close/close9.mp3",
			"ace_weapons/sweps/multi_sound/content/galil/close/close10.mp3",
		}
	},
	mid = {
		Volume	= 1,
		Pitch	= 100,
		Package = {
			"ace_weapons/sweps/multi_sound/content/galil/mid/mid1.mp3",
			"ace_weapons/sweps/multi_sound/content/galil/mid/mid2.mp3",
			"ace_weapons/sweps/multi_sound/content/galil/mid/mid3.mp3",
			"ace_weapons/sweps/multi_sound/content/galil/mid/mid4.mp3",
			"ace_weapons/sweps/multi_sound/content/galil/mid/mid5.mp3",
			"ace_weapons/sweps/multi_sound/content/galil/mid/mid6.mp3",
			"ace_weapons/sweps/multi_sound/content/galil/mid/mid7.mp3",
			"ace_weapons/sweps/multi_sound/content/galil/mid/mid8.mp3",
			"ace_weapons/sweps/multi_sound/content/galil/mid/mid9.mp3",
			"ace_weapons/sweps/multi_sound/content/galil/mid/mid10.mp3",
		}

	},
	far = {
		Volume	= 1,
		Pitch	= 100,
		Package = {
			"ace_weapons/sweps/multi_sound/content/galil/far/far1.mp3",
			"ace_weapons/sweps/multi_sound/content/galil/far/far2.mp3",
			"ace_weapons/sweps/multi_sound/content/galil/far/far3.mp3",
			"ace_weapons/sweps/multi_sound/content/galil/far/far4.mp3",
			"ace_weapons/sweps/multi_sound/content/galil/far/far5.mp3",
			"ace_weapons/sweps/multi_sound/content/galil/far/far6.mp3",
			"ace_weapons/sweps/multi_sound/content/galil/far/far7.mp3",
			"ace_weapons/sweps/multi_sound/content/galil/far/far8.mp3",
			"ace_weapons/sweps/multi_sound/content/galil/far/far9.mp3",
			"ace_weapons/sweps/multi_sound/content/galil/far/far10.mp3",
		}
	}
}
)

--glock
ACE.DefineGunFireSound( "ace_weapons/sweps/multi_sound/glock_multi.mp3",
{
	main = {
		Volume	= 1,
		Pitch	= 100,
		Package = {
			"ace_weapons/sweps/multi_sound/content/glock/close/close1.mp3",
			"ace_weapons/sweps/multi_sound/content/glock/close/close2.mp3",
			"ace_weapons/sweps/multi_sound/content/glock/close/close3.mp3",
			"ace_weapons/sweps/multi_sound/content/glock/close/close4.mp3",
			"ace_weapons/sweps/multi_sound/content/glock/close/close5.mp3",
			"ace_weapons/sweps/multi_sound/content/glock/close/close6.mp3",
		}
	}
}
)

--m3super90
ACE.DefineGunFireSound( "ace_weapons/sweps/multi_sound/m3super90_multi.mp3",
{
	main = {
		Volume	= 1,
		Pitch	= 100,
		Package = {
			"ace_weapons/sweps/multi_sound/content/m3super90/close/close1.mp3",
			"ace_weapons/sweps/multi_sound/content/m3super90/close/close2.mp3",
			"ace_weapons/sweps/multi_sound/content/m3super90/close/close3.mp3",
			"ace_weapons/sweps/multi_sound/content/m3super90/close/close4.mp3",
			"ace_weapons/sweps/multi_sound/content/m3super90/close/close5.mp3",
			"ace_weapons/sweps/multi_sound/content/m3super90/close/close6.mp3",
			"ace_weapons/sweps/multi_sound/content/m3super90/close/close7.mp3",
		}
	},
	mid = {
		Volume	= 1,
		Pitch	= 100,
		Package = {
			"ace_weapons/sweps/multi_sound/content/m3super90/mid/mid1.mp3",
			"ace_weapons/sweps/multi_sound/content/m3super90/mid/mid2.mp3",
			"ace_weapons/sweps/multi_sound/content/m3super90/mid/mid3.mp3",
			"ace_weapons/sweps/multi_sound/content/m3super90/mid/mid4.mp3",
			"ace_weapons/sweps/multi_sound/content/m3super90/mid/mid5.mp3",
			"ace_weapons/sweps/multi_sound/content/m3super90/mid/mid6.mp3",
		}

	},
}
)

--m16mm gunfire
ACE.DefineGunFireSound( "ace_weapons/sweps/multi_sound/m16_multi.mp3",
{
	main = {
		Volume	= 1,
		Pitch	= 100,
		Package = {
			"ace_weapons/sweps/multi_sound/content/m16/close/close1.mp3",
			"ace_weapons/sweps/multi_sound/content/m16/close/close2.mp3",
			"ace_weapons/sweps/multi_sound/content/m16/close/close3.mp3",
			"ace_weapons/sweps/multi_sound/content/m16/close/close4.mp3",
			"ace_weapons/sweps/multi_sound/content/m16/close/close5.mp3",
			"ace_weapons/sweps/multi_sound/content/m16/close/close6.mp3"
		}
	},
	mid = {
		Volume	= 1,
		Pitch	= 100,
		Package = {
			"ace_weapons/sweps/multi_sound/content/m16/mid/mid1.mp3",
			"ace_weapons/sweps/multi_sound/content/m16/mid/mid2.mp3",
			"ace_weapons/sweps/multi_sound/content/m16/mid/mid3.mp3",
			"ace_weapons/sweps/multi_sound/content/m16/mid/mid4.mp3",
			"ace_weapons/sweps/multi_sound/content/m16/mid/mid5.mp3",
			"ace_weapons/sweps/multi_sound/content/m16/mid/mid6.mp3"
		}

	},
	far = {
		Volume	= 1,
		Pitch	= 100,
		Package = {
			"ace_weapons/sweps/multi_sound/content/m16/far/far1.mp3",
			"ace_weapons/sweps/multi_sound/content/m16/far/far2.mp3",
			"ace_weapons/sweps/multi_sound/content/m16/far/far3.mp3",
			"ace_weapons/sweps/multi_sound/content/m16/far/far4.mp3",
			"ace_weapons/sweps/multi_sound/content/m16/far/far5.mp3",
			"ace_weapons/sweps/multi_sound/content/m16/far/far6.mp3"
		}
	}
}
)

--m249saw
ACE.DefineGunFireSound( "ace_weapons/sweps/multi_sound/m249saw_multi.mp3",
{
	main = {
		Volume	= 1,
		Pitch	= 100,
		Package = {
			"ace_weapons/sweps/multi_sound/content/m249saw/close/close1.mp3",
			"ace_weapons/sweps/multi_sound/content/m249saw/close/close2.mp3",
			"ace_weapons/sweps/multi_sound/content/m249saw/close/close3.mp3",
			"ace_weapons/sweps/multi_sound/content/m249saw/close/close4.mp3",
			"ace_weapons/sweps/multi_sound/content/m249saw/close/close5.mp3",
			"ace_weapons/sweps/multi_sound/content/m249saw/close/close6.mp3",
			"ace_weapons/sweps/multi_sound/content/m249saw/close/close7.mp3",
			"ace_weapons/sweps/multi_sound/content/m249saw/close/close8.mp3",
			"ace_weapons/sweps/multi_sound/content/m249saw/close/close9.mp3",
			"ace_weapons/sweps/multi_sound/content/m249saw/close/close10.mp3",
		}
	},
	mid = {
		Volume	= 1,
		Pitch	= 100,
		Package = {
			"ace_weapons/sweps/multi_sound/content/m249saw/mid/mid1.mp3",
			"ace_weapons/sweps/multi_sound/content/m249saw/mid/mid2.mp3",
			"ace_weapons/sweps/multi_sound/content/m249saw/mid/mid3.mp3",
			"ace_weapons/sweps/multi_sound/content/m249saw/mid/mid4.mp3",
			"ace_weapons/sweps/multi_sound/content/m249saw/mid/mid5.mp3",
			"ace_weapons/sweps/multi_sound/content/m249saw/mid/mid6.mp3",
			"ace_weapons/sweps/multi_sound/content/m249saw/mid/mid7.mp3",
			"ace_weapons/sweps/multi_sound/content/m249saw/mid/mid8.mp3",
			"ace_weapons/sweps/multi_sound/content/m249saw/mid/mid9.mp3",
			"ace_weapons/sweps/multi_sound/content/m249saw/mid/mid10.mp3",
		}

	},
	far = {
		Volume	= 1,
		Pitch	= 100,
		Package = {
			"ace_weapons/sweps/multi_sound/content/m249saw/far/far1.mp3",
			"ace_weapons/sweps/multi_sound/content/m249saw/far/far2.mp3",
			"ace_weapons/sweps/multi_sound/content/m249saw/far/far3.mp3",
			"ace_weapons/sweps/multi_sound/content/m249saw/far/far4.mp3",
			"ace_weapons/sweps/multi_sound/content/m249saw/far/far5.mp3",
			"ace_weapons/sweps/multi_sound/content/m249saw/far/far6.mp3",
			"ace_weapons/sweps/multi_sound/content/m249saw/far/far7.mp3",
			"ace_weapons/sweps/multi_sound/content/m249saw/far/far8.mp3",
			"ace_weapons/sweps/multi_sound/content/m249saw/far/far9.mp3",
			"ace_weapons/sweps/multi_sound/content/m249saw/far/far10.mp3",
		}
	}
}
)

--mac10
ACE.DefineGunFireSound( "ace_weapons/sweps/multi_sound/mac10_multi.mp3",
{
	main = {
		Volume	= 1,
		Pitch	= 100,
		Package = {
			"ace_weapons/sweps/multi_sound/content/mac10/close/close1.mp3",
			"ace_weapons/sweps/multi_sound/content/mac10/close/close2.mp3",
			"ace_weapons/sweps/multi_sound/content/mac10/close/close3.mp3",
			"ace_weapons/sweps/multi_sound/content/mac10/close/close4.mp3",
			"ace_weapons/sweps/multi_sound/content/mac10/close/close5.mp3",
			"ace_weapons/sweps/multi_sound/content/mac10/close/close6.mp3",
			"ace_weapons/sweps/multi_sound/content/mac10/close/close7.mp3",
			"ace_weapons/sweps/multi_sound/content/mac10/close/close8.mp3",
			"ace_weapons/sweps/multi_sound/content/mac10/close/close9.mp3",
			"ace_weapons/sweps/multi_sound/content/mac10/close/close10.mp3",
		}
	},
	mid = {
		Volume	= 1,
		Pitch	= 100,
		Package = {
			"ace_weapons/sweps/multi_sound/content/mac10/mid/mid1.mp3",
			"ace_weapons/sweps/multi_sound/content/mac10/mid/mid2.mp3",
			"ace_weapons/sweps/multi_sound/content/mac10/mid/mid3.mp3",
			"ace_weapons/sweps/multi_sound/content/mac10/mid/mid4.mp3",
			"ace_weapons/sweps/multi_sound/content/mac10/mid/mid5.mp3",
			"ace_weapons/sweps/multi_sound/content/mac10/mid/mid6.mp3",
			"ace_weapons/sweps/multi_sound/content/mac10/mid/mid7.mp3",
			"ace_weapons/sweps/multi_sound/content/mac10/mid/mid8.mp3",
			"ace_weapons/sweps/multi_sound/content/mac10/mid/mid9.mp3",
			"ace_weapons/sweps/multi_sound/content/mac10/mid/mid10.mp3",
		}

	},
	far = {
		Volume	= 1,
		Pitch	= 100,
		Package = {
			"ace_weapons/sweps/multi_sound/content/mac10/far/far1.mp3",
			"ace_weapons/sweps/multi_sound/content/mac10/far/far2.mp3",
			"ace_weapons/sweps/multi_sound/content/mac10/far/far3.mp3",
			"ace_weapons/sweps/multi_sound/content/mac10/far/far4.mp3",
			"ace_weapons/sweps/multi_sound/content/mac10/far/far5.mp3",
			"ace_weapons/sweps/multi_sound/content/mac10/far/far6.mp3",
			"ace_weapons/sweps/multi_sound/content/mac10/far/far7.mp3",
			"ace_weapons/sweps/multi_sound/content/mac10/far/far8.mp3",
		}
	}
}
)

--mp5
ACE.DefineGunFireSound( "ace_weapons/sweps/multi_sound/mp5_multi.mp3",
{
	main = {
		Volume	= 1,
		Pitch	= 100,
		Package = {
			"ace_weapons/sweps/multi_sound/content/mp5/close/close1.mp3",
			"ace_weapons/sweps/multi_sound/content/mp5/close/close2.mp3",
			"ace_weapons/sweps/multi_sound/content/mp5/close/close3.mp3",
			"ace_weapons/sweps/multi_sound/content/mp5/close/close4.mp3",
			"ace_weapons/sweps/multi_sound/content/mp5/close/close5.mp3",
			"ace_weapons/sweps/multi_sound/content/mp5/close/close6.mp3",
			"ace_weapons/sweps/multi_sound/content/mp5/close/close7.mp3",
			"ace_weapons/sweps/multi_sound/content/mp5/close/close8.mp3",
			"ace_weapons/sweps/multi_sound/content/mp5/close/close9.mp3",
			"ace_weapons/sweps/multi_sound/content/mp5/close/close10.mp3",
		}
	},
	mid = {
		Volume	= 1,
		Pitch	= 100,
		Package = {
			"ace_weapons/sweps/multi_sound/content/mp5/mid/mid1.mp3",
			"ace_weapons/sweps/multi_sound/content/mp5/mid/mid2.mp3",
			"ace_weapons/sweps/multi_sound/content/mp5/mid/mid3.mp3",
			"ace_weapons/sweps/multi_sound/content/mp5/mid/mid4.mp3",
			"ace_weapons/sweps/multi_sound/content/mp5/mid/mid5.mp3",
			"ace_weapons/sweps/multi_sound/content/mp5/mid/mid6.mp3",
			"ace_weapons/sweps/multi_sound/content/mp5/mid/mid7.mp3",
			"ace_weapons/sweps/multi_sound/content/mp5/mid/mid8.mp3",
			"ace_weapons/sweps/multi_sound/content/mp5/mid/mid9.mp3",
			"ace_weapons/sweps/multi_sound/content/mp5/mid/mid10.mp3",
		}

	},
	far = {
		Volume	= 1,
		Pitch	= 100,
		Package = {
			"ace_weapons/sweps/multi_sound/content/mp5/far/far1.mp3",
			"ace_weapons/sweps/multi_sound/content/mp5/far/far2.mp3",
			"ace_weapons/sweps/multi_sound/content/mp5/far/far3.mp3",
			"ace_weapons/sweps/multi_sound/content/mp5/far/far4.mp3",
			"ace_weapons/sweps/multi_sound/content/mp5/far/far5.mp3",
			"ace_weapons/sweps/multi_sound/content/mp5/far/far6.mp3",
			"ace_weapons/sweps/multi_sound/content/mp5/far/far7.mp3",
			"ace_weapons/sweps/multi_sound/content/mp5/far/far8.mp3",
		}
	}
}
)

--p90
ACE.DefineGunFireSound( "ace_weapons/sweps/multi_sound/p90_multi.mp3",
{
	main = {
		Volume	= 1,
		Pitch	= 100,
		Package = {
			"ace_weapons/sweps/multi_sound/content/p90/close/close1.mp3",
			"ace_weapons/sweps/multi_sound/content/p90/close/close2.mp3",
			"ace_weapons/sweps/multi_sound/content/p90/close/close3.mp3",
			"ace_weapons/sweps/multi_sound/content/p90/close/close4.mp3",
			"ace_weapons/sweps/multi_sound/content/p90/close/close5.mp3",
			"ace_weapons/sweps/multi_sound/content/p90/close/close6.mp3",
			"ace_weapons/sweps/multi_sound/content/p90/close/close7.mp3",
			"ace_weapons/sweps/multi_sound/content/p90/close/close8.mp3",
			"ace_weapons/sweps/multi_sound/content/p90/close/close9.mp3",
			"ace_weapons/sweps/multi_sound/content/p90/close/close10.mp3",
		}
	},
	mid = {
		Volume	= 1,
		Pitch	= 100,
		Package = {
			"ace_weapons/sweps/multi_sound/content/p90/mid/mid1.mp3",
			"ace_weapons/sweps/multi_sound/content/p90/mid/mid2.mp3",
			"ace_weapons/sweps/multi_sound/content/p90/mid/mid3.mp3",
			"ace_weapons/sweps/multi_sound/content/p90/mid/mid4.mp3",
			"ace_weapons/sweps/multi_sound/content/p90/mid/mid5.mp3",
			"ace_weapons/sweps/multi_sound/content/p90/mid/mid6.mp3",
			"ace_weapons/sweps/multi_sound/content/p90/mid/mid7.mp3",
			"ace_weapons/sweps/multi_sound/content/p90/mid/mid8.mp3",
			"ace_weapons/sweps/multi_sound/content/p90/mid/mid9.mp3",
			"ace_weapons/sweps/multi_sound/content/p90/mid/mid10.mp3"
		}

	},
	far = {
		Volume	= 1,
		Pitch	= 100,
		Package = {
			"ace_weapons/sweps/multi_sound/content/p90/far/far1.mp3",
			"ace_weapons/sweps/multi_sound/content/p90/far/far2.mp3",
			"ace_weapons/sweps/multi_sound/content/p90/far/far3.mp3",
			"ace_weapons/sweps/multi_sound/content/p90/far/far4.mp3",
			"ace_weapons/sweps/multi_sound/content/p90/far/far5.mp3",
			"ace_weapons/sweps/multi_sound/content/p90/far/far6.mp3",
			"ace_weapons/sweps/multi_sound/content/p90/far/far7.mp3",
			"ace_weapons/sweps/multi_sound/content/p90/far/far8.mp3"
		}
	}
}
)

--p228
ACE.DefineGunFireSound( "ace_weapons/sweps/multi_sound/p228_multi.mp3",
{
	main = {
		Volume	= 1,
		Pitch	= 100,
		Package = {
			"ace_weapons/sweps/multi_sound/content/p228/close/close1.mp3",
			"ace_weapons/sweps/multi_sound/content/p228/close/close2.mp3",
			"ace_weapons/sweps/multi_sound/content/p228/close/close3.mp3",
			"ace_weapons/sweps/multi_sound/content/p228/close/close4.mp3",
			"ace_weapons/sweps/multi_sound/content/p228/close/close5.mp3",
		}
	}
}
)

--scout
ACE.DefineGunFireSound( "ace_weapons/sweps/multi_sound/scout_multi.mp3",
{
	main = {
		Volume	= 1,
		Pitch	= 100,
		Package = {
			"ace_weapons/sweps/multi_sound/content/scout/close/close1.mp3",
			"ace_weapons/sweps/multi_sound/content/scout/close/close2.mp3",
			"ace_weapons/sweps/multi_sound/content/scout/close/close3.mp3",
			"ace_weapons/sweps/multi_sound/content/scout/close/close4.mp3",
			"ace_weapons/sweps/multi_sound/content/scout/close/close5.mp3",
			"ace_weapons/sweps/multi_sound/content/scout/close/close6.mp3"
		}
	},
	mid = {
		Volume	= 1,
		Pitch	= 100,
		Package = {
			"ace_weapons/sweps/multi_sound/content/scout/mid/mid1.mp3",
			"ace_weapons/sweps/multi_sound/content/scout/mid/mid2.mp3",
			"ace_weapons/sweps/multi_sound/content/scout/mid/mid3.mp3",
			"ace_weapons/sweps/multi_sound/content/scout/mid/mid4.mp3",
			"ace_weapons/sweps/multi_sound/content/scout/mid/mid5.mp3",
			"ace_weapons/sweps/multi_sound/content/scout/mid/mid6.mp3",
			"ace_weapons/sweps/multi_sound/content/scout/mid/mid7.mp3"
		}

	},
	far = {
		Volume	= 1,
		Pitch	= 100,
		Package = {
			"ace_weapons/sweps/multi_sound/content/scout/far/far1.mp3",
			"ace_weapons/sweps/multi_sound/content/scout/far/far2.mp3",
			"ace_weapons/sweps/multi_sound/content/scout/far/far3.mp3",
			"ace_weapons/sweps/multi_sound/content/scout/far/far4.mp3",
			"ace_weapons/sweps/multi_sound/content/scout/far/far5.mp3",
			"ace_weapons/sweps/multi_sound/content/scout/far/far6.mp3",
			"ace_weapons/sweps/multi_sound/content/scout/far/far7.mp3",
			"ace_weapons/sweps/multi_sound/content/scout/far/far8.mp3",
			"ace_weapons/sweps/multi_sound/content/scout/far/far9.mp3",
		}
	}
}
)

--sg552
ACE.DefineGunFireSound( "ace_weapons/sweps/multi_sound/sg552_multi.mp3",
{
	main = {
		Volume	= 1,
		Pitch	= 100,
		Package = {
			"ace_weapons/sweps/multi_sound/content/sg552/close/close1.mp3",
			"ace_weapons/sweps/multi_sound/content/sg552/close/close2.mp3",
			"ace_weapons/sweps/multi_sound/content/sg552/close/close3.mp3",
			"ace_weapons/sweps/multi_sound/content/sg552/close/close4.mp3",
			"ace_weapons/sweps/multi_sound/content/sg552/close/close5.mp3",
			"ace_weapons/sweps/multi_sound/content/sg552/close/close6.mp3",
			"ace_weapons/sweps/multi_sound/content/sg552/close/close7.mp3",
			"ace_weapons/sweps/multi_sound/content/sg552/close/close8.mp3",
			"ace_weapons/sweps/multi_sound/content/sg552/close/close9.mp3",
			"ace_weapons/sweps/multi_sound/content/sg552/close/close10.mp3"
		}
	},
	mid = {
		Volume	= 1,
		Pitch	= 100,
		Package = {
			"ace_weapons/sweps/multi_sound/content/sg552/mid/mid1.mp3",
			"ace_weapons/sweps/multi_sound/content/sg552/mid/mid2.mp3",
			"ace_weapons/sweps/multi_sound/content/sg552/mid/mid3.mp3",
			"ace_weapons/sweps/multi_sound/content/sg552/mid/mid4.mp3",
			"ace_weapons/sweps/multi_sound/content/sg552/mid/mid5.mp3",
			"ace_weapons/sweps/multi_sound/content/sg552/mid/mid6.mp3",
			"ace_weapons/sweps/multi_sound/content/sg552/mid/mid7.mp3",
			"ace_weapons/sweps/multi_sound/content/sg552/mid/mid8.mp3",
			"ace_weapons/sweps/multi_sound/content/sg552/mid/mid9.mp3",
			"ace_weapons/sweps/multi_sound/content/sg552/mid/mid10.mp3"
		}

	},
	far = {
		Volume	= 1,
		Pitch	= 100,
		Package = {
			"ace_weapons/sweps/multi_sound/content/sg552/far/far1.mp3",
			"ace_weapons/sweps/multi_sound/content/sg552/far/far2.mp3",
			"ace_weapons/sweps/multi_sound/content/sg552/far/far3.mp3",
			"ace_weapons/sweps/multi_sound/content/sg552/far/far4.mp3",
			"ace_weapons/sweps/multi_sound/content/sg552/far/far5.mp3",
			"ace_weapons/sweps/multi_sound/content/sg552/far/far6.mp3",
			"ace_weapons/sweps/multi_sound/content/sg552/far/far7.mp3",
			"ace_weapons/sweps/multi_sound/content/sg552/far/far8.mp3",
			"ace_weapons/sweps/multi_sound/content/sg552/far/far9.mp3",
			"ace_weapons/sweps/multi_sound/content/sg552/far/far10.mp3",
		}
	}
}
)

--tmp
ACE.DefineGunFireSound( "ace_weapons/sweps/multi_sound/tmp_multi.mp3",
{
	main = {
		Volume	= 1,
		Pitch	= 100,
		Package = {
			"ace_weapons/sweps/multi_sound/content/tmp/close/close1.mp3",
			"ace_weapons/sweps/multi_sound/content/tmp/close/close2.mp3",
			"ace_weapons/sweps/multi_sound/content/tmp/close/close3.mp3",
			"ace_weapons/sweps/multi_sound/content/tmp/close/close4.mp3",
			"ace_weapons/sweps/multi_sound/content/tmp/close/close5.mp3",
			"ace_weapons/sweps/multi_sound/content/tmp/close/close6.mp3",
			"ace_weapons/sweps/multi_sound/content/tmp/close/close7.mp3",
			"ace_weapons/sweps/multi_sound/content/tmp/close/close8.mp3",
			"ace_weapons/sweps/multi_sound/content/tmp/close/close9.mp3",
			"ace_weapons/sweps/multi_sound/content/tmp/close/close10.mp3"
		}
	},
}
)

--ump45
ACE.DefineGunFireSound( "ace_weapons/sweps/multi_sound/ump45_multi.mp3",
{
	main = {
		Volume	= 1,
		Pitch	= 100,
		Package = {
			"ace_weapons/sweps/multi_sound/content/ump45/close/close1.mp3",
			"ace_weapons/sweps/multi_sound/content/ump45/close/close2.mp3",
			"ace_weapons/sweps/multi_sound/content/ump45/close/close3.mp3",
			"ace_weapons/sweps/multi_sound/content/ump45/close/close4.mp3",
			"ace_weapons/sweps/multi_sound/content/ump45/close/close5.mp3",
			"ace_weapons/sweps/multi_sound/content/ump45/close/close6.mp3",
			"ace_weapons/sweps/multi_sound/content/ump45/close/close7.mp3",
			"ace_weapons/sweps/multi_sound/content/ump45/close/close8.mp3",
			"ace_weapons/sweps/multi_sound/content/ump45/close/close9.mp3",
			"ace_weapons/sweps/multi_sound/content/ump45/close/close10.mp3"
		}
	},
	mid = {
		Volume	= 1,
		Pitch	= 100,
		Package = {
			"ace_weapons/sweps/multi_sound/content/ump45/mid/mid1.mp3",
			"ace_weapons/sweps/multi_sound/content/ump45/mid/mid2.mp3",
			"ace_weapons/sweps/multi_sound/content/ump45/mid/mid3.mp3",
			"ace_weapons/sweps/multi_sound/content/ump45/mid/mid4.mp3",
			"ace_weapons/sweps/multi_sound/content/ump45/mid/mid5.mp3",
			"ace_weapons/sweps/multi_sound/content/ump45/mid/mid6.mp3",
			"ace_weapons/sweps/multi_sound/content/ump45/mid/mid7.mp3",
			"ace_weapons/sweps/multi_sound/content/ump45/mid/mid8.mp3",
			"ace_weapons/sweps/multi_sound/content/ump45/mid/mid9.mp3",
			"ace_weapons/sweps/multi_sound/content/ump45/mid/mid10.mp3"
		}

	},
	far = {
		Volume	= 1,
		Pitch	= 100,
		Package = {
			"ace_weapons/sweps/multi_sound/content/ump45/far/far1.mp3",
			"ace_weapons/sweps/multi_sound/content/ump45/far/far2.mp3",
			"ace_weapons/sweps/multi_sound/content/ump45/far/far3.mp3",
			"ace_weapons/sweps/multi_sound/content/ump45/far/far4.mp3",
			"ace_weapons/sweps/multi_sound/content/ump45/far/far5.mp3",
			"ace_weapons/sweps/multi_sound/content/ump45/far/far6.mp3",
			"ace_weapons/sweps/multi_sound/content/ump45/far/far7.mp3",
			"ace_weapons/sweps/multi_sound/content/ump45/far/far8.mp3"
		}
	}
}
)

--usp
ACE.DefineGunFireSound( "ace_weapons/sweps/multi_sound/usp_multi.mp3",
{
	main = {
		Volume	= 1,
		Pitch	= 100,
		Package = {
			"ace_weapons/sweps/multi_sound/content/usp/close/close1.mp3",
			"ace_weapons/sweps/multi_sound/content/usp/close/close2.mp3",
			"ace_weapons/sweps/multi_sound/content/usp/close/close3.mp3",
			"ace_weapons/sweps/multi_sound/content/usp/close/close4.mp3",
			"ace_weapons/sweps/multi_sound/content/usp/close/close5.mp3",
		}
	},
}
)

--xm25
ACE.DefineGunFireSound( "ace_weapons/sweps/multi_sound/xm25_multi.mp3",
{
	main = {
		Volume	= 1,
		Pitch	= 100,
		Package = {
			"ace_weapons/sweps/multi_sound/content/xm25/close/close1.mp3",
			"ace_weapons/sweps/multi_sound/content/xm25/close/close2.mp3",
			"ace_weapons/sweps/multi_sound/content/xm25/close/close3.mp3",
			"ace_weapons/sweps/multi_sound/content/xm25/close/close4.mp3",
			"ace_weapons/sweps/multi_sound/content/xm25/close/close5.mp3",
			"ace_weapons/sweps/multi_sound/content/xm25/close/close6.mp3",
			"ace_weapons/sweps/multi_sound/content/xm25/close/close7.mp3",
			"ace_weapons/sweps/multi_sound/content/xm25/close/close8.mp3",
		}
	},
}
)

--xm1014mm gunfire
ACE.DefineGunFireSound( "ace_weapons/sweps/multi_sound/xm1014_multi.mp3",
{
	main = {
		Volume	= 1,
		Pitch	= 100,
		Package = {
			"ace_weapons/sweps/multi_sound/content/xm1014/close/close1.mp3",
			"ace_weapons/sweps/multi_sound/content/xm1014/close/close2.mp3",
			"ace_weapons/sweps/multi_sound/content/xm1014/close/close3.mp3",
			"ace_weapons/sweps/multi_sound/content/xm1014/close/close4.mp3",
			"ace_weapons/sweps/multi_sound/content/xm1014/close/close5.mp3",
			"ace_weapons/sweps/multi_sound/content/xm1014/close/close6.mp3"
		}
	},
	mid = {
		Volume	= 1,
		Pitch	= 100,
		Package = {
			"ace_weapons/sweps/multi_sound/content/xm1014/mid/mid1.mp3",
			"ace_weapons/sweps/multi_sound/content/xm1014/mid/mid2.mp3",
			"ace_weapons/sweps/multi_sound/content/xm1014/mid/mid3.mp3",
			"ace_weapons/sweps/multi_sound/content/xm1014/mid/mid4.mp3",
			"ace_weapons/sweps/multi_sound/content/xm1014/mid/mid5.mp3",
			"ace_weapons/sweps/multi_sound/content/xm1014/mid/mid6.mp3"
		}

	},
	far = {
		Volume	= 1,
		Pitch	= 100,
		Package = {
			"ace_weapons/sweps/multi_sound/content/xm1014/far/far1.mp3",
			"ace_weapons/sweps/multi_sound/content/xm1014/far/far2.mp3",
			"ace_weapons/sweps/multi_sound/content/xm1014/far/far3.mp3",
			"ace_weapons/sweps/multi_sound/content/xm1014/far/far4.mp3",
			"ace_weapons/sweps/multi_sound/content/xm1014/far/far5.mp3",
			"ace_weapons/sweps/multi_sound/content/xm1014/far/far6.mp3"
		}
	}
}
)
