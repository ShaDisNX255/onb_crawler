local last_warp = {}
print("[dungeon_warps] Started! ")

Net:on("custom_warp", function(event)
    local player_id = event.player_id
    local area_id = Net.get_player_area(player_id)
    local object = Net.get_object_by_id(area_id, event.object_id)

    if not object or not object.custom_properties then
        return
    end

    local props = object.custom_properties

    -- Generated dungeon back-link.
    if props["is_back_link"] then
        local previous = last_warp[player_id]

        if not previous then
            print("[dungeon_warps] no previous warp stored for " .. player_id)
            return
        end

        local destination = Net.get_object_by_id(
            previous.area_id,
            previous.object_id
        )

        if not destination then
            print("[dungeon_warps] previous warp no longer exists")
            return
        end

        local direction =
            destination.custom_properties
            and destination.custom_properties["Direction"]
            or "Down"

        Net.transfer_player(
            player_id,
            previous.area_id,
            true,
            destination.x + 0.5,
            destination.y + 0.5,
            destination.z,
            direction
        )

        print(
            "[dungeon_warps] returned " ..
            player_id ..
            " to " ..
            previous.area_id ..
            " object " ..
            previous.object_id
        )

        return
    end

    -- Remember normal Custom Warp exits.
    if object.type ~= "Custom Warp" then
        return
    end

    local target_area = props["Target Area"]
    local target_object = props["Target Object"]

    if not target_area or not target_object then
        return
    end

    last_warp[player_id] = {
        area_id = area_id,
        object_id = object.id
    }

    print(
        "[dungeon_warps] remembered source warp " ..
        area_id ..
        ":" ..
        object.id ..
        " for " ..
        player_id
    )
end)
