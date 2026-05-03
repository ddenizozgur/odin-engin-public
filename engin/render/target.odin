package render

import "../platform/win32"
import "vendor:OpenGL"

/*
*
*/

resize_default_target :: proc() {
	client_size := win32.get_client_size()
	OpenGL.Viewport(0, 0, client_size.x, client_size.y)
}

clear_target :: proc(color: RGBA32) {
	c := rgba32_to_vec4f32(color)
	OpenGL.ClearColor(c.r, c.g, c.b, c.a)

	// OpenGL.Clear(OpenGL.COLOR_BUFFER_BIT | OpenGL.STENCIL_BUFFER_BIT | OpenGL.DEPTH_BUFFER_BIT)
	OpenGL.Clear(OpenGL.COLOR_BUFFER_BIT | OpenGL.DEPTH_BUFFER_BIT)
}

set_target_to_default :: proc() {
	client_size := win32.get_client_size()
	OpenGL.Viewport(0, 0, client_size.x, client_size.y)

	OpenGL.BindFramebuffer(OpenGL.FRAMEBUFFER, 0)
	OpenGL.DrawBuffer(OpenGL.BACK)
}

/*
*
*/

/*
Target :: struct {
	fbo, rbo: u32,
	texture:  Texture,
}

init_render_target :: proc(size: [2]int, filter: Texture_Filter = .LINEAR) -> (Render_Target, bool) {
	fbo: u32
	OpenGL.GenFramebuffers(1, &fbo)
	OpenGL.BindFramebuffer(OpenGL.FRAMEBUFFER, fbo)

	texture := texture_load_from_bytes(nil, size, filter)

	OpenGL.FramebufferTexture2D(
		OpenGL.FRAMEBUFFER,
		OpenGL.COLOR_ATTACHMENT0,
		OpenGL.TEXTURE_2D,
		texture.handle,
		0,
	)

	rbo: u32
	OpenGL.GenRenderbuffers(1, &rbo)
	OpenGL.BindRenderbuffer(OpenGL.RENDERBUFFER, rbo)
	OpenGL.RenderbufferStorage(
		OpenGL.RENDERBUFFER,
		OpenGL.DEPTH24_STENCIL8,
		cast(i32)size.x,
		cast(i32)size.y,
	)

	OpenGL.FramebufferRenderbuffer(
		OpenGL.FRAMEBUFFER,
		OpenGL.DEPTH_STENCIL_ATTACHMENT,
		OpenGL.RENDERBUFFER,
		rbo,
	)

	status := OpenGL.CheckFramebufferStatus(OpenGL.FRAMEBUFFER)
	if status != OpenGL.FRAMEBUFFER_COMPLETE {
		assert(false, "OpenGL.CheckFramebufferStatus(): failed")
		return {}, false
	}

	OpenGL.BindFramebuffer(OpenGL.FRAMEBUFFER, 0)
	OpenGL.BindTexture(OpenGL.TEXTURE_2D, 0)
	OpenGL.BindRenderbuffer(OpenGL.RENDERBUFFER, 0)

	return {fbo = fbo, rbo = rbo, texture = texture}, true
}

set_render_target :: proc(target: Render_Target) {
	OpenGL.BindFramebuffer(OpenGL.FRAMEBUFFER, target.fbo)
	OpenGL.Viewport(0, 0, cast(i32)target.texture.size.x, cast(i32)target.texture.size.y)
}
*/
