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

blockVertShader :: #load("../assets/shaders/blocks_vert.glsl", string)
blockFragShader :: #load("../assets/shaders/blocks_frag.glsl", string)
lighting :: #load("../assets/shaders/util/lighting.glsl", string)

madera :: #load("../assets/textures/box.png", string)
preda :: #load("../assets/textures/stone.png", string)
terra :: #load("../assets/textures/dirt.png", string)
teratu :: #load("../assets/textures/dirt_with_grass.png", string)
matu :: #load("../assets/textures/grass.png", string)
area :: #load("../assets/textures/sand.png", string)
foia :: #load("../assets/textures/leaves.png", string)
arvre :: #load("../assets/textures/tree.png", string)
arvre2 :: #load("../assets/textures/tree_top.png", string)
pread :: #load("../assets/textures/cobble.png", string)
glow :: #load("../assets/textures/glowstone.png", string)

setupBlockDrawing :: proc(render: ^Render) {
	shaderSuccess: bool
	temp := util.include(blockFragShader, {lighting})
	defer delete(temp)
	render.program, shaderSuccess = gl.load_shaders_source(blockVertShader, temp)

    if !shaderSuccess {
        info: [^]u8
        gl.GetShaderInfoLog(render.program, 1024, nil, info)
        a, b, c, d := gl.get_last_error_messages()
        skeewb.console_log(.ERROR, "could not compile blocks shaders\n %s\n %s", a, c)
		panic("")
    }

	gl.GenTextures(1, &render.texture)
	gl.BindTexture(gl.TEXTURE_2D_ARRAY, render.texture)
	gl.TexParameteri(gl.TEXTURE_2D_ARRAY, gl.TEXTURE_WRAP_S, gl.REPEAT)
	gl.TexParameteri(gl.TEXTURE_2D_ARRAY, gl.TEXTURE_WRAP_T, gl.REPEAT)
	gl.TexParameteri(gl.TEXTURE_2D_ARRAY, gl.TEXTURE_MIN_FILTER, gl.LINEAR_MIPMAP_LINEAR)
	gl.TexParameteri(gl.TEXTURE_2D_ARRAY, gl.TEXTURE_MAG_FILTER, gl.NEAREST)

	width, height, channels: i32
	datas := []string{
		madera,
		preda,
		terra,
		teratu,
		matu,
		area,
		foia,
		arvre,
		arvre2,
		pread,
		glow,
	}
	gl.TexImage3D(gl.TEXTURE_2D_ARRAY, 0, gl.SRGB8_ALPHA8, 16, 16, i32(len(datas)), 0, gl.RGBA, gl.UNSIGNED_BYTE, nil)
	for tex, idx in datas {
		pixels := stb.load_from_memory(raw_data(tex), i32(len(tex)), &width, &height, &channels, 4)
		gl.TexSubImage3D(gl.TEXTURE_2D_ARRAY, 0, 0, 0, i32(idx), 16, 16, 1, gl.RGBA, gl.UNSIGNED_BYTE, pixels)
		stb.image_free(pixels)
	}
	gl.GenerateMipmap(gl.TEXTURE_2D_ARRAY)
	if sdl2.GL_ExtensionSupported("GL_EXT_texture_filter_anisotropic") {
		filter: f32
		gl.GetFloatv(gl.MAX_TEXTURE_MAX_ANISOTROPY, &filter)
		gl.TexParameterf(gl.TEXTURE_2D_ARRAY, gl.TEXTURE_MAX_ANISOTROPY, filter)
	}
	render.uniforms = gl.get_uniforms_from_program(render.program)
}

setupBlocks :: proc(data: mesh.ChunkData) -> Buffers {
    VAO, VBO, EBO: u32
    
	gl.GenVertexArrays(1, &VAO)
	gl.BindVertexArray(VAO)

	gl.GenBuffers(1, &VBO)
    gl.BindBuffer(gl.ARRAY_BUFFER, VBO)
    gl.BufferData(gl.ARRAY_BUFFER, len(data.blocks.vertices)*size_of(data.blocks.vertices[0]), raw_data(data.blocks.vertices), gl.STATIC_DRAW)
	
	gl.GenBuffers(1, &EBO)
	gl.BindBuffer(gl.ELEMENT_ARRAY_BUFFER, EBO)
	gl.BufferData(gl.ELEMENT_ARRAY_BUFFER, len(data.blocks.indices)*size_of(data.blocks.indices[0]), raw_data(data.blocks.indices), gl.STATIC_DRAW)

	gl.EnableVertexAttribArray(0)
	gl.EnableVertexAttribArray(1)
	gl.EnableVertexAttribArray(2)
	gl.EnableVertexAttribArray(3)
	gl.EnableVertexAttribArray(4)
	gl.EnableVertexAttribArray(5)
	gl.VertexAttribPointer(0, 3, gl.FLOAT, false, 12 * size_of(f32), 0)
	gl.VertexAttribPointer(1, 3, gl.FLOAT, false, 12 * size_of(f32), 3 * size_of(f32))
	gl.VertexAttribPointer(2, 2, gl.FLOAT, false, 12 * size_of(f32), 6 * size_of(f32))
	gl.VertexAttribPointer(3, 1, gl.FLOAT, false, 12 * size_of(f32), 8 * size_of(f32))
	gl.VertexAttribPointer(4, 1, gl.FLOAT, false, 12 * size_of(f32), 9 * size_of(f32))
	gl.VertexAttribPointer(5, 2, gl.FLOAT, false, 12 * size_of(f32), 10 * size_of(f32))

	return {VAO, VBO, EBO}
}

drawBlocks :: proc(chunks: [dynamic]ChunkBuffer, camera: ^util.Camera, render: Render) {
	gl.DrawBuffers(2, raw_data([]u32{gl.COLOR_ATTACHMENT0, gl.COLOR_ATTACHMENT2}))
	gl.UseProgram(render.program)
	gl.UniformMatrix4fv(render.uniforms["projection"].location, 1, false, &camera.proj[0, 0])
	gl.UniformMatrix4fv(render.uniforms["view"].location, 1, false, &camera.view[0, 0])
	gl.Uniform3f(render.uniforms["sunDirection"].location, sky.sunDirection.x, sky.sunDirection.y, sky.sunDirection.z)
	gl.Uniform3f(render.uniforms["skyColor"].location, sky.skyColor.r, sky.skyColor.g, sky.skyColor.b)
	gl.Uniform3f(render.uniforms["fogColor"].location, sky.fogColor.r, sky.fogColor.g, sky.fogColor.b)
	for chunk in chunks {
		pos := vec3{f32(chunk.pos.x) * 16 - camera.pos.x, f32(chunk.pos.y) * 16 - camera.pos.y, f32(chunk.pos.z) * 16 - camera.pos.z}
		model := math.matrix4_translate_f32(pos)
		gl.UniformMatrix4fv(render.uniforms["model"].location, 1, false, &model[0, 0])

		gl.BindVertexArray(chunk.blockBuffer.VAO)
		gl.DrawElements(gl.TRIANGLES, chunk.data.blocks.length, gl.UNSIGNED_INT, nil)
	}
}