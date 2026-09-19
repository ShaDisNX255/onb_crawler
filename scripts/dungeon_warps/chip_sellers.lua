local crawler_whitelist =
    require(
        "scripts/ezlibs-scripts/crawler_whitelist"
    )

local config =
    require(
        "scripts/dungeon_warps/chip_seller_config"
    )


local chip_sellers = {}


-- ============================================================
-- RUN-TIME SELLER STATE
-- ============================================================
--
-- We currently allow at most one chip seller per generated area,
-- so the runtime area ID is the seller's unique key.
--
-- Runtime dungeon area IDs already include the run ID, so stock
-- cannot accidentally bleed between active runs.
-- ============================================================

local seller_stock_by_area = {}


-- ============================================================
-- HELPERS
-- ============================================================

local function get_mugshot_paths(
    mugshot
)
    if not mugshot then
        return nil, nil
    end

    return
        mugshot.texture_path,
        mugshot.animation_path
end


local function message_player(
    player_id,
    text,
    mugshot
)
    local texture_path,
        animation_path =
        get_mugshot_paths(
            mugshot
        )

    return Async.message_player(
        player_id,
        text,
        texture_path,
        animation_path
    )
end


local function question_player(
    player_id,
    text,
    mugshot
)
    local texture_path,
        animation_path =
        get_mugshot_paths(
            mugshot
        )

    return Async.question_player(
        player_id,
        text,
        texture_path,
        animation_path
    )
end


local function quiz_player(
    player_id,
    option_a,
    option_b,
    option_c,
    mugshot
)
    local texture_path,
        animation_path =
        get_mugshot_paths(
            mugshot
        )

    return Async.quiz_player(
        player_id,
        option_a,
        option_b,
        option_c,
        texture_path,
        animation_path
    )
end


local function shuffle(
    values
)
    for index =
        #values,
        2,
        -1
    do
        local swap_index =
            math.random(
                1,
                index
            )

        values[index],
        values[swap_index] =
            values[swap_index],
            values[index]
    end

    return values
end


local function get_display_name(
    chip_key
)
    local card_def =
        crawler_whitelist.get_card_def(
            chip_key
        )

    if card_def
        and card_def.display_name
    then
        return card_def.display_name
    end

    return chip_key
end


local function get_price(
    chip_key
)
    if config.debug_cheap_prices then
        return config.debug_price
    end

    local chip_config =
        config.chips[
            chip_key
        ]

    if not chip_config then
        return nil
    end

    return chip_config.price
end


local function build_stock_pool()
    local pool = {}

    for chip_key,
        chip_config
        in pairs(
            config.chips
        )
    do
        local card_def =
            crawler_whitelist.get_card_def(
                chip_key
            )

        if not card_def then
            print(
                "[chip_sellers] skipping unknown whitelist chip " ..
                tostring(chip_key)
            )

        elseif not crawler_whitelist.card_allows_source(
            chip_key,
            "chip_seller"
        ) then
            print(
                "[chip_sellers] skipping chip without chip_seller source " ..
                tostring(chip_key)
            )

        elseif type(
            chip_config.option_name
        ) ~= "string" then
            print(
                "[chip_sellers] skipping chip with missing option_name " ..
                tostring(chip_key)
            )

        elseif #chip_config.option_name
            > config.max_option_label_length
        then
            print(
                "[chip_sellers] skipping chip with long option_name " ..
                tostring(chip_key) ..
                ": " ..
                chip_config.option_name
            )

        else
            pool[
                #pool + 1
            ] =
                chip_key
        end
    end

    return pool
end


-- ============================================================
-- STOCK CREATION
-- ============================================================

local function create_stock(
    area_id
)
    local run_id =
        Net.get_area_custom_property(
            area_id,
            "dungeon_run_id"
        )

    if not run_id then
        print(
            "[chip_sellers] seller area has no dungeon_run_id: " ..
            tostring(area_id)
        )

        return nil
    end


    local pool =
        build_stock_pool()

    if #pool == 0 then
        print(
            "[chip_sellers] no valid seller chips configured"
        )

        return nil
    end


    shuffle(
        pool
    )


    local stock_count = 1

    if #pool >= 2
        and math.random()
            < config.two_chip_chance
    then
        stock_count = 2
    end


    local stock = {
        pool[1],
    }

    if stock_count == 2 then
        stock[2] =
            pool[2]
    end


    local state = {
        run_id =
            tostring(
                run_id
            ),

        chips =
            stock,
    }


    seller_stock_by_area[
        area_id
    ] =
        state


    print(
        "[chip_sellers] created stock for " ..
        tostring(area_id) ..
        " run=" ..
        tostring(run_id) ..
        " chips=" ..
        table.concat(
            stock,
            ", "
        )
    )


    return state
end


local function get_or_create_stock(
    area_id
)
    local run_id =
        Net.get_area_custom_property(
            area_id,
            "dungeon_run_id"
        )

    if not run_id then
        return nil
    end


    local existing =
        seller_stock_by_area[
            area_id
        ]

    if existing
        and tostring(
            existing.run_id
        ) == tostring(
            run_id
        )
    then
        return existing
    end


    return create_stock(
        area_id
    )
end


-- ============================================================
-- PURCHASE
-- ============================================================

local function try_purchase(
    player_id,
    chip_key,
    mugshot
)
    local display_name =
        get_display_name(
            chip_key
        )


    if crawler_whitelist.player_has_card_unlocked(
        player_id,
        chip_key
    ) then
        await(
            message_player(
                player_id,
                "You already have " ..
                    display_name ..
                    ".",
                mugshot
            )
        )

        return false
    end


    local price =
        get_price(
            chip_key
        )

    if not price then
        print(
            "[chip_sellers] missing price for " ..
            tostring(chip_key)
        )

        await(
            message_player(
                player_id,
                "Sorry, I can't sell that chip right now.",
                mugshot
            )
        )

        return false
    end


    local money =
        Net.get_player_money(
            player_id
        ) or 0


    if money < price then
        await(
            message_player(
                player_id,
                "Not enough money! You need " ..
                    tostring(price) ..
                    "z.",
                mugshot
            )
        )

        return false
    end


    -- Unlock first.
    --
    -- We already verified ownership and money above, so the
    -- player is only charged if the whitelist actually accepts
    -- this chip from the chip_seller source.
    local unlocked,
        reason =
        crawler_whitelist.unlock_card_from_source(
            player_id,
            chip_key,
            "chip_seller"
        )


    if not unlocked then
        if reason == "already_unlocked" then
            await(
                message_player(
                    player_id,
                    "You already have " ..
                        display_name ..
                        ".",
                    mugshot
                )
            )
        else
            print(
                "[chip_sellers] failed unlocking " ..
                tostring(chip_key) ..
                " for " ..
                tostring(player_id) ..
                ": " ..
                tostring(reason)
            )

            await(
                message_player(
                    player_id,
                    "Sorry, I can't sell that chip right now.",
                    mugshot
                )
            )
        end

        return false
    end


    Net.set_player_money(
        player_id,
        money - price
    )


    -- --------------------------------------------------------
    -- PURCHASE FEEDBACK
    -- --------------------------------------------------------

    if
        config.purchase_sfx_path
        and config.purchase_sfx_path ~= ""
    then
        local provided,
            provide_error =
            pcall(
                Net.provide_asset_for_player,
                player_id,
                config.purchase_sfx_path
            )

        if not provided then
            print(
                "[chip_sellers] warning: could not provide purchase SFX: " ..
                tostring(
                    provide_error
                )
            )
        end


        local played,
            play_error =
            pcall(
                Net.play_sound_for_player,
                player_id,
                config.purchase_sfx_path
            )

        if not played then
            print(
                "[chip_sellers] warning: could not play purchase SFX: " ..
                tostring(
                    play_error
                )
            )
        end
    end


    await(
        message_player(
            player_id,
            'Bought "' ..
                display_name ..
                '" for ' ..
                tostring(price) ..
                "z!",
            mugshot
        )
    )


    print(
        "[chip_sellers] " ..
        tostring(player_id) ..
        " bought " ..
        tostring(chip_key) ..
        " for " ..
        tostring(price)
    )


    return true
end


local function confirm_purchase(
    player_id,
    chip_key,
    mugshot
)
    local display_name =
        get_display_name(
            chip_key
        )

    local price =
        get_price(
            chip_key
        )

    if not price then
        return
    end


    local response =
        await(
            question_player(
                player_id,
                'Buy "' ..
                    display_name ..
                    '" for ' ..
                    tostring(price) ..
                    "z?",
                mugshot
            )
        )


    -- Player disconnected.
    if response == nil then
        return
    end


    -- question_player:
    -- 1 = Yes
    -- 0 = No
    if response ~= 1 then
        return
    end


    try_purchase(
        player_id,
        chip_key,
        mugshot
    )
end


-- ============================================================
-- INTERACTION
-- ============================================================

function chip_sellers.interact(
    player_id,
    dialogue,
    mugshot
)
    return async(
        function()
            local area_id =
                Net.get_player_area(
                    player_id
                )

            if not area_id then
                return nil
            end


            local seller =
                get_or_create_stock(
                    area_id
                )

            if not seller
                or not seller.chips
                or #seller.chips == 0
            then
                await(
                    message_player(
                        player_id,
                        "Sorry, I'm out of stock.",
                        mugshot
                    )
                )

                return
                    dialogue.custom_properties[
                        "Next 1"
                    ]
            end


            -- ==================================================
            -- ONE CHIP
            -- ==================================================

            if #seller.chips == 1 then
                confirm_purchase(
                    player_id,
                    seller.chips[1],
                    mugshot
                )

                return
                    dialogue.custom_properties[
                        "Next 1"
                    ]
            end


            -- ==================================================
            -- TWO CHIPS
            -- ==================================================

            await(
                message_player(
                    player_id,
                    "I sell chips. Want to buy one?",
                    mugshot
                )
            )


            local first_key =
                seller.chips[1]

            local second_key =
                seller.chips[2]


            local first_config =
                config.chips[
                    first_key
                ]

            local second_config =
                config.chips[
                    second_key
                ]


            local response =
                await(
                    quiz_player(
                        player_id,
                        first_config.option_name,
                        second_config.option_name,
                        "Cancel",
                        mugshot
                    )
                )


            if response == nil then
                return nil
            end


            -- quiz_player uses zero-based option indexes:
            --
            -- 0 = first option
            -- 1 = second option
            -- 2 = Cancel

            if response == 0 then
                confirm_purchase(
                    player_id,
                    first_key,
                    mugshot
                )

            elseif response == 1 then
                confirm_purchase(
                    player_id,
                    second_key,
                    mugshot
                )
            end


            return
                dialogue.custom_properties[
                    "Next 1"
                ]
        end
    )
end


-- ============================================================
-- RUN CLEANUP
-- ============================================================

function chip_sellers.clear_run(
    run_id
)
    local run_string =
        tostring(
            run_id
        )

    for area_id,
        seller
        in pairs(
            seller_stock_by_area
        )
    do
        if tostring(
            seller.run_id
        ) == run_string
        then
            seller_stock_by_area[
                area_id
            ] =
                nil
        end
    end


    print(
        "[chip_sellers] cleared seller stock for run " ..
        run_string
    )
end


return chip_sellers