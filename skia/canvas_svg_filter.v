module skia

// Acyclic SVG filter inputs use -1 for the preceding CSS filter's output.
// Node order and repeated inputs are significant (in particular for feMerge).
pub enum SvgFilterNodeKind {
	blur
	erode
	dilate
	merge
	offset
	to_linear_rgb
	to_srgb
	color_matrix
}

pub struct SvgFilterNode {
pub:
	kind   SvgFilterNodeKind
	inputs []int
	x      f32
	y      f32
	matrix [20]f32
}

pub struct SvgFilterGraph {
pub:
	nodes            []SvgFilterNode
	root             int    = -1
	region           [4]f32
	object_bounds    bool   = true
	primitive_bounds bool
}
