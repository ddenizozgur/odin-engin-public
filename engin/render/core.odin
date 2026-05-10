package render

/*
import "base:runtime"
import "core:prof/spall"
import "core:sync"

spall_ctx: spall.Context
@(thread_local)
spall_buff: spall.Buffer

@(init)
spall_init :: proc "contextless" () {
	context = runtime.default_context()

	spall_ctx = spall.context_create("trace-test.spall")

	backing_buff := make([]u8, spall.BUFFER_DEFAULT_SIZE, allocator = context.allocator)
	spall_buff = spall.buffer_create(backing_buff, u32(sync.current_thread_id()))
}

@(instrumentation_enter)
spall_enter :: proc "contextless" (proc_address, call_site_return_address: rawptr, loc: runtime.Source_Code_Location) {
	spall._buffer_begin(&spall_ctx, &spall_buff, "", "", loc)
}

@(instrumentation_exit)
spall_exit :: proc "contextless" (proc_address, call_site_return_address: rawptr, loc: runtime.Source_Code_Location) {
	spall._buffer_end(&spall_ctx, &spall_buff)
}
*/

import "core:math"
import "core:math/linalg"

RGBA32 :: distinct [4]byte

LIGHTGRAY :: RGBA32{200, 200, 200, 255}
GRAY :: RGBA32{130, 130, 130, 255}
DARKGRAY :: RGBA32{80, 80, 80, 255}
YELLOW :: RGBA32{253, 249, 0, 255}
GOLD :: RGBA32{255, 203, 0, 255}
ORANGE :: RGBA32{255, 161, 0, 255}
PINK :: RGBA32{255, 109, 194, 255}
RED :: RGBA32{230, 41, 55, 255}
MAROON :: RGBA32{190, 33, 55, 255}
GREEN :: RGBA32{0, 228, 48, 255}
LIME :: RGBA32{0, 158, 47, 255}
DARKGREEN :: RGBA32{0, 117, 44, 255}
SKYBLUE :: RGBA32{102, 191, 255, 255}
BLUE :: RGBA32{0, 121, 241, 255}
DARKBLUE :: RGBA32{0, 82, 172, 255}
PURPLE :: RGBA32{200, 122, 255, 255}
VIOLET :: RGBA32{135, 60, 190, 255}
DARKPURPLE :: RGBA32{112, 31, 126, 255}
BEIGE :: RGBA32{211, 176, 131, 255}
BROWN :: RGBA32{127, 106, 79, 255}
DARKBROWN :: RGBA32{76, 63, 47, 255}

WHITE :: RGBA32{255, 255, 255, 255}
BLACK :: RGBA32{0, 0, 0, 255}
BLANK :: RGBA32{0, 0, 0, 0}
MAGENTA :: RGBA32{255, 0, 255, 255}
RAYWHITE :: RGBA32{245, 245, 245, 255}

NAYSAYER_BG :: RGBA32{7, 38, 38, 255}

rgba32_to_vec4f32 :: #force_inline proc(c: RGBA32) -> [4]f32 {
	return linalg.to_f32(c) * (1.0 / 255.0)
}

vec4f32_to_rgba32 :: #force_inline proc(v: [4]f32) -> RGBA32 {
	c := linalg.clamp(v, 0.0, 1.0) * 255.0

	bytes := RGBA32 {
		cast(byte)math.round_f32(c.r),
		cast(byte)math.round_f32(c.g),
		cast(byte)math.round_f32(c.b),
		cast(byte)math.round_f32(c.a),
	}

	return bytes
}

/*
*
*/

Align_Kind :: enum {
	TopLeft,
	TopCenter,
	TopRight,
	CenterLeft,
	Center,
	CenterRight,
	BottomLeft,
	BottomCenter,
	BottomRight,
}

pos_from_align_kind :: proc(pos, size: [2]f32, align: Align_Kind) -> [2]f32 {
	real_pos := pos

	switch align {
	case .TopLeft:
	case .TopCenter:
		real_pos.x -= size.x * 0.5
	case .TopRight:
		real_pos.x -= size.x
	case .CenterLeft:
		real_pos.y -= size.y * 0.5
	case .Center:
		real_pos -= size * 0.5
	case .CenterRight:
		real_pos.x -= size.x
		real_pos.y -= size.y * 0.5
	case .BottomLeft:
		real_pos.y -= size.y
	case .BottomCenter:
		real_pos.x -= size.x * 0.5
		real_pos.y -= size.y
	case .BottomRight:
		real_pos -= size
	}

	return real_pos
}

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
