package world

import "../skeewb"

Light :: struct{
    pos: iVec3,
    value: u8,
}

sunlight :: proc(chunk: ^Chunk, tempMap: ^map[iVec3]^Chunk) -> ([16][16][16][2]u8, [16][16][16]bool) {
    buffer: [16][16][16][2]u8
    cache: [16][16][16]u8
    solidCache: [16][16][16]bool
    if chunk.level != .Trees {
        for x in 0..<16 {
            for y in 0..<16 {
                for z in 0..<16 {
                    block := chunk.primer[x][y][z]
                    id := block.id
                    transparent := id == 7 || id == 8 || id == 9
                    solid := id != 0 && !transparent
                    
                    solidCache[x][y][z] = solid
                    buffer[x][y][z] = chunk.primer[x][y][z].light
                }
            }
        }

        return buffer, solidCache
    }
    sunlightCache := [dynamic]Light{}
    defer delete(sunlightCache)
    emissiveCache := [dynamic]Light{}
    defer delete(emissiveCache)

    topChunk := chunk.sides[.Up]

    for x in 0..<16 {
        for z in 0..<16 {
            foundGround := false
            for y := 15; y >= 0; y -= 1 {
                block := chunk.primer[x][y][z]
                id := block.id
                transparent := id == 7 || id == 8 || id == 9
                solid := id != 0 && !transparent
                
                solidCache[x][y][z] = solid

                if id != 0 {
                    foundGround = true
                }

                if id == 9 {
                    append(&emissiveCache, Light{iVec3{i32(x), i32(y), i32(z)}, 15})
                }

                top := u8(15)
                if y == 15 {
                    if topChunk != nil {
                        top = topChunk.primer[x][0][z].light.y
                    }
                } else {
                    top = cache[x][y + 1][z]
                }

                if !foundGround {
                    cache[x][y][z] = top
                    append(&sunlightCache, Light{iVec3{i32(x), i32(y), i32(z)}, top})
                }
            }
        }
    }
    
    for &light in sunlightCache {
        pos := light.pos
        if solidCache[pos.x][pos.y][pos.z] do continue
        if buffer[pos.x][pos.y][pos.z].y >= light.value do continue
    
        x := pos.x
        y := pos.y
        z := pos.z
    
        buffer[x][y][z].y = light.value
        if light.value <= 1 do continue
        if x !=  0 do append(&sunlightCache, Light{iVec3{x - 1, y, z}, light.value - 1})
        if x != 15 do append(&sunlightCache, Light{iVec3{x + 1, y, z}, light.value - 1})
        if y !=  0 do append(&sunlightCache, Light{iVec3{x, y - 1, z}, light.value - 1})
        if y != 15 do append(&sunlightCache, Light{iVec3{x, y + 1, z}, light.value - 1})
        if z !=  0 do append(&sunlightCache, Light{iVec3{x, y, z - 1}, light.value - 1})
        if z != 15 do append(&sunlightCache, Light{iVec3{x, y, z + 1}, light.value - 1})
    }
    
    for &light in emissiveCache {
        pos := light.pos
        if solidCache[pos.x][pos.y][pos.z] do continue
        if buffer[pos.x][pos.y][pos.z].x >= light.value do continue
    
        x := pos.x
        y := pos.y
        z := pos.z
    
        buffer[x][y][z].x = light.value
        if light.value <= 1 do continue
        if x !=  0 do append(&emissiveCache, Light{iVec3{x - 1, y, z}, light.value - 1})
        if x != 15 do append(&emissiveCache, Light{iVec3{x + 1, y, z}, light.value - 1})
        if y !=  0 do append(&emissiveCache, Light{iVec3{x, y - 1, z}, light.value - 1})
        if y != 15 do append(&emissiveCache, Light{iVec3{x, y + 1, z}, light.value - 1})
        if z !=  0 do append(&emissiveCache, Light{iVec3{x, y, z - 1}, light.value - 1})
        if z != 15 do append(&emissiveCache, Light{iVec3{x, y, z + 1}, light.value - 1})
    }

    for x in 0..<16 {
        for y in 0..<16 {
            for z in 0..<16 {
                chunk.primer[x][y][z].light = buffer[x][y][z]
            }
        }
    }

    chunk.level = .InternalLight

    return buffer, solidCache
}

iluminate :: proc(chunk: ^Chunk, buffer: [16][16][16][2]u8, solidCache: [16][16][16]bool) {
    buffer := buffer

    if chunk.level != .InternalLight do return

    chunks: [3][3][3]^Chunk
    for i in -1..=1 {
        for j in -1..=1 {
            for k in -1..=1 {
                c := chunk
                if i < 0 {
                    c = c.sides[.West]
                } else if i > 0 {
                    c = c.sides[.East]
                }
                if j < 0 {
                    c = c.sides[.Bottom]
                } else if j > 0 {
                    c = c.sides[.Up]
                }
                if k < 0 {
                    c = c.sides[.South]
                } else if k > 0 {
                    c = c.sides[.North]
                }
                chunks[i + 1][j + 1][k + 1] = c
            }
        }
    }

    emissiveCache := [dynamic]Light{}
    defer delete(emissiveCache)
    sunlightCache := [dynamic]Light{}
    defer delete(sunlightCache)
    
    for i in -1..=1 {
        for j in -1..=1 {
            for k in -1..=1 {
                c := chunks[i + 1][j + 1][k + 1]

                count: u8 = 0

                if i != 0 do count += 1
                if j != 0 do count += 1
                if k != 0 do count += 1

                if count == 0 do continue
                for x in 0..<16 {
                    if i == 1 && x != 0 do continue
                    if i == -1 && x != 15 do continue
                    for y in 0..<16 {
                        if j == 1 && y != 0 do continue
                        if j == -1 && y != 15 do continue
                        for z in 0..<16 {
                            if k == 1 && z != 0 do continue
                            if k == -1 && z != 15 do continue
                            light := c.primer[x][y][z].light
                            xx, yy, zz: i32
                            xx = i != 0 ? 15 - i32(x) : i32(x)
                            yy = j != 0 ? 15 - i32(y) : i32(y)
                            zz = k != 0 ? 15 - i32(z) : i32(z)
                            if light.y > count do append(&sunlightCache, Light{{xx, yy, zz}, light.y - count})
                            if light.x > count do append(&emissiveCache, Light{{xx, yy, zz}, light.x - count})
                        }
                    }
                }
            }
        }
    }
    
    for &light in sunlightCache {
        pos := light.pos
        if solidCache[pos.x][pos.y][pos.z] do continue
        if buffer[pos.x][pos.y][pos.z].y >= light.value do continue
    
        x := pos.x
        y := pos.y
        z := pos.z
    
        buffer[x][y][z].y = light.value
        if light.value <= 1 do continue
        if x !=  0 do append(&sunlightCache, Light{iVec3{x - 1, y, z}, light.value - 1})
        if x != 15 do append(&sunlightCache, Light{iVec3{x + 1, y, z}, light.value - 1})
        if y !=  0 do append(&sunlightCache, Light{iVec3{x, y - 1, z}, light.value - 1})
        if y != 15 do append(&sunlightCache, Light{iVec3{x, y + 1, z}, light.value - 1})
        if z !=  0 do append(&sunlightCache, Light{iVec3{x, y, z - 1}, light.value - 1})
        if z != 15 do append(&sunlightCache, Light{iVec3{x, y, z + 1}, light.value - 1})
    }
    
    for &light in emissiveCache {
        pos := light.pos
        if solidCache[pos.x][pos.y][pos.z] do continue
        if buffer[pos.x][pos.y][pos.z].x >= light.value do continue
    
        x := pos.x
        y := pos.y
        z := pos.z
    
        buffer[x][y][z].x = light.value
        if light.value <= 1 do continue
        if x !=  0 do append(&emissiveCache, Light{iVec3{x - 1, y, z}, light.value - 1})
        if x != 15 do append(&emissiveCache, Light{iVec3{x + 1, y, z}, light.value - 1})
        if y !=  0 do append(&emissiveCache, Light{iVec3{x, y - 1, z}, light.value - 1})
        if y != 15 do append(&emissiveCache, Light{iVec3{x, y + 1, z}, light.value - 1})
        if z !=  0 do append(&emissiveCache, Light{iVec3{x, y, z - 1}, light.value - 1})
        if z != 15 do append(&emissiveCache, Light{iVec3{x, y, z + 1}, light.value - 1})
    }

    for x in 0..<16 {
        for y in 0..<16 {
            for z in 0..<16 {
                chunk.primer[x][y][z].light = buffer[x][y][z]
            }
        }
    }

    chunk.level = .ExternalLight
}