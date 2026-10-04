local M = {}

local REQUIRED = 20
local FLOOR_CHANCE = 0.25
local EXTRA_TRADER_CHANCE = 0.25

local FIRST_TEXT =
    "A strange BugFrag has been recovered... Something in the Cyberworld seems drawn to it."

local BASS_TEXT =
    "A savage growl echoes throughout the Cyberworld... An overwhelming presence has been unleashed."

local function key(area_id, object_id)
    return tostring(area_id) .. ":" .. tostring(object_id)
end

local function free_marker(state, area_id)
    local list = {}
    for _, marker_key in ipairs(state.marker_order) do
        local marker = state.markers[marker_key]
        if marker.area_id == area_id and not marker.reserved_by then
            list[#list + 1] = marker
        end
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
    return tostring(Net.get_area_custom_property(
        area_id,
        "dungeon_run_id"
    )) == tostring(state.run_id)
end

local function broadcast(state, message, shake)
    local seen = {}
    for _, area_id in ipairs(Net.list_areas()) do
        for _, player_id in ipairs(Net.list_players(area_id)) do
            if not seen[player_id] then
                seen[player_id] = true
                if shake and player_is_in_run(state, player_id) then
                    pcall(Net.shake_player_camera, player_id, 3.0, 6)
                end
                pcall(Net.message_player, player_id, message)
            end
        end
    end
end

local function set_battle_drops(state, enabled)
    for area_id in pairs(state.areas) do
        Net.set_area_custom_property(
            area_id,
            "crawler_bugfrag_battle_drops",
            enabled and "true" or "false"
        )
    end
end

function M.create_state()
    return {
        scenario = "bass", -- Later this can become bass/gregar.
        active = false,
        unlocked = false,
        contributed = 0,
        bugfrags = {},
        traders = {},
        poll_time = 0,
        bass = {
            spawn_pending = false,
            placeholder_id = nil,
            area_id = nil,
            marker_key = nil,
        },
    }
end

local function remove_spawn(state, spawn)
    pcall(Net.remove_object, spawn.area_id, spawn.object_id)
    state.object_index[key(spawn.area_id, spawn.object_id)] = nil
    release_marker(state, spawn.marker_key)
end

local function spawn_bugfrag(state, area_id)
    local quest = state.scenarios.bugfrag
    local marker = free_marker(state, area_id)
    local gid = tonumber(Net.get_area_custom_property(
        area_id,
        "crawler_bugfrag_gid"
    ))
    if not marker or not gid then return false end

    local ok, object_id = pcall(Net.create_object, area_id, {
        name = "BugFrag",
        class = "BugFrag",
        visible = true,
        x = marker.x,
        y = marker.y,
        z = marker.z,
        width = 28 / 32,
        height = 34 / 32,
        data = { type = "tile", gid = gid },
        custom_properties = {
            ["BugFrag Scenario"] = quest.scenario,
        },
    })
    if not ok then return false end

    marker.reserved_by = "bugfrag_floor"
    marker.spawned_object_id = object_id

    local spawn = {
        area_id = area_id,
        object_id = object_id,
        marker_key = marker.key,
    }

    quest.bugfrags[#quest.bugfrags + 1] = spawn
    state.object_index[key(area_id, object_id)] = {
        kind = "bugfrag",
        scenario = quest.scenario,
    }

    print("[bugfrag_quests] spawned BugFrag in " .. area_id)
    return true
end

local function spawn_trader(state, area_id)
    local quest = state.scenarios.bugfrag
    local marker = free_marker(state, area_id)
    local gid = tonumber(Net.get_area_custom_property(
        area_id,
        "crawler_bugfrag_trader_gid"
    ))
    if not marker or not gid then return false end

    local ok, object_id = pcall(Net.create_object, area_id, {
        name = "BugFrag Trader",
        class = "BugFrag Trader",
        visible = true,
        x = marker.x,
        y = marker.y,
        z = marker.z,
        width = 22 / 32,
        height = 41 / 32,
        data = { type = "tile", gid = gid },
        custom_properties = {
            ["Bass Contribution Serial"] = "0",
        },
    })
    if not ok then return false end

    marker.reserved_by = "bugfrag_trader"
    marker.spawned_object_id = object_id

    quest.traders[#quest.traders + 1] = {
        area_id = area_id,
        object_id = object_id,
        marker_key = marker.key,
        seen = 0,
    }

    print("[bugfrag_quests] spawned trader in " .. area_id)
    return true
end

local function spawn_bass(state, area_id)
    local quest = state.scenarios.bugfrag
    local bass = quest.bass
    local marker = free_marker(state, area_id)
    if not marker then return false end

    local ok, object_id = pcall(Net.create_object, area_id, {
        name = "Bass",
        class = "NPC",
        visible = true,
        x = marker.x,
        y = marker.y,
        z = marker.z,
        data = { type = "point" },
        custom_properties = {
            ["Asset Name"] = "bass",
            ["Direction"] = marker.direction or "Down",
            ["Dialogue Type"] = "first",
            ["Event Name"] = "dungeon_bass_boss",
            ["Boss Quest"] = "bass",
        },
    })
    if not ok then return false end

    marker.reserved_by = "bass_boss"
    marker.spawned_object_id = object_id

    bass.spawn_pending = false
    bass.placeholder_id = object_id
    bass.area_id = area_id
    bass.marker_key = marker.key

    print("[bugfrag_quests] Bass spawned in " .. area_id)
    return true
end

local function activate(state)
    local quest = state.scenarios.bugfrag
    if quest.active then return end

    quest.active = true
    set_battle_drops(state, true)
    broadcast(state, FIRST_TEXT, false)

    print("[bugfrag_quests] Bass quest activated")
end

local function unlock_bass(state)
    local quest = state.scenarios.bugfrag
    if quest.unlocked then return end

    quest.unlocked = true
    quest.contributed = REQUIRED
    set_battle_drops(state, false)

    for _, spawn in ipairs(quest.bugfrags) do
        remove_spawn(state, spawn)
    end
    for _, spawn in ipairs(quest.traders) do
        remove_spawn(state, spawn)
    end

    quest.bugfrags = {}
    quest.traders = {}
    quest.bass.spawn_pending = true

    broadcast(state, BASS_TEXT, true)
    print("[bugfrag_quests] Bass unlocked")
end

function M.handle_object_interaction(state, entry)
    if not entry or entry.kind ~= "bugfrag" then
        return false
    end

    activate(state)
    return true
end

function M.register_area(state, area_id, _, room_type)
    local quest = state.scenarios.bugfrag

    Net.set_area_custom_property(
        area_id,
        "crawler_bugfrag_battle_drops",
        quest.active and not quest.unlocked and "true" or "false"
    )

    Net.set_area_custom_property(
        area_id,
        "crawler_bugfrag_scenario",
        quest.scenario
    )

    if room_type ~= "regular" then return end

    if quest.unlocked then
        if quest.bass.spawn_pending and not quest.bass.placeholder_id then
            spawn_bass(state, area_id)
        end
        return
    end

    if not quest.active then
        if math.random() < FLOOR_CHANCE then
            spawn_bugfrag(state, area_id)
        end
        return
    end

    -- First trader after activation is guaranteed.
    if #quest.traders == 0 or math.random() < EXTRA_TRADER_CHANCE then
        spawn_trader(state, area_id)
    end

    if math.random() < FLOOR_CHANCE then
        spawn_bugfrag(state, area_id)
    end
end

function M.tick(state, delta_time)
    local quest = state.scenarios.bugfrag
    if not quest.active or quest.unlocked then return end

    quest.poll_time = quest.poll_time + (tonumber(delta_time) or 0)
    if quest.poll_time < 0.2 then return end
    quest.poll_time = 0

    for _, trader in ipairs(quest.traders) do
        local object = Net.get_object_by_id(
            trader.area_id,
            trader.object_id
        )

        if object then
            local serial = tonumber(
                object.custom_properties[
                    "Bass Contribution Serial"
                ]
            ) or 0

            if serial > trader.seen then
                quest.contributed =
                    quest.contributed +
                    (serial - trader.seen)

                trader.seen = serial

                print(
                    "[bugfrag_quests] contributed=" ..
                    tostring(quest.contributed) ..
                    "/" .. tostring(REQUIRED)
                )

                if quest.contributed >= REQUIRED then
                    unlock_bass(state)
                    return
                end
            end
        end
    end
end

return M