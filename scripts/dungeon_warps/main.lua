local warp_history = {}

-- One dungeon run is shared by everybody.
-- Each player still has an independent return history.
local active_run = nil
local next_run_id = 0

-- IMPORTANT:
-- Every top-level server script runs in its own Lua state.
-- This eznpcs instance owns the dynamically-created dungeon NPCs,
-- so this script must also forward interaction/tick/transfer events to it.
local eznpcs = require('scripts/ezlibs-scripts/eznpcs/eznpcs')

-- dialogue_types.lua expects eznpcs to exist globally.
_G.eznpcs = eznpcs

require('scripts/events/eznpcs_events')

-- ==============================================================
-- TEST CONFIGURATION
-- ==============================================================

-- Depth 0 is the root room.
-- Current test: depth 0 through depth 5.
local TEST_MAX_DEPTH = 5
local TEST_MIN_BRANCHES = 1
local TEST_MAX_BRANCHES = 4
local DUNGEON_POOL_SIZE = 5

-- TEMPORARY:
-- 1.0 guarantees Regular -> Lobby -> Regular -> Lobby...
-- Once everything works, change this to 0.15.
local LOBBY_ROOM_CHANCE = 0.15

-- ==============================================================
-- RUN / ROOM IDS
-- ==============================================================

local function create_run_id()
    next_run_id = next_run_id + 1
    return tostring(os.time()) .. "_" .. tostring(next_run_id)
end

local function make_room_area_id(run_id, room_id)
    return string.format("dungeon_%s_r%03d", run_id, room_id)
end

-- ==============================================================
-- FILE HELPERS
-- ==============================================================

local function read_text_file(path)
    local file, err = io.open(path, "rb")

    if not file then
        print("[dungeon_warps] unable to read " .. path .. ": " .. tostring(err))
        return nil
    end

    local contents = file:read("*a")
    file:close()
    return contents
end

-- ==============================================================
-- POOL PATH HELPERS
-- ==============================================================

local function get_pool_slot_path(room_type, exit_count, slot_number)
    return string.format(
        "./runtime/dungeon_pool/%s/%d/slot_%02d.tmx",
        room_type,
        exit_count,
        slot_number
    )
end

local function get_claimed_layout_path(room_type, exit_count, run_id, room_id, slot_number)
    return string.format(
        "./runtime/dungeon_pool/%s/%d/claimed_%s_r%03d_%02d.tmx",
        room_type,
        exit_count,
        run_id,
        room_id,
        slot_number
    )
end

-- ==============================================================
-- CLAIM A CACHED LAYOUT
-- ==============================================================

local function claim_layout(room_type, exit_count, run_id, room_id)
    local starting_slot = math.random(1, DUNGEON_POOL_SIZE)

    for offset = 0, DUNGEON_POOL_SIZE - 1 do
        local slot_number = ((starting_slot + offset - 1) % DUNGEON_POOL_SIZE) + 1
        local source_path = get_pool_slot_path(room_type, exit_count, slot_number)
        local claimed_path = get_claimed_layout_path(
            room_type,
            exit_count,
            run_id,
            room_id,
            slot_number
        )

        if os.rename(source_path, claimed_path) then
            print(
                "[dungeon_warps] claimed " ..
                room_type .. " " ..
                exit_count .. "-exit layout slot " ..
                slot_number
            )

            return claimed_path
        end
    end

    return nil
end

-- ==============================================================
-- PLAYER BACKTRACK HISTORY
-- ==============================================================

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
    local previous = history[#history]

    -- Prevent duplicate pushes if the warp collision fires more
    -- than once before the transfer finishes.
    if previous
        and previous.area_id == area_id
        and previous.object_id == object_id
    then
        return
    end

    history[#history + 1] = {
        area_id = area_id,
        object_id = object_id,
    }

    print(
        "[dungeon_warps] pushed source warp " ..
        area_id .. ":" .. object_id ..
        " for " .. player_id ..
        " depth=" .. #history
    )
end

-- ==============================================================
-- ENTRY WARP
-- ==============================================================

local function get_entry_object_id(area_id)
    local entry_id = Net.get_area_custom_property(area_id, "entry_warp_id")

    if not entry_id then
        return nil
    end

    return tonumber(entry_id)
end

local function transfer_to_entry(player_id, area_id)
    local entry_id = get_entry_object_id(area_id)

    if not entry_id then
        print("[dungeon_warps] no entry_warp_id for " .. area_id)
        return false
    end

    local destination = Net.get_object_by_id(area_id, entry_id)

    if not destination then
        print(
            "[dungeon_warps] entry object " ..
            tostring(entry_id) ..
            " missing from " ..
            area_id
        )
        return false
    end

    local direction = destination.custom_properties
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

-- ==============================================================
-- ROOM TYPE SELECTION
-- ==============================================================

local function choose_child_room_type(parent_room)
    -- Never generate two lobby rooms back-to-back.
    if parent_room and parent_room.room_type == "lobby" then
        return "regular"
    end

    if math.random() < LOBBY_ROOM_CHANCE then
        return "lobby"
    end

    return "regular"
end

-- ==============================================================
-- ROOM GENERATION / CACHE CONSUMPTION
-- ==============================================================

local function generate_room(run_id, room_id, depth, room_type)
    room_type = room_type or "regular"

    local area_id = make_room_area_id(run_id, room_id)
    local exit_count = 0

    if depth < TEST_MAX_DEPTH then
        exit_count = math.random(TEST_MIN_BRANCHES, TEST_MAX_BRANCHES)
    end

    print(
        "[dungeon_warps] preparing room " ..
        room_id ..
        " depth=" .. depth ..
        " type=" .. room_type ..
        " exits=" .. exit_count
    )

    local layout_path = claim_layout(
        room_type,
        exit_count,
        run_id,
        room_id
    )

    if not layout_path then
        print(
            "[dungeon_warps] no ready " ..
            room_type .. " " ..
            exit_count ..
            "-exit layouts available"
        )
        return nil
    end

    local map_string = read_text_file(layout_path)

    if not map_string then
        os.remove(layout_path)
        return nil
    end

    local update_ok, update_err = pcall(
        Net.update_area,
        area_id,
        map_string
    )

    if not update_ok then
        print(
            "[dungeon_warps] failed loading cached room: " ..
            tostring(update_err)
        )
        os.remove(layout_path)
        return nil
    end

    local display_name

    if room_type == "lobby" then
        display_name = string.format(
            "Rest %d-%02d",
            depth,
            room_id
        )
    else
        display_name = string.format(
            "Area %d-%02d",
            depth,
            room_id
        )
    end

    Net.set_area_name(area_id, display_name)

    Net.set_area_custom_property(area_id, "dungeon_run_id", run_id)
    Net.set_area_custom_property(area_id, "dungeon_room_id", tostring(room_id))
    Net.set_area_custom_property(area_id, "dungeon_depth", tostring(depth))
    Net.set_area_custom_property(area_id, "dungeon_exit_count", tostring(exit_count))
    Net.set_area_custom_property(area_id, "dungeon_room_type", room_type)

    -- The area did not exist during ezlibs startup, so this Lua
    -- state explicitly scans the new map's NPC placeholders.
    local npc_ok, npc_err = pcall(
        eznpcs.add_npcs_to_area,
        area_id
    )

    if not npc_ok then
        print(
            "[dungeon_warps] failed adding NPCs to " ..
            area_id .. ": " ..
            tostring(npc_err)
        )
    end

    -- Net.update_area() has already parsed the map. Removing this
    -- claimed file lets generator_server refill the missing slot.
    os.remove(layout_path)

    print(
        "[dungeon_warps] loaded cached room " ..
        room_id ..
        " as " .. area_id ..
        " depth=" .. depth ..
        " type=" .. room_type ..
        " exits=" .. exit_count
    )

    return {
        room_id = room_id,
        area_id = area_id,
        depth = depth,
        room_type = room_type,
        exit_count = exit_count,
        children = {},
    }
end

-- ==============================================================
-- CREATE SHARED RUN
-- ==============================================================

local function create_active_run()
    local run_id = create_run_id()

    print("[dungeon_warps] creating shared dungeon run " .. run_id)

    -- The starting map is always a regular dungeon room.
    local root_room = generate_room(
        run_id,
        1,
        0,
        "regular"
    )

    if not root_room then
        print("[dungeon_warps] failed to create root room")
        return nil
    end

    active_run = {
        run_id = run_id,
        root_room_id = 1,
        next_room_id = 2,
        rooms = {
            [1] = root_room,
        },
        areas = {
            root_room.area_id,
        },
    }

    print("[dungeon_warps] shared dungeon run ready: " .. run_id)
    return active_run
end

local function get_active_run()
    if active_run then
        return active_run
    end

    return create_active_run()
end

-- ==============================================================
-- RUN CLEANUP
-- ==============================================================

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

    -- Clear this before removing areas so nobody new can
    -- accidentally join a run being destroyed.
    active_run = nil

    for _, area_id in ipairs(run.areas) do
        Net.remove_area(area_id)
    end

    print(
        "[dungeon_warps] destroyed empty shared run " ..
        run.run_id ..
        " rooms=" .. #run.areas
    )
end

local function cleanup_active_run_if_empty(ignored_player_id)
    if not active_run then
        return
    end

    if run_has_players(active_run, ignored_player_id) then
        return
    end

    destroy_active_run()
end

-- ==============================================================
-- START
-- ==============================================================

print("[dungeon_warps] Started!")

-- ==============================================================
-- EZNPCS EVENT FORWARDING
-- ==============================================================
--
-- The server creates a separate Lua VM for every top-level script.
-- The normal ezlibs main.lua therefore cannot see the NPC table
-- owned by this dungeon_warps copy of eznpcs.
--
-- Forward these events here so dynamically-generated dungeon NPCs
-- are handled by the same eznpcs instance that created them.
-- ==============================================================

Net:on("actor_interaction", function(event)
    eznpcs.handle_actor_interaction(
        event.player_id,
        event.actor_id
    )
end)

Net:on("tick", function(event)
    eznpcs.on_tick(event.delta_time)
end)

-- ==============================================================
-- CUSTOM WARPS
-- ==============================================================

Net:on("custom_warp", function(event)
    local player_id = event.player_id
    local area_id = Net.get_player_area(player_id)
    local object = Net.get_object_by_id(area_id, event.object_id)

    if not object or not object.custom_properties then
        return
    end

    local props = object.custom_properties

    -- ==========================================================
    -- DUNGEON ENTRANCE
    -- ==========================================================

    if props["is_dungeon_entrance"] then
        local run = get_active_run()

        if not run then
            print(
                "[dungeon_warps] unable to create dungeon run for " ..
                player_id
            )
            return
        end

        local root_room = run.rooms[run.root_room_id]

        if not root_room then
            print("[dungeon_warps] active run has no root room")
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
            run.run_id ..
            " at room " ..
            root_room.room_id ..
            " type=" ..
            root_room.room_type
        )

        transfer_to_entry(
            player_id,
            root_room.area_id
        )

        return
    end

    -- ==========================================================
    -- BRANCH / FORWARD WARP
    -- ==========================================================

    if props["is_dungeon_forward"] then
        if not active_run then
            print("[dungeon_warps] branch warp used with no active run")
            return
        end

        local area_run_id = Net.get_area_custom_property(
            area_id,
            "dungeon_run_id"
        )

        if tostring(area_run_id) ~= tostring(active_run.run_id) then
            print("[dungeon_warps] branch warp belongs to another dungeon run")
            return
        end

        local current_room_id = tonumber(
            Net.get_area_custom_property(
                area_id,
                "dungeon_room_id"
            )
        )

        local branch_id = tonumber(
            props["dungeon_branch"]
        )

        if not current_room_id or not branch_id then
            print(
                "[dungeon_warps] branch warp is missing room/branch information"
            )
            return
        end

        local current_room = active_run.rooms[current_room_id]

        if not current_room then
            print(
                "[dungeon_warps] unknown dungeon room " ..
                tostring(current_room_id)
            )
            return
        end

        local child_room_id = current_room.children[branch_id]
        local child_room

        -- Existing branch.
        if child_room_id then
            child_room = active_run.rooms[child_room_id]

            if not child_room then
                print(
                    "[dungeon_warps] branch references missing room " ..
                    tostring(child_room_id)
                )
                return
            end

            print(
                "[dungeon_warps] reusing room " ..
                child_room_id ..
                " from room " ..
                current_room_id ..
                " branch " ..
                branch_id ..
                " type=" ..
                child_room.room_type
            )

        -- Unexplored branch.
        else
            local child_depth = current_room.depth + 1

            if child_depth > TEST_MAX_DEPTH then
                print(
                    "[dungeon_warps] branch would exceed maximum test depth"
                )
                return
            end

            child_room_id = active_run.next_room_id

            local child_room_type = choose_child_room_type(
                current_room
            )

            print(
                "[dungeon_warps] unexplored branch: room " ..
                current_room_id ..
                " branch " ..
                branch_id ..
                " -> room " ..
                child_room_id ..
                " type=" ..
                child_room_type
            )

            child_room = generate_room(
                active_run.run_id,
                child_room_id,
                child_depth,
                child_room_type
            )

            if not child_room then
                print("[dungeon_warps] failed generating branch room")
                return
            end

            -- Only consume the room ID after successful load.
            active_run.next_room_id = child_room_id + 1
            active_run.rooms[child_room_id] = child_room
            current_room.children[branch_id] = child_room_id
            active_run.areas[#active_run.areas + 1] = child_room.area_id

            print(
                "[dungeon_warps] room " ..
                current_room_id ..
                " branch " ..
                branch_id ..
                " generated room " ..
                child_room_id ..
                " depth=" ..
                child_depth ..
                " type=" ..
                child_room_type
            )
        end

        push_history(
            player_id,
            area_id,
            object.id
        )

        transfer_to_entry(
            player_id,
            child_room.area_id
        )

        return
    end

    -- ==========================================================
    -- BACKLINK
    -- ==========================================================

    if props["is_back_link"] then
        local history = warp_history[player_id]
        local previous = history and history[#history]

        if not previous then
            print(
                "[dungeon_warps] no previous warp stored for " ..
                player_id
            )
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

        local direction = destination.custom_properties
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

-- ==============================================================
-- PLAYER AREA TRANSFER
-- ==============================================================

Net:on("player_area_transfer", function(event)
    -- Clear any conversation state owned by this eznpcs instance.
    eznpcs.handle_player_transfer(event.player_id)

    -- Moving from one dungeon room to another leaves at least one
    -- player in active_run.areas. Returning the final player to the
    -- overworld destroys the shared runtime dungeon.
    cleanup_active_run_if_empty()
end)

-- ==============================================================
-- PLAYER DISCONNECT
-- ==============================================================

Net:on("player_disconnect", function(event)
    local player_id = event.player_id

    -- Clean up conversation/exclusive-NPC state owned by this
    -- dungeon_warps eznpcs instance.
    eznpcs.handle_player_disconnect(player_id)

    warp_history[player_id] = nil

    print(
        "[dungeon_warps] cleared warp history for disconnected player " ..
        player_id
    )

    -- The disconnecting player can still appear in
    -- Net.list_players() during this callback.
    cleanup_active_run_if_empty(player_id)
end)
