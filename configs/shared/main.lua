return {
    debug = false,

    items = {
        shovel      = 'snowy_shovel',
        wheelbarrow = 'snowy_wheelbarrow',
    },

    piles = {
        renderDistance = 90.0,
        scoopDistance  = 3.0,
        maxTiltDeg     = 22.0,
        sinkDepth      = 0.03,
        types = {
            { full = 'snowy_pile_01_full', chunk = 'snowy_chunk_01_%02d', parts = 8  },
            { full = 'snowy_pile_02_full', chunk = 'snowy_chunk_02_%02d', parts = 9  },
            { full = 'snowy_pile_03_full', chunk = 'snowy_chunk_03_%02d', parts = 12 },
            { full = 'snowy_pile_04_full', chunk = 'snowy_chunk_04_%02d', parts = 16 },
            { full = 'snowy_pile_05_full', chunk = 'snowy_chunk_05_%02d', parts = 16 },
        },
    },

    shovel = {
        model     = 'snowy_shovel',
        loadModel = 'snowy_shovel_load_full',
        bone      = 28422,
        leftBone  = 60309,
        rotationOrder = 2,
        offsets = {
            unloaded = { pos = vec3(0.2060, 0.5033, 0.1641),   rot = vec3(13.455, -69.250, -114.727) },
            loaded   = { pos = vec3(-0.0628, -0.2480, -0.1288), rot = vec3(112.692, -26.724, 8.932) },
            leftHand = { pos = vec3(-0.2202, -0.6876, 0.3002),  rot = vec3(69.417, 11.445, -31.892) },
        },
        walkShift = {
            unloaded = vec3(-0.0093, -0.0149, 0.0468),
            loaded   = vec3(-0.0176, -0.0342, -0.0319),
        },
        walkBlendMs = 300,
        work = {
            { clip = 'shovel_scoop', frames = 88, toLeft = 8,  toRight = 20, before = 'unloaded', after = 'loaded' },
            { clip = 'shovel_dump',  frames = 72, toLeft = 53, toRight = 64, before = 'loaded',   after = 'unloaded' },
        },
        scoopTurnDeg = -90.0,
        scoopAnimTurnDeg = 180.0,
        dumpSideDeg  = 59.0,
        turnMs       = 1200,
        scoopMs      = 2933,
        dumpMs       = 2400,
        tipAtMs      = 700,
    },

    barrow = {
        model          = 'prop_wheelbarrow01a',
        capacity       = 6,
        interactRange  = 2.2,
        bone           = 28422,
        offset         = { pos = vec3(0.6750, 0.7411, -0.2844), rot = vec3(-50.471, -32.778, 43.899) },
        stages = {
            { min = 3, model = 'snowy_barrow_load_half' },
            { min = 6, model = 'snowy_barrow_load_full' },
        },
    },

    anims = {
        shovelDict = 'snowy@shovel',
        barrowDict = 'snowy@barrow',
        upperBodyLoopFlag = 49,
        upperBodyOnceFlag = 48,
        holdLastFrameFlag = 2,
        moveRatio = 0.1,
        minSwitchMs = 250,
        restartGraceMs = 500,
        loopBlend = 4.0,
    },

    keys = {
        interact = 38,
        pickup   = 74,
        dump     = 47,
    },
}
