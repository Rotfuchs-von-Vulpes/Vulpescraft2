package util

import "base:runtime"
import "core:fmt"
import "core:strings"
import glm "core:math/linalg/glsl"

mat4 :: glm.mat4x4
vec2 :: [2]f32
vec3 :: [3]f32
vec4 :: [4]f32

Camera :: struct{
	pos: vec3,
	front: vec3,
	up: vec3,
	right: vec3,
	chunk: [3]i32,
    viewPort: vec2,
	proj, view: mat4
}

map_force_get :: proc(m: ^$T/map[$K]$V, key: K) -> (value: ^V, just_inserted: bool, err: runtime.Allocator_Error) {
    key := key

    raw  := (^runtime.Raw_Map)(m)
    info := runtime.map_info(T)
    hash := info.key_hasher(&key, runtime.map_seed(raw^))
    
    if found := runtime.__dynamic_map_get(raw, info, hash, &key); found != nil {
        value = (^V)(found)
        return
    }

    has_grown: bool
    err, has_grown = runtime.__dynamic_map_check_grow(raw, info)
    if err != nil { return }

    if has_grown {
        hash = info.key_hasher(&key, runtime.map_seed(raw^))
    }

    zero: V
    result := runtime.map_insert_hash_dynamic(raw, info, hash, uintptr(&key), uintptr(&zero))
    if result != 0 {
        raw.len += 1
    }

    just_inserted = true
    value = (^V)(result)
    return
}

include :: proc (source: string, files: []string) -> string {
    output := strings.clone(source)
    for file in files {
        line: string = ""
        init := strings.index(output, "#include")
        if init == -1 do return output
        for i := init; i < len(output); i += 1 {
            temp := strings.clone(line)
            delete(line)
            line = strings.concatenate({temp, string([]u8{output[i]})})
            delete(temp)
            if '\n' == output[i] do break
        }
        temp := strings.clone(output)
        delete(output)
        output, _ = strings.replace(temp, line, file, 1)
        delete(temp)
        delete(line)
    }

    return output
}
