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

function findDeepestLeaf(node, depth = 0) {
    const children =
        node.features?.children || []

    if (children.length === 0) {
        return {
            node,
            depth,
        }
    }

    let deepest = null

    for (const child of children) {
        const candidate =
            findDeepestLeaf(
                child,
                depth + 1
            )

        if (
            !deepest ||
            candidate.depth > deepest.depth
        ) {
            deepest = candidate
        }
    }

    return deepest
}

async function main() {
    const [
        areaId,
        runId,
        floorArg,
        hasNextArg,
    ] = process.argv.slice(2)

    if (
        !areaId ||
        !/^[A-Za-z0-9_-]+$/.test(areaId)
    ) {
        throw new Error(
            'Invalid or missing area ID'
        )
    }

    if (!runId) {
        throw new Error(
            'Missing dungeon run ID'
        )
    }

    const floorNumber =
        Number(floorArg)

    if (
        !Number.isInteger(floorNumber) ||
        floorNumber < 1
    ) {
        throw new Error(
            'Invalid floor number'
        )
    }

    const hasNext =
        hasNextArg === '1'

    console.log(
        '[dungeon-generator] generating',
        areaId
    )

    const root =
        createDungeonNode(0, 3)

    assignParents(root)

    if (hasNext) {
        const deepest =
            findDeepestLeaf(root)

        deepest.node.features
            .next_floor_warps = [{}]
    }

    const generator =
        new NetAreaGenerator()

    generator.maximumNodeDepth = 3

    await generator.generateNetArea(
        root,
        false
    )

    const outputPath =
        path.resolve(
            __dirname,
            `../../areas/${areaId}.tmx`
        )

    const exporter =
        new TiledTMXExporter()

    await exporter.ExportTMX(
        generator,
        {
            Name:
                `Dungeon Floor ${floorNumber}`,

            dungeon_run_id:
                runId,

            dungeon_floor:
                floorNumber,
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