const fs = require('fs')
const path = require('path')

const { NetAreaGenerator } = require('./new-map-generator/NetAreaGenerator')
const TiledTMXExporter = require('./map-exporter/TiledTMXExporter')

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

async function main() {
    console.log('[dungeon-test] building synthetic dungeon tree...')

    const root = createDungeonNode(0, 3)

    assignParents(root)

    console.log(
        '[dungeon-test] generated tree with',
        countNodes(root),
        'nodes'
    )

    const generator = new NetAreaGenerator()

    // Our synthetic tree only goes this deep for this test.
    generator.maximumNodeDepth = 3

    console.log('[dungeon-test] generating ONB map geometry...')

    await generator.generateNetArea(root, false)

    console.log(
        '[dungeon-test] final trimmed size:',
        generator.width,
        'x',
        generator.length,
        'x',
        generator.height
    )

    const exporter = new TiledTMXExporter()

    const outputPath = path.resolve(
        __dirname,
        '../../areas/dungeon_generated.tmx'
    )

    console.log('[dungeon-test] exporting:', outputPath)

    await exporter.ExportTMX(
        generator,
        {
            Name: 'Generated Dungeon Test',
        },
        outputPath
    )

    // The first generated room already contains an inert BackLink object.
    // Its inherited exporter behavior marks it as the area's entry object.
    const xml = fs.readFileSync(outputPath, 'utf8')

    const entryMatch = xml.match(
        /<property name="entry_warp_id" value="([^"]+)"/
    )

    if (entryMatch) {
        console.log(
            '[dungeon-test] entry object ID:',
            entryMatch[1]
        )
    } else {
        console.warn(
            '[dungeon-test] WARNING: no entry_warp_id found'
        )
    }

    console.log('[dungeon-test] DONE')
}

main().catch((error) => {
    console.error('[dungeon-test] generation failed')
    console.error(error)
    process.exit(1)
})
