-- Half Sword Trainer Mod v0.14 by massclown for Half Sword Playtest only
-- https://github.com/massclown/HalfSwordTrainerMod-playtest
-- Requirements: LATEST EXPERIMENTAL UE4SS build from github after November 2024, e.g.
-- https://github.com/UE4SS-RE/RE-UE4SS/releases/download/experimental/UE4SS_v3.0.1-234-g4fc8691.zip
------------------------------------------------------------------------------
local mod_version = "0.14"
------------------------------------------------------------------------------
local maf = require 'maf'
local UEHelpers = require("UEHelpers")
local GetGameplayStatics = UEHelpers.GetGameplayStatics
local GetWorldContextObject = UEHelpers.GetWorldContextObject
local GetKismetSystemLibrary = UEHelpers.GetKismetSystemLibrary
local GetKismetMathLibrary = UEHelpers.GetKismetMathLibrary
local GetGameInstance = UEHelpers.GetGameInstance
------------------------------------------------------------------------------
local config = {}
local default_config = {
    -- !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
    -- !! No need to modify this table, just change the values in config.txt!
    -- !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
    ui_visible_on_start = true,
    max_rsr = 1000,
    max_mp = 200,
    max_regen_rate = 10000,
    slo_mo_game_speed = 0.5,
    spawn_offset_x_npc = 800.0,
    spawn_offset_x_object = 300.0,
    projectile_base_force_multiplier = 100,
    jump_impulse = 25000,
    jump_impulse_fallen = 1000,
    dash_forward_impulse = 15000.0,
    dash_back_impulse = 12000.0,
    dash_left_impulse = 40000.0,
    dash_right_impulse = 40000.0,
}
------------------------------------------------------------------------------
-- Load config from config.txt file
local function LoadConfig()
    -- Start with default config values
    config = {}
    -- Try to open config file
    local file = io.open("ue4ss\\Mods\\HalfSwordTrainerMod\\config.txt", "r")
    if not file then
        config = table.shallow_copy(default_config)
        return
    end

    -- Read and evaluate each line
    for line in file:lines() do
        -- Skip empty lines and full comment lines
        if not line:match("^%s*#") and not line:match("^%s*$") then
            -- Remove any trailing comments
            line = line:gsub("%s*#.*$", "")
            -- Extract key and value
            local key, value = line:match("([%w_]+)%s*=%s*(.+)")
            if key and value then
                if default_config[key] ~= nil then
                    -- Yes, this is bad but short and works fine
                    local fn, err = load("return " .. value)
                    if fn then
                        config[key] = fn()
                    end
                end
            end
        end
    end

    file:close()
end
------------------------------------------------------------------------------
local keybinds = {}
local default_keybinds = {
    -- !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
    -- !! No need to modify this table, just change the values in keybinds.txt!
    -- !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
    -- Format: action = {key, {modifiers}}
    -- key names: https://docs.ue4ss.com/lua-api/table-definitions/key.html
    -- modifiers: "CONTROL", "SHIFT", "ALT"
    -- for multiple modifiers, use array, e.g. {"CONTROL", "SHIFT"}
    -- for no modifiers, use empty array, e.g. {}
    --
    toggle_invulnerability = { "I", {} },
    toggle_superstrength = { "T", {} },
    save_loadout = { "L", { "CONTROL" } },
    spawn_loadout = { "L", {} },
    decrease_level = { "OEM_MINUS", {} },
    increase_level = { "OEM_PLUS", {} },
    toggle_ui = { "U", {} },
    spawn_armor = { "F1", {} },
    spawn_weapon = { "F2", {} },
    spawn_npc = { "F3", {} },
    spawn_object = { "F4", {} },
    undo_spawn = { "F5", {} },
    despawn_npcs = { "F6", {} },
    kill_npcs = { "K", {} },
    toggle_freeze = { "Z", {} },
    spawn_arena = { "B", {} },
    toggle_slowmo = { "M", {} },
    toggle_slowmo_sprint = { "M", { "SHIFT" } },
    decrease_speed = { "OEM_FOUR", {} },
    increase_speed = { "OEM_SIX", {} },
    decrease_speed_sprint = { "OEM_FOUR", { "SHIFT" } },
    increase_speed_sprint = { "OEM_SIX", { "SHIFT" } },
    toggle_crosshair = { "OEM_PERIOD", {} },
    jump = { "NUM_FIVE", {} },
    jump_sprint = { "NUM_FIVE", { "SHIFT" } },
    jump_crouch = { "NUM_FIVE", { "CONTROL" } },
    shoot = { "MIDDLE_MOUSE_BUTTON", {} },
    shoot_crouch = { "MIDDLE_MOUSE_BUTTON", { "CONTROL" } },
    shoot_sprint = { "MIDDLE_MOUSE_BUTTON", { "SHIFT" } },
    remove_armor = { "J", {} },
    next_projectile = { "TAB", {} },
    prev_projectile = { "TAB", { "SHIFT" } },
    remove_death_screen = { "U", { "ALT" } },
    resurrect = { "J", { "CONTROL" } },
    possess_npc = { "END", { "CONTROL" } },
    repossess_player = { "HOME", { "CONTROL" } },
    dash_forward = { "NUM_EIGHT", {} },
    dash_back = { "NUM_TWO", {} },
    dash_left = { "NUM_FOUR", {} },
    dash_right = { "NUM_SIX", {} },
    toggle_pause = { "MULTIPLY", {} },
    team_up = { "ADD", {} },
    team_down = { "SUBTRACT", {} },
    goto_me = { "F", { "CONTROL" } },
    despawn_target = { "DEL", {} },
    scale_target = { "DECIMAL", {} }
}
------------------------------------------------------------------------------
function LoadKeybinds()
    local file = io.open("ue4ss\\Mods\\HalfSwordTrainerMod\\keybinds.txt", "r")
    if not file then
        -- If config doesn't exist, use defaults
        keybinds = table.shallow_copy(default_keybinds)
        return
    end

    keybinds = {}
    for line in file:lines() do
        -- Skip comments and empty lines
        if not line:match("^%s*#") and not line:match("^%s*$") then
            -- Remove any trailing comments
            line = line:gsub("%s*#.*$", "")
            -- Parse line format: action = key [,modifier1,modifier2,...]
            local action, binding = line:match("([%w_]+)%s*=%s*([%w_,]+)")
            if action and binding then
                local parts = {}
                for part in binding:gmatch("[^,]+") do
                    parts[#parts + 1] = part:match("^%s*(.-)%s*$") -- Trim whitespace
                end

                if #parts > 0 then
                    local key = parts[1]
                    local modifiers = {}
                    for i = 2, #parts do
                        modifiers[#modifiers + 1] = parts[i]
                    end
                    keybinds[action] = { key, modifiers }
                end
            end
        end
    end

    file:close()

    -- Fill in any missing bindings with defaults
    for action, binding in pairs(default_keybinds) do
        if not keybinds[action] then
            keybinds[action] = binding
        end
    end
end

-- Handle for the temporary HUD implementation in TempSetupCustomHUD
local HSTM_UI_ALT_HUD = nil
local HSTM_UI_ALT_HUD_TextBox_Names = {
    ["TextBox_Logo"] = { 0, "Half Sword Trainer Mod v%s" },
    -- ["TextBox_Score"] = { 1, "Score : %d" },
    -- ["TextBox_Level"] = { 2, "Level : %d" },
    ["TextBox_HP"] = { 3, "HP : %.2f" },
    ["TextBox_Cons"] = { 4, "Conscious : %.2f" },
    ["TextBox_Tonus"] = { 5, "Tonus : %.2f" },
    ["TextBox_Stamina"] = { 6, "Stamina : %.2f" },
    ["TextBox_SuperStrength"] = { 7, "SuperStrength : %s" },
    ["TextBox_Invulnerability"] = { 8, "Invulnerability : %s" },
    ["TextBox_GameSpeed"] = { 9, "Game Speed : %.2f (%s)" },
    ["TextBox_NPCsFrozen"] = { 10, "NPCs Frozen : %s" },
    ["TextBox_Projectile"] = { 11, "Projectile : %s" },
    ["TextBox_Player_Team"] = { 12, "Team : %d" }
}

local function GetSortedHUDTextBoxNames()
    local sortedNames = {}
    for k, v in pairs(HSTM_UI_ALT_HUD_TextBox_Names) do
        table.insert(sortedNames, { k, v[1], v[2] })
    end
    table.sort(sortedNames, function(a, b) return a[2] < b[2] end)
    return sortedNames
end

local HSTM_UI_ALT_HUD_Objects = {}

local HSTM_UI_ALT_HUD_Spawn = nil

local InitGameStateHookCount = 0
local ClientRestartHookCount = 0
------------------------------------------------------------------------------
-- Saved copies of player stats before buffs
local savedRSR = 0
local savedMP = 0
local savedRegenRate = 0
-- Our buffed stats that we set
------------------------------------------------------------------------------
local GameSpeedDelta = 0.1
local DefaultGameSpeed = 1.0
local SloMoGameSpeed = default_config.slo_mo_game_speed
------------------------------------------------------------------------------
-- Variables tracking things we change or want to observe and display in HUD
local AutoSpawnEnabled = true          -- this is the default, UI is 'HSTM_Flag_AutospawnNPCs'
local AutoSpawnChangeRequested = false -- this handles the restoring of scores and levels when resuming NPC autospawn and level progression
local SpawnFrozenNPCs = false          -- we can change it, UI flag is 'HSTM_Flag_SpawnFrozenNPCs'

local SlowMotionEnabled = false
local Frozen = false
local SuperStrength = false
local SuperStamina = false

-- Those are copies of player's (or level's) object properties
local OGWillie = nil
local OGlevel = 0
local OGscore = 0
local GameSpeed = 1.0
local Invulnerable = false
local level = 0
local PlayerScore = 0
local PlayerTeam = 0
local maxPlayerTeam = 9
local PlayerHealth = 0
local PlayerConsciousness = 0
local PlayerTonus = 0
local PlayerStamina = 0

-- Cached from the spawn UI (HSTM_Slider_WeaponSize)
local WeaponScaleMultiplier = 1.0
local WeaponScaleX = true
local WeaponScaleY = true
local WeaponScaleZ = true
local WeaponScaleBladeOnly = false
local ScaleObjects = false

-- Player body detailed health data
local HH = 0  -- 'Head Health'
local NH = 0  -- 'Neck Health'
local BH = 0  -- 'Body Health'
local ARH = 0 -- 'Arm_R Health'
local ALH = 0 -- 'Arm_L Health'
local LRH = 0 -- 'Leg_R Health'
local LLH = 0 -- 'Leg_L Health'

-- Player joint detailed health data
local HJH = 0  -- "Head Joint Health"
local TJH = 0  -- "Torso Joint Health"
local HRJH = 0 -- "Hand R Joint Health"
local ARJH = 0 -- "Arm R Joint Health"
local SRJH = 0 -- "Shoulder R Joint Health"
local HLJH = 0 -- "Hand L Joint Health"
local ALJH = 0 -- "Arm L Joint Health"
local SLJH = 0 -- "Shoulder L Joint Health"
local TRJH = 0 -- "Thigh R Joint Health"
local LRJH = 0 -- "Leg R Joint Health"
local FRJH = 0 -- "Foot R Joint Health"
local TLJH = 0 -- "Thigh L Joint Health"
local LLJH = 0 -- "Leg L Joint Health"
local FLJH = 0 -- "Foot L Joint Health"

-- Chosen NPC team from the UI dropdown
local NPCTeam = 0

-- Various UI-related stuff
local ModUIHUDVisible = true
local ModUISpawnVisible = false
local CrosshairVisible = true
-- using alternative implementation for playtest
local ModUIHUDUpdateLoopEnabled = true
-- everything that we spawned
local spawned_things = {}

-- The actors from the hook
--local intercepted_actors = {}

-- Flag to distinguish between normal client restarts and resurrection
local ResurrectionWasRequested = false

-- Item/NPC tables for the spawn menus in the UI
local all_armor = {}
local all_weapons = {}
local all_characters = {}
local all_objects = {}

local custom_loadout = {}

local NullRotation = { Pitch = 0.0, Yaw = 0.0, Roll = 0.0 }
local NullLocation = { X = 0.0, Y = 0.0, Z = 0.0 }
local DefaultScale1x = { X = 1.0, Y = 1.0, Z = 1.0 }
------------------------------------------------------------------------------
-- These are UE enum constants
local Visibility_VISIBLE = 0
local Visibility_COLLAPSED = 1
local Visibility_HIDDEN = 2
local Visibility_HITTESTINVISIBLE = 3
local Visibility_SELFHITTESTINVISIBLE = 4
local Visibility_ALL = 5
------------------------------------------------------------------------------
function Log(Message)
    print("[HalfSwordTrainerMod] " .. Message)
end

function Logf(...)
    print("[HalfSwordTrainerMod] " .. string.format(...))
end

function ErrLog(Message)
    print("[HalfSwordTrainerMod] [ERROR] " .. Message)
    print(debug.traceback() .. "\n")
end

function ErrLogf(...)
    print("[HalfSwordTrainerMod] [ERROR] " .. string.format(...))
    print(debug.traceback() .. "\n")
end

function string:contains(sub)
    return self:find(sub, 1, true) ~= nil
end

function string:starts_with(start)
    return self:sub(1, #start) == start
end

function string:ends_with(ending)
    return ending == "" or self:sub(- #ending) == ending
end

------------------------------------------------------------------------------
function table.shallow_copy(t)
    local t2 = {}
    for k, v in pairs(t) do
        t2[k] = v
    end
    return t2
end

function table.random_key_value(t)
    local keys = {}
    for k in pairs(t) do
        table.insert(keys, k)
    end
    local randomKey = keys[math.random(#keys)]
    return randomKey, t[randomKey]
end

------------------------------------------------------------------------------
-- Conversion between UE4SS representation of UE structures and maf
------------------------------------------------------------------------------
-- TODO maybe replace maf with KismetMath one day ???

function vec2maf(vector)
    return maf.vec3(vector.X, vector.Y, vector.Z)
end

function maf2vec(vector)
    return { X = vector.x, Y = vector.y, Z = vector.z }
end

function maf2rot(vector)
    return { Pitch = vector.x, Yaw = vector.y, Roll = vector.z }
end

-- quaternion to pitch+yaw+roll (yaw-pitch-roll order, ZYX, yaw inverted)
function mafrotator2rot(quat)
    local x, y, z, w = quat:unpack()
    local threshold = 0.499999
    local test = x * z - w * y
    local yaw, pitch, roll

    yaw = math.deg(math.atan(2.0 * (w * z + x * y), 1.0 - 2.0 * (y * y + z * z)))

    if math.abs(test) > threshold then
        local sign = test > 0 and 1 or -1
        pitch = sign * 90.0
        roll = sign * yaw - math.deg(2.0 * math.atan(x, w))
        return { Pitch = pitch, Yaw = yaw, Roll = roll }
    else
        pitch = math.asin(2.0 * (test))
        roll = math.atan(-2.0 * (w * x + y * z), 1.0 - 2.0 * (x * x + y * y))
        return { Pitch = math.deg(pitch), Yaw = yaw, Roll = math.deg(roll) }
    end
end

-- UE pitch+yaw+roll to quaternion (yaw-pitch-roll order, ZYX, yaw inverted)
function rot2mafrotator(vector)
    local p = math.rad(vector.Pitch)
    local y = math.rad(vector.Yaw)
    local r = math.rad(vector.Roll)

    local SP, SY, SR;
    local CP, CY, CR;

    SP = math.sin(p / 2)
    SY = math.sin(y / 2)
    SR = math.sin(r / 2)

    CP = math.cos(p / 2)
    CY = math.cos(y / 2)
    CR = math.cos(r / 2)

    local X = CR * SP * SY - SR * CP * CY
    local Y = -CR * SP * CY - SR * CP * SY
    local Z = CR * CP * SY - SR * SP * CY
    local W = CR * CP * CY + SR * SP * SY
    return maf.quat(X, Y, Z, W)
end

function LogQuat(quat)
    Logf("{X=%f, Y=%f, Z=%f, W=%f}\n", quat.x, quat.y, quat.z, quat.w)
end

function LogMafVec(mafVector)
    Logf("{X=%f, Y=%f, Z=%f}\n", mafVector.x, mafVector.y, mafVector.z)
end

function LogUEVec(UEVec)
    Logf("{X=%f, Y=%f, Z=%f}\n", UEVec.X, UEVec.Y, UEVec.Z)
end

function LogUERot(UERot)
    Logf("{Pitch=%f, Yaw=%f, Roll=%f}\n", UERot.Pitch, UERot.Yaw, UERot.Roll)
end

function UEVecToStr(UEVec)
    return string.format("{X=%f, Y=%f, Z=%f}", UEVec.X, UEVec.Y, UEVec.Z)
end

function MafVecToStr(mafVector)
    return string.format("{X=%f, Y=%f, Z=%f}", mafVector.x, mafVector.y, mafVector.z)
end

------------------------------------------------------------------------------
local mapNameGauntlet = "Arena_Cutting_Map_C"
local mapNameAbyss = "Abyss_Map_Open_Intermediate_C"
local mapPlayerNameGauntlet = "Player (Temp)"
local mapPlayerNameAbyss = "Player Willie"
------------------------------------------------------------------------------
-- The caching code logic is taken from TheLich at nexusmods (Grounded QoL mod)
local cache = {}
cache.map_name = mapNameGauntlet
cache.map_player_name = mapPlayerNameGauntlet
-- Abyss version of Demo v0.5 and newer has some logic to detect the current game mode
cache.getCurrentMap = function()
    local map_playtest = FindFirstOf(mapNameGauntlet)
    local map_abyss = FindFirstOf(mapNameAbyss)
    -- TODO detect the menu and bail out
    if map_playtest and map_playtest:IsValid() then
        Log("cache.getCurrentMap() found playtest map\n")
        cache.map_name = mapNameGauntlet
        cache.map_player_name = mapPlayerNameGauntlet
        return map_playtest
    end
    if map_abyss and map_abyss:IsValid() then
        Log("cache.getCurrentMap() found abyss map\n")
        cache.map_name = mapNameAbyss
        cache.map_player_name = mapPlayerNameAbyss
        return map_abyss
    end
    Logf("cache.getCurrentMap() failed to find map object\n")
    return nil
end
cache.getMapName = function()
    return cache.map_name
end
cache.objects = {}
cache.names = {
    --    ["engine"] = { "Engine", false },
    --    ["kismet"] = { "/Script/Engine.Default__KismetSystemLibrary", true },
    --
    ["map"] = { cache.getMapName, false },
    ["worldsettings"] = { "WorldSettings", false },
    --    ["ui_hud"] = { "HSTM_UI_HUD_Widget_C", false },
    --    ["ui_spawn"] = { "HSTM_UI_Spawn_Widget_C", false },
    ["ui_game_hud"] = { "UI_HUD_C", false }
}

cache.mt = {}
cache.mt.__index = function(obj, key)
    local newObj = obj.objects[key]
    if newObj == nil or not newObj:IsValid() then
        local classNameHandle, isStatic = table.unpack(obj.names[key])
        local className
        if type(classNameHandle) == "function" then
            className = classNameHandle()
        else
            className = classNameHandle
        end
        if isStatic then
            newObj = StaticFindObject(className)
        else
            newObj = FindFirstOf(className)
        end
        if newObj == nil or not newObj:IsValid() then
            ErrLogf("Failed to find and cache object [%s][%s][%s]\n", key, className, not newObj and "nil" or "invalid")
            newObj = nil
        end
        obj.objects[key] = newObj
    end
    return newObj
end
setmetatable(cache, cache.mt)
------------------------------------------------------------------------------
function ClearCachedObjects()
    -- TODO
    cache.objects = {}
end

------------------------------------------------------------------------------
-- The function attempts to access all cached objects and call their IsValid() method
function ValidateCachedObjects()
    -- This has a side effect of detecting current game mode and pointing the cache to the map
    local map = cache.getCurrentMap()
    -- disabled for playtest
    -- local ui_hud = cache.ui_hud
    -- local ui_spawn = cache.ui_spawn

    -- The HUD is not loaded at the time of first check, so skipping
    -- local ui_game_hud = cache.ui_game_hud
    local worldsettings = cache.worldsettings

    if not map or not map:IsValid() then
        ErrLogf("Map not found! (%s)\n", not map and "nil" or "invalid")
        return false
    end

    local player = cache.map[cache.map_player_name]

    if not player or not player:IsValid() then
        ErrLogf("Player not found! (%s)\n", not player and "nil" or "invalid")
        return false
    end

    -- Logf("Map [%s] found, player [%s]\n", map:GetFullName(), player:GetFullName())

    -- if not ui_hud or not ui_hud:IsValid() then
    --     ErrLogf("UI HUD Widget not found! (%s)\n", not map and "nil" or "invalid")
    --     return false
    -- end
    -- if not ui_spawn or not ui_spawn:IsValid() then
    --     ErrLogf("UI Spawn Widget not found! (%s)\n", not map and "nil" or "invalid")
    --     return false
    -- end
    -- The HUD is not loaded at the time of first check, so skipping
    -- if not ui_game_hud or not ui_game_hud:IsValid() then
    --     ErrLogf("Game UI Widget not found! (%s)\n", not map and "nil" or "invalid")
    --     return false
    -- end
    if not worldsettings or not worldsettings:IsValid() then
        ErrLogf("UE WorldSettings not found! (%s)\n", not worldsettings and "nil" or "invalid")
        return false
    end
    return true
end

------------------------------------------------------------------------------
-- This is copied from UEHelpers but filtering better, for PlayerController
--- Returns the first valid PlayerController that is currently controlled by a player.
---@return APlayerController
function myGetPlayerController()
    local PlayerControllers = FindAllOf("PlayerController")
    if not PlayerControllers then
        ErrLog("No PlayerControllers exist\n")
        return nil
        --error("No PlayerController found\n")
    end
    local PlayerController = nil
    for Index, Controller in pairs(PlayerControllers) do
        if Controller.Pawn:IsValid() and Controller.Pawn:IsPlayerControlled() then
            PlayerController = Controller
            break
        else
            Log("[WARNING] Not valid or not player controlled\n")
        end
    end
    if PlayerController and PlayerController:IsValid() then
        return PlayerController
    else
        -- TODO: not sure if this is fatal or not at the moment. Error handling needs improvement
        -- error("No PlayerController found\n")
        Log("[WARNING] Returning default PlayerController from the map\n")
        local player = cache.map[cache.map_player_name]
        if player and player:IsValid() then
            return player['Controller']
        else
            return nil
        end
    end
end

------------------------------------------------------------------------------
function IsMainMenuOnScreen()
    -- WidgetBlueprintGeneratedClass /Game/UI/UI_MainMenuSNF.UI_MainMenuSNF_C
    local menus = FindAllOf("UI_MainMenuSNF_C")
    if menus and #menus > 0 then
--        Logf("Main menu found [%d]\n", #menus)
        for i = 1, #menus do
            local menu = menus[i]
            if menu and menu:IsValid() then
--                Logf("Main menu found [%s]\n", menu:GetFullName())
                local isMenuInViewport = menu:IsInViewport()
                if isMenuInViewport then
                    Log("Main menu is in viewport\n")
                    return true
                else
                end
            end
        end
        Log("Main menu is not in viewport\n")
        return false
    end
    Log("Main menu not found\n")
    return false
end

------------------------------------------------------------------------------
local delayInProgress = false
-- This function gets added to the game restart hook below.
-- Somehow the hook gets triggered multiple times, two or three times per restart (different in Abyss and Gauntlet modes)
-- As these 2 or 3 calls happen in a few milliseconds, we just delay the initialization of the mod by 1 second and ignore repeated calls
function DelayInitMod()
    if InitGameStateHookCount > 1 then
        if delayInProgress then
            return
        end
        delayInProgress = true
        ExecuteWithDelay(1000, function()
            Log("DelayInitMod() async delay complete, initializing the mod\n")
            InitMyMod()
            delayInProgress = false
        end)
    end
end

------------------------------------------------------------------------------
-- Timestamp of last invocation of InitMyMod()
local lastInitTimestamp = -1
local globalRestartCount = 0
function InitMyMod()
    -- If the restart is triggered by a resurrection, exit
    -- TODO check this for playtest/demo v0.5
    if ResurrectionWasRequested then
        ResurrectionWasRequested = false
        return
    end
    -- Otherwise, continue with the normal restart
    local curInitTimestamp = os.clock()
    local delta = curInitTimestamp - lastInitTimestamp
    if lastInitTimestamp == -1 or (delta > 1) then
        globalRestartCount = globalRestartCount + 1
        Log("Client Restart hook triggered\n")

        if InitGameStateHookCount > 1 then
            ClearCachedObjects()
            if IsMainMenuOnScreen() then
                Log("InitMyMod() skipped, main menu is on screen\n")
                return
            end

            if not ValidateCachedObjects() then
                ErrLog("Objects not found, exiting\n")
                return
            end

            -- Looks like a real game start attempt!
            HSTM_UI_ALT_HUD = nil
            TempSetupCustomHUD()

            -- -- We retrieve the version variable from the Blueprint just to confirm that we are on the same version
            -- if cache.ui_hud['UI_Version'] then
            --     local hud_ui_version = cache.ui_hud['UI_Version']:ToString()
            --     if mod_version ~= hud_ui_version then
            --         ErrLogf("HSTM UI version mismatch: mod version [%s], HUD version [%s]\n", mod_version, hud_ui_version)
            --         return
            --     end
            -- end

            -- if cache.ui_spawn['UI_Version'] then
            --     local spawn_ui_version = cache.ui_spawn['UI_Version']:ToString()
            --     if mod_version ~= spawn_ui_version then
            --         ErrLogf("HSTM UI version mismatch: mod version [%s], HUD version [%s]\n", mod_version, spawn_ui_version)
            --         return
            --     end
            -- end

            LoadCustomLoadout()

            PopulateArmorComboBox()
            PopulateWeaponComboBox()
            PopulateNPCComboBox()
            PopulateNPCTeamComboBox()
            PopulateObjectComboBox()

            -- if intercepted_actors then
            --     intercepted_actors = {}
            -- end

            if spawned_things then
                spawned_things = {}
            end

            Frozen = false
            SlowMotionEnabled = false
            SuperStrength = false

            -- Attempt to intercept auto-spawned enemies and do something about that
            -- Don't use that, the below method works OK
            -- Somehow if we hook this, it makes the game spawn MORE enemies (faster)
            -- Needs further investigation
            --
            -- RegisterHook("/Game/Maps/Abyss_Map_Open.Abyss_Map_Open_C:Spawn NPC", function(self, SpawnTransform, WeaponLoadout, ReturnValue)
            --     local class = self:get():GetFullName()
            --     local transform = SpawnTransform:get():GetFullName()
            --     local loadout = WeaponLoadout:get()
            --     local retval = ReturnValue
            --     Logf("Spawn NPC hooked: self [%s], SpawnTransform [%s], WeaponLoadout [%s], ReturnValue [%s],\n", class, transform, loadout, retval)
            -- end)
            --

            -- This starts a thread that updates the HUD in background.
            -- It only exits if we retrn true from the lambda, which we don't
            --
            -- TODO: handle resurrection after NPC possession: the loop must still reflect the current player!
            -- TODO: we should probably cache the PlayerController at time of loop creation to detect and restart stale loops?
            --
            local myRestartCounter = globalRestartCount

            -- This loop attempts to take care of NPC autospawn in a "better" way
            -- This is still horrible but appears to work and prevent boss fights from spawning
            -- BUG when you turn autospawn back on after disabling it, a boss fight will spawn for some reason
            -- LoopAsync(1000, function()
            --     if myRestartCounter ~= globalRestartCount then
            --         -- This is a loop initiated from a past restart hook, exit it
            --         Logf("Exiting NPC Autospawn prevention update loop leftover from restart #%d\n", myRestartCounter)
            --         return true
            --     end
            --     if AutoSpawnEnabled ~= cache.ui_spawn['HSTM_Flag_AutospawnNPCs'] then
            --         AutoSpawnChangeRequested = true
            --     end
            --     AutoSpawnEnabled = cache.ui_spawn['HSTM_Flag_AutospawnNPCs']
            --     if AutoSpawnEnabled == true then
            --         if AutoSpawnChangeRequested then
            --             ExecuteInGameThread(function()
            --                 cache.map['Score'] = OGscore
            --                 cache.map['Level'] = OGlevel
            --                 cache.map['Easy Spawn'] = true
            --             end)
            --             AutoSpawnChangeRequested = false
            --         else
            --             OGlevel = cache.map['Level']
            --             OGscore = cache.map['Score']
            --         end
            --     else
            --         cache.map['Level'] = -1
            --         cache.map['Score'] = 9999
            --         level = -1
            --         cache.map['Easy Spawn'] = false
            --         AutoSpawnChangeRequested = false
            --     end
            --     return false
            -- end)

            if ModUIHUDUpdateLoopEnabled then
                LoopAsync(250, function()
                    if myRestartCounter ~= globalRestartCount then
                        -- This is a loop initiated from a past restart hook, exit it
                        Logf("Exiting HUD update loop leftover from restart #%d, we are in restart #%d now\n",
                            myRestartCounter, globalRestartCount)
                        return true
                    end
                    -- if not ValidateCachedObjects() then
                    --     ErrLog("Objects not found, skipping loop\n")
                    --     return false
                    -- end

                    if ModUIHUDVisible then
                        HUD_UpdatePlayerStats_Playtest()
                    end
                    return false
                end)
                Log("HUD update loop started\n")
            else
                Log("HUD update loop disabled\n")
            end
        end
    else
        Logf("Client Restart hook skipped, too early %.3f seconds passed\n", delta)
    end
    lastInitTimestamp = curInitTimestamp
end

function SetSmallerFont(TextBlockHandle)
    -- TODO not working yet due to missing StructData support in UE4SS
    -- local oldFont = TextBlockHandle["Font"]
    -- local luaFont = {
    --     FontObject = oldFont.FontObject,
    --     FontMaterial = nil,
    --     OutlineSettings = oldFont.OutlineSettings,
    --     TypefaceFontName = "Bold",
    --     Size = 18.000000,
    --     LetterSpacing = 0,
    --     SkewAmount = 0.000000,
    --     bForceMonospaced = false,
    --     MonospacedWidth = 1.000000
    -- }
    -- TextBlockHandle:SetFont(luaFont)
end

-- This is a hopefully temporary workaround for Blueprint mod loading issues in UE 5.4.4
-- https://github.com/UE4SS-RE/RE-UE4SS/issues/690
-- We will have to set up UE widget classes ourselves :(
-- Note that various sizes/styles/appearances currently cannot be set dynamically
function TempSetupCustomHUD()
    local myInitGameStateHookCount = InitGameStateHookCount
    if not HSTM_UI_ALT_HUD then
        HSTM_UI_ALT_HUD_Objects = {}
        Logf("Setting up alternative HUD implementation...\n")
        local GameInstance = GetGameInstance()
        HSTM_UI_ALT_HUD = StaticConstructObject(StaticFindObject("/Script/UMG.UserWidget"), GameInstance,
            FName("HSTM_UI_HUD_Widget"))
        HSTM_UI_ALT_HUD.WidgetTree = StaticConstructObject(StaticFindObject("/Script/UMG.WidgetTree"), HSTM_UI_ALT_HUD,
            FName("HSTM_UI_HUD_Widget_Tree"))
        HSTM_UI_ALT_HUD.WidgetTree.RootWidget = StaticConstructObject(StaticFindObject("/Script/UMG.CanvasPanel"),
            HSTM_UI_ALT_HUD.WidgetTree, FName("HSTM_UI_HUD_Widget_Tree_Canvas"))
        local verticalBox = StaticConstructObject(StaticFindObject("/Script/UMG.VerticalBox"),
            HSTM_UI_ALT_HUD.WidgetTree.RootWidget, FName("HSTM_UI_HUD_Widget_Tree_Canvas_VerticalBox1"))
        for _, value in pairs(GetSortedHUDTextBoxNames()) do
            local boxName = value[1]
            local formats = value[3]
            Logf("Creating TextBox [%s] with format [%s]\n", boxName, formats)
            HSTM_UI_ALT_HUD_Objects[boxName] = StaticConstructObject(StaticFindObject("/Script/UMG.TextBlock"),
                verticalBox, FName(boxName))
            HSTM_UI_ALT_HUD_Objects[boxName]:SetText(FText(formats))
            SetSmallerFont(HSTM_UI_ALT_HUD_Objects[boxName])
            verticalBox:AddChildToVerticalBox(HSTM_UI_ALT_HUD_Objects[boxName])
        end

        HSTM_UI_ALT_HUD_Objects["TextBox_Logo"]:SetText(FText(HSTM_UI_ALT_HUD_TextBox_Names["TextBox_Logo"][2]
            :format(
                mod_version)))

        local comboBoxArmor = StaticConstructObject(StaticFindObject("/Script/UMG.ComboBoxString"), verticalBox,
            FName("ComboBoxArmor"))

        -- comboBoxArmor["ItemStyle"]["TextColor"] = { R = 1.0, G = 1.0, B = 1.0, A = 1.0 }
        -- comboBoxArmor["ItemStyle"]["SelectedTextColor"] = { R = 1.0, G = 0.0, B = 0.0, A = 1.0 }

        local comboBoxWeapons = StaticConstructObject(StaticFindObject("/Script/UMG.ComboBoxString"), verticalBox,
            FName("ComboBoxWeapons"))

        -- comboBoxWeapons["ItemStyle"]["TextColor"] = { R = 1.0, G = 1.0, B = 1.0, A = 1.0 }
        -- comboBoxWeapons["ItemStyle"]["SelectedTextColor"] = { R = 1.0, G = 0.0, B = 0.0, A = 1.0 }

        local comboBoxNPCTeam = StaticConstructObject(StaticFindObject("/Script/UMG.ComboBoxString"), verticalBox,
            FName("ComboBoxNPCTeam"))

        local comboBoxNPCClass = StaticConstructObject(StaticFindObject("/Script/UMG.ComboBoxString"), verticalBox,
            FName("ComboBoxNPClass"))

        local ArmorLabel = StaticConstructObject(StaticFindObject("/Script/UMG.TextBlock"),
            verticalBox, FName("Spawn_Armor_Label"))
        ArmorLabel:SetText(FText("Spawn Armor:"))
        SetSmallerFont(ArmorLabel)
        verticalBox:AddChildToVerticalBox(ArmorLabel)

        HSTM_UI_ALT_HUD_Objects["ComboBox_Armor"] = comboBoxArmor
        verticalBox:AddChildToVerticalBox(comboBoxArmor)

        local WeaponLabel = StaticConstructObject(StaticFindObject("/Script/UMG.TextBlock"),
            verticalBox, FName("Spawn_Weapon_Logo"))
        WeaponLabel:SetText(FText("Spawn Weapon:"))
        SetSmallerFont(WeaponLabel)
        verticalBox:AddChildToVerticalBox(WeaponLabel)

        local ScaleHorizontalBox = StaticConstructObject(StaticFindObject("/Script/UMG.HorizontalBox"),
            verticalBox, FName("ScaleHorizontalBox"))

        local ScaleLabel = StaticConstructObject(StaticFindObject("/Script/UMG.TextBlock"),
            ScaleHorizontalBox, FName("ScaleLabel"))
        ScaleLabel:SetText(FText("Scale: %.1f "))
        SetSmallerFont(ScaleLabel)
        HSTM_UI_ALT_HUD_Objects["ScaleLabel"] = ScaleLabel
        ScaleHorizontalBox:AddChildToHorizontalBox(ScaleLabel)

        local ScaleXLabel = StaticConstructObject(StaticFindObject("/Script/UMG.TextBlock"),
            ScaleHorizontalBox, FName("ScaleXLabel"))
        ScaleXLabel:SetText(FText(" X:"))
        SetSmallerFont(ScaleXLabel)
        ScaleHorizontalBox:AddChildToHorizontalBox(ScaleXLabel)

        local ScaleXCheckBox = StaticConstructObject(StaticFindObject("/Script/UMG.CheckBox"),
            ScaleHorizontalBox, FName("ScaleXCheckBox"))
        HSTM_UI_ALT_HUD_Objects["ScaleXCheckBox"] = ScaleXCheckBox
        ScaleXCheckBox:SetIsChecked(true)
        ScaleHorizontalBox:AddChildToHorizontalBox(ScaleXCheckBox)

        local ScaleYLabel = StaticConstructObject(StaticFindObject("/Script/UMG.TextBlock"),
            ScaleHorizontalBox, FName("ScaleYLabel"))
        ScaleYLabel:SetText(FText(" Y:"))
        SetSmallerFont(ScaleYLabel)
        ScaleHorizontalBox:AddChildToHorizontalBox(ScaleYLabel)

        local ScaleYCheckBox = StaticConstructObject(StaticFindObject("/Script/UMG.CheckBox"),
            ScaleHorizontalBox, FName("ScaleYCheckBox"))
        HSTM_UI_ALT_HUD_Objects["ScaleYCheckBox"] = ScaleYCheckBox
        ScaleYCheckBox:SetIsChecked(true)
        ScaleHorizontalBox:AddChildToHorizontalBox(ScaleYCheckBox)

        local ScaleZLabel = StaticConstructObject(StaticFindObject("/Script/UMG.TextBlock"),
            ScaleHorizontalBox, FName("ScaleZLabel"))
        ScaleZLabel:SetText(FText(" Z:"))
        SetSmallerFont(ScaleZLabel)
        ScaleHorizontalBox:AddChildToHorizontalBox(ScaleZLabel)

        local ScaleZCheckBox = StaticConstructObject(StaticFindObject("/Script/UMG.CheckBox"),
            ScaleHorizontalBox, FName("ScaleZCheckBox"))
        HSTM_UI_ALT_HUD_Objects["ScaleZCheckBox"] = ScaleZCheckBox
        ScaleZCheckBox:SetIsChecked(true)
        ScaleHorizontalBox:AddChildToHorizontalBox(ScaleZCheckBox)

        verticalBox:AddChildToVerticalBox(ScaleHorizontalBox)

        local ScaleSlider = StaticConstructObject(StaticFindObject("/Script/UMG.Slider"),
            verticalBox, FName("ScaleSlider"))
        ScaleSlider:SetValue(1.0)
        ScaleSlider:SetMinValue(0.1)
        ScaleSlider:SetMaxValue(10.0)

        HSTM_UI_ALT_HUD_Objects["ScaleSlider"] = ScaleSlider

        verticalBox:AddChildToVerticalBox(ScaleSlider)

        -- Currently accessing MulticastInlineDelegateProperty from Lua is not supported in UE4SS
        -- The best we can do is to have another loop that polls the value of the slider and updates the scale

        if ModUIHUDUpdateLoopEnabled then
            LoopAsync(500, function()
                if myInitGameStateHookCount ~= InitGameStateHookCount then
                    Log("Exiting leftover ScaleSlider update loop\n")
                    return true
                end
                if not HSTM_UI_ALT_HUD_Objects["ScaleSlider"] or not HSTM_UI_ALT_HUD_Objects["ScaleLabel"] then
                    return true
                end
                local value = HSTM_UI_ALT_HUD_Objects["ScaleSlider"]:GetValue()
                WeaponScaleMultiplier = value
                HSTM_UI_ALT_HUD_Objects["ScaleLabel"]:SetText(FText(string.format("Scale: %.1f ", value)))
                return false
            end)
        end
        -- ScaleSlider["OnValueChanged"] = function(value)
        --     WeaponScaleMultiplier = value
        --     ScaleLabel:SetText(FText(string.format("Scale: %.1f ", value)))
        -- end

        local ScaleBladeOnlyHorizontalBox = StaticConstructObject(StaticFindObject("/Script/UMG.HorizontalBox"),
            verticalBox, FName("ScaleBladeOnlyHorizontalBox"))

        local ScaleBladeOnlyLabel = StaticConstructObject(StaticFindObject("/Script/UMG.TextBlock"),
            ScaleBladeOnlyHorizontalBox, FName("ScaleBladeOnlyLabel"))
        ScaleBladeOnlyLabel:SetText(FText("Blade Only:"))
        SetSmallerFont(ScaleBladeOnlyLabel)
        ScaleBladeOnlyHorizontalBox:AddChildToHorizontalBox(ScaleBladeOnlyLabel)

        local ScaleBladeOnlyCheckBox = StaticConstructObject(StaticFindObject("/Script/UMG.CheckBox"),
            ScaleBladeOnlyHorizontalBox, FName("ScaleBladeOnlyCheckBox"))
        HSTM_UI_ALT_HUD_Objects["ScaleBladeOnlyCheckBox"] = ScaleBladeOnlyCheckBox
        ScaleBladeOnlyHorizontalBox:AddChildToHorizontalBox(ScaleBladeOnlyCheckBox)

        verticalBox:AddChildToVerticalBox(ScaleBladeOnlyHorizontalBox)

        HSTM_UI_ALT_HUD_Objects["ComboBox_Weapon"] = comboBoxWeapons
        verticalBox:AddChildToVerticalBox(comboBoxWeapons)

        local NPCSpawnLabel = StaticConstructObject(StaticFindObject("/Script/UMG.TextBlock"),
            verticalBox, FName("Spawn_NPC_Label"))
        NPCSpawnLabel:SetText(FText("Spawn NPC:"))

        SetSmallerFont(NPCSpawnLabel)
        verticalBox:AddChildToVerticalBox(NPCSpawnLabel)

        HSTM_UI_ALT_HUD_Objects["ComboBox_NPCClass"] = comboBoxNPCClass
        verticalBox:AddChildToVerticalBox(comboBoxNPCClass)

        local NPCTeamLabel = StaticConstructObject(StaticFindObject("/Script/UMG.TextBlock"),
            verticalBox, FName("NPCTeam_Label"))
        NPCTeamLabel:SetText(FText("NPC Team:"))
        SetSmallerFont(NPCTeamLabel)
        verticalBox:AddChildToVerticalBox(NPCTeamLabel)

        HSTM_UI_ALT_HUD_Objects["ComboBox_NPCTeam"] = comboBoxNPCTeam
        verticalBox:AddChildToVerticalBox(comboBoxNPCTeam)

        local SpawnFrozenNPCsHorizontalBox = StaticConstructObject(StaticFindObject("/Script/UMG.HorizontalBox"),
            verticalBox, FName("SpawnFrozenNPCsHorizontalBox"))

        local SpawnFrozenNPCsLabel = StaticConstructObject(StaticFindObject("/Script/UMG.TextBlock"),
            SpawnFrozenNPCsHorizontalBox, FName("SpawnFrozenNPCsLabel"))
        SpawnFrozenNPCsLabel:SetText(FText("Spawn Frozen NPCs:"))
        SetSmallerFont(SpawnFrozenNPCsLabel)
        SpawnFrozenNPCsHorizontalBox:AddChildToHorizontalBox(SpawnFrozenNPCsLabel)

        local SpawnFrozenNPCsCheckBox = StaticConstructObject(StaticFindObject("/Script/UMG.CheckBox"),
            SpawnFrozenNPCsHorizontalBox, FName("SpawnFrozenNPCsCheckBox"))
        HSTM_UI_ALT_HUD_Objects["SpawnFrozenNPCsCheckBox"] = SpawnFrozenNPCsCheckBox
        SpawnFrozenNPCsHorizontalBox:AddChildToHorizontalBox(SpawnFrozenNPCsCheckBox)

        verticalBox:AddChildToVerticalBox(SpawnFrozenNPCsHorizontalBox)

        verticalBox:SetVisibility(Visibility_SELFHITTESTINVISIBLE)
        local slot = HSTM_UI_ALT_HUD.WidgetTree.RootWidget:AddChildToCanvas(verticalBox)
        -- anchors/alignment do no seem to work yet, neither before nor after adding to a viewport
        -- slot:SetAnchors({Minimum = {X = 1.0, Y = 0.0}, Maximum = {X = 1.0, Y = 1.0}})
        -- slot:SetAlignment({X = 1.0, Y = 0.0})
        -- slot:SetPosition({X = 0.0, Y = 0.0})
        -- slot:SetSize({X = 0.0, Y = 200.0})
        HSTM_UI_ALT_HUD:SetVisibility(Visibility_SELFHITTESTINVISIBLE)
        HSTM_UI_ALT_HUD:AddToViewport(99)
        -- slot:SetMinimum({X = 1.0, Y = 0.0})
        -- slot:SetMaximum({X = 1.0, Y = 1.0})
        --HSTM_UI_ALT_HUD:SetVisibility(Visibility_SELFHITTESTINVISIBLE)

        if not config.ui_visible_on_start then
            ToggleModUI()
        end
    end
end

------------------------------------------------------------------------------
-- A very long function taking all the various stats we want from the player object
-- and writing them into the textblocks of the UI Widget that we use as a mod's HUD
-- using the bound variables of the mod's HSTM_UI blueprint, because:
-- * TextBlock does not seem to have a SetText() method we could use,
-- * and for SetText() we also need FText for an argument, the constructor of which is not in the stable UE4SS 2.5.2
--   and not yet merged into the master branch either (https://github.com/UE4SS-RE/RE-UE4SS/pull/301)
-- On the other hand, the stable UE4SS 2.5.2 crashes less with Half Sword, so all this is justified.
-- The mod is also compatible with UE4SS 3.x.x, which should have FText() now, but we use the old implementation anyway
------------------------------------------------------------------------------
-- function HUD_UpdatePlayerStats()
--     local player = GetActivePlayer()
--     -- Attempting to just skip the loop if the player wasn't found for some reasons
--     if not player then
--         ErrLogf("Player not found, skipping\n")
--         return
--     end
--     PlayerTeam                              = player['Team Int']
--     PlayerHealth                            = player['Health']
--     Invulnerable                            = player['Invulnerable']
--     cache.ui_hud['HUD_Player_Team_Value']   = PlayerTeam
--     cache.ui_hud['HUD_HP_Value']            = PlayerHealth
--     cache.ui_hud['HUD_Invuln_Value']        = Invulnerable
--     cache.ui_hud['HUD_SuperStrength_Value'] = SuperStrength
--     --
--     PlayerScore                             = cache.map['Score']
--     cache.ui_hud['HUD_Score_Value']         = PlayerScore

--     PlayerConsciousness                     = player['Consciousness']
--     cache.ui_hud['HUD_Cons_Value']          = PlayerConsciousness

--     PlayerTonus                             = player['All Body Tonus']
--     cache.ui_hud['HUD_Tonus_Value']         = PlayerTonus
--     --
--     GameSpeed                               = cache.worldsettings['TimeDilation']
--     cache.ui_hud['HUD_GameSpeed_Value']     = GameSpeed
--     cache.ui_hud['HUD_NPCsFrozen_Value']    = Frozen
--     cache.ui_hud['HUD_SlowMotion_Value']    = SlowMotionEnabled
--     --
--     HH                                      = player['Head Health']
--     NH                                      = player['Neck Health']
--     BH                                      = player['Body Health']
--     ARH                                     = player['Arm_R Health']
--     ALH                                     = player['Arm_L Health']
--     LRH                                     = player['Leg_R Health']
--     LLH                                     = player['Leg_L Health']
--     --
--     cache.ui_hud['HUD_HH']                  = math.floor(HH)
--     cache.ui_hud['HUD_NH']                  = math.floor(NH)
--     cache.ui_hud['HUD_BH']                  = math.floor(BH)
--     cache.ui_hud['HUD_ARH']                 = math.floor(ARH)
--     cache.ui_hud['HUD_ALH']                 = math.floor(ALH)
--     cache.ui_hud['HUD_LRH']                 = math.floor(LRH)
--     cache.ui_hud['HUD_LLH']                 = math.floor(LLH)
--     --
--     -- Joint health logic is commented for now, as the Joint health HUD is disabled since mod v0.6
--     --
--     -- HJH                                     = player['Head Joint Health']
--     -- TJH                                     = player['Torso Joint Health']
--     -- HRJH                                    = player['Hand R Joint Health']
--     -- ARJH                                    = player['Arm R Joint Health']
--     -- SRJH                                    = player['Shoulder R Joint Health']
--     -- HLJH                                    = player['Hand L Joint Health']
--     -- ALJH                                    = player['Arm L Joint Health']
--     -- SLJH                                    = player['Shoulder L Joint Health']
--     -- TRJH                                    = player['Thigh R Joint Health']
--     -- LRJH                                    = player['Leg R Joint Health']
--     -- FRJH                                    = player['Foot R Joint Health']
--     -- TLJH                                    = player['Thigh L Joint Health']
--     -- LLJH                                    = player['Leg L Joint Health']
--     -- FLJH                                    = player['Foot L Joint Health']
--     -- --
--     -- cache.ui_hud['HUD_HJH']                 = math.floor(HJH)
--     -- cache.ui_hud['HUD_TJH']                 = math.floor(TJH)
--     -- cache.ui_hud['HUD_HRJH']                = math.floor(HRJH)
--     -- cache.ui_hud['HUD_ARJH']                = math.floor(ARJH)
--     -- cache.ui_hud['HUD_SRJH']                = math.floor(SRJH)
--     -- cache.ui_hud['HUD_HLJH']                = math.floor(HLJH)
--     -- cache.ui_hud['HUD_ALJH']                = math.floor(ALJH)
--     -- cache.ui_hud['HUD_SLJH']                = math.floor(SLJH)
--     -- cache.ui_hud['HUD_TRJH']                = math.floor(TRJH)
--     -- cache.ui_hud['HUD_LRJH']                = math.floor(LRJH)
--     -- cache.ui_hud['HUD_FRJH']                = math.floor(FRJH)
--     -- cache.ui_hud['HUD_TLJH']                = math.floor(TLJH)
--     -- cache.ui_hud['HUD_LLJH']                = math.floor(LLJH)
--     -- cache.ui_hud['HUD_FLJH']                = math.floor(FLJH)

--     --

--     HUD_CacheLevel()
--     HUD_CacheProjectile()
-- end

function formatHUDTextBox(boxName, ...)
    if not HSTM_UI_ALT_HUD_Objects[boxName] or not HSTM_UI_ALT_HUD_Objects[boxName]:IsValid() then
        ErrLogf("TextBox [%s] not valid, skipping\n", boxName)
        return
    end
    -- This is a horrible hack to handle nil values to default to 0 to avoid string.format() errors
    local args = { ... }
    if #args == 0 then
        args = { 0 }
    end
    for i, v in ipairs(args) do
        if v == nil then
            args[i] = 0
        end
    end
    HSTM_UI_ALT_HUD_Objects[boxName]:SetText(FText(HSTM_UI_ALT_HUD_TextBox_Names[boxName][2]:format(table.unpack(args))))
end

------------------------------------------------------------------------------
-- This implementation is for playtest only, using manually constructed UMG objects
function HUD_UpdatePlayerStats_Playtest()
    local player = GetActivePlayer()
    -- Attempting to just skip the loop if the player wasn't found for some reasons
    if not player then
        ErrLogf("Player not found, skipping\n")
        return
    end
    PlayerTeam   = tonumber(player['Team Int'])
    PlayerHealth = tonumber(player['Health'])
    Invulnerable = player['Invulnerable']

    formatHUDTextBox("TextBox_Player_Team", PlayerTeam)

    formatHUDTextBox("TextBox_HP", PlayerHealth)

    formatHUDTextBox("TextBox_Invulnerability", tostring(Invulnerable))

    formatHUDTextBox("TextBox_SuperStrength", tostring(SuperStrength))
    --
    PlayerScore = cache.map['Score']
    -- HSTM_UI_ALT_HUD_TextBox_Objects["TextBox_Score"]:SetText(FText(HSTM_UI_ALT_HUD_TextBox_Names["TextBox_Score"][2]
    -- :format(
    --     PlayerScore)))

    PlayerConsciousness = player['Consciousness']
    formatHUDTextBox("TextBox_Cons", PlayerConsciousness)

    PlayerTonus = player['All Body Tonus']
    formatHUDTextBox("TextBox_Tonus", PlayerTonus)

    PlayerStamina = player['Stamina']
    formatHUDTextBox("TextBox_Stamina", PlayerStamina)
    --
    GameSpeed = cache.worldsettings['TimeDilation']

    formatHUDTextBox("TextBox_GameSpeed", GameSpeed, tostring(SlowMotionEnabled))

    formatHUDTextBox("TextBox_NPCsFrozen", tostring(Frozen))
    --
    HUD_CacheProjectile()
end

------------------------------------------------------------------------------
-- Refresh stamina to 100 in a loop, 4 times per second. Exit if no cheats on.
function SuperStaminaLoop()
    -- Exit if already active, allow max 1 loop of this
    if SuperStamina then
        return
    end
    local player = GetActivePlayer()
    Logf("Entering stamina refresh loop...\n")
    LoopAsync(250, function()
        if SuperStrength or Invulnerable then
            player['Stamina'] = 100
        else
            SuperStamina = false
            Logf("Exiting stamina refresh loop.\n")
            return true
        end
        return false
    end)
end

------------------------------------------------------------------------------
-- We switch between standard stats and our idea of increased stats, saving the original stats
function ToggleSuperStrength()
    -- TODO handle possession
    local player = GetActivePlayer()
    SuperStrength = not SuperStrength
    if SuperStrength then
        savedRSR = player['Running Speed Rate']
        savedMP = player['Muscle Power']
        player['Running Speed Rate'] = config.max_rsr
        player['Muscle Power'] = config.max_mp
        -- Activating stamina refresher loop
        SuperStaminaLoop()
    else
        player['Running Speed Rate'] = savedRSR
        player['Muscle Power'] = savedMP
    end
    Log("SuperStrength = " .. tostring(SuperStrength) .. "\n")
    if ModUIHUDVisible then
        formatHUDTextBox("TextBox_SuperStrength", tostring(SuperStrength))
    end
end

------------------------------------------------------------------------------
-- We also increase regeneration rate together with invulnerability
-- to prevent the player from dying from past wounds
function ToggleInvulnerability()
    -- TODO handle possession
    local player = GetActivePlayer()
    Invulnerable = player['Invulnerable']
    Invulnerable = not Invulnerable
    if Invulnerable then
        savedRegenRate = player['Regen Rate']
        player['Regen Rate'] = config.max_regen_rate
        -- Activating stamina refresher loop
        SuperStaminaLoop()
        -- Attempt to undo some of the damage done before to the player and the body model
        -- Doesn't seem to work.
        --player['Reset Sustained Damage']()
        --player['Reset Blood Bleed']()
        --player['Reset Dismemberment']()
    else
        player['Regen Rate'] = savedRegenRate
    end
    player['Invulnerable'] = Invulnerable
    Log("Invulnerable = " .. tostring(Invulnerable) .. "\n")
    if ModUIHUDVisible then
        formatHUDTextBox("TextBox_Invulnerability", tostring(Invulnerable))
    end
end

------------------------------------------------------------------------------
-- 99 is the z-order set in UI HUD blueprint in UE5 editor
-- 100 is the z-order set in UI Spawn blueprint in UE5 editor
-- should be high enough to be on top of everything
function ToggleModUI()
    if ModUIHUDVisible then
        HSTM_UI_ALT_HUD:SetVisibility(Visibility_HIDDEN)
        ModUIHUDVisible = false
    else
        HSTM_UI_ALT_HUD:SetVisibility(Visibility_SELFHITTESTINVISIBLE)
        ModUIHUDVisible = true
        -- If the HUD update loop has crashed, try to update the HUD in the worst case
        HUD_UpdatePlayerStats_Playtest()
    end
    -- TODO
    if ModUISpawnVisible then
        --cache.ui_spawn:SetVisibility(Visibility_HIDDEN)
        ModUISpawnVisible = false
    else
        --cache.ui_spawn:SetVisibility(Visibility_SELFHITTESTINVISIBLE)
        ModUISpawnVisible = true
    end
end

------------------------------------------------------------------------------
-- Just some high-tier loadout I like, all the best armor, a huge shield, long polearm and two one-armed swords.
-- The table structure is: class, {X=scale,Y=scale,Z=scale}, scale_blade_only}
local default_loadout = {
    { "/Game/Assets/Armor/Blueprints/Built_Armor/Cloth/BP_Armor_Legs_Hosen_Arming_A.BP_Armor_Legs_Hosen_Arming_A_C",                 DefaultScale1x, false },
    { "/Game/Assets/Armor/Blueprints/Built_Armor/Metal/Feet/BP_Armor_Feet_Sabbatons_A.BP_Armor_Feet_Sabbatons_A_C",                  DefaultScale1x, false },
    { "/Game/Assets/Armor/Blueprints/Built_Armor/Cloth/BP_Armor_Body_Doublet_Arming.BP_Armor_Body_Doublet_Arming_C",                 DefaultScale1x, false },
    { "/Game/Assets/Armor/Blueprints/Built_Armor/Metal/Chest/BP_Armor_Body_Cuirass_C_T3.BP_Armor_Body_Cuirass_C_T3_C",               DefaultScale1x, false },
    { "/Game/Assets/Armor/Blueprints/Built_Armor/Mail/BP_Armor_Waist_Foulds_T3.BP_Armor_Waist_Foulds_T3_C",                          DefaultScale1x, false },
    { "/Game/Assets/Armor/Blueprints/Built_Armor/Metal/Arms/BP_Armor_Arms_Vambrace_C_T3_B.BP_Armor_Arms_Vambrace_C_T3_B_C",          DefaultScale1x, false },
    { "/Game/Assets/Armor/Blueprints/Built_Armor/Metal/Legs/BP_Armor_Legs_Cuisse_A_T3.BP_Armor_Legs_Cuisse_A_T3_C",                  DefaultScale1x, false },
    { "/Game/Assets/Armor/Blueprints/Built_Armor/Metal/Legs/BP_Armor_Legs_Greaves_T3.BP_Armor_Legs_Greaves_T3_C",                    DefaultScale1x, false },
    { "/Game/Assets/Armor/Blueprints/Built_Armor/Metal/Neck/BP_Armor_Neck_Bevor_T3.BP_Armor_Neck_Bevor_T3_C",                        DefaultScale1x, false },
    { "/Game/Assets/Armor/Blueprints/Built_Armor/Metal/Shoulders/BP_Armor_Shoulders_Pauldron_C_B.BP_Armor_Shoulders_Pauldron_C_B_C", DefaultScale1x, false },
    { "/Game/Assets/Armor/Blueprints/Built_Armor/Metal/Head/BP_Armor_Head_Sallet_Solid_C_002.BP_Armor_Head_Sallet_Solid_C_002_C",    DefaultScale1x, false },
    { "/Game/Assets/Armor/Blueprints/Built_Armor/Metal/Hands/BP_Armor_Hands_Gauntlets_T3B.BP_Armor_Hands_Gauntlets_T3B_C",           DefaultScale1x, false },
    { "/Game/Assets/Weapons/Blueprints/Built_Weapons/Shield_Pavise_Tower.Shield_Pavise_Tower_C",                                     DefaultScale1x, false },
    { "/Game/Assets/Weapons/Blueprints/Built_Weapons/ModularWeaponBP_BastardSword_T3.ModularWeaponBP_BastardSword_T3_C",             DefaultScale1x, false },
    { "/Game/Assets/Weapons/Blueprints/Built_Weapons/ModularWeaponBP_BastardSword_T3.ModularWeaponBP_BastardSword_T3_C",             DefaultScale1x, false },
    { "/Game/Assets/Weapons/Blueprints/Built_Weapons/Tiers/ModularWeaponBP_Polearm_High_Tier.ModularWeaponBP_Polearm_High_Tier_C",   DefaultScale1x, false },
}

-- Read custom loadout from a text file `data\custom_loadout.txt` containing class names to spawn around player
--
-- The format of the file is like this:
--
-- /foo/bar/baz/class
-- (2.0)/foo/bar/baz/class
-- (1.0,2.0,3.0)/foo/bar/baz/class
-- [BladeOnly](2.0)/foo/bar/baz/class
-- [BladeOnly](1.0,2.0,3.0)/foo/bar/baz/class
--
-- Use [BAD] in the beginning of the line to comment it

function LoadCustomLoadout()
    local file = io.open("ue4ss\\Mods\\HalfSwordTrainerMod\\data\\custom_loadout.txt", "r");
    if file ~= nil then
        if custom_loadout then custom_loadout = {} end
        Logf("Loading custom loadout...\n")
        for line in file:lines() do
            -- skip commented lines
            if not line:starts_with('[BAD]') and not line:match("^%s*#") and not line:match("^%s*$") then
                local _, _, scale, class = string.find(line, "%(([%d%.]+)%)([/%w_%.]+)$")
                -- Blade-only scaling is passed through to the loadout table as a flag
                local blade = line:starts_with('[BladeOnly]')
                if scale and class then
                    -- The single (all X=Y=Z proportional) scale multiplier is applied if found
                    local mult = tonumber(scale)
                    table.insert(custom_loadout, { class, { X = mult, Y = mult, Z = mult }, blade })
                else
                    -- Otherwise, we have individual non-proportional X, Y, Z scale coefficients
                    local _, _, scaleX, scaleY, scaleZ, class = string.find(line,
                        "%(%s*([%d%.]+),%s*([%d%.]+),%s*([%d%.]+)%s*%)([/%w_%.]+)$")
                    if scaleX and scaleY and scaleZ and class then
                        table.insert(custom_loadout,
                            { class, { X = tonumber(scaleX), Y = tonumber(scaleY), Z = tonumber(scaleZ) }, blade })
                    else
                        -- No scale is supplied, just spawn the actor as is
                        table.insert(custom_loadout, { line, DefaultScale1x, false })
                    end
                end
            end
        end
        Logf("Custom loadout loaded, %d items\n", #custom_loadout)
    end
end

------------------------------------------------------------------------------
-- The function spawns any of the loaded assets by their class name and customizes a few parameters
-- A lot of them are dirty hacks and should probably be moved elsewhere
-- We are handling some special cases inside which is not optimal
-- Also as we often need the return value, this whole function has to be executed in a game thread
-- For NPCs, this sometimes leads to crashes https://github.com/UE4SS-RE/RE-UE4SS/issues/527
function SpawnActorByClassPath(FullClassPath, SpawnLocation, SpawnRotation, SpawnScale, BladeScaleOnly, AlsoScaleObjects)
    -- TODO Load missing assets!
    -- WARN Only spawns loaded assets now!
    if FullClassPath == nil or FullClassPath == "" then
        ErrLogf("Invalid ClassPath [%s] for actor, cannot spawn!\n", tostring(FullClassPath))
        return
    end

    LoadAsset(FullClassPath)

    local DefaultLocation = { X = 100.0, Y = 100.0, Z = 100.0 }
    local CurrentLocation = SpawnLocation == nil and DefaultLocation or SpawnLocation
    local DefaultScaleMultiplier = DefaultScale1x
    local SpawnScaleMultiplier = SpawnScale == nil and DefaultScaleMultiplier or SpawnScale
    local DefaultRotation = NullRotation
    local CurrentRotation = SpawnRotation == nil and DefaultRotation or SpawnRotation
    -- TODO This assumes the class associated with this asset is loaded!
    local ActorClass = StaticFindObject(FullClassPath)
    if ActorClass == nil or not ActorClass:IsValid() then error("[ERROR] ActorClass is not valid") end
    local isNPC = FullClassPath:contains("/Game/Character/Blueprints/")
    local World = myGetPlayerController():GetWorld()
    if World == nil or not World:IsValid() then error("[ERROR] World is not valid") end
    local Actor = World:SpawnActor(ActorClass, CurrentLocation, CurrentRotation)
    if Actor == nil or not Actor:IsValid() then
        Logf("[ERROR] Actor for \"%s\" is not valid\n", FullClassPath)
        return nil
    else
        if spawned_things then
            -- We try to guess if this actor was an NPC
            table.insert(spawned_things,
                { Object = Actor, IsCharacter = isNPC })
        end
        if isNPC then
            -- Try to freeze the NPC if we have spawn frozen flag set
            if SpawnFrozenNPCs then
                Actor['CustomTimeDilation'] = 0.0
            end
            -- Try to apply the chosen NPC Team
            Actor['Team Int'] = NPCTeam
        else
            -- We don't really care if this is a weapon, but we try anyway
            -- Some actors already have non-default scale, so we don't override that
            -- Yes, it is not a good idea to compare floats like this, but we do 0.1 increments so "this is fine" (c)
            if SpawnScale ~= nil then
                if BladeScaleOnly then
                    if FullClassPath:contains("/Built_Weapons/ModularWeaponBP") then
                        -- Actually not sure which scale we should set, relative or world?
                        Actor['head']:SetRelativeScale3D(SpawnScale)
                    end
                else
                    if AlsoScaleObjects then
                        if FullClassPath:contains("_Prop_Furniture") then
                            Actor['SM_Prop']:SetRelativeScale3D(SpawnScale)
                        elseif FullClassPath:contains("Dest_Barrel") then
                            Actor['RootComponent']:SetRelativeScale3D(SpawnScale)
                        elseif FullClassPath:contains("BP_Prop_Barrel") then
                            Actor['SM_Barrel']:SetRelativeScale3D(SpawnScale)
                        end
                    end
                    Actor:SetActorScale3D(SpawnScale)
                end
            end
        end
        Logf("Spawned Actor: %s at {X=%.3f, Y=%.3f, Z=%.3f} rotation {Pitch=%.3f, Yaw=%.3f, Roll=%.3f}\n",
            Actor:GetFullName(), CurrentLocation.X, CurrentLocation.Y, CurrentLocation.Z,
            CurrentRotation.Pitch, CurrentRotation.Yaw, CurrentRotation.Roll)
        return Actor
    end
end

-- Should also undo all spawned things if called repeatedly
function UndoLastSpawn()
    if spawned_things then
        if #spawned_things > 0 then
            local actorToDespawnRecord = spawned_things[#spawned_things]
            local actorToDespawn = actorToDespawnRecord.Object
            if actorToDespawn and actorToDespawn:IsValid() then
                Logf("Despawning actor: %s\n", actorToDespawn:GetFullName())
                --                actorToDespawn:Destroy()
                actorToDespawn:K2_DestroyActor()
                -- let's remove it for now so undo can be repeated.
                -- K2_DestroyActor() is supposed to clean up things properly
                table.remove(spawned_things, #spawned_things)
            end
        end
    end
end

-- We are iterating from the end of the array to make sure Lua does not reindex the array as we are deleting items
-- We probaly could also just set them to nil but YOLO let's try to actually remove them from the array
function UndoAllPlayerSpawnedCharacters()
    if spawned_things then
        for i = #spawned_things, 1, -1 do
            local actorToDespawnRecord = spawned_things[i]
            local actorToDespawn = actorToDespawnRecord.Object
            if actorToDespawn and actorToDespawn:IsValid() and actorToDespawnRecord.IsCharacter then
                Logf("Despawning NPC actor: %s\n", actorToDespawn:GetFullName())
                actorToDespawn:K2_DestroyActor()
                -- let's remove it for now so undo can be repeated.
                -- K2_DestroyActor() is supposed to clean up things properly
                table.remove(spawned_things, i)
            end
        end
    end
end

------------------------------------------------------------------------------
-- This takes possession into account
function GetActivePlayer()
    local player
    local FirstPlayerController = myGetPlayerController()
    -- TODO maybe this is not a great idea
    if not FirstPlayerController then
        if cache.map then
            player = cache.map[cache.map_player_name]
            if player:IsValid() then
                return player
            end
        end
        return nil
    end
    player = FirstPlayerController.Pawn
    if player:IsValid() then
        return player
    end
    return nil
end

------------------------------------------------------------------------------
-- The location is retrieved using a less documented approach of K2_GetActorLocation()
function GetPlayerLocation()
    local FirstPlayerController = myGetPlayerController()
    if not FirstPlayerController then
        return NullLocation
    end
    local Pawn = FirstPlayerController.Pawn
    local location = Pawn:K2_GetActorLocation()
    return location
end

function GetPlayerViewRotation()
    local FirstPlayerController = myGetPlayerController()
    if not FirstPlayerController then
        return NullRotation
    end
    local rotation = FirstPlayerController['ControlRotation']
    return rotation
end

------------------------------------------------------------------------------
-- We spawn the loadout in a circle, rotating a displacement vector a bit
-- with every item (360 degrees / number of items), so they all fit nicely
function SpawnLoadoutAroundPlayer()
    local spawnDeltaDelay = 300 -- in milliseconds
    local PlayerLocation = GetPlayerLocation()
    local PlayerRotation = GetPlayerViewRotation()
    local DeltaLocation = maf.vec3(config.spawn_offset_x_object, 0.0, 200.0)

    local rotatedDelta = DeltaLocation
    local loadout = default_loadout
    if #custom_loadout > 0 then
        loadout = custom_loadout
        Logf("Spawning custom loadout...\n")
    end
    -- This attempts to start spawning from the direction of the player view
    local initialRotator = maf.rotation.fromAngleAxis(
        math.rad(PlayerRotation.Yaw),
        0.0, -- math.rad(PlayerRotation.Pitch),
        0.0, -- math.rad(PlayerRotation.Roll),
        1.0
    )
    rotatedDelta:rotate(initialRotator)

    -- This is splitting the spawn circle (360 degrees / number of items) in radians
    local rotator = maf.rotation.fromAngleAxis(((math.pi * 2) / #loadout), 0.0, 0.0, 1.0)
    for index, value in ipairs(loadout) do
        local class, scale, bladescale = table.unpack(value)
        local SpawnLocation = {
            X = PlayerLocation.X + rotatedDelta.x,
            Y = PlayerLocation.Y + rotatedDelta.y,
            Z = PlayerLocation.Z + rotatedDelta.z
        }
        -- The delays are accumulated, step =
        ExecuteWithDelay((index - 1) * spawnDeltaDelay, function()
            ExecuteInGameThread(function()
                _ = SpawnActorByClassPath(class, SpawnLocation, NullRotation, scale, bladescale)
            end)
        end)
        rotatedDelta:rotate(rotator)
    end
end

-- Try to spawn the actor(item) in front of the player
-- Get player's rotation vector and rotate our offset by its value
function SpawnActorInFrontOfPlayer(classpath, offset, lookingAtPlayer, scale, BladeOnly, AlsoScaleObjects)
    local defaultOffset = maf.vec3(300.0, 0.0, 0.0)
    local PlayerLocation = GetPlayerLocation()
    local PlayerRotation = GetPlayerViewRotation()

    local rotator = maf.rotation.fromAngleAxis(
        math.rad(PlayerRotation.Yaw),
        0.0, -- math.rad(PlayerRotation.Pitch),
        0.0, -- math.rad(PlayerRotation.Roll),
        1.0
    )
    local DeltaLocation = offset == nil and defaultOffset or maf.vec3(offset.X, offset.Y, offset.Z)
    local rotatedDelta = DeltaLocation
    rotatedDelta:rotate(rotator)
    local SpawnLocation = {
        X = PlayerLocation.X + rotatedDelta.x,
        Y = PlayerLocation.Y + rotatedDelta.y,
        Z = PlayerLocation.Z + rotatedDelta.z
    }
    local lookingAtPlayerRotation = { Yaw = 180.0 + PlayerRotation.Yaw, Pitch = 0.0, Roll = 0.0 }
    local SpawnRotation = lookingAtPlayer and lookingAtPlayerRotation or NullRotation
    local SpawnScale = scale == nil and DefaultScale1x or scale
    ExecuteInGameThread(function()
        _ = SpawnActorByClassPath(classpath, SpawnLocation, SpawnRotation, SpawnScale, BladeOnly, AlsoScaleObjects)
    end)
end

------------------------------------------------------------------------------
function HUD_SetLevel(Level)
    cache.map['Level'] = Level
    Logf("Set Level = %d\n", Level)
    if ModUIHUDVisible then
        --cache.ui_hud['HUD_Level_Value'] = Level
    end
end

function HUD_CacheLevel()
    level = cache.map['Level']
    if ModUIHUDVisible then
        --cache.ui_hud['HUD_Level_Value'] = level
    end
end

-- We allow the player to use only the levels that are present in the game code
-- From 0 to 6 inclusive. Level 6 removes the music, which is also convenient.
function DecreaseLevel()
    HUD_CacheLevel()
    if level > 0 then
        level = level - 1
        HUD_SetLevel(level)
    end
end

function IncreaseLevel()
    HUD_CacheLevel()
    if level < 6 then
        level = level + 1
        HUD_SetLevel(level)
    end
end

------------------------------------------------------------------------------
function HUD_SetPlayerTeam(PlayerTeam)
    local player = GetActivePlayer()
    player['Team Int'] = PlayerTeam
    Logf("Set Player Team = %d\n", PlayerTeam)
    if ModUIHUDVisible then
        formatHUDTextBox("TextBox_Player_Team", PlayerTeam)
    end
end

function HUD_CachePlayerTeam()
    local player = GetActivePlayer()
    local PlayerTeam = player['Team Int']
    if ModUIHUDVisible then
        formatHUDTextBox("TextBox_Player_Team", PlayerTeam)
    end
end

-- We allow the player to choose between teams 0 - 9
function ChangePlayerTeamDown()
    HUD_CachePlayerTeam()
    if PlayerTeam > 0 then
        PlayerTeam = PlayerTeam - 1
        HUD_SetPlayerTeam(PlayerTeam)
    end
end

function ChangePlayerTeamUp()
    HUD_CachePlayerTeam()
    if PlayerTeam < maxPlayerTeam then
        PlayerTeam = PlayerTeam + 1
        HUD_SetPlayerTeam(PlayerTeam)
    end
end

------------------------------------------------------------------------------
-- Killing is actually exploding head and spilling guts
-- That is resource intensive and may lead to crashes sometimes
-- Alternative killing method below, slow animation but also cool
local silentKill = true
function KillAllNPCs()
    local player = GetActivePlayer()
    -- if cache.ui_spawn["HSTM_Flag_KillExplode"] then
    --     silentKill = false
    -- elseif cache.ui_spawn["HSTM_Flag_KillSlow"] then
    --     silentKill = true
    -- end
    ExecuteForAllNPCs(function(NPC)
        if UEAreObjectsEqual(player, NPC) then
            -- this is a possessed NPC, don't
        else
            if silentKill then
                NPC['Health'] = -1.0
                NPC['Death']()
            else
                NPC['Explode Head']()
                NPC['Spill Guts']()
            end
        end
    end)
end

function DespawnAllNPCs()
    local player = GetActivePlayer()
    ExecuteForAllNPCs(function(NPC)
        if UEAreObjectsEqual(player, NPC) then
            -- this is a possessed NPC, don't
        else
            NPC:K2_DestroyActor()
        end
    end)
end

-- TODO figure out how to freeze the upper half of the NPC as well.
function FreezeAllNPCs()
    Frozen = not Frozen
    local player = GetActivePlayer()

    ExecuteForAllNPCs(function(NPC)
        if UEAreObjectsEqual(player, NPC) then
            -- this is a possessed NPC, don't
        else
            NPC['CustomTimeDilation'] = Frozen and 0.0 or 1.0
        end
    end)

    if ModUIHUDVisible then
        formatHUDTextBox("TextBox_NPCsFrozen", tostring(Frozen))
    end
end

------------------------------------------------------------------------------
-- Does not seem to actually remove the armor stats, only the meshes
-- Removing armor/clothes may expose gaps in meshes
function RemoveAllArmor(willie)
    -- It seems that any object inherited from BP_Armor_Master_C will work here, for some reason
    local panties = StaticFindObject("/Game/Assets/Armor/Blueprints/Built_Armor/BP_Armor_Panties.BP_Armor_Panties_C")
    local SpawnTransform = { Rotation = { W = 0.0, X = 0.0, Y = 0.0, Z = 0.0 }, Translation = { X = 0.0, Y = 0.0, Z = 0.0 }, Scale3D = { X = 1.0, Y = 1.0, Z = 1.0 } }
    -- There are 13 values in the enum, from 0 to 12
    -- 0, Helmet
    -- 1, Neck
    -- 2, Neck 2
    -- 3, Body
    -- 4, Body 2
    -- 5, Shoulders
    -- 6, Arms
    -- 7, Hands
    -- 8, Waist
    -- 9, Legs
    -- 10, Legs 2
    -- 11, Legs 3
    -- 12, Feet
    for i = 0, 12, 1 do
        local key = i
        local out1 = {}
        willie['Remove Armor'](
            willie,
            panties,
            SpawnTransform,
            out1,
            key
        )
    end
end

function RemovePlayerArmor()
    local player = GetActivePlayer()
    RemoveAllArmor(player)
end

------------------------------------------------------------------------------
-- The idea of this function is to try to find all NPCs that the game knows about
-- but without enumerating objects in UE, and call a function on those.
-- We go through the enemy array on the map, enemies+bosses in boss arenas, and
-- through the array of things we spawned ourselves.
-- This is useful to despawn or kill all NPCs, etc.
function ExecuteForAllNPCs(callback)
    if cache.map['Enemies'] then
        local npc = cache.map['Enemies']
        if npc:GetArrayNum() > 0 then
            npc:ForEach(function(Index, Elem)
                --                if Elem:IsValid() then
                Logf("Executing for NPC [%i]: %s\n", Index - 1, Elem:get():GetFullName())
                callback(Elem:get())
                --                end
            end)
        end
    end
    -- -- Then freeze the boss if we are in a boss arena and the boss is alive
    -- if cache.map['Current Boss Arena'] and cache.map['Current Boss Arena']:IsValid() then
    --     if cache.map['Boss Alive'] then
    --         local boss = cache.map['Current Boss Arena']['Boss']
    --         if boss:IsValid() then
    --             Logf("Executing for Boss: %s\n", boss:GetFullName())
    --             callback(boss)
    --         end
    --     end
    --     local npc = cache.map['Current Boss Arena']['Spawned Enemies']
    --     if npc and npc:GetArrayNum() > 0 then
    --         npc:ForEach(function(Index, Elem)
    --             if npc:IsValid() then
    --                 Logf("Executing for Boss Spawned NPC [%i]: %s\n", Index - 1, Elem:get():GetFullName())
    --                 callback(Elem:get())
    --             end
    --         end)
    --     end
    -- end
    if spawned_things then
        for i = #spawned_things, 1, -1 do
            local actorToProcessRecord = spawned_things[i]
            local actorToProcess = actorToProcessRecord.Object
            if actorToProcess and actorToProcess:IsValid() and actorToProcessRecord.IsCharacter then
                Logf("Executing for NPC actor: %s\n", actorToProcess:GetFullName())
                callback(actorToProcess)
            end
        end
    end
end

------------------------------------------------------------------------------
-- The SpawnSelected* functions take the currently selected object
-- from the dropdowns in the mod UI on the right side of the screen
-- and spawn that in the direction fo the player's camera view
------------------------------------------------------------------------------

function SpawnSelectedArmor()
    -- local Selected_Spawn_Armor = cache.ui_spawn['Selected_Spawn_Armor']:ToString()
    local selected_actor = nil
    if HSTM_UI_ALT_HUD_Objects["ComboBox_Armor"] and HSTM_UI_ALT_HUD_Objects["ComboBox_Armor"]:IsValid() then
        local Selected_Spawn_Armor = HSTM_UI_ALT_HUD_Objects["ComboBox_Armor"]:GetSelectedOption():ToString()
        --Logf("Spawning armor key [%s]\n", Selected_Spawn_Armor)
        --    if not Selected_Spawn_Armor == nil and not Selected_Spawn_Armor == "" then
        selected_actor = all_armor[Selected_Spawn_Armor]
    else
        _, selected_actor = table.random_key_value(all_armor)
    end
    Logf("Spawning armor [%s]\n", selected_actor)
    SpawnActorInFrontOfPlayer(selected_actor)
    --    end
end

function SpawnSelectedWeapon()
    local selected_actor = nil
    if HSTM_UI_ALT_HUD_Objects["ComboBox_Weapon"] and HSTM_UI_ALT_HUD_Objects["ComboBox_Weapon"]:IsValid() then
        local Selected_Spawn_Weapon = HSTM_UI_ALT_HUD_Objects["ComboBox_Weapon"]:GetSelectedOption():ToString()
        -- WeaponScaleMultiplier = cache.ui_spawn['HSTM_Slider_WeaponSize']
        WeaponScaleMultiplier = HSTM_UI_ALT_HUD_Objects["ScaleSlider"]:GetValue()
        WeaponScaleX = HSTM_UI_ALT_HUD_Objects["ScaleXCheckBox"]:IsChecked()
        WeaponScaleY = HSTM_UI_ALT_HUD_Objects["ScaleYCheckBox"]:IsChecked()
        WeaponScaleZ = HSTM_UI_ALT_HUD_Objects["ScaleZCheckBox"]:IsChecked()
        WeaponScaleBladeOnly = HSTM_UI_ALT_HUD_Objects["ScaleBladeOnlyCheckBox"]:IsChecked()

        --Logf("Spawning weapon key [%s]\n", Selected_Spawn_Weapon)
        --    if not Selected_Spawn_Weapon == nil and not Selected_Spawn_Weapon == "" then
        --local _, selected_actor = table.random_key_value(all_weapons)
        selected_actor = all_weapons[Selected_Spawn_Weapon]
    else
        _, selected_actor = table.random_key_value(all_weapons)
    end
    Logf("Spawning weapon [%s]\n", selected_actor)

    if WeaponScaleMultiplier ~= 1.0 then
        local scale = {
            X = WeaponScaleX and WeaponScaleMultiplier or 1.0,
            Y = WeaponScaleY and WeaponScaleMultiplier or 1.0,
            Z = WeaponScaleZ and WeaponScaleMultiplier or 1.0
        }
        SpawnActorInFrontOfPlayer(selected_actor, nil, nil, scale, WeaponScaleBladeOnly)
    else
        SpawnActorInFrontOfPlayer(selected_actor)
    end
    --    end
end

-- WARN Danger, don't spawn too many of them, crashes will happen!
function SpawnSelectedNPC()
    -- -- Update the flag from the Spawn HUD
    -- SpawnFrozenNPCs = cache.ui_spawn['HSTM_Flag_SpawnFrozenNPCs']
    if HSTM_UI_ALT_HUD_Objects["SpawnFrozenNPCsCheckBox"] and HSTM_UI_ALT_HUD_Objects["SpawnFrozenNPCsCheckBox"]:IsValid() then
        SpawnFrozenNPCs = HSTM_UI_ALT_HUD_Objects["SpawnFrozenNPCsCheckBox"]:IsChecked()
    end
    if HSTM_UI_ALT_HUD_Objects["ComboBox_NPCTeam"] and HSTM_UI_ALT_HUD_Objects["ComboBox_NPCTeam"]:IsValid() then
        NPCTeam = HSTM_UI_ALT_HUD_Objects["ComboBox_NPCTeam"]:GetSelectedOption():ToString()
    end
    -- local Selected_Spawn_NPC = cache.ui_spawn['Selected_Spawn_NPC']:ToString()
    -- --Logf("Spawning NPC key [%s]\n", Selected_Spawn_NPC)
    -- --    if not Selected_Spawn_NPC == nil and not Selected_Spawn_NPC == "" then
    -- local selected_actor = all_characters[Selected_Spawn_NPC]
    local selected_actor = nil
    if HSTM_UI_ALT_HUD_Objects["ComboBox_NPCClass"] and HSTM_UI_ALT_HUD_Objects["ComboBox_NPCClass"]:IsValid() then
        local Selected_Spawn_NPC = HSTM_UI_ALT_HUD_Objects["ComboBox_NPCClass"]:GetSelectedOption():ToString()
        selected_actor = all_characters[Selected_Spawn_NPC]
    else
        -- TODO this is a random NPC, not a random class
        _, selected_actor = table.random_key_value(all_characters)
    end
    --    local selected_actor = "/Game/Character/Blueprints/Willie_BP_DressUp.Willie_BP_DressUp_C"
    Logf("Spawning NPC [%s]\n", selected_actor)
    SpawnActorInFrontOfPlayer(selected_actor, { X = config.spawn_offset_x_npc, Y = 0.0, Z = 50.0 }, true)
    --    end
end

-- Object spawning applies scaling only intended for weapons,
-- just for fun, if the corresponding `ScaleObjects` flag is set
function SpawnSelectedObject()
    -- local Selected_Spawn_Object = cache.ui_spawn['Selected_Spawn_Object']:ToString()
    -- WeaponScaleMultiplier = cache.ui_spawn['HSTM_Slider_WeaponSize']
    -- WeaponScaleX = cache.ui_spawn['HSTM_Flag_ScaleX']
    -- WeaponScaleY = cache.ui_spawn['HSTM_Flag_ScaleY']
    -- WeaponScaleZ = cache.ui_spawn['HSTM_Flag_ScaleZ']

    -- ScaleObjects = cache.ui_spawn['HSTM_Flag_ScaleObjects']

    --Logf("Spawning object key [%s]\n", Selected_Spawn_Object)
    --    if not Selected_Spawn_Object == nil and not Selected_Spawn_Object == "" then
    --local selected_actor = all_objects[Selected_Spawn_Object]

    local _, selected_actor = table.random_key_value(all_objects)

    Logf("Spawning object [%s]\n", selected_actor)
    -- TODO the -60 in Z offset comes from player's camera elevation, I believe?
    local thisSpawnOffset = { X = config.spawn_offset_x_object, Y = 0.0, Z = -60.0 }
    if WeaponScaleMultiplier ~= 1.0 then
        local scale = {
            X = WeaponScaleX and WeaponScaleMultiplier or 1.0,
            Y = WeaponScaleY and WeaponScaleMultiplier or 1.0,
            Z = WeaponScaleZ and WeaponScaleMultiplier or 1.0
        }
        SpawnActorInFrontOfPlayer(selected_actor, thisSpawnOffset, nil, scale, nil, ScaleObjects)
    else
        SpawnActorInFrontOfPlayer(selected_actor, thisSpawnOffset)
    end
    --    end
end

-- Spawns the boss arena fence around the player's location
-- No bosses will spawn, only the fence. Player is the center, rotation is ignored (aligned with X/Y axes)
-- Scaling of the boss arena is ignored
function SpawnBossArena()
    local PlayerLocation = GetPlayerLocation()
    local SpawnLocation = PlayerLocation
    SpawnLocation.Z = 0
    local FullClassPath = "/Game/Blueprints/Spawner/BossFight_Arena_BP.BossFight_Arena_BP_C"
    Log("Spawning Boss Arena\n")
    local arena = SpawnActorByClassPath(FullClassPath, SpawnLocation)
end

------------------------------------------------------------------------------
-- All the functions that load spawnable items ignore the ones starting with [BAD]
-- used to mark those that are not useful (not visible, etc.)
------------------------------------------------------------------------------
function PopulateArmorComboBox()
    local ComboBox_Armor = HSTM_UI_ALT_HUD_Objects["ComboBox_Armor"]
    if ComboBox_Armor and ComboBox_Armor:IsValid() then
        ComboBox_Armor:ClearOptions()
        local file = io.open("ue4ss\\Mods\\HalfSwordTrainerMod\\data\\all_armor.txt", "r");
        for line in file:lines() do
            if not line:starts_with('[BAD]') and not line:match("^%s*#") and not line:match("^%s*$") then
                local fkey = ExtractHumanReadableNameShorter(line)
                all_armor[fkey] = line
                --Logf("%s: %s\n", fkey, line)
                ComboBox_Armor:AddOption(fkey)
            end
        end
        ComboBox_Armor:SetSelectedIndex(0)
    else
        Log("ComboBox_Armor is not valid\n")
    end
end

function PopulateWeaponComboBox()
    local ComboBox_Weapon = HSTM_UI_ALT_HUD_Objects["ComboBox_Weapon"]
    if ComboBox_Weapon and ComboBox_Weapon:IsValid() then
        ComboBox_Weapon:ClearOptions()

        local file = io.open("ue4ss\\Mods\\HalfSwordTrainerMod\\data\\all_weapons.txt", "r");
        for line in file:lines() do
            if not line:starts_with('[BAD]') and not line:match("^%s*#") and not line:match("^%s*$") then
                local fkey = ExtractHumanReadableNameShorter(line)
                all_weapons[fkey] = line
                --Logf("%s: %s\n", fkey, line)
                ComboBox_Weapon:AddOption(fkey)
            end
        end
        ComboBox_Weapon:SetSelectedIndex(0)
    else
        Log("ComboBox_Weapon is not valid\n")
    end
end

function PopulateNPCComboBox()
    local ComboBox_NPC = HSTM_UI_ALT_HUD_Objects["ComboBox_NPCClass"]
    if ComboBox_NPC and ComboBox_NPC:IsValid() then
        ComboBox_NPC:ClearOptions()

        local file = io.open("ue4ss\\Mods\\HalfSwordTrainerMod\\data\\all_characters.txt", "r");
        for line in file:lines() do
            if not line:starts_with('[BAD]') and not line:match("^%s*#") and not line:match("^%s*$") then
                local fkey = ExtractHumanReadableNameShorter(line)
                all_characters[fkey] = line
                ComboBox_NPC:AddOption(fkey)
            end
        end
        ComboBox_NPC:SetSelectedIndex(0)
    else
        Log("ComboBox_NPC is not valid\n")
    end
end

function PopulateNPCTeamComboBox()
    --local ComboBox_NPC_Team = cache.ui_spawn['ComboBox_NPC_Team']
    local ComboBox_NPC_Team = HSTM_UI_ALT_HUD_Objects["ComboBox_NPCTeam"]

    ComboBox_NPC_Team:ClearOptions()

    for TeamIndex = 0, maxPlayerTeam do
        ComboBox_NPC_Team:AddOption(tostring(TeamIndex))
    end
    ComboBox_NPC_Team:SetSelectedIndex(0)
end

function PopulateObjectComboBox()
    -- local ComboBox_Object = cache.ui_spawn['ComboBox_Object']
    -- ComboBox_Object:ClearOptions()

    local file = io.open("ue4ss\\Mods\\HalfSwordTrainerMod\\data\\all_objects.txt", "r");
    for line in file:lines() do
        if not line:starts_with('[BAD]') and not line:match("^%s*#") and not line:match("^%s*$") then
            local fkey = ExtractHumanReadableNameShorter(line)
            all_objects[fkey] = line
            -- ComboBox_Object:AddOption(fkey)
        end
    end
    -- ComboBox_Object:SetSelectedIndex(0)
end

-- The function takes the final part of the class name, but without the _C
function ExtractHumanReadableName(BPFullClassName)
    local hname = string.match(BPFullClassName, "/([%w_]+)%.[%w_]+$")
    return hname
end

-- This attempts to clean up the item name even further by removing common prefixes
function ExtractHumanReadableNameShorter(BPFullClassName)
    local hname = ExtractHumanReadableName(BPFullClassName)
    -- this is a stupid replacement, the order matters as one filter may contain the other
    local filters = {
        "BP_Weapon_Improv_",
        "BP_Weapon_Tool_",
        "ModularWeaponBP_",
        "BP_Armor_",
        "BP_Container_",
        "BM_Prop_Furniture_",
        "BP_Prop_Furniture_",
        "BP_Prop_",
    }

    for _, filter in ipairs(filters) do
        i, j = string.find(hname, filter)
        if i ~= nil then
            hname = string.sub(hname, j + 1)
        end
    end

    return hname
end

------------------------------------------------------------------------------
function ToggleCrosshair()
    local crosshair = cache.ui_game_hud['Aim']
    if crosshair and crosshair:IsValid() then
        CrosshairVisible = crosshair:GetVisibility() == Visibility_VISIBLE and true or false
        if CrosshairVisible then
            crosshair:SetVisibility(Visibility_HIDDEN)
            CrosshairVisible = false
        else
            crosshair:SetVisibility(Visibility_VISIBLE)
            CrosshairVisible = true
        end
    end
end

------------------------------------------------------------------------------
-- TODO fix this and use it to transition between normal and slomo
-- TODO customize the slowmo factor in the timeline float curves
function ToggleClassicSlowMotion()
    local worldsettings = cache.worldsettings
    local player = GetActivePlayer()
    player['Slomo Timeline']['SetTimelineLength'](1.0)
    SlowMotionEnabled = not SlowMotionEnabled
    if SlowMotionEnabled then
        player['Slomo Timeline']['PlayFromStart']()
    else
        player['Slomo Timeline']['ReverseFromEnd']()
    end
    if ModUIHUDVisible then
        formatHUDTextBox("TextBox_GameSpeed", GameSpeed, tostring(SlowMotionEnabled))
    end
end

-- This is our attempt at chaning the game speed instantly
function ToggleSlowMotion()
    local worldsettings = cache.worldsettings
    SlowMotionEnabled = not SlowMotionEnabled
    if SlowMotionEnabled then
        GameSpeed = SloMoGameSpeed
    else
        GameSpeed = DefaultGameSpeed
    end
    worldsettings['TimeDilation'] = GameSpeed
    if ModUIHUDVisible then
        formatHUDTextBox("TextBox_GameSpeed", GameSpeed, tostring(SlowMotionEnabled))
    end
end

-- Game goes faster
function IncreaseGameSpeed()
    -- 5x speed is already too prone to crashes
    if SloMoGameSpeed < DefaultGameSpeed * 5 then
        SloMoGameSpeed = SloMoGameSpeed + GameSpeedDelta
    end
    -- We only update the slowmo factor on screen if we are in slowmo
    -- TODO should we update it always to help players prepare their favourite slowmo factor in advance?
    if SlowMotionEnabled then
        local worldsettings = cache.worldsettings
        GameSpeed = SloMoGameSpeed
        worldsettings['TimeDilation'] = GameSpeed
        if ModUIHUDVisible then
            formatHUDTextBox("TextBox_GameSpeed", GameSpeed, tostring(SlowMotionEnabled))
        end
    end
end

-- Game goes slower
function DecreaseGameSpeed()
    if SloMoGameSpeed > GameSpeedDelta then
        SloMoGameSpeed = SloMoGameSpeed - GameSpeedDelta
    end
    -- We only update the slowmo factor on screen if we are in slowmo
    -- TODO should we update it always to help players prepare their favourite slowmo factor in advance?
    if SlowMotionEnabled then
        local worldsettings = cache.worldsettings
        GameSpeed = SloMoGameSpeed
        worldsettings['TimeDilation'] = GameSpeed
        if ModUIHUDVisible then
            formatHUDTextBox("TextBox_GameSpeed", GameSpeed, tostring(SlowMotionEnabled))
        end
    end
end

------------------------------------------------------------------------------
-- Try to have a cooldown between jumps
local lastJumpTimestamp = -1
-- The jump cooldown/recharge delay has been selected to avoid flying into the sky
local deltaJumpCooldown = 1.0
-- The standard UE Jump() method does nothing in Half Sword due to customizations
-- player:Jump()
-- so we have to add impulse ourselves
function PlayerJump()
    local forceJump = true

    local curJumpTimestamp = os.clock()
    local delta = curJumpTimestamp - lastJumpTimestamp
    -- Logf("TS = %f, LJTS = %f, delta = %f\n", curJumpTimestamp, lastJumpTimestamp, delta)
    local player = GetActivePlayer()
    local mesh = player['Mesh']

    if player['Fallen'] and not forceJump then
        -- TODO what if the player is laying down? Currently we do a small boost just in case
        local jumpImpulse = config.jump_impulse_fallen --* GameSpeed
        mesh:AddImpulse({ X = 0.0, Y = 0.0, Z = jumpImpulse }, FName("None"), true)
    else
        -- Only jump if the last jump happened long enough ago
        if delta >= deltaJumpCooldown or forceJump then
            -- Update last successful jump timestamp
            lastJumpTimestamp = curJumpTimestamp
            -- The jump impulse value has been selected to jump high enough for a table or boss fence
            local jumpImpulse = config.jump_impulse --* GameSpeed
            mesh:AddImpulse({ X = 0.0, Y = 0.0, Z = jumpImpulse }, FName("None"), true)
        end
    end
end

------------------------------------------------------------------------------
local DASH_FORWARD = 0
local DASH_BACK = 1
local DASH_LEFT = 2
local DASH_RIGHT = 4
local lastDashTimestamp = -1
local deltaDashCooldown = 1.0
-- The dash moves the player horizontally in the selected direction
-- The dash directions cannot be combined (no diagonals!)
function PlayerDash(direction)
    local forceDash = true

    local curDashTimestamp = os.clock()
    local delta = curDashTimestamp - lastDashTimestamp
    -- Logf("TS = %f, LJTS = %f, delta = %f\n", curJumpTimestamp, lastDashTimestamp, delta)
    local player = GetActivePlayer()
    local PlayerRotation = GetPlayerViewRotation()
    local mesh = player['Mesh']

    local angles = { [DASH_FORWARD] = 0.0, [DASH_BACK] = 2.0 * math.pi, [DASH_LEFT] = -math.pi, [DASH_RIGHT] = math.pi }
    -- The liftoff angles for the dash compensate for the ground friction and legs grappling the ground, hopefully
    local liftoffAnglesDeg = { [DASH_FORWARD] = 15.0, [DASH_BACK] = 15.0, [DASH_LEFT] = 30.0, [DASH_RIGHT] = 30.0 }
    -- The dash forces have been tuned to provide a decent movement while not tripping the player (hopefully)
    local dashForces = {
        [DASH_FORWARD] = config.dash_forward_impulse,
        [DASH_BACK] = config.dash_back_impulse,
        [DASH_LEFT] = config.dash_left_impulse,
        [DASH_RIGHT] = config.dash_right_impulse
    }

    local direction_rotator = maf.rotation.fromAngleAxis(
        angles[direction] / 2.0,
        0.0,
        0.0,
        1.0
    )

    -- We only apply the horizonal, XY-plane-bound view direction (Yaw)
    local viewRotator = maf.rotation.fromAngleAxis(
        math.rad(PlayerRotation.Yaw),
        0.0,
        0.0,
        1.0
    )

    local liftoffRotator = maf.rotation.fromAngleAxis(
        -math.rad(liftoffAnglesDeg[direction]),
        0.0,
        1.0,
        0.0
    )

    if player['Fallen'] and not forceDash then
        -- TODO what if the player is laying down? Currently we do a small boost just in case
        local dashImpulse = 1000.0 --* GameSpeed
        local dashImpulseVector = maf.vec3(dashImpulse, 0.0, 0.0)

        dashImpulseVector:rotate(liftoffRotator)
        dashImpulseVector:rotate(viewRotator)
        dashImpulseVector:rotate(direction_rotator)
        local dashVector = maf2vec(dashImpulseVector)

        mesh:AddImpulse(dashVector, FName("None"), true)
    else
        -- Only dash if the last dash happened long enough ago
        if forceDash or delta >= deltaDashCooldown then
            -- Update last successful dash timestamp
            lastDashTimestamp = curDashTimestamp
            local dashImpulse = dashForces[direction] --* GameSpeed
            local dashImpulseVector = maf.vec3(dashImpulse, 0.0, 0.0)

            dashImpulseVector:rotate(liftoffRotator)
            dashImpulseVector:rotate(viewRotator)
            dashImpulseVector:rotate(direction_rotator)
            local dashVector = maf2vec(dashImpulseVector)

            mesh:AddImpulse(dashVector, FName("None"), true)
        end
    end
end

------------------------------------------------------------------------------
-- index of the projectile in the table, starts with 1 (because Lua)
local selectedProjectile = 1
-- these DEFAULT_* constants allow selecting items from the menu to be launched
local DEFAULT_PROJECTILE = "/CURRENTLY_SELECTED.CURRENTLY_SELECTED_DEFAULT"
local DEFAULT_NPC_PROJECTILE = "/CURRENTLY_SELECTED_NPC.CURRENTLY_SELECTED_NPC_DEFAULT"

-- The first and the last projectiles in this list are special cases that launch the currently selected weapon and NPC from the menus, respectively
local projectiles = {
    { DEFAULT_PROJECTILE,                                                                                            { X = 1.0, Y = 1.0, Z = 1.0 }, { Pitch = -90.0, Yaw = 0.0, Roll = 0.0 }, 1.00 },
    { "/Game/Assets/Weapons/Blueprints/Built_Weapons/Reforged/ModularWeaponBP_Spear_B.ModularWeaponBP_Spear_B_C",    { X = 0.5, Y = 0.5, Z = 0.5 }, { Pitch = -90.0, Yaw = 0.0, Roll = 0.0 }, 1.00 },
    { "/Game/Assets/Weapons/Blueprints/Built_Weapons/Tools/BP_Weapon_Tool_Pitchfork_A.BP_Weapon_Tool_Pitchfork_A_C", { X = 0.5, Y = 0.5, Z = 0.5 }, { Pitch = -90.0, Yaw = 0.0, Roll = 0.0 }, 1.50 },
    { "/Game/Assets/Weapons/Blueprints/Built_Weapons/ModularWeaponBP_Dagger.ModularWeaponBP_Dagger_C",               { X = 1.0, Y = 1.0, Z = 1.0 }, { Pitch = -90.0, Yaw = 0.0, Roll = 0.0 }, 0.50 },
    { "/Game/Assets/Weapons/Blueprints/Built_Weapons/Tools/BP_Weapon_Tool_Axe_C.BP_Weapon_Tool_Axe_C_C",             { X = 1.0, Y = 1.0, Z = 1.0 }, { Pitch = 0.0, Yaw = 180.0, Roll = 0.0 }, 0.50 },
    { "/Game/Assets/Weapons/Blueprints/Built_Weapons/Improvized/BP_Weapon_Improv_Stool.BP_Weapon_Improv_Stool_C",    { X = 1.0, Y = 1.0, Z = 1.0 }, { Pitch = -90.0, Yaw = 0.0, Roll = 0.0 }, 1.50 },
    { "/Game/Assets/Weapons/Blueprints/Built_Weapons/Shield_Buckler.Shield_Buckler_C",                               { X = 1.0, Y = 1.0, Z = 1.0 }, { Pitch = -90.0, Yaw = 0.0, Roll = 0.0 }, 1.50 },
    -- Not a good idea at the moment, NPCs spawn and hang for some time, so they don't fly at all
    --{ DEFAULT_NPC_PROJECTILE,                                                                                        { X = 1.0, Y = 1.0, Z = 1.0 }, { Pitch = 0.0, Yaw = 0.0, Roll = 0.0 },   5.00 },
}

-- The projectile shooting logic attempts to take into account various manual corrections
-- to try to not kill the player when spawning projectiles.
function ShootProjectile()
    local offset = { X = 40.0, Y = 0.0, Z = 0.0 }
    local baseImpulseVector = { X = 50.0, Y = 0.0, Z = 0.0 }
    local PlayerViewRotation = GetPlayerViewRotation()
    local PlayerLocation = GetPlayerLocation()

    local class, scale, baseRotation, forceMultiplier = table.unpack(projectiles[selectedProjectile])

    -- Allow to shoot a weapon from spawn menu, taking into account the scale
    if class == DEFAULT_PROJECTILE then
        -- ScaleObjects = cache.ui_spawn['HSTM_Flag_ScaleObjects']
        local selected_actor = nil
        if HSTM_UI_ALT_HUD_Objects["ComboBox_Weapon"] then
            local Selected_Spawn_Weapon = HSTM_UI_ALT_HUD_Objects["ComboBox_Weapon"]:GetSelectedOption():ToString()
            WeaponScaleMultiplier = HSTM_UI_ALT_HUD_Objects["ScaleSlider"]:GetValue()
            WeaponScaleX = HSTM_UI_ALT_HUD_Objects["ScaleXCheckBox"]:IsChecked()
            WeaponScaleY = HSTM_UI_ALT_HUD_Objects["ScaleYCheckBox"]:IsChecked()
            WeaponScaleZ = HSTM_UI_ALT_HUD_Objects["ScaleZCheckBox"]:IsChecked()
            WeaponScaleBladeOnly = HSTM_UI_ALT_HUD_Objects["ScaleBladeOnlyCheckBox"]:IsChecked()

            selected_actor = all_weapons[Selected_Spawn_Weapon]
        else
            _, selected_actor = table.random_key_value(all_weapons)
        end
        --Logf("Shooting custom weapon [%s]\n", selected_actor)

        -- Try to guess the correct rotation for various weapons
        if selected_actor:contains("Axe") then
            baseRotation = { Pitch = 0.0, Yaw = 180.0, Roll = 0.0 }
        elseif selected_actor:contains("Scythe") then
            baseRotation = { Pitch = 90.0, Yaw = 0.0, Roll = 0.0 }
            offset.X = offset.X + 120
        elseif selected_actor:contains("Pitchfork") then
            offset.X = offset.X + 20
        elseif selected_actor:contains("Sickle") then
            baseRotation = { Pitch = 0.0, Yaw = 180.0, Roll = 0.0 }
        elseif selected_actor:contains("Pavise") then
            offset.X = offset.X + 30
            baseRotation = { Pitch = 0.0, Yaw = 90.0, Roll = 90.0 }
        elseif selected_actor:contains("CandleStick") then
            -- Currently bugged
            offset.X = offset.X + 100
            baseRotation = { Pitch = -90.0, Yaw = 0.0, Roll = 0.0 }
        end

        if WeaponScaleMultiplier ~= 1.0 then
            scale = {
                X = WeaponScaleX and WeaponScaleMultiplier or 1.0,
                Y = WeaponScaleY and WeaponScaleMultiplier or 1.0,
                Z = WeaponScaleZ and WeaponScaleMultiplier or 1.0
            }
            if WeaponScaleMultiplier > 1.0 then
                -- When a long weapon spawns, it is the Z axis that is the longest
                -- Try to move the projectile away from the player to prevent sudden death
                -- If we only scale the blade, don't move, it should be safe
                if WeaponScaleZ and not WeaponScaleBladeOnly then
                    offset.X = offset.X * WeaponScaleMultiplier
                end
                -- Only scale up the force if the object is scaled across all axes
                if WeaponScaleX and WeaponScaleY and WeaponScaleZ then
                    forceMultiplier = forceMultiplier * WeaponScaleMultiplier
                end
            end
        else
            -- Just to be safer against longer weapons
            offset.X = offset.X + 10
        end
        class = selected_actor
    elseif class == DEFAULT_NPC_PROJECTILE then
        -- TODO fix combobox
        if HSTM_UI_ALT_HUD_Objects["SpawnFrozenNPCsCheckBox"] then
            SpawnFrozenNPCs = HSTM_UI_ALT_HUD_Objects["SpawnFrozenNPCsCheckBox"]:IsChecked()
            NPCTeam = tonumber(HSTM_UI_ALT_HUD_Objects["ComboBox_NPCTeam"]:GetSelectedOption():ToString())
        end
        -- TODO fix combobox
        --local Selected_Spawn_NPC = cache.ui_spawn['Selected_Spawn_NPC']:ToString()
        --local selected_actor = all_characters[Selected_Spawn_NPC]
        local selected_actor = "/Game/Character/Blueprints/Willie_BP.Willie_BP_C"
        class = selected_actor
    end

    -- General corrections
    if class:contains("Barrel") then
        offset.X = offset.X + 50
    elseif class:contains("BM_Prop_Furniture_Small_Bench_001") then
        offset.X = offset.X + 50
    elseif class:contains("BP_Prop_Furniture_Small_Table_001") then
        offset.X = offset.X + 150
    elseif class:contains("Willie") then
        offset.X = offset.X + 60
        offset.Z = -60
    end

    -- First locate the spawn point by rotating the offset by player camera yaw (around Z axis in UE), horizontal camera position
    local rotator = maf.rotation.fromAngleAxis(
        math.rad(PlayerViewRotation.Yaw),
        0.0, -- X
        0.0, -- Y
        1.0  -- Z
    )
    local DeltaLocation = vec2maf(offset)
    local rotatedDelta = DeltaLocation
    rotatedDelta:rotate(rotator)

    -- Add the displacement vector to player location with some Z-height adjustments
    local SpawnLocation = {
        X = PlayerLocation.X + rotatedDelta.x,
        Y = PlayerLocation.Y + rotatedDelta.y,
        Z = PlayerLocation.Z + 70 + rotatedDelta.z
    }

    -- Rotate the projectile along its yaw and pitch to address horizontal and vertical camera movement

    local SpawnRotation = {
        Pitch = math.fmod(baseRotation.Pitch + PlayerViewRotation.Pitch, 360.0),
        Yaw = math.fmod(baseRotation.Yaw + PlayerViewRotation.Yaw, 360.0),
        Roll = baseRotation.Roll,
    }

    local ImpulseRotation = vec2maf(baseImpulseVector)

    -- Prepare the projectile impulse vector: rotate it according to vertical camera movement
    local TargetRotator = maf.rotation.fromAngleAxis(
        -math.rad(PlayerViewRotation.Pitch),
        0.0, -- X
        1.0, -- Y
        0.0  -- Z
    )

    ImpulseRotation:rotate(TargetRotator)
    -- Then address the horizonal (Yaw) camera movement around Z-axis as done above for spawn location, same for impulse
    ImpulseRotation:rotate(rotator)

    local projectile = SpawnActorByClassPath(class, SpawnLocation, SpawnRotation, scale, WeaponScaleBladeOnly,
        ScaleObjects)
    -- Correct the spawned projectile rotation by the camera-specific angles
    projectile:K2_SetActorRotation(SpawnRotation, true)

    -- We don't compensate for game speed to make projectiles a bit stronger in slow-mo
    local impulseMaf = ImpulseRotation
    local impulse = impulseMaf * (forceMultiplier * config.projectile_base_force_multiplier)
    local impulseUE = maf2vec(impulse)
    -- Don't apply impulse immediately, give the player a chance to see the projectile
    ExecuteWithDelay(200, function()
        -- More dumb fixes to apply impulse to different components.
        -- We should probably be trying to find a StaticMesh inside instead of this.
        -- Ignoring mass is set to True for non-standard projectiles.
        if class:contains("_Prop_Furniture") then
            projectile['SM_Prop']:AddImpulse(impulseUE, FName("None"), true)
        elseif class:contains("Dest_Barrel") then
            projectile['RootComponent']:AddImpulse(impulseUE, FName("None"), true)
        elseif class:contains("BP_Prop_Barrel") then
            projectile['SM_Barrel']:AddImpulse(impulseUE, FName("None"), true)
        elseif class:contains("Willie") then
            projectile['Mesh']:AddImpulse(impulseUE, FName("None"), true)
        else
            projectile['BaseMesh']:AddImpulse(impulseUE, FName("None"), false)
        end
    end)
end

-- This is some truly horrible attempt to rotate through a list that I should be ashamed of
function ChangeProjectileNext()
    selectedProjectile = math.fmod(selectedProjectile, #projectiles) + 1
    HUD_CacheProjectile()
end

-- This, too, is not great but works
function ChangeProjectilePrev()
    selectedProjectile = math.fmod(#projectiles + selectedProjectile - 2, #projectiles) + 1
    HUD_CacheProjectile()
end

-- As the UI may not be on screen when we shoot the selected menu items, we try to cache them
function HUD_CacheProjectile()
    local class, _, _, _ = table.unpack(projectiles[selectedProjectile])
    local classname = class
    if class == DEFAULT_PROJECTILE then
        if not HSTM_UI_ALT_HUD_Objects["ComboBox_Weapon"] or not HSTM_UI_ALT_HUD_Objects["ComboBox_Weapon"]:IsValid() then
            ErrLogf("ComboBox_Weapon is not valid\n")
            return
        end
        local selectedWeapon = HSTM_UI_ALT_HUD_Objects["ComboBox_Weapon"]:GetSelectedOption():ToString()
        classname = all_weapons[selectedWeapon]
        -- elseif class == DEFAULT_NPC_PROJECTILE then
        --     local Selected_Spawn_NPC = cache.ui_spawn['Selected_Spawn_NPC']:ToString()
        --     classname = all_characters[Selected_Spawn_NPC]
    end
    local projectileShortName = ExtractHumanReadableNameShorter(classname)
    if class == DEFAULT_PROJECTILE then
        projectileShortName = projectileShortName .. " (menu)"
        -- elseif class == DEFAULT_NPC_PROJECTILE then
        --     projectileShortName = projectileShortName .. " (NPC menu)"
    end
    if ModUIHUDVisible then
        -- HSTM_UI_ALT_HUD_Objects["TextBox_Projectile"]:SetText(
        --     FText(
        --         HSTM_UI_ALT_HUD_TextBox_Names
        --         ["TextBox_Projectile"][2]
        --         :format(projectileShortName)
        --     )
        -- )
        formatHUDTextBox("TextBox_Projectile", projectileShortName)
    end
end

------------------------------------------------------------------------------
-- We check equality of non-static objects by their full names,
-- which includes the unique numbered name of an instance of a class (something like My_Object_C_123456789)
-- Horrible, but a bit better than using their address (UE4SS and Lua don't help there)
function UEAreObjectsEqual(a, b)
    local aa = tostring(a:GetFullName())
    local bb = tostring(b:GetFullName())
    -- Logf("[%s] == [%s]?\n", aa, bb)
    return aa == bb
end

------------------------------------------------------------------------------
-- TODO this is unused, the idea was to see if the map's player willie is the one we are actually controlling or not
function IsPossessing()
    local player = cache.map[cache.map_player_name]
    local playerController = myGetPlayerController()
    local possessedPawn = playerController['Pawn']
    return UEAreObjectsEqual(player, possessedPawn)
end

function IsThisNPCPossessed(NPC)
    local playerController = myGetPlayerController()
    local possessedPawn = playerController['Pawn']
    return UEAreObjectsEqual(NPC, possessedPawn)
end

-- Possession is making the PlayerController possess the Pawn of an NPC
-- Possession is buggy and may break things
-- An NPC with a weapon may remain buggy when you possess it:
-- * not allowing you to swing a weapon with the NPC body
-- * auto-picking up the weapon from the ground
-- etc.
function PossessNearestNPC()
    local currentLocation = GetPlayerLocation()
    local currentPawn = GetActivePlayer()
    local playerController = myGetPlayerController()

    if OGWillie == nil then
        -- cache the original Willie so that we can go back to it when repossessing
        OGWillie = cache.map[cache.map_player_name]
        Logf("OGWillie: %s\n", OGWillie:GetFullName())
    end

    local AllNPCs = {}
    ExecuteForAllNPCs(function(NPC)
        -- Don't try to re-possess the current, already possessed NPC
        if UEAreObjectsEqual(NPC, currentPawn) then
            -- TODO process a currently possessed NPC or not?
        else
            table.insert(AllNPCs, { Pawn = NPC, Location = NPC:K2_GetActorLocation() })
        end
    end)
    -- Totally arbitrary large value, in fact a couple tiles' worth of units should be enough but YOLO
    local minDelta = 10e23
    local closestNPCidx = -1
    for idx, NPC in ipairs(AllNPCs) do
        local thisLocation = NPC.Location
        local delta = maf.vec3.distance(vec2maf(currentLocation), vec2maf(thisLocation))
        if delta < minDelta then
            minDelta = delta
            closestNPCidx = idx
        end
    end
    if closestNPCidx ~= -1 then
        local pawnToPossess = AllNPCs[closestNPCidx].Pawn
        ResurrectionWasRequested = true
        Logf("Possessing NPC: %s\n", pawnToPossess:GetFullName())
        playerController:Possess(pawnToPossess)
        -- TODO fix the player X and Y and map's link to the player character
        -- currently we use the stored one to be able to repossess it, but game progression is broken if you keep the new character
        -- we should probably fix it
        cache.map[cache.map_player_name] = pawnToPossess
    else
        ErrLogf("Could not find the closest NPC\n")
    end
    -- Not sure why we are doing this
    SetAllPlayerOneHUDVisibility(Visibility_HIDDEN)
end

-- Re-possession breaks AI control of previously possessed NPCs
function RepossessPlayer()
    -- ExecuteForAllNPCs(function(NPC)
    --     NPC['Controller']:UnPossess()
    -- end)
    local playerController = myGetPlayerController()
    ResurrectionWasRequested = true
    if OGWillie ~= nil and OGWillie:IsValid() then
        Logf("Possessing player Willie back: %s\n", OGWillie:GetFullName())
        playerController:Possess(OGWillie)
        cache.map[cache.map_player_name] = OGWillie
        SetAllPlayerOneHUDVisibility(Visibility_VISIBLE)
    else
        Logf("[ERROR]: Cannot repossess the original Willie, aborting.\n")
    end
end

------------------------------------------------------------------------------
-- Resurrection may not guarantee a complete revival, doesn't seem to work well for NPCs
-- Being decapitated or sliced in half does not allow resurrection
function ResurrectWillie(player, forcePlayerController)
    player['DED'] = false
    player['Consciousness'] = 100.0
    player['All Body Tonus'] = 100.0
    player['Stamina'] = 100.0

    player['Health'] = 100.0

    player['Head Health'] = 100.0
    player['Neck Health'] = 100.0
    player['Body Health'] = 100.0
    player['Arm_R Health'] = 100.0
    player['Arm_L Health'] = 100.0
    player['Leg_R Health'] = 100.0
    player['Leg_L Health'] = 100.0

    player['Pain'] = 0.0
    player['Bleeding'] = 0.0

    -- Not sure if those functions do anything but let's call them just in case
    --player['Reset Dismemberment']()
    player['Reset Sustained Damage']()
    if forcePlayerController then
        -- Possess this willie with a PlayerController instead of the last controller
        local playerController = myGetPlayerController()
        playerController:Possess(player)
    else
        -- Just reuse the last controller.
        local controller = player['Controller']
        if controller and controller:IsValid() then
            controller:Possess(player)
        else
            ErrLogf("Cannot resurrect Willie, invalid controller\n")
        end
    end
end

------------------------------------------------------------------------------
function ResurrectPlayer()
    -- TODO handle detecting and bypassing the death screen
    Logf("Resurrecting player\n")
    ResurrectionWasRequested = true
    local player = GetActivePlayer()
    ResurrectWillie(player, true)
end

function ResurrectPlayerByController()
    -- TODO handle detecting and bypassing the death screen
    Logf("Resurrecting player using default PlayerController\n")
    local PlayerController = myGetPlayerController()
    local player = PlayerController['Pawn']
    ResurrectionWasRequested = true
    ResurrectWillie(player, true)
end

------------------------------------------------------------------------------
-- This has to be called when the DED screen/knock-out is triggered, not before
function RemovePlayerOneDeathScreen()
    -- We don't use the caching of those objects just in case
    local HUD = FindFirstOf("UI_HUD_C")
    if HUD and HUD:IsValid() then
        -- HUD:RemoveFromViewport()
        -- It is better to hide the black death screen on the HUD
        -- Damage HUD and crosshair are still visible
        HUD['Black']:SetVisibility(Visibility_HIDDEN)
        HUD['Vignette']:SetVisibility(Visibility_HIDDEN)
        HUD['Vignette_WakeUp']:SetVisibility(Visibility_HIDDEN)
        HUD['Vignette_Pain']:SetVisibility(Visibility_HIDDEN)
        Logf("Removing HUD Black screen\n")
    end
    local DED = FindFirstOf("UI_DED_C")
    if DED and DED:IsValid() then
        -- It is better to remove the DED screen as it blocks the menu UI with it (cannot restart otherwise)
        DED:RemoveFromViewport()
        -- DED:SetVisibility(Visibility_HIDDEN)
        Logf("Removing Death screen\n")
    end
    local KO = FindFirstOf("UI_KO_C")
    if KO and KO:IsValid() then
        KO:RemoveFromViewport()
        Logf("Removing KO screen\n")
    end
    if GetGameplayStatics():IsGamePaused(GetWorldContextObject()) then
        GetGameplayStatics():SetGamePaused(GetWorldContextObject(), false)
        Logf("Unpausing game after death screen\n")
    end
end

-- This is the game's standard original HUD, the blood splashes on screen that indicate damage to player
function SetAllPlayerOneHUDVisibility(NewVisibility)
    -- We don't use the caching of those objects just in case
    local HUD = FindFirstOf("UI_HUD_C")
    if HUD and HUD:IsValid() then
        -- crosshair
        HUD['Aim']:SetVisibility(NewVisibility)
        -- damage HUD
        HUD['ArmLDmg']:SetVisibility(NewVisibility)
        HUD['ArmRDmg']:SetVisibility(NewVisibility)
        HUD['HeadDmg']:SetVisibility(NewVisibility)
        HUD['HPDmg1']:SetVisibility(NewVisibility)
        HUD['HPDmg2']:SetVisibility(NewVisibility)
        HUD['HPDmg3']:SetVisibility(NewVisibility)
        HUD['LegLDmg']:SetVisibility(NewVisibility)
        HUD['LegRDmg']:SetVisibility(NewVisibility)
        -- shock/death vignette
        HUD['Black']:SetVisibility(NewVisibility)
        HUD['Vignette']:SetVisibility(NewVisibility)
        HUD['Vignette_WakeUp']:SetVisibility(NewVisibility)
        HUD['Vignette_Pain']:SetVisibility(NewVisibility)

        Logf("Toggling visibility for Player one HUD\n")
    end
end

-- function RemoveUIHints()
--     local hint1 = FindFirstOf("UI_Hint_Move_C")
--     local hint2 = FindFirstOf("UI_Hint_Interact_C")
--     if hint1 and hint2 then
--         hint1:RemoveFromViewport()
--         hint2:RemoveFromViewport()
--         Logf("Removing hints UI\n")
--     end
-- end

------------------------------------------------------------------------------
-- This is intended to be used mostly to get free camera from PhotoMode
-- But can be used to unpause from death screen as well
-- The function is trying to be smart and hide the HUD with blood when in free camera mode, and bring it back when you exit it from PhotoMode.
-- Note that if you just exit the photomode with ESC, the HUD will probably stay disabled.
function ToggleGamePaused()
    local UI_PhotoMode_C = FindFirstOf("UI_PhotoMode_C")
    if GetGameplayStatics():IsGamePaused(GetWorldContextObject()) then
        if UI_PhotoMode_C ~= nil and UI_PhotoMode_C:IsValid() and UI_PhotoMode_C['bUsingFreeCamera'] == true then
            -- Let the camera fly further away, default is 1000
            UI_PhotoMode_C['FreeCameraActor']['MaximumDistance'] = 5000
            SetAllPlayerOneHUDVisibility(Visibility_HIDDEN)
        end
        GetGameplayStatics():SetGamePaused(GetWorldContextObject(), false)
        Logf("Unpausing game\n")
    else
        if UI_PhotoMode_C ~= nil and UI_PhotoMode_C:IsValid() and UI_PhotoMode_C['bUsingFreeCamera'] == true then
            SetAllPlayerOneHUDVisibility(Visibility_VISIBLE)
        end
        GetGameplayStatics():SetGamePaused(GetWorldContextObject(), true)
        Logf("Pausing game\n")
    end
end

------------------------------------------------------------------------------
-- The code below is commented as a better free camera implementation above can be enabled straight from PhotoMode by unpausing the game
--
-- local freeCameraMode = false
-- -- set freezePlayerFreeCamera to false if you need the player to move with free camera (e.g. to keep fighting)
-- local freezePlayerFreeCamera = true
-- -- This attempts to reuse the built-in photo mode's "free camera" and gives control to the player in game
-- -- The player will be frozen or not, depending on freezePlayerFreeCamera
-- function ToggleFreeCamera()
--     local UI_PhotoMode_C = FindFirstOf("UI_PhotoMode_C")
--     local controller = myGetPlayerController()
--     local player = GetActivePlayer()
--     if UI_PhotoMode_C ~= nil then
--         if freeCameraMode == false then
--             -- enable Free Camera
--             UI_PhotoMode_C:ChangeFreeCameraFOV(100)
--             UI_PhotoMode_C:OpenFreeCamera()
--             freeCameraMode = true
--             -- prevent the player character from moving
--             if freezePlayerFreeCamera then
--                 player:DisableInput(controller)
--             end
--             -- hide the on-screen pain/blood UI
--             SetAllPlayerOneHUDVisibility(Visibility_HIDDEN)
--         else
--             -- disable Free Camera
--             UI_PhotoMode_C:CloseFreeCamera()
--             freeCameraMode = false
--             -- re-enable the player character movement
--             if freezePlayerFreeCamera then
--                 player:EnableInput(controller)
--             end
--             -- restore the on-screen pain/blood UI
--             SetAllPlayerOneHUDVisibility(Visibility_VISIBLE)
--         end
--     end
-- end
------------------------------------------------------------------------------
-- The code below is based on UE4SS LineTraceMod
-- It uses UKismetSystemLibrary::LineTraceSingle() to find the actor under cursor (center of screen)
-- No actual line is ever drawn on screen as the game is in a shipping build, not debug one
function TraceObjectFromPlayerCamera()
    local PlayerController = myGetPlayerController()
    local PlayerPawn = PlayerController.Pawn
    local CameraManager = PlayerController.PlayerCameraManager
    local StartVector = CameraManager:GetCameraLocation()
    local AddValue = GetKismetMathLibrary():Multiply_VectorInt(
        GetKismetMathLibrary():GetForwardVector(CameraManager:GetCameraRotation()), 50000.0)
    local EndVector = GetKismetMathLibrary():Add_VectorVector(StartVector, AddValue)
    local TraceColor = {
        ["R"] = 0,
        ["G"] = 0,
        ["B"] = 0,
        ["A"] = 0,
    }
    local TraceHitColor = TraceColor
    local EDrawDebugTrace_Type_None = 0
    local ETraceTypeQuery_TraceTypeQuery1 = 0
    local ActorsToIgnore = {}
    local HitResult = {}
    local WasHit = GetKismetSystemLibrary():LineTraceSingle(
        PlayerPawn,
        StartVector,
        EndVector,
        ETraceTypeQuery_TraceTypeQuery1,
        false,
        ActorsToIgnore,
        EDrawDebugTrace_Type_None,
        HitResult,
        true,
        TraceColor,
        TraceHitColor,
        0.0
    )

    if WasHit then
        HitActor = HitResult.HitObjectHandle.Actor:Get()
        return HitActor
    else
        return nil
    end
end

-- We find the actor under cursor (center of screen) and despawn it with K2_DestroyActor
function DespawnObjectFromPlayerCamera()
    local actor = TraceObjectFromPlayerCamera()
    if actor then
        local actorName = actor:GetFullName()
        -- Refuse to despawn the floor or the player for obvious reasons
        if not UEAreObjectsEqual(actor, GetActivePlayer()) and not actorName:contains("BP_Floor_Tile") then
            Logf("Despawning actor: %s\n", actor:GetFullName())
            actor:K2_DestroyActor()
        end
    end
end

-- Attempt to command all the NPCs on the same team to move to the player
-- TODO should we do something about Team 0 which are hostile to each other?
function GoToMe()
    ExecuteForAllNPCs(function(NPC)
        if NPC and NPC:IsValid() and NPC['Team Int'] == PlayerTeam then
            local npcController = NPC['Controller']
            if npcController and npcController:IsValid() then
                npcController['MoveToActor'](npcController,
                    GetActivePlayer(),
                    200.0,
                    true,
                    true,
                    true,
                    nil,
                    true
                )
            end
        end
    end)
end

-- We find the actor under cursor (center of screen) and try to scale it
function ScaleObjectUnderCamera()
    WeaponScaleMultiplier = cache.ui_spawn['HSTM_Slider_WeaponSize']
    WeaponScaleX = cache.ui_spawn['HSTM_Flag_ScaleX']
    WeaponScaleY = cache.ui_spawn['HSTM_Flag_ScaleY']
    WeaponScaleZ = cache.ui_spawn['HSTM_Flag_ScaleZ']
    WeaponScaleBladeOnly = cache.ui_spawn['HSTM_Flag_ScaleBladeOnly']

    if WeaponScaleMultiplier ~= 1.0 then
        local scale = {
            X = WeaponScaleX and WeaponScaleMultiplier or 1.0,
            Y = WeaponScaleY and WeaponScaleMultiplier or 1.0,
            Z = WeaponScaleZ and WeaponScaleMultiplier or 1.0
        }
        local Actor = TraceObjectFromPlayerCamera()
        if Actor then
            local actorName = Actor:GetFullName()
            -- Refuse to scale the floor or the player for obvious reasons
            if not UEAreObjectsEqual(Actor, GetActivePlayer()) and not actorName:contains("BP_Floor_Tile") then
                Logf("Scaling actor: %s to %s\n", actorName, UEVecToStr(scale))
                -- We apply hacks to find the correct mesh/component to scale if possible
                if actorName:contains("/Built_Weapons/ModularWeaponBP") then
                    if WeaponScaleBladeOnly then
                        -- Actually not sure which scale we should set, relative or world?
                        Actor['head']:SetRelativeScale3D(scale)
                    else
                        Actor:SetActorScale3D(scale)
                    end
                elseif actorName:contains("_Prop_Furniture") then
                    Actor['SM_Prop']:SetRelativeScale3D(scale)
                elseif actorName:contains("Dest_Barrel") then
                    Actor['RootComponent']:SetRelativeScale3D(scale)
                elseif actorName:contains("BP_Prop_Barrel") then
                    Actor['SM_Barrel']:SetRelativeScale3D(scale)
                elseif actorName:contains("BP_Container") then
                    Actor['Box']:SetRelativeScale3D(scale)
                else
                    Actor:SetActorScale3D(scale)
                end
            end
        end
    end
end

------------------------------------------------------------------------------
-- Calls the built-in function to save the current loadout on the player
function SaveLoadout()
    local player = GetActivePlayer()
    Logf("Saving loadout for player: %s\n", player:GetFullName())
    player['Save Loadout']()
    Logf("Loadout saved.\n")
end

------------------------------------------------------------------------------
-- This function is called when the mod is loaded at the end of this file
function AllHooks()
    CriticalHooks()
    AllCustomEventHooks()
    AllKeybindHooks()
end

------------------------------------------------------------------------------
function CriticalHooks()
    ------------------------------------------------------------------------------
    -- We hook the restart event, which somehow fires 2/3 times per restart
    -- We take care of that in the InitMyMod() function above
    RegisterHook("/Script/Engine.PlayerController:ClientRestart", DelayInitMod)
    -- RegisterLoadMapPostHook(function(Engine, World)
    --     Logf("UEngine::LoadMap() triggered with RegisterLoadMapPostHook\n")
    -- end)

    -- This may be a better trigger for mod init than the above ClientRestart hook as the menu is also on a loaded map
    -- This still gets called two times by the game
    RegisterInitGameStatePostHook(function(Context)
        Logf("AGameModeBase::InitGameState() triggered with RegisterInitGameStatePostHook\n")
        -- We try to find the real game start event amond multiple spurious invocations of ClientRestart hook and this hook
        InitGameStateHookCount = InitGameStateHookCount + 1
        -- After InitGameStateHookCount == 1, we can reset the ClientRestart counter, so we assume the last timestamp never happened
        lastInitTimestamp = -1
        --        RegisterHook("/Game/Blueprints/Utility/BP_HalfSwordGameMode.BP_HalfSwordGameMode_C:ReceiveBeginPlay", function()
        --            Logf("/Game/Blueprints/Utility/BP_HalfSwordGameMode.BP_HalfSwordGameMode_C:ReceiveBeginPlay triggered\n")
        --        end)
    end)

    Log("Critical hooks registered\n")
end

------------------------------------------------------------------------------
function DangerousHooks()
    ------------------------------------------------------------------------------
    -- We hook the creation of Character class objects, those are NPCs usually
    -- WARN for some reason, this crashes the game on restart
    -- TODO intercept and set CustomTimeDilation if we want to freeze all NPCs
    -- Maybe it is the Lua GC doing this to a table of actors somehow?
    -- NotifyOnNewObject("/Script/Engine.Character", function(ConstructedObject)
    --     if intercepted_actors then
    --         table.insert(intercepted_actors, ConstructedObject)
    --     end
    --     Logf("Hook Character spawned: %s\n", ConstructedObject:GetFullName())
    -- end)
    ------------------------------------------------------------------------------
    -- Damage hooks are commented for now, not sure which is the correct one to intercept and how to interpret the variables
    -- TODO Needs a proper investigation
    -- RegisterHook("/Script/Engine.Actor:ReceiveAnyDamage", function(self, Damage, DamageType, InstigatedBy, DamageCauser)
    --     Logf("Damage %f\n", Damage:get())
    -- end)
    -- RegisterHook("/Game/Character/Blueprints/Willie_BP.Willie_BP_C:Get Damage", function(self,
    --         Impulse,Velocity,Location,Normal,bone,Raw_Damage,Cutting_Power,Inside,Damaged_Mesh,Dism_Blunt,Lower_Threshold,Shockwave,Hit_By_Component,Damage_Out
    --     )
    --     Logf("Damage %f %f\n", Raw_Damage:get(), Damage_Out:get())
    -- end)
end

------------------------------------------------------------------------------
-- Trying to hook the button click functions of the HSTM_UI blueprint:
-- * HSTM_SpawnArmor
-- * HSTM_SpawnWeapon
-- * HSTM_SpawnNPC
-- * HSTM_SpawnObject
-- * HSTM_UndoSpawn
-- * HSTM_ToggleSlowMotion
-- * HSTM_KillAllNPCs
-- * HSTM_FreezeAllNPCs
-- Those are defined as custom functions in the spawn widget of the HSTM_UI blueprint itself.
function AllCustomEventHooks()
    RegisterCustomEvent("HSTM_SpawnArmor", function(ParamContext, ParamMessage)
        SpawnSelectedArmor()
    end)

    RegisterCustomEvent("HSTM_SpawnWeapon", function(ParamContext, ParamMessage)
        SpawnSelectedWeapon()
    end)

    RegisterCustomEvent("HSTM_SpawnNPC", function(ParamContext, ParamMessage)
        SpawnSelectedNPC()
    end)

    RegisterCustomEvent("HSTM_SpawnObject", function(ParamContext, ParamMessage)
        SpawnSelectedObject()
    end)

    -- Buttons below
    RegisterCustomEvent("HSTM_UndoSpawn", function(ParamContext, ParamMessage)
        UndoLastSpawn()
    end)

    RegisterCustomEvent("HSTM_DespawnNPCs", function(ParamContext, ParamMessage)
        UndoLastSpawn()
    end)

    RegisterCustomEvent("HSTM_ToggleSlowMotion", function(ParamContext, ParamMessage)
        ToggleSlowMotion()
    end)

    RegisterCustomEvent("HSTM_KillAllNPCs", function(ParamContext, ParamMessage)
        KillAllNPCs()
    end)

    RegisterCustomEvent("HSTM_FreezeAllNPCs", function(ParamContext, ParamMessage)
        FreezeAllNPCs()
    end)

    Log("Custom events registered\n")
end

------------------------------------------------------------------------------
-- This is a wrapper taking care of both UE4SS provided overloads while also allowing empty modifier table
function RegisterCustomKeyBind(key, modifiers, callback)
    if modifiers ~= nil and #modifiers > 0 then
        RegisterKeyBind(key, modifiers, callback)
    else
        RegisterKeyBind(key, callback)
    end
end

------------------------------------------------------------------------------
-- The user-facing key bindings are below.
-- Most are wrapped in a ExecuteInGameThread() call to not crash,
-- the others have that wrapper inside them around the critical sections like spawning
-- Some keybinds have to be specified with Ctrl and/or Shift modifiers,
-- otherwise they won't work while sprinting or crouching
function AllKeybindHooks()
    -- Load keybinds from config
    LoadKeybinds()

    -- Register each keybind
    for action, binding in pairs(keybinds) do
        local key = Key[binding[1]]
        local modifiers = {}
        for _, modifier in ipairs(binding[2]) do
            table.insert(modifiers, ModifierKey[modifier])
        end

        -- Handle each action
        if action == "toggle_invulnerability" then
            RegisterCustomKeyBind(key, modifiers, function()
                ExecuteInGameThread(function() ToggleInvulnerability() end)
            end)
        elseif action == "toggle_superstrength" then
            RegisterCustomKeyBind(key, modifiers, function()
                ExecuteInGameThread(function() ToggleSuperStrength() end)
            end)
        elseif action == "save_loadout" then
            RegisterCustomKeyBind(key, modifiers, SaveLoadout)
        elseif action == "spawn_loadout" then
            RegisterCustomKeyBind(key, modifiers, SpawnLoadoutAroundPlayer)
        elseif action == "decrease_level" then
            RegisterCustomKeyBind(key, modifiers, function()
                ExecuteInGameThread(function() DecreaseLevel() end)
            end)
        elseif action == "increase_level" then
            RegisterCustomKeyBind(key, modifiers, function()
                ExecuteInGameThread(function() IncreaseLevel() end)
            end)
        elseif action == "toggle_ui" then
            RegisterCustomKeyBind(key, modifiers, function()
                ExecuteInGameThread(function() ToggleModUI() end)
            end)
        elseif action == "spawn_armor" then
            RegisterCustomKeyBind(key, modifiers, SpawnSelectedArmor)
        elseif action == "spawn_weapon" then
            RegisterCustomKeyBind(key, modifiers, SpawnSelectedWeapon)
        elseif action == "spawn_npc" then
            RegisterCustomKeyBind(key, modifiers, SpawnSelectedNPC)
        elseif action == "spawn_object" then
            RegisterCustomKeyBind(key, modifiers, SpawnSelectedObject)
        elseif action == "undo_spawn" then
            RegisterCustomKeyBind(key, modifiers, UndoLastSpawn)
        elseif action == "despawn_npcs" then
            RegisterCustomKeyBind(key, modifiers, DespawnAllNPCs)
        elseif action == "kill_npcs" then
            RegisterCustomKeyBind(key, modifiers, function()
                ExecuteInGameThread(function() KillAllNPCs() end)
            end)
        elseif action == "toggle_freeze" then
            RegisterCustomKeyBind(key, modifiers, function()
                ExecuteInGameThread(function() FreezeAllNPCs() end)
            end)
        elseif action == "spawn_arena" then
            RegisterCustomKeyBind(key, modifiers, function()
                ExecuteInGameThread(function() SpawnBossArena() end)
            end)
        elseif action == "toggle_slowmo" or action == "toggle_slowmo_sprint" then
            RegisterCustomKeyBind(key, modifiers, function()
                ExecuteInGameThread(function() ToggleSlowMotion() end)
            end)
        elseif action == "decrease_speed" or action == "decrease_speed_sprint" then
            RegisterCustomKeyBind(key, modifiers, function()
                ExecuteInGameThread(function() DecreaseGameSpeed() end)
            end)
        elseif action == "increase_speed" or action == "increase_speed_sprint" then
            RegisterCustomKeyBind(key, modifiers, function()
                ExecuteInGameThread(function() IncreaseGameSpeed() end)
            end)
        elseif action == "toggle_crosshair" then
            RegisterCustomKeyBind(key, modifiers, function()
                ExecuteInGameThread(function() ToggleCrosshair() end)
            end)
            -- Also make sure we can still jump while sprinting with Shift, or crouching with Ctrl held down
        elseif action == "jump" or action == "jump_sprint" or action == "jump_crouch" then
            RegisterCustomKeyBind(key, modifiers, function()
                ExecuteInGameThread(function() PlayerJump() end)
            end)
            -- Also make sure we can still shoot while sprinting with Shift or crouching with Ctrl held down
        elseif action == "shoot" or action == "shoot_sprint" or action == "shoot_crouch" then
            RegisterCustomKeyBind(key, modifiers, function()
                ExecuteInGameThread(function() ShootProjectile() end)
            end)
        elseif action == "remove_armor" then
            RegisterCustomKeyBind(key, modifiers, function()
                ExecuteInGameThread(function() RemovePlayerArmor() end)
            end)
        elseif action == "next_projectile" then
            RegisterCustomKeyBind(key, modifiers, ChangeProjectileNext)
        elseif action == "prev_projectile" then
            RegisterCustomKeyBind(key, modifiers, ChangeProjectilePrev)
        elseif action == "remove_death_screen" then
            RegisterCustomKeyBind(key, modifiers, RemovePlayerOneDeathScreen)
        elseif action == "resurrect" then
            RegisterCustomKeyBind(key, modifiers, function()
                ExecuteInGameThread(function() ResurrectPlayerByController() end)
            end)
        elseif action == "possess_npc" then
            RegisterCustomKeyBind(key, modifiers, PossessNearestNPC)
        elseif action == "repossess_player" then
            RegisterCustomKeyBind(key, modifiers, RepossessPlayer)
        elseif action == "dash_forward" then
            RegisterCustomKeyBind(key, modifiers, function()
                ExecuteInGameThread(function() PlayerDash(DASH_FORWARD) end)
            end)
        elseif action == "dash_back" then
            RegisterCustomKeyBind(key, modifiers, function()
                ExecuteInGameThread(function() PlayerDash(DASH_BACK) end)
            end)
        elseif action == "dash_left" then
            RegisterCustomKeyBind(key, modifiers, function()
                ExecuteInGameThread(function() PlayerDash(DASH_LEFT) end)
            end)
        elseif action == "dash_right" then
            RegisterCustomKeyBind(key, modifiers, function()
                ExecuteInGameThread(function() PlayerDash(DASH_RIGHT) end)
            end)
        elseif action == "toggle_pause" then
            RegisterCustomKeyBind(key, modifiers, function()
                ExecuteInGameThread(function() ToggleGamePaused() end)
            end)
        elseif action == "team_up" then
            RegisterCustomKeyBind(key, modifiers, function()
                ExecuteInGameThread(function() ChangePlayerTeamUp() end)
            end)
        elseif action == "team_down" then
            RegisterCustomKeyBind(key, modifiers, function()
                ExecuteInGameThread(function() ChangePlayerTeamDown() end)
            end)
        elseif action == "goto_me" then
            RegisterCustomKeyBind(key, modifiers, function()
                ExecuteInGameThread(function() GoToMe() end)
            end)
        elseif action == "despawn_target" then
            RegisterCustomKeyBind(key, modifiers, function()
                ExecuteInGameThread(function() DespawnObjectFromPlayerCamera() end)
            end)
        elseif action == "scale_target" then
            RegisterCustomKeyBind(key, modifiers, function()
                ExecuteInGameThread(function() ScaleObjectUnderCamera() end)
            end)
        else
            ErrLogf("Unknown keybind action: %s\n", action)
        end
    end

    Log("Keybinds registered\n")
end

------------------------------------------------------------------------------
-- The logic below attempts to check if the environment is OK to run in
function SanityCheckAndInit()
    LoadConfig()

    local UE4SS_Major, UE4SS_Minor, UE4SS_Hotfix = UE4SS.GetVersion()
    local UE4SS_Version_String = string.format("%d.%d.%d", UE4SS_Major, UE4SS_Minor, UE4SS_Hotfix)

    if UE4SS_Major == 2 and UE4SS_Minor == 5 and (UE4SS_Hotfix == 2 or UE4SS_Hotfix == 1) then
        AllHooks()
    elseif UE4SS_Major == 3 then -- and UE4SS_Minor == 0 and UE4SS_Hotfix == 0 then
        -- All this is commented out as we don't need BP Mod Loader as UE 5.4.4 refuses to load BP mods, or so it seems
        -- -- We are on UE4SS 3.x.x
        -- -- TODO special handling of BPModLoaderMod
        -- -- Currently the best course of action is to copy BPModLoaderMod from UE4SS 2.5.2
        -- -- We will check if the BPModLoaderMod is our patched one or not
        -- local bpml_file_path = "Mods\\BPModLoaderMod\\Scripts\\main.lua"
        -- local bpml_file = io.open(bpml_file_path, "r")
        -- if bpml_file then
        --     local file_size = bpml_file:seek("end")
        --     --            Logf("BMPL size: %d\n", file_size)
        --     -- Yes, this is horrible.
        --     -- The file contains 203 lines
        --     -- 7819 is the size of that file with CRLF (Windows style) endings and
        --     -- 7616 is the size of that file with LF (unix style) endings (7616 + 203 = 7819)
        --     -- If you download the master branch from github you get the LF, otherwise CRLF.
        --     if file_size ~= 7819 and file_size ~= 7616 and file_size ~= 10962 then
        --         Logf(
        --             "You are using UE4SS 3.x.x, please copy Mods\\BPModLoaderMod\\Scripts\\main.lua from UE4SS 2.5.2!\n")
        --     end
        -- else
        --     error("BPModLoaderMod not found!")
        -- end
        AllHooks()
    else
        -- Unsupported UE4SS version
        error("Unsupported UE4SS version: " .. UE4SS_Version_String)
    end

    -- Half Sword steam demo is on UE 5.1 currently.
    -- Half Sword Playtest demo is on UE 5.4.4 currently.
    -- If UE4SS didn't detect the correct UE version, we bail out.
    assert(UnrealVersion.IsEqual(5, 4))

    -- Both return ??? at the moment.
    -- local gameName = GetKismetSystemLibrary():GetGameName():ToString()
    -- Logf("Game \"%s\" detected\n", gameName)
    -- local gameBundle = GetKismetSystemLibrary():GetGameBundleId():ToString()
    -- Logf("Game bundle \"%s\" detected\n",  gameBundle)

    Logf("Sanity check passed!\n")
end

------------------------------------------------------------------------------
SanityCheckAndInit()
------------------------------------------------------------------------------
-- EOF
