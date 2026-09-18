const fs = require('fs')
const path = require('path')
const crypto = require('crypto')
const { spawn } = require('child_process')


// ============================================================
// CONFIG
// ============================================================

const POOL_SIZE_PER_BRANCH_COUNT = 5
const STARTUP_MIN_PER_BRANCH_COUNT = 1

const BRANCH_COUNTS = [
    0,
    1,
    2,
    3,
    4,
]

const REFILL_CHECK_MS = 500


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

let generationCounter = 0
let shuttingDown = false


// ============================================================
// HELPERS
// ============================================================

function sleep(ms) {
    return new Promise(
        resolve =>
            setTimeout(resolve, ms)
    )
}


function getBranchDirectory(branchCount) {
    return path.join(
        POOL_DIR,
        String(branchCount)
    )
}

function getSlotPath(
    branchCount,
    slotNumber
) {
    return path.join(
        getBranchDirectory(branchCount),
        `slot_${String(slotNumber).padStart(2, '0')}.tmx`
    )
}


function getTempSlotPath(
    branchCount,
    slotNumber
) {
    return path.join(
        getBranchDirectory(branchCount),
        `slot_${String(slotNumber).padStart(2, '0')}.tmp`
    )
}


function findMissingSlot(branchCount) {
    for (
        let slot = 1;
        slot <= POOL_SIZE_PER_BRANCH_COUNT;
        slot++
    ) {
        if (
            !fs.existsSync(
                getSlotPath(
                    branchCount,
                    slot
                )
            )
        ) {
            return slot
        }
    }

    return null
}

function ensureDirectories() {
    fs.mkdirSync(
        POOL_DIR,
        {
            recursive: true,
        }
    )

    for (
        const branchCount
        of BRANCH_COUNTS
    ) {
        fs.mkdirSync(
            getBranchDirectory(
                branchCount
            ),
            {
                recursive: true,
            }
        )
    }
}


function removeReadyMarker() {
    try {
        fs.unlinkSync(
            READY_FILE
        )
    } catch (_) {
        // File simply does not exist.
    }
}


function cleanupIncompleteFiles() {
    for (
        const branchCount
        of BRANCH_COUNTS
    ) {
        const directory =
            getBranchDirectory(
                branchCount
            )

        for (
            const filename
            of fs.readdirSync(directory)
        ) {
            if (
                filename.endsWith(
                    '.tmp'
                )
            ) {
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


function listReadyLayouts(
    branchCount
) {
    const ready = []

    for (
        let slot = 1;
        slot <= POOL_SIZE_PER_BRANCH_COUNT;
        slot++
    ) {
        const filepath =
            getSlotPath(
                branchCount,
                slot
            )

        if (fs.existsSync(filepath)) {
            ready.push(filepath)
        }
    }

    return ready
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
// GENERATION
// ============================================================

function runGenerator(
    branchCount,
    tempPath
) {
    return new Promise(
        (resolve, reject) => {
            const layoutId =
                createLayoutId()

            const areaId =
                'pool_' +
                branchCount +
                '_' +
                layoutId

            const roomId =
                generationCounter

            console.log(
                '[dungeon-generator-server] generating',
                branchCount +
                '-branch layout',
                areaId
            )


            const args = [
                GENERATE_SCRIPT,

                areaId,

                // Cached layouts do not belong to an actual run yet.
                'pool',

                String(roomId),

                // Dungeon depth is assigned later by Lua.
                '0',

                String(branchCount),

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
                    reject(error)
                }
            )


            child.on(
                'exit',
                code => {
                    if (code === 0) {
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


async function generateOneLayout(
    branchCount,
    slotNumber
) {
    const tempPath =
        getTempSlotPath(
            branchCount,
            slotNumber
        )

    const finalPath =
        getSlotPath(
            branchCount,
            slotNumber
        )

    try {
        fs.unlinkSync(tempPath)
    } catch (_) {
    }

    try {
        await runGenerator(
            branchCount,
            tempPath
        )

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
            fs.unlinkSync(tempPath)
        } catch (_) {
        }

        return false
    }
}


// ============================================================
// POOL MANAGEMENT
// ============================================================

async function refillPool(
    branchCount,
    targetCount =
        POOL_SIZE_PER_BRANCH_COUNT
) {
    while (!shuttingDown) {
        const readyCount =
            listReadyLayouts(
                branchCount
            ).length

        if (readyCount >= targetCount) {
            return
        }

        const missingSlot =
            findMissingSlot(
                branchCount
            )

        if (missingSlot === null) {
            return
        }

        console.log(
            '[dungeon-generator-server] pool',
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
                branchCount,
                missingSlot
            )

        if (!success) {
            await sleep(1000)
        }
    }
}


async function refillAllPools(
    targetCount =
        POOL_SIZE_PER_BRANCH_COUNT
) {
    for (
        const branchCount
        of BRANCH_COUNTS
    ) {
        if (shuttingDown) {
            return
        }

        await refillPool(
            branchCount,
            targetCount
        )
    }
}


function allPoolsReady(
    minimumCount =
        STARTUP_MIN_PER_BRANCH_COUNT
) {
    for (
        const branchCount
        of BRANCH_COUNTS
    ) {
        if (
            listReadyLayouts(
                branchCount
            ).length <
            minimumCount
        ) {
            return false
        }
    }

    return true
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
// SHUTDOWN
// ============================================================

function shutdown() {
    if (shuttingDown) {
        return
    }

    shuttingDown = true

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

    // Only require one ready layout of each type before
    // allowing ONB to start.
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

    while (!shuttingDown) {
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
