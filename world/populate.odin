package world

import "core:math"
import "core:math/rand"
import "../skeewb"

setBlock :: proc(x, y, z: i32, id: u16, c: ^Chunk, tempMap: ^map[iVec3]^Chunk) {
    x := x; y := y; z := z; c := c
    ox, oy, oz: i32

    for x >= 16 {
        ox += 1
        x -= 16
    }
    for x < 0 {
        ox -= 1
        x += 16
    }
    for y >= 16 {
        oy += 1
        y -= 16
    }
    for y < 0 {
        oy -= 1
        y += 16
    }
    for z >= 16 {
        oz += 1
        z -= 16
    }
    for z < 0 {
        oz -= 1
        z += 16
    }

    if x != 0 || y != 0 || z != 0 do c = eval(c.pos.x + ox, c.pos.y + oy, c.pos.z + oz, tempMap)

    c.isEmpty = false
    c.primer[x + 1][y + 1][z + 1].id = id
}

placeTree :: proc(x, y, z: i32, c: ^Chunk, tempMap: ^map[iVec3]^Chunk, rnd: f32) {
    setBlock(x, y, z, 2, c, tempMap)

    for i := y + 1; i <= y + 5; i += 1 { 
        if i - y == 2 && rnd <= 2 {
            setBlock(x, i, z, 9, c, tempMap)
        } else {
            setBlock(x, i, z, 6, c, tempMap)
        }
    }

    leaves: u16 = rnd <= 1 || rnd >= 3 ? 7 : 5

    for i: i32 = x - 2; i <= x + 2; i += 1 {
        for j: i32 = z - 2; j <= z + 2; j += 1 {
            for k: i32 = y + 3; k <= y + 4; k += 1 {
                xx := i == x - 2 || i == x + 2
                zz := j == z - 2 || j == z + 2

                if xx && zz || i == x && j == z {continue}

                setBlock(i, k, j, leaves, c, tempMap);
            }
        }
    }
    
    for i: i32 = x - 1; i <= x + 1; i += 1 {
        for j: i32 = z - 1; j <= z + 1; j += 1 {
            for k: i32 = y + 5; k <= y + 6; k += 1 {
                xx := i == x - 1 || i == x + 1
                zz := j == z - 1 || j == z + 1

                if xx && zz || k == y + 5 && i == x && j == z {continue}

                setBlock(i, k, j, leaves, c, tempMap);
            }
        }
    }
}

populate :: proc(chunk: ^Chunk, tempMap: ^map[iVec3]^Chunk) {
    if chunk.level != .Blocks do return
    x := chunk.pos.x
    y := chunk.pos.y
    z := chunk.pos.z
        
    state := rand.create(u64(math.abs(x * 263781623 + y * 3647463 + z)))
    rnd := rand.default_random_generator(&state)
    n := int(math.floor(3 * rand.float32(rnd) + 3))
        
    for i in 0..<n {
        x0 := u32(math.floor(16 * rand.float32(rnd)))
        z0 := u32(math.floor(16 * rand.float32(rnd)))
        
        toPlace := false
        y0: u32 = 0
        for j in 0..<16 {
            y0 = u32(j)
            if chunk.primer[x0 + 1][j + 1][z0 + 1].id == 3 {
                toPlace = true
                break
            }
        }
        
        if toPlace {
            placeTree(i32(x0), i32(y0), i32(z0), chunk, tempMap, 4 * rand.float32(rnd))
        }
    }

    chunk.level = .Trees
}