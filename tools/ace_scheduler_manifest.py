"""Generate a source-derived ACE scheduling-surface inventory.

The output is deliberately an inventory, not an approval mechanism: rows that do not match a
known disposition are emitted as ``pending`` so a future migration cannot hide an unreviewed
callback behind a broad file-level classification.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import re
import sys
from pathlib import Path


FUNCTION_RE = re.compile(
    r"(?:^|\s)(?:local\s+)?(?:function\s+([\w.:]+)|([\w.]+)\s*=\s*function)"
)
SURFACE_RE = re.compile(
    r"timer\.(?:Create|Simple|Adjust|Remove|Exists|RepsLeft)|"
    r"ACE\.ScheduleSafezoneVisualization\s*\(|"
    r"ACE\.ScheduleLegalCheckReset\s*\(|"
    r"(?:ACE\.)?Scheduler\.RegisterAdapter\s*\(|"
    r"\b(?:NextThink|SetNextThink)\s*\(|"
    r"hook\.Add\s*\(\s*[\"'](?:Think|Tick)[\"']|"
    r"function\s+(?:ENT|SWEP):Think\s*\("
)

def reviewed(*lines: int) -> frozenset[tuple[int, int]]:
    return frozenset((line, 1) for line in lines)


# Every discovered row must appear here. This is deliberately line-specific: broad path or
# realm defaults would make --strict look green while silently classifying a new callback.
REVIEWED_ROWS = {
    'lua/ace/client/cl_acemenu_gui.lua': [
        (frozenset({(469, 1), (790, 1)}), 'engine-bound', 'realm/input/presentation contract'),
    ],
    'lua/ace/client/cl_acfballistics.lua': [
        (frozenset({(14, 1)}), 'engine-bound', 'realm/input/presentation contract'),
    ],
    'lua/ace/client/cl_soundbase.lua': [
        (frozenset({(698, 1)}), 'engine-bound', 'realm/input/presentation contract'),
    ],
    'lua/ace/server/sv_ace_ammo_cookoff_scheduler.lua': [
        (frozenset({(24, 1), (37, 1), (51, 1), (73, 1), (127, 1)}), 'migrated', 'ACE.AmmoCookoffFlash'),
    ],
    'lua/ace/server/sv_ace_damage_effect_scheduler.lua': [
        (frozenset({(26, 1), (38, 1), (59, 1), (107, 1)}), 'migrated', 'ACE.DamageDetonationEffect'),
    ],
    'lua/ace/server/sv_ace_debris_scheduler.lua': [
        (frozenset({(25, 1), (38, 1), (44, 1), (66, 1), (132, 1)}), 'migrated', 'ACE.EntityRemoval'),
    ],
    'lua/ace/server/sv_ace_flare_scheduler.lua': [
        (frozenset({(34, 1), (124, 1), (158, 1), (164, 1)}), 'migrated', 'ACE.FlareThink'),
    ],
    'lua/ace/server/sv_ace_gforce_meter_scheduler.lua': [
        (frozenset({(46, 1), (71, 1), (119, 1)}), 'migrated', 'ACE.GForceMeterThink'),
    ],
    'lua/ace/server/sv_ace_gun_autosound_scheduler.lua': [
        (frozenset({(24, 1), (32, 1), (42, 1), (69, 1), (121, 1)}), 'migrated', 'ACE.GunAutoSound'),
    ],
    'lua/ace/server/sv_ace_legalcheck.lua': [
        (frozenset({(54, 1), (63, 1), (78, 1), (85, 1)}), 'migrated', 'ACE.ContraptionLegalCheck'),
    ],
    'lua/ace/server/sv_ace_renderqueue.lua': [
        (frozenset({(97, 1), (113, 1)}), 'engine-bound', 'load-order/compatibility or server callback contract'),
        (frozenset({(106, 1)}), 'migrated', 'ACE.RenderPropDamage'),
    ],
    'lua/ace/server/sv_ace_safezone.lua': [
        (frozenset({(120, 1), (129, 1), (136, 1)}), 'migrated', 'ACE.SafezoneTransition'),
        (frozenset({(49, 1), (56, 1), (67, 1), (78, 1)}), 'migrated', 'ACE.SafezoneVisualization'),
    ],
    'lua/ace/server/sv_ace_scalability_scheduler.lua': [
        (frozenset({(23, 1), (51, 1), (59, 1), (77, 1), (89, 1), (127, 1), (140, 1)}), 'migrated', 'ACE.ScalableResync'),
    ],
    'lua/ace/server/sv_ace_scheduler.lua': [
        (frozenset({(220, 1), (326, 1)}), 'engine-bound', 'load-order/compatibility or server callback contract'),
    ],
    'lua/ace/server/sv_ace_sonar_scheduler.lua': [
        (frozenset({(107, 1), (126, 1), (140, 1), (166, 1), (286, 1)}), 'migrated', 'ACE.SonarPingExpiry'),
        (frozenset({(34, 1), (47, 1), (57, 1), (79, 1), (285, 1)}), 'migrated', 'ACE.SonarTravelSound'),
    ],
    'lua/ace/server/sv_ace_vheat_source_scheduler.lua': [
        (frozenset({(49, 1), (74, 1), (122, 1)}), 'migrated', 'ACE.VHeatSourceThink'),
    ],
    'lua/ace/server/sv_ace_wind_sensor_scheduler.lua': [
        (frozenset({(49, 1), (74, 1), (121, 1)}), 'migrated', 'ACE.WindSensorThink'),
    ],
    'lua/ace/server/sv_acfballistics.lua': [
        (frozenset({(334, 1)}), 'blocked', 'physics/fuse/entity-state contract'),
    ],
    'lua/ace/server/sv_acfdamage.lua': [
        (frozenset({(319, 1)}), 'blocked', 'physics/fuse/entity-state contract'),
        (frozenset({(1684, 1)}), 'migrated', 'ACE.DamageDetonationEffect'),
    ],
    'lua/ace/server/sv_acfpermission.lua': [
        (frozenset({(509, 1), (545, 1), (551, 1)}), 'migrated', 'ACE.PermissionModeThink'),
        (frozenset({(111, 1)}), 'migrated', 'ACE.SafezoneVisualization'),
    ],
    'lua/ace/server/sv_contraption.lua': [
        (frozenset({(108, 1)}), 'engine-bound', 'load-order/compatibility or server callback contract'),
        (frozenset({(324, 1), (329, 1), (338, 1), (347, 1)}), 'migrated', 'ACE.PeriodicCleanup'),
    ],
    'lua/ace/server/sv_contraptionlegality.lua': [
        (frozenset({(77, 1)}), 'migrated', 'ACE.ContraptionLegalCheck'),
    ],
    'lua/ace/server/sv_crewseat_base.lua': [
        (frozenset({(105, 1)}), 'engine-bound', 'load-order/compatibility or server callback contract'),
    ],
    'lua/ace/server/sv_pointshandling.lua': [
        (frozenset({(460, 1), (463, 1), (465, 1)}), 'migrated', 'ACE.PointFlush'),
    ],
    'lua/ace/shared/armor/du.lua': [
        (frozenset({(67, 1), (96, 1)}), 'blocked', 'physics/fuse/entity-state contract'),
    ],
    'lua/ace/shared/armor/era.lua': [
        (frozenset({(105, 1), (106, 1), (124, 1)}), 'blocked', 'physics/fuse/entity-state contract'),
    ],
    'lua/ace/shared/compatibility/cppiCompatibility.lua': [
        (frozenset({(1, 1)}), 'engine-bound', 'load-order/compatibility or server callback contract'),
    ],
    'lua/ace/shared/fuses/e_plunging.lua': [
        (frozenset({(73, 1)}), 'blocked', 'physics/fuse/entity-state contract'),
    ],
    'lua/ace/shared/rounds/roundclusterap.lua': [
        (frozenset({(209, 1)}), 'blocked', 'physics/fuse/entity-state contract'),
    ],
    'lua/ace/shared/rounds/roundclusterhe.lua': [
        (frozenset({(230, 1)}), 'blocked', 'physics/fuse/entity-state contract'),
    ],
    'lua/ace/shared/rounds/roundclusterheat.lua': [
        (frozenset({(301, 1)}), 'blocked', 'physics/fuse/entity-state contract'),
    ],
    'lua/ace/shared/sh_ace_functions.lua': [
        (frozenset({(495, 1), (507, 1)}), 'engine-bound', 'load-order/compatibility or server callback contract'),
    ],
    'lua/ace/shared/sh_ace_sound_loader.lua': [
        (frozenset({(80, 1)}), 'engine-bound', 'load-order/compatibility or server callback contract'),
    ],
    'lua/ace/shared/sh_acfm_roundinject.lua': [
        (frozenset({(182, 1), (183, 1), (184, 1)}), 'engine-bound', 'load-order/compatibility or server callback contract'),
    ],
    'lua/autorun/ace_entity_aliases.lua': [
        (frozenset({(40, 1), (41, 1)}), 'engine-bound', 'load-order/compatibility or server callback contract'),
    ],
    'lua/autorun/acf_globals.lua': [
        (frozenset({(515, 1), (522, 1)}), 'engine-bound', 'initialization/realm contract'),
        (frozenset({(597, 1), (601, 1), (610, 1), (615, 1)}), 'migrated', 'ACE.Wind'),
    ],
    'lua/autorun/client/cl_ace_vignette.lua': [
        (frozenset({(9, 1)}), 'engine-bound', 'realm/input/presentation contract'),
    ],
    'lua/autorun/client/cl_acfm_menuinject.lua': [
        (frozenset({(299, 1), (308, 1), (372, 1), (379, 1)}), 'engine-bound', 'realm/input/presentation contract'),
    ],
    'lua/autorun/server/sv_acf_missiles.lua': [
        (frozenset({(241, 1), (250, 1)}), 'engine-bound', 'initialization/realm contract'),
    ],
    'lua/entities/ace_crewseat_driver/init.lua': [
        (frozenset({(200, 1)}), 'blocked', 'entity validity and delayed-callback contract'),
        (frozenset({(69, 1)}), 'engine-bound', 'entity Think/lifecycle/Wire ordering contract'),
    ],
    'lua/entities/ace_crewseat_gunner/init.lua': [
        (frozenset({(190, 1)}), 'blocked', 'entity validity and delayed-callback contract'),
        (frozenset({(86, 1)}), 'engine-bound', 'entity Think/lifecycle/Wire ordering contract'),
    ],
    'lua/entities/ace_crewseat_loader/init.lua': [
        (frozenset({(128, 1)}), 'engine-bound', 'entity Think/lifecycle/Wire ordering contract'),
    ],
    'lua/entities/ace_debris.lua': [
        (frozenset({(30, 1)}), 'migrated', 'ACE.EntityRemoval'),
    ],
    'lua/entities/ace_ecm/init.lua': [
        (frozenset({(73, 1), (89, 1), (92, 1)}), 'engine-bound', 'entity Think/lifecycle/Wire ordering contract'),
    ],
    'lua/entities/ace_explosive/init.lua': [
        (frozenset({(167, 1)}), 'blocked', 'entity validity and delayed-callback contract'),
    ],
    'lua/entities/ace_explosive_prebuilt/init.lua': [
        (frozenset({(153, 1)}), 'blocked', 'entity validity and delayed-callback contract'),
    ],
    'lua/entities/ace_flare/init.lua': [
        (frozenset({(35, 1)}), 'migrated', 'ACE.EntityRemoval'),
        (frozenset({(57, 1), (75, 1)}), 'migrated', 'ACE.FlareThink'),
    ],
    'lua/entities/ace_gforce_meter/init.lua': [
        (frozenset({(161, 1), (165, 1), (178, 1)}), 'migrated', 'ACE.GForceMeterThink'),
    ],
    'lua/entities/ace_grenade/init.lua': [
        (frozenset({(34, 1)}), 'engine-bound', 'entity Think/lifecycle/Wire ordering contract'),
    ],
    'lua/entities/ace_irst/init.lua': [
        (frozenset({(417, 1), (446, 1)}), 'engine-bound', 'entity Think/lifecycle/Wire ordering contract'),
    ],
    'lua/entities/ace_mine/init.lua': [
        (frozenset({(40, 1), (79, 1)}), 'blocked', 'entity validity and delayed-callback contract'),
        (frozenset({(93, 1)}), 'engine-bound', 'entity Think/lifecycle/Wire ordering contract'),
    ],
    'lua/entities/ace_missile/init.lua': [
        (frozenset({(114, 1), (121, 1), (657, 1)}), 'blocked', 'physics/fuse/entity-state contract'),
    ],
    'lua/entities/ace_rwr_dir/init.lua': [
        (frozenset({(86, 1), (89, 1)}), 'engine-bound', 'entity Think/lifecycle/Wire ordering contract'),
    ],
    'lua/entities/ace_rwr_sphere/init.lua': [
        (frozenset({(84, 1), (87, 1)}), 'engine-bound', 'entity Think/lifecycle/Wire ordering contract'),
    ],
    'lua/entities/ace_scalability/init.lua': [
        (frozenset({(146, 1), (147, 1)}), 'migrated', 'ACE.ScalableResync'),
    ],
    'lua/entities/ace_searchradar/init.lua': [
        (frozenset({(146, 1), (267, 1), (273, 1)}), 'engine-bound', 'entity Think/lifecycle/Wire ordering contract'),
    ],
    'lua/entities/ace_slammine/cl_init.lua': [
        (frozenset({(30, 1)}), 'engine-bound', 'entity Think/lifecycle/Wire ordering contract'),
    ],
    'lua/entities/ace_slammine/init.lua': [
        (frozenset({(103, 1)}), 'blocked', 'entity validity and delayed-callback contract'),
        (frozenset({(71, 1)}), 'engine-bound', 'entity Think/lifecycle/Wire ordering contract'),
    ],
    'lua/entities/ace_smokegrenade/init.lua': [
        (frozenset({(43, 1)}), 'engine-bound', 'entity Think/lifecycle/Wire ordering contract'),
    ],
    'lua/entities/ace_sonar/init.lua': [
        (frozenset({(446, 1), (594, 1), (717, 1)}), 'blocked', 'entity validity and delayed-callback contract'),
        (frozenset({(232, 1), (1000, 1), (1041, 1)}), 'engine-bound', 'entity Think/lifecycle/Wire ordering contract'),
        (frozenset({(568, 1)}), 'migrated', 'ACE.SonarPingExpiry'),
        (frozenset({(555, 1), (587, 1)}), 'migrated', 'ACE.SonarTravelSound'),
    ],
    'lua/entities/ace_trackingradar/init.lua': [
        (frozenset({(149, 1), (159, 1), (475, 1), (477, 1)}), 'engine-bound', 'entity Think/lifecycle/Wire ordering contract'),
    ],
    'lua/entities/ace_vheat_source/init.lua': [
        (frozenset({(140, 1), (143, 1), (157, 1)}), 'migrated', 'ACE.VHeatSourceThink'),
    ],
    'lua/entities/ace_wind_sensor/init.lua': [
        (frozenset({(110, 1), (113, 1), (123, 1)}), 'migrated', 'ACE.WindSensorThink'),
    ],
    'lua/entities/acf_ammo/init.lua': [
        (frozenset({(786, 1), (837, 1), (870, 1), (876, 1), (882, 1), (933, 1), (992, 1)}), 'blocked', 'physics/fuse/entity-state contract'),
        (frozenset({(963, 1)}), 'migrated', 'ACE.AmmoCookoffFlash'),
    ],
    'lua/entities/acf_engine/init.lua': [
        (frozenset({(503, 1), (561, 1), (1132, 1)}), 'blocked', 'physics/fuse/entity-state contract'),
    ],
    'lua/entities/acf_explosive/init.lua': [
        (frozenset({(171, 1), (173, 1), (200, 1)}), 'blocked', 'physics/fuse/entity-state contract'),
    ],
    'lua/entities/acf_fueltank/init.lua': [
        (frozenset({(136, 1), (143, 1), (430, 1), (447, 1), (452, 1), (457, 1)}), 'blocked', 'physics/fuse/entity-state contract'),
    ],
    'lua/entities/acf_gearbox/init.lua': [
        (frozenset({(424, 1), (440, 1), (880, 1)}), 'blocked', 'physics/fuse/entity-state contract'),
    ],
    'lua/entities/acf_gun/cl_init.lua': [
        (frozenset({(38, 1)}), 'blocked', 'physics/fuse/entity-state contract'),
    ],
    'lua/entities/acf_gun/init.lua': [
        (frozenset({(327, 1), (540, 1), (601, 1), (745, 1), (846, 1), (1035, 1)}), 'blocked', 'physics/fuse/entity-state contract'),
        (frozenset({(1174, 1)}), 'migrated', 'ACE.GunAutoSound'),
    ],
    'lua/entities/acf_missile_to_rack/init.lua': [
        (frozenset({(20, 1)}), 'engine-bound', 'entity Think/lifecycle/Wire ordering contract'),
    ],
    'lua/entities/acf_missileradar/init.lua': [
        (frozenset({(222, 1), (231, 1)}), 'engine-bound', 'entity Think/lifecycle/Wire ordering contract'),
    ],
    'lua/entities/acf_opticalcomputer/init.lua': [
        (frozenset({(36, 1)}), 'engine-bound', 'entity Think/lifecycle/Wire ordering contract'),
    ],
    'lua/entities/acf_rack/init.lua': [
        (frozenset({(327, 1), (330, 1)}), 'blocked', 'physics/fuse/entity-state contract'),
    ],
    'lua/weapons/gmod_tool/stools/acechaircam.lua': [
        (frozenset({(33, 1)}), 'engine-bound', 'realm/input/presentation contract'),
    ],
    'lua/weapons/weapon_ace_antipersonmine/shared.lua': [
        (frozenset({(105, 1)}), 'engine-bound', 'realm/input/presentation contract'),
    ],
    'lua/weapons/weapon_ace_antitankmine/shared.lua': [
        (frozenset({(105, 1)}), 'engine-bound', 'realm/input/presentation contract'),
    ],
    'lua/weapons/weapon_ace_base/init.lua': [
        (frozenset({(133, 1)}), 'engine-bound', 'realm/input/presentation contract'),
    ],
    'lua/weapons/weapon_ace_base/shared.lua': [
        (frozenset({(109, 1), (444, 1)}), 'engine-bound', 'realm/input/presentation contract'),
    ],
    'lua/weapons/weapon_ace_boundingmine/shared.lua': [
        (frozenset({(105, 1)}), 'engine-bound', 'realm/input/presentation contract'),
    ],
    'lua/weapons/weapon_ace_flaregun/shared.lua': [
        (frozenset({(49, 1)}), 'engine-bound', 'realm/input/presentation contract'),
    ],
    'lua/weapons/weapon_ace_grenade/shared.lua': [
        (frozenset({(54, 1), (56, 1), (134, 1)}), 'engine-bound', 'realm/input/presentation contract'),
    ],
    'lua/weapons/weapon_ace_javelin/shared.lua': [
        (frozenset({(472, 1)}), 'engine-bound', 'realm/input/presentation contract'),
    ],
    'lua/weapons/weapon_ace_minedetector/init.lua': [
        (frozenset({(199, 1), (275, 1), (291, 1), (295, 1), (406, 1), (585, 1)}), 'engine-bound', 'realm/input/presentation contract'),
    ],
    'lua/weapons/weapon_ace_minedetector/shared.lua': [
        (frozenset({(270, 1)}), 'engine-bound', 'realm/input/presentation contract'),
    ],
    'lua/weapons/weapon_ace_portablemortar/shared.lua': [
        (frozenset({(589, 1)}), 'engine-bound', 'realm/input/presentation contract'),
    ],
    'lua/weapons/weapon_ace_slam/shared.lua': [
        (frozenset({(230, 1)}), 'engine-bound', 'realm/input/presentation contract'),
    ],
    'lua/weapons/weapon_ace_smokegrenade/shared.lua': [
        (frozenset({(54, 1), (56, 1), (133, 1)}), 'engine-bound', 'realm/input/presentation contract'),
    ],
    'lua/weapons/weapon_ace_stinger/shared.lua': [
        (frozenset({(426, 1)}), 'engine-bound', 'realm/input/presentation contract'),
    ],
    'lua/weapons/weapon_ace_torch/shared.lua': [
        (frozenset({(58, 1), (78, 1)}), 'engine-bound', 'realm/input/presentation contract'),
    ],
    'lua/weapons/weapon_szcreator/shared.lua': [
        (frozenset({(147, 1)}), 'engine-bound', 'realm/input/presentation contract'),
    ],
}


REVIEWED_FILE_HASHES = {
    'lua/ace/client/cl_acemenu_gui.lua': '3de2452b6008ef4daf293811b41fe9d69acd2bdc5028e5f03d041a0ba598c428',
    'lua/ace/client/cl_acfballistics.lua': 'd2b6065575a829994f2cd9244fcc0af1c808f7d43cd1f39a5fb3710d62012767',
    'lua/ace/client/cl_soundbase.lua': '1ff6b5caf88fec7168689391864725184b2656ff7a667297b44a56a5248c451d',
    'lua/ace/server/sv_ace_ammo_cookoff_scheduler.lua': '9b209ac32d95d7c769f3f29e3c897d3e4e47efeb935904b7136940aa1618cd7d',
    'lua/ace/server/sv_ace_damage_effect_scheduler.lua': '3e448609be2ff32845a3e6235f809eed3c34a11d06a7119524ba77d78cd952dc',
    'lua/ace/server/sv_ace_debris_scheduler.lua': '4ced35a03edbf543a0b46e31ffb3627e1cac51ef487b298d77dbbb2553bec4d8',
    'lua/ace/server/sv_ace_flare_scheduler.lua': '3733cbe10002418c72a87224459e8183ee163a4a603868cbfb0faedeb3c7eea6',
    'lua/ace/server/sv_ace_gforce_meter_scheduler.lua': '72f34d9b26b747bb097aed025dbd7e13bab8e96fefb43c3e416a0dc6a2ff4be9',
    'lua/ace/server/sv_ace_gun_autosound_scheduler.lua': '7c29be7b7bd1892d9647b64f1b8032bc10a04d97baebf031d9c6ac01505e434e',
    'lua/ace/server/sv_ace_legalcheck.lua': '9dcf14326af1a07cdf639d7c94609d87db46e87982af03ff91fcac88f8118152',
    'lua/ace/server/sv_ace_renderqueue.lua': 'b9b4dbb94ec1d795efebcaf7f58a34a51600cecbbbae648ccf998f7d039566a0',
    'lua/ace/server/sv_ace_safezone.lua': '8c64609374b32a40da3496db25cc4fadc554e2731700c67152809b6a7003da62',
    'lua/ace/server/sv_ace_scalability_scheduler.lua': '0d61986e31d9ff6eca91507161e320d0ecb07d9b36a18c139ad7bc59509e8e54',
    'lua/ace/server/sv_ace_scheduler.lua': '6581cf59353ac1cc6661eab93bffa3125368e34b868652990a67c99fd49c5955',
    'lua/ace/server/sv_ace_sonar_scheduler.lua': 'f1800a31cbcc8ddd7f786f009c891eea8b9ec027c1e4098981fe8012b04d66a5',
    'lua/ace/server/sv_ace_vheat_source_scheduler.lua': '876a06816d9a1374e69c6f19b28ac4ae99a89cc8342c8c2422b4272f02815c96',
    'lua/ace/server/sv_ace_wind_sensor_scheduler.lua': '9ae7e2986c50c3f37cee071d7494a94f565b6499beb76183d5407f71c0340329',
    'lua/ace/server/sv_acfballistics.lua': '49f5dce5949f9ef2aa9410cce2169ad0a3e4655f55734bd017e4c5a42b9aec7d',
    'lua/ace/server/sv_acfdamage.lua': '0797c2549c0969caa5e58581a55bc4c07a82f7aa695e5129076913eb021b84df',
    'lua/ace/server/sv_acfpermission.lua': 'b478579175a5101122151ffc3f6f4643a3d9ff1ee443ac446a50415e4ca945ee',
    'lua/ace/server/sv_contraption.lua': 'f0a71cbaed13621563d6fb3f363c6f504705bf129046d69de29ac870bf94eb25',
    'lua/ace/server/sv_contraptionlegality.lua': '24fc05d6b8193c1c246c7812542f0cd3e88231b707b523213f4a9c52353e399d',
    'lua/ace/server/sv_crewseat_base.lua': 'b69ccf49eb5fc61a4f3baf6b9b0468414aafe61e699284e6701bc8db50963493',
    'lua/ace/server/sv_pointshandling.lua': 'bf73912ec80d833cec01abaf60518953fed52f5e2cc14814ae8815a286140e16',
    'lua/ace/shared/armor/du.lua': 'c1d790242cecd8ff581d989506445713ae90728c548d9d51cf3942ec677a3d2e',
    'lua/ace/shared/armor/era.lua': '5d896c296c9fffc88f9a330bf229b33eb508ce6422fef288e89300409aefeed0',
    'lua/ace/shared/compatibility/cppiCompatibility.lua': 'cf1a4c10df2549a819cb4eebcde4a780cb2315506f7edfcc3667b20b65928679',
    'lua/ace/shared/fuses/e_plunging.lua': '73f2e041c01b7a589a5c45ffecc32c4f61ea361fb0b72143689b67414ebabae9',
    'lua/ace/shared/rounds/roundclusterap.lua': '1a4a96c5b9a9f25abfd91c49f59be5ef1fa7681455bb38d183ef18b3594b9181',
    'lua/ace/shared/rounds/roundclusterhe.lua': 'd8e6641a8f79fb7a8fd96e4e7f0e9cf04904dfa5b1b0de5d9652ed5fab9412bd',
    'lua/ace/shared/rounds/roundclusterheat.lua': '54bf8d44757773a787283e84f2f6ec3722b0cd052edb0ccaa9fbd0766a762d3f',
    'lua/ace/shared/sh_ace_functions.lua': 'b457d2f99583b4999a07a68bb00ac721fa0ebf31a100ae583f9be98754f78507',
    'lua/ace/shared/sh_ace_sound_loader.lua': 'e6b87edb025492f8eda9f1aab7d3fa616b426ba65d3ca2454515054951ae21ea',
    'lua/ace/shared/sh_acfm_roundinject.lua': 'f7d6c0df96ffb537d406014fe76cae72c342a57f997f94b445cf094e25568048',
    'lua/autorun/ace_entity_aliases.lua': 'e8854a2fe70f22d36cca117af7e2c93eb22579663b69b7d8639940116a32b866',
    'lua/autorun/acf_globals.lua': 'ff62c04fab7bf4e23ac506e56e8ace26db6332952cfd6aa1d87bbc695e5dab9f',
    'lua/autorun/client/cl_ace_vignette.lua': '923adabba7e039d4a6dc4d40b199e96b1182c8a1ebb6a7fe675b37a96dedbe9c',
    'lua/autorun/client/cl_acfm_menuinject.lua': 'ef1bcf99d8aa47946120a481dfe374e0c5278bc00a3467582889fa2854a29673',
    'lua/autorun/server/sv_acf_missiles.lua': '71a98faa2cdedd22374cb986425ac96f5d4ada9dd08652ba6a04d66e6f7b3981',
    'lua/entities/ace_crewseat_driver/init.lua': '6f9582cb59a440d9f8abecf3394870ffb4a02439468304d01c4732d1a4b9a545',
    'lua/entities/ace_crewseat_gunner/init.lua': '5c6b725cb2cd84167dcfdfed974f9f7ab36f5e3ff2b65e8e73b13828d30d44c1',
    'lua/entities/ace_crewseat_loader/init.lua': 'e69858716190f99551ed89dc2eeaf1f26917863d417881be85050ab1f66af289',
    'lua/entities/ace_debris.lua': '0126bae6039d4a7bed4f4606834ef968dc3a2b2119459c3185ef582930886fe8',
    'lua/entities/ace_ecm/init.lua': '233dc7e61b48a744e3b37532d68c849a234509969406534ecd7828228a92ce81',
    'lua/entities/ace_explosive/init.lua': '7ca135db05d691a66201082c65c3edf8c968624bac6e8eb9da915caaa317f667',
    'lua/entities/ace_explosive_prebuilt/init.lua': '17402eba300b3f166b9968eac5aab1514b3cbf9ee787d54746485452e6f02684',
    'lua/entities/ace_flare/init.lua': 'd342bd1739001803443ddd206404ead3720578278314ab287679b35978cc86e6',
    'lua/entities/ace_gforce_meter/init.lua': 'ca943c0fef8040a4ec861bd2492d0b92750dba47ff16b4546439e78cd73313fc',
    'lua/entities/ace_grenade/init.lua': 'd85e5a3c7ebd48884e6769f2ecc42d35f89ab120c59e7679ad4452dbd8cd2702',
    'lua/entities/ace_irst/init.lua': '602e112a87e360415073ef8735f3a35736ba5c0508f01b31a937371890af481c',
    'lua/entities/ace_mine/init.lua': '459c438de1eeb48c00029d24b813380e7acddbf156ad83dc2287905c5be2c15c',
    'lua/entities/ace_missile/init.lua': '50e553c04977f36445063a23fdd027700e72af0ae39110b50228197bb7cc2af8',
    'lua/entities/ace_rwr_dir/init.lua': 'a519ab6f92ce0dd6c5624026b200580957676a4b6b9bac82cb86453c48d611e4',
    'lua/entities/ace_rwr_sphere/init.lua': '81fad2f0a4ff33f9b85df06eb9e8109c4ad9979bb43ab49b539713aa77b4cfed',
    'lua/entities/ace_scalability/init.lua': 'd5bd0298636d2d6169ea306c884f5aeee71498b6bce3d9b71516c052410e50a8',
    'lua/entities/ace_searchradar/init.lua': '210217fe6b7bb965c74c17b4dc16c44e28badfb2d59fc3311f27f23f47de5a8a',
    'lua/entities/ace_slammine/cl_init.lua': 'd1a37c94c25b3d7f31d2597c3cec5e5773150697f389997d3a5bf33064fe3e61',
    'lua/entities/ace_slammine/init.lua': '51ab3fe76da0949cafb770a98cd66dbc026cf807ffee3c552c6ee8bc1e4c5ceb',
    'lua/entities/ace_smokegrenade/init.lua': 'f06ab445e6c6e133ecfcd5498b3510bd5541bc85d568f6bdda0f6f1111900275',
    'lua/entities/ace_sonar/init.lua': '5bc67c86b1294d574a6ea3c9e30a60043d753a4331da4ced078d77728c725faf',
    'lua/entities/ace_trackingradar/init.lua': 'f323cd2ad699595cb06ddf47f9ac6dffcd7250cc0f8442a2c82212ece9b99793',
    'lua/entities/ace_vheat_source/init.lua': 'ec7adc4248401d376862f85ebc321aba768a0ba4e007e2efe8461445214b3b1d',
    'lua/entities/ace_wind_sensor/init.lua': '901a984aa9c2a1a9acb50b2380b2a8a470772e69361293e4fc688c6e2fdf3381',
    'lua/entities/acf_ammo/init.lua': 'ab0927d5c8556c300b0e73455092d073355731356d910bb1786e20d7bd87ef73',
    'lua/entities/acf_engine/init.lua': 'daeec1fa1abbbc98d695a324f1f133d8b0827327692ef2952847f9b8a54b4cc6',
    'lua/entities/acf_explosive/init.lua': '9f86d5cc86c3909bf06ece5008484587b62a52ec1b400583886e8713a9217f76',
    'lua/entities/acf_fueltank/init.lua': 'baba9265b0925442d1b1a62d19aa31245fd811ff7bafd8635a8720ff3444dcf4',
    'lua/entities/acf_gearbox/init.lua': '721a370741d06fed24378d91b8d7c8c5ae8d0172d5369991c0e44b925779e2a5',
    'lua/entities/acf_gun/cl_init.lua': 'a462012ed01491cf10db921f52f771492aaf735cb4ce06568d198728732a9d73',
    'lua/entities/acf_gun/init.lua': 'a1a7bbe1623f208d3ba68a51e801cafde1e9fa0c2756eb6f902be7a170dfe3d8',
    'lua/entities/acf_missile_to_rack/init.lua': 'fd6914126bf9a0ca65ce359d04898cde18cb519d95bfe4c49fbfbe6e58db6f8c',
    'lua/entities/acf_missileradar/init.lua': '1f8a4264665c204deda429470c59e74f222b331f0e9c5a55734a4d7ea3e87bf5',
    'lua/entities/acf_opticalcomputer/init.lua': 'ac39509d2a6a9d49b5c2653e64f3ac36c6e62b93d3aeb0e6d03e6bbd76ecaa84',
    'lua/entities/acf_rack/init.lua': '80bdc2521e4283dac61852aa75071c625c36b0bb2819e674830182bde8762aa0',
    'lua/weapons/gmod_tool/stools/acechaircam.lua': '78c5d6c190e88eecba13448dabf4df9b37dd8af56d9190877ce3d93048e86d59',
    'lua/weapons/weapon_ace_antipersonmine/shared.lua': 'dc6dcf363c41134b1360ec8613ad940b1f03e161ee646b95847c856de5c9633f',
    'lua/weapons/weapon_ace_antitankmine/shared.lua': '5aede11c4cb5ce771f1e246c0160623c556cff635ceb5e20bc14f4e84b891633',
    'lua/weapons/weapon_ace_base/init.lua': '9861e7c0f1a9c454f5ea0073bb45f8b539a1e6826ffb8d5717c6eb2fd4904530',
    'lua/weapons/weapon_ace_base/shared.lua': 'a30c4dc216f2179cf6657e42c53a7ec252aea4f07d78f6b13579d55dda46a8fa',
    'lua/weapons/weapon_ace_boundingmine/shared.lua': '5b15bee1b7dfc6d7e2953eb5887f03e9bfff91f04d8a0dd13535c06cc84ae3e7',
    'lua/weapons/weapon_ace_flaregun/shared.lua': 'b6aefa04ae675f71481af811ed0a243c6eede764835dd5a8816d270576162ea8',
    'lua/weapons/weapon_ace_grenade/shared.lua': '6ae3f1135452426ef6b6d9b302e5d171743cc5f8980583696b457f436c675033',
    'lua/weapons/weapon_ace_javelin/shared.lua': 'a23cf279d37bd7f7b211e4dfbe8c91ad9426c5a8e93ce7fa3b406b5028ae9ce1',
    'lua/weapons/weapon_ace_minedetector/init.lua': '951543718a5a1d28a023b0770dd42029873144b33e6422b688682c55b7c14c34',
    'lua/weapons/weapon_ace_minedetector/shared.lua': 'f9cc89bde01765fd02889507277c8a0cfe4298bdc30dc8b6d43c259b00391de1',
    'lua/weapons/weapon_ace_portablemortar/shared.lua': 'c0ee758f74b7538744f0ce055c5e049ea8be8ab88fed5ed9f4e8a3d8f1d25ed8',
    'lua/weapons/weapon_ace_slam/shared.lua': '7f2df27542d6e635edafa70121ce23471e4534ba7bd2139437ca58c134ffa990',
    'lua/weapons/weapon_ace_smokegrenade/shared.lua': '2ccec226e32f23a49a3a7be597523c7f74ed5e7371b0f906c878fe72a7fe7eb5',
    'lua/weapons/weapon_ace_stinger/shared.lua': '2871791397851dbfbb071ee0575b09183326a8d4bbb4d0e31843644f64eeed9c',
    'lua/weapons/weapon_ace_torch/shared.lua': '5fb43c3cc651c364a7a9913a4e26323c1a94cce49bf96357662208260c9c7977',
    'lua/weapons/weapon_szcreator/shared.lua': '288af14cde82af0e920087f73a9c425be56b4c28fc00cea119b0877b041031bb',
}

MIGRATED_EVIDENCE = {
    "ACE.PointFlush": ("partial", "LuaJIT direct/scheduled point parity and teardown; dynamic mutation sensitivity open"),
    "ACE.PeriodicCleanup": ("partial", "LuaJIT activation/disable/teardown; active-contraption scaling open"),
    "ACE.PermissionModeThink": ("passing", "LuaJIT activation/teardown and cadence"),
    "ACE.SafezoneTransition": ("partial", "LuaJIT activation, cadence, entry/exit delivery, and teardown; relative hook-order parity remains open"),
    "ACE.SafezoneVisualization": ("partial", "LuaJIT delayed-callback parity, fallback invalidation, reload, and teardown; presentation ordering open"),
    "ACE.ContraptionLegalCheck": ("partial", "LuaJIT per-entity cooldown parity, validity guard, reload, and fallback teardown; warning-scan parity open"),
    "ACE.Wind": ("partial", "LuaJIT activation/disable/teardown; full reset broadcast/cadence parity open"),
    "ACE.RenderPropDamage": ("partial", "LuaJIT coalescing/cadence/reload/teardown; packet parity open"),
    "ACE.WindSensorThink": ("partial", "LuaJIT cadence, fallback, removal, reload, and key-ownership coverage; connected Wire packet ordering and larger-scale load scaling open"),
    "ACE.ScalableResync": ("partial", "LuaJIT reverse-order live-table parity, one-per-tick pacing, replacement, disconnect cancellation, reload, and enable/disable fallback coverage; direct net receiver and disconnect cancellation remain open"),
    "ACE.VHeatSourceThink": ("partial", "LuaJIT fixed-step heat/clamp, Wire/overlay ordering, two-entity independence, phase-preserving fallback, removal, and enabled reload coverage; recurrence, connected Wire packet, and larger-scale load scaling remain open"),
    "ACE.GForceMeterThink": ("partial", "LuaJIT fixed-step output/overlay ordering, independent entities, fallback phase, removal, and enabled reload coverage; dynamic physics parity, connected Wire packet, and larger-scale load scaling remain open"),
    "ACE.EntityRemoval": ("partial", "LuaJIT one-shot heap/fallback parity for debris and flare lifetimes, replacement, cancellation, invalid-entity guard, and disable restoration; larger-scale timer/dispatch cost remains open"),
    "ACE.GunAutoSound": ("partial", "LuaJIT heap/fallback parity for independent delayed gun sounds, argument preservation, invalid-gun guard, invalidation-before-delivery, reload, and disable restoration; larger-scale dispatch cost remains open"),
    "ACE.AmmoCookoffFlash": ("partial", "LuaJIT heap/fallback parity for independent delayed flashes, dynamic position capture, invalid-ammo guard, invalidation-before-reload cleanup, and disable restoration; larger-scale dispatch cost remains open"),
    "ACE.DamageDetonationEffect": ("partial", "LuaJIT heap/fallback parity for independent delayed detonation effects, argument preservation, reload, and disable restoration; larger-scale dispatch cost remains open"),
    "ACE.FlareThink": ("partial", "LuaJIT fixed-step signature parity, fallback phase, underwater stop/frozen radar signature, disable, unregister, and enabled-reload coverage; larger-scale cadence cost remains open"),
    "ACE.SonarTravelSound": ("partial", "LuaJIT behavioral parity for heap/timer selection, disable/re-enable fallback, due-time delivery, invalid-base cleanup, and teardown; audible delivery and larger-scale dispatch cost remain open"),
    "ACE.SonarPingExpiry": ("partial", "LuaJIT heap/fallback parity for stale-cache expiry, per-contraption/ping coalescing, invalid-base rejection, replacement, due cleanup, and teardown; whole-server lag attribution remains open"),
}

EXPECTED_MIGRATED_PRIMITIVES = {
    ('lua/ace/server/sv_ace_ammo_cookoff_scheduler.lua', 24, 1): 'timer.Remove',
    ('lua/ace/server/sv_ace_ammo_cookoff_scheduler.lua', 37, 1): 'timer.Remove',
    ('lua/ace/server/sv_ace_ammo_cookoff_scheduler.lua', 51, 1): 'timer.Create',
    ('lua/ace/server/sv_ace_ammo_cookoff_scheduler.lua', 73, 1): 'timer.Remove',
    ('lua/ace/server/sv_ace_ammo_cookoff_scheduler.lua', 127, 1): 'ACE.Scheduler.RegisterAdapter(',
    ('lua/ace/server/sv_ace_damage_effect_scheduler.lua', 26, 1): 'timer.Remove',
    ('lua/ace/server/sv_ace_damage_effect_scheduler.lua', 38, 1): 'timer.Create',
    ('lua/ace/server/sv_ace_damage_effect_scheduler.lua', 59, 1): 'timer.Remove',
    ('lua/ace/server/sv_ace_damage_effect_scheduler.lua', 107, 1): 'ACE.Scheduler.RegisterAdapter(',
    ('lua/ace/server/sv_ace_debris_scheduler.lua', 25, 1): 'timer.Remove',
    ('lua/ace/server/sv_ace_debris_scheduler.lua', 38, 1): 'timer.Remove',
    ('lua/ace/server/sv_ace_debris_scheduler.lua', 44, 1): 'timer.Create',
    ('lua/ace/server/sv_ace_debris_scheduler.lua', 66, 1): 'timer.Remove',
    ('lua/ace/server/sv_ace_debris_scheduler.lua', 132, 1): 'ACE.Scheduler.RegisterAdapter(',
    ('lua/ace/server/sv_ace_flare_scheduler.lua', 34, 1): 'NextThink(',
    ('lua/ace/server/sv_ace_flare_scheduler.lua', 124, 1): 'NextThink(',
    ('lua/ace/server/sv_ace_flare_scheduler.lua', 158, 1): 'NextThink(',
    ('lua/ace/server/sv_ace_flare_scheduler.lua', 164, 1): 'ACE.Scheduler.RegisterAdapter(',
    ('lua/ace/server/sv_ace_gforce_meter_scheduler.lua', 46, 1): 'NextThink(',
    ('lua/ace/server/sv_ace_gforce_meter_scheduler.lua', 71, 1): 'NextThink(',
    ('lua/ace/server/sv_ace_gforce_meter_scheduler.lua', 119, 1): 'ACE.Scheduler.RegisterAdapter(',
    ('lua/ace/server/sv_ace_gun_autosound_scheduler.lua', 24, 1): 'timer.Remove',
    ('lua/ace/server/sv_ace_gun_autosound_scheduler.lua', 32, 1): 'timer.Remove',
    ('lua/ace/server/sv_ace_gun_autosound_scheduler.lua', 42, 1): 'timer.Create',
    ('lua/ace/server/sv_ace_gun_autosound_scheduler.lua', 69, 1): 'timer.Remove',
    ('lua/ace/server/sv_ace_gun_autosound_scheduler.lua', 121, 1): 'ACE.Scheduler.RegisterAdapter(',
    ('lua/ace/server/sv_ace_legalcheck.lua', 54, 1): 'timer.Simple',
    ('lua/ace/server/sv_ace_legalcheck.lua', 63, 1): 'ACE.ScheduleLegalCheckReset(',
    ('lua/ace/server/sv_ace_legalcheck.lua', 78, 1): 'timer.Simple',
    ('lua/ace/server/sv_ace_legalcheck.lua', 85, 1): 'ACE.Scheduler.RegisterAdapter(',
    ('lua/ace/server/sv_ace_renderqueue.lua', 106, 1): 'ACE.Scheduler.RegisterAdapter(',
    ('lua/ace/server/sv_ace_safezone.lua', 49, 1): 'timer.Simple',
    ('lua/ace/server/sv_ace_safezone.lua', 56, 1): 'ACE.ScheduleSafezoneVisualization(',
    ('lua/ace/server/sv_ace_safezone.lua', 67, 1): 'timer.Simple',
    ('lua/ace/server/sv_ace_safezone.lua', 78, 1): 'ACE.Scheduler.RegisterAdapter(',
    ('lua/ace/server/sv_ace_safezone.lua', 120, 1): 'hook.Add("Think"',
    ('lua/ace/server/sv_ace_safezone.lua', 129, 1): 'ACE.Scheduler.RegisterAdapter(',
    ('lua/ace/server/sv_ace_safezone.lua', 136, 1): 'hook.Add("Think"',
    ('lua/ace/server/sv_ace_scalability_scheduler.lua', 23, 1): 'timer.Remove',
    ('lua/ace/server/sv_ace_scalability_scheduler.lua', 51, 1): 'timer.Remove',
    ('lua/ace/server/sv_ace_scalability_scheduler.lua', 59, 1): 'timer.Create',
    ('lua/ace/server/sv_ace_scalability_scheduler.lua', 77, 1): 'timer.Remove',
    ('lua/ace/server/sv_ace_scalability_scheduler.lua', 89, 1): 'timer.Create',
    ('lua/ace/server/sv_ace_scalability_scheduler.lua', 127, 1): 'timer.Create',
    ('lua/ace/server/sv_ace_scalability_scheduler.lua', 140, 1): 'ACE.Scheduler.RegisterAdapter(',
    ('lua/ace/server/sv_ace_sonar_scheduler.lua', 34, 1): 'timer.Remove',
    ('lua/ace/server/sv_ace_sonar_scheduler.lua', 47, 1): 'timer.Remove',
    ('lua/ace/server/sv_ace_sonar_scheduler.lua', 57, 1): 'timer.Create',
    ('lua/ace/server/sv_ace_sonar_scheduler.lua', 79, 1): 'timer.Remove',
    ('lua/ace/server/sv_ace_sonar_scheduler.lua', 107, 1): 'timer.Remove',
    ('lua/ace/server/sv_ace_sonar_scheduler.lua', 126, 1): 'timer.Remove',
    ('lua/ace/server/sv_ace_sonar_scheduler.lua', 140, 1): 'timer.Create',
    ('lua/ace/server/sv_ace_sonar_scheduler.lua', 166, 1): 'timer.Remove',
    ('lua/ace/server/sv_ace_sonar_scheduler.lua', 285, 1): 'ACE.Scheduler.RegisterAdapter(',
    ('lua/ace/server/sv_ace_sonar_scheduler.lua', 286, 1): 'ACE.Scheduler.RegisterAdapter(',
    ('lua/ace/server/sv_ace_vheat_source_scheduler.lua', 49, 1): 'NextThink(',
    ('lua/ace/server/sv_ace_vheat_source_scheduler.lua', 74, 1): 'NextThink(',
    ('lua/ace/server/sv_ace_vheat_source_scheduler.lua', 122, 1): 'ACE.Scheduler.RegisterAdapter(',
    ('lua/ace/server/sv_ace_wind_sensor_scheduler.lua', 49, 1): 'NextThink(',
    ('lua/ace/server/sv_ace_wind_sensor_scheduler.lua', 74, 1): 'NextThink(',
    ('lua/ace/server/sv_ace_wind_sensor_scheduler.lua', 121, 1): 'ACE.Scheduler.RegisterAdapter(',
    ('lua/ace/server/sv_acfdamage.lua', 1684, 1): 'timer.Simple',
    ('lua/ace/server/sv_acfpermission.lua', 111, 1): 'ACE.ScheduleSafezoneVisualization(',
    ('lua/ace/server/sv_acfpermission.lua', 509, 1): 'timer.Simple',
    ('lua/ace/server/sv_acfpermission.lua', 545, 1): 'ACE.Scheduler.RegisterAdapter(',
    ('lua/ace/server/sv_acfpermission.lua', 551, 1): 'timer.Simple',
    ('lua/ace/server/sv_contraption.lua', 324, 1): 'timer.Create',
    ('lua/ace/server/sv_contraption.lua', 329, 1): 'timer.Remove',
    ('lua/ace/server/sv_contraption.lua', 338, 1): 'timer.Create',
    ('lua/ace/server/sv_contraption.lua', 347, 1): 'ACE.Scheduler.RegisterAdapter(',
    ('lua/ace/server/sv_contraptionlegality.lua', 77, 1): 'ACE.ScheduleLegalCheckReset(',
    ('lua/ace/server/sv_pointshandling.lua', 460, 1): 'hook.Add("Think"',
    ('lua/ace/server/sv_pointshandling.lua', 463, 1): 'hook.Add("Think"',
    ('lua/ace/server/sv_pointshandling.lua', 465, 1): 'ACE.Scheduler.RegisterAdapter(',
    ('lua/autorun/acf_globals.lua', 597, 1): 'timer.Create',
    ('lua/autorun/acf_globals.lua', 601, 1): 'timer.Remove',
    ('lua/autorun/acf_globals.lua', 610, 1): 'timer.Create',
    ('lua/autorun/acf_globals.lua', 615, 1): 'ACE.Scheduler.RegisterAdapter(',
    ('lua/entities/ace_debris.lua', 30, 1): 'timer.Simple',
    ('lua/entities/ace_flare/init.lua', 35, 1): 'timer.Simple',
    ('lua/entities/ace_flare/init.lua', 57, 1): 'function ENT:Think(',
    ('lua/entities/ace_flare/init.lua', 75, 1): 'NextThink(',
    ('lua/entities/ace_gforce_meter/init.lua', 161, 1): 'function ENT:Think(',
    ('lua/entities/ace_gforce_meter/init.lua', 165, 1): 'NextThink(',
    ('lua/entities/ace_gforce_meter/init.lua', 178, 1): 'NextThink(',
    ('lua/entities/ace_scalability/init.lua', 146, 1): 'timer.Create',
    ('lua/entities/ace_scalability/init.lua', 147, 1): 'timer.RepsLeft',
    ('lua/entities/ace_sonar/init.lua', 555, 1): 'timer.Simple',
    ('lua/entities/ace_sonar/init.lua', 568, 1): 'timer.Simple',
    ('lua/entities/ace_sonar/init.lua', 587, 1): 'timer.Simple',
    ('lua/entities/ace_vheat_source/init.lua', 140, 1): 'function ENT:Think(',
    ('lua/entities/ace_vheat_source/init.lua', 143, 1): 'NextThink(',
    ('lua/entities/ace_vheat_source/init.lua', 157, 1): 'NextThink(',
    ('lua/entities/ace_wind_sensor/init.lua', 110, 1): 'function ENT:Think(',
    ('lua/entities/ace_wind_sensor/init.lua', 113, 1): 'NextThink(',
    ('lua/entities/ace_wind_sensor/init.lua', 123, 1): 'NextThink(',
    ('lua/entities/acf_ammo/init.lua', 963, 1): 'timer.Simple',
    ('lua/entities/acf_gun/init.lua', 1174, 1): 'timer.Simple',
}


def disposition(relative: str, line: int, occurrence: int, primitive: str) -> tuple[str, str]:
    for lines, status, reason in REVIEWED_ROWS.get(relative, []):
        if (line, occurrence) in lines:
            expected = EXPECTED_MIGRATED_PRIMITIVES.get((relative, line, occurrence))
            if expected and primitive != expected:
                return "pending", "reviewed primitive changed; re-audit this row"
            return status, reason
    return "pending", "focused ownership and parity audit required"


def nearest_symbol(lines: list[str], index: int) -> str:
    for previous in range(index, max(-1, index - 80), -1):
        match = FUNCTION_RE.search(lines[previous])
        if match:
            return match.group(1) or match.group(2) or "<anonymous>"
    return "<top-level>"


def scan(root: Path) -> list[dict[str, object]]:
    root = root.resolve()
    rows: list[dict[str, object]] = []
    for path in sorted((root / "lua").rglob("*.lua")):
        path = path.resolve()
        relative = path.relative_to(root).as_posix()
        lines = path.read_text(encoding="utf-8", errors="replace").splitlines()
        # Hash normalized LF bytes so the reviewed ledger is stable across Git
        # checkout settings and platform line endings.
        file_hash = hashlib.sha256(path.read_bytes().replace(b"\r\n", b"\n")).hexdigest()
        hash_reviewed = REVIEWED_FILE_HASHES.get(relative) == file_hash
        for index, line in enumerate(lines):
            if line.lstrip().startswith("--"):
                continue
            for occurrence, match in enumerate(SURFACE_RE.finditer(line), 1):
                primitive = match.group(0).strip()
                if hash_reviewed:
                    status, reason = disposition(relative, index + 1, occurrence, primitive)
                else:
                    status, reason = "pending", "reviewed source hash changed; re-audit every row"
                row = {
                    "source": relative,
                    "line": index + 1,
                    "occurrence": occurrence,
                    "primitive": primitive,
                    "preceding_declaration_hint": nearest_symbol(lines, index),
                    "preceding_declaration_hint_basis": "preceding declaration search; navigation aid, not ownership proof",
                    "status": status,
                    "reason": reason,
                }
                if status == "migrated":
                    row["evidence_state"], row["evidence"] = MIGRATED_EVIDENCE[reason]
                rows.append(row)
    return rows


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--repo", type=Path, default=Path(__file__).resolve().parents[1])
    parser.add_argument("--output", type=Path)
    parser.add_argument("--strict", action="store_true", help="fail if any row remains pending")
    args = parser.parse_args()

    rows = scan(args.repo.resolve())
    payload = {
        "schema": 1,
        "repo": str(args.repo.resolve()),
        "rows": rows,
        "counts": {status: sum(row["status"] == status for row in rows)
                   for status in ("migrated", "engine-bound", "blocked", "pending")},
    }
    if args.strict and payload["counts"]["pending"]:
        print(f"pending scheduling rows: {payload['counts']['pending']}", file=sys.stderr)
        return 1
    rendered = json.dumps(payload, indent=2, sort_keys=True) + "\n"
    if args.output:
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(rendered, encoding="utf-8")
    else:
        print(rendered, end="")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
