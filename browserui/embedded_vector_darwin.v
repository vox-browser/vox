module browserui

import ui2

$if vox_ui2 && !ui2_custom_rendering ? {
	// Reuse UI2's AppKit vector primitive for an existing embedded control.
	// The backend copies the coordinates into a native path before returning.
	fn C.ui2_embedded_vector_path(view voidptr, points &f64, count i32, closed bool, fill_enabled bool, fill u32, stroke u32, line_width f64)

	fn update_embedded_vector_path(id string, path ui2.VectorPath) {
		view := ui2.embedded_browser_control(id)
		if view == unsafe { nil } { return }
		C.ui2_embedded_vector_path(view, unsafe { &f64(path.points.data) }, i32(path.points.len),
			path.closed, path.fill_enabled, path.fill, path.stroke, path.stroke_width)
	}
}
