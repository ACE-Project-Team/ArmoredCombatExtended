# ACE - Armored Combat Extended

[![Website](https://img.shields.io/badge/Website-acegmod.com-E02020?style=flat-square)](https://acegmod.com)
[![Documentation](https://img.shields.io/badge/Docs-Wiki-blue?style=flat-square)](https://acegmod.com/wiki)
[![Discord](https://img.shields.io/discord/580463055595503646?label=Discord&style=flat-square&logo=discord)](https://discord.gg/Y8aEYU6)
[![Steam Workshop](https://img.shields.io/badge/Steam-Workshop-black?style=flat-square&logo=steam)](https://steamcommunity.com/sharedfiles/filedetails/?id=3282568819)
[![Linting](https://img.shields.io/github/actions/workflow/status/ACE-Project-Team/ArmoredCombatExtended/glualint.yml?branch=master&label=Linting&style=flat-square)](https://github.com/ACE-Project-Team/ArmoredCombatExtended/actions)
[![Commits](https://img.shields.io/github/commit-activity/m/ACE-Project-Team/ArmoredCombatExtended?label=Commits&style=flat-square)](https://github.com/ACE-Project-Team/ArmoredCombatExtended/graphs/commit-activity)

**ACE (Armored Combat Extended)** is a comprehensive engineering framework for Garry's Mod that replaces legacy building tools with realistic physics simulation and authentic components. From engines and drivetrains to advanced sensors and weaponry, ACE challenges you to solve real engineering problems. Whether you're new to advanced building or a veteran seeking depth, ACE rewards skill and creativity with systems that actually behave like their real-world counterparts. Actively developed since 2018, est. in 2015.

🌐 **[Visit acegmod.com](https://acegmod.com)** for documentation, tutorials, community content, and more.

---

## Why ACE?

ACE is a **direct successor to ACF-2** (the original Armored Combat Framework), continuing its legacy with modern features and active development. When ACF-2 development slowed, ACE was created to push the framework forward — adding new systems, fixing long-standing issues, and expanding what's possible in Garry's Mod engineering.

Decade later, ACE remains the most feature-complete combat and engineering addon available:

| Feature | Description |
|---------|-------------|
| **Realistic Ballistics** | Accurate projectile physics with penetration, ricochet, and spalling |
| **Advanced Mobility** | Realistic vehicle handling — no thrusters or hoverballs needed |
| **Comprehensive Arsenal** | Cannons, missiles, bombs, and 10+ ammunition types (AP, APHE, HEAT, APFSDS, etc.) |
| **Damage Modeling** | Component-based damage with armor penetration and internal spalling |
| **Sensor Systems** | Multiple radar types, each with unique capabilities |
| **Immersive Audio/Visual** | Dynamic sound (including speed of sound simulation) and stunning visual effects |
| **Wiremod Integration** | Full compatibility with Expression 2 and Wiremod systems |

---

## Quick Links

| Resource | Link |
|----------|------|
| 🌐 **Website** | [acegmod.com](https://acegmod.com) |
| 📖 **Documentation** | [acegmod.com/wiki](https://acegmod.com/wiki) |
| 📰 **Blog & Updates** | [acegmod.com/blog](https://acegmod.com/blog) |
| 💬 **Discord** | [discord.gg/Y8aEYU6](https://discord.gg/Y8aEYU6) |
| 🎬 **Videos** | [YouTube](https://www.youtube.com/@ArmoredCombatExtended) |
| 🎮 **Steam Workshop** | [Workshop Page](https://steamcommunity.com/sharedfiles/filedetails/?id=3282568819) |

---

## Installation

### Requirements

ACE requires the following addons:

| Addon | Required | Link |
|-------|----------|------|
| **Wiremod** | ✅ Yes | [Workshop](https://steamcommunity.com/workshop/filedetails/?id=160250458) |
| **Advanced Duplicator 2** | ✅ Yes | [Workshop](https://steamcommunity.com/sharedfiles/filedetails/?id=773402917) |
| **Contraption Framework** | ✅ Yes | [Workshop](https://steamcommunity.com/sharedfiles/filedetails/?id=3154971187) |

### Option 1: Steam Workshop (Recommended)

Subscribe to ACE on the Steam Workshop for automatic updates:

👉 **[Subscribe on Steam Workshop](https://steamcommunity.com/sharedfiles/filedetails/?id=3282568819)**

### Option 2: Manual / Git Installation

Clone this repository to your addons folder:

    git clone https://github.com/ACE-Project-Team/ArmoredCombatExtended.git

Or use [GitHub Desktop](https://desktop.github.com/), [GitKraken](https://www.gitkraken.com/), or download as ZIP.

---
## Features

### 🔫 Weapons & Ammunition

- Large arsenal of cannons, autocannons, mortars, howitzers and machine guns
- Missiles with 5+ guidance types and many accurate to real life models
- Bombs and rockets for aircraft
- Diverse ammo: AP, APHE, APFSDS, HEAT, HE, Smoke, and more
- SWEPs for infantry combat - rifles, javelin missile launcher, anti tank mines and more

### 🚗 Mobility & Vehicles

- Realistic drivetrain simulation (engines, transmissions, differentials). Forget thrusters.
- Fuel, heat system
- Pre-made vehicles / tools included (spawn with Advanced Duplicator 2)

### 🛡️ Armor & Damage

- Realistic armor penetration calculations and composite armor - DU, ceramic, rubber, RHA, textolite and so on.
- Component-based damage modeling, real tank modelling by using fuel, crew and more
- Internal spalling and module damage
- Balanced for competitive multiplayer
- Realistic crew members: stamina, different positions, gforce & more

### 📡 Sensors & Electronics

- Multiple radar types with distinct capabilities - IRST, RWR, ECM, Tracking / Search Radar
- Full Wiremod/E2 compatibility

### 🎨 Effects & Immersion

- Dynamic explosions with proper lighting
- Speed of sound simulation
- Tracer rounds, smoke, flares, chaff
- Immersive audio ambience

---

## Documentation

Full documentation is available at **[acegmod.com/wiki](https://acegmod.com/wiki)**

- Getting Started Guides
- Weapon & Ammo Reference
- Vehicle Building Tutorials
- E2/Wiremod Integration

---

## Contributing

We welcome contributions! Before submitting:

1. Read our [Contribution Guidelines](https://acegmod.com/wiki/contributing)
2. Use the [Dev Branch](https://github.com/ACE-Project-Team/ArmoredCombatExtended/tree/dev) for pull requests
3. Join our [Discord](https://discord.gg/Y8aEYU6) to discuss changes

Run the repository's pinned GLuaFixer locally before submitting:

    powershell -ExecutionPolicy Bypass -File tools/glualint.ps1

---

## Community

- 💬 **Discord**: [discord.gg/Y8aEYU6](https://discord.gg/Y8aEYU6)
- 🎮 **Steam Workshop**: [Subscribe](https://steamcommunity.com/sharedfiles/filedetails/?id=3282568819)
- 🐛 **Bug Reports**: [GitHub Issues](https://github.com/ACE-Project-Team/ArmoredCombatExtended/issues)
- 🎬 **Videos**: [YouTube](https://www.youtube.com/@ArmoredCombatExtended)

## License

ACE is open source under the [MIT license](LICENSE).

---

<p align="center">
  <a href="https://acegmod.com">
    <img src="ace_logo.png" alt="ACE Logo" width="128">
  </a>
  <br>
  <strong>ACE - Armored Combat Extended</strong>
  <br>
  The definitive engineering and combat framework for Garry's Mod.
  <br>
  <a href="https://acegmod.com">acegmod.com</a>
</p>
