package render

import "../platform"
import "../platform/win32"
import "core:math/linalg"
import "core:sys/windows"

point_within_rect :: proc(p: [2]f32, pos, size: [2]f32) -> bool {
	if p.x > pos.x && p.y > pos.y {
		br := pos + size
		if p.x < br.x && p.y < br.y {
			return true
		}
		return false
	}
	return false
}

_UI_Widget_Flags :: enum {
	Clickable,
	// ViewScroll,
	DrawText,
	// DrawBorder,
	DrawBackground,
	// DrawDropShadow,
	// Clip,
	// HotAnimation,
	// ActiveAnimation,
}
UI_Widget_Flags :: bit_set[_UI_Widget_Flags]

UI_Action :: struct {
	hovered: bool,
	clicked: bool,
}

ui_widget_base :: proc(text: string, pos: [2]f32, flags: UI_Widget_Flags) -> UI_Action {
	bbox := text_bbox(_font, text, _font_size)
	mouse_pos := cast([2]f32)win32.get_mouse_pos()

	bbox_rect := bbox + _PADDING * 2
	text_pos := pos + _PADDING

	hovered := point_within_rect(mouse_pos, pos, bbox_rect)
	pressed := hovered && platform.mouse_is_down(.Left)
	clicked := hovered && platform.mouse_is_released(.Left)

	if .DrawBackground in flags {
		tcol := _DARK_GRAY
		bcol := _DARK_GRAY

		if .Clickable in flags {
			if pressed {
				tcol = _DARKER_GRAY
				bcol = _DARKER_GRAY
			} else if hovered {
				tcol = _LIGHT_GRAY
				bcol = _DARK_GRAY
			}
		} else {
			tcol = _DARKER_GRAY
			bcol = _DARKER_GRAY
		}

		imm_push_rect_grad(pos, bbox_rect, tcol, tcol, bcol, bcol, _ROUNDNESS)
	}

	if .DrawText in flags {
		imm_push_text(_font, text, text_pos, _font_size, _ALMOST_WHITE)
	}

	return {hovered = hovered, clicked = .Clickable in flags ? clicked : false}
}

ui_button :: #force_inline proc(text: string, pos: [2]f32) -> UI_Action {
	return ui_widget_base(text, pos, {.Clickable, .DrawBackground, .DrawText})
}
ui_label :: #force_inline proc(text: string, pos: [2]f32) -> UI_Action {
	return ui_widget_base(text, pos, {.DrawText})
}
ui_panel :: #force_inline proc(text: string, pos: [2]f32) -> UI_Action {
	return ui_widget_base(text, pos, {.DrawBackground, .DrawText})
}

ui_begin_frame :: proc(font: Font) {
	_font = font
}
ui_end_frame :: proc() {
}
@(deferred_out = ui_end_frame)
UI_FRAME_SCOPED :: #force_inline proc(font: Font) {
	ui_begin_frame(font)
}

/*
*
*/

_ROUNDNESS :: 6
_PADDING :: [2]f32{6, 2}

_DARK_GRAY :: RGBA32{55, 55, 55, 255}
_LIGHT_GRAY :: RGBA32{85, 85, 85, 255}
_DARKER_GRAY :: RGBA32{35, 35, 35, 255}
_ALMOST_WHITE :: RGBA32{245, 245, 245, 255}

_font: Font
_font_size := f32(18)

_idle_bg_col := _DARK_GRAY
_pressed_bg_col := _DARKER_GRAY
_hover_bg_top_col := _LIGHT_GRAY
_hover_bg_btm_col := _DARK_GRAY

ui_to_test :: proc(font: Font) {
	UI_FRAME_SCOPED(font)

	@(static) did := false
	if ui_button("Continue", {100, 40}).clicked {
		did = !did
	}

	if did {
		ui_label("Press", {100, 80})
		ui_button("Handling...", {100, 120})
	}

	ui_panel("Yer Seviyesi", {100, 160})
	ui_button("Basma Bana", {100, 200})
}

/*
*
draw_button_flat_dark :: proc(font: Font, text: string, pos: [2]f32, font_size: f32) -> bool {
	IDLE :: RGBA32{60, 60, 60, 255}
	HOVER :: RGBA32{85, 85, 85, 255}
	PRESSED :: RGBA32{40, 40, 40, 255}
	LABEL :: RGBA32{245, 245, 245, 255}

	bbox := text_bbox(font, text, font_size)
	mouse_pos := cast([2]f32)win32.get_mouse_pos()

	bbox_rect := bbox + _PAD * 2
	text_pos := pos + _PAD

	hover := point_within_rect(mouse_pos, pos, bbox_rect)
	pressed := hover && platform.mouse_is_down(.Left) // its just for rendering. in logic wise, button must fire when release

	if pressed {
		imm_push_rect_grad(pos, bbox_rect, PRESSED, PRESSED, PRESSED, PRESSED, 8)
	} else if hover {
		imm_push_rect_grad(pos, bbox_rect, HOVER, HOVER, IDLE, IDLE, 8)
	} else {
		imm_push_rect_grad(pos, bbox_rect, IDLE, IDLE, IDLE, IDLE, 8)
	}

	imm_push_text(font, text, text_pos, font_size, LABEL)

	return hover && platform.mouse_is_released(.Left)
}
*/

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
