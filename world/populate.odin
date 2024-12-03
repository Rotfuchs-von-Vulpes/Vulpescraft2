package world

import "core:math"
import "core:math/rand"

setBlock :: proc(x, y, z: i32, id: u16, c: ^Chunk, tempMap: ^map[iVec3]^Chunk) {
    x := x; y := y; z := z; c := c

    for x >= 16 {
        x -= 16
        side := c.sides[.East]
        if side == nil {
            side = eval(c.pos.x + 1, c.pos.y, c.pos.z, tempMap)
            c.sides[.East] = side
        }
        if .East not_in c.opened {
            c.opened += {.East}
        }
        c = side
    }
    for x < 0 {
        x += 16
        side := c.sides[.West]
        if side == nil {
            side = eval(c.pos.x - 1, c.pos.y, c.pos.z, tempMap)
            c.sides[.West] = side
        }
        if .West not_in c.opened {
            c.opened += {.West}
        }
        c = side
    }
    for y >= 16 {
        y -= 16
        side := c.sides[.Up]
        if side == nil {
            side = eval(c.pos.x, c.pos.y + 1, c.pos.z, tempMap)
            c.sides[.Up] = side
        }
        if .Up not_in c.opened {
            c.opened += {.Up}
        }
        c = side
    }
    for y < 0 {
        y += 16
        side := c.sides[.Bottom]
        if side == nil {
            side = eval(c.pos.x, c.pos.y - 1, c.pos.z, tempMap)
            c.sides[.Bottom] = side
        }
        if .Bottom not_in c.opened {
            c.opened += {.Bottom}
        }
        c = side
    }
    for z >= 16 {
        z -= 16
        side := c.sides[.North]
        if side == nil {
            side = eval(c.pos.x, c.pos.y, c.pos.z + 1, tempMap)
            c.sides[.North] = side
        }
        if .North not_in c.opened {
            c.opened += {.North}
        }
        c = side
    }
    for z < 0 {
        z += 16
        side := c.sides[.South]
        if side == nil {
            side = eval(c.pos.x, c.pos.y, c.pos.z - 1, tempMap)
            c.sides[.South] = side
        }
        if .South not_in c.opened {
            c.opened += {.South}
        }
        c = side
    }

    c.isEmpty = false
    c.primer[x][y][z].id = id
    c.primer[x][y][z].light = {0, 0}
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
            if chunk.primer[x0][j][z0].id == 3 {
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