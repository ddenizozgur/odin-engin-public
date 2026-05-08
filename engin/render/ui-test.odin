package render

import "../platform/win32"
import "core:math/linalg"
import "core:sys/windows"

point_within_rect :: proc(p: [2]f32, pos, size: [2]f32) -> bool {
	if p.x > pos.x && p.y > pos.y {
		tmp := pos + size
		if p.x < tmp.x && p.y < tmp.y {
			return true
		}
		return false
	}
	return false
}

_lb_press :: proc() -> bool {
	return cast(u16)windows.GetAsyncKeyState(windows.VK_LBUTTON) & 0x8000 != 0
}

PAD :: [2]f32{6, 2}

draw_button_flat_dark :: proc(font: Font, text: string, pos: [2]f32, font_size: f32) -> bool {
	IDLE :: RGBA32{60, 60, 60, 255}
	HOVER :: RGBA32{85, 85, 85, 255}
	PRESSED :: RGBA32{40, 40, 40, 255}
	LABEL :: RGBA32{245, 245, 245, 255}

	bbox := text_bbox(font, text, font_size)
	mouse_pos := cast([2]f32)win32.get_mouse_pos()

	bbox_rect := bbox + PAD * 2
	text_pos := pos + PAD

	hover := point_within_rect(mouse_pos, pos, bbox_rect)
	pressed := hover && _lb_press() // its just for rendering. in logic wise, button must fire when release

	if pressed {
		imm_push_rect_grad(pos, bbox_rect, PRESSED, PRESSED, PRESSED, PRESSED, 8)
	} else if hover {
		imm_push_rect_grad(pos, bbox_rect, HOVER, HOVER, IDLE, IDLE, 8)
	} else {
		imm_push_rect_grad(pos, bbox_rect, IDLE, IDLE, IDLE, IDLE, 8)
	}

	imm_push_text(font, text, text_pos, font_size, LABEL)

	return pressed// && _lb_release()
}

ui_to_test :: proc(font: Font) {
	@(static) did := false

	if draw_button_flat_dark(font, "Continue", {100, 40}, 18) {
		did = !did
	}

	if did {
		draw_button_flat_dark(font, "Press", {100, 80}, 18)
		draw_button_flat_dark(font, "Handling...", {100, 120}, 18)
	}

	draw_button_flat_dark(font, "Yer Seviyesi", {100, 160}, 18)
	draw_button_flat_dark(font, "Basma Bana", {100, 200}, 18)
}

/*
draw_button_gradient_vertical :: proc(font: Font, text: string, pos: [2]f32, font_size: f32) {
	TOP :: RGBA32{100, 200, 255, 255} // sky blue
	BOT :: RGBA32{20, 80, 200, 255} // deep blue
	LABEL :: RGBA32{255, 255, 255, 255}

	PAD :: [2]f32{6, 0}
	bbox := text_bbox(font, text, font_size)
	mouse_pos := cast([2]f32)win32.get_mouse_pos()

	if point_within_rect(mouse_pos, pos, bbox) {
		imm_push_rect_grad(pos, bbox + PAD * 2, BOT, BOT, TOP, TOP, 8)
	} else {
		imm_push_rect_grad(pos, bbox + PAD * 2, TOP, TOP, BOT, BOT, 8)
	}

	imm_push_text(font, text, pos + PAD, font_size, LABEL)
}

draw_button_gradient_diagonal :: proc(font: Font, text: string, pos: [2]f32, font_size: f32) {
	TL :: RGBA32{255, 100, 150, 255} // rose
	TR :: RGBA32{255, 180, 60, 255} // amber
	BL :: RGBA32{200, 60, 200, 255} // purple
	BR :: RGBA32{255, 120, 60, 255} // orange
	LABEL :: RGBA32{255, 255, 255, 255}

	PAD :: [2]f32{6, 0}
	bbox := text_bbox(font, text, font_size)

	imm_push_rect_grad(pos, bbox + PAD * 2, TL, TR, BL, BR, 10)
	imm_push_text(font, text, pos + PAD, font_size, LABEL)
}

draw_button_pill :: proc(font: Font, text: string, pos: [2]f32, font_size: f32) {
	TOP :: RGBA32{80, 220, 160, 255} // mint green
	BOT :: RGBA32{20, 160, 90, 255}
	LABEL :: RGBA32{255, 255, 255, 255}

	PAD :: [2]f32{6, 3}
	bbox := text_bbox(font, text, font_size)

	imm_push_rect_grad(pos, bbox + PAD * 2, TOP, TOP, BOT, BOT, 10)
	imm_push_text(font, text, pos + PAD, font_size, LABEL)
}

draw_button_gradient_border :: proc(font: Font, text: string, pos: [2]f32, font_size: f32) {
	FRAME_TL :: RGBA32{255, 80, 200, 255} // hot pink
	FRAME_BR :: RGBA32{80, 80, 255, 255} // violet
	INNER :: RGBA32{12, 12, 20, 255} // near-black fill
	LABEL :: RGBA32{255, 255, 255, 255}
	BORDER :: f32(2)

	PAD :: [2]f32{6, 4}
	bbox := text_bbox(font, text, font_size)

	imm_push_rect_grad(pos, bbox + PAD * 2, FRAME_TL, FRAME_TL, FRAME_BR, FRAME_BR, 10)
	imm_push_rect(pos + BORDER, bbox + PAD * 2 - BORDER * 2, INNER, 8)
	imm_push_text(font, text, pos + PAD, font_size, LABEL)
}
*/
