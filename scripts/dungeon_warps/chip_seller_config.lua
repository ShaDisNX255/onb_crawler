local config = {}

-- ============================================================
-- DEBUG
-- ============================================================

-- When true, every seller chip costs debug_price.
config.debug_cheap_prices = false
config.debug_price = 50


-- ============================================================
-- PURCHASE FEEDBACK
-- ============================================================

-- Server asset path for the successful-purchase sound.
--
-- Put the .ogg at:
--     assets/sfx/chip_purchase.ogg
--
-- Set this to nil if you temporarily want no sound.
config.purchase_sfx_path =
    "/server/assets/sfx/chip_purchase.ogg"

-- ============================================================
-- STOCK
-- ============================================================

-- 50% of sellers offer one chip.
-- 50% offer two chips.
config.two_chip_chance = 0.50

-- Keep quiz_player labels deliberately tiny.
-- We don't actually know the engine's hard visual limit,
-- so we're being conservative.
config.max_option_label_length = 8


-- ============================================================
-- CHIP PRICES
-- ============================================================
--
-- price:
--     Actual purchase price.
--
-- option_name:
--     Short label used only by quiz_player.
--
-- The full whitelist display_name is still used in the
-- Yes/No confirmation.
--
-- Some prices come directly from BN shops.
-- Others are balancing estimates placed near comparable chips.
-- ============================================================

config.chips = {
    aquasword = {
        price = 6000,
        option_name = "AquaSwrd",
    },

    bigbomb = {
        price = 9000,
        option_name = "BigBomb",
    },

    energybomb = {
        price = 2400,
        option_name = "EnrgBomb",
    },

    flamesword = {
        price = 6000,
        option_name = "FlmSwrd",
    },

    fullcustom = {
        price = 7800,
        option_name = "FullCust",
    },

    gundelsol1 = {
        price = 1000,
        option_name = "GDelSol1",
    },

    gundelsol2 = {
        price = 8400,
        option_name = "GDelSol2",
    },

    gundelsol3 = {
        price = 12000,
        option_name = "GDelSol3",
    },

    longsword = {
        price = 6000,
        option_name = "LongSwrd",
    },

    markvulcan1 = {
        price = 4000,
        option_name = "MarkVul1",
    },

    markvulcan2 = {
        price = 7000,
        option_name = "MarkVul2",
    },

    markvulcan3 = {
        price = 10000,
        option_name = "MarkVul3",
    },

    megaenergybomb = {
        price = 7200,
        option_name = "MegaBomb",
    },

    pulsebeam1 = {
        price = 2500,
        option_name = "Pulse1",
    },

    pulsebeam2 = {
        price = 5000,
        option_name = "Pulse2",
    },

    pulsebeam3 = {
        price = 8000,
        option_name = "Pulse3",
    },

    recov10 = {
        price = 300,
        option_name = "Recov10",
    },

    recov30 = {
        price = 1000,
        option_name = "Recov30",
    },

    recov50 = {
        price = 2000,
        option_name = "Recov50",
    },

    recov80 = {
        price = 3000,
        option_name = "Recov80",
    },

    recov120 = {
        price = 10000,
        option_name = "Recov120",
    },

    recov150 = {
        price = 15000,
        option_name = "Recov150",
    },

    recov200 = {
        price = 20000,
        option_name = "Recov200",
    },

    recov300 = {
        price = 30000,
        option_name = "Recov300",
    },

    spreadgun1 = {
        price = 600,
        option_name = "Spread1",
    },

    spreadgun2 = {
        price = 3200,
        option_name = "Spread2",
    },

    spreadgun3 = {
        price = 6000,
        option_name = "Spread3",
    },

    stonecube = {
        price = 2500,
        option_name = "StoneCub",
    },

    supernorthwind = {
        price = 8000,
        option_name = "SuprWind",
    },

    supervulcan = {
        price = 9800,
        option_name = "SuprVulc",
    },

    thunderball = {
        price = 4000,
        option_name = "ThndrBal",
    },

    timebomb1 = {
        price = 8800,
        option_name = "TimeBom1",
    },

    timebomb2 = {
        price = 12000,
        option_name = "TimeBom2",
    },

    timebomb3 = {
        price = 15200,
        option_name = "TimeBom3",
    },

    tornado = {
        price = 7600,
        option_name = "Tornado",
    },

    variablesword = {
        price = 10000,
        option_name = "VarSwrd",
    },

    vulcan1 = {
        price = 500,
        option_name = "Vulcan1",
    },

    vulcan2 = {
        price = 6000,
        option_name = "Vulcan2",
    },

    vulcan3 = {
        price = 5800,
        option_name = "Vulcan3",
    },
}

return config