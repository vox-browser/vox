module layout

import math
import painting

// Paint-containment fragments snap from the outer fragment inward. Carry the
// resulting translation separately so the DOM/layout rectangles stay exact.
fn chromium_contained_image_paint_adjustment(node &Node, state &LayoutState) painting.Point {
	parent := node.parent() or { return painting.Point{} }
	return chromium_contained_fragment_adjustment(parent, state)
}

// A fragment's overflow clip shares its own snapped origin; image content uses
// the fragment established by its ancestors.
fn chromium_contained_fragment_adjustment(node &Node, state &LayoutState) painting.Point {
	if node.document().font_rendering_policy() != .chromium { return painting.Point{} }
	mut origins := []painting.Point{}
	mut seen := map[u64]bool{}
	mut parent := node
	for {
		key := u64(voidptr(parent))
		if key in seen { return painting.Point{} }
		seen[key] = true
		if styled := parent.as_node_with_style() {
			if parent.has_paint_containment() {
				if used := state.try_get(styled) {
					position := paint_cumulative_offset(parent, state, used)
					origins << painting.Point{
						x: position.x().to_double() - used.padding_left.to_double() - used.border_left.to_double()
						y: position.y().to_double() - used.padding_top.to_double() - used.border_top.to_double()
					}
				}
			}
		}
		parent = parent.parent() or { break }
	}
	mut adjustment := painting.Point{}
	for index := origins.len - 1; index >= 0; index-- {
		origin := origins[index]
		adjustment = painting.Point{
			x: math.floor(origin.x + adjustment.x + .5) - origin.x
			y: math.floor(origin.y + adjustment.y + .5) - origin.y
		}
	}
	return adjustment
}
