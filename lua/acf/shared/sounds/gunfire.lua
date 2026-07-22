--Little desc for every value here:

--ACE_DefineGunFireSound( id, data)

--id	: this will be the sound patch which this content is associated to. Make sure that every id is unique so we dont have colliding data
--data	: here we will have 3 tables, which each one will edit the sounds to be played PER distance. So we will have main sounds (those you hear normally when standing close to the gun), mid sounds and far sounds.

--Each table contains this same structure:
----Volume (0-1)			: Adjust the volume of this section. This applies to all sounds for this section and always consider to amplify sounds via programs if they are too quiet as this will not solve that entirely.
----Pitch (0-255)			: You can set the desired Pitch for the sounds of this section. Leave as 100 if you dont want to mess with it, but if you want more control over your sounds.... use it.
----Package (table)			: This is the area where you insert your sounds. Flood this table to your liking as long as you put their paths correctly. The gun will switch between these sounds when being used. Recommended to put the id here too.
----NOTE about Package		: sounds are played IN order according to the table. So if you want that x sound is played before another, put that first sound first in the list (from above)

-- These sound packages will work for both sounds placed via sound replacer or generic ones, so feel free to create your own scripted sounds. Only works with GUNs.

--7.62mm Machinegun gunfire
ACE_DefineGunFireSound( "ace_weapons/multi_sound/7_62mm_multi.mp3",
	{
		main = {
			Volume	= 1,
			Pitch	= 100,
			Package = {
				"ace_weapons/multi_sound/content/7_62/close/close_multi.mp3",
				"ace_weapons/multi_sound/content/7_62/close/close1.mp3",
				"ace_weapons/multi_sound/content/7_62/close/close2.mp3",
				"ace_weapons/multi_sound/content/7_62/close/close3.mp3",
				"ace_weapons/multi_sound/content/7_62/close/close4.mp3",
				"ace_weapons/multi_sound/content/7_62/close/close5.mp3",
				"ace_weapons/multi_sound/content/7_62/close/close6.mp3",
				"ace_weapons/multi_sound/content/7_62/close/close7.mp3",
				"ace_weapons/multi_sound/content/7_62/close/close8.mp3",
				"ace_weapons/multi_sound/content/7_62/close/close9.mp3",
				"ace_weapons/multi_sound/content/7_62/close/close10.mp3",
				"ace_weapons/multi_sound/content/7_62/close/close11.mp3",
				"ace_weapons/multi_sound/content/7_62/close/close12.mp3",
				"ace_weapons/multi_sound/content/7_62/close/close13.mp3",
				"ace_weapons/multi_sound/content/7_62/close/close14.mp3",
				"ace_weapons/multi_sound/content/7_62/close/close15.mp3",
				"ace_weapons/multi_sound/content/7_62/close/close16.mp3",
				"ace_weapons/multi_sound/content/7_62/close/close17.mp3",
				"ace_weapons/multi_sound/content/7_62/close/close18.mp3",
				"ace_weapons/multi_sound/content/7_62/close/close19.mp3",
				"ace_weapons/multi_sound/content/7_62/close/close20.mp3"
			}
		},
		mid = {
			Volume	= 1,
			Pitch	= 100,
			Package = {
				"ace_weapons/multi_sound/content/7_62/medium/mid.mp3",
				"ace_weapons/multi_sound/content/7_62/medium/mid1.mp3",
				"ace_weapons/multi_sound/content/7_62/medium/mid2.mp3",
				"ace_weapons/multi_sound/content/7_62/medium/mid3.mp3",
				"ace_weapons/multi_sound/content/7_62/medium/mid4.mp3",
				"ace_weapons/multi_sound/content/7_62/medium/mid5.mp3",
				"ace_weapons/multi_sound/content/7_62/medium/mid6.mp3",
				"ace_weapons/multi_sound/content/7_62/medium/mid7.mp3",
				"ace_weapons/multi_sound/content/7_62/medium/mid8.mp3",
				"ace_weapons/multi_sound/content/7_62/medium/mid9.mp3",
				"ace_weapons/multi_sound/content/7_62/medium/mid10.mp3",
				"ace_weapons/multi_sound/content/7_62/medium/mid11.mp3",
				"ace_weapons/multi_sound/content/7_62/medium/mid12.mp3",
				"ace_weapons/multi_sound/content/7_62/medium/mid13.mp3",
				"ace_weapons/multi_sound/content/7_62/medium/mid14.mp3"
			}

		},
		far = {
			Volume	= 1,
			Pitch	= 100,
			Package = {
				"ace_weapons/multi_sound/content/7_62/far/far.mp3",
				"ace_weapons/multi_sound/content/7_62/far/far1.mp3",
				"ace_weapons/multi_sound/content/7_62/far/far2.mp3",
				"ace_weapons/multi_sound/content/7_62/far/far3.mp3",
				"ace_weapons/multi_sound/content/7_62/far/far4.mp3",
				"ace_weapons/multi_sound/content/7_62/far/far5.mp3",
				"ace_weapons/multi_sound/content/7_62/far/far6.mp3",
				"ace_weapons/multi_sound/content/7_62/far/far7.mp3",
				"ace_weapons/multi_sound/content/7_62/far/far8.mp3",
				"ace_weapons/multi_sound/content/7_62/far/far9.mp3",
				"ace_weapons/multi_sound/content/7_62/far/far10.mp3",
				"ace_weapons/multi_sound/content/7_62/far/far11.mp3",
				"ace_weapons/multi_sound/content/7_62/far/far12.mp3",
				"ace_weapons/multi_sound/content/7_62/far/far13.mp3",
				"ace_weapons/multi_sound/content/7_62/far/far14.mp3",
				"ace_weapons/multi_sound/content/7_62/far/far15.mp3",
				"ace_weapons/multi_sound/content/7_62/far/far16.mp3",
				"ace_weapons/multi_sound/content/7_62/far/far17.mp3"
			}
		}
	}
)

--12.7mm Machinegun gunfire
ACE_DefineGunFireSound( "ace_weapons/multi_sound/12_7mm_multi.mp3",
	{
		main = {
			Volume	= 1,
			Pitch	= 100,
			Package = {
				"ace_weapons/multi_sound/content/12_7/close/close_multi.mp3",
				"ace_weapons/multi_sound/content/12_7/close/close1.mp3",
				"ace_weapons/multi_sound/content/12_7/close/close2.mp3",
				"ace_weapons/multi_sound/content/12_7/close/close3.mp3",
				"ace_weapons/multi_sound/content/12_7/close/close4.mp3",
				"ace_weapons/multi_sound/content/12_7/close/close5.mp3",
				"ace_weapons/multi_sound/content/12_7/close/close6.mp3",
				"ace_weapons/multi_sound/content/12_7/close/close7.mp3",
				"ace_weapons/multi_sound/content/12_7/close/close8.mp3",
				"ace_weapons/multi_sound/content/12_7/close/close9.mp3",
				"ace_weapons/multi_sound/content/12_7/close/close10.mp3",
				"ace_weapons/multi_sound/content/12_7/close/close11.mp3",
				"ace_weapons/multi_sound/content/12_7/close/close12.mp3",
				"ace_weapons/multi_sound/content/12_7/close/close13.mp3",
				"ace_weapons/multi_sound/content/12_7/close/close14.mp3",
				"ace_weapons/multi_sound/content/12_7/close/close15.mp3",
				"ace_weapons/multi_sound/content/12_7/close/close16.mp3",
				"ace_weapons/multi_sound/content/12_7/close/close17.mp3",
				"ace_weapons/multi_sound/content/12_7/close/close18.mp3",
				"ace_weapons/multi_sound/content/12_7/close/close19.mp3"
			}
		},
		mid = {
			Volume	= 1,
			Pitch	= 100,
			Package = {
				"ace_weapons/multi_sound/content/12_7/medium/mid.mp3",
				"ace_weapons/multi_sound/content/12_7/medium/mid1.mp3",
				"ace_weapons/multi_sound/content/12_7/medium/mid2.mp3",
				"ace_weapons/multi_sound/content/12_7/medium/mid3.mp3",
				"ace_weapons/multi_sound/content/12_7/medium/mid4.mp3",
				"ace_weapons/multi_sound/content/12_7/medium/mid5.mp3",
				"ace_weapons/multi_sound/content/12_7/medium/mid6.mp3",
				"ace_weapons/multi_sound/content/12_7/medium/mid7.mp3",
				"ace_weapons/multi_sound/content/12_7/medium/mid8.mp3",
				"ace_weapons/multi_sound/content/12_7/medium/mid9.mp3",
				"ace_weapons/multi_sound/content/12_7/medium/mid10.mp3",
				"ace_weapons/multi_sound/content/12_7/medium/mid11.mp3",
				"ace_weapons/multi_sound/content/12_7/medium/mid12.mp3",
				"ace_weapons/multi_sound/content/12_7/medium/mid13.mp3",
				"ace_weapons/multi_sound/content/12_7/medium/mid14.mp3",
				"ace_weapons/multi_sound/content/12_7/medium/mid15.mp3",
				"ace_weapons/multi_sound/content/12_7/medium/mid16.mp3"
			}

		},
		far = {
			Volume	= 1,
			Pitch	= 100,
			Package = {
				"ace_weapons/multi_sound/content/12_7/far/far.mp3",
				"ace_weapons/multi_sound/content/12_7/far/far1.mp3",
				"ace_weapons/multi_sound/content/12_7/far/far2.mp3",
				"ace_weapons/multi_sound/content/12_7/far/far3.mp3",
				"ace_weapons/multi_sound/content/12_7/far/far4.mp3",
				"ace_weapons/multi_sound/content/12_7/far/far5.mp3",
				"ace_weapons/multi_sound/content/12_7/far/far6.mp3",
				"ace_weapons/multi_sound/content/12_7/far/far7.mp3",
				"ace_weapons/multi_sound/content/12_7/far/far8.mp3",
				"ace_weapons/multi_sound/content/12_7/far/far9.mp3",
				"ace_weapons/multi_sound/content/12_7/far/far10.mp3",
				"ace_weapons/multi_sound/content/12_7/far/far11.mp3",
				"ace_weapons/multi_sound/content/12_7/far/far12.mp3",
				"ace_weapons/multi_sound/content/12_7/far/far13.mp3"
			}
		}
	}
)

--20mm heavy machinegun gunfire.
ACE_DefineGunFireSound( "ace_weapons/multi_sound/20mm_hmg_multi.mp3",
	{
		main = {
			Volume	= 1,
			Pitch	= 100,
			Package = {
				"ace_weapons/multi_sound/content/20hmg/close/close_multi.mp3",
				"ace_weapons/multi_sound/content/20hmg/close/close1.mp3",
				"ace_weapons/multi_sound/content/20hmg/close/close2.mp3",
				"ace_weapons/multi_sound/content/20hmg/close/close3.mp3",
				"ace_weapons/multi_sound/content/20hmg/close/close4.mp3",
				"ace_weapons/multi_sound/content/20hmg/close/close5.mp3",
				"ace_weapons/multi_sound/content/20hmg/close/close6.mp3",
				"ace_weapons/multi_sound/content/20hmg/close/close7.mp3",
				"ace_weapons/multi_sound/content/20hmg/close/close8.mp3",
				"ace_weapons/multi_sound/content/20hmg/close/close9.mp3",
				"ace_weapons/multi_sound/content/20hmg/close/close10.mp3",
				"ace_weapons/multi_sound/content/20hmg/close/close11.mp3",
				"ace_weapons/multi_sound/content/20hmg/close/close12.mp3",
				"ace_weapons/multi_sound/content/20hmg/close/close13.mp3",
				"ace_weapons/multi_sound/content/20hmg/close/close14.mp3",
				"ace_weapons/multi_sound/content/20hmg/close/close15.mp3",
				"ace_weapons/multi_sound/content/20hmg/close/close16.mp3",
				"ace_weapons/multi_sound/content/20hmg/close/close17.mp3"
			}
		},
		mid = {
			Volume	= 1,
			Pitch	= 100,
			Package = {
				"ace_weapons/multi_sound/content/20hmg/medium/mid.mp3",
				"ace_weapons/multi_sound/content/20hmg/medium/mid1.mp3",
				"ace_weapons/multi_sound/content/20hmg/medium/mid2.mp3",
				"ace_weapons/multi_sound/content/20hmg/medium/mid3.mp3",
				"ace_weapons/multi_sound/content/20hmg/medium/mid4.mp3",
				"ace_weapons/multi_sound/content/20hmg/medium/mid5.mp3",
				"ace_weapons/multi_sound/content/20hmg/medium/mid6.mp3",
				"ace_weapons/multi_sound/content/20hmg/medium/mid7.mp3",
				"ace_weapons/multi_sound/content/20hmg/medium/mid8.mp3",
				"ace_weapons/multi_sound/content/20hmg/medium/mid9.mp3",
				"ace_weapons/multi_sound/content/20hmg/medium/mid10.mp3",
				"ace_weapons/multi_sound/content/20hmg/medium/mid11.mp3",
				"ace_weapons/multi_sound/content/20hmg/medium/mid12.mp3",
				"ace_weapons/multi_sound/content/20hmg/medium/mid13.mp3",
				"ace_weapons/multi_sound/content/20hmg/medium/mid14.mp3",
				"ace_weapons/multi_sound/content/20hmg/medium/mid15.mp3",
				"ace_weapons/multi_sound/content/20hmg/medium/mid16.mp3",
				"ace_weapons/multi_sound/content/20hmg/medium/mid17.mp3",
				"ace_weapons/multi_sound/content/20hmg/medium/mid18.mp3",
				"ace_weapons/multi_sound/content/20hmg/medium/mid19.mp3"
			}

		},
		far = {
			Volume	= 1,
			Pitch	= 100,
			Package = {
				"ace_weapons/multi_sound/content/20hmg/far/far.mp3",
				"ace_weapons/multi_sound/content/20hmg/far/far1.mp3",
				"ace_weapons/multi_sound/content/20hmg/far/far2.mp3",
				"ace_weapons/multi_sound/content/20hmg/far/far3.mp3",
				"ace_weapons/multi_sound/content/20hmg/far/far4.mp3",
				"ace_weapons/multi_sound/content/20hmg/far/far5.mp3",
				"ace_weapons/multi_sound/content/20hmg/far/far6.mp3",
				"ace_weapons/multi_sound/content/20hmg/far/far7.mp3",
				"ace_weapons/multi_sound/content/20hmg/far/far8.mp3",
				"ace_weapons/multi_sound/content/20hmg/far/far9.mp3",
				"ace_weapons/multi_sound/content/20hmg/far/far10.mp3",
				"ace_weapons/multi_sound/content/20hmg/far/far11.mp3",
				"ace_weapons/multi_sound/content/20hmg/far/far12.mp3",
				"ace_weapons/multi_sound/content/20hmg/far/far13.mp3",
				"ace_weapons/multi_sound/content/20hmg/far/far14.mp3",
				"ace_weapons/multi_sound/content/20hmg/far/far15.mp3",
				"ace_weapons/multi_sound/content/20hmg/far/far16.mp3",
				"ace_weapons/multi_sound/content/20hmg/far/far17.mp3"
			}
		}
	}
)

--30mm heavy machinegun gunfire.
ACE_DefineGunFireSound( "ace_weapons/multi_sound/30mm_hmg_multi.mp3",
	{
		main = {
			Volume	= 1,
			Pitch	= 100,
			Package = {
				"ace_weapons/multi_sound/content/30hmg/close/close_multi.mp3",
				"ace_weapons/multi_sound/content/30hmg/close/close1.mp3",
				"ace_weapons/multi_sound/content/30hmg/close/close2.mp3",
				"ace_weapons/multi_sound/content/30hmg/close/close3.mp3",
				"ace_weapons/multi_sound/content/30hmg/close/close4.mp3",
				"ace_weapons/multi_sound/content/30hmg/close/close5.mp3",
				"ace_weapons/multi_sound/content/30hmg/close/close6.mp3",
				"ace_weapons/multi_sound/content/30hmg/close/close7.mp3"
			}
		},
		mid = {
			Volume	= 1,
			Pitch	= 100,
			Package = {
				"ace_weapons/multi_sound/content/30hmg/medium/mid.mp3",
				"ace_weapons/multi_sound/content/30hmg/medium/mid1.mp3",
				"ace_weapons/multi_sound/content/30hmg/medium/mid2.mp3",
				"ace_weapons/multi_sound/content/30hmg/medium/mid3.mp3",
				"ace_weapons/multi_sound/content/30hmg/medium/mid4.mp3"
			}

		},
		far = {
			Volume	= 1,
			Pitch	= 100,
			Package = {
				"ace_weapons/multi_sound/content/30hmg/medium/mid.mp3",
				"ace_weapons/multi_sound/content/30hmg/medium/mid1.mp3",
				"ace_weapons/multi_sound/content/30hmg/medium/mid2.mp3",
				"ace_weapons/multi_sound/content/30hmg/medium/mid3.mp3",
				"ace_weapons/multi_sound/content/30hmg/medium/mid4.mp3"
			}
		}
	}
)

--20mm Cannon sound
ACE_DefineGunFireSound( "ace_weapons/multi_sound/20mm_multi.mp3",
	{
		main = {
			Volume	= 1,
			Pitch	= 100,
			Package = {
				"ace_weapons/multi_sound/content/20/close/close_multi.mp3",
				"ace_weapons/multi_sound/content/20/close/close1.mp3",
				"ace_weapons/multi_sound/content/20/close/close2.mp3",
				"ace_weapons/multi_sound/content/20/close/close3.mp3",
				"ace_weapons/multi_sound/content/20/close/close4.mp3",
				"ace_weapons/multi_sound/content/20/close/close5.mp3",
				"ace_weapons/multi_sound/content/20/close/close6.mp3",
				"ace_weapons/multi_sound/content/20/close/close7.mp3",
				"ace_weapons/multi_sound/content/20/close/close8.mp3",
				"ace_weapons/multi_sound/content/20/close/close9.mp3",
				"ace_weapons/multi_sound/content/20/close/close10.mp3"
			}
		},
		mid = {
			Volume	= 1,
			Pitch	= 100,
			Package = {
				"ace_weapons/multi_sound/content/20/medium/mid.mp3",
				"ace_weapons/multi_sound/content/20/medium/mid1.mp3",
				"ace_weapons/multi_sound/content/20/medium/mid2.mp3",
				"ace_weapons/multi_sound/content/20/medium/mid3.mp3",
				"ace_weapons/multi_sound/content/20/medium/mid4.mp3",
				"ace_weapons/multi_sound/content/20/medium/mid5.mp3",
				"ace_weapons/multi_sound/content/20/medium/mid6.mp3",
				"ace_weapons/multi_sound/content/20/medium/mid7.mp3",
				"ace_weapons/multi_sound/content/20/medium/mid8.mp3",
				"ace_weapons/multi_sound/content/20/medium/mid9.mp3",
				"ace_weapons/multi_sound/content/20/medium/mid10.mp3"
			}

		},
		far = {
			Volume	= 1,
			Pitch	= 100,
			Package = {
				"ace_weapons/multi_sound/content/20/far/far.mp3",
				"ace_weapons/multi_sound/content/20/far/far1.mp3",
				"ace_weapons/multi_sound/content/20/far/far2.mp3",
				"ace_weapons/multi_sound/content/20/far/far3.mp3",
				"ace_weapons/multi_sound/content/20/far/far4.mp3",
				"ace_weapons/multi_sound/content/20/far/far5.mp3",
				"ace_weapons/multi_sound/content/20/far/far6.mp3",
				"ace_weapons/multi_sound/content/20/far/far7.mp3"
			}
		}
	}
)

--30mm Cannon sound
ACE_DefineGunFireSound( "ace_weapons/multi_sound/30mm_multi.mp3",
	{
		main = {
			Volume	= 1,
			Pitch	= 100,
			Package = {
				"ace_weapons/multi_sound/content/30/close/close_multi.mp3",
				"ace_weapons/multi_sound/content/30/close/close1.mp3",
				"ace_weapons/multi_sound/content/30/close/close2.mp3",
				"ace_weapons/multi_sound/content/30/close/close3.mp3",
				"ace_weapons/multi_sound/content/30/close/close4.mp3"
			}
		},
		mid = {
			Volume	= 1,
			Pitch	= 100,
			Package = {
				"ace_weapons/multi_sound/content/30/medium/mid.mp3",
				"ace_weapons/multi_sound/content/30/medium/mid1.mp3",
				"ace_weapons/multi_sound/content/30/medium/mid2.mp3",
				"ace_weapons/multi_sound/content/30/medium/mid3.mp3",
				"ace_weapons/multi_sound/content/30/medium/mid4.mp3"
			}

		},
		far = {
			Volume	= 1,
			Pitch	= 100,
			Package = {
				"ace_weapons/multi_sound/content/30/far/far.mp3",
				"ace_weapons/multi_sound/content/30/far/far1.mp3",
				"ace_weapons/multi_sound/content/30/far/far2.mp3",
				"ace_weapons/multi_sound/content/30/far/far3.mp3",
				"ace_weapons/multi_sound/content/30/far/far4.mp3",
				"ace_weapons/multi_sound/content/30/far/far5.mp3",
				"ace_weapons/multi_sound/content/30/far/far6.mp3",
				"ace_weapons/multi_sound/content/30/far/far7.mp3"
			}
		}
	}
)

--40mm Cannon sound
ACE_DefineGunFireSound( "ace_weapons/multi_sound/40mm_multi.mp3",
	{
		main = {
			Volume	= 1,
			Pitch	= 100,
			Package = {
				"ace_weapons/multi_sound/content/40/close/close_multi.mp3",
				"ace_weapons/multi_sound/content/40/close/close1.mp3",
				"ace_weapons/multi_sound/content/40/close/close2.mp3",
				"ace_weapons/multi_sound/content/40/close/close3.mp3",
				"ace_weapons/multi_sound/content/40/close/close4.mp3",
				"ace_weapons/multi_sound/content/40/close/close5.mp3"
			}
		},
		mid = {
			Volume	= 1,
			Pitch	= 100,
			Package = {
				"ace_weapons/multi_sound/content/40/medium/mid.mp3",
				"ace_weapons/multi_sound/content/40/medium/mid1.mp3",
				"ace_weapons/multi_sound/content/40/medium/mid2.mp3",
				"ace_weapons/multi_sound/content/40/medium/mid3.mp3",
				"ace_weapons/multi_sound/content/40/medium/mid4.mp3"
			}

		},
		far = {
			Volume	= 1,
			Pitch	= 100,
			Package = {
				"ace_weapons/multi_sound/content/40/far/far.mp3",
				"ace_weapons/multi_sound/content/40/far/far1.mp3",
				"ace_weapons/multi_sound/content/40/far/far2.mp3",
				"ace_weapons/multi_sound/content/40/far/far3.mp3",
				"ace_weapons/multi_sound/content/40/far/far4.mp3",
				"ace_weapons/multi_sound/content/40/far/far5.mp3",
				"ace_weapons/multi_sound/content/40/far/far6.mp3",
				"ace_weapons/multi_sound/content/40/far/far7.mp3"
			}
		}
	}
)

--50mm Cannon sound
ACE_DefineGunFireSound( "ace_weapons/multi_sound/50mm_multi.mp3",
	{
		main = {
			Volume	= 1,
			Pitch	= 100,
			Package = {
				"ace_weapons/multi_sound/content/50/close/close_multi.mp3",
				"ace_weapons/multi_sound/content/50/close/close1.mp3",
				"ace_weapons/multi_sound/content/50/close/close2.mp3",
				"ace_weapons/multi_sound/content/50/close/close3.mp3"
			}
		},
		mid = {
			Volume	= 1,
			Pitch	= 100,
			Package = {
				"ace_weapons/multi_sound/content/50/medium/mid.mp3",
				"ace_weapons/multi_sound/content/50/medium/mid1.mp3",
				"ace_weapons/multi_sound/content/50/medium/mid2.mp3",
				"ace_weapons/multi_sound/content/50/medium/mid3.mp3"
			}

		},
		far = {
			Volume	= 1,
			Pitch	= 100,
			Package = {
				"ace_weapons/multi_sound/content/50/far/far.mp3",
				"ace_weapons/multi_sound/content/50/far/far1.mp3",
				"ace_weapons/multi_sound/content/50/far/far2.mp3"
			}
		}
	}
)

--75mm Cannon sound
ACE_DefineGunFireSound( "ace_weapons/multi_sound/75mm_multi.mp3",
	{
		main = {
			Volume	= 1,
			Pitch	= 100,
			Package = {
				"ace_weapons/multi_sound/content/75/close/close_multi.mp3",
				"ace_weapons/multi_sound/content/75/close/close1.mp3",
				"ace_weapons/multi_sound/content/75/close/close2.mp3",
				"ace_weapons/multi_sound/content/75/close/close3.mp3"
			}
		},
		mid = {
			Volume	= 1,
			Pitch	= 100,
			Package = {
				"ace_weapons/multi_sound/content/75/medium/mid.mp3",
				"ace_weapons/multi_sound/content/75/medium/mid1.mp3",
				"ace_weapons/multi_sound/content/75/medium/mid2.mp3",
				"ace_weapons/multi_sound/content/75/medium/mid3.mp3"
			}

		},
		far = {
			Volume	= 1,
			Pitch	= 100,
			Package = {
				"ace_weapons/multi_sound/content/75/far/far.mp3",
				"ace_weapons/multi_sound/content/75/far/far1.mp3",
				"ace_weapons/multi_sound/content/75/far/far2.mp3",
				"ace_weapons/multi_sound/content/75/far/far3.mp3"
			}
		}
	}
)

--100mm Cannon sound
ACE_DefineGunFireSound( "ace_weapons/multi_sound/100mm_multi.mp3",
	{
		main = {
			Volume	= 1,
			Pitch	= 100,
			Package = {
				"ace_weapons/multi_sound/content/100/close/close_multi.mp3",
				"ace_weapons/multi_sound/content/100/close/close1.mp3",
				"ace_weapons/multi_sound/content/100/close/close2.mp3",
				"ace_weapons/multi_sound/content/100/close/close3.mp3"
			}
		},
		mid = {
			Volume	= 1,
			Pitch	= 100,
			Package = {
				"ace_weapons/multi_sound/content/100/medium/mid.mp3",
				"ace_weapons/multi_sound/content/100/medium/mid1.mp3",
				"ace_weapons/multi_sound/content/100/medium/mid2.mp3",
				"ace_weapons/multi_sound/content/100/medium/mid3.mp3"
			}

		},
		far = {
			Volume	= 1,
			Pitch	= 100,
			Package = {
				"ace_weapons/multi_sound/content/100/far/far.mp3",
				"ace_weapons/multi_sound/content/100/far/far1.mp3",
				"ace_weapons/multi_sound/content/100/far/far2.mp3",
				"ace_weapons/multi_sound/content/100/far/far3.mp3"
			}
		}
	}
)

--120mm+ Cannon sound
ACE_DefineGunFireSound( "ace_weapons/multi_sound/120mm_multi.mp3",
	{
		main = {
			Volume	= 1,
			Pitch	= 100,
			Package = {
				"ace_weapons/multi_sound/content/120/close/close_multi.mp3",
				"ace_weapons/multi_sound/content/120/close/close1.mp3",
				"ace_weapons/multi_sound/content/120/close/close2.mp3",
				"ace_weapons/multi_sound/content/120/close/close3.mp3",
				"ace_weapons/multi_sound/content/120/close/close4.mp3"
			}
		},
		mid = {
			Volume	= 1,
			Pitch	= 100,
			Package = {
				"ace_weapons/multi_sound/content/120/medium/mid.mp3",
				"ace_weapons/multi_sound/content/120/medium/mid1.mp3",
				"ace_weapons/multi_sound/content/120/medium/mid2.mp3",
				"ace_weapons/multi_sound/content/120/medium/mid3.mp3",
				"ace_weapons/multi_sound/content/120/medium/mid4.mp3"
			}

		},
		far = {
			Volume	= 1,
			Pitch	= 100,
			Package = {
				"ace_weapons/multi_sound/content/120/far/far.mp3",
				"ace_weapons/multi_sound/content/120/far/far1.mp3",
				"ace_weapons/multi_sound/content/120/far/far2.mp3",
				"ace_weapons/multi_sound/content/120/far/far3.mp3"
			}
		}
	}
)

--Generic Howitzer gunfire
ACE_DefineGunFireSound( "ace_weapons/multi_sound/howitzer_multi.wav",
	{
		main = {
			Volume	= 10,
			Pitch	= 100,
			Package = {
				"ace_weapons/multi_sound/content/howitzer/close/close1.wav",
				"ace_weapons/multi_sound/content/howitzer/close/close2.wav",
				"ace_weapons/multi_sound/content/howitzer/close/close3.wav",
				"ace_weapons/multi_sound/content/howitzer/close/close4.wav"
			}

		},
		mid = {
			Volume	= 10,
			Pitch	= 100,
			Package = {
				"ace_weapons/multi_sound/content/howitzer/medium/mid1.wav",
				"ace_weapons/multi_sound/content/howitzer/medium/mid2.wav",
				"ace_weapons/multi_sound/content/howitzer/medium/mid3.wav",
				"ace_weapons/multi_sound/content/howitzer/medium/mid4.wav"
			}

		},
		far = {
			Volume	= 10,
			Pitch	= 100,
			Package = {
				"ace_weapons/multi_sound/content/howitzer/medium/mid1.wav",
				"ace_weapons/multi_sound/content/howitzer/medium/mid2.wav",
				"ace_weapons/multi_sound/content/howitzer/medium/mid3.wav",
				"ace_weapons/multi_sound/content/howitzer/medium/mid4.wav"
			}
		}
	}
)
--[[
--Generic Mortar gunfire. Ik its empty, the structure is here just to avoid recreate it in the future.
ACE_DefineGunFireSound( "weapons/ACE_Gun/mortar_new.wav",
	{
		main = {
			Volume	= 1,
			Pitch	= 100,
			Package = {
				"weapons/ACE_Gun/mortar_new.wav"
			}
		},
		mid = {
			Volume	= 1,
			Pitch	= 100,
			Package = {
				"weapons/ACE_Gun/mortar_new.wav"
			}

		},
		far = {
			Volume	= 1,
			Pitch	= 100,
			Package = {
				"weapons/ACE_Gun/mortar_new.wav"
			}
		}
	}
)
]]
--Generic AT Rifle gunfire
ACE_DefineGunFireSound( "acf_extra/tankfx/gnomefather/7mm1.wav",
	{
		main = {
			Volume	= 1,
			Pitch	= 100,
			Package = {
				"acf_extra/tankfx/gnomefather/7mm1.wav"
			}
		},
		mid = {
			Volume	= 100,
			Pitch	= 100,
			Package = {
				"acf_other/gunfire/autocannon/autocannon_mid_far1.wav",
				"acf_other/gunfire/autocannon/autocannon_mid_far2.wav",
				"acf_other/gunfire/autocannon/autocannon_mid_far3.wav",
				"acf_other/gunfire/autocannon/autocannon_mid_far4.wav"
			}

		},
		far = {
			Volume	= 100,
			Pitch	= 100,
			Package = {
				"acf_other/gunfire/autocannon/autocannon_mid_far1.wav",
				"acf_other/gunfire/autocannon/autocannon_mid_far2.wav",
				"acf_other/gunfire/autocannon/autocannon_mid_far3.wav",
				"acf_other/gunfire/autocannon/autocannon_mid_far4.wav"
			}
		}
	}
)
--[[
--generic rotary autocannon gunfire. Broken atm
ACE_DefineGunFireSound( "weapons/acf_gun/mg_fire2.wav",
	{
		main = {
			Volume	= 0.9,
			Pitch	= 90,
			Package = {
				"weapons/acf_gun/mg_fire2.wav"
			}
		},
		mid = {
			Volume	= 2,
			Pitch	= 100,
			Package = {
				"acf_other/gunfire/rotaryautocannon/rac_mid_far1.wav",
				"acf_other/gunfire/rotaryautocannon/rac_mid_far2.wav",
				"acf_other/gunfire/rotaryautocannon/rac_mid_far3.wav",
				"acf_other/gunfire/rotaryautocannon/rac_mid_far4.wav"
			}

		},
		far = {
			Volume	= 2,
			Pitch	= 100,
			Package = {
				"acf_other/gunfire/rotaryautocannon/rac_mid_far1.wav",
				"acf_other/gunfire/rotaryautocannon/rac_mid_far2.wav",
				"acf_other/gunfire/rotaryautocannon/rac_mid_far3.wav",
				"acf_other/gunfire/rotaryautocannon/rac_mid_far4.wav"
			}
		}
	}
)
]]
--[[
--Generic GL gunfire
ACE_DefineGunFireSound( "weapons/acf_gun/grenadelauncher.wav",
	{
		main = {
			Volume	= 1,
			Pitch	= 100,
			Package = {
				"weapons/acf_gun/grenadelauncher.wav"
			}
		},
		mid = {
			Volume	= 0.5,
			Pitch	= 100,
			Package = {
				"weapons/acf_gun/grenadelauncher.wav"
			}

		},
		far = {
			Volume	= 0.5,
			Pitch	= 100,
			Package = {
				"weapons/acf_gun/grenadelauncher.wav"
			}
		}
	}
)

--Generic SL gunfire
ACE_DefineGunFireSound( "ace_weapons/multi_sound/smoke_multi.mp3",
	{
		main = {
			Volume	= 1,
			Pitch	= 100,
			Package = {
				"ace_weapons/multi_sound/content/smoke/launcher/close/close_multi.mp3"
			}
		},
		mid = {
			Volume	= 0.1,
			Pitch	= 100,
			Package = {
				"ace_weapons/multi_sound/content/smoke/launcher/mid/mid.mp3"
			}

		},
		far = {
			Volume	= 0.1,
			Pitch	= 100,
			Package = {
				"ace_weapons/multi_sound/content/smoke/launcher/mid/mid.mp3"
			}
		}
	}
)

--Generic FGL gunfire
ACE_DefineGunFireSound( "acf_extra/tankfx/flare_launch.wav",
	{
		main = {
			Volume	= 1,
			Pitch	= 100,
			Package = {
				"acf_extra/tankfx/flare_launch.wav"
			}
		},
		mid = {
			Volume	= 0.1,
			Pitch	= 100,
			Package = {
				"acf_extra/tankfx/flare_launch.wav"
			}

		},
		far = {
			Volume	= 0.1,
			Pitch	= 100,
			Package = {
				"acf_extra/tankfx/flare_launch.wav"
			}
		}
	}
)
]]--
--[[
--Test sound definition. Meant to see if the core works as intended.
ACE_DefineGunFireSound( "physics/metal/bts5_panels_impact_lg_01.wav",
	{
		main = {
			Volume	= 1,
			Pitch	= 100,
			Package = {
				"physics/metal/bts5_panels_impact_lg_01.wav",
				"physics/metal/bts5_panels_impact_lg_02.wav",
				"physics/metal/bts5_panels_impact_lg_03.wav",
				"physics/metal/bts5_panels_impact_lg_04.wav",
				"physics/metal/bts5_panels_impact_lg_05.wav",
				"physics/metal/bts5_panels_impact_lg_06.wav",
				"physics/metal/bts5_panels_impact_lg_07.wav",
				"physics/metal/bts5_panels_impact_lg_08.wav",
				"physics/metal/bts5_panels_impact_lg_09.wav"
			}
		},
		mid = {
			Volume	= 1,
			Pitch	= 50,
			Package = {
				"physics/metal/bts5_panels_impact_lg_01.wav",
				"physics/metal/bts5_panels_impact_lg_02.wav",
				"physics/metal/bts5_panels_impact_lg_03.wav",
				"physics/metal/bts5_panels_impact_lg_04.wav",
				"physics/metal/bts5_panels_impact_lg_05.wav",
				"physics/metal/bts5_panels_impact_lg_06.wav",
				"physics/metal/bts5_panels_impact_lg_07.wav",
				"physics/metal/bts5_panels_impact_lg_08.wav",
				"physics/metal/bts5_panels_impact_lg_09.wav"
			}

		},
		far = {
			Volume	= 1,
			Pitch	= 25,
			Package = {
				"physics/metal/bts5_panels_impact_lg_01.wav",
				"physics/metal/bts5_panels_impact_lg_02.wav",
				"physics/metal/bts5_panels_impact_lg_03.wav",
				"physics/metal/bts5_panels_impact_lg_04.wav",
				"physics/metal/bts5_panels_impact_lg_05.wav",
				"physics/metal/bts5_panels_impact_lg_06.wav",
				"physics/metal/bts5_panels_impact_lg_07.wav",
				"physics/metal/bts5_panels_impact_lg_08.wav",
				"physics/metal/bts5_panels_impact_lg_09.wav"
			}
		}
	}
)
 ]]
