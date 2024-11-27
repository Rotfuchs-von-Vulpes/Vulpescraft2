package world

import "../skeewb"
import "core:math"
import "core:math/rand"
import "core:time"
import "core:fmt"
import "core:mem/virtual"
import "../util"
import "terrain"

iVec2 :: [2]i32
iVec3 :: [3]i32
vec3 :: [3]f32

blockState :: struct {
    id: u16,
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

eval :: proc(x, y, z: i32, tempMap: ^map[iVec3]^Chunk) -> ^Chunk {
    pos := iVec3{x, y, z}
    chunk, empty, _ := util.map_force_get(tempMap, pos)
    if empty {
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
    if abs(pos.x - center.x) > VIEW_DISTANCE || abs(pos.y - center.y) > VIEW_DISTANCE || abs(pos.z - center.z) > VIEW_DISTANCE {return false}

    if pos in history {return false}

    history[pos] = true

    return true
}

hasAllSides :: proc(chunk: ^Chunk) -> bool {
    for side in chunk.sides {
        if side == nil do return false
    }

    return true
}

peak :: proc(x, y, z: i32, tempMap: ^map[iVec3]^Chunk) -> [dynamic]^Chunk {
    chunksToView := [dynamic]^Chunk{}
    chunksToSide := [dynamic]^Chunk{}
    defer delete(chunksToSide)

    worms: [dynamic]iVec3 = {{x, y, z}}
    defer delete(worms)
    history := make(map[iVec3]bool)
    defer delete(history)
    history[worms[0]] = true
    tops := make(map[iVec2]iVec3)

    for i := 0; i < len(worms); i += 1 {
        worm := worms[i]
        c := eval(worm.x, worm.y, worm.z, tempMap)
        append(&chunksToSide, c)

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

    posOffsets: [Direction]iVec3 = {
        .West   = {-1, 0, 0},
        .East   = {1, 0, 0},
        .Bottom = {0, -1, 0},
        .Up     = {0, 1, 0},
        .South  = {0, 0, -1},
        .North  = {0, 0, 1},
    }

    for &chunk in chunksToSide {
        dist := chunk.pos - iVec3{x, y, z}
        if dist.x * dist.x + dist.y * dist.y + dist.z * dist.z <= VIEW_DISTANCE * VIEW_DISTANCE {
            append(&chunksToView, chunk)
        }

        for &c1, dir in chunk.sides {
            offset := posOffsets[dir]
            c1 = eval(chunk.pos.x + offset.x, chunk.pos.y + offset.y, chunk.pos.z + offset.z, tempMap)
                
            for &c2, dir2 in c1.sides {
                offset := posOffsets[dir2]
                c2 = eval(c1.pos.x + offset.x, c1.pos.y + offset.y, c1.pos.z + offset.z, tempMap)
            }
        }

        pos := chunk.pos
        top, empty, _ := util.map_force_get(&tops, iVec2{pos.x, pos.z})
        if empty {
            top^ = pos
        } else if top.y < pos.y {
            top.y = pos.y
        }
    }

    populate(&chunksToSide, tempMap)

    Cache :: struct{
        chunk: ^Chunk,
        buffer: [16][16][16][2]u8,
        solid: [16][16][16]bool,
    }

    toIluminate := [dynamic]Cache{}
    defer delete(toIluminate)
    sunLighetHistory := make(map[iVec2]bool)
    defer delete(sunLighetHistory)

    t := time.tick_now()
    for &chunk in chunksToSide {
        if sunLighetHistory[{chunk.pos.x, chunk.pos.z}] do continue
        init := i32(0)
        top := chunk
        for {
            top = top.sides[.Up]
            if top == nil do break
            init += 1
        }
        sunLighetHistory[{chunk.pos.x, chunk.pos.z}] = true
        for {
            chunk2 := tempMap[chunk.pos + {0, init, 0}]
            if chunk2 == nil do break
            init -= 1
            buffer, solidCache := sunlight(chunk2, tempMap)
            if hasAllSides(chunk2) do append(&toIluminate, Cache{chunk2, buffer, solidCache})
        }
    }

    for &cache in toIluminate {
        cache.buffer = iluminate(cache.chunk, cache.buffer, cache.solid)
    }

    for &cache in toIluminate {
        iluminate(cache.chunk, cache.buffer, cache.solid)
    }
    skeewb.console_log(.INFO, "%d", i32(time.duration_milliseconds(time.tick_since(t))))

    return chunksToView
}

nuke :: proc() {
    delete(chunkMap)
    delete(allChunks)
}
