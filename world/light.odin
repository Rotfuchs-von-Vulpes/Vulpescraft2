package world

import "../skeewb"

Light :: struct{
    pos: iVec3,
    value: u8,
}

allLight :: proc(chunk: ^Chunk) {
    for x in 0..<16 {
        for y in 0..<16 {
            for z in 0..<16 {
                chunk.primer[x + 1][y + 1][z + 1].light = {0, 15}
            }
        }
    }
}

sunlight :: proc(chunk: ^Chunk) {
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
        x := light.pos.x
        y := light.pos.y
        z := light.pos.z
        if solidCache[x][y][z] do continue
        if chunk.primer[x + 1][y + 1][z + 1].light.y >= light.value do continue
    
    
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
        x := light.pos.x
        y := light.pos.y
        z := light.pos.z
        if solidCache[x][y][z] do continue
        if chunk.primer[x + 1][y + 1][z + 1].light.x >= light.value do continue
    
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
                if light.y > 1 do append(&sunlightCache, Light{iVec3{i32(x) - 1, i32(y) - 1, i32(z) - 1}, light.y})
                if light.x > 1 do append(&emissiveCache, Light{iVec3{i32(x) - 1, i32(y) - 1, i32(z) - 1}, light.x})
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
        x := light.pos.x
        y := light.pos.y
        z := light.pos.z
        insideChunk := x >= 0 && x < 16 && y >= 0 && y < 16 && z >= 0 && z < 16

        if insideChunk && solidCache[x][y][z] do continue
        if chunk.primer[x + 1][y + 1][z + 1].light.y >= light.value do continue
    
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
        x := light.pos.x
        y := light.pos.y
        z := light.pos.z
        insideChunk := x >= 0 && x < 16 && y >= 0 && y < 16 && z >= 0 && z < 16
        if insideChunk && solidCache[x][y][z] do continue
        if chunk.primer[x + 1][y + 1][z + 1].light.x >= light.value do continue
    
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