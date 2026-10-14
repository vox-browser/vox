module main

import gg

fn test_native_paint_fallbacks_do_not_require_a_gpu_pipeline() {
	$if macos {
		context := gg.new_context(native_rendering: true)
		assert context.pipeline == unsafe { nil }
		begin_browser_frame(context)
		draw_browser_polygon(context, [f32(0), 0, 20, 0, 20, 20], gg.rgba(10, 20, 30, 128))
		for line_type in [gg.PenLineType.solid, .dotted, .dashed] {
			draw_browser_line(context, 0, 0, 20, 10, gg.PenConfig{
				color:     gg.rgba(10, 20, 30, 128)
				thickness: 2
				line_type: line_type
			})
		}
		end_browser_frame(context)
		assert context.pipeline == unsafe { nil }
		assert !context.font_inited
	}
}
