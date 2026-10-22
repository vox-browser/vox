module layout

import painting

// These snapshots are replaced as a unit. Copying a BlockBox keeps the old
// path and hit geometry valid for retained recordings.
pub struct BlockBoxSVGData {
pub:
	has_path     bool
	path         &PaintSVGPathData = unsafe { nil }
	bounding_box painting.Rect
	points       []f64
	fill_color   string
	stroke_color string
	stroke_width f64
}

__global empty_box_svg_path = &PaintSVGPathData{}

pub fn (box &BlockBox) has_svg_path() bool {
	return box.svg_data != unsafe { nil } && box.svg_data.has_path
}

pub fn (box &BlockBox) svg_path() &PaintSVGPathData {
	if box.svg_data != unsafe { nil } && box.svg_data.path != unsafe { nil } {
		return box.svg_data.path
	}
	return empty_box_svg_path
}

fn normalized_box_svg_path(path &PaintSVGPathData) &PaintSVGPathData {
	if gradients := path.svg_gradient_data {
		if gradients.fill_linear_gradient == none && gradients.stroke_linear_gradient == none
			&& gradients.fill_radial_gradient == none && gradients.stroke_radial_gradient == none {
			snapshot := *path
			return &PaintSVGPathData{ ...snapshot, svg_gradient_data: none }
		}
	}
	return path
}
