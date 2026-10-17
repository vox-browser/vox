module layout

import css
import math

// SVGRootPainter::TransformToPixelSnappedBorderBox rounds the outer CSS
// border-box origin before entering SVG user space. Keep padding/borders and
// nested SVG transforms fractional, and leave committed layout unchanged.
fn svg_root_position_for_paint(root &Node, state &LayoutState, used &UsedValues) css.CSSPixelPoint {
	position := paint_cumulative_offset(root, state, used)
	if root.document().font_rendering_policy() != .chromium { return position }
	inset_x := used.padding_left.to_double() + used.border_left.to_double()
	inset_y := used.padding_top.to_double() + used.border_top.to_double()
	return css.CSSPixelPoint.from_values(
		math.floor(position.x().to_double() - inset_x + 0.5) + inset_x,
		math.floor(position.y().to_double() - inset_y + 0.5) + inset_y)
}
