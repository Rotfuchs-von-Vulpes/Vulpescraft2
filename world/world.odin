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
Primer :: [32][32][32]blockState

Direction :: enum {Up, Bottom, North, South, East, West}
FaceSet :: bit_set[Direction]

Chunk :: struct {
    id: int,
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

getNewChunk :: proc(chunk: ^Chunk, id: int, x, y, z: i32) {
    empty: blockState = {
        id = 0,
        light = {0, 0},
    }

    chunk.id = id
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
    for i in 0..<32 {
        for j in 0..<32 {
            height := int(heightMap[i][j])
            localHeight := height - int(chunk.pos.y) * 32
            topHeight := min(height, 15)
            for k in 0..<32 {
                chunk.primer[i][k][j].light = {0, 0}
                if k >= localHeight {
                    if k == 0 {
                        chunk.opened += {.Bottom}
                    } else if k == 31 {
                        chunk.opened += {.Up}
                    }
                    if i == 0 {
                        chunk.opened += {.West}
                    } else if i == 31 {
                        chunk.opened += {.East}
                    }
                     if j == 0 {
                        chunk.opened += {.South}
                    } else if j == 31 {
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

setBlock :: proc(x, y, z: i32, id: u32, c: ^Chunk, chunks: ^[dynamic]^Chunk) {
    x := x; y := y; z := z; c := c

    for x >= 32 {
        x -= 32
        side := c.sides[.East]
        if side == nil {
            side = eval(c.pos.x + 1, c.pos.y, c.pos.z)
            c.sides[.East] = side
        }
        if .East not_in c.opened {
            append(chunks, side)
            c.opened += {.East}
        }
        c = side
    }
    for x < 0 {
        x += 32
        side := c.sides[.West]
        if side == nil {
            side = eval(c.pos.x - 1, c.pos.y, c.pos.z)
            c.sides[.West] = side
        }
        if .West not_in c.opened {
            append(chunks, side)
            c.opened += {.West}
        }
        c = side
    }
    for y >= 32 {
        y -= 32
        side := c.sides[.Up]
        if side == nil {
            side = eval(c.pos.x, c.pos.y + 1, c.pos.z)
            c.sides[.Up] = side
            //skeewb.console_log(.INFO, "ah, %s", .Up in c.opened ? "true" : "false")
        }
        if .Up not_in c.opened {
            append(chunks, side)
            c.opened += {.Up}
        }
        c = side
    }
    for y < 0 {
        y += 32
        side := c.sides[.Bottom]
        if side == nil {
            side = eval(c.pos.x, c.pos.y - 1, c.pos.z)
            c.sides[.Bottom] = side
        }
        if .Bottom not_in c.opened {
            append(chunks, side)
            c.opened += {.Bottom}
        }
        c = side
    }
    for z >= 32 {
        z -= 32
        side := c.sides[.North]
        if side == nil {
            side = eval(c.pos.x, c.pos.y, c.pos.z + 1)
            c.sides[.North] = side
        }
        if .North not_in c.opened {
            append(chunks, side)
            c.opened += {.North}
        }
        c = side
    }
    for z < 0 {
        z += 32
        side := c.sides[.South]
        if side == nil {
            side = eval(c.pos.x, c.pos.y, c.pos.z - 1)
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

placeTree :: proc(x, y, z: i32, c: ^Chunk, chunks: ^[dynamic]^Chunk) {
    setBlock(x, y, z, 2, c, chunks)

    for i := y + 1; i <= y + 5; i += 1 {
        if i - y == 2 {
            setBlock(x, i, z, 9, c, chunks)
        } else {
            setBlock(x, i, z, 6, c, chunks)
        }
    }

    for i: i32 = x - 2; i <= x + 2; i += 1 {
        for j: i32 = z - 2; j <= z + 2; j += 1 {
            for k: i32 = y + 3; k <= y + 4; k += 1 {
                xx := i == x - 2 || i == x + 2
                zz := j == z - 2 || j == z + 2

                if xx && zz || i == x && j == z {continue}

                setBlock(i, k, j, 7, c, chunks);
            }
        }
    }
    
    for i: i32 = x - 1; i <= x + 1; i += 1 {
        for j: i32 = z - 1; j <= z + 1; j += 1 {
            for k: i32 = y + 5; k <= y + 6; k += 1 {
                xx := i == x - 1 || i == x + 1
                zz := j == z - 1 || j == z + 1

                if xx && zz || k == y + 5 && i == x && j == z {continue}

                setBlock(i, k, j, 7, c, chunks);
            }
        }
    }
}

populate :: proc(popChunks: ^[dynamic]^Chunk, chunks: ^[dynamic]^Chunk) {
    for c in popChunks {
        x := c.pos.x
        y := c.pos.y
        z := c.pos.z
        
        state := rand.create(u64(math.abs(x * 263781623 + y * 3647463 + z)))
        rnd := rand.default_random_generator(&state)
        n := int(math.floor(3 * rand.float32(rnd) + 3))
        
        for i in 0..<n {
            x0 := u32(math.floor(32 * rand.float32(rnd)))
            z0 := u32(math.floor(32 * rand.float32(rnd)))
        
            toPlace := false
            y0: u32 = 0
            for j in 0..<32 {
                y0 = u32(j)
                if c.primer[x0][j][z0].id == 3 {
                    toPlace = true
                    break
                }
            }
        
            if toPlace {
                placeTree(i32(x0), i32(y0), i32(z0), c, chunks)
            }
        }

        c.level = 2
    }
}

iluminate :: proc(chunk: ^Chunk) {
    light :: struct{
        pos: iVec3,
        lm: [2]i8,
    }

    for x in 0..<32 {
        for z in 0..<32 {
            findSolidBlock := false
            for y: i32 = 31; y >= 0; y -= 1 {
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
                    chunk.primer[x][y][z].light.y = y < 31 ? clamp(chunk.primer[x][y + 1][z].light.y - 1, 0, 15) : 0
                } else {
                    chunk.primer[x][y][z].light.x = 0
                    chunk.primer[x][y][z].light.y = 15
                }
            } 
        }
    }

    noWorkDoneCache := [32]bool{} 
    for i in 0..<16 {
        for y in 0..<32 {
            if noWorkDoneCache[y] {continue}
            noWorkDone := true
            for x in 0..<32 {
                for z in 0..<32 {
                    state := &chunk.primer[x][y][z]

                    if state.id != 0 {continue}
                    if state.light.x >= 15 && state.light.x >= 15 {continue}

                    noWorkDone = false

                    nx := x == 0  ? [2]u8{0, 0} : chunk.primer[x - 1][y][z].light
                    px := x == 31 ? [2]u8{0, 0} : chunk.primer[x + 1][y][z].light
                    ny := y == 0  ? [2]u8{0, 0} : chunk.primer[x][y - 1][z].light
                    py := y == 31 ? [2]u8{0, 0} : chunk.primer[x][y + 1][z].light
                    nz := z == 0  ? [2]u8{0, 0} : chunk.primer[x][y][z - 1].light
                    pz := z == 31 ? [2]u8{0, 0} : chunk.primer[x][y][z + 1].light

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

    /*
    for worm in worms {
        tested[worm.pos.x][worm.pos.y][worm.pos.z] = true
        if worm.pos.y > 0 {
            if chunk.primer[worm.pos.x][worm.pos.y - 1][worm.pos.z].id == 0 {
                append(&worms, light{{worm.pos.x, worm.pos.y - 1, worm.pos.z}, worm.lm})
            }
        }
    }
    
    for worm in worms {
        pos := worm.pos
        tested[pos.x][pos.y][pos.z] = true
        chunk.primer[pos.x][pos.y][pos.z].light = {u8(worm.lm.x), u8(worm.lm.y)}
        /*
        if pos.x > 0 && !tested[pos.x - 1][pos.y][pos.z] {
            id := chunk.primer[pos.x - 1][pos.y][pos.z].id
            if id == 0 || id == 8 || id == 7 {
                append(&worms, light{{pos.x - 1, pos.y, pos.z}, {clamp(worm.lm.x - 1, 0, 15), clamp(worm.lm.y - 1, 0, 15)}})
            }
        } else if pos.x < 31 && !tested[pos.x + 1][pos.y][pos.z] {
            id := chunk.primer[pos.x + 1][pos.y][pos.z].id
            if id == 0 || id == 8 || id == 7 {
                append(&worms, light{{pos.x + 1, pos.y, pos.z}, {clamp(worm.lm.x - 1, 0, 15), clamp(worm.lm.y - 1, 0, 15)}})
            }
        }
        if pos.y > 0 && !tested[pos.x][pos.y - 1][pos.z] {
            id := chunk.primer[pos.x][pos.y - 1][pos.z].id
            if id == 0 || id == 8 || id == 7 {
                append(&worms, light{{pos.x, pos.y - 1, pos.z}, {clamp(worm.lm.x - 1, 0, 15), clamp(worm.lm.y - 1, 0, 15)}})
            }
        } else if pos.y < 31 && !tested[pos.x][pos.y + 1][pos.z] {
            id := chunk.primer[pos.x][pos.y + 1][pos.z].id
            if id == 0 || id == 8 || id == 7 {
                append(&worms, light{{pos.x, pos.y + 1, pos.z}, {clamp(worm.lm.x - 1, 0, 15), clamp(worm.lm.y - 1, 0, 15)}})
            }
        }
        if pos.z > 0 && !tested[pos.x][pos.y][pos.z - 1] {
            id := chunk.primer[pos.x][pos.y][pos.z - 1].id
            if id == 0 || id == 8 || id == 7 {
                append(&worms, light{{pos.x, pos.y, pos.z - 1}, {clamp(worm.lm.x - 1, 0, 15), clamp(worm.lm.y - 1, 0, 15)}})
            }
        } else if pos.z < 31 && !tested[pos.x][pos.y][pos.z + 1] {
            id := chunk.primer[pos.x][pos.y][pos.z + 1].id
            if id == 0 || id == 8 || id == 7 {
                append(&worms, light{{pos.x, pos.y, pos.z + 1}, {clamp(worm.lm.x - 1, 0, 15), clamp(worm.lm.y - 1, 0, 15)}})
            }
        }
            */
    }*/

    chunk.level = 3
}

eval :: proc(x, y, z: i32) -> ^Chunk {
    pos := iVec3{x, y, z}
    chunk, inserted, _ := util.map_force_get(&allChunks, pos)
    if inserted {
        idx := len(allChunks)
        chunk^ = new(Chunk)
        getNewChunk(chunk^, idx, x, y, z)
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

    //skeewb.console_log(.INFO, "added: %d, %d, %d", pos.x, pos.y, pos.z)

    history[pos] = true

    return true
}

peak :: proc(x, y, z: i32) -> [dynamic]^Chunk {
    chunksToView := [dynamic]^Chunk{}
    //chunks := [dynamic]Chunk{}
    //defer delete(chunks)
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
        c := eval(worm.x, worm.y, worm.z)
        append(&chunksToSide, c)
        //skeewb.console_log(.INFO, "%d", c.pos.y)
        // if c.level == 0 {setBlocksChunk(c, terrain.getHeightMap(worm.x, worm.z))}
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

    populate(&chunksToPopulate, &chunksToSide)

    for chunk in chunksToSide {
        dist := chunk.pos - iVec3{x, y, z}
        if abs(dist.x) < VIEW_DISTANCE && abs(dist.y) < VIEW_DISTANCE && abs(dist.z) < VIEW_DISTANCE {
            iluminate(chunk)
            append(&chunksToView, chunk)
        }
    }

    return chunksToView
}

getPosition :: proc(pos: iVec3) -> (^Chunk, iVec3) {
    chunkPos := iVec3{
        i32(math.floor(f32(pos.x) / 32)),
        i32(math.floor(f32(pos.y) / 32)),
        i32(math.floor(f32(pos.z) / 32))
    }

    chunk := eval(chunkPos.x, chunkPos.y, chunkPos.z)

    iPos: iVec3
    iPos.x = pos.x %% 32
    iPos.y = pos.y %% 32
    iPos.z = pos.z %% 32

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

    if pos.x >= 16 {
        offsetX += 1
    } else {
        offsetX -= 1
    }

    if pos.y >= 16 {
        offsetY += 1
    } else {
        offsetY -= 1
    }

    if pos.z >= 16 {
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
                chunk := eval(chunkPos.x, chunkPos.y, chunkPos.z)

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
    } else if pos.x == 31 {
        chunk.opened += {.East}
    }
    if pos.y == 0 {
        chunk.opened += {.Bottom}
    } else if pos.y == 31 {
        chunk.opened += {.Up}
    }
    if pos.z == 0 {
        chunk.opened += {.South}
    } else if pos.z == 31 {
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
    } else if pos.x == 31 {
        chunk.opened += {.East}
    }
    if pos.y == 0 {
        chunk.opened += {.Bottom}
    } else if pos.y == 31 {
        chunk.opened += {.Up}
    }
    if pos.z == 0 {
        chunk.opened += {.South}
    } else if pos.z == 31 {
        chunk.opened += {.North}
    }
    
    chunks = atualizeChunks(chunk, pos)

    return chunks, pos, true
}

nuke :: proc() {
    delete(chunkMap)
    for pos, chunk in allChunks {
        free(chunk)
    }
    delete(allChunks)
}
