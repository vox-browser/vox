module main

fn C.native_rect_prefetch_scratch_enabled() int
fn C.native_begin_rect_prefetch_scratch(&C.VoxGraphiteShape, int, f32, f32, f32, f32) int
fn C.native_append_rect_prefetch_scratch(int) int
fn C.native_finish_rect_prefetch_scratch(int) int

fn (mut app BrowserApp) prefetch_chromium_rect_scratch(shapes []C.VoxGraphiteShape,
	start int, end int, page_y f32) {
	$if macos {
		if C.native_begin_rect_prefetch_scratch(shapes.data, shapes.len, 0, page_y,
			f32(app.ctx.width), f32(app.ctx.height)) == 0 {
			return
		}
		mut commit := 0
		defer { C.native_finish_rect_prefetch_scratch(commit) }
		mut shape_index := 0
		for index in start .. end {
			command := app.paint_commands[index]
			if command.kind == 'fill_rect' {
				if C.native_append_rect_prefetch_scratch(shape_index) == 0 { return }
				shape_index++
			} else {
				// This is the same text replay, with its normal clips and glyph flags.
				// It changes only the private bitmap. The real command is drawn later.
				app.draw_command(command, 0, page_y, app.ctx.height)
			}
		}
		commit = 1
	}
}
