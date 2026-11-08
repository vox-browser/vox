module main

import gg
import os
import sokol.sapp

struct WindowsGraphicsSmoke {
mut:
	ctx &gg.Context = unsafe { nil }
}

fn main() {
	mut state := &WindowsGraphicsSmoke{}
	state.ctx = gg.new_context(
		width:        320
		height:       240
		window_title: 'Vox Windows graphics smoke'
		bg_color:     gg.white
		init_fn:      fn (mut state WindowsGraphicsSmoke) {
			configure_windows_browser_renderer(state.ctx)
		}
		frame_fn:     fn (mut state WindowsGraphicsSmoke) {
			begin_browser_frame(state.ctx)
			state.ctx.draw_rect_filled(20, 30, 80, 50, gg.red)
			state.ctx.draw_rect_filled(180, 130, 60, 70, gg.blue)
			state.ctx.draw_text(20, 100, 'Windows', color: gg.black, size: 20)
			end_browser_frame(state.ctx)
			if state.ctx.frame >= 2 {
				sapp.screenshot_png(os.args[1]) or { panic(err) }
				println('Windows GG projection, color and text smoke: captured')
				exit(0)
			}
		}
		user_data:    state
	)
	state.ctx.run()
}
