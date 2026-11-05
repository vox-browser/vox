module html

import math
import svg

fn test_svg_float_path_keeps_the_rounded_current_point_through_axis_lines_and_close() {
	path := svg.parse_path_data('M40.1 30.3 h.1 v.2 l.1 .2 z l.1 .2')
	precise := canvas_gfx_path_from_svg_path_with_precision(path, true).segments()
	assert precise[1].point == FloatPoint{40.19999694824219, 30.299999237060547}
	assert precise[2].point == FloatPoint{40.19999694824219, 30.5}
	assert precise[3].point == FloatPoint{40.29999542236328, 30.700000762939453}
	assert precise[5].point == FloatPoint{40.19999694824219, 30.5}
	ordinary := canvas_gfx_path_from_svg_path(path).segments()
	assert ordinary[1].point.x == 40.2
	assert ordinary[3].point.x > precise[3].point.x
	assert ordinary[5].point.x == 40.2
}

fn test_svg_float_curves_keep_both_controls_and_reflect_after_rounding() {
	path := svg.parse_path_data('M40.1 30.3 c.1 .2 .2 .3 .3 .4 s.2 .3 .3 .4 q.1 .2 .3 .4 t.3 .4')
	segments := canvas_gfx_path_from_svg_path_with_precision(path, true).segments()
	assert segments[1].control_point_0 == FloatPoint{40.19999694824219, 30.5}
	assert segments[1].control_point_1 == FloatPoint{40.29999923706055, 30.599998474121094}
	assert segments[1].point == FloatPoint{40.39999771118164, 30.69999885559082}
	assert segments[2].control_point_0 == FloatPoint{40.499996185302734, 30.799999237060547}
	assert segments[2].point == FloatPoint{40.69999694824219, 31.099998474121094}
	assert segments[3].control_point_0 == FloatPoint{40.79999542236328, 31.299999237060547}
	assert segments[4].control_point_0 == FloatPoint{41.19999694824219, 31.699996948242188}
	assert segments[4].point == FloatPoint{41.29999542236328, 31.89999771118164}
}

fn test_svg_float_operands_round_absolute_points_and_arcs_without_changing_path2d() {
	path := svg.parse_path_data('M40.1 30.3 A3.1 4.2 30.1 0 1 60.3 50.4 M80.1 20.3 s.1 .2 .3 .4')
	segments := canvas_gfx_path_from_svg_path_with_precision(path, true).segments()
	assert segments[0].point == FloatPoint{40.099998474121094, 30.299999237060547}
	assert segments[1].radii == FloatSize{3.0999999046325684, 4.199999809265137}
	assert segments[1].x_axis_rotation == 30.100000381469727 * math.pi / 180.0
	assert segments[1].point == FloatPoint{60.29999923706055, 50.400001525878906}
	assert segments[3].control_point_0 == segments[2].point
	ordinary := Path2D.create_from_svg_path_data('M40.1 30.3 l.1 .2').path().segments()
	assert ordinary[0].point == FloatPoint{40.1, 30.3}
	assert ordinary[1].point == FloatPoint{40.2, 30.5}
}
