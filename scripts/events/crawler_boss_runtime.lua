local eznpcs =
    require(
        "scripts/ezlibs-scripts/eznpcs/eznpcs"
    )

local ezencounters =
    require(
        "scripts/ezlibs-scripts/ezencounters/main"
    )

local crawler_config =
    require(
        "scripts/ezlibs-scripts/crawler_encounter_config"
    )

local helpers =
    require(
        "scripts/ezlibs-scripts/helpers"
    )

local M = {}

local battling = {}
local revealed = {}
local cleared_local = {}

local function csv_has(raw, value)
    for item in tostring(
        raw or ""
    ):gmatch("[^,]+") do
        if item == value then
            return true
        end
    end

    return false
end

local function get_key(
    player_id,
    area_id,
    scenario
)
    local run_id =
        Net.get_area_custom_property(
            area_id,
            "dungeon_run_id"
        ) or ""

    local player_key =
        helpers.get_safe_player_secret(
            player_id
        )

    if not player_key or
        player_key == ""
    then
        return nil, nil
    end

    return
        tostring(run_id) ..
        ":" ..
        tostring(scenario) ..
        ":" ..
        tostring(player_key),
        player_key
end

local function can_participate(
    player_id,
    area_id,
    scenario
)
    local key,
        player_key =
        get_key(
            player_id,
            area_id,
            scenario
        )

    if not key or
        cleared_local[key]
    then
        return false
    end

    local prefix =
        "crawler_scenario_" ..
        scenario ..
        "_"

    local phase =
        Net.get_area_custom_property(
            area_id,
            prefix .. "phase"
        )

    if phase == "active" then
        return true
    end

    if phase ~= "legacy" then
        return false
    end

    local eligible =
        Net.get_area_custom_property(
            area_id,
            prefix .. "eligible"
        )

    local defeated =
        Net.get_area_custom_property(
            area_id,
            prefix .. "defeated"
        )

    return
        csv_has(
            eligible,
            player_key
        ) and
        not csv_has(
            defeated,
            player_key
        )
end

local function record_clear(
    area_id,
    scenario,
    player_key
)
    local property =
        "crawler_boss_clear_signals"

    local raw =
        tostring(
            Net.get_area_custom_property(
                area_id,
                property
            ) or ""
        )

    local token =
        tostring(scenario) ..
        ":" ..
        tostring(player_key)

    if csv_has(raw, token) then
        return
    end

    Net.set_area_custom_property(
        area_id,
        property,
        raw == "" and
            token or
            raw .. "," .. token
    )
end

local function boss_message(npc, player_id, object, text)
    if npc then
        local mugshot = eznpcs.get_dialogue_mugshot(npc, player_id, object)
        return Async.message_player(player_id, text, mugshot.texture_path, mugshot.animation_path)
    end

    return Async.message_player(player_id, text)
end

local function show_boss_intro(player_id, scenario, npc, object)
    return async(function()
        if scenario == "alpha" then
            Net.shake_player_camera(player_id, 3.0, 1.5)
            await(Async.message_player(player_id, "Grraaahhh...!!"))
        elseif scenario == "bass" then
            await(boss_message(npc, player_id, object, "...Grrrrr..."))
            await(boss_message(npc, player_id, object, "I have awakened..."))
            await(boss_message(npc, player_id, object, "I seek only power. I have no name... I exist only to battle."))
            await(boss_message(npc, player_id, object, "These bugs have given me power... I will test it on you."))
        end
    end)
end

local function start_boss_battle(
    npc,
    player_id,
    object
)
    return async(function()
        local area_id =
            Net.get_player_area(
                player_id
            )

        local props =
            object.custom_properties or {}

        local scenario =
            props["Boss Quest"]

        local enemy =
            props["Boss Enemy"]

        if not scenario or
            not enemy or
            battling[player_id] or
            Net.is_player_battling(
                player_id
            ) or
            not can_participate(
                player_id,
                area_id,
                scenario
            )
        then
            return
        end

        battling[player_id] = scenario

        await(show_boss_intro(player_id, scenario, npc, object))

        local stats =
            await(
                ezencounters.begin_encounter(
                    player_id,
                    {
                        name =
                            "CrawlerBoss_" ..
                            tostring(scenario) ..
                            "_" ..
                            tostring(
                                math.random(
                                    1000000
                                )
                            ),

                        path =
                            crawler_config
                                .package_paths
                                .boss,

                        enemies = {
                            {
                                name = enemy,
                                rank =
                                    tonumber(
                                        props[
                                            "Boss Rank"
                                        ]
                                    ) or 1,
                            },
                        },

                        positions = {
                            { 0,0,0,0,0,0 },
                            { 0,0,0,0,1,0 },
                            { 0,0,0,0,0,0 },
                        },

                        _crawler_reward_tier =
                            props[
                                "Boss Reward Tier"
                            ] or "boss",

                        _crawler_boss = true,
                    },
                    object
                )
            )

        battling[player_id] = nil

        if not stats or
            tonumber(stats.reason) ~= 1
        then
            return
        end

        local key,
            player_key =
            get_key(
                player_id,
                area_id,
                scenario
            )

        if not key then return end

        cleared_local[key] = true

        record_clear(
            area_id,
            scenario,
            player_key
        )

        if npc and npc.bot_id then
            Net.exclude_actor_for_player(
                player_id,
                npc.bot_id
            )
        else
            Net.exclude_object_for_player(
                player_id,
                object.id
            )
        end
    end)
end

M.event = {
    name = "dungeon_crawler_boss",

    action = function(
        npc,
        player_id,
        dialogue
    )
        return start_boss_battle(
            npc,
            player_id,
            dialogue
        )
    end,
}

function M.handle_object_interaction(
    event
)
    local area_id =
        Net.get_player_area(
            event.player_id
        )

    local object =
        Net.get_object_by_id(
            area_id,
            event.object_id
        )

    local props =
        object and
        object.custom_properties

    if not object or
        object.type == "NPC" or
        not props or
        not props["Boss Quest"] or
        not props["Boss Enemy"]
    then
        return false
    end

    start_boss_battle(
        nil,
        event.player_id,
        object
    )

    return true
end

function M.tag_runtime_npc_bots(
    area_id
)
    for _, object_id in ipairs(
        Net.list_objects(area_id)
    ) do
        local object =
            Net.get_object_by_id(
                area_id,
                object_id
            )

        if object and
            object.type == "NPC"
        then
            local bot_id =
                eznpcs.get_bot_id_for_placeholder(
                    area_id,
                    object.id
                )

            if bot_id and
                Net.is_bot(bot_id)
            then
                Net.set_object_custom_property(
                    area_id,
                    object.id,
                    "Runtime Bot ID",
                    bot_id
                )
            end
        end
    end
end

function M.ensure_boss_npcs(
    area_id
)
    for _, object_id in ipairs(
        Net.list_objects(area_id)
    ) do
        local object =
            Net.get_object_by_id(
                area_id,
                object_id
            )

        local props =
            object and
            object.custom_properties

        if object and
            object.type == "NPC" and
            props and
            props["Boss Quest"] and
            props["Boss Enemy"]
        then
            local bot_id =
                eznpcs.get_bot_id_for_placeholder(
                    area_id,
                    object.id
                )

            if not bot_id or
                not Net.is_bot(bot_id)
            then
                eznpcs.create_npc_from_object(
                    area_id,
                    object.id
                )
            end
        end
    end

    M.tag_runtime_npc_bots(
        area_id
    )
    local bass_object_id = Net.get_area_custom_property(area_id, "crawler_boss_bass_object_id")

    if bass_object_id and bass_object_id ~= "" then
        local bot_id = eznpcs.get_bot_id_for_placeholder(area_id, bass_object_id)

        if bot_id and Net.is_bot(bot_id) then
            Net.set_area_custom_property(area_id, "crawler_boss_bass_bot_id", bot_id)
        end
    end
end

function M.apply_visibility(
    player_id,
    area_id
)
    for _, object_id in ipairs(
        Net.list_objects(area_id)
    ) do
        local object =
            Net.get_object_by_id(
                area_id,
                object_id
            )

        local props =
            object and
            object.custom_properties

        local scenario =
            props and
            props["Boss Quest"]

        if scenario and
            props["Boss Enemy"]
        then
            local visible =
                can_participate(
                    player_id,
                    area_id,
                    scenario
                )

            if object.type == "NPC" then
                local bot_id =
                    eznpcs.get_bot_id_for_placeholder(
                        area_id,
                        object.id
                    )

                if bot_id then
                    if visible then
                        Net.include_actor_for_player(
                            player_id,
                            bot_id
                        )
                    else
                        Net.exclude_actor_for_player(
                            player_id,
                            bot_id
                        )
                    end
                end
            elseif visible then
                Net.include_object_for_player(
                    player_id,
                    object.id
                )
            else
                Net.exclude_object_for_player(
                    player_id,
                    object.id
                )
            end
        end
    end
end

local function restore_camera(
    player_id
)
    if not Net.is_player(player_id) then
        return
    end

    Net.unlock_player_camera(
        player_id
    )

    Net.track_with_player_camera(
        player_id
    )

    Net.unlock_player_input(
        player_id
    )
end

function M.reveal_first_unseen_boss(player_id, area_id)
    local scenario, x, y, z

    if Net.get_area_custom_property(area_id, "crawler_boss_bass_present") == "true" then
        scenario = "bass"
        x = tonumber(Net.get_area_custom_property(area_id, "crawler_boss_bass_x"))
        y = tonumber(Net.get_area_custom_property(area_id, "crawler_boss_bass_y"))
        z = tonumber(Net.get_area_custom_property(area_id, "crawler_boss_bass_z"))

        if x and y and z and can_participate(player_id, area_id, scenario) then
            local key = get_key(player_id, area_id, scenario)

            if key and not revealed[key] then
                print("[crawler_boss_runtime] revealing bass to " .. tostring(player_id))
                revealed[key] = true

                Net.lock_player_input(player_id)
                Net.slide_player_camera(player_id, x, y, z, 0.75)

                Async.sleep(2.25).and_then(function()
                    if not Net.is_player(player_id) then return end

                    if Net.get_player_area(player_id) ~= area_id then
                        restore_camera(player_id)
                        return
                    end

                    local pos = Net.get_player_position(player_id)
                    Net.slide_player_camera(player_id, pos.x, pos.y, pos.z, 0.75)

                    Async.sleep(0.75).and_then(function()
                        restore_camera(player_id)
                    end)
                end)

                return true
            end
        end
    end

    for _, object_id in ipairs(Net.list_objects(area_id)) do
        local object = Net.get_object_by_id(area_id, object_id)
        local props = object and object.custom_properties
        scenario = props and props["Boss Quest"]

        if scenario and props["Boss Enemy"] and can_participate(player_id, area_id, scenario) then
            local key = get_key(player_id, area_id, scenario)

            if key and not revealed[key] then
                print("[crawler_boss_runtime] revealing " .. scenario .. " to " .. tostring(player_id))
                revealed[key] = true

                Net.lock_player_input(player_id)
                Net.slide_player_camera(player_id, object.x, object.y, object.z, 0.75)

                Async.sleep(2.25).and_then(function()
                    if not Net.is_player(player_id) then return end

                    if Net.get_player_area(player_id) ~= area_id then
                        restore_camera(player_id)
                        return
                    end

                    local pos = Net.get_player_position(player_id)
                    Net.slide_player_camera(player_id, pos.x, pos.y, pos.z, 0.75)

                    Async.sleep(0.75).and_then(function()
                        restore_camera(player_id)
                    end)
                end)

                return true
            end
        end
    end

    return false
end

return M
