module painting

import math

pub struct StickyInsets {
pub:
	top    ?f64
	right  ?f64
	bottom ?f64
	left   ?f64
}

pub struct StickyConstraints {
pub:
	position_relative_to_scroll_ancestor Point
	border_box_size                      Size
	scrollport_size                      Size
	containing_block_region              Rect
	needs_parent_offset_adjustment       bool
	insets                               StickyInsets
}

pub struct ScrollFrame {
pub:
	paintable_id string
	is_sticky    bool
	parent_index int
pub mut:
	own_offset         Point
	sticky_constraints ?StickyConstraints
}

pub struct ScrollState {
pub mut:
	// Index zero is the upstream sentinel and is never returned to callers.
	frames []ScrollFrame = [ScrollFrame{}]
}

pub fn (mut state ScrollState) create_scroll_frame(paintable_id string, parent int) int {
	index := state.frames.len
	state.frames << ScrollFrame{
		paintable_id: paintable_id
		parent_index: parent
	}
	return index
}

pub fn (mut state ScrollState) create_sticky_frame(paintable_id string, parent int) int {
	index := state.frames.len
	state.frames << ScrollFrame{
		paintable_id: paintable_id
		is_sticky:    true
		parent_index: parent
	}
	return index
}

pub fn (state ScrollState) cumulative_offset(index int) Point {
	mut offset := Point{}
	mut current := index
	for current > 0 && current < state.frames.len {
		offset = offset.add(state.frames[current].own_offset)
		current = state.frames[current].parent_index
	}
	return offset
}

pub fn (state ScrollState) nearest_scrolling_ancestor(index int) int {
	if index <= 0 || index >= state.frames.len {
		return 0
	}
	mut ancestor := state.frames[index].parent_index
	for ancestor > 0 && ancestor < state.frames.len {
		if !state.frames[ancestor].is_sticky {
			return ancestor
		}
		ancestor = state.frames[ancestor].parent_index
	}
	return 0
}

pub fn (state ScrollState) scrolling_frame_indices() []int {
	mut indices := []int{}
	for index := 1; index < state.frames.len; index++ {
		if !state.frames[index].is_sticky {
			indices << index
		}
	}
	return indices
}

pub fn (state ScrollState) sticky_frame_indices() []int {
	mut indices := []int{}
	for index := 1; index < state.frames.len; index++ {
		if state.frames[index].is_sticky {
			indices << index
		}
	}
	return indices
}

pub fn (mut state ScrollState) clear() {
	state.frames = [ScrollFrame{}]
}

pub struct ScrollStateSnapshot {
pub:
	device_offsets []Point
}

pub fn (state ScrollState) snapshot(device_scale f64) ScrollStateSnapshot {
	mut offsets := []Point{cap: state.frames.len}
	for frame in state.frames {
		offsets << frame.own_offset.scale(device_scale)
	}
	return ScrollStateSnapshot{
		device_offsets: offsets
	}
}

pub fn (snapshot ScrollStateSnapshot) device_offset_for_index(index int) Point {
	if index < 0 || index >= snapshot.device_offsets.len {
		return Point{}
	}
	return snapshot.device_offsets[index]
}

pub enum ScrollDirection {
	horizontal
	vertical
}

pub struct ScrollbarData {
pub:
	gutter_rect                  Rect
	thumb_rect                   Rect
	thumb_travel_to_scroll_ratio f64
}

pub struct ScrollbarGeometryInput {
pub:
	direction           ScrollDirection
	padding_rect        Rect
	scrollable_overflow Rect
	scroll_offset       Point
	metrics             ChromeMetrics
	with_gutter         bool
	chrome_mirrored     bool
	has_resizer         bool
	has_other_scrollbar bool
}

pub fn compute_scrollbar_data(input ScrollbarGeometryInput) ?ScrollbarData {
	is_horizontal := input.direction == .horizontal
	overflow_length := if is_horizontal {
		input.scrollable_overflow.width
	} else {
		input.scrollable_overflow.height
	}
	scrollport_length := if is_horizontal {
		input.padding_rect.width
	} else {
		input.padding_rect.height
	}
	if overflow_length <= 0 || overflow_length <= scrollport_length {
		return none
	}
	mut scrollbar_rect := input.padding_rect
	thickness := if input.with_gutter {
		input.metrics.scroll_gutter_thickness
	} else {
		input.metrics.scroll_thumb_thickness_thin + input.metrics.scroll_thumb_padding_thin
	}
	if is_horizontal {
		mut width := scrollbar_rect.width
		if input.has_resizer {
			width = math.max(0.0, width - input.metrics.resize_gripper_size)
		} else if input.has_other_scrollbar {
			width = math.max(0.0, width - input.metrics.scroll_gutter_thickness)
		}
		mut x := scrollbar_rect.x
		if input.chrome_mirrored && (input.has_resizer || input.has_other_scrollbar) {
			x += if input.has_resizer {
				input.metrics.resize_gripper_size
			} else {
				input.metrics.scroll_gutter_thickness
			}
		}
		scrollbar_rect =
			Rect{x, math.max(0.0, scrollbar_rect.bottom() - thickness), width, thickness}
	} else {
		height := if input.has_resizer {
			math.max(0.0, scrollbar_rect.height - input.metrics.resize_gripper_size)
		} else {
			scrollbar_rect.height
		}
		x := if input.chrome_mirrored {
			scrollbar_rect.x
		} else {
			math.max(0.0, scrollbar_rect.right() - thickness)
		}
		scrollbar_rect = Rect{x, scrollbar_rect.y, thickness, height}
	}
	thumb_thickness := if input.with_gutter {
		input.metrics.scroll_thumb_thickness
	} else {
		input.metrics.scroll_thumb_thickness_thin
	}
	thumb_margin := if input.with_gutter {
		(input.metrics.scroll_gutter_thickness - input.metrics.scroll_thumb_thickness) / 2.0
	} else {
		input.metrics.scroll_thumb_padding_thin
	}
	scrollbar_length := if is_horizontal { scrollbar_rect.width } else { scrollbar_rect.height }
	usable := math.max(0.0, scrollbar_length - 2.0 * thumb_margin)
	min_thumb := math.min(usable, input.metrics.scroll_thumb_min_length)
	thumb_length := math.max(usable * scrollport_length / overflow_length, min_thumb)
	ratio := (usable - thumb_length) / (overflow_length - scrollport_length)
	scroll_position := if is_horizontal { input.scroll_offset.x } else { input.scroll_offset.y }
	thumb_offset := scroll_position * ratio
	mut thumb := scrollbar_rect
	if is_horizontal {
		thumb = Rect{
			x:      scrollbar_rect.x + thumb_margin + thumb_offset
			y:      scrollbar_rect.y + if input.with_gutter { thumb_margin } else { 0 }
			width:  thumb_length
			height: thumb_thickness
		}
	} else {
		thumb = Rect{
			x:      scrollbar_rect.x +
				if input.with_gutter || input.chrome_mirrored { thumb_margin } else { 0 }
			y:      scrollbar_rect.y + thumb_margin + thumb_offset
			width:  thumb_thickness
			height: thumb_length
		}
	}
	return ScrollbarData{
		gutter_rect:                  if input.with_gutter { scrollbar_rect } else { Rect{} }
		thumb_rect:                   thumb
		thumb_travel_to_scroll_ratio: ratio
	}
}

pub fn scrollbar_offset_for_pointer(position f64, gutter_start f64, gutter_length f64,
	thumb_length f64, grab_position ?f64) (f64, f64) {
	if gutter_length < thumb_length || gutter_length <= 0 {
		return 0, 0
	}
	relative := position - gutter_start
	grab := grab_position or {
		math.max(math.min(relative, thumb_length / 2.0), relative - gutter_length + thumb_length)
	}

	constrained := math.max(0.0, math.min(gutter_length - thumb_length, relative - grab))
	return constrained / (gutter_length - thumb_length), grab
}

pub enum MouseAction {
	none
	capture_input
	swallow_event
}

pub enum ResizeCursor {
	none
	ew_resize
	ns_resize
	se_resize
	sw_resize
}

pub struct PhysicalResizeAxes {
pub:
	horizontal bool
	vertical   bool
}

pub fn resize_cursor(axes PhysicalResizeAxes, chrome_mirrored bool) ResizeCursor {
	if axes.vertical {
		if axes.horizontal {
			return if chrome_mirrored { .sw_resize } else { .se_resize }
		}
		return .ns_resize
	}
	return .ew_resize
}

pub struct ResizeHandle {
pub mut:
	is_resizing bool
	origin      Point
	last_point  Point
}

pub fn (mut handle ResizeHandle) handle_pointer_event(event_type string, button int,
	position Point) MouseAction {
	if event_type == 'pointermove' {
		if !handle.is_resizing {
			return .none
		}
	} else if button != 0 {
		return .none
	}
	if !handle.is_resizing {
		handle.is_resizing = true
		handle.origin = position
	}
	handle.last_point = position
	if event_type == 'pointerup' {
		handle.is_resizing = false
		return .none
	}
	return .capture_input
}

pub struct BackingStoreManager {
pub mut:
	allocated_size  IntSize
	front_bitmap_id u64
	back_bitmap_id  u64
	next_bitmap_id  u64 = 1
}

pub fn (mut manager BackingStoreManager) resize_if_needed(viewport IntSize, resizing bool,
	is_top_level bool, is_svg_page bool) bool {
	if !is_top_level || is_svg_page || viewport.width <= 0 || viewport.height <= 0 {
		return false
	}
	minimum := if resizing {
		IntSize{viewport.width + 256, viewport.height + 256}
	} else {
		viewport
	}
	contains := manager.allocated_size.width >= minimum.width
		&& manager.allocated_size.height >= minimum.height
	force := !resizing && manager.allocated_size != minimum
	if !force && manager.allocated_size.width > 0 && manager.allocated_size.height > 0 && contains {
		return false
	}
	manager.allocated_size = minimum
	manager.front_bitmap_id = manager.next_bitmap_id
	manager.next_bitmap_id++
	manager.back_bitmap_id = manager.next_bitmap_id
	manager.next_bitmap_id++
	return true
}
