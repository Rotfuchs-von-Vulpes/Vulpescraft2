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

Direction :: enum {Up, Bottom, North, South, East, West}
FaceSet :: bit_set[Direction]


GeneratePhase :: enum {Empty, Blocks, Trees, InternalLight, ExternalTrees, ExternalLight}
Chunk :: struct {
    pos: iVec3,
    primer: Primer,
    opened: FaceSet,
    level: GeneratePhase,
    isEmpty: bool,
}

allChunks := make(map[iVec3]^Chunk)

getNewChunk :: proc(chunk: ^Chunk, x, y, z: i32) {
    empty: blockState = {
        id = 0,
        light = {0, 0},
    }

    chunk.level = .Empty
    chunk.opened = {}
    chunk.pos = {x, y, z}
    chunk.isEmpty = true
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

VIEW_DISTANCE :: 7

sqDist :: proc(pos1, pos2: iVec3, dist: int) -> bool {
    diff := pos1 - pos2
    return diff.x * diff.x + diff.y * diff.y + diff.z * diff.z < i32(dist * dist)
}

history := make(map[iVec3]bool)
genStack := [dynamic]iVec3{}

calcSides :: proc(chunk: ^Chunk, tempMap: ^map[iVec3]^Chunk) {
    if chunk.level != .ExternalTrees do return
    for i in -1..=1 {
        for j in -1..=1 {
            for k in -1..=1 {
                c := eval(chunk.pos.x + i32(i), chunk.pos.y + i32(j), chunk.pos.z + i32(k), tempMap)

                if i == 0 && j == 0 && k == 0 do continue
                for x in 0..<16 {
                    if i == 1 && x != 0 do continue
                    if i == -1 && x != 15 do continue
                    for y in 0..<16 {
                        if j == 1 && y != 0 do continue
                        if j == -1 && y != 15 do continue
                        for z in 0..<16 {
                            if k == 1 && z != 0 do continue
                            if k == -1 && z != 15 do continue
                            xx := i != 0 ? i < 0 ? 0 : 17 : x + 1
                            yy := j != 0 ? j < 0 ? 0 : 17 : y + 1
                            zz := k != 0 ? k < 0 ? 0 : 17 : z + 1
                            chunk.primer[xx][yy][zz] = c.primer[x + 1][y + 1][z + 1]
                        }
                    }
                }
            }
        }
    }
}

genPoll :: proc(center, pos: iVec3, tempMap: ^map[iVec3]^Chunk) -> (^Chunk, bool) {
    if history[pos] do return nil, true
    chunk := eval(pos.x, pos.y, pos.z, tempMap)
    if chunk.level != .ExternalLight {
        for i in -2..=2 {
            for j in -2..=2 {
                for k in -2..=2 {
                    c := eval(pos.x + i32(i), pos.y + i32(j), pos.z + i32(k), tempMap)
                    populate(c, tempMap)
                }
            }
        }
        for i in -1..=1 {
            for j in -1..=1 {
                for k in -1..=1 {
                    c := eval(pos.x + i32(i), pos.y + i32(j), pos.z + i32(k), tempMap)
                    sunlight(c)
                }
            }
        }
        chunk.level = .ExternalTrees
        calcSides(chunk, tempMap)
        iluminate(chunk)
    }

    if .West in chunk.opened && sqDist(pos + {-1, 0, 0}, center, VIEW_DISTANCE) && pos + {-1, 0, 0} not_in history {
        append(&genStack, iVec3{pos.x - 1, pos.y, pos.z})
    }
    if .East in chunk.opened && sqDist(pos + {1, 0, 0}, center, VIEW_DISTANCE) && pos + {1, 0, 0} not_in history {
        append(&genStack, iVec3{pos.x + 1, pos.y, pos.z})
    }
    if .Bottom in chunk.opened && sqDist(pos + {0,-1, 0}, center, VIEW_DISTANCE) && pos + {0,-1, 0} not_in history {
        append(&genStack, iVec3{pos.x, pos.y - 1, pos.z})
    }
    if .Up in chunk.opened && sqDist(pos + {0, 1, 0}, center, VIEW_DISTANCE) && pos + {0, 1, 0} not_in history {
        append(&genStack, iVec3{pos.x, pos.y + 1, pos.z})
    }
    if .South in chunk.opened && sqDist(pos + {0, 0,-1}, center, VIEW_DISTANCE) && pos + {0, 0,-1} not_in history {
        append(&genStack, iVec3{pos.x, pos.y, pos.z - 1})
    }
    if .North in chunk.opened && sqDist(pos + {0, 0, 1}, center, VIEW_DISTANCE) && pos + {0, 0, 1} not_in history {
        append(&genStack, iVec3{pos.x, pos.y, pos.z + 1})
    }

    return chunk, true
}

nuke :: proc() {
    delete(allChunks)
}
