package world

import math "core:math/linalg"
import "core:fmt"
import "core:sync"

getPosition :: proc(pos: iVec3) -> (^Chunk, iVec3) {
    chunkPos := iVec3{
        i32(math.floor(f32(pos.x) / 16)),
        i32(math.floor(f32(pos.y) / 16)),
        i32(math.floor(f32(pos.z) / 16)),
    }

    chunk := eval(chunkPos, &allChunks)

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

signalum :: proc(vec: iVec3) -> iVec3 {
    res := iVec3{0, 0, 0}
    for axis, idx in vec {
        if axis > 0 do res[idx] = 1
        if axis < 0 do res[idx] = -1
    }
    return res
}

isPLaceable :: proc(id: u16) -> bool {
    return id == 0 || id == 8
}

raycast :: proc(origin, direction: vec3, place: bool) -> (^Chunk, iVec3, bool) {
    step: f32 = 0.05
    maxLength: f32 = 10

    lastBlockSet := false
    lastBlock, pos, sidePos: iVec3

    length: f32 = 0
    for length <= maxLength {
        fPos := origin + direction * length
        iPos := toiVec3(fPos)

        if lastBlockSet && (iPos.x == lastBlock.x && iPos.y == lastBlock.y && iPos.z == lastBlock.z) {
            length += step
            continue
        }

        chunk, blockPos := getPosition(iPos)
        blockID := chunk.blocks[blockPos.x][blockPos.y][blockPos.z]
        if !isPLaceable(blockID) {
            pos = blockPos
            offset: iVec3 = {0, 0, 0}
            canPlaceAtSide := false
            if lastBlockSet {
                offset = signalum(lastBlock - iPos)

                if math.abs(offset.x) + math.abs(offset.y) + math.abs(offset.z) != 1 {
                    findBestAxis: {
                        if offset.x != 0 {
                            chunk2, posB := getPosition({iPos.x + offset.x, iPos.y, iPos.z})
                            b := chunk2.blocks[posB.x][posB.y][posB.z]
                            if isPLaceable(b) {
                                if place do chunk = chunk2
                                if place do pos = posB
                                offset.y = 0
                                offset.z = 0
                                canPlaceAtSide = true
                                break findBestAxis
                            }
                        }
                        if offset.y != 0 {
                            chunk2, posB := getPosition({iPos.x, iPos.y + offset.y, iPos.z})
                            b := chunk2.blocks[posB.x][posB.y][posB.z]
                            if isPLaceable(b) {
                                if place do chunk = chunk2
                                if place do pos = posB
                                offset.x = 0
                                offset.z = 0
                                canPlaceAtSide = true
                                break findBestAxis
                            }
                        }
                        if offset.x != 0 {
                            chunk2, posB := getPosition({iPos.x, iPos.y, iPos.z + offset.z})
                            b := chunk2.blocks[posB.x][posB.y][posB.z]
                            if isPLaceable(b) {
                                if place do chunk = chunk2
                                if place do pos = posB
                                offset.x = 0
                                offset.y = 0
                                canPlaceAtSide = true
                                break findBestAxis
                            }
                        }
                        offset = {0, 0, 0}
                    }
                }
            }

            if !canPlaceAtSide {
                chunk2, posB := getPosition(iPos + offset)
                b := chunk2.blocks[posB.x][posB.y][posB.z]
                canPlaceAtSide = isPLaceable(b)
                if place do chunk = chunk2
                if place do pos = posB
            }

            return chunk, pos, true
        }
        lastBlock = iPos
        lastBlockSet = true
        length += step
    }

    return nil, pos, false
}

atualizeChunks :: proc(chunk: ^Chunk, pos: iVec3, id: u16, lock: ^sync.RW_Mutex) -> [dynamic]^ChunkPrimer {
    chunks: [dynamic]^ChunkPrimer = {}

    // chunk.blocks[pos.x][pos.y][pos.z] = id
    cs: [3][3][3]^ChunkPrimer
    for i in -1..=1 do for j in -1..=1 do for k in -1..=1 {
        c := evalPrimer(chunk.pos + {i32(i), i32(j), i32(k)}, lock)
        cs[i + 1][j + 1][k + 1] = c
        append(&chunks, c)
    }
    chunk.blocks[pos.x][pos.y][pos.z] = id
    setBlockChunks(cs, pos, id)

    return chunks
}

destroy :: proc(origin, direction: vec3, lock: ^sync.RW_Mutex) -> ([dynamic]^ChunkPrimer, bool) {
    chunks: [dynamic]^ChunkPrimer
    chunk, pos, ok := raycast(origin, direction, false)

    if !ok {return {}, false}
    // chunk.primer[pos.x + 1][pos.y + 1][pos.z + 1].id = 0
    // chunk.isFill = false

    chunks = atualizeChunks(chunk, pos, 0, lock)

    return chunks, true
}

place :: proc(origin, direction: vec3, block: u16, lock: ^sync.RW_Mutex) -> ([dynamic]^ChunkPrimer, bool) {
    chunks: [dynamic]^ChunkPrimer
    chunk, pos, ok := raycast(origin, direction, true)

    if !ok {return {}, false}
    // chunk.primer[pos.x + 1][pos.y + 1][pos.z + 1].id = block
    // chunk.isEmpty = false
    
    chunks = atualizeChunks(chunk, pos, block, lock)

    return chunks, true
}