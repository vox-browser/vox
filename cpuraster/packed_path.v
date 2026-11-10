module cpuraster

// A canvas or SVG path packed as LibGfx segments, twelve floats each: the
// verb, the end point, then control points and arc parameters.
pub struct PackedPath {
pub:
	segments []f32
	even_odd bool
}

pub fn (p PackedPath) path() Path {
	return canvas_path(p.segments, p.even_odd)
}

// Geometry queries share Canvas replay's path decoder, caps and joins. Paint
// colors and opacity are deliberately absent: the caller selects hit regions.
pub struct PackedPathHitTest {
pub:
	path        PackedPath
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

pub fn packed_path_hit_test(query PackedPathHitTest) bool {
	if query.path.segments.len == 0 || query.path.segments.len % 12 != 0 || query.areas == 0 {
		return false
	}
	return path_hit_test(PathHitTest{
		path:        query.path.path()
		x:           query.x
		y:           query.y
		areas:       query.areas
		width:       query.width
		miter:       query.miter
		cap:         if query.cap == 0 {
			StrokeCap.butt
		} else if query.cap == 1 {
			StrokeCap.round
		} else {
			StrokeCap.square
		}
		join:        if query.join == 0 {
			StrokeJoin.round
		} else if query.join == 1 {
			StrokeJoin.bevel
		} else {
			StrokeJoin.miter
		}
		dashes:      query.dashes
		dash_offset: query.dash_offset
		non_scaling: query.non_scaling
		transform:   query.transform
	})
}
