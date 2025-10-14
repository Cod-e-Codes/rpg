# RPG

A top-down RPG game built with LÖVE (Love2D). Personal side project for learning game development.

![Gameplay Demo](assets/demo/rpg.gif)

## What it is

A simple action RPG with:
- Top-down movement and combat
- Spell system with progression
- Dark caves with lighting effects
- Save/load system
- Toon-shaded art style
- Ambient audio (footsteps, river, cave, overworld, interactions)

## Requirements

- [LÖVE 11.4+](https://love2d.org/)

## How to run

### Windows
```bash
.\run.bat
```

### PowerShell
```bash
.\run.ps1
```

### Manual
```bash
love .
```

## Controls

- **WASD / Arrow Keys** - Move
- **E** - Interact
- **1-5** - Cast spell (slot)
- **B** - Spellbook
- **I** - Inventory
- **6-0** - Use quick slot
- **P** - Player profile
- **ESC / P** - Pause
- **F3** - Debug info (includes audio status)
- **F12** - Dev mode

## Dev Mode

Press F12 to toggle dev mode:
- Jump to any level
- Give yourself items/spells
- Reset progress (chests/enemies)
- Speed multiplier
- View debug info

## Save Files

Save files are stored in your LOVE save directory:
- **Windows**: `%APPDATA%\LOVE\rpg-game\`
- **macOS**: `~/Library/Application Support/LOVE/rpg-game/`
- **Linux**: `~/.local/share/love/rpg-game/`

Save file: `savegame.sav`

## Current Progress

- [x] Overworld with village
- [x] Combat system with health/damage/projectiles
- [x] Class selection (Fire/Ice/Storm/Earth Mage)
- [x] Spell system with progression and attack spells
- [x] Inventory with quick slots, stacking, and usable items
- [x] Quest progression
- [x] Cave dungeon with dynamic lighting
- [x] Save/load with persistent world state
- [x] Portal animations with player effects
- [x] Start screen and player profile
- [x] Spellbook and UI improvements
- [x] Camera cutscenes and story progression
- [x] Multiple levels with puzzle areas
- [x] Defense trials with elemental hazards and resistance spells
- [x] Healing strategy selection (Tank/Lifesteal/Soul Reaper)
- [x] Skeleton spawn animations and combat arenas
- [x] Audio system (footsteps, river, cave, overworld ambience, chest/door sounds)
- [x] Visual effects for elemental hazards
- [ ] More content and puzzles
- [ ] Additional sound effects and music

## License

MIT License - see LICENSE file for details.

