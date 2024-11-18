package debug

import gl "vendor:OpenGL"
import "vendor:sdl2"
import stb "vendor:stb/image"
import "core:strings"
import glm "core:math/linalg/glsl"
import math "core:math/linalg"

import "../../skeewb"
import "../../util"

iVec3 :: [3]i32

VertShader :: #load("../../assets/shaders/debug_vert.glsl", string)
FragShader :: #load("../../assets/shaders/debug_frag.glsl", string)

Render :: struct{
	uniforms: map[string]gl.Uniform_Info,
	program: u32,
}

Buffers :: struct{
    VAO, VBO, EBO: u32,
    length: i32,
}

data := Buffers{}

setup :: proc(render: ^Render) {
	shaderSuccess: bool
	render.program, shaderSuccess = gl.load_shaders_source(VertShader, FragShader)

    if !shaderSuccess {
        info: [^]u8
        gl.GetShaderInfoLog(render.program, 1024, nil, info)
        a, b, c, d := gl.get_last_error_messages()
        skeewb.console_log(.ERROR, "could not compile blocks shaders\n %s\n %s", a, c)
    }

	render.uniforms = gl.get_uniforms_from_program(render.program)

    vertices := [dynamic]f32{}
    defer delete(vertices)
    indices := [dynamic]u32{}
    defer delete(indices)

    normals := [6]iVec3{{-1, 0, 0}, {1, 0, 0}, {0, -1, 0}, {0, 1, 0}, {0, 0, -1}, {0, 0, 1}}

    for normal in normals {
        scale: [3][2]i32
        offset := iVec3{0, 0, 0}
        corners: [4][3]f32
        if normal.x == 1 {
            scale.x = {0, 0}
            scale.y = {1, 0}
            scale.z = {0, 1}
            corners = {
                {0, 0, 1},
                {0, 1, 1},
                {0, 1, 0},
                {0, 0, 0}
            }
            offset.x = 16
        } else if normal.x == -1 {
            scale.x = {0, 0}
            scale.y = {1, 0}
            scale.z = {0, 1}
            corners = {
                {0, 0, 0},
                {0, 1, 0},
                {0, 1, 1},
                {0, 0, 1}
            }
        } else if normal.y == 1 {
            scale.x = {1, 0}
            scale.y = {0, 0}
            scale.z = {0, 1}
            corners = {
                {0, 0, 0},
                {1, 0, 0},
                {1, 0, 1},
                {0, 0, 1}
            }
            offset.y = 16
        } else if normal.y == -1 {
            scale.x = {1, 0}
            scale.y = {0, 0}
            scale.z = {0, 1}
            corners = {
                {0, 0, 1},
                {1, 0, 1},
                {1, 0, 0},
                {0, 0, 0}
            }
        } else if normal.z == 1 {
            scale.x = {1, 0}
            scale.y = {0, 1}
            scale.z = {0, 0}
            corners = {
                {0, 1, 0},
                {1, 1, 0},
                {1, 0, 0},
                {0, 0, 0}
            }
            offset.z = 16
        } else {
            scale.x = {1, 0}
            scale.y = {0, 1}
            scale.z = {0, 0}
            corners = {
                {0, 0, 0},
                {1, 0, 0},
                {1, 1, 0},
                {0, 1, 0}
            }
        }
        for i := i32(0); i < 16; i += 1 {
            for j := i32(0); j < 16; j += 1 {
                x := f32(offset.x + i * scale.x[0] + j * scale.x[1])
                y := f32(offset.y + i * scale.y[0] + j * scale.y[1])
                z := f32(offset.z + i * scale.z[0] + j * scale.z[1])

                append(&vertices, x + corners[0].x, y + corners[0].y, z + corners[0].z)
                append(&vertices, x + corners[1].x, y + corners[1].y, z + corners[1].z)
                append(&vertices, x + corners[2].x, y + corners[2].y, z + corners[2].z)
                append(&vertices, x + corners[3].x, y + corners[3].y, z + corners[3].z)

                n := u32(len(vertices)) / 3
                append(&indices, n - 4, n - 3, n - 2, n - 2, n - 1, n - 4)
            }
        }
    }

    VAO, VBO, EBO: u32
    
	gl.GenVertexArrays(1, &VAO)
	gl.BindVertexArray(VAO)

	gl.GenBuffers(1, &VBO)
    gl.BindBuffer(gl.ARRAY_BUFFER, VBO)
    gl.BufferData(gl.ARRAY_BUFFER, len(vertices)*size_of(vertices[0]), raw_data(vertices), gl.STATIC_DRAW)
	
	gl.GenBuffers(1, &EBO)
	gl.BindBuffer(gl.ELEMENT_ARRAY_BUFFER, EBO)
	gl.BufferData(gl.ELEMENT_ARRAY_BUFFER, len(indices)*size_of(indices[0]), raw_data(indices), gl.STATIC_DRAW)

	gl.EnableVertexAttribArray(0)
	gl.VertexAttribPointer(0, 3, gl.FLOAT, false, 3 * size_of(f32), 0)

    data.VAO = VAO
    data.VBO = VBO
    data.EBO = EBO
    data.length = i32(len(indices))
}

draw :: proc(camera: ^util.Camera, render: Render) {
	gl.UseProgram(render.program)
	gl.UniformMatrix4fv(render.uniforms["projection"].location, 1, false, &camera.proj[0, 0])
	gl.UniformMatrix4fv(render.uniforms["view"].location, 1, false, &camera.view[0, 0])

	pos := [3]f32{f32(camera.chunk.x) * 16 - camera.pos.x, f32(camera.chunk.y) * 16 - camera.pos.y, f32(camera.chunk.z) * 16 - camera.pos.z}
	model := math.matrix4_translate_f32(pos)
	gl.UniformMatrix4fv(render.uniforms["model"].location, 1, false, &model[0, 0])

	gl.BindVertexArray(data.VAO)
	gl.DrawElements(gl.TRIANGLES, data.length, gl.UNSIGNED_INT, nil)
}