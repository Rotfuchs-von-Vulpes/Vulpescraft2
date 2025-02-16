package effects

import gl "vendor:OpenGL"

Buffer :: struct {
	attachment: u32,
	texture: u32,
}

quadVertices := [?]f32{
	// positions   // texCoords
	-1.0,  1.0,  0.0, 1.0,
	-1.0, -1.0,  0.0, 0.0,
	 1.0, -1.0,  1.0, 0.0,

	-1.0,  1.0,  0.0, 1.0,
	 1.0, -1.0,  1.0, 0.0,
	 1.0,  1.0,  1.0, 1.0
}

setBuffers :: proc (vbo, vao: ^u32) {
	gl.GenVertexArrays(1, vao)
	gl.GenBuffers(1, vbo)
	gl.BindVertexArray(vao^)
	gl.BindBuffer(gl.ARRAY_BUFFER, vbo^)
	gl.BufferData(gl.ARRAY_BUFFER, len(quadVertices)*size_of(quadVertices[0]), &quadVertices, gl.STATIC_DRAW)
	gl.EnableVertexAttribArray(0)
	gl.VertexAttribPointer(0, 2, gl.FLOAT, false, 4 * size_of(quadVertices[0]), 0)
	gl.EnableVertexAttribArray(1)
	gl.VertexAttribPointer(1, 2, gl.FLOAT, false, 4 * size_of(quadVertices[0]), 2 * size_of(quadVertices[0]))
}
