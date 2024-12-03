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


GeneratePhase :: enum {Empty, Blocks, Trees, InternalLight, ExternalTrees, ExternalLight}
Chunk :: struct {
    pos: iVec3,
    sides: [Direction]^Chunk,
    primer: Primer,
    opened: FaceSet,
    level: GeneratePhase,
    isEmpty: bool,
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

    chunk.level = .Empty
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
                    empty = false
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
                } else if chunk.pos.y <= 0 && k < 15 {
                    empty = false
                    chunk.primer[i][k][j].id = 8
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

sqDist :: proc(pos1, pos2: iVec3, dist: int) -> bool {
    diff := pos1 - pos2
    return diff.x * diff.x + diff.y * diff.y + diff.z * diff.z < i32(dist * dist)
}

prevCenter: iVec3
history := make(map[iVec3]bool)
genStack := [dynamic]iVec3{}

posOffsets: [Direction]iVec3 = {
    .West   = {-1, 0, 0},
    .East   = {1, 0, 0},
    .Bottom = {0, -1, 0},
    .Up     = {0, 1, 0},
    .South  = {0, 0, -1},
    .North  = {0, 0, 1},
}
opposite: [Direction]Direction = {
    .West   = .East,
    .East   = .West,
    .Bottom = .Up,
    .Up     = .Bottom,
    .South  = .North,
    .North  = .South,
}

idx := 0

genPoll :: proc(center, pos: iVec3, tempMap: ^map[iVec3]^Chunk) -> (^Chunk, bool) {
    history[pos] = true
    prevCenter = center
    chunk := eval(pos.x, pos.y, pos.z, tempMap)
    count := 0
    if chunk.level != .ExternalLight {
        for i in -1..=1 {
            loop: for k in -1..=1 {
                j := -1
                c: ^Chunk
                for {
                    c = eval(pos.x + i32(i), pos.y + i32(j), pos.z + i32(k), tempMap)
                    if c.level == .ExternalLight do continue loop
                    for &cSide, dir in c.sides {
                        offset := posOffsets[dir]
                        cSide = eval(c.pos.x + offset.x, c.pos.y + offset.y, c.pos.z + offset.z, tempMap)
                    }
                    populate(c, tempMap)
                    if c.isEmpty && j > 1 do break
                    j += 1
                    // sunlight(c)
                    // sunlight(c, tempMap)
                    //c.isEmpty = false
                }
                for {
                    c = eval(pos.x + i32(i), pos.y + i32(j), pos.z + i32(k), tempMap)
                    sunlight(c)
                    j -= 1
                    if .Bottom not_in c.opened do break
                }
            }
        }
        chunk.level = .ExternalTrees
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
    delete(chunkMap)
    delete(allChunks)
}
