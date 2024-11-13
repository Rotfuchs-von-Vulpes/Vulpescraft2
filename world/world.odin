package world

import "../skeewb"
import "core:math"
import "core:math/rand"
import "core:fmt"
import "core:mem/virtual"
import "../util"
import "terrain"

iVec2 :: [2]i32
iVec3 :: [3]i32
vec3 :: [3]f32

blockState :: struct {
    id: u32,
    light: [2]u8,
}
Primer :: [16][16][16]blockState

Direction :: enum {Up, Bottom, North, South, East, West}
FaceSet :: bit_set[Direction]

Chunk :: struct {
    pos: iVec3,
    sides: [Direction]^Chunk,
    primer: Primer,
    opened: FaceSet,
    level: int
}

allChunks := make(map[iVec3]^Chunk)
chunkMap := make(map[iVec3]int)
nodeMap := make(map[iVec3]int)
blocked := make(map[iVec3]bool)
populated := make(map[iVec3]bool)

getNewChunk :: proc(chunk: ^Chunk, x, y, z: i32) {
    empty: blockState = {
        id = 0,
        light = {0, 0},
    }

    chunk.level = 0
    chunk.opened = {}
    chunk.pos = {x, y, z}
    chunk.sides = {
        .Up = nil,
        .Bottom = nil,
        .North = nil,
        .South = nil,
        .East = nil,
        .West = nil
    }
}

setBlocksChunk :: proc(chunk: ^Chunk, heightMap: terrain.HeightMap) {
    for i in 0..<16 {
        for j in 0..<16 {
            height := int(heightMap[i][j])
            localHeight := height - int(chunk.pos.y) * 16
            topHeight := min(height, 15)
            for k in 0..<16 {
                chunk.primer[i][k][j].light = {0, 0}
                if k >= localHeight {
                    if k == 0 {
                        chunk.opened += {.Bottom}
                    } else if k == 15 {
                        chunk.opened += {.Up}
                    }
                    if i == 0 {
                        chunk.opened += {.West}
                    } else if i == 15 {
                        chunk.opened += {.East}
                    }
                     if j == 0 {
                        chunk.opened += {.South}
                    } else if j == 15 {
                        chunk.opened += {.North}
                    }
                }
                if localHeight - k > 0 {
                    if height > 15 {
                        if localHeight - k > 4 {
                            chunk.primer[i][k][j].id = 1
                        } else if localHeight - k > 1 {
                            chunk.primer[i][k][j].id = 2
                        } else {
                            chunk.primer[i][k][j].id = 3
                        }
                    } else {
                        if localHeight - k > 3 {
                            chunk.primer[i][k][j].id = 1
                        } else {
                            chunk.primer[i][k][j].id = 4
                        }
                    }
                } else if chunk.pos.y == 0 && k < 15 {
                    chunk.primer[i][k][j].id = 8
                } else {
                    break
                }
            }
        }
    }

    chunk.level = 1
}

setBlock :: proc(x, y, z: i32, id: u32, c: ^Chunk, chunks: ^[dynamic]^Chunk, tempMap: ^map[iVec3]^Chunk) {
    x := x; y := y; z := z; c := c

    for x >= 16 {
        x -= 16
        side := c.sides[.East]
        if side == nil {
            side = eval(c.pos.x + 1, c.pos.y, c.pos.z, tempMap)
            c.sides[.East] = side
        }
        if .East not_in c.opened {
            append(chunks, side)
            c.opened += {.East}
        }
        c = side
    }
    for x < 0 {
        x += 16
        side := c.sides[.West]
        if side == nil {
            side = eval(c.pos.x - 1, c.pos.y, c.pos.z, tempMap)
            c.sides[.West] = side
        }
        if .West not_in c.opened {
            append(chunks, side)
            c.opened += {.West}
        }
        c = side
    }
    for y >= 16 {
        y -= 16
        side := c.sides[.Up]
        if side == nil {
            side = eval(c.pos.x, c.pos.y + 1, c.pos.z, tempMap)
            c.sides[.Up] = side
        }
        if .Up not_in c.opened {
            append(chunks, side)
            c.opened += {.Up}
        }
        c = side
    }
    for y < 0 {
        y += 16
        side := c.sides[.Bottom]
        if side == nil {
            side = eval(c.pos.x, c.pos.y - 1, c.pos.z, tempMap)
            c.sides[.Bottom] = side
        }
        if .Bottom not_in c.opened {
            append(chunks, side)
            c.opened += {.Bottom}
        }
        c = side
    }
    for z >= 16 {
        z -= 16
        side := c.sides[.North]
        if side == nil {
            side = eval(c.pos.x, c.pos.y, c.pos.z + 1, tempMap)
            c.sides[.North] = side
        }
        if .North not_in c.opened {
            append(chunks, side)
            c.opened += {.North}
        }
        c = side
    }
    for z < 0 {
        z += 16
        side := c.sides[.South]
        if side == nil {
            side = eval(c.pos.x, c.pos.y, c.pos.z - 1, tempMap)
            c.sides[.South] = side
        }
        if .South not_in c.opened {
            append(chunks, side)
            c.opened += {.South}
        }
        c = side
    }

    c.primer[x][y][z].id = id
    c.primer[x][y][z].light = {0, 0}
}

placeTree :: proc(x, y, z: i32, c: ^Chunk, chunks: ^[dynamic]^Chunk, tempMap: ^map[iVec3]^Chunk) {
    setBlock(x, y, z, 2, c, chunks, tempMap)

    for i := y + 1; i <= y + 5; i += 1 {
        if i - y == 2 {
            setBlock(x, i, z, 9, c, chunks, tempMap)
        } else {
            setBlock(x, i, z, 6, c, chunks, tempMap)
        }
    }

    for i: i32 = x - 2; i <= x + 2; i += 1 {
        for j: i32 = z - 2; j <= z + 2; j += 1 {
            for k: i32 = y + 3; k <= y + 4; k += 1 {
                xx := i == x - 2 || i == x + 2
                zz := j == z - 2 || j == z + 2

                if xx && zz || i == x && j == z {continue}

                setBlock(i, k, j, 7, c, chunks, tempMap);
            }
        }
    }
    
    for i: i32 = x - 1; i <= x + 1; i += 1 {
        for j: i32 = z - 1; j <= z + 1; j += 1 {
            for k: i32 = y + 5; k <= y + 6; k += 1 {
                xx := i == x - 1 || i == x + 1
                zz := j == z - 1 || j == z + 1

                if xx && zz || k == y + 5 && i == x && j == z {continue}

                setBlock(i, k, j, 7, c, chunks, tempMap);
            }
        }
    }
}

populate :: proc(popChunks: ^[dynamic]^Chunk, chunks: ^[dynamic]^Chunk, tempMap: ^map[iVec3]^Chunk) {
    for c in popChunks {
        x := c.pos.x
        y := c.pos.y
        z := c.pos.z
        
        state := rand.create(u64(math.abs(x * 263781623 + y * 3647463 + z)))
        rnd := rand.default_random_generator(&state)
        n := int(math.floor(3 * rand.float32(rnd) + 3))
        
        for i in 0..<n {
            x0 := u32(math.floor(16 * rand.float32(rnd)))
            z0 := u32(math.floor(16 * rand.float32(rnd)))
        
            toPlace := false
            y0: u32 = 0
            for j in 0..<16 {
                y0 = u32(j)
                if c.primer[x0][j][z0].id == 3 {
                    toPlace = true
                    break
                }
            }
        
            if toPlace {
                placeTree(i32(x0), i32(y0), i32(z0), c, chunks, tempMap)
            }
        }

        c.level = 2
    }
}

getLumeBlock :: proc(x, y, z: int, c: ^Chunk, tempMap: ^map[iVec3]^Chunk) -> ^[2]u8 {
    x := x; y := y; z := z; c := c

    if x >= 16 {
        x -= 16
        side := c.sides[.East]
        if side == nil {
            side = eval(c.pos.x + 1, c.pos.y, c.pos.z, tempMap)
            c.sides[.East] = side
        }
        c = side
    }
    if x < 0 {
        x += 16
        side := c.sides[.West]
        if side == nil {
            side = eval(c.pos.x - 1, c.pos.y, c.pos.z, tempMap)
            c.sides[.West] = side
        }
        c = side
    }
    if y >= 16 {
        y -= 16
        side := c.sides[.Up]
        if side == nil {
            side = eval(c.pos.x, c.pos.y + 1, c.pos.z, tempMap)
            c.sides[.Up] = side
        }
        c = side
    }
    if y < 0 {
        y += 16
        side := c.sides[.Bottom]
        if side == nil {
            side = eval(c.pos.x, c.pos.y - 1, c.pos.z, tempMap)
            c.sides[.Bottom] = side
        }
        c = side
    }
    if z >= 16 {
        z -= 16
        side := c.sides[.North]
        if side == nil {
            side = eval(c.pos.x, c.pos.y, c.pos.z + 1, tempMap)
            c.sides[.North] = side
        }
        c = side
    }
    if z < 0 {
        z += 16
        side := c.sides[.South]
        if side == nil {
            side = eval(c.pos.x, c.pos.y, c.pos.z - 1, tempMap)
            c.sides[.South] = side
        }
        c = side
    }

    return &c.primer[x][y][z].light
}

iluminate :: proc(chunk: ^Chunk, tempMap: ^map[iVec3]^Chunk) {
    light :: struct{
        pos: iVec3,
        lm: [2]i8,
    }

    for x in 0..<16 {
        for z in 0..<16 {
            findSolidBlock := false
            for y: i32 = 15; y >= 0; y -= 1 {
                id := chunk.primer[x][y][z].id
                transparentBlock := id == 7 || id == 8

                if id != 0 && !transparentBlock {
                    findSolidBlock = true
                }

                if findSolidBlock {
                    if id == 9 {
                        chunk.primer[x][y][z].light = {15, 0}
                    } else {
                        chunk.primer[x][y][z].light = {0, 0}
                    }
                } else if transparentBlock {
                    chunk.primer[x][y][z].light.x = 0
                    chunk.primer[x][y][z].light.y = y < 15 ? clamp(chunk.primer[x][y + 1][z].light.y - 1, 0, 15) : 0
                } else {
                    chunk.primer[x][y][z].light.x = 0
                    chunk.primer[x][y][z].light.y = 15
                }
            } 
        }
    }

    noWorkDoneCache := [16]bool{} 
    for i in 0..<16 {
        for y in 0..<16 {
            if noWorkDoneCache[y] {continue}
            noWorkDone := true
            for x in 0..<16 {
                for z in 0..<16 {
                    state := &chunk.primer[x][y][z]

                    if state.id != 0 {continue}
                    if state.light.x >= 15 && state.light.x >= 15 {continue}

                    noWorkDone = false

                    nx := getLumeBlock(x - 1, y, z, chunk, tempMap)
                    px := getLumeBlock(x + 1, y, z, chunk, tempMap)
                    ny := getLumeBlock(x, y - 1, z, chunk, tempMap)
                    py := getLumeBlock(x, y + 1, z, chunk, tempMap)
                    nz := getLumeBlock(x, y, z - 1, chunk, tempMap)
                    pz := getLumeBlock(x, y, z + 1, chunk, tempMap)

                    blockLight: u8 = 0;
                    if state.light.x <= 16 {
                        blockLight = max(max(max(nx.x, px.x), max(ny.x, py.x)), max(nz.x, pz.x))
                        if blockLight > 0 {blockLight -= 1}
                        blockLight = max(blockLight, state.light.x)
                    }
                    sunLight: u8 = 0;
                    if state.light.y < 16 {
                        sunLight = max(max(max(nx.y, px.y), max(ny.y, py.y)), max(nz.y, pz.y))
                        if sunLight > 0 {sunLight -= 1}
                        sunLight = max(sunLight, state.light.y)
                    }

                    state.light = {blockLight, sunLight}
                }
            }
            noWorkDoneCache[y] = noWorkDone
        }
    }

    chunk.level = 3
}

eval :: proc(x, y, z: i32, tempMap: ^map[iVec3]^Chunk) -> ^Chunk {
    pos := iVec3{x, y, z}
    chunk, inserted, _ := util.map_force_get(tempMap, pos)
    if inserted {
        // skeewb.console_log(.INFO, "%d", chunk^.primer[0][0][0].id)
        chunk^ = new(Chunk)
        getNewChunk(chunk^, x, y, z)
        setBlocksChunk(chunk^, terrain.getHeightMap(x, z))
    }
    return chunk^
}

length :: proc(v: iVec3) -> i32 {
    return i32((v.x * v.x + v.y * v.y + v.z * v.z))
}

VIEW_DISTANCE :: 6

addWorm :: proc(pos, center: iVec3, history: ^map[iVec3]bool) -> bool {
    if abs(pos.x - center.x) > VIEW_DISTANCE + 2 || abs(pos.y - center.y) > VIEW_DISTANCE + 2 || abs(pos.z - center.z) > VIEW_DISTANCE + 2 {return false}

    if pos in history {return false}

    history[pos] = true

    return true
}

peak :: proc(x, y, z: i32, tempMap: ^map[iVec3]^Chunk) -> [dynamic]^Chunk {
    chunksToView := [dynamic]^Chunk{}
    chunksToSide := [dynamic]^Chunk{}
    defer delete(chunksToSide)
    chunksToPopulate := [dynamic]^Chunk{}
    defer delete(chunksToPopulate)
    r: i32 = VIEW_DISTANCE + 2
    rr: i32 = VIEW_DISTANCE + 1

    worms: [dynamic]iVec3 = {{x, y, z}}
    defer delete(worms)
    history := make(map[iVec3]bool)
    defer delete(history)
    history[worms[0]] = true

    for i := 0; i < len(worms); i += 1 {
        worm := worms[i]
        c := eval(worm.x, worm.y, worm.z, tempMap)
        if c == nil {
            skeewb.console_log(.INFO, "bruh")
            continue
        }
        append(&chunksToSide, c)
        if c.level == 1 && abs(worm.x - x) < VIEW_DISTANCE + 1 && abs(worm.y - y) < VIEW_DISTANCE + 1 && abs(worm.z - z) < VIEW_DISTANCE + 1 {append(&chunksToPopulate, c)}

        if .West in c.opened && addWorm(worm + {-1, 0, 0}, {x, y, z}, &history) {
            append(&worms, iVec3{worm.x - 1, worm.y, worm.z})
        }
        if .East in c.opened && addWorm(worm + { 1, 0, 0}, {x, y, z}, &history) {
            append(&worms, iVec3{worm.x + 1, worm.y, worm.z})
        }
        if .Bottom in c.opened && addWorm(worm + { 0,-1, 0}, {x, y, z}, &history) {
            append(&worms, iVec3{worm.x, worm.y - 1, worm.z})
        }
        if .Up in c.opened && addWorm(worm + { 0, 1, 0}, {x, y, z}, &history) {
            append(&worms, iVec3{worm.x, worm.y + 1, worm.z})
        }
        if .South in c.opened && addWorm(worm + { 0, 0,-1}, {x, y, z}, &history) {
            append(&worms, iVec3{worm.x, worm.y, worm.z - 1})
        }
        if .North in c.opened && addWorm(worm + { 0, 0, 1}, {x, y, z}, &history) {
            append(&worms, iVec3{worm.x, worm.y, worm.z + 1})
        }
    }

    populate(&chunksToPopulate, &chunksToSide, tempMap)

    for chunk in chunksToSide {
        dist := chunk.pos - iVec3{x, y, z}
        if abs(dist.x) < VIEW_DISTANCE && abs(dist.y) < VIEW_DISTANCE && abs(dist.z) < VIEW_DISTANCE {
            append(&chunksToView, chunk)
        }
    }

    for chunk in chunksToPopulate {
        iluminate(chunk, tempMap)
    }

    return chunksToView
}

getPosition :: proc(pos: iVec3) -> (^Chunk, iVec3) {
    chunkPos := iVec3{
        i32(math.floor(f32(pos.x) / 16)),
        i32(math.floor(f32(pos.y) / 16)),
        i32(math.floor(f32(pos.z) / 16))
    }

    chunk := eval(chunkPos.x, chunkPos.y, chunkPos.z, &allChunks)

    iPos: iVec3
    iPos.x = pos.x %% 16
    iPos.y = pos.y %% 16
    iPos.z = pos.z %% 16

    return chunk, iPos
}

toiVec3 :: proc(vec: vec3) -> iVec3 {
    return iVec3{
        i32(math.floor(vec.x)),
        i32(math.floor(vec.y)),
        i32(math.floor(vec.z)),
    }
}

raycast :: proc(origin, direction: vec3, place: bool) -> (^Chunk, iVec3, bool) {
    fPos := origin
    pos, pPos, lastBlock: iVec3

    chunk: ^Chunk
    pChunk: ^Chunk
    ok: bool = true

    step: f32 = 0.05
    length: f32 = 0
    maxLength: f32 = 10
    for length < maxLength {
        iPos := toiVec3(fPos)

        if lastBlock != iPos {
            chunk, pos = getPosition(iPos)
            if ok && chunk.primer[pos.x][pos.y][pos.z].id != 0 {
                if place {
                    offset := iPos - lastBlock
                    if math.abs(offset.x) + math.abs(offset.y) + math.abs(offset.z) != 1 {
                        if offset.x != 0 {
                            chunk, pos = getPosition({iPos.x + offset.x, iPos.y, iPos.z})
                            if ok && chunk.primer[pos.x][pos.y][pos.z].id != 0 {
                                return chunk, pos, true
                            }
                        }
                        if offset.y != 0 {
                            chunk, pos = getPosition({iPos.x, iPos.y + offset.y, iPos.z})
                            if ok && chunk.primer[pos.x][pos.y][pos.z].id != 0 {
                                return chunk, pos, true
                            }
                        }
                        if offset.z != 0 {
                            chunk, pos = getPosition({iPos.x, iPos.y, iPos.z + offset.z})
                            if ok && chunk.primer[pos.x][pos.y][pos.z].id != 0 {
                                return chunk, pos, true
                            }
                        }
                    } else {
                        return pChunk, pPos, true
                    }
                } else {
                    return chunk, pos, true
                }
            }

            lastBlock = iPos
        }

        pPos = pos
        pChunk = chunk
        fPos += step * direction
        length += step
    }

    return chunk, pos, false
}

atualizeChunks :: proc(chunk: ^Chunk, pos: iVec3) -> [dynamic]^Chunk {
    chunks: [dynamic]^Chunk

    offsetX: i32 = 0
    offsetY: i32 = 0
    offsetZ: i32 = 0

    if pos.x >= 8 {
        offsetX += 1
    } else {
        offsetX -= 1
    }

    if pos.y >= 8 {
        offsetY += 1
    } else {
        offsetY -= 1
    }

    if pos.z >= 8 {
        offsetZ += 1
    } else {
        offsetZ -= 1
    }

    for i in 0..=1 {
        for j in 0..=1 {
            for k in 0..=1 {
                chunkPos: iVec3 = {
                    chunk.pos.x + i32(i) * offsetX,
                    chunk.pos.y + i32(j) * offsetY,
                    chunk.pos.z + i32(k) * offsetZ
                }
                chunk := eval(chunkPos.x, chunkPos.y, chunkPos.z, &allChunks)

                append(&chunks, chunk)
            }
        }
    }

    return chunks
}

destroy :: proc(origin, direction: vec3) -> ([dynamic]^Chunk, iVec3, bool) {
    chunks: [dynamic]^Chunk
    chunk, pos, ok := raycast(origin, direction, false)

    if !ok {return chunks, pos, false}
    chunk.primer[pos.x][pos.y][pos.z].id = 0
    if pos.x == 0 {
        chunk.opened += {.West}
    } else if pos.x == 15 {
        chunk.opened += {.East}
    }
    if pos.y == 0 {
        chunk.opened += {.Bottom}
    } else if pos.y == 15 {
        chunk.opened += {.Up}
    }
    if pos.z == 0 {
        chunk.opened += {.South}
    } else if pos.z == 15 {
        chunk.opened += {.North}
    }

    chunks = atualizeChunks(chunk, pos)

    return chunks, pos, true
}

place :: proc(origin, direction: vec3) -> ([dynamic]^Chunk, iVec3, bool) {
    chunks: [dynamic]^Chunk
    chunk, pos, ok := raycast(origin, direction, true)

    if !ok {return chunks, pos, false}
    chunk.primer[pos.x][pos.y][pos.z].id = 5
    if pos.x == 0 {
        chunk.opened += {.West}
    } else if pos.x == 15 {
        chunk.opened += {.East}
    }
    if pos.y == 0 {
        chunk.opened += {.Bottom}
    } else if pos.y == 15 {
        chunk.opened += {.Up}
    }
    if pos.z == 0 {
        chunk.opened += {.South}
    } else if pos.z == 15 {
        chunk.opened += {.North}
    }
    
    chunks = atualizeChunks(chunk, pos)

    return chunks, pos, true
}

nuke :: proc() {
    delete(chunkMap)
    // for pos, chunk in allChunks {
    //     free(chunk)
    // }
    delete(allChunks)
}
