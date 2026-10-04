local boss_quests = {}

local bugfrag_quests =
    require("scripts/dungeon_warps/bugfrag_quests")

local active_state = nil

local TETRA_FALLBACK_ROOMS = 2
local TETRA_MAX_COPIES = 2

local TETRA_ORDER = {
    "A",
    "B",
    "C",
    "D",
}

local TETRA_CONFIG = {
    A = { min_depth = 1, max_depth = 3 },
    B = { min_depth = 4, max_depth = 6 },
    C = { min_depth = 7, max_depth = 9 },
    D = { min_depth = 7, max_depth = 9 },
}

local ALPHA_PROGRESS_TEXT = {
    [1] = "A strange pulse echoes through the Cyberworld... Something deep within the Net has begun to stir.",
    [2] = "The network trembles again. Whatever lies beneath the Cyberworld is growing stronger.",
    [3] = "A violent surge tears through the Net. Alpha is close to awakening.",
    [4] = "The final TetraCode has been recovered. Alpha has awakened somewhere in Area 10.",
}

local ALPHA_FLAVOR_TEXT = {
    [1] = "You felt that tremor too, didn't you? Something ancient is stirring deep in the Net.",
    [2] = "The disturbances are getting stronger. Whatever is down there... we're running out of time.",
    [3] = "You should turn back. I can feel it now. Alpha is almost awake.",
}

local function create_tetra_state()
    return {
        collected = false,
        spawns = {},
        rooms_since_spawn = 0,
    }
end

function boss_quests.create_run_state(run_id)
    local state = {
        run_id = tostring(run_id),
        markers = {},
        marker_order = {},
        areas = {},
        area_sequence = 0,
        object_index = {},

        scenarios = {
            alpha = {
                tetra = {
                    A = create_tetra_state(),
                    B = create_tetra_state(),
                    C = create_tetra_state(),
                    D = create_tetra_state(),
                },

                flavor_queue = {},
                flavor_npcs = {},
                boss_areas = {},

                awakened = false,
                spawn_pending = false,

                object_id = nil,
                area_id = nil,
                marker_key = nil,

                defeated_players = {},
                battling_players = {},
            },
            bugfrag = bugfrag_quests.create_state(),
        },
    }

    active_state = state

    return state
end

local function object_key(area_id, object_id)
    return tostring(area_id) .. ":" .. tostring(object_id)
end

local function get_player_key(player_id)
    local helpers = require("scripts/ezlibs-scripts/helpers")
    return helpers.get_safe_player_secret(player_id)
end

local function get_online_players()
    local players = {}
    local seen = {}

    for _, area_id in ipairs(Net.list_areas()) do
        for _, player_id in ipairs(Net.list_players(area_id)) do
            if not seen[player_id] then
                seen[player_id] = true
                players[#players + 1] = player_id
            end
        end
    end

    return players
end

local function player_is_in_run(state, player_id)
    local area_id = Net.get_player_area(player_id)

    if not area_id then
        return false
    end

    local run_id = Net.get_area_custom_property(
        area_id,
        "dungeon_run_id"
    )

    return tostring(run_id) == tostring(state.run_id)
end

local function get_free_marker(state, area_id)
    local available = {}

    for _, key in ipairs(state.marker_order) do
        local marker = state.markers[key]

        if marker.area_id == area_id and not marker.reserved_by then
            available[#available + 1] = marker
        end
    end

    if #available == 0 then
        return nil
    end

    return available[math.random(#available)]
end

local function release_marker(state, marker_key)
    local marker = state.markers[marker_key]

    if marker then
        marker.reserved_by = nil
        marker.spawned_object_id = nil
        marker.spawned_bot_id = nil
    end
end

local function count_collected_tetra(alpha)
    local count = 0

    for _, code in ipairs(TETRA_ORDER) do
        if alpha.tetra[code].collected then
            count = count + 1
        end
    end

    return count
end

local function tetra_spawned_in_area(tetra, area_id)
    for _, spawn in ipairs(tetra.spawns) do
        if spawn.area_id == area_id then
            return true
        end
    end

    return false
end

local function remove_tetra_object(state, spawn)
    pcall(
        Net.remove_object,
        spawn.area_id,
        spawn.object_id
    )

    state.object_index[
        object_key(
            spawn.area_id,
            spawn.object_id
        )
    ] = nil

    release_marker(
        state,
        spawn.marker_key
    )
end

local function clear_tetra_spawns(state, code)
    local tetra = state.scenarios.alpha.tetra[code]

    for _, spawn in ipairs(tetra.spawns) do
        remove_tetra_object(state, spawn)
    end

    tetra.spawns = {}
    tetra.rooms_since_spawn = 0
end

local function spawn_tetra(state, code, area_id, marker)
    local tetra = state.scenarios.alpha.tetra[code]

    if tetra.collected then
        return false
    end

    marker = marker or get_free_marker(state, area_id)

    if not marker then
        return false
    end

    local gid = tonumber(
        Net.get_area_custom_property(
            area_id,
            "crawler_tetra_code_gid"
        )
    )

    if not gid then
        print(
            "[boss_quests] missing crawler_tetra_code_gid in " ..
            tostring(area_id)
        )

        return false
    end

    local ok, object_id = pcall(
        Net.create_object,
        area_id,
        {
            name = "TetraCode " .. code,
            class = "TetraCode",
            visible = true,

            x = marker.x,
            y = marker.y,
            z = marker.z,

            width = 30 / 32,
            height = 34 / 32,

            data = {
                type = "tile",
                gid = gid,
            },

            custom_properties = {
                ["Boss Quest"] = "alpha",
                ["TetraCode"] = code,
            },
        }
    )

    if not ok then
        print(
            "[boss_quests] failed spawning TetraCode " ..
            code .. ": " .. tostring(object_id)
        )

        return false
    end

    marker.reserved_by = "alpha_tetra_" .. code
    marker.spawned_object_id = object_id

    local spawn = {
        area_id = area_id,
        object_id = object_id,
        marker_key = marker.key,
    }

    tetra.spawns[#tetra.spawns + 1] = spawn
    tetra.rooms_since_spawn = 0

    state.object_index[
        object_key(area_id, object_id)
    ] = {
        kind = "tetra",
        code = code,
    }

    print(
        "[boss_quests] spawned TetraCode " ..
        code .. " in " .. tostring(area_id)
    )

    return true
end

local function spawn_flavor_npc(state, area_id)
    local alpha = state.scenarios.alpha
    local stage = alpha.flavor_queue[1]

    if not stage then
        return false
    end

    local marker = get_free_marker(state, area_id)

    if not marker then
        return false
    end

    local ok, object_id = pcall(
        Net.create_object,
        area_id,
        {
            name = "???",
            class = "NPC",
            visible = true,

            x = marker.x,
            y = marker.y,
            z = marker.z,

            data = {
                type = "point",
            },

            custom_properties = {
                ["Asset Name"] = "ranked-navi-bn3",
                ["Direction"] = marker.direction or "Down",
                ["Dialogue Type"] = "first",
                ["Text 1"] = ALPHA_FLAVOR_TEXT[stage],
            },
        }
    )

    if not ok then
        print(
            "[boss_quests] failed creating Alpha flavor NPC placeholder: " ..
            tostring(object_id)
        )

        return false
    end

    marker.reserved_by = "alpha_flavor_" .. tostring(stage)
    marker.spawned_object_id = object_id

    alpha.flavor_npcs[#alpha.flavor_npcs + 1] = {
        stage = stage,
        area_id = area_id,
        marker_key = marker.key,
        placeholder_object_id = object_id,
    }

    table.remove(alpha.flavor_queue, 1)

    print(
        "[boss_quests] queued Alpha flavor NPC stage " ..
        tostring(stage) .. " in " .. tostring(area_id)
    )

    return true
end

local function spawn_alpha_in_area(state, area_id)
    local alpha = state.scenarios.alpha

    if alpha.object_id then
        return true
    end

    local marker = get_free_marker(state, area_id)

    if not marker then
        return false
    end

    local gid = tonumber(
        Net.get_area_custom_property(
            area_id,
            "crawler_alpha_gid"
        )
    )

    if not gid then
        print(
            "[boss_quests] missing crawler_alpha_gid in " ..
            tostring(area_id)
        )

        return false
    end

    local ok, object_id = pcall(
        Net.create_object,
        area_id,
        {
            name = "Alpha",
            class = "Alpha Boss",
            visible = true,

            -- Alpha's oversized tile needs a small runtime correction to visually
            -- center it on the BossMarker while preserving its tested draw ordering.
            x = marker.x + 0.3,
            y = marker.y - 1,
            z = marker.z,

            width = 84 / 32,
            height = 103 / 32,

            data = {
                type = "tile",
                gid = gid,
            },

            custom_properties = {
                ["Boss Quest"] = "alpha",
            },
        }
    )

    if not ok then
        print(
            "[boss_quests] failed spawning Alpha: " ..
            tostring(object_id)
        )

        return false
    end

    marker.reserved_by = "alpha_boss"
    marker.spawned_object_id = object_id

    alpha.object_id = object_id
    alpha.area_id = area_id
    alpha.marker_key = marker.key
    alpha.spawn_pending = false

    state.object_index[
        object_key(area_id, object_id)
    ] = {
        kind = "alpha",
    }

    print(
        "[boss_quests] Alpha awakened in " ..
        tostring(area_id)
    )

    return true
end

local function try_spawn_alpha(state, preferred_area_id)
    local alpha = state.scenarios.alpha

    if not alpha.awakened or alpha.object_id then
        return false
    end

    if preferred_area_id and
        spawn_alpha_in_area(state, preferred_area_id)
    then
        return true
    end

    for i = #alpha.boss_areas, 1, -1 do
        local area_id = alpha.boss_areas[i]

        if area_id ~= preferred_area_id and
            spawn_alpha_in_area(state, area_id)
        then
            return true
        end
    end

    alpha.spawn_pending = true

    return false
end

local function broadcast_tetra_collection(state, code)
    local alpha = state.scenarios.alpha
    local count = count_collected_tetra(alpha)

    local message =
        "TetraCode " .. code .. " has been recovered.\n" ..
        ALPHA_PROGRESS_TEXT[count]

    for _, player_id in ipairs(get_online_players()) do
        if player_is_in_run(state, player_id) then
            pcall(
                Net.shake_player_camera,
                player_id,
                3.0,
                6
            )
        end

        pcall(
            Net.message_player,
            player_id,
            message
        )
    end
end

local function awaken_alpha(state)
    local alpha = state.scenarios.alpha

    if alpha.awakened then
        return
    end

    alpha.awakened = true
    alpha.spawn_pending = true

    -- No more pre-awakening flavor NPCs need to appear.
    alpha.flavor_queue = {}

    try_spawn_alpha(state)
end

local function collect_tetra(state, player_id, code)
    local alpha = state.scenarios.alpha
    local tetra = alpha.tetra[code]

    if not tetra or tetra.collected then
        return
    end

    -- Mark it FIRST so simultaneous interactions cannot
    -- complete the same objective twice.
    tetra.collected = true

    clear_tetra_spawns(
        state,
        code
    )

    local count = count_collected_tetra(alpha)

    print(
        "[boss_quests] TetraCode " ..
        code .. " collected by " ..
        tostring(player_id) ..
        " progress=" .. tostring(count) .. "/4"
    )

    broadcast_tetra_collection(
        state,
        code
    )

    if count >= 4 then
        awaken_alpha(state)
    else
        alpha.flavor_queue[
            #alpha.flavor_queue + 1
        ] = count
    end
end

local function process_tetra_area(state, area_id, depth)
    local alpha = state.scenarios.alpha
    local placed_tetra = false

    -- Primary placement:
    -- only one new primary TetraCode per map.
    for _, code in ipairs(TETRA_ORDER) do
        local tetra = alpha.tetra[code]
        local config = TETRA_CONFIG[code]

        if not tetra.collected and
            #tetra.spawns == 0 and
            depth >= config.min_depth and
            depth <= config.max_depth
        then
            placed_tetra = spawn_tetra(
                state,
                code,
                area_id
            )

            if placed_tetra then
                break
            end
        end
    end

    -- Every suitable newly generated map counts toward
    -- moving a missed code forward.
    for _, code in ipairs(TETRA_ORDER) do
        local tetra = alpha.tetra[code]
        local config = TETRA_CONFIG[code]

        if not tetra.collected and
            #tetra.spawns > 0 and
            depth >= config.min_depth and
            depth <= 9 and
            not tetra_spawned_in_area(tetra, area_id)
        then
            tetra.rooms_since_spawn =
                tetra.rooms_since_spawn + 1
        end
    end

    if placed_tetra then
        return
    end

    -- Fallback placement.
    for _, code in ipairs(TETRA_ORDER) do
        local tetra = alpha.tetra[code]
        local config = TETRA_CONFIG[code]

        if not tetra.collected and
            #tetra.spawns > 0 and
            depth >= config.min_depth and
            depth <= 9
        then
            local due =
                tetra.rooms_since_spawn >=
                TETRA_FALLBACK_ROOMS

            -- Safety valve at the end of the code's normal band.
            if depth == config.max_depth and
                tetra.rooms_since_spawn >= 1
            then
                due = true
            end

            if due then
                local marker =
                    get_free_marker(state, area_id)

                if marker then
                    if #tetra.spawns >= TETRA_MAX_COPIES then
                        local oldest =
                            tetra.spawns[1]

                        if spawn_tetra(
                            state,
                            code,
                            area_id,
                            marker
                        ) then
                            table.remove(
                                tetra.spawns,
                                1
                            )

                            remove_tetra_object(
                                state,
                                oldest
                            )

                            return
                        end
                    elseif spawn_tetra(
                        state,
                        code,
                        area_id,
                        marker
                    ) then
                        return
                    end
                end
            end
        end
    end
end

local function process_alpha_area(
    state,
    area_id,
    depth,
    room_type
)
    if room_type ~= "regular" then
        return
    end

    local alpha = state.scenarios.alpha

    if depth == 10 then
        alpha.boss_areas[
            #alpha.boss_areas + 1
        ] = area_id

        if alpha.awakened then
            try_spawn_alpha(
                state,
                area_id
            )
        end

        return
    end

    if depth < 1 or depth > 9 then
        return
    end

    process_tetra_area(
        state,
        area_id,
        depth
    )

    if not alpha.awakened and
        #alpha.flavor_queue > 0
    then
        spawn_flavor_npc(
            state,
            area_id
        )
    end
end

local function apply_alpha_visibility(state, player_id)
    local alpha = state.scenarios.alpha

    if not alpha.object_id or
        not Net.is_player(player_id)
    then
        return
    end

    if Net.get_player_area(player_id) ~= alpha.area_id then
        return
    end

    local player_key =
        get_player_key(player_id)

    if alpha.defeated_players[player_key] then
        pcall(
            Net.exclude_object_for_player,
            player_id,
            alpha.object_id
        )
    end
end

local function start_alpha_battle(state, player_id)
    local alpha = state.scenarios.alpha

    if not alpha.object_id or
        alpha.battling_players[player_id] or
        Net.is_player_battling(player_id)
    then
        return
    end

    local player_key =
        get_player_key(player_id)

    if alpha.defeated_players[player_key] then
        pcall(
            Net.exclude_object_for_player,
            player_id,
            alpha.object_id
        )

        return
    end

    local alpha_object =
        Net.get_object_by_id(
            alpha.area_id,
            alpha.object_id
        )

    if not alpha_object then
        return
    end

    local crawler_config = require(
        "scripts/ezlibs-scripts/crawler_encounter_config"
    )

    local ezencounters = require(
        "scripts/ezlibs-scripts/ezencounters/main"
    )

    local encounter_info = {
        name =
            "CrawlerAlpha_" ..
            tostring(state.run_id) ..
            "_" ..
            tostring(math.random(1000000)),

        path =
            crawler_config.package_paths.boss,

        enemies = {
            {
                name = "Proto",
                rank = 1,
            },
        },

        positions = {
            { 0, 0, 0, 0, 0, 0 },
            { 0, 0, 0, 0, 1, 0 },
            { 0, 0, 0, 0, 0, 0 },
        },

        _crawler_reward_tier = "hard",
        _crawler_boss = true,

        results_callback =
            function(
                result_player_id,
                _,
                stats
            )
                alpha.battling_players[
                    result_player_id
                ] = nil

                if tonumber(stats.reason) ~= 1 then
                    return
                end

                if active_state ~= state then
                    return
                end

                local result_key =
                    get_player_key(
                        result_player_id
                    )

                alpha.defeated_players[
                    result_key
                ] = true

                if alpha.object_id then
                    pcall(
                        Net.exclude_object_for_player,
                        result_player_id,
                        alpha.object_id
                    )
                end

                print(
                    "[boss_quests] player defeated Alpha: " ..
                    tostring(result_player_id)
                )
            end,
    }

    alpha.battling_players[player_id] = true

    async(function()
        await(
            ezencounters.begin_encounter(
                player_id,
                encounter_info,
                alpha_object
            )
        )

        alpha.battling_players[player_id] = nil
    end)
end

function boss_quests.register_area(state, area_id, depth)
    if not state or state.areas[area_id] then
        return
    end

    depth = tonumber(depth) or 0

    state.area_sequence =
        state.area_sequence + 1

    state.areas[area_id] = {
        depth = depth,
        sequence = state.area_sequence,
    }

    local objects =
        Net.list_objects(area_id)

    local found = 0

    for _, object_id in ipairs(objects) do
        local object =
            Net.get_object_by_id(
                area_id,
                object_id
            )

        if object and
            object.type == "BossMarker"
        then
            local key =
                object_key(
                    area_id,
                    object.id
                )

            if not state.markers[key] then
                local properties =
                    object.custom_properties or {}

                local marker = {
                    key = key,
                    area_id = area_id,
                    object_id = object.id,
                    depth = depth,

                    x = object.x,
                    y = object.y,
                    z = object.z,

                    direction =
                        properties["Direction"] or
                        "Down",

                    reserved_by = nil,
                    spawned_object_id = nil,
                    spawned_bot_id = nil,
                }

                state.markers[key] = marker
                state.marker_order[
                    #state.marker_order + 1
                ] = key

                found = found + 1
            end
        end
    end

    print(
        "[boss_quests] registered " ..
        tostring(found) ..
        " BossMarkers in " ..
        tostring(area_id) ..
        " depth=" ..
        tostring(depth)
    )

    local room_type =
        Net.get_area_custom_property(
            area_id,
            "dungeon_room_type"
        )

    process_alpha_area(
        state,
        area_id,
        depth,
        room_type
    )
    bugfrag_quests.register_area(
        state,
        area_id,
        depth,
        room_type
    )
end

function boss_quests.destroy_run_state(state)
    if active_state == state then
        active_state = nil
    end
end

Net:on("object_interaction", function(event)
    local state = active_state

    if not state then
        return
    end

    local area_id =
        Net.get_player_area(
            event.player_id
        )

    if not area_id then
        return
    end

    local entry =
        state.object_index[
            object_key(
                area_id,
                event.object_id
            )
        ]

    if not entry then
        return
    end

    if bugfrag_quests.handle_object_interaction(
        state,
        entry,
        event.player_id
    ) then
        return
    end

    if entry.kind == "tetra" then
        collect_tetra(
            state,
            event.player_id,
            entry.code
        )

        return
    end

    if entry.kind == "alpha" then
        start_alpha_battle(
            state,
            event.player_id
        )
    end
end)

Net:on("tick", function(event)
    if active_state then
        bugfrag_quests.tick(
            active_state,
            event.delta_time
        )
    end
end)

Net:on("player_area_transfer", function(event)
    Async.sleep(0.05).and_then(function()
        if active_state and
            Net.is_player(event.player_id)
        then
            apply_alpha_visibility(
                active_state,
                event.player_id
            )
        end
    end)
end)

Net:on("player_disconnect", function(event)
    if active_state then
        active_state.scenarios.alpha
            .battling_players[event.player_id] = nil
    end
end)

return boss_quests