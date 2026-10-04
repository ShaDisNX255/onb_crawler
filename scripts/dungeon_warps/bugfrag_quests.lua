local M = {}

local scenario_lifecycle = require("scripts/dungeon_warps/scenario_lifecycle")
local helpers = require("scripts/ezlibs-scripts/helpers")

local REQUIRED = 20
local FLOOR_CHANCE = 0.35
local EXTRA_TRADER_CHANCE = 0.35
local BASS_ACTIVE_COPIES = 3
local BASS_LEGACY_COPIES = 1
local BASS_NEW_AREA_ROLL_CHANCE = 0.50

local FIRST_TEXT = "A strange BugFrag has been recovered... Something in the Cyberworld seems drawn to it."
local BASS_TEXT = "A savage growl echoes throughout the Cyberworld... An overwhelming presence has been unleashed."

local function key(area_id, object_id)
    return tostring(area_id) .. ":" .. tostring(object_id)
end

local function free_marker(state, area_id)
    local list = {}
    for _, marker_key in ipairs(state.marker_order) do
        local marker = state.markers[marker_key]
        if marker.area_id == area_id and not marker.reserved_by then list[#list + 1] = marker end
    end
    if #list == 0 then return nil end
    return list[math.random(#list)]
end

local function release_marker(state, marker_key)
    local marker = state.markers[marker_key]
    if not marker then return end
    marker.reserved_by = nil
    marker.spawned_object_id = nil
    marker.spawned_bot_id = nil
end

local function player_is_in_run(state, player_id)
    local area_id = Net.get_player_area(player_id)
    if not area_id then return false end
    return tostring(Net.get_area_custom_property(area_id, "dungeon_run_id")) == tostring(state.run_id)
end

local function broadcast(state, message, shake)
    local seen = {}
    for _, area_id in ipairs(Net.list_areas()) do
        for _, player_id in ipairs(Net.list_players(area_id)) do
            if not seen[player_id] then
                seen[player_id] = true
                if shake and player_is_in_run(state, player_id) then pcall(Net.shake_player_camera, player_id, 3.0, 6) end
                pcall(Net.message_player, player_id, message)
            end
        end
    end
end

local function set_battle_drops(state, enabled)
    for area_id in pairs(state.areas) do
        Net.set_area_custom_property(area_id, "crawler_bugfrag_battle_drops", enabled and "true" or "false")
    end
end

local function stop_battle_drops(state)
    local quest = state.scenarios.bugfrag
    if not quest.battle_drops_enabled then return end
    quest.battle_drops_enabled = false
    set_battle_drops(state, false)
end

function M.create_state()
    return {
        scenario = "bass", -- Later this can become bass/gregar.
        active = false,
        unlocked = false,
        battle_drops_enabled = false,
        contributed = 0,
        bugfrags = {},
        traders = {},
        poll_time = 0,
        bass = {
            spawns = {},
            lifecycle = scenario_lifecycle.create("bass", BASS_ACTIVE_COPIES, BASS_LEGACY_COPIES),
        },
    }
end

local function remove_spawn(state, spawn)
    local object = Net.get_object_by_id(spawn.area_id, spawn.object_id)
    local bot_id = object and object.custom_properties and object.custom_properties["Runtime Bot ID"]
    if bot_id and Net.is_bot(bot_id) then pcall(Net.remove_bot, bot_id) end
    pcall(Net.remove_object, spawn.area_id, spawn.object_id)
    state.object_index[key(spawn.area_id, spawn.object_id)] = nil
    release_marker(state, spawn.marker_key)
end

local function spawn_bugfrag(state, area_id)
    local quest = state.scenarios.bugfrag
    local marker = free_marker(state, area_id)
    local gid = tonumber(Net.get_area_custom_property(area_id, "crawler_bugfrag_gid"))
    if not marker or not gid then return false end

    local ok, object_id = pcall(Net.create_object, area_id, {
        name = "BugFrag", class = "BugFrag", visible = true,
        x = marker.x, y = marker.y, z = marker.z,
        width = 28 / 32, height = 34 / 32,
        data = { type = "tile", gid = gid },
        custom_properties = { ["BugFrag Scenario"] = quest.scenario },
    })
    if not ok then return false end

    marker.reserved_by = "bugfrag_floor"
    marker.spawned_object_id = object_id
    local spawn = { area_id = area_id, object_id = object_id, marker_key = marker.key }
    quest.bugfrags[#quest.bugfrags + 1] = spawn
    state.object_index[key(area_id, object_id)] = { kind = "bugfrag", scenario = quest.scenario }

    print("[bugfrag_quests] spawned BugFrag in " .. area_id)
    return true
end

local function spawn_trader(state, area_id)
    local quest = state.scenarios.bugfrag
    local marker = free_marker(state, area_id)
    local gid = tonumber(Net.get_area_custom_property(area_id, "crawler_bugfrag_trader_gid"))
    if not marker or not gid then return false end

    local ok, object_id = pcall(Net.create_object, area_id, {
        name = "BugFrag Trader", class = "BugFrag Trader", visible = true,
        x = marker.x, y = marker.y, z = marker.z,
        width = 22 / 32, height = 41 / 32,
        data = { type = "tile", gid = gid },
        custom_properties = { ["Bass Contribution Serial"] = "0" },
    })
    if not ok then return false end

    marker.reserved_by = "bugfrag_trader"
    marker.spawned_object_id = object_id
    quest.traders[#quest.traders + 1] = {
        area_id = area_id, object_id = object_id, marker_key = marker.key, seen = 0,
    }

    print("[bugfrag_quests] spawned trader in " .. area_id)
    return true
end

local function bass_spawned_in_area(bass, area_id)
    for _, spawn in ipairs(bass.spawns) do
        if spawn.area_id == area_id then return true end
    end
    return false
end

local function get_retirable_bass(bass)
    for index, spawn in ipairs(bass.spawns) do
        if #Net.list_players(spawn.area_id) == 0 then return index, spawn end
    end
    return nil, nil
end

local function spawn_bass(state, area_id, allow_roll)
    local quest = state.scenarios.bugfrag
    local bass = quest.bass
    local life = bass.lifecycle
    if life.phase ~= "active" or bass_spawned_in_area(bass, area_id) then return false end

    local retire_index, retire_spawn
    if #bass.spawns >= life.active_copy_limit then
        if not allow_roll then return false end
        retire_index, retire_spawn = get_retirable_bass(bass)
        if not retire_spawn then return false end
    end

    local marker = free_marker(state, area_id)
    if not marker then return false end

    local ok, object_id = pcall(Net.create_object, area_id, {
        name = "Bass", class = "NPC", visible = true,
        x = marker.x, y = marker.y, z = marker.z,
        data = { type = "point" },
        custom_properties = {
            ["Asset Name"] = "bass",
            ["Direction"] = marker.direction or "Down",
            ["Dialogue Type"] = "first",
            ["Event Name"] = "dungeon_crawler_boss",
            ["Boss Quest"] = "bass",
            ["Boss Enemy"] = "Forte",
            ["Boss Rank"] = "1",
            ["Boss Reward Tier"] = "boss",
        },
    })
    if not ok then return false end

    marker.reserved_by = "bass_boss"
    marker.spawned_object_id = object_id
    bass.spawns[#bass.spawns + 1] = { area_id = area_id, object_id = object_id, marker_key = marker.key }

    if retire_spawn then
        table.remove(bass.spawns, retire_index)
        remove_spawn(state, retire_spawn)
        print("[bugfrag_quests] rolled Bass from " .. tostring(retire_spawn.area_id) .. " to " .. tostring(area_id))
    else
        print("[bugfrag_quests] Bass spawned in " .. tostring(area_id))
    end

    stop_battle_drops(state)
    return true
end

local function fill_initial_bass_spawns(state)
    local bass = state.scenarios.bugfrag.bass
    local candidates = {}

    for area_id, area in pairs(state.areas) do
        if Net.get_area_custom_property(area_id, "dungeon_room_type") == "regular" and #Net.list_players(area_id) == 0 then
            candidates[#candidates + 1] = { area_id = area_id, sequence = tonumber(area.sequence) or 0 }
        end
    end

    table.sort(candidates, function(a, b) return a.sequence > b.sequence end)

    for _, candidate in ipairs(candidates) do
        if #bass.spawns >= bass.lifecycle.active_copy_limit then break end
        spawn_bass(state, candidate.area_id, false)
    end
end

local function activate(state)
    local quest = state.scenarios.bugfrag
    if quest.active then return end

    quest.active = true
    quest.battle_drops_enabled = true
    set_battle_drops(state, true)
    broadcast(state, FIRST_TEXT, false)
    print("[bugfrag_quests] Bass quest activated")
end

local function prune_bass_legacy(state)
    local bass = state.scenarios.bugfrag.bass
    if bass.lifecycle.phase ~= "legacy" then return end

    while #bass.spawns > bass.lifecycle.legacy_copy_limit do
        local index, spawn = get_retirable_bass(bass)
        if not spawn then return end
        table.remove(bass.spawns, index)
        remove_spawn(state, spawn)
    end
end

local function clear_bass_spawns(state)
    local bass = state.scenarios.bugfrag.bass
    for _, spawn in ipairs(bass.spawns) do remove_spawn(state, spawn) end
    bass.spawns = {}
end

local function unlock_bass(state)
    local quest = state.scenarios.bugfrag
    if quest.unlocked then return end

    quest.unlocked = true
    quest.contributed = REQUIRED

    for _, spawn in ipairs(quest.bugfrags) do remove_spawn(state, spawn) end
    for _, spawn in ipairs(quest.traders) do remove_spawn(state, spawn) end
    quest.bugfrags = {}
    quest.traders = {}

    scenario_lifecycle.activate(quest.bass.lifecycle)

    for _, area_id in ipairs(Net.list_areas()) do
        for _, player_id in ipairs(Net.list_players(area_id)) do
            if player_is_in_run(state, player_id) then
                scenario_lifecycle.enroll(quest.bass.lifecycle, helpers.get_safe_player_secret(player_id))
            end
        end
    end

    scenario_lifecycle.sync_all(state, quest.bass.lifecycle)
    fill_initial_bass_spawns(state)
    broadcast(state, BASS_TEXT, true)
    print("[bugfrag_quests] Bass unlocked")
end

function M.enroll_player(state, player_key)
    local life = state.scenarios.bugfrag.bass.lifecycle
    if not scenario_lifecycle.enroll(life, player_key) then return false end
    scenario_lifecycle.sync_all(state, life)
    return true
end

function M.handle_boss_clear(state, player_key)
    local bass = state.scenarios.bugfrag.bass
    local accepted, first_clear, finished = scenario_lifecycle.mark_defeated(bass.lifecycle, player_key)
    if not accepted then return end

    if finished then
        clear_bass_spawns(state)
    elseif first_clear then
        prune_bass_legacy(state)
    end

    scenario_lifecycle.sync_all(state, bass.lifecycle)
    print("[bugfrag_quests] Bass clear phase=" .. tostring(bass.lifecycle.phase))
    if first_clear then print("[bugfrag_quests] Bass scenario slot released") end
end

function M.handle_object_interaction(state, entry)
    if not entry or entry.kind ~= "bugfrag" then return false end
    activate(state)
    return true
end

function M.register_area(state, area_id, _, room_type)
    local quest = state.scenarios.bugfrag

    scenario_lifecycle.sync_area(quest.bass.lifecycle, area_id)
    Net.set_area_custom_property(area_id, "crawler_bugfrag_battle_drops", quest.battle_drops_enabled and "true" or "false")
    Net.set_area_custom_property(area_id, "crawler_bugfrag_scenario", quest.scenario)

    if room_type ~= "regular" then return end

    if quest.unlocked then
        local bass = quest.bass
        if bass.lifecycle.phase == "active" and (#bass.spawns == 0 or math.random() < BASS_NEW_AREA_ROLL_CHANCE) then
            spawn_bass(state, area_id, true)
        end
        return
    end

    if not quest.active then
        if math.random() < FLOOR_CHANCE then spawn_bugfrag(state, area_id) end
        return
    end

    -- First trader after activation is guaranteed.
    if #quest.traders == 0 or math.random() < EXTRA_TRADER_CHANCE then spawn_trader(state, area_id) end
    if math.random() < FLOOR_CHANCE then spawn_bugfrag(state, area_id) end
end

function M.tick(state, delta_time)
    local quest = state.scenarios.bugfrag

    if quest.unlocked then
        prune_bass_legacy(state)
        return
    end
    if not quest.active then return end

    quest.poll_time = quest.poll_time + (tonumber(delta_time) or 0)
    if quest.poll_time < 0.2 then return end
    quest.poll_time = 0

    for _, trader in ipairs(quest.traders) do
        local object = Net.get_object_by_id(trader.area_id, trader.object_id)
        if object then
            local serial = tonumber(object.custom_properties["Bass Contribution Serial"]) or 0
            if serial > trader.seen then
                quest.contributed = quest.contributed + (serial - trader.seen)
                trader.seen = serial
                print("[bugfrag_quests] contributed=" .. tostring(quest.contributed) .. "/" .. tostring(REQUIRED))

                if quest.contributed >= REQUIRED then
                    unlock_bass(state)
                    return
                end
            end
        end
    end
end

return M