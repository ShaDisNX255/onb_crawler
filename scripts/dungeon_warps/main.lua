local warp_history = {}

-- One dungeon run is shared by everybody.
-- Each player still has an independent return history.
local active_run = nil
local next_run_id = 0

-- Temporary while we prove arbitrary-depth generation.
local TEST_MAX_FLOORS = 5
local IS_WINDOWS = package.config:sub(1, 1) == "\\"

local NODE_EXE

if IS_WINDOWS then
    -- Short Windows path avoids cmd.exe quoting problems.
    NODE_EXE = [[C:\Progra~1\nodejs\node.exe]]
else
    -- Raspberry Pi / Linux.
    NODE_EXE = "node"
end

local function create_run_id()
    next_run_id = next_run_id + 1

    return tostring(os.time()) .. "_" .. tostring(next_run_id)
end


local function make_floor_area_id(run_id, floor_number)
    return string.format(
        "dungeon_%s_f%03d",
        run_id,
        floor_number
    )
end


local function read_text_file(path)
    local file, err = io.open(path, "rb")

    if not file then
        print(
            "[dungeon_warps] unable to read " ..
            path ..
            ": " ..
            tostring(err)
        )

        return nil
    end

    local contents = file:read("*a")
    file:close()

    return contents
end


local function get_history(player_id)
    local history = warp_history[player_id]

    if not history then
        history = {}
        warp_history[player_id] = history
    end

    return history
end


local function push_history(player_id, area_id, object_id)
    local history = get_history(player_id)

    -- Prevent duplicate pushes if the warp collision fires more than once
    -- before the transfer finishes.
    local previous = history[#history]

    if previous
        and previous.area_id == area_id
        and previous.object_id == object_id
    then
        return
    end

    history[#history + 1] = {
        area_id = area_id,
        object_id = object_id
    }

    print(
        "[dungeon_warps] pushed source warp " ..
        area_id ..
        ":" ..
        object_id ..
        " for " ..
        player_id ..
        " depth=" ..
        #history
    )
end


local function get_entry_object_id(area_id)
    local entry_id = Net.get_area_custom_property(
        area_id,
        "entry_warp_id"
    )

    if not entry_id then
        return nil
    end

    return tonumber(entry_id)
end


local function transfer_to_entry(player_id, area_id)
    local entry_id = get_entry_object_id(area_id)

    if not entry_id then
        print(
            "[dungeon_warps] no entry_warp_id for " ..
            area_id
        )

        return false
    end

    local destination = Net.get_object_by_id(
        area_id,
        entry_id
    )

    if not destination then
        print(
            "[dungeon_warps] entry object " ..
            entry_id ..
            " missing from " ..
            area_id
        )

        return false
    end

    local direction =
        destination.custom_properties
        and destination.custom_properties["Direction"]
        or "Down"

    Net.transfer_player(
        player_id,
        area_id,
        true,
        destination.x + 0.5,
        destination.y + 0.5,
        destination.z,
        direction
    )

    return true
end


local function generate_floor(run_id, floor_number)
    local area_id =
        make_floor_area_id(
            run_id,
            floor_number
        )

    local has_next =
        floor_number < TEST_MAX_FLOORS

    local map_path =
        "./areas/" ..
        area_id ..
        ".tmx"

    -- This should normally not exist because run IDs are unique,
    -- but removing it avoids accidentally loading stale data.
    os.remove(map_path)

    local command =
        NODE_EXE ..
        ' "tools/dungeon-generator/generate_floor.js" "' ..
        area_id ..
        '" "' ..
        run_id ..
        '" "' ..
        tostring(floor_number) ..
        '" "' ..
        (has_next and "1" or "0") ..
        '"'

    print(
        "[dungeon_warps] generating floor " ..
        floor_number ..
        " for run " ..
        run_id
    )

    local success, reason, code =
        os.execute(command)

    -- Handle both Lua-style os.execute return formats.
    local command_ok =
        success == true or success == 0

    if not command_ok or (code and code ~= 0) then
        print(
            "[dungeon_warps] generator failed: " ..
            tostring(reason) ..
            " " ..
            tostring(code)
        )

        return nil
    end

    local map_string =
        read_text_file(map_path)

    if not map_string then
        print(
            "[dungeon_warps] generated TMX could not be read: " ..
            map_path
        )

        return nil
    end

    local update_ok, update_err =
        pcall(
            Net.update_area,
            area_id,
            map_string
        )

    if not update_ok then
        print(
            "[dungeon_warps] failed loading generated floor: " ..
            tostring(update_err)
        )

        return nil
    end

    print(
        "[dungeon_warps] generated and loaded " ..
        area_id
    )

    print(
        "[dungeon_warps] generation date: " ..
        tostring(
            Net.get_area_custom_property(
                area_id,
                "Generation Date"
            )
        )
    )

    return area_id
end


local function create_active_run()
    local run_id = create_run_id()

    print(
        "[dungeon_warps] creating shared dungeon run " ..
        run_id
    )

    -- Only Floor 1 exists initially.
    -- Deeper floors are generated when somebody reaches them.
    local floor1 =
        generate_floor(
            run_id,
            1
        )

    if not floor1 then
        print(
            "[dungeon_warps] failed to create first floor"
        )

        return nil
    end

    active_run = {
        run_id = run_id,

        floors = {
            [1] = floor1,
        },

        areas = {
            floor1,
        }
    }

    print(
        "[dungeon_warps] shared dungeon run ready: " ..
        run_id
    )

    return active_run
end


local function get_active_run()
    if active_run then
        return active_run
    end

    return create_active_run()
end


local function run_has_players(run, ignored_player_id)
    if not run then
        return false
    end

    for _, area_id in ipairs(run.areas) do
        local players = Net.list_players(area_id)

        for _, player_id in ipairs(players) do
            if player_id ~= ignored_player_id then
                return true
            end
        end
    end

    return false
end


local function destroy_active_run()
    local run = active_run

    if not run then
        return
    end

    -- Clear this first so nobody new gets sent into areas
    -- while they are being removed.
    active_run = nil

    for _, area_id in ipairs(run.areas) do
        Net.remove_area(area_id)

        local map_path =
            "./areas/" ..
            area_id ..
            ".tmx"

        local removed, remove_err =
            os.remove(map_path)

        if removed then
            print(
                "[dungeon_warps] deleted generated file " ..
                map_path
            )
        elseif remove_err then
            print(
                "[dungeon_warps] could not delete " ..
                map_path ..
                ": " ..
                tostring(remove_err)
            )
        end
    end

    print(
        "[dungeon_warps] destroyed empty shared run " ..
        run.run_id
    )
end


local function cleanup_active_run_if_empty(ignored_player_id)
    if not active_run then
        return
    end

    if run_has_players(
        active_run,
        ignored_player_id
    ) then
        return
    end

    destroy_active_run()
end


print("[dungeon_warps] Started!")


Net:on("custom_warp", function(event)
    local player_id = event.player_id
    local area_id = Net.get_player_area(player_id)

    local object = Net.get_object_by_id(
        area_id,
        event.object_id
    )

    if not object or not object.custom_properties then
        return
    end

    local props = object.custom_properties


    -- ==============================================================
    -- DUNGEON ENTRANCE
    -- ==============================================================

    -- The first player creates the shared dungeon.
    -- Everybody else joins that same active dungeon.
    if props["is_dungeon_entrance"] then
        local run = get_active_run()

        if not run then
            print(
                "[dungeon_warps] unable to create dungeon run for " ..
                player_id
            )

            return
        end

        push_history(
            player_id,
            area_id,
            object.id
        )

        print(
            "[dungeon_warps] " ..
            player_id ..
            " entering shared run " ..
            run.run_id
        )

        transfer_to_entry(
            player_id,
            run.floors[1]
        )

        return
    end


    -- ==============================================================
    -- GO DEEPER
    -- ==============================================================

    if props["is_dungeon_forward"] then
        if not active_run then
            print(
                "[dungeon_warps] forward warp used with no active run"
            )

            return
        end

        local current_floor =
            tonumber(
                Net.get_area_custom_property(
                    area_id,
                    "dungeon_floor"
                )
            )

        if not current_floor then
            print(
                "[dungeon_warps] current area has no dungeon_floor property"
            )

            return
        end

        local next_floor =
            current_floor + 1

        if next_floor > TEST_MAX_FLOORS then
            print(
                "[dungeon_warps] floor " ..
                current_floor ..
                " is currently the deepest floor"
            )

            return
        end

        local next_area =
            active_run.floors[next_floor]

        -- The first person to reach this depth generates it.
        if not next_area then
            print(
                "[dungeon_warps] first player reached floor " ..
                next_floor ..
                "; generating it now"
            )

            next_area =
                generate_floor(
                    active_run.run_id,
                    next_floor
                )

            if not next_area then
                print(
                    "[dungeon_warps] failed to generate floor " ..
                    next_floor
                )

                return
            end

            active_run.floors[next_floor] =
                next_area

            active_run.areas[
                #active_run.areas + 1
            ] = next_area

            print(
                "[dungeon_warps] floor " ..
                next_floor ..
                " added to shared run " ..
                active_run.run_id
            )
        else
            print(
                "[dungeon_warps] floor " ..
                next_floor ..
                " already exists; reusing it"
            )
        end

        push_history(
            player_id,
            area_id,
            object.id
        )

        transfer_to_entry(
            player_id,
            next_area
        )

        return
    end


    -- ==============================================================
    -- GO BACK
    -- ==============================================================

    if props["is_back_link"] then
        local history =
            warp_history[player_id]

        local previous =
            history and history[#history]

        if not previous then
            print(
                "[dungeon_warps] no previous warp stored for " ..
                player_id
            )

            return
        end

        local destination =
            Net.get_object_by_id(
                previous.area_id,
                previous.object_id
            )

        if not destination then
            print(
                "[dungeon_warps] previous warp no longer exists"
            )

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

        table.remove(history)

        if #history == 0 then
            warp_history[player_id] = nil
        end

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
end)


Net:on("player_area_transfer", function(event)
    -- If somebody simply moved between dungeon floors,
    -- another dungeon area will still contain them.
    --
    -- If the last player returned to the overworld,
    -- this destroys the completed/abandoned run.
    cleanup_active_run_if_empty()
end)


Net:on("player_disconnect", function(event)
    local player_id = event.player_id

    warp_history[player_id] = nil

    print(
        "[dungeon_warps] cleared warp history for disconnected player " ..
        player_id
    )

    -- The disconnecting player may still appear in Net.list_players()
    -- during this callback, so explicitly ignore them.
    cleanup_active_run_if_empty(player_id)
end)