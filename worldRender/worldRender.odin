package worldRender

import gl "vendor:OpenGL"
import "vendor:sdl2"
import stb "vendor:stb/image"
import "core:strings"
import glm "core:math/linalg/glsl"
import math "core:math/linalg"

import "../skeewb"
import "../world"
import "../util"
import "../sky"
import mesh "meshGenerator"

iVec3 :: [3]i32
ivec2 :: [2]u32

mat4 :: glm.mat4x4
vec2 :: [2]f32
vec3 :: [3]f32
vec4 :: [4]f32

Buffers :: struct{
	VAO, VBO, EBO: u32,
}

ChunkBuffer :: struct{
    x, y, z: i32,
	faceSet: mesh.FaceSet,
	data: mesh.ChunkData,
	blockBuffer: Buffers,
	waterBuffer: Buffers,
}

Render :: struct{
	uniforms: map[string]gl.Uniform_Info,
	program: u32,
	texture: u32,
}

chunkMap := make(map[iVec3]ChunkBuffer)

setupChunk :: proc(chunk: ^world.Chunk) -> ChunkBuffer {
    data := mesh.generateMesh(chunk)
	defer delete(data.blocks.indices)
	defer delete(data.blocks.vertices)
	defer delete(data.water.indices)
	defer delete(data.water.vertices)

	blocksBuffer := setupBlocks(data)
	waterBuffer := setupWater(data)

    return ChunkBuffer{chunk.pos.x, chunk.pos.y, chunk.pos.z, {}, data, blocksBuffer, waterBuffer}
}

eval :: proc(chunk: ^world.Chunk) -> ChunkBuffer {
    pos := iVec3{chunk.pos.x, chunk.pos.y, chunk.pos.z}
    chunkBuffer, ok, _ := util.map_force_get(&chunkMap, pos)
    if ok {
        chunkBuffer^ = setupChunk(chunk)
    }
    return chunkBuffer^
}

setupManyChunks :: proc(chunks: [dynamic]^world.Chunk) -> [dynamic]ChunkBuffer {
    chunksBuffers: [dynamic]ChunkBuffer

    for _, idx in chunks {
        append(&chunksBuffers, eval(chunks[idx]))
    }

    return chunksBuffers;
}

testAabb :: proc(MPV: mat4, min, max: vec3) -> bool
{
	nxX := MPV[0][3] + MPV[0][0]; nxY := MPV[1][3] + MPV[1][0]; nxZ := MPV[2][3] + MPV[2][0]; nxW := MPV[3][3] + MPV[3][0]
	pxX := MPV[0][3] - MPV[0][0]; pxY := MPV[1][3] - MPV[1][0]; pxZ := MPV[2][3] - MPV[2][0]; pxW := MPV[3][3] - MPV[3][0]
	nyX := MPV[0][3] + MPV[0][1]; nyY := MPV[1][3] + MPV[1][1]; nyZ := MPV[2][3] + MPV[2][1]; nyW := MPV[3][3] + MPV[3][1]
	pyX := MPV[0][3] - MPV[0][1]; pyY := MPV[1][3] - MPV[1][1]; pyZ := MPV[2][3] - MPV[2][1]; pyW := MPV[3][3] - MPV[3][1]
	nzX := MPV[0][3] + MPV[0][2]; nzY := MPV[1][3] + MPV[1][2]; nzZ := MPV[2][3] + MPV[2][2]; nzW := MPV[3][3] + MPV[3][2]
	pzX := MPV[0][3] - MPV[0][2]; pzY := MPV[1][3] - MPV[1][2]; pzZ := MPV[2][3] - MPV[2][2]; pzW := MPV[3][3] - MPV[3][2]
	
	return nxX * (nxX < 0 ? min[0] : max[0]) + nxY * (nxY < 0 ? min[1] : max[1]) + nxZ * (nxZ < 0 ? min[2] : max[2]) >= -nxW &&
		pxX * (pxX < 0 ? min[0] : max[0]) + pxY * (pxY < 0 ? min[1] : max[1]) + pxZ * (pxZ < 0 ? min[2] : max[2]) >= -pxW &&
		nyX * (nyX < 0 ? min[0] : max[0]) + nyY * (nyY < 0 ? min[1] : max[1]) + nyZ * (nyZ < 0 ? min[2] : max[2]) >= -nyW &&
		pyX * (pyX < 0 ? min[0] : max[0]) + pyY * (pyY < 0 ? min[1] : max[1]) + pyZ * (pyZ < 0 ? min[2] : max[2]) >= -pyW &&
		nzX * (nzX < 0 ? min[0] : max[0]) + nzY * (nzY < 0 ? min[1] : max[1]) + nzZ * (nzZ < 0 ? min[2] : max[2]) >= -nzW &&
		pzX * (pzX < 0 ? min[0] : max[0]) + pzY * (pzY < 0 ? min[1] : max[1]) + pzZ * (pzZ < 0 ? min[2] : max[2]) >= -pzW;
}

frustumMove :: proc(chunks: ^[dynamic]ChunkBuffer, camera: ^util.Camera) {
	for &chunk in chunks {
		faces: mesh.FaceSet = {}

		if chunk.x <= camera.chunk.x {faces = faces + {.East}}
		if chunk.x >= camera.chunk.x {faces = faces + {.West}}
		if chunk.y <= camera.chunk.y {faces = faces + {.Up}}
		if chunk.y >= camera.chunk.y {faces = faces + {.Bottom}}
		if chunk.z <= camera.chunk.z {faces = faces + {.North}}
		if chunk.z >= camera.chunk.z {faces = faces + {.South}}

		chunk.faceSet = faces
	}
}

frustumCulling :: proc(chunks: [dynamic]ChunkBuffer, camera: ^util.Camera) -> [dynamic]ChunkBuffer {
	chunksBuffers: [dynamic]ChunkBuffer = {}

	PV := camera.proj * camera.view
	for chunk in chunks {
		minC := 16 * vec3{f32(chunk.x), f32(chunk.y), f32(chunk.z)} - camera.pos
		maxC := minC + vec3{16, 16, 16}
		
		if testAabb(PV, minC, maxC) {append(&chunksBuffers, chunk)}
	}

	return chunksBuffers
}

nuke :: proc() {
	for pos, &chunk in chunkMap {
		gl.DeleteBuffers(1, &chunk.blockBuffer.VBO)
		gl.DeleteBuffers(1, &chunk.blockBuffer.EBO)
		gl.DeleteBuffers(1, &chunk.waterBuffer.VBO)
		gl.DeleteBuffers(1, &chunk.waterBuffer.EBO)
	}
    delete(chunkMap)
}

destroy :: proc(chunks: [dynamic]^world.Chunk) {
	for chunk in chunks {
		delete_key(&chunkMap, iVec3{chunk.pos.x, chunk.pos.y, chunk.pos.z})
	}
}