package main

import "base:runtime"
import "core:fmt"
import "core:math"
import "core:math/linalg"
import "core:sys/windows"
import "core:time"

import "engin/platform"
import "engin/platform/win32"
import "engin/render"

/*
*
*/

font: render.Font

to_update :: proc(dt: f32) -> bool {
	@(static) initted := false
	if (!initted) {
		defer initted = true

		runtime.DEFAULT_TEMP_ALLOCATOR_TEMP_GUARD()

		json_path, png_path := render.msdf_atlas_gen(
			"resource/fonts/VarelaRound-Regular.ttf",
			allocator = context.temp_allocator,
		) or_return

		font = render.msdf_load_from_file(json_path, png_path) or_return
	}

	@(static) et: f32
	defer et += dt

	client_size := linalg.to_f32(win32.get_client_size())
	mouse_pos := linalg.to_f32(win32.get_mouse_pos())

	{
		render.IMM_FRAME_SCOPED()

		aurora_bg(et)
		// render.clear_target(render.NAYSAYER_BG)

		torture_test_liquid_neon(font, et)

		// render.ui_to_test(font)

		draw_some_text(font, {0, 0}, 1, render.RAYWHITE)

		draw_fps(font, {client_size.x, 0}, 20, dt, .TopRight)
	}

	return true
}

main :: proc() {
	win32.set_console_utf8()

	win32.window_init("Kralsın", {1280, 800}, .Windowed)
	defer win32.window_free()

	win32.wgl_init()
	windows.wglSwapIntervalEXT(0)

	render.gl_load_up_to(4, 3)

	prev_time := time.now()

	frame_loop: for {
		curr_time := time.now()
		duration := time.diff(prev_time, curr_time)
		dt := cast(f32)time.duration_seconds(duration)
		prev_time = curr_time
		// print_fps(delta_time)

		win32.poll_events_this_frame()
		for event in platform.events_this_frame {
			#partial switch data in event {
			case platform.Event_Window_Close:
				break frame_loop
			case platform.Event_Mouse_Button:
				if data.state == {.Pressed} do mouse_pressed = true
				if data.state == {.Released} do mouse_pressed = false
			}
		}

		to_update(dt)
	}
}

mouse_pressed := false

@(export) //link_name="NvOptimusEnablement"
NvOptimusEnablement: u32 = 1
@(export) //link_name="AmdPowerXpressRequestHighPerformance"
AmdPowerXpressRequestHighPerformance: i32 = 1

draw_fps :: proc(
	font: render.Font,
	pos: [2]f32,
	font_size: f32,
	dt: f32,
	align_kind := render.Align_Kind.TopLeft,
) {
	@(static) et: f32
	@(static) fps: u32

	@(static) fps_buf: [32]u8
	@(static) fps_str: string

	defer {
		et += dt
		fps += 1
	}

	if et >= 1. {
		fps_str = fmt.bprintf(fps_buf[:], "FPS: %v", fps)

		et -= 1.
		fps = 0
	}

	bounds := render.text_bbox(font, fps_str, font_size)
	real_pos := render.pos_from_align_kind(pos, bounds, align_kind)
	render.imm_push_text(font, fps_str, real_pos, font_size, render.YELLOW)
}

/*
*
*/

draw_some_text :: proc(font: render.Font, pos: [2]f32, scale: f32, color: render.RGBA32) {
	y := pos.y

	for i in 0 ..= 32 {
		font_size := (cast(f32)i + 4) * scale
		font_scale := font_size / font.metrics.emSize
		line_h := font.metrics.lineHeight * font_scale
		defer y += line_h

		{
			runtime.DEFAULT_TEMP_ALLOCATOR_TEMP_GUARD()

			render.imm_push_text(
				font,
				"The quick brown fox jumps over the lazy dog",
				{pos.x, y},
				font_size,
				color,
			)
		}
	}
}

aurora_bg :: proc(et: f32) {
	client := linalg.to_f32(win32.get_client_size())

	s1 := math.sin_f32(et * 0.15)
	s2 := math.cos_f32(et * 0.22)
	s3 := math.sin_f32(et * 0.18 + 1.0)
	s4 := math.cos_f32(et * 0.12 + 2.0)

	tl := [4]f32{0.10 + 0.05 * s1, 0.02, 0.25 + 0.1 * s2, 1.0}
	tr := [4]f32{0.30 + 0.10 * s3, 0.05, 0.15, 1.0}
	bl := [4]f32{0.02, 0.15 + 0.05 * s4, 0.35 + 0.1 * s1, 1.0}
	br := [4]f32{0.15, 0.05, 0.25 + 0.05 * s2, 1.0}

	render.imm_push_rect_grad(
		{0, 0},
		client,
		render.vec4f32_to_rgba32(tl),
		render.vec4f32_to_rgba32(tr),
		render.vec4f32_to_rgba32(bl),
		render.vec4f32_to_rgba32(br),
	)
}

torture_test_liquid_neon :: proc(font: render.Font, et: f32) {
	client_size := linalg.to_f32(win32.get_client_size())

	cols := 40
	rows := 25
	cell_w := client_size.x / cast(f32)cols
	cell_h := client_size.y / cast(f32)rows

	color_at :: proc(nx, ny, t: f32) -> [4]f32 {
		v1 := math.sin(nx * 10.0 + t * 1.5)
		v2 := math.sin(ny * 8.0 - t * 1.2)
		v3 := math.sin((nx + ny) * 12.0 + t)

		dx := nx - 0.5
		dy := ny - 0.5
		dist := math.sqrt(dx * dx + dy * dy)
		v4 := math.cos(dist * 20.0 - t * 3.0)

		sum := (v1 + v2 + v3 + v4) * 0.25

		r := 0.6 + 0.4 * math.sin(sum * math.PI + 0.0)
		g := 0.3 + 0.3 * math.sin(sum * math.PI + 2.0)
		b := 0.8 + 0.2 * math.sin(sum * math.PI + 4.0)

		return {r, g, b, 1.0}
	}

	for y in 0 ..< rows {
		for x in 0 ..< cols {
			xf := cast(f32)x
			yf := cast(f32)y

			nx0 := xf / cast(f32)cols
			ny0 := yf / cast(f32)rows
			nx1 := (xf + 1.0) / cast(f32)cols
			ny1 := (yf + 1.0) / cast(f32)rows

			c0 := color_at(nx0, ny0, et)
			c1 := color_at(nx1, ny0, et)
			c2 := color_at(nx0, ny1, et)
			c3 := color_at(nx1, ny1, et)

			base_pos := [2]f32{xf * cell_w, yf * cell_h}

			pulse := math.sin(et * 3.0 + c0.r * 5.0)
			scale := 0.60 + (0.40 * pulse)

			size := [2]f32{cell_w * scale, cell_h * scale}

			offset := [2]f32{cell_w * (1.0 - scale) * 0.5, cell_h * (1.0 - scale) * 0.5}

			roundness := (cell_w * 0.5) * scale

			render.imm_push_rect_grad(
				base_pos + offset,
				size,
				render.vec4f32_to_rgba32(c0),
				render.vec4f32_to_rgba32(c1),
				render.vec4f32_to_rgba32(c2),
				render.vec4f32_to_rgba32(c3),
				roundness,
			)
		}
	}

	TEXT_SIZE :: 20
	text := "Benden Sana Gelsin"
	text_bbox := render.text_bbox(font, text, TEXT_SIZE)

	box_pos := render.pos_from_align_kind(
		client_size,
		render.text_bbox(font, text, TEXT_SIZE),
		.BottomRight,
	)

	bg_dark := [4]f32{0.05, 0.05, 0.08, 0.85}
	render.imm_push_rect(
		box_pos,
		text_bbox,
		{render.BLACK.x, render.BLACK.y, render.BLACK.z, 0x55},
		8.0,
	)

	render.imm_push_text(font, "Benden Sana Gelsin", box_pos, TEXT_SIZE, render.WHITE)
}
