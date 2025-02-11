# Trainer Mod for Half Sword Playtest
This is an experimental version of the trainer mod for Half Sword Playtest only.

For the Nov 2023 demo v0.3 use the [regular trainer mod](https://github.com/massclown/HalfSwordTrainerMod).

# How to install (easy)
The one-click installer supports Playtest and this mod.

It will automatically choose the correct versions of everything.

## Download the fresh installer here at https://github.com/massclown/HalfSwordModInstaller/releases/latest/download/HalfSwordModInstaller.exe

The documentation for the installer is here: https://github.com/massclown/HalfSwordModInstaller

# How to install (hard)
Follow the steps at https://github.com/massclown/HalfSwordTrainerMod?tab=readme-ov-file#installation-hard-mode, 
but make sure to do the following changes to that procedure:
1) find the game installation folder of the playtest version of the game, not the demo, obviously.

* The Half Sword Playtest is usually installed somewhere like: 
`C:\Program Files (x86)\Steam\steamapps\common\Half Sword Playtest\`, and if that is the case for you, then:
  * the UE4SS archive will need to be unzipped into:
`C:\Program Files (x86)\Steam\steamapps\common\Half Sword Playtest\VersionTest54\Binaries\Win64`
  * and the mod's release will need to be unzipped into: 
`C:\Program Files (x86)\Steam\steamapps\common\Half Sword Playtest\VersionTest54\Binaries\Win64\use4ss\Mods`

2) download the release of this mod from here:
https://github.com/massclown/HalfSwordTrainerMod-playtest/releases
or just download the bleeding edge version directly from the repository.

3) download **experimental** UE4SS from here:
https://github.com/UE4SS-RE/RE-UE4SS/releases/download/experimental/UE4SS_v3.0.1-234-g4fc8691.zip

4) No need to enable `BPModLoaderMod` as this version of the mod for the playtest does not use Blueprint UI.

5) follow the rest of the procedure with the above changes in mind.

# How does the mod look on screen

![Alt text](images/hud_playtest_v0.10_2K.jpg?raw=true "Screenshot of mod UI v0.10")

# Configuration of this mod

## Config file
The config file is located at: `ue4ss\Mods\HalfSwordTrainerMod\config.txt` in your game installation folder.

You can modify the following settings in the config file:

- `ui_visible_on_start`: Whether the HUD is visible when starting the game (default: true). Set to false to hide the mod UI on start
- `max_rsr`: Maximum Running Speed Rate stat value (default: 1000)
- `max_mp`: Maximum Muscle Power stat value (default: 200)
- `max_regen_rate`: Maximum regeneration rate (default: 10000)
- `slo_mo_game_speed`: Game speed when slow motion is enabled for the first time (default: 0.5)
- `spawn_offset_x_npc`: How far NPCs spawn from player in X direction (default: 800.0)
- `spawn_offset_x_object`: How far objects spawn from player in X direction (default: 300.0)
- `projectile_base_force_multiplier`: Base force multiplier for projectiles (default: 100)
- `jump_impulse`: Force applied when jumping normally (default: 25000)
- `jump_impulse_fallen`: Force applied when jumping while fallen (default: 1000)
- `dash_forward_impulse`: Force applied when dashing forward (default: 15000.0)
- `dash_back_impulse`: Force applied when dashing backward (default: 12000.0)
- `dash_left_impulse`: Force applied when dashing left (default: 40000.0)
- `dash_right_impulse`: Force applied when dashing right (default: 40000.0)

The config file uses a simple key = value format. Lines starting with # are comments and are ignored.
For example, to hide the mod UI on start:
```
ui_visible_on_start = false
```

If the config file doesn't exist, the mod will use the default values listed above. 

## Custom keybinds file
The keybinds file is located at: `ue4ss\Mods\HalfSwordTrainerMod\keybinds.txt` in your game installation folder.

You can customize the keyboard shortcuts by editing this file. 

Don't rebind the mod's functions on top of the game's own keybinds, things will break!

The file uses the following format:
```
action = key[,modifier1,modifier2,...]
```

Where:
- action: The name of the action to bind
- key: The key name (see https://docs.ue4ss.com/lua-api/table-definitions/key.html)
- modifiers: Optional comma-separated list of modifiers (CONTROL, SHIFT, ALT)

For example:
`toggle_invulnerability = F11`

If the keybinds file doesn't exist, the mod will use the default values listed in the keybinds table below. 

# Known issues and limitations and changes from trainer mod for Demo 
* Unfortunately **there is almost no user interface**, just use the [keybinds](https://github.com/massclown/HalfSwordTrainerMod?tab=readme-ov-file#keyboard-shortcuts-of-this-mod) and check the UE4SS logs (`Ctrl+O`) if something goes wrong. 
* Most of the functionality from the regular trainer mod may still work (or not)
* `F3` only spawns an unarmed NPC Willie. 
* `F4` spawns the only object present in the game files, the training dummy.
* Jump is now bound to `Numpad 5`, as `Space` is used by the game for kicking.
  * Jump also has been unlocked to allow infinite ragdolling.
* `Ctrl + L` saves the current loadout to the game's standard loadout slot (I believe you have to be in a class above unarmed for that to be loaded afterwards)
* Player team changes and NPC team changes are somewhat broken. 
  * You can get your NPC teammates to attack you by changing your team, but they will keep attacking you if you change it back, etc.

# License
Distributed under the MIT License. See LICENSE file for more information.