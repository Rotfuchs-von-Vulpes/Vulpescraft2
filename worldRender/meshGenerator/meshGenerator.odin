package meshGenerator

import "../../skeewb"
import "../../world"

Primers :: [3][3][3]^^world.Chunk

uVec2 :: [2]u32
iVec3 :: [3]i32
vec3 :: [3]f32

Direction :: enum {Up, Bottom, North, South, East, West}
FaceSet :: bit_set[Direction]

Cube :: struct {
    id: u32,
    pos: iVec3,
}

CubeFaces :: struct {
    id: u32,
    pos: iVec3,
    faces: FaceSet,
}

Orientation :: enum {Up, Down, Right, Left}
Position :: enum {NorthwestUp, NorthwestDown, NortheastUp, NortheastDown, SoutheastUp, SoutheastDown, SouthwestUp, SouthwestDown}
Corner :: enum {TopLeft, BottomLeft, BottomRight, TopRight}
PositionSet :: bit_set[Position]

CubePoints :: struct {
    id: u32,
    pos: iVec3,
    points: PositionSet,
}

CubeFacesPoints :: struct {
    id: u32,
    pos: iVec3,
    faces: FaceSet,
    points: PositionSet,
}

Point :: struct {
    pos: vec3,
    occlusion: f32,
    light: [2]f32,
}

Face :: struct {
    pos: iVec3,
    direction: Direction,
    textureID: f32,
    orientation: Orientation,
    corners: [Corner]Point,
}

Mesh :: struct {
    vertices: [dynamic]f32,
    indices: [dynamic]u32,
    length: i32,
}

ChunkData :: struct {
    pos: iVec3,
    blocks: Mesh,
    water: Mesh,
}

toVec3 :: proc(vec: iVec3) -> vec3 {
    return vec3{f32(vec.x), f32(vec.y), f32(vec.z)}
}

isSideExposed :: proc(chunk: ^world.Chunk, pos: iVec3, offset: iVec3) -> bool {
    id := chunk.primer[pos.x + offset.x + 1][pos.y + offset.y + 1][pos.z + offset.z + 1].id
    return id == 0 || id == 7 || id == 8 && chunk.primer[pos.x + 1][pos.y + 1][pos.z + 1].id != 8;
}

hasSideExposed :: proc(chunk: ^world.Chunk, pos: iVec3) -> bool {
    if isSideExposed(chunk, pos, {-1, 0, 0}) {return true}
    if isSideExposed(chunk, pos, { 1, 0, 0}) {return true}
    if isSideExposed(chunk, pos, { 0,-1, 0}) {return true}
    if isSideExposed(chunk, pos, { 0, 1, 0}) {return true}
    if isSideExposed(chunk, pos, { 0, 0,-1}) {return true}
    if isSideExposed(chunk, pos, { 0, 0, 1}) {return true}

    return false
}

filterCubes :: proc(chunk: ^world.Chunk) -> [dynamic]Cube {
    filtered := [dynamic]Cube{}

    for i: i32 = 0; i < 16; i += 1 {
        for j: i32 = 0; j < 16; j += 1 {
            for k: i32 = 0; k < 16; k += 1 {
                pos: iVec3 = {i, j, k}
                id := chunk.primer[i + 1][j + 1][k + 1].id

                if id == 0 {continue}

                if hasSideExposed(chunk, pos) {append(&filtered, Cube{u32(id), pos})}
            }
        }
    }

    return filtered
}

makeCubes :: proc(chunk: ^world.Chunk, cubes: [dynamic]Cube) -> [dynamic]CubeFaces {
    cubesFaces := [dynamic]CubeFaces{}

    for cube in cubes {
        pos := cube.pos
        faces := FaceSet{}

        if isSideExposed(chunk, pos, {-1, 0, 0}) {faces = faces + {.West}};
        if isSideExposed(chunk, pos, { 1, 0, 0}) {faces = faces + {.East}};
        if isSideExposed(chunk, pos, { 0,-1, 0}) {faces = faces + {.Bottom}};
        if isSideExposed(chunk, pos, { 0, 1, 0}) {faces = faces + {.Up}};
        if isSideExposed(chunk, pos, { 0, 0,-1}) {faces = faces + {.South}};
        if isSideExposed(chunk, pos, { 0, 0, 1}) {faces = faces + {.North}};

        append(&cubesFaces, CubeFaces{cube.id, pos, faces})
    }

    return cubesFaces;
}

makeCubePoints :: proc(cubesFaces: [dynamic]CubeFaces) -> [dynamic]CubeFacesPoints {
    cubeFacesPoints := [dynamic]CubeFacesPoints{}

    for cube in cubesFaces {
        min := cube.pos
        max := cube.pos + 1
        positions := PositionSet{}
        
        if .East  in cube.faces {positions = positions + {.NortheastDown, .NortheastUp, .SoutheastDown, .SoutheastUp}}
        if .Up    in cube.faces {positions = positions + {.NortheastUp,   .NorthwestUp, .SoutheastUp,   .SouthwestUp}}
        if .North in cube.faces {positions = positions + {.NortheastDown, .NortheastUp, .NorthwestDown, .NorthwestUp}}
        if .West   in cube.faces {positions = positions + {.NorthwestDown, .NorthwestUp,   .SouthwestDown, .SouthwestUp  }}
        if .Bottom in cube.faces {positions = positions + {.NortheastDown, .NorthwestDown, .SoutheastDown, .SouthwestDown}}
        if .South  in cube.faces {positions = positions + {.SoutheastDown, .SoutheastUp,   .SouthwestDown, .SouthwestUp  }}

        append(&cubeFacesPoints, CubeFacesPoints{cube.id, cube.pos, cube.faces, positions})
    }

    return cubeFacesPoints
}

getBlockPos :: proc(primers: Primers, pos: iVec3) -> (^^world.Chunk, iVec3, bool) {
    sidePos := pos

    chunkXOffset := 0
    chunkYOffset := 0
    chunkZOffset := 0

    if pos.x < 0 {
        sidePos = {sidePos.x + 16, sidePos.y, sidePos.z}
        chunkXOffset = -1
    }
    if pos.x > 15 {
        sidePos = {sidePos.x - 16, sidePos.y, sidePos.z}
        chunkXOffset = 1
    }
    if pos.y < 0 {
        sidePos = {sidePos.x, sidePos.y + 16, sidePos.z}
        chunkYOffset = -1
    }
    if pos.y > 15 {
        sidePos = {sidePos.x, sidePos.y - 16, sidePos.z}
        chunkYOffset = 1
    }
    if pos.z < 0 {
        sidePos = {sidePos.x, sidePos.y, sidePos.z + 16}
        chunkZOffset = -1
    }
    if pos.z > 15 {
        sidePos = {sidePos.x, sidePos.y, sidePos.z - 16}
        chunkZOffset = 1
    }

    if primers[chunkXOffset + 1][chunkYOffset + 1][chunkZOffset + 1] == nil {
        return primers[1][1][1], {0, 0, 0}, false
    }
    finalPos := iVec3{sidePos.x, sidePos.y, sidePos.z}
    return primers[chunkXOffset + 1][chunkYOffset + 1][chunkZOffset + 1], finalPos, true
}

getLight :: proc(pos: iVec3, offset: iVec3, direction: Direction, chunk: ^world.Chunk) -> [2]f32 {
    normal: iVec3

    switch direction {
        case .Up:     normal = { 0, 1, 0}
        case .Bottom: normal = { 0,-1, 0}
        case .North:  normal = { 0, 0, 1}
        case .South:  normal = { 0, 0,-1}
        case .East:   normal = { 1, 0, 0}
        case .West:   normal = {-1, 0, 0}
    }

    posV := iVec3{pos.x, pos.y, pos.z}

    signX: i32 = 1
    signY: i32 = 1
    signZ: i32 = 1
    if offset.x == 0 {signX = -1}
    if offset.y == 0 {signY = -1}
    if offset.z == 0 {signZ = -1}

    side1Pos, side2Pos: iVec3

    if normal.x != 0 {
        side1Pos = posV + {signX, signY, 0}
        side2Pos = posV + {signX, 0, signZ}
    } else if normal.y != 0 {
        side1Pos = posV + {signX, signY, 0}
        side2Pos = posV + {0, signY, signZ}
    } else if normal.z != 0 {
        side1Pos = posV + {signX, 0, signZ}
        side2Pos = posV + {0, signY, signZ}
    }

    cornerPos := posV + {signX, signY, signZ}
    side1Pos2 := side1Pos
    side2Pos2 := side2Pos
    corner := chunk.primer[cornerPos.x + 1][cornerPos.y + 1][cornerPos.z + 1]
    side1 := chunk.primer[side1Pos2.x + 1][side1Pos2.y + 1][side1Pos2.z + 1]
    side2 := chunk.primer[side2Pos2.x + 1][side2Pos2.y + 1][side2Pos2.z + 1]

    normalPos := posV + normal
    light := chunk.primer[normalPos.x + 1][normalPos.y + 1][normalPos.z + 1].light
    blockLight := f32(light.x)
    sunLight := f32(light.y)
    if side1.id == 0 || side1.id == 9 {
        blockLight = max(blockLight, f32(side1.light.x))
        sunLight = max(sunLight, f32(side1.light.y))
    }
    if side2.id == 0 || side2.id == 9 {
        blockLight = max(blockLight, f32(side2.light.x))
        sunLight = max(sunLight, f32(side2.light.y))
    }
    if corner.id == 0 || corner.id == 9 {
        blockLight = max(blockLight, f32(corner.light.x))
        sunLight = max(sunLight, f32(corner.light.y))
    }
    return {f32(blockLight), f32(sunLight)}
}

getAO :: proc(pos: iVec3, offset: vec3, direction: Direction, chunk: ^world.Chunk) -> f32 {
    normal: iVec3

    switch direction {
        case .Up:     normal = { 0, 1, 0}
        case .Bottom: normal = { 0,-1, 0}
        case .North:  normal = { 0, 0, 1}
        case .South:  normal = { 0, 0,-1}
        case .East:   normal = { 1, 0, 0}
        case .West:   normal = {-1, 0, 0}
    }

    posV: iVec3 = {pos.x, pos.y, pos.z}

    signX: i32 = 1
    signY: i32 = 1
    signZ: i32 = 1
    if offset.x == 0 {signX = -1}
    if offset.y == 0 {signY = -1}
    if offset.z == 0 {signZ = -1}

    side1Pos, side2Pos: iVec3

    if normal.x != 0 {
        side1Pos = posV + {signX, signY, 0}
        side2Pos = posV + {signX, 0, signZ}
    } else if normal.y != 0 {
        side1Pos = posV + {signX, signY, 0}
        side2Pos = posV + {0, signY, signZ}
    } else if normal.z != 0 {
        side1Pos = posV + {signX, 0, signZ}
        side2Pos = posV + {0, signY, signZ}
    }

    cornerPos := posV + {signX, signY, signZ}
    side1Pos2 := side1Pos
    side2Pos2 := side2Pos
    corner := chunk.primer[cornerPos.x + 1][cornerPos.y + 1][cornerPos.z + 1].id
    side1 := chunk.primer[side1Pos2.x + 1][side1Pos2.y + 1][side1Pos2.z + 1].id
    side2 := chunk.primer[side2Pos2.x + 1][side2Pos2.y + 1][side2Pos2.z + 1].id

    if corner == 8 {corner = 0}
    if side1 == 8 {side1 = 0}
    if side2 == 8 {side2 = 0}

    if side1 != 0 && side2 != 0 {return 0}
    if corner != 0 && (side1 != 0 || side2 != 0) {return 1}
    if corner != 0 || side1 != 0 || side2 != 0 {return 2}

    return 3
}

makeCorners :: proc(topLeft, bottomLeft, bottomRight, topRight: Point) -> [Corner]Point {
    return {
        .TopLeft     = topLeft,   
        .BottomLeft  = bottomLeft,   
        .BottomRight = bottomRight,   
        .TopRight    = topRight
    }
}

getFacePoints :: proc(cube: CubeFacesPoints, chunk: ^world.Chunk, direction: Direction) -> [Corner]Point {
    pointByVertex := [Position]Point{}

    if .SouthwestDown in cube.points {
        pointByVertex[.SouthwestDown] = Point{toVec3(cube.pos) + {0, 0, 0}, getAO(cube.pos, {0, 0, 0}, direction, chunk), getLight(cube.pos, {0, 0, 0}, direction, chunk)}
    }
    if .NorthwestDown in cube.points {
        pointByVertex[.NorthwestDown] = Point{toVec3(cube.pos) + {0, 0, 1}, getAO(cube.pos, {0, 0, 1}, direction, chunk), getLight(cube.pos, {0, 0, 1}, direction, chunk)}
    }
    if .SouthwestUp   in cube.points {
        pointByVertex[.SouthwestUp]   = Point{toVec3(cube.pos) + {0, 1, 0}, getAO(cube.pos, {0, 1, 0}, direction, chunk), getLight(cube.pos, {0, 1, 0}, direction, chunk)}
    }
    if .NorthwestUp   in cube.points {
        pointByVertex[.NorthwestUp]   = Point{toVec3(cube.pos) + {0, 1, 1}, getAO(cube.pos, {0, 1, 1}, direction, chunk), getLight(cube.pos, {0, 1, 1}, direction, chunk)}
    }
    if .SoutheastDown in cube.points {
        pointByVertex[.SoutheastDown] = Point{toVec3(cube.pos) + {1, 0, 0}, getAO(cube.pos, {1, 0, 0}, direction, chunk), getLight(cube.pos, {1, 0, 0}, direction, chunk)}
    }
    if .NortheastDown in cube.points {
        pointByVertex[.NortheastDown] = Point{toVec3(cube.pos) + {1, 0, 1}, getAO(cube.pos, {1, 0, 1}, direction, chunk), getLight(cube.pos, {1, 0, 1}, direction, chunk)}
    }
    if .SoutheastUp   in cube.points {
        pointByVertex[.SoutheastUp]   = Point{toVec3(cube.pos) + {1, 1, 0}, getAO(cube.pos, {1, 1, 0}, direction, chunk), getLight(cube.pos, {1, 1, 0}, direction, chunk)}
    }
    if .NortheastUp   in cube.points {
        pointByVertex[.NortheastUp]   = Point{toVec3(cube.pos) + {1, 1, 1}, getAO(cube.pos, {1, 1, 1}, direction, chunk), getLight(cube.pos, {1, 1, 1}, direction, chunk)}
    }

    switch direction {
        case .Up:     return makeCorners(pointByVertex[.NortheastUp],   pointByVertex[.SoutheastUp],   pointByVertex[.SouthwestUp],   pointByVertex[.NorthwestUp])
        case .Bottom: return makeCorners(pointByVertex[.NorthwestDown], pointByVertex[.SouthwestDown], pointByVertex[.SoutheastDown], pointByVertex[.NortheastDown])
        case .North:  return makeCorners(pointByVertex[.NorthwestUp],   pointByVertex[.NorthwestDown], pointByVertex[.NortheastDown], pointByVertex[.NortheastUp])
        case .South:  return makeCorners(pointByVertex[.SoutheastUp],   pointByVertex[.SoutheastDown], pointByVertex[.SouthwestDown], pointByVertex[.SouthwestUp])
        case .East:   return makeCorners(pointByVertex[.NortheastUp],   pointByVertex[.NortheastDown], pointByVertex[.SoutheastDown], pointByVertex[.SoutheastUp])
        case .West:   return makeCorners(pointByVertex[.SouthwestUp],   pointByVertex[.SouthwestDown], pointByVertex[.NorthwestDown], pointByVertex[.NorthwestUp])
    }

    panic("Alert, bit flip by cosmic rays detect.")
}

getTextureID :: proc(dir: Direction, id: u32) -> f32 {
    if id == 1 {return 1}
    if id == 2 {return 2}
    if id == 3 {
        if dir == .Up {return 4}
        if dir == .Bottom {return 2}
        return 3
    }
    if id == 4 {return 5}
    if id == 5 {return 9}
    if id == 6 {
        if dir == .Up || dir == .Bottom {return 8}
        return 7
    }
    if id == 7 {return 6}
    if id == 8 {return -1}
    if id == 9 {return 10}

    return 0
}

makePoinsAndFaces :: proc(cubesPoints: [dynamic]CubeFacesPoints, chunk: ^world.Chunk) -> [dynamic]Face {
    faces := [dynamic]Face{}

    for cube in cubesPoints {
        if .Up     in cube.faces {append(&faces, Face{cube.pos, .Up,     getTextureID(.Up,     cube.id), .Up, getFacePoints(cube, chunk, .Up    )})}
        if .Bottom in cube.faces {append(&faces, Face{cube.pos, .Bottom, getTextureID(.Bottom, cube.id), .Up, getFacePoints(cube, chunk, .Bottom)})}
        if .North  in cube.faces {append(&faces, Face{cube.pos, .North,  getTextureID(.North,  cube.id), .Up, getFacePoints(cube, chunk, .North )})}
        if .South  in cube.faces {append(&faces, Face{cube.pos, .South,  getTextureID(.South,  cube.id), .Up, getFacePoints(cube, chunk, .South )})}
        if .East   in cube.faces {append(&faces, Face{cube.pos, .East,   getTextureID(.East,   cube.id), .Up, getFacePoints(cube, chunk, .East  )})}
        if .West   in cube.faces {append(&faces, Face{cube.pos, .West,   getTextureID(.West,   cube.id), .Up, getFacePoints(cube, chunk, .West  )})}
    }

    return faces
}

toFlipe :: proc(a00, a01, a10, a11: f32) -> bool {
	return a00 + a11 < a01 + a10;
}

makeVertices :: proc(faces: [dynamic]Face) -> (Mesh, Mesh) {
    blockVertices := [dynamic]f32{}
    waterVertices := [dynamic]f32{}
    blockIndices := [dynamic]u32{}
    waterIndices := [dynamic]u32{}

    for face in faces {
        // toFlip: bool
        normal: vec3
        switch face.direction {
            case .Up:     normal = { 0, 1, 0}
            case .Bottom: normal = { 0,-1, 0}
            case .North:  normal = { 0, 0, 1}
            case .South:  normal = { 0, 0,-1}
            case .East:   normal = { 1, 0, 0}
            case .West:   normal = {-1, 0, 0}
        }
        ppPos := face.corners[.TopLeft].pos
        pmPos := face.corners[.BottomLeft].pos
        mmPos := face.corners[.BottomRight].pos
        mpPos := face.corners[.TopRight].pos
        a00 := face.corners[.TopLeft].occlusion
        a01 := face.corners[.BottomLeft].occlusion
        a10 := face.corners[.BottomRight].occlusion
        a11 := face.corners[.TopRight].occlusion
        if face.textureID < 0 {
            offset: f32 = 0
            if face.direction == .Up {offset = 2.0 / 16}
            append(&waterVertices, ppPos.x, ppPos.y - offset, ppPos.z, normal.x, normal.y, normal.z)
            append(&waterVertices, pmPos.x, pmPos.y - offset, pmPos.z, normal.x, normal.y, normal.z)
            append(&waterVertices, mmPos.x, mmPos.y - offset, mmPos.z, normal.x, normal.y, normal.z)
            append(&waterVertices, mpPos.x, mpPos.y - offset, mpPos.z, normal.x, normal.y, normal.z)
            toFlip := toFlipe(a01, a00, a10, a11)
            n := u32(len(waterVertices)) / 6
            if toFlip {
                append(&waterIndices, n - 4, n - 3, n - 2, n - 2, n - 1, n - 4)
            } else {
                append(&waterIndices, n - 1, n - 4, n - 3, n - 3, n - 2, n - 1)
            }
        } else {
            append(&blockVertices,
                ppPos.x, ppPos.y, ppPos.z,
                normal.x, normal.y, normal.z, 0, 0,
                face.corners[.TopLeft].occlusion, face.textureID,
                face.corners[.TopLeft].light.x,
                face.corners[.TopLeft].light.y
            )
            append(&blockVertices,
                pmPos.x, pmPos.y, pmPos.z,
                normal.x, normal.y, normal.z, 0, 1,
                face.corners[.BottomLeft].occlusion, face.textureID, 
                face.corners[.BottomLeft].light.x,
                face.corners[.BottomLeft].light.y
            )
            append(&blockVertices,
                mmPos.x, mmPos.y, mmPos.z,
                normal.x, normal.y, normal.z, 1, 1,
                face.corners[.BottomRight].occlusion, face.textureID, 
                face.corners[.BottomRight].light.x,
                face.corners[.BottomRight].light.y
            )
            append(&blockVertices,
                mpPos.x, mpPos.y, mpPos.z,
                normal.x, normal.y, normal.z, 1, 0,
                face.corners[.TopRight].occlusion, face.textureID, 
                face.corners[.TopRight].light.x,
                face.corners[.TopRight].light.y
            )
            toFlip := toFlipe(a01, a00, a10, a11)
            n := u32(len(blockVertices)) / 12
            if toFlip {
                append(&blockIndices, n - 4, n - 3, n - 2, n - 2, n - 1, n - 4)
            } else {
                append(&blockIndices, n - 1, n - 4, n - 3, n - 3, n - 2, n - 1)
            }
        }
    }

    return {blockVertices, blockIndices, i32(len(blockIndices))}, {waterVertices, waterIndices, i32(len(waterIndices))}
}

generateMesh :: proc(chunk: ^world.Chunk) -> ChunkData {
    cubes := filterCubes(chunk)
    cubesFaces := makeCubes(chunk, cubes)
    delete(cubes)
    cubesPoints := makeCubePoints(cubesFaces)
    delete(cubesFaces)
    faces := makePoinsAndFaces(cubesPoints, chunk)
    delete(cubesPoints)
    blocks, water := makeVertices(faces)
    delete(faces)

    return {chunk.pos, blocks, water}
}
