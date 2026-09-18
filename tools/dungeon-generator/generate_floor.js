const path = require('path')

const { NetAreaGenerator } =
    require('./new-map-generator/NetAreaGenerator')

const TiledTMXExporter =
    require('./map-exporter/TiledTMXExporter')


function randomInt(min, max) {
    return Math.floor(
        Math.random() * (max - min + 1)
    ) + min
}


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

    // The first internal room always branches so the generated
    // map has some structure to explore.
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


function addBranchWarps(
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

    // Prefer terminal rooms farther away from the entrance.
    //
    // Because shuffle() happened first, leaves at the same depth
    // still get randomized.
    leaves.sort(
        (a, b) => b.depth - a.depth
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

async function main() {
    const [
        areaId,
        runId,
        roomArg,
        depthArg,
        exitCountArg,
        outputArg,
    ] = process.argv.slice(2)


    // ----------------------------------------------------------
    // Validate arguments
    // ----------------------------------------------------------

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


    const roomId =
        Number(roomArg)

    if (
        !Number.isInteger(roomId) ||
        roomId < 1
    ) {
        throw new Error(
            'Invalid room ID'
        )
    }


    const dungeonDepth =
        Number(depthArg)

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


    console.log(
        '[dungeon-generator] generating',
        areaId
    )

    console.log(
        '[dungeon-generator] room:',
        roomId,
        'depth:',
        dungeonDepth,
        'requested exits:',
        requestedExitCount
    )


    // ----------------------------------------------------------
    // Build this individual map
    // ----------------------------------------------------------

    const root =
        createTreeWithEnoughLeaves(
            requestedExitCount,
            3
        )

    const actualExitCount =
        addBranchWarps(
            root,
            requestedExitCount
        )

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


    const generator =
        new NetAreaGenerator()

    // This controls complexity inside this individual TMX.
    // It is separate from the dungeon network depth.
    generator.maximumNodeDepth = 3

    await generator.generateNetArea(
        root,
        false
    )


    // ----------------------------------------------------------
    // Export
    // ----------------------------------------------------------

    const outputPath =
        outputArg
            ? path.resolve(outputArg)
            : path.resolve(
                __dirname,
                `../../areas/${areaId}.tmx`
            )

    const exporter =
        new TiledTMXExporter()

    await exporter.ExportTMX(
        generator,
        {
            Name:
                `Dungeon Room ${roomId}`,

            dungeon_run_id:
                runId,

            dungeon_room_id:
                roomId,

            dungeon_depth:
                dungeonDepth,

            dungeon_exit_count:
                actualExitCount,

            // For now every generated map uses the same
            // background as default.tmx.
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
        },
        outputPath
    )

    console.log(
        '[dungeon-generator] wrote',
        outputPath
    )
}


main().catch((error) => {
    console.error(
        '[dungeon-generator] generation failed'
    )

    console.error(error)

    process.exit(1)
})
