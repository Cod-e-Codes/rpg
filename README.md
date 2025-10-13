# RPG

A top-down RPG game built with LÖVE (Love2D). Personal side project for learning game development.

## What it is

A simple action RPG with:
- Top-down movement and combat
- Spell system with progression
- Dark caves with lighting effects
- Save/load system
- Toon-shaded art style

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
- **ESC / P** - Pause
- **F3** - Debug info
- **F12** - Dev mode

## Dev Mode

Press F12 to toggle dev mode:
- Jump to any level
- Give yourself items/spells
- Speed multiplier
- View debug info

## Save Files

Save files are stored in your LOVE save directory:
- Windows: `%APPDATA%\LOVE\RPG\`
- Files: `save_slot_1.sav`, etc.

## Current Progress

- ✅ Overworld with village
- ✅ Basic combat with knockback
- ✅ Inventory system
- ✅ Quest progression
- ✅ Cave dungeon with lighting
- ✅ Spell system (Illumination spell)
- ✅ Save/load functionality
- 🚧 More spells coming
- 🚧 More levels/dungeons

## License

MIT License - see LICENSE file for details.

