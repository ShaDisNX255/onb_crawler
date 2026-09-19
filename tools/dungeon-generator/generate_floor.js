const path = require('path')

const { NetAreaGenerator } =
    require('./new-map-generator/NetAreaGenerator')

const TiledTMXExporter =
    require('./map-exporter/TiledTMXExporter')

// ============================================================
// ROOM TYPE CONFIG
// ============================================================

const ROOM_TYPE_REGULAR = 'regular'
const ROOM_TYPE_LOBBY = 'lobby'

// ============================================================
// LOBBY VISUALS
// ============================================================

const LOBBY_BACKGROUND_ANIMATION =
    '/server/assets/backgrounds/SkyHP.animation'

const LOBBY_BACKGROUND_TEXTURE =
    '/server/assets/backgrounds/SkyHP.png'

const LOBBY_BACKGROUND_VEL_X = 0.115
const LOBBY_BACKGROUND_VEL_Y = 0.065

// ============================================================
// LOBBY MUSIC
// ============================================================

const LOBBY_SONG =
    '/server/assets/lobby.ogg'

// ============================================================
// GENERATED NPC CONFIG
// ============================================================

const ATMOSPHERIC_NPC_ASSETS = [
    'normal-navi-bn4_red',
    'normal-navi-bn4_green',
    'normal-navi-bn4_brown',
    'male-navi-exe6_teal',
    'female-navi-exe6_pink',
    'female-navi-exe6_yellow',
    'official-navi-exe4_orange',
]

const CHIP_SELLER_NPC_ASSETS = [
    'normal-navi-bn4_green',
    'male-navi-exe6_teal',
    'official-navi-exe4_orange',
]


// Starting values.
// These are intentionally easy to rebalance later.

const REGULAR_CHIP_SELLER_CHANCE =
    0.25

const LOBBY_CHIP_SELLER_CHANCE =
    0.50

const REGULAR_NPC_LINES = [
    'The Net feels different every time I come through here.',
    'You never know what you will find down the next path.',
    'Be careful. There is no telling what is waiting ahead.',
    'I have been wandering around here for a while.',
]

const LOBBY_NPC_LINES = [
    'Take a moment. It is safe here.',
    'Nice place to catch your breath, huh?',
    'You should rest before heading back out there.',
]

// ============================================================
// MYSTERY DATA CONFIG
// ============================================================

// Three possible Mystery Data objects are placed in each regular
// map. ezmystery decides how many of the three each player sees.
const MYSTERY_DATA_CANDIDATES = 5

// TEMPORARY TEST VALUE.
//
// Every regular map gets one Blue Mystery Data candidate.
// ezmystery may still hide that candidate as part of the
// player's normal 0-3 visible Mystery Data roll.
//
// We'll choose the real probability after testing.
const BLUE_CHIP_MAP_CHANCE = 1.0

// 10% of regular maps have one Red Mystery Data candidate.
// Since ezmystery may hide that candidate, the actual chance of
// finding an HPMem is lower than 10%.
const RED_HPMEM_MAP_CHANCE = 0.8

const GREEN_MONEY_MIN = 100
const GREEN_MONEY_MAX = 500

// ============================================================
// GENERAL HELPERS
// ============================================================

function randomInt(min, max) {
    return Math.floor(
        Math.random() * (max - min + 1)
    ) + min
}

function randomChoice(array) {
    return array[
        Math.floor(
            Math.random() * array.length
        )
    ]
}

function shuffle(array) {
    for (
        let i = array.length - 1;
        i > 0;
        i--
    ) {
        const j =
            Math.floor(
                Math.random() * (i + 1)
            )

        const temp = array[i]
        array[i] = array[j]
        array[j] = temp
    }

    return array
}

// ============================================================
// REGULAR DUNGEON TREE GENERATION
// ============================================================

function createDungeonNode(depth, maxDepth) {
    const node = {
        features: {
            children: [],
        },
    }

    if (depth >= maxDepth) {
        return node
    }

    let childCount

    if (depth === 0) {
        childCount = randomInt(2, 3)
    } else {
        childCount = randomInt(0, 2)
    }

    for (let i = 0; i < childCount; i++) {
        node.features.children.push(
            createDungeonNode(
                depth + 1,
                maxDepth
            )
        )
    }

    return node
}

function assignParents(node, parent = null) {
    node.parent = parent

    for (
        const child
        of node.features?.children || []
    ) {
        assignParents(child, node)
    }
}

function collectLeaves(
    node,
    depth = 0,
    leaves = []
) {
    const children =
        node.features?.children || []

    if (children.length === 0) {
        leaves.push({
            node,
            depth,
        })
        return leaves
    }

    for (const child of children) {
        collectLeaves(
            child,
            depth + 1,
            leaves
        )
    }

    return leaves
}

function collectNodes(node, nodes = []) {
    nodes.push(node)

    for (
        const child
        of node.features?.children || []
    ) {
        collectNodes(child, nodes)
    }

    return nodes
}

function createTreeWithEnoughLeaves(
    requestedExitCount,
    maxDepth,
    maxAttempts = 100
) {
    for (
        let attempt = 1;
        attempt <= maxAttempts;
        attempt++
    ) {
        const root =
            createDungeonNode(
                0,
                maxDepth
            )

        assignParents(root)

        const leaves =
            collectLeaves(root)

        if (
            leaves.length >=
            requestedExitCount
        ) {
            return root
        }
    }

    throw new Error(
        `Unable to generate a map with at least ${requestedExitCount} leaves after ${maxAttempts} attempts`
    )
}

// ============================================================
// REST AREA GENERATION
// ============================================================
//
// Rest Areas intentionally do not use the normal multi-node
// dungeon tree. Every return warp, NPC, and forward exit is
// placed in one large open lobby room.
//

function createLobbyRoot() {
    return {
        room_style: ROOM_TYPE_LOBBY,
        features: {
            children: [],
        },
    }
}

// ============================================================
// BRANCH WARPS
// ============================================================

function addRegularBranchWarps(
    root,
    requestedCount
) {
    if (requestedCount <= 0) {
        return 0
    }

    const leaves =
        shuffle(
            collectLeaves(root)
        )

    leaves.sort(
        (a, b) =>
            b.depth - a.depth
    )

    const actualCount =
        Math.min(
            requestedCount,
            leaves.length
        )

    for (
        let index = 0;
        index < actualCount;
        index++
    ) {
        const leaf =
            leaves[index].node

        if (!leaf.features) {
            leaf.features = {}
        }

        leaf.features.next_floor_warps = [
            {
                branch_id:
                    index + 1,
            },
        ]
    }

    return actualCount
}

function addLobbyBranchWarps(
    root,
    requestedCount
) {
    if (!root.features) {
        root.features = {}
    }

    root.features.next_floor_warps = []

    for (
        let index = 0;
        index < requestedCount;
        index++
    ) {
        root.features.next_floor_warps.push({
            branch_id: index + 1,
        })
    }

    return requestedCount
}

// ============================================================
// NPC GENERATION
// ============================================================

function addNpcToNode(node, npc) {
    if (!node.features) {
        node.features = {}
    }

    if (!node.features.dungeon_npcs) {
        node.features.dungeon_npcs = []
    }

    node.features.dungeon_npcs.push(npc)
}

function addGeneratedNpcs(
    root,
    roomType
) {
    const nodes =
        shuffle(
            collectNodes(root)
        )


    if (nodes.length === 0) {
        return
    }


    let nextNpcNodeIndex = 0


    function hasFreeNode() {
        return (
            nextNpcNodeIndex <
            nodes.length
        )
    }


    function takeNode() {
        if (!hasFreeNode()) {
            return null
        }

        const node =
            nodes[
                nextNpcNodeIndex
            ]

        nextNpcNodeIndex++

        return node
    }


    function addChipSeller() {
        const node =
            takeNode()

        if (!node) {
            return false
        }

        addNpcToNode(
            node,
            {
                asset_name:
                    randomChoice(
                        CHIP_SELLER_NPC_ASSETS
                    ),

                dialogue_type:
                    'first',

                event_name:
                    'dungeon_chip_seller',

                text:
                    'I sell battle chips.',
            }
        )

        return true
    }


    // --------------------------------------------------------
    // LOBBY
    // --------------------------------------------------------

    if (
        roomType ===
        ROOM_TYPE_LOBBY
    ) {
        // Every lobby gets exactly one healer.
        const healerNode =
            takeNode()

        if (healerNode) {
            addNpcToNode(
                healerNode,
                {
                    asset_name:
                        'female-navi-exe6_yellow',

                    dialogue_type:
                        'first',

                    event_name:
                        'dungeon_heal',

                    text:
                        'You have had a tough journey, traveler. Rest here.',
                }
            )
        }


        // Chip seller.
        if (
            hasFreeNode() &&
            Math.random() <
                LOBBY_CHIP_SELLER_CHANCE
        ) {
            addChipSeller()
        }


        // 50% chance of an atmospheric NPC.
        if (
            hasFreeNode() &&
            Math.random() < 0.5
        ) {
            const atmosphericNode =
                takeNode()

            addNpcToNode(
                atmosphericNode,
                {
                    asset_name:
                        randomChoice(
                            ATMOSPHERIC_NPC_ASSETS
                        ),

                    dialogue_type:
                        'first',

                    text:
                        randomChoice(
                            LOBBY_NPC_LINES
                        ),
                }
            )
        }

        return
    }


    // --------------------------------------------------------
    // REGULAR DUNGEON ROOM
    // --------------------------------------------------------

    const atmosphericCount =
        randomInt(
            0,
            Math.min(
                2,
                nodes.length
            )
        )


    for (
        let i = 0;
        i < atmosphericCount;
        i++
    ) {
        const atmosphericNode =
            takeNode()

        if (!atmosphericNode) {
            break
        }

        addNpcToNode(
            atmosphericNode,
            {
                asset_name:
                    randomChoice(
                        ATMOSPHERIC_NPC_ASSETS
                    ),

                dialogue_type:
                    'first',

                text:
                    randomChoice(
                        REGULAR_NPC_LINES
                    ),
            }
        )
    }


    if (
        hasFreeNode() &&
        Math.random() <
            REGULAR_CHIP_SELLER_CHANCE
    ) {
        addChipSeller()
    }
}

// ============================================================
// MYSTERY DATA GENERATION
// ============================================================

function addMysteryDataToNode(
    node,
    featureName,
    data = {}
) {
    if (!node.features) {
        node.features = {}
    }

    if (!node.features[featureName]) {
        node.features[featureName] = []
    }

    node.features[featureName].push(
        data
    )
}

function addGeneratedMysteryData(
    root,
    roomType
) {
    // Rest Areas are safe hubs and do not get Mystery Data.
    if (roomType !== ROOM_TYPE_REGULAR) {
        return
    }

    const nodes =
        shuffle(
            collectNodes(root)
        )

    if (nodes.length === 0) {
        return
    }

    // Shuffle candidate positions first so special Mystery Data
    // types cannot accidentally overwrite one another.
    const candidateIndices =
        shuffle(
            Array.from(
                {
                    length:
                        MYSTERY_DATA_CANDIDATES,
                },
                (_, index) => index
            )
        )

    let specialIndex = 0

    // At most one Red Mystery Data candidate per map.
    const redIndex =
        Math.random() <
            RED_HPMEM_MAP_CHANCE &&
        specialIndex <
            candidateIndices.length
            ? candidateIndices[
                specialIndex++
            ]
            : -1

    // At most one Blue Mystery Data candidate per map.
    const blueIndex =
        Math.random() <
            BLUE_CHIP_MAP_CHANCE &&
        specialIndex <
            candidateIndices.length
            ? candidateIndices[
                specialIndex++
            ]
            : -1

    for (
        let i = 0;
        i < MYSTERY_DATA_CANDIDATES;
        i++
    ) {
        const node =
            nodes[
                i % nodes.length
            ]

        if (i === redIndex) {
            addMysteryDataToNode(
                node,
                'red_mystery_data'
            )

            continue
        }

        if (i === blueIndex) {
            addMysteryDataToNode(
                node,
                'blue_mystery_data',
                {
                    source:
                        'blue_mystery',
                }
            )

            continue
        }

        addMysteryDataToNode(
            node,
            'green_mystery_data',
            {
                amount:
                    randomInt(
                        GREEN_MONEY_MIN / 50,
                        GREEN_MONEY_MAX / 50
                    ) * 50,
            }
        )
    }
}

// ============================================================
// MAIN
// ============================================================

async function main() {
    const [
        areaId,
        runId,
        roomArg,
        depthArg,
        exitCountArg,
        roomTypeArg,
        outputArg,
    ] = process.argv.slice(2)

    if (
        !areaId ||
        !/^[A-Za-z0-9_-]+$/.test(areaId)
    ) {
        throw new Error(
            'Invalid or missing area ID'
        )
    }

    if (
        !runId ||
        !/^[A-Za-z0-9_-]+$/.test(runId)
    ) {
        throw new Error(
            'Invalid or missing dungeon run ID'
        )
    }

    const roomId = Number(roomArg)

    if (
        !Number.isInteger(roomId) ||
        roomId < 1
    ) {
        throw new Error(
            'Invalid room ID'
        )
    }

    const dungeonDepth = Number(depthArg)

    if (
        !Number.isInteger(dungeonDepth) ||
        dungeonDepth < 0
    ) {
        throw new Error(
            'Invalid dungeon depth'
        )
    }

    const requestedExitCount =
        Number(exitCountArg)

    if (
        !Number.isInteger(
            requestedExitCount
        ) ||
        requestedExitCount < 0
    ) {
        throw new Error(
            'Invalid branch count'
        )
    }

    const roomType =
        roomTypeArg ||
        ROOM_TYPE_REGULAR

    if (
        roomType !== ROOM_TYPE_REGULAR &&
        roomType !== ROOM_TYPE_LOBBY
    ) {
        throw new Error(
            'Invalid dungeon room type: ' +
            roomType
        )
    }

    console.log(
        '[dungeon-generator] generating',
        areaId
    )

    console.log(
        '[dungeon-generator] room:',
        roomId,
        'depth:',
        dungeonDepth,
        'type:',
        roomType,
        'requested exits:',
        requestedExitCount
    )

    // ========================================================
    // BUILD MAP
    // ========================================================

    let root
    let actualExitCount

    if (roomType === ROOM_TYPE_LOBBY) {
        root = createLobbyRoot()

        actualExitCount =
            addLobbyBranchWarps(
                root,
                requestedExitCount
            )
    } else {
        root =
            createTreeWithEnoughLeaves(
                requestedExitCount,
                3
            )

        actualExitCount =
            addRegularBranchWarps(
                root,
                requestedExitCount
            )
    }

    if (
        actualExitCount !==
        requestedExitCount
    ) {
        throw new Error(
            `Requested ${requestedExitCount} exits but generated ${actualExitCount}`
        )
    }

    console.log(
        '[dungeon-generator] actual exits:',
        actualExitCount
    )

    addGeneratedNpcs(
        root,
        roomType
    )

    addGeneratedMysteryData(
        root,
        roomType
    )

    const generator =
        new NetAreaGenerator()

    generator.maximumNodeDepth =
        roomType === ROOM_TYPE_LOBBY
            ? 0
            : 3

    await generator.generateNetArea(
        root,
        false
    )

    // ========================================================
    // OUTPUT PATH
    // ========================================================

    const outputPath =
        outputArg
            ? path.resolve(outputArg)
            : path.resolve(
                __dirname,
                `../../areas/${areaId}.tmx`
            )

    // ========================================================
    // MAP PROPERTIES
    // ========================================================

    const exportProperties = {
        Name:
            roomType === ROOM_TYPE_LOBBY
                ? `Rest Area ${roomId}`
                : `Dungeon Area ${roomId}`,

            'Forced Base HP':
                100,

            'Honor HPMem':
                true,

        dungeon_run_id:
            runId,

        dungeon_room_id:
            roomId,

        dungeon_depth:
            dungeonDepth,

        dungeon_exit_count:
            actualExitCount,

        dungeon_room_type:
            roomType,
    }

    if (roomType === ROOM_TYPE_REGULAR) {
        Object.assign(
            exportProperties,
            {
                'Mystery Data Minimum':
                    0,

                'Mystery Data Maximum':
                    MYSTERY_DATA_CANDIDATES,
            }
        )
    }

    if (roomType === ROOM_TYPE_LOBBY) {
        Object.assign(
            exportProperties,
            {
                Background:
                    'Custom',

                'Background Animation':
                    LOBBY_BACKGROUND_ANIMATION,

                'Background Texture':
                    LOBBY_BACKGROUND_TEXTURE,

                'Background Vel X':
                    LOBBY_BACKGROUND_VEL_X,

                'Background Vel Y':
                    LOBBY_BACKGROUND_VEL_Y,

                Song:
                    LOBBY_SONG,
            }
        )
    } else {
        Object.assign(
            exportProperties,
            {
                Background:
                    'Custom',

                'Background Animation':
                    '/server/assets/backgrounds/02-nettonohp.animation',

                'Background Texture':
                    '/server/assets/backgrounds/02-nettonohp.png',

                'Background Vel X':
                    0.115,

                'Background Vel Y':
                    0.065,
            }
        )
    }

    // ========================================================
    // EXPORT
    // ========================================================

    const exporter =
        new TiledTMXExporter()

    await exporter.ExportTMX(
        generator,
        exportProperties,
        outputPath
    )

    console.log(
        '[dungeon-generator] wrote',
        outputPath
    )
}

main().catch(
    error => {
        console.error(
            '[dungeon-generator] generation failed'
        )
        console.error(error)
        process.exit(1)
    }
)
