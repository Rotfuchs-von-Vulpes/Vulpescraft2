package FXAA

import gl "vendor:OpenGL"

import "../../effects"
import "../../skeewb"
import "../../util"

vertShader :: #load("../../assets/shaders/quad_vert.glsl", string)
fragShader :: #load("../../assets/shaders/anti_alising_frag.glsl", string)
fxaaShader :: #load("../../assets/shaders/util/fxaa.glsl", string)

Render :: struct {
    program: u32,
    vbo: u32,
    vao: u32,
	uniforms: map[string]gl.Uniform_Info,
    inputColorBuffer: effects.Buffer,
    FXAAColorBuffer: effects.Buffer,
}

render: Render

setup :: proc () {
	temp := util.include(fragShader, {fxaaShader})
	defer delete(temp)
    shaderSuccess: bool
	render.program, shaderSuccess = gl.load_shaders_source(vertShader, temp)

    if !shaderSuccess {
        info: [^]u8
        gl.GetShaderInfoLog(render.program, 1024, nil, info)
        a, b, c, d := gl.get_last_error_messages()
        skeewb.console_log(.ERROR, "could not compile blur fbo shaders\n %s\n %s", a, c)
		panic("")
    }

	effects.setBuffers(&render.vbo, &render.vao)
	
	render.uniforms = gl.get_uniforms_from_program(render.program)
}

set :: proc (input, antiAlising: effects.Buffer) {
    render.inputColorBuffer = input
    render.FXAAColorBuffer = antiAlising
}

draw :: proc () {
	gl.UseProgram(render.program)

	gl.BindVertexArray(render.vao)
	gl.DrawBuffers(1, raw_data([]u32{render.FXAAColorBuffer.attachment}))
	gl.ActiveTexture(gl.TEXTURE0)
	gl.BindTexture(gl.TEXTURE_2D, render.inputColorBuffer.texture)
	gl.DrawArrays(gl.TRIANGLES, 0, 6)
}

nuke :: proc () {
	for key, value in render.uniforms {
		delete(value.name)
	}
	delete(render.uniforms)
	gl.DeleteProgram(render.program)
}
