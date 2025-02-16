package color

import gl "vendor:OpenGL"

import "../../effects"
import "../../skeewb"
import "../../util"

vertShader :: #load("../../assets/shaders/quad_vert.glsl", string)
fragShader :: #load("../../assets/shaders/quad_frag.glsl", string)

Render :: struct {
    program: u32,
    vbo: u32,
    vao: u32,
	uniforms: map[string]gl.Uniform_Info,
    inputColorBuffer: effects.Buffer,
    finalColorBuffer: effects.Buffer,
}

render: Render

setup :: proc () {
    shaderSuccess: bool
	render.program, shaderSuccess = gl.load_shaders_source(vertShader, fragShader)

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

set :: proc (input, output: effects.Buffer) {
    render.inputColorBuffer = input
    render.finalColorBuffer = output
}

draw :: proc () {
	gl.UseProgram(render.program)

	gl.Disable(gl.DEPTH_TEST)
	gl.Disable(gl.BLEND)

	gl.BindVertexArray(render.vao)
	gl.ActiveTexture(gl.TEXTURE0)
	gl.BindTexture(gl.TEXTURE_2D, render.inputColorBuffer.texture)
	
	gl.DrawBuffers(1, raw_data([]u32{render.finalColorBuffer.attachment}))
	gl.Clear(gl.COLOR_BUFFER_BIT)
	gl.DrawArrays(gl.TRIANGLES, 0, 6)
}

nuke :: proc () {
	for key, value in render.uniforms {
		delete(value.name)
	}
	delete(render.uniforms)
	gl.DeleteProgram(render.program)
}
