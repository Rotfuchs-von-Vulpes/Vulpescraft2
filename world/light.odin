package world

import "../skeewb"
import "core:fmt"

Light :: struct{
    pos: iVec3,
    value: u8,
}

allLight :: proc(chunk: ^Chunk) {
    if chunk.level != .Trees do return
    for x in 0..<16 {
        for y in 0..<16 {
            for z in 0..<16 {
                chunk.primer[x + 1][y + 1][z + 1].light = {0, 15}
            }
        }
    }
    chunk.level = .InternalLight
}

sunlight :: proc(chunk: ^Chunk) {
    if chunk.level != .Trees do return
    cache: [16][16][16]u8
    solidCache: [16][16][16]bool
    sunlightCache := [dynamic]Light{}
    defer delete(sunlightCache)
    emissiveCache := [dynamic]Light{}
    defer delete(emissiveCache)

    for x in 0..<16 {
        for z in 0..<16 {
            foundGround := false
            for y := 15; y >= 0; y -= 1 {
                chunk.primer[x + 1][y + 1][z + 1].light = {0, 0}
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

                top := u8(15)
                if y == 15 {
                    top = 15
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
    if chunk.level != .SidesClone do return

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

applyLight :: proc (chunks: [3][3][3]^Chunk) {
    emissiveCache := [dynamic]Light{}
    defer delete(emissiveCache)
    sunlightCache := [dynamic]Light{}
    defer delete(sunlightCache)

    lightCopy: [3 * 16][3 * 16][3 * 16][2]u8
    solidCache: [3 * 16][3 * 16][3 * 16]bool
    visited: [3 * 16][3 * 16][3 * 16][2]bool
    for i in -1..=1 do for j in -1..=1 do for k in -1..=1 {
        chunk := chunks[i + 1][j + 1][k + 1]
        for x in 0..<16 do for z in 0..<16 {
            foundGround := false
            for y := 15; y >= 0; y -= 1 {
                if i == 0 && j == 0 && k == 0 do chunk.primer[x + 1][y + 1][z + 1].light = {0, 0}
                block := chunk.primer[x + 1][y + 1][z + 1]
                id := block.id
                transparent := id == 7 || id == 8 || id == 9
                solid := id != 0 && !transparent
                
                solidCache[x + i * 16 + 16][y + j * 16 + 16][z + k * 16 + 16] = solid
                visited[x + i * 16 + 16][y + j * 16 + 16][z + k * 16 + 16] = {solid, solid}
                lightCopy[x + i * 16 + 16][y + j * 16 + 16][z + k * 16 + 16] = {0, 0}

                if id != 0 {
                    foundGround = true
                }

                if id == 9 {
                    append(&emissiveCache, Light{{i32(x + i * 16) + 16, i32(y + j * 16) + 16, i32(z + k * 16) + 16}, 15})
                    visited[x + i * 16 + 16][y + j * 16 + 16][z + k * 16 + 16].x = true
                }

                if !foundGround {
                    append(&sunlightCache, Light{{i32(x + i * 16) + 16, i32(y + j * 16) + 16, i32(z + k * 16) + 16}, 15})
                    visited[x + i * 16 + 16][y + j * 16 + 16][z + k * 16 + 16].y = true
                }
            }
        }
    }

    chunk := chunks[1][1][1]

    for light in emissiveCache {
        x := light.pos.x
        y := light.pos.y
        z := light.pos.z

        if solidCache[x][y][z] do continue
        if light.value <= lightCopy[x][y][z].x do continue

        lightCopy[x][y][z].x = light.value
        if light.value <= 1 do continue

        if x >  0 && !visited[x - 1][y][z].x {
            append(&emissiveCache, Light{{x - 1, y, z}, light.value - 1})
            visited[x - 1][y][z].x = true
        }
        if x < 47 && !visited[x + 1][y][z].x {
            append(&emissiveCache, Light{{x + 1, y, z}, light.value - 1})
            visited[x + 1][y][z].x = true
        }
        if y >  0 && !visited[x][y - 1][z].x {
            append(&emissiveCache, Light{{x, y - 1, z}, light.value - 1})
            visited[x][y - 1][z].x = true
        }
        if y < 47 && !visited[x][y + 1][z].x {
            append(&emissiveCache, Light{{x, y + 1, z}, light.value - 1})
            visited[x][y + 1][z].x = true
        }
        if z >  0 && !visited[x][y][z - 1].x {
            append(&emissiveCache, Light{{x, y, z - 1}, light.value - 1})
            visited[x][y][z - 1].x = true
        }
        if z < 47 && !visited[x][y][z + 1].x {
            append(&emissiveCache, Light{{x, y, z + 1}, light.value - 1})
            visited[x][y][z + 1].x = true
        }
    }

    for light in sunlightCache {
        x := light.pos.x
        y := light.pos.y
        z := light.pos.z

        lightCopy[x][y][z].y = light.value
        if light.value <= 1 do continue

        if x >  0 && !visited[x - 1][y][z].y {
            append(&sunlightCache, Light{{x - 1, y, z}, light.value - 1})
            visited[x - 1][y][z].y = true
        }
        if x < 47 && !visited[x + 1][y][z].y {
            append(&sunlightCache, Light{{x + 1, y, z}, light.value - 1})
            visited[x + 1][y][z].y = true
        }
        if y >  0 && !visited[x][y - 1][z].y {
            append(&sunlightCache, Light{{x, y - 1, z}, light.value - 1})
            visited[x][y - 1][z].y = true
        }
        if y < 47 && !visited[x][y + 1][z].y {
            append(&sunlightCache, Light{{x, y + 1, z}, light.value - 1})
            visited[x][y + 1][z].y = true
        }
        if z >  0 && !visited[x][y][z - 1].y {
            append(&sunlightCache, Light{{x, y, z - 1}, light.value - 1})
            visited[x][y][z - 1].y = true
        }
        if z < 47 && !visited[x][y][z + 1].y {
            append(&sunlightCache, Light{{x, y, z + 1}, light.value - 1})
            visited[x][y][z + 1].y = true
        }
    }


    for x in -1..=16 do for y in -1..<17 do for z in -1..<17 {
        chunk.primer[x + 1][y + 1][z + 1].light = lightCopy[x + 16][y + 16][z + 16]
    }

    chunks[1][1][1].level = .ExternalLight
}
