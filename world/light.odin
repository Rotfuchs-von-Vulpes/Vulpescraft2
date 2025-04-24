package world

import "../skeewb"
import "core:fmt"

Light :: struct{
    pos: iVec3,
    value: u8,
}

applyLight :: proc (chunks: [3][3][3]^Chunk) {
    emissiveCache := [dynamic]Light{}
    defer delete(emissiveCache)
    sunlightCache := [dynamic]Light{}
    defer delete(sunlightCache)

    lightCopy: [3 * 16][3 * 16][3 * 16][2]u8
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

                pos := [3]int{x + i * 16 + 16, y + j * 16 + 16, z + k * 16 + 16}
                
                visited[pos.x][pos.y][pos.z] = {solid, solid}
                lightCopy[pos.x][pos.y][pos.z] = {0, 0}

                if id != 0 {
                    foundGround = true
                }

                if id == 9 {
                    light := Light{{i32(x + i * 16) + 16, i32(y + j * 16) + 16, i32(z + k * 16) + 16}, 15}
                    append(&emissiveCache, light)
                    visited[pos.x][pos.y][pos.z].x = true
                }

                if !foundGround {
                    light := Light{{i32(x + i * 16) + 16, i32(y + j * 16) + 16, i32(z + k * 16) + 16}, 15}
                    append(&sunlightCache, light)
                    visited[pos.x][pos.y][pos.z].y = true
                }
            }
        }
    }

    for light in emissiveCache {
        x := light.pos.x
        y := light.pos.y
        z := light.pos.z

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

        if light.value <= lightCopy[x][y][z].x do continue

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

    chunk := chunks[1][1][1]
    for x in -1..<17 do for y in -1..<17 do for z in -1..<17 {
        chunk.primer[x + 1][y + 1][z + 1].light = lightCopy[x + 16][y + 16][z + 16]
    }

    chunks[1][1][1].level = .ExternalLight
}
