local eznpcs =
    require(
        'scripts/ezlibs-scripts/eznpcs/eznpcs'
    )

local chip_sellers =
    require(
        "scripts/dungeon_warps/chip_sellers"
    )

local ezmemory =
    require("scripts/ezlibs-scripts/ezmemory")

local ezencounters =
    require("scripts/ezlibs-scripts/ezencounters/main")

local crawler_config =
    require("scripts/ezlibs-scripts/crawler_encounter_config")

local BUGFRAG_GET_SFX =
    "/server/assets/ezlibs-assets/sfx/item_get.ogg"

local BUGFRAG_TRADER_SFX =
    "/server/assets/sfx/EXE1_42-chiptrader.ogg"

local REWARD_SFX =
    "/server/assets/sfx/chip_purchase.ogg"

local function play_sfx(player_id, path)
    pcall(Net.provide_asset_for_player, player_id, path)
    pcall(Net.play_sound_for_player, player_id, path)
end

local dungeon_heal = {
    name = "dungeon_heal",

    action = function(
        npc,
        player_id,
        dialogue,
        relay_object
    )
        return async(function()
            local mugshot =
                eznpcs.get_dialogue_mugshot(
                    npc,
                    player_id,
                    dialogue
                )

            local text =
                dialogue.custom_properties[
                    "Text 1"
                ]
                or
                "You have had a tough journey. Rest here."


            await(
                Async.message_player(
                    player_id,
                    text,
                    mugshot.texture_path,
                    mugshot.animation_path
                )
            )


            local max_health = Net.get_player_max_health(player_id)

            if max_health then
                Net.set_player_health(
                    player_id,
                    max_health
                )
            end


            Net.play_sound_for_player(
                player_id,
                "/server/assets/ezlibs-assets/sfx/recover.ogg"
            )


            return
                dialogue.custom_properties[
                    "Next 1"
                ]
        end)
    end,
}

local dungeon_chip_seller = {
    name =
        "dungeon_chip_seller",

    action =
        function(
            npc,
            player_id,
            dialogue,
            relay_object
        )
            local mugshot =
                eznpcs.get_dialogue_mugshot(
                    npc,
                    player_id,
                    dialogue
                )

            return chip_sellers.interact(
                player_id,
                dialogue,
                mugshot
            )
        end,
}


eznpcs.add_event(
    dungeon_heal
)

eznpcs.add_event(
    dungeon_chip_seller
)

local bass_battling = {}

local dungeon_bass_boss = {
    name = "dungeon_bass_boss",

    action = function(npc, player_id, dialogue)
        return async(function()
            local area_id = Net.get_player_area(player_id)

            if bass_battling[player_id] or
                Net.is_player_battling(player_id) or
                ezmemory.object_is_hidden_from_player(
                    player_id,
                    area_id,
                    dialogue.id
                )
            then
                return
            end

            bass_battling[player_id] = true

            local stats = await(ezencounters.begin_encounter(
                player_id,
                {
                    name = "CrawlerBass_" ..
                        tostring(math.random(1000000)),
                    path = crawler_config.package_paths.boss,
                    enemies = {
                        { name = "Forte", rank = 1 },
                    },
                    positions = {
                        { 0,0,0,0,0,0 },
                        { 0,0,0,0,1,0 },
                        { 0,0,0,0,0,0 },
                    },
                    _crawler_reward_tier = "hard",
                    _crawler_boss = true,
                },
                dialogue
            ))

            bass_battling[player_id] = nil

            if stats and tonumber(stats.reason) == 1 then
                ezmemory.hide_object_from_player(
                    player_id,
                    area_id,
                    dialogue.id
                )

                if npc.bot_id then
                    Net.exclude_actor_for_player(
                        player_id,
                        npc.bot_id
                    )
                end
            end
        end)
    end,
}

eznpcs.add_event(
    dungeon_bass_boss
)

-- ============================================================
-- DYNAMIC DUNGEON NPC DISCOVERY
-- ============================================================
--
-- Runtime dungeon maps do not exist when eznpcs initially scans
-- the server.
--
-- Scan each generated dungeon area the first time a player
-- transfers into it.
--
-- IMPORTANT:
-- This runs inside the normal ezlibs Lua state, so seller
-- interactions share the SAME ezmemory/crawler_whitelist state
-- used by Mystery Data and other crawler rewards.
-- ============================================================

local scanned_dungeon_areas = {}


local function scan_dungeon_area(
    area_id
)
    if not area_id then
        return
    end


    if scanned_dungeon_areas[
        area_id
    ] then
        return
    end


    local run_id =
        Net.get_area_custom_property(
            area_id,
            "dungeon_run_id"
        )

    if not run_id then
        return
    end


    local ok,
        err =
        pcall(
            eznpcs.add_npcs_to_area,
            area_id
        )


    if not ok then
        print(
            "[eznpcs_events] failed scanning dungeon NPCs in " ..
            tostring(area_id) ..
            ": " ..
            tostring(err)
        )

        return
    end


    scanned_dungeon_areas[
        area_id
    ] =
        true


    print(
        "[eznpcs_events] scanned runtime dungeon NPCs in " ..
        tostring(area_id)
    )
end

local function apply_bass_visibility(
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

        if object and
            object.type == "NPC" and
            object.custom_properties and
            object.custom_properties["Boss Quest"] == "bass" and
            ezmemory.object_is_hidden_from_player(
                player_id,
                area_id,
                object.id
            )
        then
            local bot_id =
                eznpcs.get_bot_id_for_placeholder(
                    area_id,
                    object.id
                )

            if bot_id then
                Net.exclude_actor_for_player(
                    player_id,
                    bot_id
                )
            end
        end
    end
end

Net:on(
    "player_area_transfer",
    function(event)
        Async.sleep(
            0.05
        ).and_then(
            function()
                if not Net.is_player(
                    event.player_id
                ) then
                    return
                end


                local area_id =
                    Net.get_player_area(
                        event.player_id
                    )


                scan_dungeon_area(
                    area_id
                )

                apply_bass_visibility(
                    event.player_id,
                    area_id
                )
            end
        )
    end
)

local bugfrag_busy = {}

Net:on("object_interaction", function(event)
    local player_id = event.player_id
    local area_id = Net.get_player_area(player_id)
    local object = Net.get_object_by_id(
        area_id,
        event.object_id
    )

    if not object then return end

    local object_type = object.type

    if object_type ~= "BugFrag" and
        object_type ~= "BugFrag Trader"
    then
        return
    end

    local lock =
        tostring(player_id) .. ":" ..
        tostring(event.object_id)

    if bugfrag_busy[lock] then return end
    bugfrag_busy[lock] = true

    async(function()
        if object_type == "BugFrag" then
            if not ezmemory.object_is_hidden_from_player(
                player_id,
                area_id,
                object.id
            ) then
                local direction =
                    Net.get_player_direction(player_id)

                ezmemory.play_anim_get(player_id)
                Net.play_sound_for_player(
                    player_id,
                    BUGFRAG_GET_SFX
                )

                ezmemory.add_player_fragments(
                    player_id,
                    1
                )

                ezmemory.hide_object_from_player(
                    player_id,
                    area_id,
                    object.id
                )

                await(Async.message_player(
                    player_id,
                    "Got 1 BugFrag!"
                ))

                ezmemory.set_direction_anim(
                    player_id,
                    direction
                )
            end

            bugfrag_busy[lock] = nil
            return
        end

        local choice = await(Async.question_player(
            player_id,
            "Trade 1 BugFrag?"
        ))

        if choice == 1 then
            local trader = Net.get_object_by_id(
                area_id,
                object.id
            )

            if trader then
                local fragments =
                    tonumber(
                        ezmemory.get_player_fragments(
                            player_id
                        )
                    ) or 0

                if fragments < 1 then
                    await(Async.message_player(
                        player_id,
                        "You don't have any BugFrags."
                    ))
                elseif ezmemory.spend_player_fragments(
                    player_id,
                    1
                ) then
                    play_sfx(
                        player_id,
                        BUGFRAG_TRADER_SFX
                    )

                    await(Async.message_player(
                        player_id,
                        "Handed over the BugFrag"
                    ))

                    local money =
                        math.random(2, 10) * 50

                    ezmemory.set_player_money(
                        player_id,
                        (ezmemory.get_player_money(player_id) or 0) +
                        money
                    )

                    trader = Net.get_object_by_id(
                        area_id,
                        object.id
                    )

                    if trader then
                        local serial = tonumber(
                            trader.custom_properties[
                                "Bass Contribution Serial"
                            ]
                        ) or 0

                        Net.set_object_custom_property(
                            area_id,
                            object.id,
                            "Bass Contribution Serial",
                            tostring(serial + 1)
                        )
                    end

                    local direction =
                        Net.get_player_direction(player_id)

                    ezmemory.play_anim_get(player_id)

                    play_sfx(
                        player_id,
                        REWARD_SFX
                    )

                    await(Async.message_player(
                        player_id,
                        "Got " .. tostring(money) .. "z!"
                    ))

                    ezmemory.set_direction_anim(
                        player_id,
                        direction
                    )
                end
            end
        end

        bugfrag_busy[lock] = nil
    end)
end)