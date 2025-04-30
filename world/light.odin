package world

import "../skeewb"
import "core:fmt"

Light :: struct{
    pos: iVec3,
    value: u8,
}

applyLight :: proc (chunk: ^ChunkPrimer) -> ^ChunkData {
    emissiveCache := [dynamic]Light{}
    defer delete(emissiveCache)
    sunlightCache := [dynamic]Light{}
    defer delete(sunlightCache)

    lightCopy: [3 * 16][3 * 16][3 * 16][2]u8
    visited: [3 * 16][3 * 16][3 * 16][2]bool

    for i in -1..=1 do for j in -1..=1 do for k in -1..=1 {
        for x in 0..<16 do for y in 0..<16 do for z in 0..<16 {
            data := chunk.light[(i + 1) * 16 + x][(j + 1) * 16 + y][(k + 1) * 16 + z]
            pos := iVec3{i32((i + 1) * 16 + x), i32((j + 1) * 16 + y), i32((k + 1) * 16 + z)}
                
            visited[pos.x][pos.y][pos.z] = {data.solid, data.solid}
            lightCopy[pos.x][pos.y][pos.z] = {0, 0}

            //if data.solid do continue

            if data.light {
                light := Light{pos, 15}
                append(&emissiveCache, light)
                visited[pos.x][pos.y][pos.z].x = true
            }

            if data.sky {
                light := Light{pos, 15}
                append(&sunlightCache, light)
                visited[pos.x][pos.y][pos.z].y = true
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

    data := new(ChunkData)
    data.pos = chunk.pos

    for x in -1..<17 do for y in -1..<17 do for z in -1..<17 {
        data.primer[x + 1][y + 1][z + 1].id = chunk.primer[x + 1][y + 1][z + 1]
        data.primer[x + 1][y + 1][z + 1].light = lightCopy[x + 16][y + 16][z + 16]
    }

    return data
}
