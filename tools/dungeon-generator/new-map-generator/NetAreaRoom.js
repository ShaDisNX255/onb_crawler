const { featureCategories } = require('./features.js')
const GenerateForRequirements = require('./NetPrefabGenerator')
const Prefab = require('./Prefab.js')

function createOpenLobbyPrefab(requiredGroundFeatures) {
    const prefab = new Prefab()

    const canvasSize = 21
    const centralSize = 7
    const satelliteSize = 4
    const centralStart = 7
    const centralEnd = centralStart + centralSize - 1

    const matrix = Array.from(
        { length: canvasSize },
        () => Array(canvasSize).fill(0)
    )

    const featureSlots = []

    function randomInt(min, max) {
        return Math.floor(
            Math.random() * (max - min + 1)
        ) + min
    }

    function fillRect(startX, startY, width, height, tileId = 2) {
        for (let y = startY; y < startY + height; y++) {
            for (let x = startX; x < startX + width; x++) {
                matrix[y][x] = tileId
            }
        }
    }

    function addFeatureSlot(x, y) {
        if (
            !featureSlots.some(
                slot => slot.x === x && slot.y === y
            )
        ) {
            featureSlots.push({ x, y })
        }
    }

    function shuffle(array) {
        for (let i = array.length - 1; i > 0; i--) {
            const j = randomInt(0, i)
            const temp = array[i]
            array[i] = array[j]
            array[j] = temp
        }

        return array
    }

    // Smaller central plaza than the old 9x9 Rest Area.
    fillRect(
        centralStart,
        centralStart,
        centralSize,
        centralSize
    )

    // Four useful positions in the central plaza.
    addFeatureSlot(centralStart + 1, centralStart + 1)
    addFeatureSlot(centralEnd - 1, centralStart + 1)
    addFeatureSlot(centralStart + 1, centralEnd - 1)
    addFeatureSlot(centralEnd - 1, centralEnd - 1)

    const directions = shuffle([
        'north',
        'south',
        'west',
        'east',
    ])

    // Most Rest Areas get 3 satellite rooms.
    // The rest get all 4.
    const satelliteCount =
        Math.random() < 0.5
            ? 3
            : 4

    for (let i = 0; i < satelliteCount; i++) {
        const direction = directions[i]
        let roomX
        let roomY

        if (direction === 'north') {
            roomX = randomInt(
                centralStart,
                centralEnd - satelliteSize + 1
            )
            roomY = 1

            // Two-tile-wide, two-tile-long corridor.
            fillRect(
                roomX + 1,
                roomY + satelliteSize,
                2,
                centralStart - (roomY + satelliteSize)
            )
        } else if (direction === 'south') {
            roomX = randomInt(
                centralStart,
                centralEnd - satelliteSize + 1
            )
            roomY = centralEnd + 3

            fillRect(
                roomX + 1,
                centralEnd + 1,
                2,
                roomY - centralEnd - 1
            )
        } else if (direction === 'west') {
            roomX = 1
            roomY = randomInt(
                centralStart,
                centralEnd - satelliteSize + 1
            )

            fillRect(
                roomX + satelliteSize,
                roomY + 1,
                centralStart - (roomX + satelliteSize),
                2
            )
        } else {
            roomX = centralEnd + 3
            roomY = randomInt(
                centralStart,
                centralEnd - satelliteSize + 1
            )

            fillRect(
                centralEnd + 1,
                roomY + 1,
                roomX - centralEnd - 1,
                2
            )
        }

        // Occasionally use the alternate floor tile in a side room.
        const satelliteTile =
            Math.random() < 0.35
                ? 3
                : 2

        fillRect(
            roomX,
            roomY,
            satelliteSize,
            satelliteSize,
            satelliteTile
        )

        // Each small room can hold an NPC or warp.
        addFeatureSlot(
            roomX + randomInt(1, 2),
            roomY + randomInt(1, 2)
        )
    }

    // Future-proofing in case Rest Areas eventually need more
    // NPCs/warps than the current setup.
    if (featureSlots.length < requiredGroundFeatures) {
        for (
            let y = centralStart + 1;
            y < centralEnd &&
                featureSlots.length < requiredGroundFeatures;
            y++
        ) {
            for (
                let x = centralStart + 1;
                x < centralEnd &&
                    featureSlots.length < requiredGroundFeatures;
                x++
            ) {
                addFeatureSlot(x, y)
            }
        }
    }

    // Randomize which features end up in which rooms.
    shuffle(featureSlots)

    prefab.AddMatrixLayer(matrix)

    const middle =
        centralStart +
        Math.floor(centralSize / 2)

    prefab.AddFeature(
        'male_connectors',
        centralStart - 1,
        middle,
        0,
        {}
    )
    prefab.AddFeature(
        'male_connectors',
        centralEnd + 1,
        middle,
        0,
        {}
    )
    prefab.AddFeature(
        'male_connectors',
        middle,
        centralStart - 1,
        0,
        {}
    )
    prefab.AddFeature(
        'male_connectors',
        middle,
        centralEnd + 1,
        0,
        {}
    )

    prefab.AddFeature(
        'female_connectors',
        centralStart,
        middle,
        0,
        {}
    )
    prefab.AddFeature(
        'female_connectors',
        centralEnd,
        middle,
        0,
        {}
    )
    prefab.AddFeature(
        'female_connectors',
        middle,
        centralStart,
        0,
        {}
    )
    prefab.AddFeature(
        'female_connectors',
        middle,
        centralEnd,
        0,
        {}
    )

    for (const slot of featureSlots) {
        prefab.AddFeature(
            'ground_features',
            slot.x,
            slot.y,
            0,
            {}
        )
    }

    return prefab
}

class NetAreaRoom {
    constructor(node, netAreaGenerator) {
        const defaultX = parseInt(netAreaGenerator.width / 2)
        const defaultY = parseInt(netAreaGenerator.length / 2)

        this._x = defaultX
        this._y = defaultY
        this._z = 0
        this.node = node
        this.node.room = this
        this.netAreaGenerator = netAreaGenerator
        this.features = {
            links: {},
            back_links: {},
            next_floor_warps: {},
            text: {},
            page_tags: {},
            tag_boards: {},
            images: {},
            home_warps: {},
            dungeon_npcs: {},
        }
        this.nextGroundFeatureIndex = 0
        this.nextWallFeatureIndex = 0

        const { prefabRequirements, totalRequired } =
            this.determineFeatureRequirementsFromNode(this.node)

        this.prefabRequirements = prefabRequirements
        this.totalRequired = totalRequired

        this.color = this.node['background-color']
        if (!this.color && this.node?.parent?.room?.color) {
            this.color = this.node.parent.room.color
        }

        this.prefab = this.pickSmallestPrefab(node)
        this.width = this.prefab.width
        this.length = this.prefab.length
        this.height = this.prefab.height

        if (this.height > 0) {
            this.isStairs = true
        }

        this.widthRatio = this.width / this.length
        this.lengthRatio = this.length / this.width

        this.placeFeatures()
    }

    determineFeatureRequirementsFromNode(node) {
        const prefabRequirements = {}
        const totalRequired = {
            ground_features: 0,
            wall_features: 0,
            back_links: 0,
        }

        for (const featureCategory in featureCategories) {
            const category = featureCategories[featureCategory]

            for (const featureName in category) {
                const feature = category[featureName]
                let requiredCount = feature.extraRequirements

                if (node?.features) {
                    const nodeCollection =
                        node.features[feature.scrapedName]

                    if (nodeCollection) {
                        requiredCount += nodeCollection.length
                    }

                    totalRequired[featureCategory] += requiredCount
                    prefabRequirements[featureName] = requiredCount
                }
            }
        }

        return {
            prefabRequirements,
            totalRequired,
        }
    }

    pickGroundPlacement(featureName) {
        const positions = this.prefab.features.ground_features
        const index = this.nextGroundFeatureIndex

        if (
            (featureName === 'page_tags' ||
                featureName === 'tag_boards') &&
            index < positions.length
        ) {
            const swapIndex =
                this.netAreaGenerator.RNG.Integer(
                    index,
                    positions.length - 1
                )

            const temp = positions[index]
            positions[index] = positions[swapIndex]
            positions[swapIndex] = temp
        }

        const position = positions[index]
        this.nextGroundFeatureIndex++
        return position
    }

    placeFeatures() {
        for (const category in featureCategories) {
            if (category === 'unplaced') {
                continue
            }

            if (this.prefab.features[category].length === 0) {
                continue
            }

            const featureTypes = featureCategories[category]

            for (const featureName in featureTypes) {
                const featureMapping = featureTypes[featureName]

                if (
                    !this.node?.features ||
                    !this.node.features[featureMapping.scrapedName]
                ) {
                    continue
                }

                const nodeFeaturesOfType =
                    this.node.features[featureMapping.scrapedName]

                for (const featureKey in nodeFeaturesOfType) {
                    let newPlacementPosition

                    if (category === 'ground_features') {
                        newPlacementPosition =
                            this.pickGroundPlacement(featureName)
                    }

                    if (category === 'wall_features') {
                        newPlacementPosition =
                            this.prefab.features[category][
                                this.nextWallFeatureIndex
                            ]
                        this.nextWallFeatureIndex++
                    }

                    const featureData =
                        nodeFeaturesOfType[featureKey]

                    const {
                        x,
                        y,
                        z,
                        properties,
                    } = newPlacementPosition

                    const newFeature =
                        new featureMapping.className(
                            x,
                            y,
                            z,
                            featureData,
                            properties
                        )

                    this.features[featureName][
                        newFeature.locationString
                    ] = newFeature
                }
            }
        }
    }

    connectionsOnZ(targetZ) {
        return this.prefab.features.male_connectors.filter(
            connection => connection.z === targetZ
        )
    }

    getHighestConnectorZ() {
        let highestLayer = 0

        for (const connection of this.prefab.features.male_connectors) {
            if (connection.z > highestLayer) {
                highestLayer = connection.z
            }
        }

        return highestLayer
    }

    filterAllButSmallestPrefabs(prefabList) {
        let leastFeatures = Infinity
        let smallestPrefabs = []

        for (const prefab of prefabList) {
            if (prefab.totalFeatures < leastFeatures) {
                leastFeatures = prefab.totalFeatures
                smallestPrefabs = [prefab]
            } else if (prefab.totalFeatures === leastFeatures) {
                smallestPrefabs.push(prefab)
            }
        }

        return smallestPrefabs
    }

    pickSmallestPrefab(node) {
        if (this.node.isFirstNode) {
            if (!this.node.features) {
                this.node.features = {}
            }

            if (this.netAreaGenerator.isHomePage) {
                this.totalRequired.home_warps = 1
                this.totalRequired.ground_features += 2
                this.node.features.home_warps = [{}]
                this.node.features.tag_boards = [{}]
            } else {
                this.totalRequired.back_links = 1
                this.totalRequired.ground_features += 1
                this.node.features.back_links = [{}]
            }
        }

        const requiredGroundFeatures =
            this.totalRequired.ground_features

        const requiredWallFeatures =
            this.totalRequired.wall_features

        if (node?.room_style === 'lobby') {
            return createOpenLobbyPrefab(
                requiredGroundFeatures
            )
        }

        const requirements = {
            ground_features: requiredGroundFeatures,
            wall_features: requiredWallFeatures,
            stairs: 0,
        }

        if (
            requirements.ground_features === 0 &&
            requirements.wall_features === 0
        ) {
            const childCount =
                node?.features?.children?.length ?? 0

            if (childCount > 0) {
                requirements.stairs = 1
            }
        }

        if (
            requirements.ground_features === 0 &&
            requirements.wall_features === 0 &&
            requirements.stairs === 0
        ) {
            requirements.ground_features = 1
        }

        return GenerateForRequirements(requirements)
    }

    set x(val) {
        if (
            val > 0 &&
            val + this.width < this.netAreaGenerator.width - 1
        ) {
            this._x = val
        }
    }

    set y(val) {
        if (
            val > 0 &&
            val + this.length < this.netAreaGenerator.length - 1
        ) {
            this._y = val
        }
    }

    set z(val) {
        if (
            val >= 0 &&
            val + this.height < this.netAreaGenerator.height - 1
        ) {
            this._z = val
            return
        }

        if (!this.netAreaGenerator.allowLayerGeneration) {
            return
        }

        if (
            val + this.height >=
            this.netAreaGenerator.height - 1
        ) {
            const heightNeeded =
                val +
                this.height -
                (this.netAreaGenerator.height - 1) +
                1

            console.log(
                val + this.height,
                '>=',
                this.netAreaGenerator.height - 1
            )
            console.log('adding layers', heightNeeded)

            this.netAreaGenerator.addLayers(heightNeeded)
            this._z = val
        }
    }

    get x() {
        return this._x
    }

    get y() {
        return this._y
    }

    get z() {
        return this._z
    }
}

module.exports = { NetAreaRoom }
