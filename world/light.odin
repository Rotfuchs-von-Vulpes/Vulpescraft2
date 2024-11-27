package world

Light :: struct{
    pos: iVec3,
    value: u8,
}

sunlight :: proc(chunk: ^Chunk, tempMap: ^map[iVec3]^Chunk) -> ([16][16][16][2]u8, [16][16][16]bool) {
    buffer: [16][16][16][2]u8
    cache: [16][16][16]u8
    solidCache: [16][16][16]bool
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

    chunk.level = 3

    return buffer, solidCache
}

iluminate :: proc(chunk: ^Chunk, buffer: [16][16][16][2]u8, solidCache: [16][16][16]bool) -> [16][16][16][2]u8 {
    buffer := buffer
    
    mxx := chunk.sides[.West]
    pxx := chunk.sides[.East]
    xmx := chunk.sides[.Bottom]
    xpx := chunk.sides[.Up]
    xxm := chunk.sides[.South]
    xxp := chunk.sides[.North]

    emissiveCache := [dynamic]Light{}
    defer delete(emissiveCache)
    sunlightCache := [dynamic]Light{}
    defer delete(sunlightCache)

    for y in 0..<16 {
        for z in 0..<16 {
            light := mxx.primer[15][y][z].light
            if light.y > 1 do append(&sunlightCache, Light{{0, i32(y), i32(z)}, light.y - 1})
            if light.x > 1 do append(&emissiveCache, Light{{0, i32(y), i32(z)}, light.x - 1})
        }
    }
    for y in 0..<16 {
        for z in 0..<16 {
            light := pxx.primer[0][y][z].light
            if light.y > 1 do append(&sunlightCache, Light{{15, i32(y), i32(z)}, light.y - 1})
            if light.x > 1 do append(&emissiveCache, Light{{15, i32(y), i32(z)}, light.x - 1})
        }
    }
    for x in 0..<16 {
        for z in 0..<16 {
            light := xmx.primer[x][15][z].light
            if light.y > 1 do append(&sunlightCache, Light{{i32(x), 0, i32(z)}, light.y - 1})
            if light.x > 1 do append(&emissiveCache, Light{{i32(x), 0, i32(z)}, light.x - 1})
        }
    }
    for x in 0..<16 {
        for z in 0..<16 {
            light := xpx.primer[x][0][z].light
            if light.y > 1 do append(&sunlightCache, Light{{i32(x), 15, i32(z)}, light.y - 1})
            if light.x > 1 do append(&emissiveCache, Light{{i32(x), 15, i32(z)}, light.x - 1})
        }
    }
    for x in 0..<16 {
        for y in 0..<16 {
            light := xxm.primer[x][y][15].light
            if light.y > 1 do append(&sunlightCache, Light{{i32(x), i32(y), 0}, light.y - 1})
            if light.x > 1 do append(&emissiveCache, Light{{i32(x), i32(y), 0}, light.x - 1})
        }
    }
    for x in 0..<16 {
        for y in 0..<16 {
            light := xxp.primer[x][y][0].light
            if light.y > 1 do append(&sunlightCache, Light{{i32(x), i32(y), 15}, light.y - 1})
            if light.x > 1 do append(&emissiveCache, Light{{i32(x), i32(y), 15}, light.x - 1})
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

    chunk.level = 4

    return buffer
}