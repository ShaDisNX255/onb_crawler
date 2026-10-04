local M = {}

local function encode(set)
    local out = {}

    for key, value in pairs(set) do
        if value then
            out[#out + 1] = key
        end
    end

    table.sort(out)

    return table.concat(out, ",")
end

function M.create(id, active_copy_limit, legacy_copy_limit)
    return {
        id = id,
        phase = "dormant",
        eligible_players = {},
        defeated_players = {},
        active_copy_limit = active_copy_limit or 1,
        legacy_copy_limit = legacy_copy_limit or 1,
        slot_released = false,
    }
end

function M.activate(scenario)
    if scenario.phase ~= "dormant" then
        return false
    end

    scenario.phase = "active"

    return true
end

function M.enroll(scenario, player_key)
    if scenario.phase ~= "active" or
        not player_key or
        player_key == "" or
        scenario.eligible_players[player_key]
    then
        return false
    end

    scenario.eligible_players[player_key] = true

    return true
end

function M.can_participate(scenario, player_key)
    if not player_key or
        player_key == "" or
        scenario.defeated_players[player_key]
    then
        return false
    end

    if scenario.phase == "active" then
        return true
    end

    return scenario.phase == "legacy" and
        scenario.eligible_players[player_key] == true
end

function M.is_complete(scenario)
    if scenario.phase ~= "legacy" then
        return false
    end

    local found = false

    for player_key in pairs(
        scenario.eligible_players
    ) do
        found = true

        if not scenario.defeated_players[
            player_key
        ] then
            return false
        end
    end

    return found
end

function M.mark_defeated(
    scenario,
    player_key
)
    if not M.can_participate(
        scenario,
        player_key
    ) then
        return false, false, false
    end

    scenario.eligible_players[
        player_key
    ] = true

    scenario.defeated_players[
        player_key
    ] = true

    local first_clear =
        scenario.phase == "active"

    if first_clear then
        scenario.phase = "legacy"
        scenario.slot_released = true
    end

    local finished =
        M.is_complete(scenario)

    if finished then
        scenario.phase = "finished"
    end

    return true, first_clear, finished
end

function M.sync_area(
    scenario,
    area_id
)
    local prefix =
        "crawler_scenario_" ..
        scenario.id ..
        "_"

    Net.set_area_custom_property(
        area_id,
        prefix .. "phase",
        scenario.phase
    )

    Net.set_area_custom_property(
        area_id,
        prefix .. "eligible",
        encode(
            scenario.eligible_players
        )
    )

    Net.set_area_custom_property(
        area_id,
        prefix .. "defeated",
        encode(
            scenario.defeated_players
        )
    )
end

function M.sync_all(
    state,
    scenario
)
    for area_id in pairs(state.areas) do
        M.sync_area(
            scenario,
            area_id
        )
    end
end

return M