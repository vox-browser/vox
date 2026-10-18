module layout

import math
import svg

fn test_chromium_viewbox_alignment_retains_fractional_container_precision() {
	viewbox := svg.ViewBox{
		width:  139
		height: 150
	}
	transform := chromium_scale_and_align_viewbox_content(svg.PreserveAspectRatio{}, viewbox, 80,
		86.328125)
	assert transform.scale_factor_x == 86.328125 / 150
	assert transform.scale_factor_x == transform.scale_factor_y
	assert math.abs(transform.offset.x - 0.00130208333333) < 1e-12
	assert math.abs(transform.offset.y) < 1e-12
	stretched := chromium_scale_and_align_viewbox_content(svg.PreserveAspectRatio{ align: .none_ },
		viewbox, 80, 86)
	assert stretched.scale_factor_x == f64(80) / 139
	assert stretched.scale_factor_y == f64(86) / 150
	assert stretched.offset == svg.Point{}
}
