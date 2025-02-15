package effects

import gl "vendor:OpenGL"
import math "core:math/linalg"
import glm "core:math/linalg/glsl"

import "../../skeewb"

vertShader :: #load("../../assets/shaders/quadBlur_vert.glsl", string)
fragShader :: #load("../../assets/shaders/quadBlur_frag.glsl", string)

Render :: struct {
    program: u32,
	uniforms: map[string]gl.Uniform_Info,
	inputTexture: Buffer,
    blurTexture: Buffer,
    auxiliarTexture: Buffer,
}

render: Render

setupBlur :: proc (inputTexture, auxiliarTexture, blurTexture: Buffer) {
    render.inputTexture = inputTexture
    render.auxiliarTexture = auxiliarTexture
    render.blurTexture = blurTexture

    shaderSuccess: bool
	render.program, shaderSuccess = gl.load_shaders_source(vertShader, fragShader)

    if !shaderSuccess {
        info: [^]u8
        gl.GetShaderInfoLog(render.program, 1024, nil, info)
        a, b, c, d := gl.get_last_error_messages()
        skeewb.console_log(.ERROR, "could not compile blur fbo shaders\n %s\n %s", a, c)
		panic("")
    }
	
	render.uniforms = gl.get_uniforms_from_program(render.program)
}

drawBlur :: proc () {
	gl.UseProgram(render.program)
	
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