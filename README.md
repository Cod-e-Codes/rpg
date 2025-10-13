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
- **I** - Quick slots
- **I+I** (double tap) - Full inventory
- **6-0** - Use quick slot
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
- **Windows**: `%APPDATA%\LOVE\rpg-game\`
- **macOS**: `~/Library/Application Support/LOVE/rpg-game/`
- **Linux**: `~/.local/share/love/rpg-game/`

Save file: `savegame.sav`

## Current Progress

- [x] Overworld with village
- [x] Basic combat with knockback
- [x] Inventory system with quick slots and stacking
- [x] Quest progression
- [x] Cave dungeon with dynamic lighting
- [x] Spell system (Illumination spell)
- [x] Save/load with position preservation
- [x] Portal system with animations
- [x] Directional signage
- [ ] More spells
- [ ] More levels
- [ ] Sound effects and music

## License

MIT License - see LICENSE file for details.

