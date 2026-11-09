module skia

import cpuraster

// Geometry queries share Canvas replay's path decoder, caps and joins. Paint
// colors and opacity are deliberately absent: the caller selects hit regions.
pub struct PathHitTest {
pub:
	path        Path
	x           f32
	y           f32
	areas       u8 = 3 // fill = 1, stroke = 2
	width       f32
	cap         int // butt = 0, round = 1, square = 2
	join        int = 2 // round = 0, bevel = 1, miter = 2
	miter       f32 = 4
	dashes      []f32
	dash_offset f32
	non_scaling bool
	transform   [6]f32 = [f32(1), 0, 0, 1, 0, 0]!
}

pub fn path_hit_test(query PathHitTest) bool {
	if query.path.segments.len == 0 || query.path.segments.len % 12 != 0 || query.areas == 0 {
		return false
	}
	return cpuraster.path_hit_test(cpuraster.PathHitTest{
		path:        cpuraster.canvas_path(query.path.segments, query.path.even_odd)
		x:           query.x
		y:           query.y
		areas:       query.areas
		width:       query.width
		miter:       query.miter
		cap:         if query.cap == 0 {
			cpuraster.StrokeCap.butt
		} else if query.cap == 1 {
			cpuraster.StrokeCap.round
		} else {
			cpuraster.StrokeCap.square
		}
		join:        if query.join == 0 {
			cpuraster.StrokeJoin.round
		} else if query.join == 1 {
			cpuraster.StrokeJoin.bevel
		} else {
			cpuraster.StrokeJoin.miter
		}
		dashes:      query.dashes
		dash_offset: query.dash_offset
		non_scaling: query.non_scaling
		transform:   query.transform
	})
}
