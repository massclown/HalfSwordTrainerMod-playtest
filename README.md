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