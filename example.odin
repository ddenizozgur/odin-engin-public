#+build windows
package main

import "core:fmt"
import "core:math"
import "core:math/linalg"
import "core:sys/windows"
import "core:time"
import "vendor:OpenGL"

import "engin/platform"
import "engin/platform/win32"
import "engin/render"

/*
*
*/

font: render.Font

to_init :: proc() -> bool {
	render.imm_init() or_return

	font = render.font_load_from_file(
		"resource/fonts/size32pxrange8/VarelaRound-Regular.json",
		"resource/fonts/size32pxrange8/VarelaRound-Regular.png",
	) or_return

	return true
}

to_update :: proc(delta_time: f32) {
	@(static) initted := false
	if (!initted) {
		defer initted = true
		to_init()
	}

	client_size := linalg.to_f32(win32.get_client_size())
	mouse_pos := linalg.to_f32(win32.get_mouse_pos())

	{
		render.imm_begin()
		defer {
			draw_fps(font, {0, 0}, 20, delta_time)
			render.imm_end()
		}

		render.clear_render_target({0.15, 0.1, 0.15, 1})

		torture_test0(font, delta_time)
	}
}

main :: proc() {
	win32.set_console_utf8()

	win32.window_init("Odin-Engin-Public", {1280, 800}, .Windowed)
	defer win32.window_free()

	win32.wgl_init()
	windows.wglSwapIntervalEXT(0)

	OpenGL.load_up_to(4, 3, windows.gl_set_proc_address)

	prev_time := time.now()

	frame_loop: for {
		curr_time := time.now()
		duration := time.diff(prev_time, curr_time)
		delta_time := cast(f32)time.duration_seconds(duration)
		prev_time = curr_time

		win32.poll_events_this_frame()
		for event in platform.events_this_frame {
			#partial switch data in event {
			case platform.Event_Window_Close:
				break frame_loop
			case platform.Event_Mouse_Button:
				if data.state == .Press do fmt.printfln("pressed")
				if data.state == .Release do fmt.printfln("released")
			}
		}

		to_update(delta_time)
	}
}

@(export) //link_name="NvOptimusEnablement"
NvOptimusEnablement: u32 = 1
@(export) //link_name="AmdPowerXpressRequestHighPerformance"
AmdPowerXpressRequestHighPerformance: i32 = 1

draw_fps :: proc(font: render.Font, pos: [2]f32, font_size: f32, delta_time: f32) {
	@(static) elapsed_time: f32
	@(static) fps: u32

	@(static) fps_buf: [32]u8
	@(static) fps_str: string

	for elapsed_time >= 1. {
		fps_str = fmt.bprintf(fps_buf[:], "FPS: %v", fps)

		elapsed_time -= 1.
		fps = 0
	}

	render.imm_push_text(font, fps_str, pos, font_size, {1, 1, 0, 1})

	elapsed_time += delta_time
	fps += 1
}

torture_test0 :: proc(font: render.Font, delta_time: f32) {
	@(static) time_elapsed: f32
	time_elapsed += delta_time

	client_size := linalg.to_f32(win32.get_client_size())
	mouse_pos := linalg.to_f32(win32.get_mouse_pos())

	center := client_size * 0.5

	// Draws a massive grid of pulsing, rounded rectangles.
	grid_size := client_size / 30
	spacing :: 30.0
	rect_size :: 20.0

	start := center - (grid_size * spacing) * 0.5

	for y in 0 ..< grid_size.y {
		for x in 0 ..< grid_size.x {
			xf := cast(f32)x
			yf := cast(f32)y

			wave := math.sin(time_elapsed * 2.0 + (xf * 0.2) + (yf * 0.2))

			pos := [2]f32 {
				start.x + xf * spacing + (wave * 10.0),
				start.y + yf * spacing + (math.cos(time_elapsed + xf * 0.3) * 10.0),
			}

			size := [2]f32{rect_size + (wave * 5.0), rect_size + (wave * 5.0)}
			radius := (rect_size * 0.5) * (wave * 0.5 + 0.5)

			color := [4]f32 {
				0.5 + 0.5 * math.sin(time_elapsed + xf * 0.1),
				0.5 + 0.5 * math.cos(time_elapsed + yf * 0.1),
				0.8,
				0.4, // forces heavy blending work on the GPU
			}

			render.imm_push_rect(pos, size, color, radius)
		}
	}

	// Pushes floating text that scales up and down
	str_count :: 30
	for i in 0 ..< str_count {
		f_i := cast(f32)i
		angle := time_elapsed * 0.5 + (f_i * 0.5)
		dist := 150.0 + math.sin(time_elapsed * 1.5 + f_i) * 100.0

		txt_x := center.x + math.cos(angle) * dist
		txt_y := center.y + math.sin(angle) * dist

		txt_size := 36.0 + math.sin(time_elapsed * 3.0 + f_i) * 28.0

		color := [4]f32{1.0, f_i / cast(f32)str_count, 0.2, 1.0}

		render.imm_push_text(font, "Bu benden sana gelsin", {txt_x, txt_y}, txt_size, color)
	}
}
