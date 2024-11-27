package world

getPosition :: proc(pos: iVec3) -> (^Chunk, iVec3) {
    chunkPos := iVec3{
        (pos.x + 16) / 16 - 1,
        (pos.y + 16) / 16 - 1,
        (pos.z + 16) / 16 - 1
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
        i32(vec.x),
        i32(vec.y),
        i32(vec.z),
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
                    if abs(offset.x) + abs(offset.y) + abs(offset.z) != 1 {
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

    chunk := eval(chunk.pos.x, chunk.pos.y, chunk.pos.z, &allChunks)
    chunk.level = 2
    append(&chunks, chunk)

    if pos.x == 0 {
        chunk := eval(chunk.pos.x - 1, chunk.pos.y, chunk.pos.z, &allChunks)
        chunk.level = 2
        append(&chunks, chunk)
    } else if pos.x == 15 {
        chunk := eval(chunk.pos.x + 1, chunk.pos.y, chunk.pos.z, &allChunks)
        chunk.level = 2
        append(&chunks, chunk)
    }
    if pos.y == 0 {
        chunk := eval(chunk.pos.x, chunk.pos.y - 1, chunk.pos.z, &allChunks)
        chunk.level = 2
        append(&chunks, chunk)
    } else if pos.y == 15 {
        chunk := eval(chunk.pos.x, chunk.pos.y + 1, chunk.pos.z, &allChunks)
        chunk.level = 2
        append(&chunks, chunk)
    }
    if pos.z == 0 {
        chunk := eval(chunk.pos.x, chunk.pos.y, chunk.pos.z - 1, &allChunks)
        chunk.level = 2
        append(&chunks, chunk)
    } else if pos.z == 15 {
        chunk := eval(chunk.pos.x, chunk.pos.y, chunk.pos.z + 1, &allChunks)
        chunk.level = 2
        append(&chunks, chunk)
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