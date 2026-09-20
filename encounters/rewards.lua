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
    -- Used whenever:
    --   * the chip roll fails
    --   * the player already owns the chip
    --   * that virus/rank has no chip configured yet

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
    -- LOW HP OVERRIDE
    -- ========================================================

    low_hp_recovery = {
        threshold = 0.375,
        value = 50,
    },


    -- ========================================================
    -- VIRUS CHIP DROPS
    -- ========================================================
    --
    -- I'm only putting associations here that we have already
    -- explicitly established or that are part of the families
    -- we've already mapped.
    --
    -- Missing entries still reward money normally.

    drops = {
        Metall = {
            [1] = {chip="shockwave"},
            [2] = {chip="sonicwave"},
            [3] = {chip="dynawave"},
        },

        Paraball = {
            [1] = {chip="plasmaball1"},
            [2] = {chip="plasmaball2"},
            [3] = {chip="plasmaball3"},
        },

        HeavyArei = {
            [1] = {chip="heavyshake1"},
            [2] = {chip="heavyshake2"},
            [3] = {chip="heavyshake3"},
        },

        Rabiree = {
            [1] = {chip="rabiring1"},
            [2] = {chip="rabiring2"},
            [3] = {chip="rabiring3"},
        },

        CirKiller = {
            [1] = {chip="circgun1"},
            [2] = {chip="circgun2"},
            [3] = {chip="circgun3"},
        },

        Gunner = {
            [1] = {chip="machinegun1"},
            [2] = {chip="machinegun2"},
            [3] = {chip="machinegun3"},
        },

        Piranha = {
            [1] = {chip="triarrow"},
            [2] = {chip="trispear"},
            [3] = {chip="trilance"},
        },

        Chuuton = {
            [1] = {chip="ratton1"},
            [2] = {chip="ratton2"},
            [3] = {chip="ratton3"},
        },

        Kakajee = {
            [1] = {chip="reflector1"},
            [2] = {chip="reflector2"},
            [3] = {chip="reflector3"},
        },

        BombCorn = {
            [1] = {chip="cornshot1"},
        },

        MegaCorn = {
            [1] = {chip="cornshot2"},
        },

        GigaCorn = {
            [1] = {chip="cornshot3"},
        },

        KillerEye = {
            [1] = {chip="killersensor1"},
        },

        DemonEye = {
            [1] = {chip="killersensor2"},
        },

        JokerEye = {
            [1] = {chip="killersensor3"},
        },

        Rounda = {
            [1] = {chip="boomerang1"},
        },

        Roundarau = {
            [1] = {chip="boomerang2"},
        },

        Roundabar = {
            [1] = {chip="boomerang3"},
        },

        Yort = {
            [1] = {chip="yoyo1"},
            [2] = {chip="yoyo2"},
            [3] = {chip="yoyo3"},
        },

        Volgear = {
            [1] = {chip="flameline1"},
            [2] = {chip="flameline2"},

            -- Deliberately no FlameLine3.
            --
            -- We already established that the downloaded
            -- Volgear progression does not reach the variant
            -- associated with FlameLine3.
        },
    },
}