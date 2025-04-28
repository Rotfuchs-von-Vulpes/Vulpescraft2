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
Primer :: [18][18][18]blockState

LightData :: struct {
    light: bool,
    solid: bool,
    sky: bool,
    fused: bool,
}
LightPrimer :: [3 * 16][3 * 16][3 * 16]LightData
Chunk :: struct {
    pos: iVec3,
    primer: Primer,
    lightData: LightPrimer,
    opened: FaceSet,
    level: GeneratePhase,
    isEmpty: bool,
    isFill: bool,
    remeshing: bool,
}

Direction :: enum {Up, Bottom, North, South, East, West}
FaceSet :: bit_set[Direction]

GeneratePhase :: enum {Empty, Blocks, Trees, InternalLight, SidesClone, ExternalLight, Final}

allChunks := make(map[iVec3]^Chunk)

getNewChunk :: proc(chunk: ^Chunk, pos: iVec3) {
    chunk.level = .Empty
    chunk.opened = {}
    chunk.pos = pos
    chunk.isEmpty = true
    chunk.isFill = false
    chunk.remeshing = false
}

seeSides :: proc(chunk: ^Chunk) {
    chunk.opened = {}
    for i in 0..<16 do for j in 0..<16 {
        if chunk.primer[i + 1][j + 1][ 1].id == 0 do chunk.opened += {.South}
        if chunk.primer[i + 1][j + 1][16].id == 0 do chunk.opened += {.North}
        if chunk.primer[i + 1][ 1][j + 1].id == 0 do chunk.opened += {.Bottom}
        if chunk.primer[i + 1][16][j + 1].id == 0 do chunk.opened += {.Up}
        if chunk.primer[ 1][i + 1][j + 1].id == 0 do chunk.opened += {.West}
        if chunk.primer[16][i + 1][j + 1].id == 0 do chunk.opened += {.East}
    }
}

isFilled :: proc(chunk: ^Chunk) {
    for i in 0..<18 do for j in 0..<18 do for k in 0..<18 {
        id := chunk.primer[i][j][k].id
        if isPLaceable(id) {
            chunk.isFill = false
            return 
        }
    }

    chunk.isFill = true
}

setBlocksChunk :: proc(chunk: ^Chunk, heightMap: terrain.HeightMap) {
    empty := true
    for i in 0..<16 {
        for j in 0..<16 {
            height := int(heightMap[i][j])
            localHeight := height - int(chunk.pos.y) * 16
            topHeight := min(height, 15)
            for k in 0..<16 {
                chunk.primer[i + 1][k + 1][j + 1].light = {0, 0}
                if localHeight - k > 0 {
                    empty = false
                    if height > 15 {
                        if localHeight - k > 4 {
                            chunk.primer[i + 1][k + 1][j + 1].id = 1
                        } else if localHeight - k > 1 {
                            chunk.primer[i + 1][k + 1][j + 1].id = 2
                        } else {
                            chunk.primer[i + 1][k + 1][j + 1].id = 3
                        }
                    } else {
                        if localHeight - k > 3 {
                            chunk.primer[i + 1][k + 1][j + 1].id = 1
                        } else {
                            chunk.primer[i + 1][k + 1][j + 1].id = 4
                        }
                    }
                } else if chunk.pos.y <= 0 && k < 15 {
                    empty = false
                    chunk.primer[i + 1][k + 1][j + 1].id = 8
                } else {
                    break
                }
            }
        }
    }

    chunk.isEmpty = empty
    chunk.level = .Blocks
    seeSides(chunk)
}

eval :: proc(pos: iVec3, tempMap: ^map[iVec3]^Chunk) -> ^Chunk {
    chunk, empty, _ := util.map_force_get(tempMap, pos)
    if empty {
        chunk^ = new(Chunk)
        getNewChunk(chunk^, pos)
        setBlocksChunk(chunk^, terrain.getHeightMap(pos.x, pos.z))
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

calcSides :: proc(chunks: [3][3][3]^Chunk) {
    chunk := chunks[1][1][1]

    for i in -1..=1 do for j in -1..=1 do for k in -1..=1 {
        c := chunks[i + 1][j + 1][k + 1]

        if i != 0 || j != 0 || k != 0 do for x in 0..<16 {
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
                        chunk.primer[x1][y1][z1] = c.primer[x + 1][y + 1][z + 1]
                    } else do continue
                }
            }
        }

        for x in 0..<16 do for z in 0..<16 {
            foundGround := false
            for y := 15; y > 0; y -= 1 {
                final := LightData{false, false, false, false}
                id: u16
                if c != nil {
                    id = c.primer[x + 1][y + 1][z + 1].id
                } else do continue

                if id == 0 && !foundGround {
                    final.sky = true
                } else {
                    foundGround = true
                }

                if id != 0 {
                    final.solid = true
                    if id == 9 do final.light = true
                    if id == 7 || id == 8 do final.fused = true
                }

                chunk.lightData[(i + 1) * 16 + x][(j + 1) * 16 + y][(k + 1) * 16 + z] = final
            }
        }
    }
}

genPoll :: proc(chunk: ^Chunk) {
    // chunk := eval(pos.x, pos.y, pos.z, tempMap)
    chunks: [3][3][3]^Chunk
    if chunk.level == .Empty {
        for i in -1..=1 {
            for j in -1..=1 {
                for k in -1..=1 {
                    c: ^Chunk
                    if i == 0 && j == 0 && k == 0 {
                        c = chunk
                        setBlocksChunk(c, terrain.getHeightMap(chunk.pos.x, chunk.pos.z))
                    } else {
                        c = new(Chunk)
                        getNewChunk(c, chunk.pos + {i32(i), i32(j), i32(k)})
                        setBlocksChunk(c, terrain.getHeightMap(chunk.pos.x + i32(i), chunk.pos.z + i32(k)))
                    }
                    chunks[i + 1][j + 1][k + 1] = c
                }
            }
        }
        populate(chunks)
        calcSides(chunks)
        isFilled(chunk)
        chunk.level = .Trees
    }
}

addLights :: proc (chunk: ^Chunk) {
    // chunk := chunks[1][1][1]
    // calcSides(chunks)
    applyLight(chunk)
    chunk.level = .Final
}

nuke :: proc() {
    for _, &chunk in allChunks do free(chunk)
    delete(allChunks)
}
