package world

import "core:math"
import "core:math/rand"
import "core:fmt"
import "base:runtime"
import "../skeewb"

setBlock :: proc(x, y, z: i32, id: u16, chunks: [3][3][3]^Chunk) {
    x := x; y := y; z := z
    c := chunks[1][1][1]
    ox, oy, oz: i32 = 0, 0, 0

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

    if abs(ox) > 1 || abs(oy) > 1 || abs(oz) > 1 do return

    c = chunks[ox + 1][oy + 1][oz + 1]

    c.isEmpty = false
    c.primer[x + 1][y + 1][z + 1].id = id
}

placeTree :: proc(x, y, z: i32, chunks: [3][3][3]^Chunk, rnd: f32) {
    setBlock(x, y, z, 2, chunks)

    for i := y + 1; i <= y + 5; i += 1 { 
        if i - y == 2 && rnd <= 2 {
            setBlock(x, i, z, 9, chunks)
        } else {
            setBlock(x, i, z, 6, chunks)
        }
    }

    leaves: u16 = rnd <= 1 || rnd >= 3 ? 7 : 5

    for i: i32 = x - 2; i <= x + 2; i += 1 {
        for j: i32 = z - 2; j <= z + 2; j += 1 {
            for k: i32 = y + 3; k <= y + 4; k += 1 {
                xx := i == x - 2 || i == x + 2
                zz := j == z - 2 || j == z + 2

                if xx && zz || i == x && j == z {continue}

                setBlock(i, k, j, leaves, chunks);
            }
        }
    }
    
    for i: i32 = x - 1; i <= x + 1; i += 1 {
        for j: i32 = z - 1; j <= z + 1; j += 1 {
            for k: i32 = y + 5; k <= y + 6; k += 1 {
                xx := i == x - 1 || i == x + 1
                zz := j == z - 1 || j == z + 1

                if xx && zz || k == y + 5 && i == x && j == z {continue}

                setBlock(i, k, j, leaves, chunks);
            }
        }
    }
}

populate :: proc (chunks: [3][3][3]^Chunk) {
    for i in -1..=1 do for j in -1..=1 do for k in -1..=1 {
        chunk := chunks[i + 1][j + 1][k + 1]
        x := chunk.pos.x
        y := chunk.pos.y
        z := chunk.pos.z
        
        rand.reset(u64(math.abs(x * 263781623 + y * 3647463 + z * z + 1)))
        n := int(math.floor(3 * rand.float32() + 3))

        if x == 0 && y == 0 && z == 0 do fmt.printfln("%d", n)
            
        for _ in 0..<n {
            x0 := u32(math.floor(16 * rand.float32()))
            z0 := u32(math.floor(16 * rand.float32()))
            
            toPlace := false
            y0 := 0
            if j == 0 && chunks[i + 1][j][k + 1].primer[x0 + 1][15][z0 + 1].id == 3 {
                toPlace = true
            } else {
                for h in 0..<16 {
                    y0 = h
                    if chunk.primer[x0 + 1][y0 + 1][z0 + 1].id == 3 {
                        toPlace = true
                        break
                    }
                }
            }
            
            if toPlace {
                placeTree(i32(x0) + i32(i) * 16, i32(y0) + i32(j) * 16, i32(z0) + i32(k) * 16, chunks, 4 * rand.float32())
            }
        }
    }

    chunks[1][1][1].level = .Trees
}