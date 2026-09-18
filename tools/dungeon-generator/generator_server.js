const fs = require('fs')
const path = require('path')
const crypto = require('crypto')
const { spawn } = require('child_process')


// ============================================================
// CONFIG
// ============================================================

const POOL_SIZE_PER_BRANCH_COUNT =
    5

const STARTUP_MIN_PER_BRANCH_COUNT =
    1


const BRANCH_COUNTS = [
    0,
    1,
    2,
    3,
    4,
]


const ROOM_TYPES = [
    'regular',
    'lobby',
]


const REFILL_CHECK_MS =
    500


// ============================================================
// PATHS
// ============================================================

const ROOT_DIR =
    path.resolve(
        __dirname,
        '../..'
    )


const GENERATE_SCRIPT =
    path.join(
        __dirname,
        'generate_floor.js'
    )


const POOL_DIR =
    path.join(
        ROOT_DIR,
        'runtime',
        'dungeon_pool'
    )


const READY_FILE =
    path.join(
        POOL_DIR,
        'READY'
    )


// ============================================================
// STATE
// ============================================================

let generationCounter =
    0

let shuttingDown =
    false


// ============================================================
// GENERAL HELPERS
// ============================================================

function sleep(ms) {
    return new Promise(
        resolve =>
            setTimeout(
                resolve,
                ms
            )
    )
}


function createLayoutId() {
    generationCounter++

    return (
        Date.now().toString(36) +
        '_' +
        generationCounter +
        '_' +
        crypto
            .randomBytes(4)
            .toString('hex')
    )
}


// ============================================================
// POOL PATH HELPERS
// ============================================================

function getBranchDirectory(
    roomType,
    branchCount
) {
    return path.join(
        POOL_DIR,
        roomType,
        String(branchCount)
    )
}


function getSlotPath(
    roomType,
    branchCount,
    slotNumber
) {
    return path.join(
        getBranchDirectory(
            roomType,
            branchCount
        ),
        `slot_${String(slotNumber).padStart(2, '0')}.tmx`
    )
}


function getTempSlotPath(
    roomType,
    branchCount,
    slotNumber
) {
    return path.join(
        getBranchDirectory(
            roomType,
            branchCount
        ),
        `slot_${String(slotNumber).padStart(2, '0')}.tmp`
    )
}


// ============================================================
// DIRECTORY SETUP
// ============================================================

function ensureDirectories() {
    fs.mkdirSync(
        POOL_DIR,
        {
            recursive: true,
        }
    )


    for (
        const roomType
        of ROOM_TYPES
    ) {
        for (
            const branchCount
            of BRANCH_COUNTS
        ) {
            fs.mkdirSync(
                getBranchDirectory(
                    roomType,
                    branchCount
                ),
                {
                    recursive: true,
                }
            )
        }
    }
}


// ============================================================
// READY MARKER
// ============================================================

function removeReadyMarker() {
    try {
        fs.unlinkSync(
            READY_FILE
        )
    } catch (_) {
        // It simply did not exist.
    }
}


function writeReadyMarker() {
    fs.writeFileSync(
        READY_FILE,
        'ready\n'
    )

    console.log('')

    console.log(
        '[dungeon-generator-server] ============================='
    )

    console.log(
        '[dungeon-generator-server] INITIAL POOL READY'
    )

    console.log(
        '[dungeon-generator-server] ============================='
    )

    console.log('')
}


// ============================================================
// POOL INSPECTION
// ============================================================

function listReadyLayouts(
    roomType,
    branchCount
) {
    const ready = []

    for (
        let slot = 1;
        slot <=
            POOL_SIZE_PER_BRANCH_COUNT;
        slot++
    ) {
        const filepath =
            getSlotPath(
                roomType,
                branchCount,
                slot
            )

        if (
            fs.existsSync(
                filepath
            )
        ) {
            ready.push(
                filepath
            )
        }
    }

    return ready
}


function findMissingSlot(
    roomType,
    branchCount
) {
    for (
        let slot = 1;
        slot <=
            POOL_SIZE_PER_BRANCH_COUNT;
        slot++
    ) {
        const filepath =
            getSlotPath(
                roomType,
                branchCount,
                slot
            )

        if (
            !fs.existsSync(
                filepath
            )
        ) {
            return slot
        }
    }

    return null
}


// ============================================================
// CLEANUP INCOMPLETE FILES
// ============================================================

function cleanupIncompleteFiles() {
    for (
        const roomType
        of ROOM_TYPES
    ) {
        for (
            const branchCount
            of BRANCH_COUNTS
        ) {
            const directory =
                getBranchDirectory(
                    roomType,
                    branchCount
                )


            for (
                const filename
                of fs.readdirSync(
                    directory
                )
            ) {
                if (
                    !filename.endsWith(
                        '.tmp'
                    )
                ) {
                    continue
                }


                const filepath =
                    path.join(
                        directory,
                        filename
                    )


                console.log(
                    '[dungeon-generator-server] removing incomplete file',
                    filepath
                )


                try {
                    fs.unlinkSync(
                        filepath
                    )
                } catch (error) {
                    console.error(
                        '[dungeon-generator-server] failed removing incomplete file:',
                        error
                    )
                }
            }
        }
    }
}


// ============================================================
// GENERATION PROCESS
// ============================================================

function runGenerator(
    roomType,
    branchCount,
    tempPath
) {
    return new Promise(
        (resolve, reject) => {
            const layoutId =
                createLayoutId()


            const areaId =
                'pool_' +
                roomType +
                '_' +
                branchCount +
                '_' +
                layoutId


            const roomId =
                generationCounter


            console.log(
                '[dungeon-generator-server] generating',
                roomType,
                branchCount +
                '-branch layout',
                areaId
            )


            const args = [
                GENERATE_SCRIPT,

                areaId,

                // Cached layouts do not belong
                // to a real dungeon run yet.
                'pool',

                String(roomId),

                // Real dungeon depth is assigned
                // later by Lua.
                '0',

                String(branchCount),

                roomType,

                tempPath,
            ]


            const child =
                spawn(
                    process.execPath,
                    args,
                    {
                        cwd:
                            ROOT_DIR,

                        stdio:
                            'inherit',
                    }
                )


            child.on(
                'error',
                error => {
                    reject(
                        error
                    )
                }
            )


            child.on(
                'exit',
                code => {
                    if (
                        code === 0
                    ) {
                        resolve()
                    } else {
                        reject(
                            new Error(
                                'generate_floor.js exited with code ' +
                                code
                            )
                        )
                    }
                }
            )
        }
    )
}


// ============================================================
// GENERATE ONE SLOT
// ============================================================

async function generateOneLayout(
    roomType,
    branchCount,
    slotNumber
) {
    const tempPath =
        getTempSlotPath(
            roomType,
            branchCount,
            slotNumber
        )


    const finalPath =
        getSlotPath(
            roomType,
            branchCount,
            slotNumber
        )


    try {
        fs.unlinkSync(
            tempPath
        )
    } catch (_) {
    }


    try {
        await runGenerator(
            roomType,
            branchCount,
            tempPath
        )


        // Atomic rename.
        //
        // Lua never sees a .tmp file,
        // so it cannot claim a map while
        // the generator is still writing it.
        fs.renameSync(
            tempPath,
            finalPath
        )


        console.log(
            '[dungeon-generator-server] ready:',
            finalPath
        )


        return true
    } catch (error) {
        console.error(
            '[dungeon-generator-server] generation failed:',
            error
        )


        try {
            fs.unlinkSync(
                tempPath
            )
        } catch (_) {
        }


        return false
    }
}


// ============================================================
// REFILL ONE POOL
// ============================================================

async function refillPool(
    roomType,
    branchCount,
    targetCount =
        POOL_SIZE_PER_BRANCH_COUNT
) {
    while (
        !shuttingDown
    ) {
        const readyCount =
            listReadyLayouts(
                roomType,
                branchCount
            ).length


        if (
            readyCount >=
            targetCount
        ) {
            return
        }


        const missingSlot =
            findMissingSlot(
                roomType,
                branchCount
            )


        if (
            missingSlot === null
        ) {
            return
        }


        console.log(
            '[dungeon-generator-server] pool',
            roomType,
            branchCount,
            'has',
            readyCount,
            '/',
            targetCount,
            '- filling slot',
            missingSlot
        )


        const success =
            await generateOneLayout(
                roomType,
                branchCount,
                missingSlot
            )


        if (
            !success
        ) {
            await sleep(
                1000
            )
        }
    }
}


// ============================================================
// REFILL ALL POOLS
// ============================================================

async function refillAllPools(
    targetCount =
        POOL_SIZE_PER_BRANCH_COUNT
) {
    for (
        const roomType
        of ROOM_TYPES
    ) {
        for (
            const branchCount
            of BRANCH_COUNTS
        ) {
            if (
                shuttingDown
            ) {
                return
            }


            await refillPool(
                roomType,
                branchCount,
                targetCount
            )
        }
    }
}


// ============================================================
// STARTUP READINESS
// ============================================================

function allPoolsReady(
    minimumCount =
        STARTUP_MIN_PER_BRANCH_COUNT
) {
    for (
        const roomType
        of ROOM_TYPES
    ) {
        for (
            const branchCount
            of BRANCH_COUNTS
        ) {
            const readyCount =
                listReadyLayouts(
                    roomType,
                    branchCount
                ).length


            if (
                readyCount <
                minimumCount
            ) {
                return false
            }
        }
    }

    return true
}


// ============================================================
// SHUTDOWN
// ============================================================

function shutdown() {
    if (
        shuttingDown
    ) {
        return
    }

    shuttingDown =
        true


    console.log(
        '[dungeon-generator-server] shutting down'
    )


    removeReadyMarker()
}


process.on(
    'SIGINT',
    shutdown
)


process.on(
    'SIGTERM',
    shutdown
)


// ============================================================
// MAIN
// ============================================================

async function main() {
    console.log(
        '[dungeon-generator-server] starting'
    )


    console.log(
        '[dungeon-generator-server] pool directory:',
        POOL_DIR
    )


    ensureDirectories()

    removeReadyMarker()

    cleanupIncompleteFiles()


    // --------------------------------------------------------
    // Initial startup pool
    // --------------------------------------------------------

    console.log(
        '[dungeon-generator-server] preparing initial layout pool'
    )


    // Only one layout of every room-type/branch-count
    // combination is required before ONB starts.
    await refillAllPools(
        STARTUP_MIN_PER_BRANCH_COUNT
    )


    if (
        !shuttingDown &&
        allPoolsReady(
            STARTUP_MIN_PER_BRANCH_COUNT
        )
    ) {
        writeReadyMarker()
    }


    // --------------------------------------------------------
    // Permanent refill loop
    // --------------------------------------------------------

    while (
        !shuttingDown
    ) {
        await refillAllPools()

        await sleep(
            REFILL_CHECK_MS
        )
    }


    removeReadyMarker()
}


main().catch(
    error => {
        console.error(
            '[dungeon-generator-server] fatal error:',
            error
        )


        removeReadyMarker()

        process.exit(1)
    }
)
