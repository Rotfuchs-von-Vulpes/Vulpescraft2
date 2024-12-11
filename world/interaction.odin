package world

import math "core:math/linalg"

getPosition :: proc(pos: iVec3) -> (^Chunk, iVec3) {
    chunkPos := iVec3{
        i32(math.floor(f32(pos.x) / 16)),
        i32(math.floor(f32(pos.y) / 16)),
        i32(math.floor(f32(pos.z) / 16)),
    }

    chunk := eval(chunkPos.x, chunkPos.y, chunkPos.z, &allChunks)

    iPos: iVec3
    iPos.x = i32(math.floor(16 * math.fract(f32(pos.x) / 16)))
    iPos.y = i32(math.floor(16 * math.fract(f32(pos.y) / 16)))
    iPos.z = i32(math.floor(16 * math.fract(f32(pos.z) / 16)))

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
            if ok && chunk.primer[pos.x + 1][pos.y + 1][pos.z + 1].id != 0 {
                if place {
                    offset := iPos - lastBlock
                    if abs(offset.x) + abs(offset.y) + abs(offset.z) != 1 {
                        if offset.x != 0 {
                            chunk, pos = getPosition({iPos.x + offset.x, iPos.y, iPos.z})
                            if ok && chunk.primer[pos.x + 1][pos.y + 1][pos.z + 1].id != 0 {
                                return chunk, pos, true
                            }
                        }
                        if offset.y != 0 {
                            chunk, pos = getPosition({iPos.x, iPos.y + offset.y, iPos.z})
                            if ok && chunk.primer[pos.x + 1][pos.y + 1][pos.z + 1].id != 0 {
                                return chunk, pos, true
                            }
                        }
                        if offset.z != 0 {
                            chunk, pos = getPosition({iPos.x, iPos.y, iPos.z + offset.z})
                            if ok && chunk.primer[pos.x + 1][pos.y + 1][pos.z + 1].id != 0 {
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

    for i in -1..=1 {
        for j in -1..=1 {
            for k in -1..=1 {
                c := eval(chunk.pos.x + i32(i), chunk.pos.y + i32(j), chunk.pos.z + i32(k), &allChunks)
                c.level = .Trees
                append(&chunks, c)
            }
        }
    }

    for &chunk in chunks {
        chunk.remeshing = true
    }

    return chunks
}

destroy :: proc(origin, direction: vec3) -> ([dynamic]^Chunk, iVec3, bool) {
    chunks: [dynamic]^Chunk
    chunk, pos, ok := raycast(origin, direction, false)

    if !ok {return chunks, pos, false}
    chunk.primer[pos.x + 1][pos.y + 1][pos.z + 1].id = 0
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
    chunk.primer[pos.x + 1][pos.y + 1][pos.z + 1].id = 5
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