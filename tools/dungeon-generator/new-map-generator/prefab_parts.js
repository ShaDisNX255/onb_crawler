let sl = 7
let sr = 8

let slt = 9
let srt = 10

let sdl_base = 12
let sdr_base = 11

let sdl_middle = 14
let sdr_middle = 13

let sdl_top = 12
let sdr_top = 11

let parts = [
    {
        name: '1x1 default',
        width: 1,
        length: 1,
        height: 1,
        matrix: [
            [
                [1]
            ],
        ],
        ground_features: [],
        wall_features: [],
        male_connectors: [
            { x: 1, y: 0, z: 0 },
            { x: -1, y: 0, z: 0 },
        ],
        female_connectors: [
            { x: 0, y: 0, z: 0 },
        ],
    },
    {
        name: '4x3 stairs up left',
        is_stairs: true,
        width: 4,
        length: 3,
        height: 4,
        matrix: [
            [
                [1, 1, 1, 1],
                [1, 1, 1, sl],
                [1, 1, 1, 1],
            ],
            [
                [1, 1, 1, 1],
                [1, 1, sl, 1],
                [1, 1, 1, 1],
            ],
            [
                [1, 1, 1, 1],
                [1, sl, 1, 1],
                [1, 1, 1, 1],
            ],
            [
                [1, 1, 1, 1],
                [2, slt, 1, 1],
                [1, 1, 1, 1],
            ],
        ],
        ground_features: [],
        wall_features: [],
        male_connectors: [
            { x: 4, y: 1, z: 0 },
            { x: -1, y: 1, z: 3 },
        ],
        female_connectors: [
            { x: 3, y: 1, z: 0 },
            { x: 0, y: 1, z: 3 },
        ],
    },
    {
        name: '4x3 stairs up right',
        is_stairs: true,
        width: 3,
        length: 4,
        height: 4,
        matrix: [
            [
                [1, 1, 1],
                [1, 1, 1],
                [1, 1, 1],
                [1, sr, 1],
            ],
            [
                [1, 1, 1],
                [1, 1, 1],
                [1, sr, 1],
                [1, 1, 1],
            ],
            [
                [1, 1, 1],
                [1, sr, 1],
                [1, 1, 1],
                [1, 1, 1],
            ],
            [
                [1, 2, 1],
                [1, srt, 1],
                [1, 1, 1],
                [1, 1, 1],
            ],
        ],
        ground_features: [],
        wall_features: [],
        male_connectors: [
            { x: 1, y: 4, z: 0 },
            { x: 1, y: -1, z: 3 },
        ],
        female_connectors: [
            { x: 1, y: 3, z: 0 },
            { x: 1, y: 0, z: 3 },
        ],
    },
    {
        name: '4x3 stairs down right',
        is_stairs: true,
        width: 4,
        length: 3,
        height: 4,
        matrix: [
          [
              [1, 1, 1, 1],
              [sdr_base, 1, 1, 1],
              [1, 1, 1, 1],
          ],
          [
              [1, 1, 1, 1],
              [1, sdr_middle, 1, 1],
              [1, 1, 1, 1],
          ],
          [
              [1, 1, 1, 1],
              [1, 1, sdr_top, 1],
              [1, 1, 1, 1],
          ],
          [
              [1, 1, 1, 1],
              [1, 1, 1, 2],
              [1, 1, 1, 1],
          ],
        ],
        ground_features: [],
        wall_features: [],
        male_connectors: [
            { x: -1, y: 1, z: 0 },
            { x: 4, y: 1, z: 3 },
        ],
        female_connectors: [
            { x: 0, y: 1, z: 0 },
            { x: 3, y: 1, z: 3 },
        ],
    },
    {
        name: '4x3 stairs down left',
        is_stairs: true,
        width: 3,
        length: 4,
        height: 4,
        matrix: [
          [
              [1, sdl_base, 1],
              [1, 1, 1],
              [1, 1, 1],
              [1, 1, 1],
          ],
          [
              [1, 1, 1],
              [1, sdl_middle, 1],
              [1, 1, 1],
              [1, 1, 1],
          ],
          [
              [1, 1, 1],
              [1, 1, 1],
              [1, sdl_top, 1],
              [1, 1, 1],
          ],
          [
              [1, 1, 1],
              [1, 1, 1],
              [1, 1, 1],
              [1, 2, 1],
          ],
        ],
        ground_features: [],
        wall_features: [],
        male_connectors: [
            { x: 1, y: -1, z: 0 },
            { x: 1, y: 4, z: 3 },
        ],
        female_connectors: [
            { x: 1, y: 0, z: 0 },
            { x: 1, y: 3, z: 3 },
        ],
    },
    {
        name: '3x3 with ground_feature',
        width: 3,
        length: 3,
        height: 1,
        matrix: [
            [
                [2, 2, 2],
                [2, 2, 2],
                [2, 2, 2],
            ],
        ],
        ground_features: [
            {
                x: 1,
                y: 1,
                z: 0,
                properties: {},
            },
        ],
        wall_features: [],
        male_connectors: [
            { x: -1, y: 1, z: 0, },
            { x: 3, y: 1, z: 0, },
            { x: 1, y: -1, z: 0, },
            { x: 1, y: 3, z: 0, },
        ],
        female_connectors: [
            { x: 0, y: 1, z: 0, },
            { x: 2, y: 1, z: 0, },
            { x: 1, y: 0, z: 0, },
            { x: 1, y: 2, z: 0, },
        ],
    },
    {
        name: '3x3 with ground_feature alt',
        width: 3,
        length: 3,
        height: 1,
        matrix: [
            [
                [3, 3, 3],
                [3, 3, 3],
                [3, 3, 3],
            ],
        ],
        ground_features: [
            {
                x: 1,
                y: 1,
                z: 0,
                properties: {},
            },
        ],
        wall_features: [],
        male_connectors: [
            { x: -1, y: 1, z: 0, },
            { x: 3, y: 1, z: 0, },
            { x: 1, y: -1, z: 0, },
            { x: 1, y: 3, z: 0, },
        ],
        female_connectors: [
            { x: 0, y: 1, z: 0, },
            { x: 2, y: 1, z: 0, },
            { x: 1, y: 0, z: 0, },
            { x: 1, y: 2, z: 0, },
        ],
    },
    {
        name: '5x3 with ground_features',
        width: 3,
        length: 3,
        height: 1,
        matrix: [
            [
                [2, 2, 2, 2, 2],
                [2, 2, 2, 2, 2],
                [2, 2, 2, 2, 2],
            ],
        ],
        ground_features: [
            {
                x: 1,
                y: 1,
                z: 0,
                properties: {},
            },
            {
                x: 3,
                y: 1,
                z: 0,
                properties: {},
            },
        ],
        wall_features: [],
        male_connectors: [
            { x: -1, y: 1, z: 0, },
            { x: 5, y: 1, z: 0, },
            { x: 2, y: -1, z: 0, },
            { x: 2, y: 3, z: 0, },
        ],
        female_connectors: [
            { x: 0, y: 1, z: 0, },
            { x: 4, y: 1, z: 0, },
            { x: 2, y: 0, z: 0, },
            { x: 2, y: 2, z: 0, },
        ],
    },
    {
        name: '3x3 with wall_feature_left',
        width: 3,
        length: 3,
        height: 1,
        matrix: [
            [
                [2, 2, 2],
                [2, 2, 2],
                [2, 2, 2],
            ],
        ],
        ground_features: [
            {
                x: 1,
                y: 1,
                z: 0,
                properties: {},
            },
        ],
        wall_features: [
            {
                x: 0,
                y: 1,
                z: 0,
                properties: { Direction: 'Down Right' },
            },
        ],
        male_connectors: [
            { x: 3, y: 1, z: 0, },
            { x: 1, y: -1, z: 0, },
            { x: 1, y: 3, z: 0, },
        ],
        female_connectors: [
            { x: 2, y: 1, z: 0, },
            { x: 1, y: 0, z: 0, },
            { x: 1, y: 2, z: 0, },
        ],
    },
    {
        name: '3x3 with wall_feature_right',
        width: 3,
        length: 3,
        height: 1,
        matrix: [
            [
                [2, 2, 2],
                [2, 2, 2],
                [2, 2, 2],
            ],
        ],
        ground_features: [
            {
                x: 1,
                y: 1,
                z: 0,
                properties: {},
            },
        ],
        wall_features: [
            {
                x: 1,
                y: 0,
                z: 0,
                properties: { Direction: 'Down Left' },
            },
        ],
        male_connectors: [
            { x: 3, y: 1, z: 0, },
            { x: -1, y: 1, z: 0, },
            { x: 1, y: 3, z: 0, },
        ],
        female_connectors: [
            { x: 2, y: 1, z: 0, },
            { x: 0, y: 1, z: 0, },
            { x: 1, y: 2, z: 0, },
        ],
    },
]

module.exports = parts
