local eznpcs =
    require(
        'scripts/ezlibs-scripts/eznpcs/eznpcs'
    )

local ezmemory =
    require(
        'scripts/ezlibs-scripts/ezmemory'
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


            local max_health =
                tonumber(
                    ezmemory.get_player_max_health(
                        player_id
                    )
                )
                or
                tonumber(
                    Net.get_player_max_health(
                        player_id
                    )
                )


            if max_health then
                ezmemory.set_player_health(
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


eznpcs.add_event(
    dungeon_heal
)
