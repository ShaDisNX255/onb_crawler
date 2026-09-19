local eznpcs =
    require(
        'scripts/ezlibs-scripts/eznpcs/eznpcs'
    )

local chip_sellers =
    require(
        "scripts/dungeon_warps/chip_sellers"
    )

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
            end
        )
    end
)