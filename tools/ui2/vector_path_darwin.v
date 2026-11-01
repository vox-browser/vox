// vfmt off
module ui2

$if !ui2_custom_rendering ? {
	#flag darwin -framework QuartzCore
	#include "@VMODROOT/vox/vector_path_darwin.h"
	fn C.ui2_embedded_vector_path(view voidptr, points &f64, count i32, closed bool, fill_enabled bool, fill u32, stroke u32, line_width f64)

	fn apply_embedded_vector_path(native NativeView, element Element) {
		path := element.vector
		// VectorPoint is two contiguous f64 coordinates; the native call copies them.
		C.ui2_embedded_vector_path(native, unsafe { &f64(path.points.data) }, i32(path.points.len), path.closed,
			path.fill_enabled, path.fill, path.stroke, path.stroke_width)
	}
}
