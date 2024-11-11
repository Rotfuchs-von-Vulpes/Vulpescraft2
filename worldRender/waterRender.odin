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

waterVertShader :: #load("../assets/shaders/water_vert.glsl", string)
waterFragShader :: #load("../assets/shaders/water_frag.glsl", string)

setupWaterDrawing :: proc(render: ^Render) {
	shaderSuccess: bool
	render.program, shaderSuccess = gl.load_shaders_source(waterVertShader, waterFragShader)

    if !shaderSuccess {
        info: [^]u8
        gl.GetShaderInfoLog(render.program, 1024, nil, info)
        a, b, c, d := gl.get_last_error_messages()
        skeewb.console_log(.ERROR, "could not compile water shaders\n %s\n %s", a, c)
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

drawWater :: proc(chunks: [dynamic]ChunkBuffer, camera: ^util.Camera, render: Render) {
	gl.UseProgram(render.program)
	gl.UniformMatrix4fv(render.uniforms["projection"].location, 1, false, &camera.proj[0, 0])
	gl.UniformMatrix4fv(render.uniforms["view"].location, 1, false, &camera.view[0, 0])
	gl.Uniform3f(render.uniforms["sunDirection"].location, sky.sunDirection.x, sky.sunDirection.y, sky.sunDirection.z)
	gl.Uniform3f(render.uniforms["skyColor"].location, sky.skyColor.r, sky.skyColor.g, sky.skyColor.b)
	gl.Uniform3f(render.uniforms["fogColor"].location, sky.fogColor.r, sky.fogColor.g, sky.fogColor.b)
	for chunk in chunks {
		pos := vec3{f32(chunk.x) * 16 - camera.pos.x, f32(chunk.y) * 16 - camera.pos.y, f32(chunk.z) * 16 - camera.pos.z}
		model := math.matrix4_translate_f32(pos)
		modelView := camera.view * model
		// inverseModelView := glm.inverse_mat4(modelView)
		gl.UniformMatrix4fv(render.uniforms["model"].location, 1, false, &model[0, 0])
		// gl.UniformMatrix4fv(render.uniforms["modelView"].location, 1, false, &modelView[0, 0])
		// gl.UniformMatrix4fv(render.uniforms["inverseModelView"].location, 1, false, &inverseModelView[0, 0])
		
		gl.BindVertexArray(chunk.waterBuffer.VAO)
		gl.BindBuffer(gl.ELEMENT_ARRAY_BUFFER, chunk.waterBuffer.EBO);
		gl.DrawElements(gl.TRIANGLES, chunk.data.water.length, gl.UNSIGNED_INT, nil)
		// skeewb.console_log(.INFO, "%d", chunk.waterBuffer.EBO)
	}
}