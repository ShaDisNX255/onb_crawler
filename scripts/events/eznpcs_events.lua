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