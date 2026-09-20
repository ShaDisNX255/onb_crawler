local function reward(
    difficulty,
    chip
)
    local result = {
        difficulty =
            difficulty,
    }

    if chip then
        result.chip =
            chip
    end

    return result
end


return {
    -- ========================================================
    -- CHIP DROP CHANCES
    -- ========================================================

    chip_chances = {
        easy = {
            low = 0.45,
            mid = 0.65,
            high = 0.85,
        },

        medium = {
            low = 0.40,
            mid = 0.60,
            high = 0.80,
        },

        hard = {
            low = 0.35,
            mid = 0.55,
            high = 0.75,
        },
    },


    -- ========================================================
    -- DEFAULT MONEY
    -- ========================================================
    --
    -- Used when:
    --
    --   * the virus/rank has no assigned chip
    --   * the chip roll fails
    --   * the player already owns the chip
    --   * a chip unlock fails and falls back safely
    --
    -- Individual virus/rank entries can override these later
    -- with their own:
    --
    -- money = {
    --     low = ...,
    --     mid = ...,
    --     high = ...,
    -- }

    money = {
        easy = {
            low = 50,
            mid = 100,
            high = 200,
        },

        medium = {
            low = 100,
            mid = 250,
            high = 500,
        },

        hard = {
            low = 250,
            mid = 500,
            high = 1000,
        },
    },


    -- ========================================================
    -- LOW HP RECOVERY
    -- ========================================================
    --
    -- This is ADDITIONAL.
    --
    -- The player still receives the normal chip-or-money
    -- reward after receiving this recovery.

    low_hp_recovery = {
        threshold = 0.375,
        value = 50,
    },


    -- ========================================================
    -- VIRUS / RANK REWARDS
    -- ========================================================
    --
    -- IMPORTANT:
    --
    -- No chip = intentional money-only virus/rank.
    --
    -- We only assign chips where we already established an
    -- association. Nothing below invents missing drops.

    drops = {

        -- ====================================================
        -- PARABALL
        -- ====================================================

        Paraball = {
            [1] = reward(
                "easy",
                "plasmaball1"
            ),

            [2] = reward(
                "medium",
                "plasmaball2"
            ),

            [3] = reward(
                "hard",
                "plasmaball3"
            ),
        },


        -- ====================================================
        -- KIORUSHIN
        -- ====================================================

        Kiorushin = {
            [1] = reward(
                "easy"
            ),

            [2] = reward(
                "medium"
            ),

            [3] = reward(
                "hard"
            ),
        },


        -- ====================================================
        -- HEAVY AREI
        -- ====================================================

        HeavyArei = {
            [1] = reward(
                "easy",
                "heavyshake1"
            ),

            [2] = reward(
                "medium",
                "heavyshake2"
            ),

            [3] = reward(
                "hard",
                "heavyshake3"
            ),
        },


        -- ====================================================
        -- CANNODUMB
        -- ====================================================

        Cannodumb = {
            [1] = reward(
                "easy"
            ),

            [2] = reward(
                "medium"
            ),

            [3] = reward(
                "hard"
            ),
        },


        -- ====================================================
        -- RABIREE
        -- ====================================================

        Rabiree = {
            [1] = reward(
                "easy",
                "rabiring1"
            ),

            [2] = reward(
                "medium",
                "rabiring2"
            ),

            [3] = reward(
                "hard",
                "rabiring3"
            ),
        },


        -- ====================================================
        -- NUMBERS FAMILY
        -- ====================================================

        Numbers1 = {
            [1] = reward(
                "easy"
            ),
        },

        Numbers2 = {
            [1] = reward(
                "medium"
            ),
        },

        Numbers3 = {
            [1] = reward(
                "hard"
            ),
        },


        -- ====================================================
        -- WEATHERS
        -- ====================================================

        Weathers = {
            [1] = reward(
                "easy"
            ),

            [2] = reward(
                "medium"
            ),

            [3] = reward(
                "hard"
            ),
        },


        -- ====================================================
        -- ZAEMON
        -- ====================================================

        Zaemon = {
            [1] = reward(
                "easy"
            ),

            [2] = reward(
                "medium"
            ),

            [3] = reward(
                "hard"
            ),
        },


        -- ====================================================
        -- APPLESAM
        -- ====================================================

        AppleSam = {
            [1] = reward(
                "easy"
            ),

            [2] = reward(
                "medium"
            ),

            [3] = reward(
                "hard"
            ),
        },


        -- ====================================================
        -- GENIN
        -- ====================================================

        Genin = {
            [1] = reward(
                "easy"
            ),

            [2] = reward(
                "medium"
            ),

            [3] = reward(
                "hard"
            ),
        },


        -- ====================================================
        -- SHELLKY
        -- ====================================================

        Shellky = {
            [1] = reward(
                "easy"
            ),

            [2] = reward(
                "medium"
            ),

            [3] = reward(
                "hard"
            ),
        },


        -- ====================================================
        -- CIRKILLER
        -- ====================================================

        CirKiller = {
            [1] = reward(
                "easy",
                "circgun1"
            ),

            [2] = reward(
                "medium",
                "circgun2"
            ),

            [3] = reward(
                "hard",
                "circgun3"
            ),
        },


        -- ====================================================
        -- KUUMOSS
        -- ====================================================

        Kuumoss = {
            [1] = reward(
                "easy"
            ),

            [2] = reward(
                "medium"
            ),

            [3] = reward(
                "hard"
            ),
        },


        -- ====================================================
        -- METALL
        -- ====================================================

        Metall = {
            [1] = reward(
                "easy",
                "shockwave"
            ),

            [2] = reward(
                "medium",
                "sonicwave"
            ),

            [3] = reward(
                "hard",
                "dynawave"
            ),
        },


        -- ====================================================
        -- KAKAJEE
        -- ====================================================

        Kakajee = {
            [1] = reward(
                "easy",
                "reflector1"
            ),

            [2] = reward(
                "medium",
                "reflector2"
            ),

            [3] = reward(
                "hard",
                "reflector3"
            ),
        },


        -- ====================================================
        -- GUNNER
        -- ====================================================

        Gunner = {
            [1] = reward(
                "easy",
                "machinegun1"
            ),

            [2] = reward(
                "medium",
                "machinegun2"
            ),

            [3] = reward(
                "hard",
                "machinegun3"
            ),
        },


        -- ====================================================
        -- FANCAR
        -- ====================================================

        Fancar = {
            [1] = reward(
                "easy"
            ),

            [2] = reward(
                "medium"
            ),

            [3] = reward(
                "hard"
            ),
        },


        -- ====================================================
        -- PIRANHA
        -- ====================================================

        Piranha = {
            [1] = reward(
                "easy",
                "triarrow"
            ),

            [2] = reward(
                "medium",
                "trispear"
            ),

            [3] = reward(
                "hard",
                "trilance"
            ),
        },


        -- ====================================================
        -- YURA FAMILY
        -- ====================================================

        Yura = {
            [1] = reward(
                "easy"
            ),
        },

        Yurayura = {
            [1] = reward(
                "medium"
            ),
        },

        Yurarion = {
            [1] = reward(
                "hard"
            ),
        },


        -- ====================================================
        -- OLD STOVE FAMILY
        -- ====================================================

        OldStove = {
            [1] = reward(
                "easy"
            ),
        },

        OldHeater = {
            [1] = reward(
                "medium"
            ),
        },

        OldBurner = {
            [1] = reward(
                "hard"
            ),
        },


        -- ====================================================
        -- CHUUTON
        -- ====================================================

        Chuuton = {
            [1] = reward(
                "easy",
                "ratton1"
            ),

            [2] = reward(
                "medium",
                "ratton2"
            ),

            [3] = reward(
                "hard",
                "ratton3"
            ),
        },


        -- ====================================================
        -- CURZE FAMILY
        -- ====================================================

        Curze = {
            [1] = reward(
                "easy"
            ),
        },

        Curzena = {
            [1] = reward(
                "medium"
            ),
        },

        Curzed = {
            [1] = reward(
                "hard"
            ),
        },


        -- ====================================================
        -- DHARMA FAMILY
        -- ====================================================

        Dharma = {
            [1] = reward(
                "easy"
            ),
        },

        Dharga = {
            [1] = reward(
                "medium"
            ),
        },

        Dhardara = {
            [1] = reward(
                "hard"
            ),
        },


        -- ====================================================
        -- KILLPLANT FAMILY
        -- ====================================================

        KillPlant = {
            [1] = reward(
                "easy"
            ),
        },

        KillWeed = {
            [1] = reward(
                "medium"
            ),
        },

        KillFlower = {
            [1] = reward(
                "hard"
            ),
        },


        -- ====================================================
        -- GARUE FAMILY
        -- ====================================================

        Garue = {
            [1] = reward(
                "easy"
            ),
        },

        Garuebar = {
            [1] = reward(
                "medium"
            ),
        },

        Garuedan = {
            [1] = reward(
                "hard"
            ),
        },


        -- ====================================================
        -- EBIRON FAMILY
        -- ====================================================

        Ebiron = {
            [1] = reward(
                "easy"
            ),
        },

        Ebidel = {
            [1] = reward(
                "medium"
            ),
        },

        EbiSide = {
            [1] = reward(
                "hard"
            ),
        },


        -- ====================================================
        -- HARD BOLZ FAMILY
        -- ====================================================

        HardBolz = {
            [1] = reward(
                "easy"
            ),
        },

        ColdBolz = {
            [1] = reward(
                "medium"
            ),
        },

        MagraBolz = {
            [1] = reward(
                "hard"
            ),
        },


        -- ====================================================
        -- KABUTANK
        -- ====================================================

        Kabutank = {
            [1] = reward(
                "easy"
            ),

            [2] = reward(
                "medium"
            ),

            [3] = reward(
                "hard"
            ),
        },


        -- ====================================================
        -- SWORDIN FAMILY
        -- ====================================================

        Swordin = {
            [1] = reward(
                "easy"
            ),
        },

        Swordra = {
            [1] = reward(
                "medium"
            ),
        },

        Swortar = {
            [1] = reward(
                "hard"
            ),
        },


        -- ====================================================
        -- DREAM MERARU
        -- ====================================================

        DreamMeraru = {
            [1] = reward(
                "easy"
            ),

            [2] = reward(
                "medium"
            ),

            [3] = reward(
                "hard"
            ),
        },


        -- ====================================================
        -- DREAM LAPIA
        -- ====================================================

        DreamLapia = {
            [1] = reward(
                "easy"
            ),

            [2] = reward(
                "medium"
            ),

            [3] = reward(
                "hard"
            ),
        },


        -- ====================================================
        -- DREAM BOLT
        -- ====================================================

        DreamBolt = {
            [1] = reward(
                "easy"
            ),

            [2] = reward(
                "medium"
            ),

            [3] = reward(
                "hard"
            ),
        },


        -- ====================================================
        -- DREAM MOSS
        -- ====================================================

        DreamMoss = {
            [1] = reward(
                "easy"
            ),

            [2] = reward(
                "medium"
            ),

            [3] = reward(
                "hard"
            ),
        },


        -- ====================================================
        -- LARK FAMILY
        -- ====================================================

        Lark = {
            [1] = reward(
                "easy"
            ),
        },

        Bark = {
            [1] = reward(
                "medium"
            ),
        },

        Tark = {
            [1] = reward(
                "hard"
            ),
        },


        -- ====================================================
        -- CORN FAMILY
        -- ====================================================

        BombCorn = {
            [1] = reward(
                "easy",
                "cornshot1"
            ),
        },

        MegaCorn = {
            [1] = reward(
                "medium",
                "cornshot2"
            ),
        },

        GigaCorn = {
            [1] = reward(
                "hard",
                "cornshot3"
            ),
        },


        -- ====================================================
        -- QUAKER
        -- ====================================================

        Quaker = {
            [1] = reward(
                "easy"
            ),

            [2] = reward(
                "medium"
            ),

            [3] = reward(
                "hard"
            ),
        },


        -- ====================================================
        -- HEEL NAVI
        -- ====================================================

        HeelNavi = {
            [1] = reward(
                "easy"
            ),

            [2] = reward(
                "medium"
            ),

            [3] = reward(
                "hard"
            ),
        },


        -- ====================================================
        -- HAUNTED CANDLE
        -- ====================================================

        HauntedCandle = {
            [1] = reward(
                "easy"
            ),

            [2] = reward(
                "medium"
            ),

            [3] = reward(
                "hard"
            ),
        },


        -- ====================================================
        -- MET FIRE FAMILY
        -- ====================================================

        MetFire = {
            [1] = reward(
                "easy"
            ),
        },

        FulFire = {
            [1] = reward(
                "medium"
            ),
        },

        DthFire = {
            [1] = reward(
                "hard"
            ),
        },


        -- ====================================================
        -- VOLGEAR
        -- ====================================================
        --
        -- We established that the available Volgear package
        -- mapping gives us FlameLine1 and FlameLine2.
        --
        -- FlameLine3 remains BMD-only.

        Volgear = {
            [1] = reward(
                "easy",
                "flameline1"
            ),

            [2] = reward(
                "medium",
                "flameline2"
            ),

            [3] = reward(
                "hard"
            ),
        },


        -- ====================================================
        -- KILLER EYE FAMILY
        -- ====================================================

        KillerEye = {
            [1] = reward(
                "easy",
                "killersensor1"
            ),
        },

        DemonEye = {
            [1] = reward(
                "medium",
                "killersensor2"
            ),
        },

        JokerEye = {
            [1] = reward(
                "hard",
                "killersensor3"
            ),
        },


        -- ====================================================
        -- PUFFY
        -- ====================================================

        Puffy = {
            [1] = reward(
                "easy"
            ),

            [2] = reward(
                "medium"
            ),

            [3] = reward(
                "hard"
            ),
        },


        -- ====================================================
        -- VOLCANO
        -- ====================================================

        Volcano = {
            [1] = reward(
                "easy"
            ),

            [2] = reward(
                "medium"
            ),

            [3] = reward(
                "hard"
            ),
        },


        -- ====================================================
        -- ROUNDA FAMILY
        -- ====================================================

        Rounda = {
            [1] = reward(
                "easy",
                "boomerang1"
            ),
        },

        Roundarau = {
            [1] = reward(
                "medium",
                "boomerang2"
            ),
        },

        Roundabar = {
            [1] = reward(
                "hard",
                "boomerang3"
            ),
        },


        -- ====================================================
        -- YORT
        -- ====================================================

        Yort = {
            [1] = reward(
                "easy",
                "yoyo1"
            ),

            [2] = reward(
                "medium",
                "yoyo2"
            ),

            [3] = reward(
                "hard",
                "yoyo3"
            ),
        },


        -- ====================================================
        -- CURRENT BOSS POOL
        -- ====================================================
        --
        -- Money-only for now unless we have explicitly wired
        -- that boss/rank to one of the boss-chip packages.
        --
        -- They use the Hard money table.

        Forte = {
            [1] = reward(
                "hard"
            ),
        },

        Gregar = {
            [1] = reward(
                "hard"
            ),
        },

        GregarBeast = {
            [1] = reward(
                "hard"
            ),
        },

        Duo = {
            [1] = reward(
                "hard"
            ),
        },

        BurnerMan = {
            [1] = reward(
                "hard"
            ),
        },

        Colonel = {
            [1] = reward(
                "hard"
            ),
        },

        ElementMan = {
            [1] = reward(
                "hard"
            ),
        },

        StarMan = {
            [1] = reward(
                "hard"
            ),
        },

        Proto = {
            [1] = reward(
                "hard"
            ),
        },

        ShadowMan = {
            [1] = reward(
                "hard"
            ),
        },

        HatMan = {
            [1] = reward(
                "hard"
            ),
        },

        QuickMan = {
            [1] = reward(
                "hard"
            ),
        },

        ShadeMan = {
            [1] = reward(
                "hard"
            ),
        },

        Noir = {
            [1] = reward(
                "hard"
            ),
        },
    },
}