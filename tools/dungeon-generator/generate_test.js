const fs = require('fs')
const path = require('path')

const { NetAreaGenerator } = require('./new-map-generator/NetAreaGenerator')
const TiledTMXExporter = require('./map-exporter/TiledTMXExporter')
const crypto = require('crypto')

function randomInt(min, max) {
    return Math.floor(Math.random() * (max - min + 1)) + min
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

    // The root always branches.
    // Deeper nodes may terminate early.
    let childCount

    if (depth === 0) {
        childCount = randomInt(2, 3)
    } else {
        childCount = randomInt(0, 2)
    }

    for (let i = 0; i < childCount; i++) {
        node.features.children.push(
            createDungeonNode(depth + 1, maxDepth)
        )
    }

    return node
}

function assignParents(node, parent = null) {
    node.parent = parent

    const children = node.features?.children || []

    for (const child of children) {
        assignParents(child, node)
    }
}

function countNodes(node) {
    let count = 1

    for (const child of node.features?.children || []) {
        count += countNodes(child)
    }

    return count
}

function findDeepestLeaf(node, depth = 0) {
    const children = node.features?.children || []

    if (children.length === 0) {
        return {
            node,
            depth,
        }
    }

    let deepest = null

    for (const child of children) {
        const candidate = findDeepestLeaf(child, depth + 1)

        if (!deepest || candidate.depth > deepest.depth) {
            deepest = candidate
        }
    }

    return deepest
}

function readEntryObjectId(outputPath) {
    const xml = fs.readFileSync(outputPath, 'utf8')

    const match = xml.match(
        /<property name="entry_warp_id" value="([^"]+)"/
    )

    if (!match) {
        throw new Error(
            `No entry_warp_id found in ${outputPath}`
        )
    }

    return match[1]
}

async function generateFloor(runId, floorNumber, nextFloor = null) {
    console.log(
        `[dungeon-test] generating floor ${floorNumber}...`
    )

    const root = createDungeonNode(0, 3)

    assignParents(root)

    if (nextFloor) {
        const deepest = findDeepestLeaf(root)

        deepest.node.features.next_floor_warps = [
            {
                target_area: nextFloor.areaId,
                target_object: nextFloor.entryObjectId,
            },
        ]

        console.log(
            '[dungeon-test] forward warp:',
            `floor ${floorNumber} -> ${nextFloor.areaId}:${nextFloor.entryObjectId}`
        )
    }

    const generator = new NetAreaGenerator()
    generator.maximumNodeDepth = 3

    await generator.generateNetArea(root, false)

    const floorString = String(floorNumber).padStart(3, '0')

    const areaId =
        `dungeon_${runId}_f${floorString}`

    const outputPath = path.resolve(
        __dirname,
        `../../areas/${areaId}.tmx`
    )

    const exporter = new TiledTMXExporter()

    await exporter.ExportTMX(
        generator,
        {
            Name: `Dungeon Floor ${floorNumber}`,
            dungeon_run_id: runId,
            dungeon_floor: floorNumber,
        },
        outputPath
    )

    const entryObjectId =
        readEntryObjectId(outputPath)

    console.log(
        `[dungeon-test] ${areaId} entry object:`,
        entryObjectId
    )

    return {
        areaId,
        outputPath,
        entryObjectId,
    }
}

async function main() {
    const runId = 'template'

    console.log(
        '[dungeon-test] creating run:',
        runId
    )

    // Generate Floor 2 first because Floor 1 needs to know
    // Floor 2's area ID and entry object.
    const floor2 = await generateFloor(
        runId,
        2
    )

    const floor1 = await generateFloor(
        runId,
        1,
        floor2
    )

    console.log('')
    console.log('[dungeon-test] RUN READY')
    console.log('')
    console.log('Run ID:', runId)
    console.log('')
    console.log('Set the default entrance warp to:')
    console.log('Target Area:', floor1.areaId)
    console.log('Target Object:', floor1.entryObjectId)
    console.log('')
    console.log('Expected route:')
    console.log(
        `default -> ${floor1.areaId} -> ${floor2.areaId}`
    )
    console.log(
        `${floor2.areaId} -> ${floor1.areaId} -> default`
    )
}

main().catch((error) => {
    console.error('[dungeon-test] generation failed')
    console.error(error)
    process.exit(1)
})
