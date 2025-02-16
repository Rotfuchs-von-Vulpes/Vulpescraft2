package blur

import gl "vendor:OpenGL"

import "../../effects"
import "../../skeewb"

vertShader :: #load("../../assets/shaders/quadBlur_vert.glsl", string)
fragShader :: #load("../../assets/shaders/quadBlur_frag.glsl", string)

Render :: struct {
    program: u32,
	vao: u32,
	vbo: u32,
	uniforms: map[string]gl.Uniform_Info,
	inputTexture: effects.Buffer,
    blurTexture: effects.Buffer,
    auxiliarTexture: effects.Buffer,
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

set :: proc (inputTexture, auxiliarTexture, blurTexture: effects.Buffer) {
    render.inputTexture = inputTexture
    render.auxiliarTexture = auxiliarTexture
    render.blurTexture = blurTexture
}

draw :: proc () {
	gl.UseProgram(render.program)
	
	gl.BindVertexArray(render.vao)
	gl.Disable(gl.DEPTH_TEST)
	gl.ActiveTexture(gl.TEXTURE0)
	gl.BindTexture(gl.TEXTURE_2D, render.inputTexture.texture)
	gl.Uniform1i(render.uniforms["axis"].location, 0)
	gl.DrawBuffers(1, raw_data([]u32{render.auxiliarTexture.attachment}))
	gl.DrawArrays(gl.TRIANGLES, 0, 6)
	gl.BindTexture(gl.TEXTURE_2D, render.auxiliarTexture.texture)
	gl.DrawBuffers(1, raw_data([]u32{render.blurTexture.attachment}))
	gl.Uniform1i(render.uniforms["axis"].location, 1)
	gl.DrawArrays(gl.TRIANGLES, 0, 6)
	gl.Enable(gl.DEPTH_TEST)
}

nuke :: proc () {
	for key, value in render.uniforms {
		delete(value.name)
	}
	delete(render.uniforms)
	gl.DeleteProgram(render.program)
}