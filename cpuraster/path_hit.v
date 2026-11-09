module cpuraster

// Geometry-only regions selected by SVG pointer-events. Stroke outlines use
// FillPathWithPaint's identity resolution scale after any non-scaling transform.
pub struct PathHitTest {
pub:
	path        Path
	x           f32
	y           f32
	areas       u8 = 3
	width       f32
	cap         StrokeCap
	join        StrokeJoin = .miter
	miter       f32        = 4
	dashes      []f32
	dash_offset f32
	non_scaling bool
	transform   [6]f32 = [f32(1), 0, 0, 1, 0, 0]!
}

pub fn path_hit_test(query PathHitTest) bool {
	if !is_finite_f32(query.x) || !is_finite_f32(query.y) || query.areas == 0 { return false }
	t := query.transform
	mut path := if query.non_scaling {
		query.path.transform(Matrix{t[0], t[1], t[2], t[3], t[4], t[5]})
	} else {
		query.path
	}
	if query.areas & 1 != 0 && path.contains(query.x, query.y) { return true }
	if query.areas & 2 == 0 || !is_finite_f32(query.width) || query.width <= 0 { return false }
	if path.bounds() == none { return false }
	miter := if query.miter >= 0 { query.miter } else { f32(4) }
	mut filled := false
	if dash := new_dash_effect(query.dashes, query.dash_offset) {
		stroke := DashStroke{
			width:       query.width
			cap:         query.cap
			join:        query.join
			miter_limit: miter
			res_scale:   1
		}
		result := dash_path(path, dash, stroke, none)
		filled = result.fill
		if result.applied { path = result.path }
	}
	if !filled {
		inverse := path.is_inverse_fill()
		outline := stroke_path(path, query.width, query.cap, query.join, miter, 1)
		stroked, _ := outline.transformed(Matrix{})
		path = Path{ ...stroked, fill_type: if inverse { .inverse_winding } else { .winding } }
	}
	return path.contains(query.x, query.y)
}
