package worldRender

import "core:strings"
import glm "core:math/linalg/glsl"
import math "core:math/linalg"
import "core:time"

import gl "vendor:OpenGL"
import "vendor:sdl2"
import stb "vendor:stb/image"

import "../skeewb"
import "../world"
import "../util"
import "../sky"
import mesh "meshGenerator"

waterVertShader :: #load("../assets/shaders/water_vert.glsl", string)
waterFragShader :: #load("../assets/shaders/water_frag.glsl", string)
lightingShader :: #load("../assets/shaders/util/lighting.glsl", string)

tick := time.tick_now()

setupWaterDrawing :: proc(render: ^Render) {
	shaderSuccess: bool
	temp := util.include(waterFragShader, {lightingShader})
	defer delete(temp)
	render.program, shaderSuccess = gl.load_shaders_source(waterVertShader, temp)

    if !shaderSuccess {
        info: [^]u8
        gl.GetShaderInfoLog(render.program, 1024, nil, info)
        a, b, c, d := gl.get_last_error_messages()
        skeewb.console_log(.ERROR, "could not compile water shaders\n %s\n %s", a, c)
		panic("")
    }

	render.uniforms = gl.get_uniforms_from_program(render.program)
}

setupWater :: proc(data: mesh.ChunkData) -> Buffers {
    VAO, VBO, EBO: u32
    
	gl.GenVertexArrays(1, &VAO)
	gl.BindVertexArray(VAO)

	gl.GenBuffers(1, &VBO)
    gl.BindBuffer(gl.ARRAY_BUFFER, VBO)
    gl.BufferData(gl.ARRAY_BUFFER, len(data.water.vertices)*size_of(data.water.vertices[0]), raw_data(data.water.vertices), gl.STATIC_DRAW)
	
	gl.GenBuffers(1, &EBO)
	gl.BindBuffer(gl.ELEMENT_ARRAY_BUFFER, EBO)
	gl.BufferData(gl.ELEMENT_ARRAY_BUFFER, len(data.water.indices)*size_of(data.water.indices[0]), raw_data(data.water.indices), gl.STATIC_DRAW)

	gl.EnableVertexAttribArray(0)
	gl.EnableVertexAttribArray(1)
	gl.VertexAttribPointer(0, 3, gl.FLOAT, false, 6 * size_of(f32), 0)
	gl.VertexAttribPointer(1, 3, gl.FLOAT, false, 6 * size_of(f32), 3 * size_of(f32))

	return {VAO, VBO, EBO}
}

drawWater :: proc(chunks: [dynamic]ChunkBuffer, camera: ^util.Camera, render: Render, frameTexture, depthTexture: u32) {
	gl.DrawBuffers(1, raw_data([]u32{gl.COLOR_ATTACHMENT0}))
	gl.UseProgram(render.program)
	gl.Uniform1i(render.uniforms["screenTexture"].location, 0)
	gl.Uniform1i(render.uniforms["depthTexture"].location, 1)
	gl.ActiveTexture(gl.TEXTURE0)
	gl.BindTexture(gl.TEXTURE_2D, frameTexture)
	gl.ActiveTexture(gl.TEXTURE1)
	gl.BindTexture(gl.TEXTURE_2D, depthTexture)
	duration := time.tick_since(tick)
	timePassed := time.duration_seconds(duration)
	gl.Uniform1f(render.uniforms["time"].location, f32(timePassed))
	gl.UniformMatrix4fv(render.uniforms["projection"].location, 1, false, &camera.proj[0, 0])
	gl.UniformMatrix4fv(render.uniforms["view"].location, 1, false, &camera.view[0, 0])
	gl.Uniform2f(render.uniforms["resolution"].location, camera.viewPort.x, camera.viewPort.y)
	gl.Uniform3f(render.uniforms["sunDirection"].location, sky.sunDirection.x, sky.sunDirection.y, sky.sunDirection.z)
	gl.Uniform3f(render.uniforms["skyColor"].location, sky.skyColor.r, sky.skyColor.g, sky.skyColor.b)
	gl.Uniform3f(render.uniforms["fogColor"].location, sky.fogColor.r, sky.fogColor.g, sky.fogColor.b)
	for chunk in chunks {
		if chunk.data.water.length == 0 do continue 
		pos := vec3{f32(chunk.pos.x) * 16 - camera.pos.x, f32(chunk.pos.y) * 16 - camera.pos.y, f32(chunk.pos.z) * 16 - camera.pos.z}
		model := math.matrix4_translate_f32(pos)
		modelView := camera.view * model
		
		gl.Uniform3f(render.uniforms["chunkPosition"].location, f32(chunk.pos.x) * 16, f32(chunk.pos.y) * 16, f32(chunk.pos.z) * 16)
		gl.UniformMatrix4fv(render.uniforms["model"].location, 1, false, &model[0, 0])
		
		gl.BindVertexArray(chunk.waterBuffer.VAO)
		gl.BindBuffer(gl.ELEMENT_ARRAY_BUFFER, chunk.waterBuffer.EBO);
		gl.DrawElements(gl.TRIANGLES, chunk.data.water.length, gl.UNSIGNED_INT, nil)
	}
}