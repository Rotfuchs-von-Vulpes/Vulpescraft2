package world

import "../skeewb"
import "core:math"
import "core:math/rand"
import "core:time"
import "core:fmt"
import "core:mem/virtual"
import "core:sync"
import "../util"
import "terrain"

iVec2 :: [2]i32
iVec3 :: [3]i32
vec3 :: [3]f32

BlocksPrimer :: [18][18][18]u16
blockState :: struct {
    id: u16,
    light: [2]u8,
}
Primer ::  [18][18][18]blockState

LightData :: struct {
    light: bool,
    solid: bool,
    sky: bool,
    fused: bool,
}
LightPrimer :: [3 * 16][3 * 16][3 * 16]LightData

// Chunk :: struct {
//     pos: iVec3,
//     primer: Primer,
//     lightData: LightPrimer,
//     opened: FaceSet,
//     level: GeneratePhase,
//     isEmpty: bool,
//     isFill: bool,
//     remeshing: bool,
// }

Chunk :: struct {
    pos: iVec3,
    blocks: [16][16][16]u16,
}

ChunkPrimer :: struct {
    pos: iVec3,
    primer: BlocksPrimer,
    light: [3 * 16][3 * 16][3 * 16]LightData,
}

ChunkData :: struct {
    pos: iVec3,
    primer: Primer,
}

Direction :: enum {Up, Bottom, North, South, East, West}
FaceSet :: bit_set[Direction]

GeneratePhase :: enum {Empty, Blocks, Trees, InternalLight, SidesClone, ExternalLight, Final}

allChunks := make(map[iVec3]^Chunk)
allChunksPrimers := make(map[iVec3]^ChunkPrimer)

// getNewChunk :: proc(chunk: ^Chunk, pos: iVec3) {
//     chunk.level = .Empty
//     chunk.opened = {}
//     chunk.pos = pos
//     chunk.isEmpty = true
//     chunk.isFill = false
//     chunk.remeshing = false
// }

// seeSides :: proc(chunk: ^Chunk) {
//     chunk.opened = {}
//     for i in 0..<16 do for j in 0..<16 {
//         if chunk.primer[i + 1][j + 1][ 1].id == 0 do chunk.opened += {.South}
//         if chunk.primer[i + 1][j + 1][16].id == 0 do chunk.opened += {.North}
//         if chunk.primer[i + 1][ 1][j + 1].id == 0 do chunk.opened += {.Bottom}
//         if chunk.primer[i + 1][16][j + 1].id == 0 do chunk.opened += {.Up}
//         if chunk.primer[ 1][i + 1][j + 1].id == 0 do chunk.opened += {.West}
//         if chunk.primer[16][i + 1][j + 1].id == 0 do chunk.opened += {.East}
//     }
// }

// isFilled :: proc(chunk: ^Chunk) {
//     for i in 0..<18 do for j in 0..<18 do for k in 0..<18 {
//         id := chunk.primer[i][j][k].id
//         if isPLaceable(id) {
//             chunk.isFill = false
//             return 
//         }
//     }

//     chunk.isFill = true
// }

setBlocksChunk :: proc(chunk: ^Chunk, heightMap: terrain.HeightMap) {
    empty := true
    for i in 0..<16 {
        for j in 0..<16 {
            height := int(heightMap[i][j])
            localHeight := height - int(chunk.pos.y) * 16
            topHeight := min(height, 15)
            for k in 0..<16 {
                if localHeight - k > 0 {
                    empty = false
                    if height > 15 {
                        if localHeight - k > 4 {
                            chunk.blocks[i][k][j] = 1
                        } else if localHeight - k > 1 {
                            chunk.blocks[i][k][j] = 2
                        } else {
                            chunk.blocks[i][k][j] = 3
                        }
                    } else {
                        if localHeight - k > 3 {
                            chunk.blocks[i][k][j] = 1
                        } else {
                            chunk.blocks[i][k][j] = 4
                        }
                    }
                } else if chunk.pos.y <= 0 && k < 15 {
                    empty = false
                    chunk.blocks[i][k][j] = 8
                } else {
                    break
                }
            }
        }
    }

    // chunk.isEmpty = empty
    // chunk.level = .Blocks
    // seeSides(chunk)
}

eval :: proc(pos: iVec3, tempMap: ^map[iVec3]^Chunk) -> ^Chunk {
    chunk, empty, _ := util.map_force_get(tempMap, pos)
    if empty {
        chunk^ = new(Chunk)
        chunk^.pos = pos
        setBlocksChunk(chunk^, terrain.getHeightMap(pos.x, pos.z))
    }
    return chunk^
}

evalPrimer :: proc (pos: iVec3, lock: ^sync.RW_Mutex) -> ^ChunkPrimer {
    chunk, empty, _ := util.map_force_get(&allChunksPrimers, pos)
    if empty {
        chunk^ = new(ChunkPrimer)
        cs: [3][3][3]^Chunk
        for i in -1..=1 do for j in -1..=1 do for k in -1..=1 {
            cs[i + 1][j + 1][k + 1] = allChunks[pos + {i32(i), i32(j), i32(k)}]
        }
        chunk ^= calcSides(cs, lock)
    }
    return chunk^
}

length :: proc(v: iVec3) -> i32 {
    return i32((v.x * v.x + v.y * v.y + v.z * v.z))
}

VIEW_DISTANCE :: 7

sqDist :: proc(pos1, pos2: iVec3, dist: int) -> bool {
    diff := pos1 - pos2
    return diff.x * diff.x + diff.y * diff.y + diff.z * diff.z < i32(dist * dist)
}

history := make(map[iVec3]bool)
genStack := [dynamic]iVec3{}

setBlock :: proc (chunk: ^ChunkPrimer, idx: iVec3, id: u16) {
    chunk.primer[idx.x][idx.y][idx.z] = id
}

setBlockChunks :: proc (chunks: [3][3][3]^ChunkPrimer, pos: iVec3, id: u16) {
    setBlock(chunks[1][1][1], pos + {1, 1, 1}, id)

    dx: i32 = 0
    dy: i32 = 0
    dz: i32 = 0
    if pos.x == 15 do dx = 1
    if pos.x == 0  do dx = -1
    if pos.y == 15 do dy = 1
    if pos.y == 0  do dy = -1
    if pos.z == 15 do dz = 1
    if pos.z == 0  do dz = -1

    if dx != 0 {
        setBlock(chunks[dx + 1][1][1], {dx > 0 ? 0 : 17, pos.y + 1, pos.z + 1}, id)
    }
    if dy != 0 {
        setBlock(chunks[1][dy + 1][1], {pos.x + 1, dy > 0 ? 0 : 17, pos.z + 1}, id)
    }
    if dz != 0 {
        setBlock(chunks[1][1][dz + 1], {pos.x + 1, pos.y + 1, dz > 0 ? 0 : 17}, id)
    }
    if dx != 0 && dy != 0 {
        setBlock(chunks[dx + 1][dy + 1][1], {dx > 0 ? 0 : 17, dy > 0 ? 0 : 17, pos.z + 1}, id)
    }
    if dx != 0 && dz != 0 {
        setBlock(chunks[dx + 1][1][dz + 1], {dx > 0 ? 0 : 17, pos.y + 1, dy > 0 ? 0 : 17}, id)
    }
    if dy != 0 && dz != 0 {
        setBlock(chunks[1][dy + 1][dz + 1], {pos.x + 1, dy > 0 ? 0 : 17, dy > 0 ? 0 : 17}, id)
    }
    if dx != 0 && dy != 0 && dz != 0 {
        setBlock(chunks[dx + 1][dy + 1][dz + 1], {dx > 0 ? 0 : 17, dy > 0 ? 0 : 17, dz > 0 ? 0 : 17}, id)
    }

    final := LightData{false, false, false, false} 

    if id == 7 || id == 8 do final.fused = true
    if id != 0 && !final.fused do final.solid = true
    if id == 9 do final.light = true

    if pos.y < 16 {
        final.sky = chunks[1][1][1].light[pos.x + 16][pos.y + 17][pos.z + 16].sky
    }

    for i in -1..=1 do for j in -1..=1 do for k in -1..=1 {
        c := chunks[i + 1][j + 1][k + 1]

        c.light[i32(1 - i) * 16 + pos.x][i32(1 - j) * 16 + pos.y][i32(1 - k) * 16 + pos.z] = final
    }
}

calcSides :: proc(chunks: [3][3][3]^Chunk, lock: ^sync.RW_Mutex) -> ^ChunkPrimer {
    chunk := chunks[1][1][1]
    resp := new(ChunkPrimer)
    resp.pos = chunk.pos

    for i in -1..=1 do for j in -1..=1 do for k in -1..=1 {
        c := chunks[i + 1][j + 1][k + 1]

        if i != 0 || j != 0 || k != 0 {
            for x in 0..<16 {
                if i == 1 && x != 0 do continue
                if i == -1 && x != 15 do continue
                for y in 0..<16 {
                    if j == 1 && y != 0 do continue
                    if j == -1 && y != 15 do continue
                    for z in 0..<16 {
                        if k == 1 && z != 0 do continue
                        if k == -1 && z != 15 do continue
                        x1 := i != 0 ? i < 0 ? 0 : 17 : x + 1
                        y1 := j != 0 ? j < 0 ? 0 : 17 : y + 1
                        z1 := k != 0 ? k < 0 ? 0 : 17 : z + 1
                        x2 := i != 0 ? i < 0 ? 17 : 0 : x + 1
                        y2 := j != 0 ? j < 0 ? 17 : 0 : y + 1
                        z2 := k != 0 ? k < 0 ? 17 : 0 : z + 1
                        if c != nil {
                            resp.primer[x1][y1][z1] = c.blocks[x][y][z]
                        } else do continue
                    }
                }
            }
        } else {
            for x in 0..<16 do for y in 0..<16 do for z in 0..<16 {
                resp.primer[x + 1][y + 1][z + 1] = c.blocks[x][y][z]
            }
        }

        for x in 0..<16 do for z in 0..<16 {
            foundGround := false
            for y := 15; y > 0; y -= 1 {
                final := LightData{false, false, false, false}
                id: u16
                if c != nil {
                    id = c.blocks[x][y][z]
                } else do continue

                if id == 0 && !foundGround {
                    final.sky = true
                } else {
                    foundGround = true
                }

                if id != 0 {
                    if id == 9 do final.light = true
                    if id == 7 || id == 8 do final.fused = true
                    if !final.fused do final.solid = true
                }

                resp.light[(i + 1) * 16 + x][(j + 1) * 16 + y][(k + 1) * 16 + z] = final
            }
        }
    }

    sync.lock(lock)
    allChunksPrimers[resp.pos] = resp
    sync.unlock(lock)

    return resp
}

genPoll :: proc(chunk: ^Chunk, lock: ^sync.RW_Mutex) -> ^ChunkPrimer {
    // chunk := eval(pos.x, pos.y, pos.z, tempMap)
    chunks: [3][3][3]^Chunk
    // if chunk.level == .Empty {
        for i in -1..=1 {
            for j in -1..=1 {
                for k in -1..=1 {
                    c: ^Chunk
                    if i == 0 && j == 0 && k == 0 {
                        c = chunk
                    } else {
                        c = new(Chunk)
                    }
                    c.pos = chunk.pos + {i32(i), i32(j), i32(k)}
                    setBlocksChunk(c, terrain.getHeightMap(chunk.pos.x + i32(i), chunk.pos.z + i32(k)))
                    chunks[i + 1][j + 1][k + 1] = c
                }
            }
        }
        populate(chunks)
        data := calcSides(chunks, lock)
        sync.lock(lock)
        allChunksPrimers[chunk.pos] = data
        sync.unlock(lock)

        for i in -1..=1 do for j in -1..=1 do for k in -1..=1 {
            if i != 0 || j != 0 || k != 0 do free(chunks[i + 1][j + 1][k + 1])
        }
        // isFilled(chunk)
        // chunk.level = .Trees
    // }

    return data
}

nuke :: proc() {
    //for _, &chunk in allChunks do free(chunk)
    for _, primer in allChunksPrimers do free(primer)
    delete(allChunksPrimers)
    delete(allChunks)
}
