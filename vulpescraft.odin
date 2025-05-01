package vulpescraft

import "core:fmt"
import "core:strings"
import "core:time"
import "core:mem"
import "core:thread"
import "core:sync"
import "core:sync/chan"
import "core:slice"
import math "core:math/linalg"
import glm "core:math/linalg/glsl"
import "skeewb"
import "base:runtime"
import "vendor:sdl2"
import gl "vendor:OpenGL"

import "world"
import "worldRender"
import mesh "worldRender/meshGenerator"
import "frameBuffer"
import "util"
import "sky"
import "worldRender/debug"
import "hud"

import "tracy"

iVec3 :: [3]i32

screenWidth: i32 = 854
screenHeight: i32 = 480

playerCamera := util.Camera{
	{14, 31, 14}, 
	{0, 0, -1}, 
	{0, 1, 0}, 
	{1, 0, 0}, 
	{0, 1, 0}, 
	{f32(screenWidth), f32(screenHeight)}, 
	math.MATRIX4F32_IDENTITY, math.MATRIX4F32_IDENTITY
}

chunks: [dynamic]worldRender.ChunkBuffer
allChunks: [dynamic]worldRender.ChunkBuffer
toRemashing: [dynamic][3]i32

primersLock: sync.RW_Mutex

cameraSetup :: proc() {
	playerCamera.proj = math.matrix4_infinite_perspective_f32(45, playerCamera.viewPort.x / playerCamera.viewPort.y, 0.1)
}

cameraMove :: proc() {
	playerCamera.view = math.matrix4_look_at_f32({0, 0, 0}, playerCamera.front, playerCamera.up)
}

ThreadWork :: struct {
	chunkPosition: [3]i32,
	reset: bool,
}

ChunkData :: struct {
	pos: iVec3,
	primer: world.Primer,
	light: world.LightPrimer,
}

ChunkBlocks :: struct {
	pos: iVec3,
	primer: world.Primer,
}

pos_chan: chan.Chan(^world.Chunk)
chunks_chan: chan.Chan(^world.ChunkData)
chunks_light_chan: chan.Chan(^world.ChunkPrimer)
// lightData_chan: chan.Chan(^world.LightData)
// final_chan: chan.Chan(^world.Chunk)
meshes_chan: chan.Chan(mesh.ChunkData)

generateChunkBlocks :: proc(^thread.Thread) {
	context = runtime.default_context()
	context.allocator = mem.tracking_allocator(tracking_allocator)

	for !chan.is_closed(pos_chan) {
		chunk, ok := chan.recv(pos_chan)
		if !ok do continue
		data := world.genPoll(chunk, &primersLock)
		chan.send(chunks_light_chan, data)
		// world.allChunks[pos] = ptr
	}
}

iluminateChunk :: proc (^thread.Thread) {
	context = runtime.default_context()
	context.allocator = mem.tracking_allocator(tracking_allocator)

	for !chan.is_closed(chunks_light_chan) {
		chunk, ok := chan.recv(chunks_light_chan)
		if !ok do continue 
		resp := world.applyLight(chunk)
		chan.send(chunks_chan, resp)
	}
}

generateChunkMesh :: proc(^thread.Thread) {
	context = runtime.default_context()
	context.allocator = mem.tracking_allocator(tracking_allocator)

	for !chan.is_closed(chunks_chan) {
		chunk, ok := chan.recv(chunks_chan)
		if !ok do continue
		//chan.send(final_chan, chunk)
		chan.send(meshes_chan, mesh.generateMesh(chunk.pos, &chunk.primer))
		free(chunk)
	}
}

toReload := false

history := make(map[[3]i32]bool)

less_dist :: proc (a, b: [3]i32) -> bool {
	return a.x*a.x + a.y*a.y + a.z*a.z < b.x*b.x + b.y*b.y + b.z*b.z
}

reloadChunks :: proc(reset: bool) {
	context = runtime.default_context()
	toReload = false

	buffer := [dynamic]int{}
	defer delete(buffer)
	for chunk, idx in allChunks {
		if !world.sqDist(chunk.pos, playerCamera.chunk, world.VIEW_DISTANCE) {
			append(&buffer, idx)
		}
	}
	#reverse for idx in buffer {
		unordered_remove(&allChunks, idx)
	}

	viewDist := world.VIEW_DISTANCE
	viewSize := 2 * viewDist + 1
	positions := [dynamic][3]i32{}
	defer delete(positions)

	for x in 0..<viewSize do for y in 0..<viewSize do for z in 0..<viewSize {
		xx := x - viewDist
		yy := y - viewDist
		zz := z - viewDist

		append(&positions, [3]i32{i32(xx), i32(yy), i32(zz)})
	}

	positionsList := positions[:]
	slice.sort_by(positionsList, less_dist)

	for pos in positionsList {
		if pos.x*pos.x + pos.y*pos.y + pos.z*pos.z >= world.VIEW_DISTANCE * world.VIEW_DISTANCE do break
		p := pos + playerCamera.chunk
		if !history[p] {
			chunk := new(world.Chunk)
			// world.getNewChunk(chunk, p)
			chunk.pos = p
			world.allChunks[p] = chunk
			chan.send(pos_chan, chunk)
			history[p] = true
		}
	}
}

yaw: f32 = -90.0;
pitch: f32 = 0.0;

lastChunkX := playerCamera.chunk.x
lastChunkY := playerCamera.chunk.y
lastChunkZ := playerCamera.chunk.z

last: time.Tick
cameraSpeed: f32 = 0.0125

tracking_allocator: ^mem.Tracking_Allocator

main :: proc() {
	context = runtime.default_context()

	tracking_allocator = new(mem.Tracking_Allocator)
	defer free(tracking_allocator)
	mem.tracking_allocator_init(tracking_allocator, context.allocator)
	context.allocator = mem.tracking_allocator(tracking_allocator)

	// tracy.Zone()

	chunksAllocator := runtime.heap_allocator()
	err: runtime.Allocator_Error
	pos_chan, err = chan.create_buffered(chan.Chan(^world.Chunk), 2000000, chunksAllocator)
	meshes_chan, err = chan.create_buffered(chan.Chan(mesh.ChunkData), 8 * 8, chunksAllocator)
	chunks_chan, err = chan.create_buffered(chan.Chan(^world.ChunkData), 8 * 8, chunksAllocator)
	chunks_light_chan, err = chan.create_buffered(chan.Chan(^world.ChunkPrimer), 2000000, chunksAllocator)
	
	start_tick := time.tick_now()

	sdl2.Init(sdl2.INIT_EVERYTHING)

	sdl2.GL_SetAttribute(sdl2.GLattr.CONTEXT_MAJOR_VERSION, 3)
	sdl2.GL_SetAttribute(sdl2.GLattr.CONTEXT_MINOR_VERSION, 3)
	sdl2.GL_SetAttribute(sdl2.GLattr.CONTEXT_PROFILE_MASK, i32(sdl2.GLprofile.CORE))


	window := sdl2.CreateWindow(
		"testando se muda alguma coisa", 
		sdl2.WINDOWPOS_CENTERED, 
		sdl2.WINDOWPOS_CENTERED, 
		screenWidth, screenHeight, 
		sdl2.WINDOW_RESIZABLE | sdl2.WINDOW_OPENGL)
	if window == nil {
		skeewb.console_log(.ERROR, "could not create a window sdl error: %s", sdl2.GetError())
	}
	skeewb.console_log(.INFO, "successfully created a window")

	sdl2.SetRelativeMouseMode(true)

	gl_context := sdl2.GL_CreateContext(window);
	if gl_context == nil {
		skeewb.console_log(.ERROR, "could not create an OpenGL context sdl error: %s", sdl2.GetError())
	}
	skeewb.console_log(.INFO, "successfully created an OpenGL context")

	sdl2.GL_SetSwapInterval(1)

	gl.load_up_to(3, 3, sdl2.gl_set_proc_address)
	
	gl.Enable(gl.DEPTH_TEST)
	gl.Enable(gl.CULL_FACE)
	gl.CullFace(gl.BACK)
	gl.BlendFunc(gl.SRC_ALPHA, gl.ONE_MINUS_SRC_ALPHA)

	blockRender := worldRender.Render{{}, 0, 0}
	waterRender := worldRender.Render{{}, 0, 0}
	skyRender := sky.Render{0, 0, {}, 0, 0}
	sunRender := sky.Render{0, 0, {}, 0, 0}
	debugRender := debug.Render{{}, 0}

	debug.setup(&debugRender)
	worldRender.setupBlockDrawing(&blockRender)
	worldRender.setupWaterDrawing(&waterRender)

	gl.ClearColor(1.0, 1.0, 1.0, 1.0)

	playerCamera.proj = math.matrix4_infinite_perspective_f32(45, playerCamera.viewPort.x / playerCamera.viewPort.y, 0.1)
	playerCamera.view = math.matrix4_look_at_f32({0, 0, 0}, playerCamera.front, playerCamera.up)

	frameBuffer.setup(&playerCamera)
	hud.setup()

	sky.setup(&playerCamera, &skyRender)
	sky.setupSun(&playerCamera, &sunRender)

	worldRender.frustumMove(&allChunks, &playerCamera)
	chunks = worldRender.frustumCulling(&allChunks, &playerCamera)

	lastTimeTicks := time.tick_now()
	nbFrames := 0
	fps := 0
	
	toFront := false
	toBehind := false
	toRight := false
	toLeft := false
	toDebug := false
	
	// chunkInitializatorThread := thread.create(getChunkPointerThread)
	// thread.start(chunkInitializatorThread)
	chunkGenereatorThreads: [6]^thread.Thread
	for &t in chunkGenereatorThreads {
		t = thread.create(generateChunkBlocks)
		thread.start(t)
	}
	chunkIluminatorThreads: [6]^thread.Thread
	for &t in chunkIluminatorThreads {
		t = thread.create(iluminateChunk)
		thread.start(t)
	}
	meshGenereatorThread := thread.create(generateChunkMesh)
	thread.start(meshGenereatorThread)
	reloadChunks(false)

	looking := true

	index := 0

	loop: for {
		duration := time.tick_since(start_tick)
		deltaTime := f32(time.duration_milliseconds(duration))

		event: sdl2.Event
		for sdl2.PollEvent(&event) {
			if event.type == .QUIT || event.type == .WINDOWEVENT && event.window.event == .CLOSE {
				break loop
			} else if event.type == .KEYUP {
				#partial switch (event.key.keysym.sym) {
					case .ESCAPE:
						break loop
					case .W:
						toFront = false
					case .S:
						toBehind = false
					case .A:
						toLeft = false
					case .D:
						toRight = false
					case .F1:
						toDebug = !toDebug
					case .E:
						looking = !looking
						if looking do sdl2.SetRelativeMouseMode(true); else do sdl2.SetRelativeMouseMode(false)
				}
			} else if event.type == .KEYDOWN {
				#partial switch (event.key.keysym.sym) {
					case .ESCAPE:
						break loop
					case .W:
						toFront = true
					case .S:
						toBehind = true
					case .A:
						toLeft = true
					case .D:
						toRight = true
					// case .Q:
					// 	c := world.allChunks[playerCamera.chunk]
					// 	oponed := c.opened
					// 	str := "Opened sides: "
					// 	if .Up in oponed do str = fmt.tprintf("%s, Up", str)
					// 	if .Bottom in oponed do str = fmt.tprintf("%s, Bottom", str)
					// 	if .North in oponed do str = fmt.tprintf("%s, North", str)
					// 	if .South in oponed do str = fmt.tprintf("%s, South", str)
					// 	if .West in oponed do str = fmt.tprintf("%s, West", str)
					// 	if .East in oponed do str = fmt.tprintf("%s, East", str)
					// 	fmt.printfln(str)
					// 	fmt.printfln("%d", c.level)
				}
			} else if looking && event.type == .MOUSEMOTION {
				xpos :=  f32(event.motion.xrel)
				ypos := -f32(event.motion.yrel)
			
				sensitivity: f32 = 0.0625
				xoffset := xpos * sensitivity
				yoffset := ypos * sensitivity
			
				yaw += xoffset
				pitch += yoffset

				if pitch >= 89 {
					pitch = 89
				}
				if pitch <= -89 {
					pitch = -89
				}

				yawRadians := yaw * math.RAD_PER_DEG
				pitchRadians := pitch * math.RAD_PER_DEG
			
				playerCamera.front = {
					math.cos(yawRadians) * math.cos(pitchRadians),
					math.sin(pitchRadians),
					math.sin(yawRadians) * math.cos(pitchRadians)
				}
				playerCamera.front = math.vector_normalize(playerCamera.front)
				
				playerCamera.up = {
					-math.sin(pitchRadians) * math.cos(yawRadians),
					math.cos(pitchRadians),
					-math.sin(pitchRadians) * math.sin(yawRadians)
				}
				playerCamera.up = math.vector_normalize(playerCamera.up)

				playerCamera.right = math.cross(playerCamera.front, playerCamera.up)
				
				playerCamera.view = math.matrix4_look_at_f32({0, 0, 0}, playerCamera.front, playerCamera.up)
				if chunks != nil {delete(chunks)}
				chunks = worldRender.frustumCulling(&allChunks, &playerCamera)
			} else if event.type == .WINDOWEVENT {
				if event.window.event == .RESIZED {
					screenWidth = event.window.data1
					screenHeight = event.window.data2
					playerCamera.viewPort.x = f32(screenWidth)
					playerCamera.viewPort.y = f32(screenHeight)
					playerCamera.proj = math.matrix4_infinite_perspective_f32(45, playerCamera.viewPort.x / playerCamera.viewPort.y, 0.1)
					frameBuffer.resize(&playerCamera)
				}
			} else if event.type == .MOUSEBUTTONDOWN {
				if event.button.button == 1 {
					chunksToUpdate, ok := world.destroy(playerCamera.pos, playerCamera.front, &primersLock)
					for chunk, idx in chunksToUpdate do chan.send(chunks_light_chan, chunk)
					delete(chunksToUpdate)
				} else if event.button.button == 3 {
					chunksToUpdate, ok := world.place(playerCamera.pos, playerCamera.front, u16(index) + 1, &primersLock)
					for &chunk in chunksToUpdate do chan.send(chunks_light_chan, chunk)
					delete(chunksToUpdate)
				}
			} else if event.type == .MOUSEWHEEL {
				if event.wheel.y < 0 {
					index += 1
					if index > 8 do index = 0
				} else {
					index -= 1
					if index < 0 do index = 8
				}
			}
		}

		scale: [3]f32 = {0, 0, 0}

		if toFront != toBehind {
			if toFront {
				scale += playerCamera.front
			} else {
				scale -= playerCamera.front
			}
		}

		if toLeft != toRight {
			if toLeft {
				scale -= playerCamera.right
			} else {
				scale += playerCamera.right
			}
		}

		if scale.x != 0 || scale.y != 0 || scale.z != 0 {
			scale = math.vector_normalize(scale) * cameraSpeed * f32(time.duration_milliseconds(time.tick_since(last)))
			playerCamera.pos += scale;
			if chunks != nil {delete(chunks)}
			chunks = worldRender.frustumCulling(&allChunks, &playerCamera)
		}
		last = time.tick_now()
		
		chunkX := i32(math.floor(playerCamera.pos.x / 16))
		chunkY := i32(math.floor(playerCamera.pos.y / 16))
		chunkZ := i32(math.floor(playerCamera.pos.z / 16))
		moved := false

		if chunkX != lastChunkX {
			playerCamera.chunk.x = chunkX
			lastChunkX = chunkX
			moved = true
		}
		if chunkY != lastChunkY {
			playerCamera.chunk.y = chunkY
			lastChunkY = chunkY
			moved = true
		}
		if chunkZ != lastChunkZ {
			playerCamera.chunk.z = chunkZ
			lastChunkZ = chunkZ
			moved = true
		}

		if moved {reloadChunks(false)}

		if toReload {reloadChunks(false)}
		
		{
			//tmp := [dynamic]mesh.ChunkData{}
			//defer delete(tmp)
			done := false
			for {
				chunk, ok := chan.try_recv(meshes_chan)
				if !ok do break
				done = true
				for chunk2, idx in allChunks {
					if chunk.pos == chunk2.pos {
						unordered_remove(&allChunks, idx)
					}
				}
				append(&allChunks, worldRender.setupChunk(chunk))
			}

			if done {
				worldRender.frustumMove(&allChunks, &playerCamera)
				delete(chunks)
				chunks = worldRender.frustumCulling(&allChunks, &playerCamera)
			}
		}

		gl.UseProgram(frameBuffer.render.program)
		gl.BindFramebuffer(gl.FRAMEBUFFER, frameBuffer.render.id)
		gl.Clear(gl.COLOR_BUFFER_BIT | gl.DEPTH_BUFFER_BIT)

		gl.Viewport(0, 0, i32(playerCamera.viewPort.x), i32(playerCamera.viewPort.y))
		gl.UseProgram(skyRender.program)
		sky.draw(&playerCamera, skyRender, deltaTime)
		gl.UseProgram(sunRender.program)
		sky.drawSun(&playerCamera, sunRender, deltaTime)
		gl.Enable(gl.DEPTH_TEST)
		if toDebug {
			gl.PolygonMode(gl.FRONT_AND_BACK, gl.LINE)
			debug.draw(&playerCamera, debugRender)
			gl.PolygonMode(gl.FRONT_AND_BACK, gl.FILL)
		}
		frameBuffer.clearDepth()
		worldRender.drawBlocks(chunks, &playerCamera, blockRender)
		frameBuffer.drawBlur()
		worldRender.drawWater(chunks, &playerCamera, waterRender, frameBuffer.render.blurColorBuffer.texture, frameBuffer.render.auxiliarDepth.texture)
		
		frameBuffer.colorEffect()
		frameBuffer.drawAA()
		gl.BindFramebuffer(gl.FRAMEBUFFER, 0)
		frameBuffer.draw()
		hud.draw(screenWidth, screenHeight, index, frameBuffer.render.colorBuffer.texture, blockRender.texture)

		sdl2.GL_SwapWindow(window)
		
		nbFrames += 1
		if time.duration_seconds(time.tick_since(lastTimeTicks)) >= 1.0 {
			fps = nbFrames
			nbFrames = 0
			lastTimeTicks = time.tick_now()
			// fmt.printfln("%d", chan.len(pos_chan))
		}
		sdl2.SetWindowTitle(window, strings.unsafe_string_to_cstring(fmt.tprintfln("FPS: %d", fps)))
	}

	for {
		data, ok := chan.try_recv(chunks_chan)
		if !ok do break
		fmt.printfln("a")
		free(data)
	}
	for {
		data, ok := chan.try_recv(chunks_light_chan)
		if !ok do break
		free(data)
	}
	
	chan.close(pos_chan)
	chan.close(chunks_chan)
	chan.close(chunks_light_chan)
	chan.close(meshes_chan)
	for &t in chunkGenereatorThreads do thread.destroy(t)
	for &t in chunkIluminatorThreads do thread.destroy(t)
	thread.destroy(meshGenereatorThread)
	
	hud.nuke()
	world.nuke()
	worldRender.nuke()
	frameBuffer.nuke()

	for key, value in blockRender.uniforms {
		delete(value.name)
	}
	for key, value in waterRender.uniforms {
		delete(value.name)
	}
	for key, value in skyRender.uniforms {
		delete(value.name)
	}
	for key, value in sunRender.uniforms {
		delete(value.name)
	}
	for key, value in debugRender.uniforms {
		delete(value.name)
	}
	delete(blockRender.uniforms)
	delete(waterRender.uniforms)
	delete(skyRender.uniforms)
	delete(sunRender.uniforms)
	delete(debugRender.uniforms)
	gl.DeleteProgram(blockRender.program)
	gl.DeleteProgram(waterRender.program)
	gl.DeleteProgram(skyRender.program)
	gl.DeleteProgram(sunRender.program)
	gl.DeleteProgram(debugRender.program)
	delete(toRemashing)
	delete(history)
	delete(allChunks)
	delete(chunks)
	
	sdl2.GL_DeleteContext(gl_context)
	sdl2.DestroyWindow(window)
	sdl2.Quit()

	prev_allocator := context.allocator
	context.allocator = mem.tracking_allocator(tracking_allocator)

	defer context.allocator = prev_allocator
	defer mem.tracking_allocator_destroy(tracking_allocator)
	
	temp := runtime.default_temp_allocator_temp_begin()
	defer runtime.default_temp_allocator_temp_end(temp)
	skeewb.console_log(.INFO, "printing leaks...")
	for _, leak in tracking_allocator.allocation_map {
		skeewb.console_log(.INFO, fmt.tprintf("%v leaked %m\n", leak.location, leak.size))
	}
	for bad_free in tracking_allocator.bad_free_array {
		skeewb.console_log(.INFO, fmt.tprintf("%v allocation %p was freed badly\n", bad_free.location, bad_free.memory))
	}
}
