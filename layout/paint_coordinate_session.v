module layout

import css
import platform

struct PaintCoordinateValue {
	position   css.CSSPixelPoint
	absolute_x u64
	absolute_y u64
}

struct PaintCoordinateEntry {
mut:
	owner  voidptr
	value  PaintCoordinateValue
	status u8
}

@[heap]
struct PaintCoordinateSession {
mut:
	entries []PaintCoordinateEntry
}

struct PaintCoordinateScope {
	state    &LayoutState
	previous &PaintCoordinateSession = unsafe { nil }
	scratch  platform.ThreadScratchScope
}

// A projection observes immutable, committed offsets. Use layout ordinals for
// constant-time lookups without enlarging the common UsedValues allocation.
// Nested projections have independent tables, and no table survives its scope.
fn begin_paint_coordinate_session(state &LayoutState) PaintCoordinateScope {
	previous := state.paint_coordinates_
	scratch := platform.begin_thread_scratch('paint coordinate session')
	mut mutable_state := unsafe { &LayoutState(state) }
	capacity := state.used_values_store.pages.len * int(layout_state_page_size)
	mutable_state.paint_coordinates_ = if capacity <= 262144 {
		&PaintCoordinateSession{ entries: []PaintCoordinateEntry{len: capacity} }
	} else {
		unsafe { &PaintCoordinateSession(nil) }
	}
	scratch.leave()
	return PaintCoordinateScope{ state: state, previous: previous, scratch: scratch }
}

fn (scope PaintCoordinateScope) finish() {
	mut state := unsafe { &LayoutState(scope.state) }
	state.paint_coordinates_ = scope.previous
	// Remove the borrowed table pointer before poisoning or freeing its bytes.
	scope.scratch.finish()
}

fn cached_paint_coordinate(node &Node, state &LayoutState, used &UsedValues,
	session &PaintCoordinateSession, depth int) ?PaintCoordinateValue {
	// Malformed cycles and exceptionally deep chains retain the iterative
	// distinct-record fallback. Foreign records cannot borrow another ordinal.
	if depth >= 128 || voidptr(node) != voidptr(used.node()) { return none }
	index := int(used.node().layout_index())
	if index < 0 || index >= session.entries.len { return none }
	owned := state.try_get(used.node()) or { return none }
	if voidptr(owned) != voidptr(used) { return none }
	mut entry := unsafe { &session.entries[index] }
	if entry.owner == voidptr(used) {
		if entry.status == 2 { return entry.value }
		if entry.status == 1 { return none }
	}
	entry.owner = voidptr(used)
	entry.status = 1
	mut completed := false
	defer { if !completed { entry.status = 0 } }
	mut position := paint_local_offset(node, state, used)
	x := i64(position.x().raw_value())
	y := i64(position.y().raw_value())
	mut absolute_x := u64(if x < 0 { -x } else { x })
	mut absolute_y := u64(if y < 0 { -y } else { y })
	if parent := used.containing_block_used_values() {
		parent_value := cached_paint_coordinate(unsafe { &Node(parent.node()) }, state,
			parent, session, depth + 1) or { return none }
		absolute_x += parent_value.absolute_x
		absolute_y += parent_value.absolute_y
		position = css_pixel_point_add(position, parent_value.position)
	}
	// Saturating fixed-point addition is not associative. Only regroup chains
	// whose absolute travel proves that no intermediate sum can saturate.
	if absolute_x > u64(2_147_483_647) || absolute_y > u64(2_147_483_647) { return none }
	value := PaintCoordinateValue{ position: position, absolute_x: absolute_x, absolute_y: absolute_y }
	entry.value = value
	entry.status = 2
	completed = true
	return value
}
