package hud

import gl "vendor:OpenGL"
import stb "vendor:stb/image"

import "../skeewb"
import "../util"

Render :: struct{
	vao: u32,
	vbo: u32,
	uniforms: map[string]gl.Uniform_Info,
	program: u32,
	hotbarTexture: u32,
	slotTexture: u32,
}

render: Render = {0, 0, {}, 0, 0, 0}

quadVertices := [?]f32{
	// positions   // texCoords
	-1.0,  1.0,  0.0, 0.0,
	-1.0, -1.0,  0.0, 1.0,
	 1.0, -1.0,  1.0, 1.0,

	 1.0, -1.0,  1.0, 1.0,
	 1.0,  1.0,  1.0, 0.0,
	-1.0,  1.0,  0.0, 0.0
}

vertShader :: #load("../assets/shaders/gui_vert.glsl", string)
fragShader :: #load("../assets/shaders/gui_frag.glsl", string)

slot :: #load("../assets/textures/slot.png", string)
hotbar :: #load("../assets/textures/hotbar.png", string)

setup :: proc() {
	gl.GenVertexArrays(1, &render.vao)
	gl.BindVertexArray(render.vao)

	gl.GenBuffers(1, &render.vbo)
    gl.BindBuffer(gl.ARRAY_BUFFER, render.vbo)
    gl.BufferData(gl.ARRAY_BUFFER, len(quadVertices)*size_of(quadVertices[0]), &quadVertices, gl.STATIC_DRAW)
	gl.EnableVertexAttribArray(0)
	gl.VertexAttribPointer(0, 2, gl.FLOAT, false, 4 * size_of(quadVertices[0]), 0)
	gl.EnableVertexAttribArray(1)
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
	// gl.ActiveTexture(gl.TEXTURE1)
	gl.GenTextures(1, &render.slotTexture)
	gl.BindTexture(gl.TEXTURE_2D, render.slotTexture)
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
    }
	
	render.uniforms = gl.get_uniforms_from_program(render.program)
}

draw :: proc(width, height: i32, index: int) {
	gl.UseProgram(render.program)
	gl.BindVertexArray(render.vao)
	gl.ActiveTexture(gl.TEXTURE0)

	gl.Uniform1f(render.uniforms["width"].location, 364 / f32(width))
	gl.Uniform1f(render.uniforms["height"].location, 44 / f32(height))
	gl.Uniform1f(render.uniforms["xOffset"].location, 0)
	gl.Uniform1f(render.uniforms["yOffset"].location, f32(height - 44) / f32(height))
	gl.BindTexture(gl.TEXTURE_2D, render.hotbarTexture)
	gl.DrawArrays(gl.TRIANGLES, 0, 6)

	gl.Uniform1f(render.uniforms["width"].location, 48 / f32(width))
	gl.Uniform1f(render.uniforms["height"].location, 48 / f32(height))
	gl.Uniform1f(render.uniforms["xOffset"].location, (f32(index) - 4) * 80 / f32(width))
	gl.Uniform1f(render.uniforms["yOffset"].location, f32(height - 44) / f32(height))
	gl.BindTexture(gl.TEXTURE_2D, render.slotTexture)
	gl.DrawArrays(gl.TRIANGLES, 0, 6)
}

nuke :: proc() {
	for key, value in render.uniforms {
		delete(value.name)
	}
	delete(render.uniforms)
	gl.DeleteProgram(render.program)
}
