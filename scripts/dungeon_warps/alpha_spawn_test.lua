local ENABLED = false

if not ENABLED then
    return
end
local AREA_ID = "default"
local TEST_POINT_NAME = "TestAlphaHere"

local ALPHA_GID = 53

-- Alpha uses objectalignment="bottomright".
-- Start by shifting half of its 84px width to the right.
local OFFSET_X = 0.3
local OFFSET_Y = -1

local existing =
    Net.get_object_by_name(
        AREA_ID,
        "AlphaSpawnTest"
    )

if existing then
    Net.remove_object(
        AREA_ID,
        existing.id
    )
end

local marker =
    Net.get_object_by_name(
        AREA_ID,
        TEST_POINT_NAME
    )

if not marker then
    print(
        "[alpha_spawn_test] missing point: " ..
        TEST_POINT_NAME
    )

    return
end

local object_id =
    Net.create_object(
        AREA_ID,
        {
            name = "AlphaSpawnTest",
            class = "AlphaSpawnTest",

            visible = true,

            x = marker.x + OFFSET_X,
            y = marker.y + OFFSET_Y,
            z = marker.z,

            width = 84 / 32,
            height = 103 / 32,

            data = {
                type = "tile",
                gid = ALPHA_GID,
            },

            custom_properties = {},
        }
    )

print(
    "[alpha_spawn_test] spawned Alpha at marker=(" ..
    tostring(marker.x) .. "," ..
    tostring(marker.y) ..
    ") offset=(" ..
    tostring(OFFSET_X) .. "," ..
    tostring(OFFSET_Y) ..
    ") object_id=" ..
    tostring(object_id)
)