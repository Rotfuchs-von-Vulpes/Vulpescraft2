package hud

import gl "vendor:OpenGL"
import stb "vendor:stb/image"
import math "core:math/linalg"
import glm "core:math/linalg/glsl"

import "../skeewb"
import "../util"

Direction :: enum {Up, Bottom, North, South, East, West}

Render :: struct{
	vao: u32,
	vbo: u32,
	uniforms: map[string]gl.Uniform_Info,
	program: u32,
	hotbarTexture: u32,
	slotTexture: u32,
	cross: u32,
}

BlockRender :: struct{
	vao: u32,
	vbo: u32,
	uniforms: map[string]gl.Uniform_Info,
	program: u32,
	blocks: u32,
}

render := Render{0, 0, {}, 0, 0, 0, 0}
blocksRender := BlockRender{0, 0, {}, 0, 0}

quadVertices := [?]f32{
	// positions   // texCoords
	-1.0,  1.0, 0.0, 0.0,
	-1.0, -1.0, 0.0, 1.0,
	 1.0, -1.0, 1.0, 1.0,

	 1.0, -1.0, 1.0, 1.0,
	 1.0,  1.0, 1.0, 0.0,
	-1.0,  1.0, 0.0, 0.0
}

cubeVertices := [?]f32{
	-1.0,  1.0,  1.0,  0.0,  1.0,  0.0, 0.0, 0.0,
	 1.0,  1.0,  1.0,  0.0,  1.0,  0.0, 1.0, 0.0,
	 1.0,  1.0, -1.0,  0.0,  1.0,  0.0, 1.0, 1.0,

	 1.0,  1.0, -1.0,  0.0,  1.0,  0.0, 1.0, 1.0,
	-1.0,  1.0, -1.0,  0.0,  1.0,  0.0, 0.0, 1.0,
	-1.0,  1.0,  1.0,  0.0,  1.0,  0.0, 0.0, 0.0,
	 
	 1.0, -1.0,  1.0,  1.0,  0.0,  0.0, 0.0, 1.0,
	 1.0, -1.0, -1.0,  1.0,  0.0,  0.0, 1.0, 1.0,
	 1.0,  1.0, -1.0,  1.0,  0.0,  0.0, 1.0, 0.0,

	 1.0,  1.0, -1.0,  1.0,  0.0,  0.0, 1.0, 0.0,
	 1.0,  1.0,  1.0,  1.0,  0.0,  0.0, 0.0, 0.0,
	 1.0, -1.0,  1.0,  1.0,  0.0,  0.0, 0.0, 1.0,
	 
    -1.0,  1.0,  1.0,  0.0,  0.0,  1.0, 0.0, 0.0,
    -1.0, -1.0,  1.0,  0.0,  0.0,  1.0, 0.0, 1.0,
	 1.0, -1.0,  1.0,  0.0,  0.0,  1.0, 1.0, 1.0,

	 1.0, -1.0,  1.0,  0.0,  0.0,  1.0, 1.0, 1.0,
	 1.0,  1.0,  1.0,  0.0,  0.0,  1.0, 1.0, 0.0,
	-1.0,  1.0,  1.0,  0.0,  0.0,  1.0, 0.0, 0.0,
}

vertShader :: #load("../assets/shaders/gui_vert.glsl", string)
fragShader :: #load("../assets/shaders/gui_frag.glsl", string)
vertShader2 :: #load("../assets/shaders/blockIcon_vert.glsl", string)
fragShader2 :: #load("../assets/shaders/blockIcon_frag.glsl", string)

slot :: #load("../assets/textures/slot.png", string)
hotbar :: #load("../assets/textures/hotbar.png", string)
cross :: #load("../assets/textures/cross.png", string)

proj := math.matrix_ortho3d_f32(-1.65, 1.65, -1.65, 1.65, -1.65, 1.65)
view := math.matrix4_look_at_f32({1, 1, 1}, {0, 0, 0}, {0, 1, 0})

setup :: proc() {
	gl.GenVertexArrays(1, &render.vao)
	gl.BindVertexArray(render.vao)

	gl.GenBuffers(1, &render.vbo)
    gl.BindBuffer(gl.ARRAY_BUFFER, render.vbo)
    gl.BufferData(gl.ARRAY_BUFFER, len(quadVertices)*size_of(quadVertices[0]), &quadVertices, gl.STATIC_DRAW)
	gl.EnableVertexAttribArray(0)
	gl.EnableVertexAttribArray(1)
	gl.VertexAttribPointer(0, 2, gl.FLOAT, false, 4 * size_of(quadVertices[0]), 0)
	gl.VertexAttribPointer(1, 2, gl.FLOAT, false, 4 * size_of(quadVertices[0]), 2 * size_of(quadVertices[0]))
	
	width, height, channels: i32
	pixels := stb.load_from_memory(raw_data(hotbar), i32(len(hotbar)), &width, &height, &channels, 4)
	gl.ActiveTexture(gl.TEXTURE0)
	gl.GenTextures(1, &render.hotbarTexture)
	gl.BindTexture(gl.TEXTURE_2D, render.hotbarTexture)
	gl.TexImage2D(gl.TEXTURE_2D, 0, gl.RGB16F, width, height, 0, gl.RGB, gl.UNSIGNED_BYTE, nil)
	gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.NEAREST)
	gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.NEAREST)
	gl.TexImage2D(gl.TEXTURE_2D, 0, gl.RGBA8, width, height, 0, gl.RGBA, gl.UNSIGNED_BYTE, pixels)

	pixels = stb.load_from_memory(raw_data(slot), i32(len(slot)), &width, &height, &channels, 4)
	gl.GenTextures(1, &render.slotTexture)
	gl.BindTexture(gl.TEXTURE_2D, render.slotTexture)
	gl.TexImage2D(gl.TEXTURE_2D, 0, gl.RGB16F, width, height, 0, gl.RGB, gl.UNSIGNED_BYTE, nil)
	gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.NEAREST)
	gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.NEAREST)
	gl.TexImage2D(gl.TEXTURE_2D, 0, gl.RGBA8, width, height, 0, gl.RGBA, gl.UNSIGNED_BYTE, pixels)

	pixels = stb.load_from_memory(raw_data(cross), i32(len(cross)), &width, &height, &channels, 4)
	gl.GenTextures(1, &render.cross)
	gl.BindTexture(gl.TEXTURE_2D, render.cross)
	gl.TexImage2D(gl.TEXTURE_2D, 0, gl.RGB16F, width, height, 0, gl.RGB, gl.UNSIGNED_BYTE, nil)
	gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.NEAREST)
	gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.NEAREST)
	gl.TexImage2D(gl.TEXTURE_2D, 0, gl.RGBA8, width, height, 0, gl.RGBA, gl.UNSIGNED_BYTE, pixels)

	gl.BindTexture(gl.TEXTURE_2D, 0)

	shaderSuccess: bool
	render.program, shaderSuccess = gl.load_shaders_source(vertShader, fragShader)

    if !shaderSuccess {
        info: [^]u8
        gl.GetShaderInfoLog(render.program, 1024, nil, info)
        a, b, c, d := gl.get_last_error_messages()
        skeewb.console_log(.ERROR, "could not compile sky shaders\n %s\n %s", a, c)
		panic("")
    }
	
	render.uniforms = gl.get_uniforms_from_program(render.program)

	gl.GenVertexArrays(1, &blocksRender.vao)
	gl.BindVertexArray(blocksRender.vao)

	gl.GenBuffers(1, &blocksRender.vbo)
    gl.BindBuffer(gl.ARRAY_BUFFER, blocksRender.vbo)
    gl.BufferData(gl.ARRAY_BUFFER, len(cubeVertices)*size_of(cubeVertices[0]), &cubeVertices, gl.STATIC_DRAW)
	gl.EnableVertexAttribArray(0)
	gl.EnableVertexAttribArray(1)
	gl.EnableVertexAttribArray(2)
	gl.VertexAttribPointer(0, 3, gl.FLOAT, false, 8 * size_of(cubeVertices[0]), 0)
	gl.VertexAttribPointer(1, 3, gl.FLOAT, false, 8 * size_of(cubeVertices[0]), 3 * size_of(cubeVertices[0]))
	gl.VertexAttribPointer(2, 2, gl.FLOAT, false, 8 * size_of(cubeVertices[0]), 6 * size_of(cubeVertices[0]))

	blocksRender.program, shaderSuccess = gl.load_shaders_source(vertShader2, fragShader2)

    if !shaderSuccess {
        info: [^]u8
        gl.GetShaderInfoLog(blocksRender.program, 1024, nil, info)
        a, b, c, d := gl.get_last_error_messages()
        skeewb.console_log(.ERROR, "could not compile sky shaders\n %s\n %s", a, c)
		panic("")
    }
	
	blocksRender.uniforms = gl.get_uniforms_from_program(blocksRender.program)
}

getTextureID :: proc(dir: Direction, id: int) -> f32 {
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

draw :: proc(width, height: i32, index: int, frameTexture, blocksTextures: u32) {
	gl.UseProgram(render.program)
	gl.BindVertexArray(render.vao)
	gl.Uniform1i(render.uniforms["isCross"].location, 0)
	gl.Uniform1i(render.uniforms["guiTexture"].location, 0)
	gl.Uniform1i(render.uniforms["fboTexture"].location, 1)
	gl.ActiveTexture(gl.TEXTURE1)
	gl.BindTexture(gl.TEXTURE_2D, frameTexture)

	gl.ActiveTexture(gl.TEXTURE0)
	gl.Uniform1f(render.uniforms["xOffset"].location, 0)
	gl.Uniform1f(render.uniforms["yOffset"].location, f32(height - 44) / f32(height))
	gl.Uniform1f(render.uniforms["width"].location, 364 / f32(width))
	gl.Uniform1f(render.uniforms["height"].location, 44 / f32(height))
	gl.BindTexture(gl.TEXTURE_2D, render.hotbarTexture)
	gl.DrawArrays(gl.TRIANGLES, 0, 6)

	gl.Uniform1f(render.uniforms["xOffset"].location, (f32(index) - 4) * 80 / f32(width))
	gl.Uniform1f(render.uniforms["yOffset"].location, f32(height - 44) / f32(height))
	gl.Uniform1f(render.uniforms["width"].location, 48 / f32(width))
	gl.Uniform1f(render.uniforms["height"].location, 48 / f32(height))
	gl.BindTexture(gl.TEXTURE_2D, render.slotTexture)
	gl.DrawArrays(gl.TRIANGLES, 0, 6)

	gl.Uniform1i(render.uniforms["isCross"].location, 1)
	gl.Uniform1f(render.uniforms["xOffset"].location, 0)
	gl.Uniform1f(render.uniforms["yOffset"].location, 0)
	gl.Uniform1f(render.uniforms["width"].location, 18 / f32(width))
	gl.Uniform1f(render.uniforms["height"].location, 18 / f32(height))
	gl.BindTexture(gl.TEXTURE_2D, render.cross)
	gl.DrawArrays(gl.TRIANGLES, 0, 6)

	model := math.MATRIX4F32_IDENTITY
	gl.UseProgram(blocksRender.program)
	gl.BindVertexArray(blocksRender.vao)
	gl.ActiveTexture(gl.TEXTURE0)
	gl.BindTexture(gl.TEXTURE_2D_ARRAY, blocksTextures)
	for i in 0..<9 {
		gl.Uniform1f(blocksRender.uniforms["textureIDTop"].location, getTextureID(.Up, i + 1))
		gl.Uniform1f(blocksRender.uniforms["textureIDSide1"].location, getTextureID(.North, i + 1))
		gl.Uniform1f(blocksRender.uniforms["textureIDSide2"].location, getTextureID(.West, i + 1))
		gl.UniformMatrix4fv(blocksRender.uniforms["projection"].location, 1, false, &proj[0, 0])
		gl.UniformMatrix4fv(blocksRender.uniforms["view"].location, 1, false, &view[0, 0])
		gl.UniformMatrix4fv(blocksRender.uniforms["model"].location, 1, false, &model[0, 0])
		gl.Uniform1f(blocksRender.uniforms["xOffset"].location, (f32(8 - i) - 4) * 80 / f32(width))
		gl.Uniform1f(blocksRender.uniforms["yOffset"].location, f32(height - 44) / f32(height))
		gl.Uniform1f(blocksRender.uniforms["width"].location, 30 / f32(width))
		gl.Uniform1f(blocksRender.uniforms["height"].location, 30 / f32(height))
		gl.DrawArrays(gl.TRIANGLES, 0, 18)
	}
}

nuke :: proc() {
	for key, value in render.uniforms {
		delete(value.name)
	}
	delete(render.uniforms)
	gl.DeleteProgram(render.program)

	for key, value in blocksRender.uniforms {
		delete(value.name)
	}
	delete(blocksRender.uniforms)
	gl.DeleteProgram(blocksRender.program)
}
