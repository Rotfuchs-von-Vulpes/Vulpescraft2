package frameBuffer

import gl "vendor:OpenGL"
import math "core:math/linalg"
import glm "core:math/linalg/glsl"

import "../skeewb"
import "../util"
import "../sky"

import "/effects"

Buffer :: effects.Buffer

mat4 :: glm.mat4x4
vec2 :: [2]f32
vec3 :: [3]f32
vec4 :: [4]f32

Render :: struct {
	id: u32,
	vao: u32,
	vbo: u32,
	uniforms: map[string]gl.Uniform_Info,
	program: u32,
	colorBuffer: Buffer,
	auxiliarColorBuffer: Buffer,
	blurColorBuffer: Buffer,
	depthBuffer: Buffer,
	auxiliarDepth: Buffer,
	auxiliarProgram: u32,
	auxiliarUniforms: map[string]gl.Uniform_Info,
	blurProgram: u32,
	blurUniforms: map[string]gl.Uniform_Info,
	AAProgram: u32,
	AAUniforms: map[string]gl.Uniform_Info,
}

render: Render

quadVertices := [?]f32{
	// positions   // texCoords
	-1.0,  1.0,  0.0, 1.0,
	-1.0, -1.0,  0.0, 0.0,
	 1.0, -1.0,  1.0, 0.0,

	-1.0,  1.0,  0.0, 1.0,
	 1.0, -1.0,  1.0, 0.0,
	 1.0,  1.0,  1.0, 1.0
}

vertShader :: #load("../assets/shaders/quad_vert.glsl", string)
fragShader :: #load("../assets/shaders/quad_frag.glsl", string)
fragShader2 :: #load("../assets/shaders/quad_frag_2.glsl", string)
AAShader :: #load("../assets/shaders/anti_alising_frag.glsl", string)
vertBlurShader :: #load("../assets/shaders/quadBlur_vert.glsl", string)
fragBlurShader :: #load("../assets/shaders/quadBlur_frag.glsl", string)
fxaaShader :: #load("../assets/shaders/util/fxaa.glsl", string)

setup :: proc (camera: ^util.Camera) {
	render = Render{0, 0, 0, {}, 0, {0, 0}, {0, 0}, {0, 0}, {0, 0}, {0, 0}, 0, {}, 0, {}, 0, {}}

    gl.GenFramebuffers(1, &render.id)
	gl.BindFramebuffer(gl.FRAMEBUFFER, render.id)

	gl.ActiveTexture(gl.TEXTURE0)
	gl.GenTextures(1, &render.colorBuffer.texture)
	gl.BindTexture(gl.TEXTURE_2D, render.colorBuffer.texture)
	gl.TexImage2D(gl.TEXTURE_2D, 0, gl.RGB16F, i32(camera.viewPort.x), i32(camera.viewPort.y), 0, gl.RGB, gl.UNSIGNED_BYTE, nil)
	gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.LINEAR)
	gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.LINEAR)
	gl.BindTexture(gl.TEXTURE_2D, 0)
	render.colorBuffer.attachment = gl.COLOR_ATTACHMENT0
	gl.FramebufferTexture2D(gl.FRAMEBUFFER, gl.COLOR_ATTACHMENT0, gl.TEXTURE_2D, render.colorBuffer.texture, 0)
	
	gl.ActiveTexture(gl.TEXTURE1)
	gl.GenTextures(1, &render.depthBuffer.texture)
	gl.BindTexture(gl.TEXTURE_2D, render.depthBuffer.texture)
	gl.TexImage2D(gl.TEXTURE_2D, 0, gl.DEPTH_COMPONENT32, i32(camera.viewPort.x), i32(camera.viewPort.y), 0, gl.DEPTH_COMPONENT, gl.UNSIGNED_INT, nil)
	gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, gl.CLAMP_TO_BORDER)
	gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.CLAMP_TO_BORDER)
	gl.TexParameterfv(gl.TEXTURE_2D, gl.TEXTURE_BORDER_COLOR, raw_data([]f32{1, 1, 1, 1}))
	gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.LINEAR)
	gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.LINEAR)
	gl.BindTexture(gl.TEXTURE_2D, 0)
	render.depthBuffer.attachment = gl.DEPTH_ATTACHMENT
	gl.FramebufferTexture(gl.FRAMEBUFFER, gl.DEPTH_ATTACHMENT, render.depthBuffer.texture, 0)

	gl.ActiveTexture(gl.TEXTURE2)
	gl.GenTextures(1, &render.blurColorBuffer.texture)
	gl.BindTexture(gl.TEXTURE_2D, render.blurColorBuffer.texture)
	gl.TexImage2D(gl.TEXTURE_2D, 0, gl.RGB16F, i32(camera.viewPort.x), i32(camera.viewPort.y), 0, gl.RGB, gl.UNSIGNED_BYTE, nil)
	gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.LINEAR)
	gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.LINEAR)
	gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, gl.CLAMP_TO_EDGE);
	gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.CLAMP_TO_EDGE);
	gl.BindTexture(gl.TEXTURE_2D, 0)
	render.blurColorBuffer.attachment = gl.COLOR_ATTACHMENT1
	gl.FramebufferTexture2D(gl.FRAMEBUFFER, gl.COLOR_ATTACHMENT1, gl.TEXTURE_2D, render.blurColorBuffer.texture, 0)

	gl.ActiveTexture(gl.TEXTURE3)
	gl.GenTextures(1, &render.auxiliarDepth.texture)
	gl.BindTexture(gl.TEXTURE_2D, render.auxiliarDepth.texture)
	gl.TexImage2D(gl.TEXTURE_2D, 0, gl.R32F, i32(camera.viewPort.x), i32(camera.viewPort.y), 0, gl.RED, gl.FLOAT, nil)
	gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.LINEAR)
	gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.LINEAR)
	gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, gl.CLAMP_TO_EDGE);
	gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.CLAMP_TO_EDGE);
	gl.BindTexture(gl.TEXTURE_2D, 0)
	render.auxiliarDepth.attachment = gl.COLOR_ATTACHMENT2
	gl.FramebufferTexture2D(gl.FRAMEBUFFER, gl.COLOR_ATTACHMENT2, gl.TEXTURE_2D, render.auxiliarDepth.texture, 0)

	gl.ActiveTexture(gl.TEXTURE4)
	gl.GenTextures(1, &render.auxiliarColorBuffer.texture)
	gl.BindTexture(gl.TEXTURE_2D, render.auxiliarColorBuffer.texture)
	gl.TexImage2D(gl.TEXTURE_2D, 0, gl.RGBA16F, i32(camera.viewPort.x), i32(camera.viewPort.y), 0, gl.RGBA, gl.UNSIGNED_BYTE, nil)
	gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.LINEAR)
	gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.LINEAR)
	gl.BindTexture(gl.TEXTURE_2D, 0)
	render.auxiliarColorBuffer.attachment = gl.COLOR_ATTACHMENT3
	gl.FramebufferTexture2D(gl.FRAMEBUFFER, gl.COLOR_ATTACHMENT3, gl.TEXTURE_2D, render.auxiliarColorBuffer.texture, 0)

	if gl.CheckFramebufferStatus(gl.FRAMEBUFFER) != u32(gl.FRAMEBUFFER_COMPLETE) {
		skeewb.console_log(.ERROR, "Framebuffer is not complete!")
	}

	gl.GenVertexArrays(1, &render.vao)
	gl.GenBuffers(1, &render.vbo)
	gl.BindVertexArray(render.vao)
	gl.BindBuffer(gl.ARRAY_BUFFER, render.vbo)
	gl.BufferData(gl.ARRAY_BUFFER, len(quadVertices)*size_of(quadVertices[0]), &quadVertices, gl.STATIC_DRAW)
	gl.EnableVertexAttribArray(0)
	gl.VertexAttribPointer(0, 2, gl.FLOAT, false, 4 * size_of(quadVertices[0]), 0)
	gl.EnableVertexAttribArray(1)
	gl.VertexAttribPointer(1, 2, gl.FLOAT, false, 4 * size_of(quadVertices[0]), 2 * size_of(quadVertices[0]))

	shaderSuccess: bool
	render.program, shaderSuccess = gl.load_shaders_source(vertShader, fragShader)

    if !shaderSuccess {
        info: [^]u8
        gl.GetShaderInfoLog(render.program, 1024, nil, info)
        a, b, c, d := gl.get_last_error_messages()
        skeewb.console_log(.ERROR, "could not compile fbo shaders\n %s\n %s", a, c)
		panic("")
    }
	
	render.uniforms = gl.get_uniforms_from_program(render.program)
	
	render.auxiliarProgram, shaderSuccess = gl.load_shaders_source(vertShader, fragShader2)

    if !shaderSuccess {
        info: [^]u8
        gl.GetShaderInfoLog(render.program, 1024, nil, info)
        a, b, c, d := gl.get_last_error_messages()
        skeewb.console_log(.ERROR, "could not compile auxiliar fbo shaders\n %s\n %s", a, c)
		panic("")
    }
	
	render.auxiliarUniforms = gl.get_uniforms_from_program(render.auxiliarProgram)

	render.blurProgram, shaderSuccess = gl.load_shaders_source(vertBlurShader, fragBlurShader)

    if !shaderSuccess {
        info: [^]u8
        gl.GetShaderInfoLog(render.program, 1024, nil, info)
        a, b, c, d := gl.get_last_error_messages()
        skeewb.console_log(.ERROR, "could not compile blur fbo shaders\n %s\n %s", a, c)
		panic("")
    }
	
	render.blurUniforms = gl.get_uniforms_from_program(render.blurProgram)

	temp := util.include(AAShader, {fxaaShader})
	defer delete(temp)
	render.AAProgram, shaderSuccess = gl.load_shaders_source(vertShader, temp)

    if !shaderSuccess {
        info: [^]u8
        gl.GetShaderInfoLog(render.AAProgram, 1024, nil, info)
        a, b, c, d := gl.get_last_error_messages()
        skeewb.console_log(.ERROR, "could not compile blur fbo shaders\n %s\n %s", a, c)
		panic("")
    }
	
	render.AAUniforms = gl.get_uniforms_from_program(render.AAProgram)
}

resize :: proc (camera: ^util.Camera) {
	gl.BindTexture(gl.TEXTURE_2D, render.colorBuffer.texture)
	gl.TexImage2D(gl.TEXTURE_2D, 0, gl.RGB16F, i32(camera.viewPort.x), i32(camera.viewPort.y), 0, gl.RGB, gl.UNSIGNED_BYTE, nil)
	
	gl.BindTexture(gl.TEXTURE_2D, render.depthBuffer.texture)
	gl.TexImage2D(gl.TEXTURE_2D, 0, gl.DEPTH_COMPONENT32, i32(camera.viewPort.x), i32(camera.viewPort.y), 0, gl.DEPTH_COMPONENT, gl.UNSIGNED_INT, nil)
	
	gl.BindTexture(gl.TEXTURE_2D, render.auxiliarColorBuffer.texture)
	gl.TexImage2D(gl.TEXTURE_2D, 0, gl.RGB16F, i32(camera.viewPort.x), i32(camera.viewPort.y), 0, gl.RGB, gl.UNSIGNED_BYTE, nil)
	
	gl.BindTexture(gl.TEXTURE_2D, render.blurColorBuffer.texture)
	gl.TexImage2D(gl.TEXTURE_2D, 0, gl.RGB16F, i32(camera.viewPort.x), i32(camera.viewPort.y), 0, gl.RGB, gl.UNSIGNED_BYTE, nil)
	
	gl.BindTexture(gl.TEXTURE_2D, render.auxiliarDepth.texture)
	gl.TexImage2D(gl.TEXTURE_2D, 0, gl.R32F, i32(camera.viewPort.x), i32(camera.viewPort.y), 0, gl.RED, gl.FLOAT, nil)
}

clearDepth :: proc () {
	gl.DrawBuffers(1, raw_data([]u32{gl.COLOR_ATTACHMENT2}))
	gl.Clear(gl.COLOR_BUFFER_BIT)
}

drawColorBuffer :: proc () {
	gl.UseProgram(render.auxiliarProgram)
	// gl.Uniform1i(render.auxiliarUniforms["screenTexture"].location, 0)
	// gl.Uniform1i(render.auxiliarUniforms["distanceTexture"].location, 1)
	gl.DrawBuffers(1, raw_data([]u32{render.auxiliarColorBuffer.attachment}))
	gl.Clear(gl.COLOR_BUFFER_BIT)

	gl.Disable(gl.DEPTH_TEST)
	gl.BindVertexArray(render.vao)
	gl.ActiveTexture(gl.TEXTURE0)
	gl.BindTexture(gl.TEXTURE_2D, render.colorBuffer.texture)
	// gl.ActiveTexture(gl.TEXTURE1)
	// gl.BindTexture(gl.TEXTURE_2D, render.auxiliarDepth)
	gl.DrawArrays(gl.TRIANGLES, 0, 6)
	gl.Enable(gl.DEPTH_TEST)
}

blurColorBuffer :: proc (camera: ^util.Camera, ) {
	gl.UseProgram(render.blurProgram)
	gl.Uniform2f(render.blurUniforms["resolution"].location, camera.viewPort.x, camera.viewPort.y)
	
	gl.Disable(gl.DEPTH_TEST)
	gl.BindVertexArray(render.vao)
	gl.ActiveTexture(gl.TEXTURE0)
	gl.BindTexture(gl.TEXTURE_2D, render.colorBuffer.texture)
	gl.Uniform1i(render.blurUniforms["axis"].location, 0)
	gl.DrawBuffers(1, raw_data([]u32{render.auxiliarColorBuffer.attachment}))
	gl.DrawArrays(gl.TRIANGLES, 0, 6)
	gl.BindTexture(gl.TEXTURE_2D, render.auxiliarColorBuffer.texture)
	gl.DrawBuffers(1, raw_data([]u32{render.blurColorBuffer.attachment}))
	gl.Uniform1i(render.blurUniforms["axis"].location, 1)
	gl.DrawArrays(gl.TRIANGLES, 0, 6)
	gl.Enable(gl.DEPTH_TEST)
}

draw :: proc () {
	gl.UseProgram(render.program)

	gl.Disable(gl.DEPTH_TEST)
	gl.Disable(gl.BLEND)

	gl.BindVertexArray(render.vao)
	gl.ActiveTexture(gl.TEXTURE0)
	gl.BindTexture(gl.TEXTURE_2D, render.colorBuffer.texture)
	
	gl.DrawBuffers(1, raw_data([]u32{render.auxiliarColorBuffer.attachment}))
	gl.Clear(gl.COLOR_BUFFER_BIT)
	gl.DrawArrays(gl.TRIANGLES, 0, 6)
}

drawAA :: proc () {
	gl.UseProgram(render.AAProgram)

	gl.BindVertexArray(render.vao)
	gl.BindTexture(gl.TEXTURE_2D, render.auxiliarColorBuffer.texture)
	gl.DrawArrays(gl.TRIANGLES, 0, 6)

	gl.Enable(gl.BLEND)
}

nuke :: proc () {
	for key, value in render.uniforms {
		delete(value.name)
	}
	for key, value in render.auxiliarUniforms {
		delete(value.name)
	}
	for key, value in render.blurUniforms {
		delete(value.name)
	}
	for key, value in render.AAUniforms {
		delete(value.name)
	}
	delete(render.uniforms)
	delete(render.blurUniforms)
	delete(render.AAUniforms)
	delete(render.auxiliarUniforms)
	gl.DeleteProgram(render.program)
	gl.DeleteProgram(render.blurProgram)
	gl.DeleteProgram(render.auxiliarProgram)
	gl.DeleteProgram(render.AAProgram)
	gl.DeleteFramebuffers(1, &render.id)
}
