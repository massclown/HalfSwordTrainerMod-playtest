# Trainer Mod for Half Sword Playtest
This is an experimental version of the trainer mod for Half Sword Playtest only.

For the Nov 2023 demo v0.3 use the [regular trainer mod](https://github.com/massclown/HalfSwordTrainerMod).

# How to install
Right now, the only way to install is manually. The one-click installer will need quite some work to support two games.

Follow the steps at https://github.com/massclown/HalfSwordTrainerMod?tab=readme-ov-file#installation-hard-mode 
but download **experimental** UE4SS from here:
https://github.com/UE4SS-RE/RE-UE4SS/releases/download/experimental/UE4SS_v3.0.1-234-g4fc8691.zip
and now all the mod files go into a `ue4ss\Mods` subfolder inside the game's folder.

# Known issues and limitations
* Unfortunately **there is no user interface**, just use the [keybinds](https://github.com/massclown/HalfSwordTrainerMod?tab=readme-ov-file#keyboard-shortcuts-of-this-mod) and check the UE4SS logs (`Ctrl+O`). 
* Most of the functionality from the regular trainer mod may still work.
* Because there is no user interface, `F1` spawns random armor and `F2` spawns random weapons. 
  * Use the despawn keybind `F5` to despawn them if you don't like what you get.
* `F3` only spawns an unarmed NPC Willie. 
* `F4` spawns the only object present in the game files, the training dummy.
* Jump is now bound to `Numpad 5`, as `Space` is used by the game for kicking.
  * Jump also has been unlocked to allow infinite ragdolling.
* Player team changes and NPC team changes are broken. 
  * You can get your NPC teammates to attack you by changing your team, but they will keep attacking you if you change it back, etc.