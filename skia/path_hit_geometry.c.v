module skia

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

struct C.VoxPathHitTest {
	path        C.VoxCanvasPath
	x           f32
	y           f32
	width       f32
	miter       f32
	transform   [6]f32
	cap         i32
	join        i32
	areas       i32
	non_scaling i32
	dashes      &f32
	dash_count  i32
	dash_offset f32
}

fn C.vox_skia_path_hit_test(&C.VoxPathHitTest) bool

pub fn path_hit_test(query PathHitTest) bool {
	if query.path.segments.len == 0 || query.path.segments.len % 12 != 0 || query.areas == 0 {
		return false
	}
	return C.vox_skia_path_hit_test(&C.VoxPathHitTest{
		path:        native_path(query.path)
		x:           query.x
		y:           query.y
		width:       query.width
		miter:       query.miter
		transform:   query.transform
		cap:         i32(query.cap)
		join:        i32(query.join)
		areas:       i32(query.areas)
		non_scaling: i32(query.non_scaling)
		dashes:      query.dashes.data
		dash_count:  i32(query.dashes.len)
		dash_offset: query.dash_offset
	})
}
