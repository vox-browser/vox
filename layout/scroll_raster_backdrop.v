module layout

import math
import os

// Same-binary control: keep complete replay for every list with a backdrop
// filter, as before.
pub const retain_backdrop_raster_rejection = os.getenv('VOX_RETAIN_BACKDROP_RASTER_REJECTION') != ''

// A backdrop filter reads the pixels painted before it within its border box
// and the filter's kernel around it, and writes inside the border box. Its
// key ink is that read region, so the retained-raster diff repaints the whole
// region whenever the filter or anything it reads changes
// (scroll/raster_backdrop_damage.v extends the damage to it), and a clipped
// replay then paints everything the filter samples afresh, in paint order.
pub fn scroll_raster_backdrop_filter_extent(command &PaintCommand) ?f64 {
	filter := command.backdrop_filter_data or { return none }
	if filter.nodes.len > 0 || filter.root_id != none { return none }
	mut extent := 0.0
	for operation in filter.operations {
		for value in [operation.first, operation.second, operation.third] {
			if math.is_nan(value) || math.is_inf(value, 0) { return none }
		}
		match operation.kind {
			'blur' {
				if operation.first < 0 { return none }
				extent += operation.first * 3.0
			}
			'drop-shadow' {
				extent += math.abs(operation.first) + math.abs(operation.second)
					+ math.max(operation.third, 0.0) * 3.0
			}
			'color', 'hue-rotate', 'grayscale', 'sepia', 'saturate', 'brightness', 'contrast',
			'invert', 'opacity' {}
			else { return none }
		}
	}
	return extent + 1.0
}

fn scroll_raster_backdrop_read_bounds(command &PaintCommand) ?LayoutRect {
	extent := scroll_raster_backdrop_filter_extent(command)?
	// The kernel is applied in device space: scale it by the transform, and
	// once more for a recording made in CSS pixels at a device scale.
	matrix := normalized_affine(command.transform)
	scale := math.max(1.0, math.max(math.sqrt(matrix[0] * matrix[0] + matrix[1] * matrix[1]),
		math.sqrt(matrix[2] * matrix[2] + matrix[3] * matrix[3])))
	margin := extent * scale * 2.0
	if math.is_nan(margin) || math.is_inf(margin, 0) { return none }
	source := PaintCommand{
		kind:      'fill_rect'
		x:         command.x
		y:         command.y
		width:     command.width
		height:    command.height
		transform: command.transform
	}
	bounds := effect_leaf_ink_bounds_with_precision_guard(&source, true)?
	return LayoutRect{bounds.x - margin, bounds.y - margin, bounds.width + margin * 2,
		bounds.height + margin * 2}
}
