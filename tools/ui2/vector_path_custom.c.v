// vfmt off
module ui2

$if (linux || ((macos || windows) && ui2_custom_rendering ?)) && !ui2_headless ? {
	import gg

	@[manualfree]
	fn draw_embedded_vector_path(ctx &gg.Context, path VectorPath, x f64, y f64) {
		if path.points.len < 2 { return }
		fill := gg.rgb(u8(path.fill >> 16), u8(path.fill >> 8), u8(path.fill))
		triangles := path.triangles()
		defer { unsafe { triangles.free() } }
		for i := 0; i + 2 < triangles.len; i += 3 {
			a, b, c := path.points[triangles[i]], path.points[triangles[i+1]], path.points[triangles[i+2]]
			ctx.draw_triangle_filled(f32(x+a.x), f32(y+a.y), f32(x+b.x), f32(y+b.y), f32(x+c.x), f32(y+c.y), fill)
		}
		if path.stroke_width <= 0 { return }
		stroke := gg.rgb(u8(path.stroke >> 16), u8(path.stroke >> 8), u8(path.stroke))
		count := if path.closed { path.points.len } else { path.points.len - 1 }
		for i in 0 .. count {
			a, b := path.points[i], path.points[(i+1) % path.points.len]
			ctx.draw_line_with_config(f32(x+a.x), f32(y+a.y), f32(x+b.x), f32(y+b.y), color: stroke, thickness: f32(path.stroke_width))
		}
	}
}
