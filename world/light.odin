package world

import "../skeewb"

Light :: struct{
    pos: iVec3,
    value: u8,
}

sunlight :: proc(chunk: ^Chunk) /*-> ([16][16][16][2]u8, [16][16][16]bool)*/ {
    if chunk.level != .Trees do return
    cache: [16][16][16]u8
    solidCache: [16][16][16]bool
    sunlightCache := [dynamic]Light{}
    defer delete(sunlightCache)
    emissiveCache := [dynamic]Light{}
    defer delete(emissiveCache)

    //topChunk := chunk.sides[.Up]

    for x in 0..<16 {
        for z in 0..<16 {
            foundGround := false
            for y := 15; y >= 0; y -= 1 {
                block := chunk.primer[x + 1][y + 1][z + 1]
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

                // top := u8(15)
                // if y == 15 {
                //     // if topChunk != nil {
                //     //     top = topChunk.primer[x][0][z].light.y
                //     // }
                //     top = 15
                // } else {
                //     top = cache[x][y + 1][z]
                // }

                if !foundGround {
                    // cache[x][y][z] = top
                    append(&sunlightCache, Light{iVec3{i32(x), i32(y), i32(z)}, 15})
                }
            }
        }
    }
    
    for light in sunlightCache {
        pos := light.pos
        if solidCache[pos.x][pos.y][pos.z] do continue
        if chunk.primer[pos.x + 1][pos.y + 1][pos.z + 1].light.y >= light.value do continue
    
        x := pos.x
        y := pos.y
        z := pos.z
    
        if light.value > 15 {
            skeewb.console_log(.DEBUG, "%d, %d, %d", x, y, z)
            continue
        }
        chunk.primer[x + 1][y + 1][z + 1].light.y = light.value
        if light.value <= 1 do continue
        if x !=  0 do append(&sunlightCache, Light{iVec3{x - 1, y, z}, light.value - 1})
        if x != 15 do append(&sunlightCache, Light{iVec3{x + 1, y, z}, light.value - 1})
        if y !=  0 do append(&sunlightCache, Light{iVec3{x, y - 1, z}, light.value - 1})
        if y != 15 do append(&sunlightCache, Light{iVec3{x, y + 1, z}, light.value - 1})
        if z !=  0 do append(&sunlightCache, Light{iVec3{x, y, z - 1}, light.value - 1})
        if z != 15 do append(&sunlightCache, Light{iVec3{x, y, z + 1}, light.value - 1})
    }
    
    for light in emissiveCache {
        pos := light.pos
        if solidCache[pos.x][pos.y][pos.z] do continue
        if chunk.primer[pos.x + 1][pos.y + 1][pos.z + 1].light.x >= light.value do continue
    
        x := pos.x
        y := pos.y
        z := pos.z
    
        if light.value > 15 do continue
        chunk.primer[x + 1][y + 1][z + 1].light.x = light.value
        if light.value <= 1 do continue
        if x !=  0 do append(&emissiveCache, Light{iVec3{x - 1, y, z}, light.value - 1})
        if x != 15 do append(&emissiveCache, Light{iVec3{x + 1, y, z}, light.value - 1})
        if y !=  0 do append(&emissiveCache, Light{iVec3{x, y - 1, z}, light.value - 1})
        if y != 15 do append(&emissiveCache, Light{iVec3{x, y + 1, z}, light.value - 1})
        if z !=  0 do append(&emissiveCache, Light{iVec3{x, y, z - 1}, light.value - 1})
        if z != 15 do append(&emissiveCache, Light{iVec3{x, y, z + 1}, light.value - 1})
    }

    chunk.level = .InternalLight
}

iluminate :: proc(chunk: ^Chunk) {
    if chunk.level != .ExternalTrees do return

    emissiveCache := [dynamic]Light{}
    defer delete(emissiveCache)
    sunlightCache := [dynamic]Light{}
    defer delete(sunlightCache)

    for x in 0..=17 {
        for y in 0..=17 {
            for z in 0..=17 {
                if x > 0 && x < 17 && y > 0 && y < 17 && z > 0 && z < 17 do continue
                light := chunk.primer[x][y][z].light
                chunk.primer[x][y][z].light = {0, 0}
                xx := i32(x) - 1 
                yy := i32(y) - 1 
                zz := i32(z) - 1 
                ox: i32 = 0
                oy: i32 = 0
                oz: i32 = 0
                count: u8 = 0
                if x == 0 {
                    ox = 1
                    count += 1
                } else if x == 17 {
                    ox = -1
                    count += 1
                }
                if y == 0 {
                    oy = 1
                    count += 1
                } else if y == 17 {
                    oy = -1
                    count += 1
                }
                if z == 0 {
                    oz = 1
                    count += 1
                } else if z == 17 {
                    oz = -1
                    count += 1
                }
                // if light.y > count + 1 do append(&sunlightCache, Light{iVec3{xx + ox, yy + oy, zz + oz}, light.y - count})
                // if light.x > count + 1 do append(&emissiveCache, Light{iVec3{xx + ox, yy + oy, zz + oz}, light.x - count})
                if light.y > 1 do append(&sunlightCache, Light{iVec3{xx, yy, zz}, light.y})
                if light.x > 1 do append(&emissiveCache, Light{iVec3{xx, yy, zz}, light.x})
            }
        }
    }

    solidCache: [16][16][16]bool
    for x in 0..<16 {
        for y in 0..<16 {
            for z in 0..<16 {
                block := chunk.primer[x + 1][y + 1][z + 1]
                id := block.id
                transparent := id == 7 || id == 8 || id == 9
                solid := id != 0 && !transparent
                
                solidCache[x][y][z] = solid
            }
        }
    }
    for light in sunlightCache {
        pos := light.pos
        x := pos.x
        y := pos.y
        z := pos.z
        insideChunk := x >= 0 && x < 16 && y >= 0 && y < 16 && z >= 0 && z < 16

        if insideChunk && solidCache[x][y][z] do continue
        if chunk.primer[x + 1][y + 1][z + 1].light.y >= light.value do continue
    
        if light.value > 15 do continue
        chunk.primer[x + 1][y + 1][z + 1].light.y = light.value
        if light.value <= 1 do continue

        if x >  0 do append(&sunlightCache, Light{iVec3{x - 1, y, z}, light.value - 1})
        if x < 15 do append(&sunlightCache, Light{iVec3{x + 1, y, z}, light.value - 1})
        if y >  0 do append(&sunlightCache, Light{iVec3{x, y - 1, z}, light.value - 1})
        if y < 15 do append(&sunlightCache, Light{iVec3{x, y + 1, z}, light.value - 1})
        if z >  0 do append(&sunlightCache, Light{iVec3{x, y, z - 1}, light.value - 1})
        if z < 15 do append(&sunlightCache, Light{iVec3{x, y, z + 1}, light.value - 1})
    }
    
    for light in emissiveCache {
        pos := light.pos
        x := pos.x
        y := pos.y
        z := pos.z
        insideChunk := x >= 0 && x < 16 && y >= 0 && y < 16 && z >= 0 && z < 16
        if insideChunk && solidCache[x][y][z] do continue
        if chunk.primer[x + 1][y + 1][z + 1].light.x >= light.value do continue
    
        if light.value > 15 do continue
        chunk.primer[x + 1][y + 1][z + 1].light.x = light.value
        if light.value <= 1 do continue
        if x >  0 do append(&emissiveCache, Light{iVec3{x - 1, y, z}, light.value - 1})
        if x < 15 do append(&emissiveCache, Light{iVec3{x + 1, y, z}, light.value - 1})
        if y >  0 do append(&emissiveCache, Light{iVec3{x, y - 1, z}, light.value - 1})
        if y < 15 do append(&emissiveCache, Light{iVec3{x, y + 1, z}, light.value - 1})
        if z >  0 do append(&emissiveCache, Light{iVec3{x, y, z - 1}, light.value - 1})
        if z < 15 do append(&emissiveCache, Light{iVec3{x, y, z + 1}, light.value - 1})
    }

    chunk.level = .ExternalLight
}