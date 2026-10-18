module painting

import css
import math
import platform

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
mut:
	// `paintable_box_` is the renderer-independent identity used in place of
	// C++'s weak PaintableBox pointer. Its access and lifetime otherwise follow
	// ScrollFrame::paintable_box().
	paintable_box_      string
	sticky_             bool
	parent_index_       int
	own_offset_         Point
	sticky_constraints_ ?StickyConstraints
}

pub fn (frame &ScrollFrame) paintable_box() string {
	return frame.paintable_box_
}

pub fn (frame &ScrollFrame) is_sticky() bool {
	return frame.sticky_
}

pub fn (frame &ScrollFrame) own_offset() Point {
	return frame.own_offset_
}

pub fn (mut frame ScrollFrame) set_own_offset(offset Point) {
	frame.own_offset_ = offset
}

pub fn (frame &ScrollFrame) parent_index() int {
	return frame.parent_index_
}

pub fn (mut frame ScrollFrame) set_sticky_constraints(constraints StickyConstraints) {
	frame.sticky_constraints_ = constraints
}

pub fn (frame &ScrollFrame) has_sticky_constraints() bool {
	return frame.sticky_constraints_ != none
}

pub fn (frame &ScrollFrame) sticky_constraints() StickyConstraints {
	return frame.sticky_constraints_ or { panic('sticky frame has no constraints') }
}

pub struct ScrollState {
pub mut:
	// Index zero is the upstream sentinel and is never returned to callers.
	frames []ScrollFrame = [ScrollFrame{}]
mut:
	// The retained visual-context scroll state owns its invalidation bit. A
	// snapshot refresh consumes it; document paint state does not mirror it.
	needs_refresh bool = true
}

pub fn (mut state ScrollState) create_scroll_frame_for(paintable_box string, parent int) int {
	index := state.frames.len
	state.frames << ScrollFrame{
		paintable_box_: paintable_box
		parent_index_: parent
	}
	state.invalidate()
	return index
}

pub fn (mut state ScrollState) create_sticky_frame_for(paintable_box string, parent int) int {
	index := state.frames.len
	state.frames << ScrollFrame{
		paintable_box_: paintable_box
		sticky_: true
		parent_index_: parent
	}
	state.invalidate()
	return index
}

pub fn (mut state ScrollState) invalidate() {
	state.needs_refresh = true
}

// Returns whether the caller should re-read live offsets and publish a new
// snapshot. `force` is used only by the verification path for skipped work.
pub fn (mut state ScrollState) begin_refresh(force bool) bool {
	if !force && !state.needs_refresh {
		return false
	}
	state.needs_refresh = false
	return true
}

pub fn (state &ScrollState) needs_refresh() bool {
	return state.needs_refresh
}

pub fn (state &ScrollState) frame_at(index int) &ScrollFrame {
	return &state.frames[index]
}

pub fn (state ScrollState) cumulative_offset(index int) Point {
	mut offset := Point{}
	mut current := index
	for current > 0 && current < state.frames.len {
		offset = offset.add(state.frame_at(current).own_offset())
		current = state.frame_at(current).parent_index()
	}
	return offset
}

pub fn (state ScrollState) nearest_scrolling_ancestor(index int) int {
	if index <= 0 || index >= state.frames.len {
		return 0
	}
	mut ancestor := state.frame_at(index).parent_index()
	for ancestor > 0 && ancestor < state.frames.len {
		if !state.frame_at(ancestor).is_sticky() {
			return ancestor
		}
		ancestor = state.frame_at(ancestor).parent_index()
	}
	return 0
}

pub fn (mut state ScrollState) for_each_scroll_frame(callback fn (int, mut ScrollFrame)) {
	for index := 1; index < state.frames.len; index++ {
		if state.frames[index].is_sticky() {
			continue
		}
		callback(index, mut state.frames[index])
	}
}

pub fn (mut state ScrollState) for_each_sticky_frame(callback fn (int, mut ScrollFrame)) {
	for index := 1; index < state.frames.len; index++ {
		if !state.frames[index].is_sticky() {
			continue
		}
		callback(index, mut state.frames[index])
	}
}

pub fn (mut state ScrollState) clear() {
	// Match Vector::resize_and_keep_capacity(): rebuilding a paint tree should
	// reuse the frame allocation from the previous tree.
	state.frames.trim(1)
	state.invalidate()
}

pub struct ScrollStateSnapshot {
pub:
	device_offsets []Point
}

pub fn ScrollStateSnapshot.create(frames []ScrollFrame, device_scale f64) ScrollStateSnapshot {
	mut offsets := []Point{cap: frames.len}
	scale := f32(device_scale)
	for frame in frames {
		offset := frame.own_offset()
		offsets << Point{
			x: f64(f32(offset.x) * scale)
			y: f64(f32(offset.y) * scale)
		}
	}
	return ScrollStateSnapshot{
		device_offsets: offsets
	}
}

pub fn (state ScrollState) snapshot(device_scale f64) ScrollStateSnapshot {
	return ScrollStateSnapshot.create(state.frames, device_scale)
}

// snapshot_matches reports whether `snapshot` already holds the offsets a new
// snapshot of this state would. Animation frames that move nothing can then
// keep publishing the existing snapshot instead of allocating an equal one.
pub fn (state &ScrollState) snapshot_matches(snapshot ScrollStateSnapshot, device_scale f64) bool {
	if snapshot.device_offsets.len != state.frames.len {
		return false
	}
	scale := f32(device_scale)
	for index, frame in state.frames {
		offset := frame.own_offset()
		current := snapshot.device_offsets[index]
		if current.x != f64(f32(offset.x) * scale) || current.y != f64(f32(offset.y) * scale) {
			return false
		}
	}
	return true
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

// Direct translation of PaintableBox::available_scrollbar_length().
pub fn paintable_box_available_scrollbar_length(input ScrollbarGeometryInput) f64 {
	is_horizontal := input.direction == .horizontal
	mut full_scrollport_length := if is_horizontal {
		input.padding_rect.width
	} else {
		input.padding_rect.height
	}
	if input.has_resizer {
		full_scrollport_length -= input.metrics.resize_gripper_size
	} else if input.has_other_scrollbar {
		full_scrollport_length -= input.metrics.scroll_gutter_thickness
	}
	return full_scrollport_length
}

// Direct translation of PaintableBox::absolute_scrollbar_rect() after its
// scrollability and `scrollbar-width` preconditions have been checked by the
// active caller.
pub fn paintable_box_absolute_scrollbar_rect(input ScrollbarGeometryInput) Rect {
	is_horizontal := input.direction == .horizontal
	adjusting_for_resizer := input.has_resizer
	rect_thickness := if input.with_gutter {
		input.metrics.scroll_gutter_thickness
	} else {
		input.metrics.scroll_thumb_thickness_thin + input.metrics.scroll_thumb_padding_thin
	}
	if is_horizontal {
		mut width := input.padding_rect.width
		mut x := input.padding_rect.x
		if !adjusting_for_resizer && input.has_other_scrollbar {
			width = math.max(0.0, width - input.metrics.scroll_gutter_thickness)
			if input.chrome_mirrored {
				x += input.metrics.scroll_gutter_thickness
			}
		} else if adjusting_for_resizer {
			width = paintable_box_available_scrollbar_length(input)
			if input.chrome_mirrored {
				x += input.metrics.resize_gripper_size
			}
		}
		return Rect{
			x: x
			y: math.max(0.0, input.padding_rect.bottom() - rect_thickness)
			width: width
			height: rect_thickness
		}
	}
	height := if adjusting_for_resizer {
		paintable_box_available_scrollbar_length(input)
	} else {
		input.padding_rect.height
	}
	x := if input.chrome_mirrored {
		input.padding_rect.x
	} else {
		math.max(0.0, input.padding_rect.right() - rect_thickness)
	}
	return Rect{x, input.padding_rect.y, rect_thickness, height}
}

// Direct translation of PaintableBox::compute_scrollbar_data().
pub fn paintable_box_compute_scrollbar_data(input ScrollbarGeometryInput) ?ScrollbarData {
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
	scrollbar_rect := paintable_box_absolute_scrollbar_rect(input)
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
			x: scrollbar_rect.x + thumb_margin + thumb_offset
			y: scrollbar_rect.y + if input.with_gutter { thumb_margin } else { 0 }
			width: thumb_length
			height: thumb_thickness
		}
	} else {
		thumb = Rect{
			x: scrollbar_rect.x + if input.with_gutter || input.chrome_mirrored {
				thumb_margin
			} else {
				0
			}
			y: scrollbar_rect.y + thumb_margin + thumb_offset
			width: thumb_thickness
			height: thumb_length
		}
	}
	return ScrollbarData{
		gutter_rect: if input.with_gutter { scrollbar_rect } else { Rect{} }
		thumb_rect: thumb
		thumb_travel_to_scroll_ratio: ratio
	}
}

// Direct translation of PaintableBox::absolute_resizer_rect().
pub fn paintable_box_absolute_resizer_rect(padding_rect Rect, has_resizer bool,
	chrome_mirrored bool, metrics ChromeMetrics) ?Rect {
	if !has_resizer {
		return none
	}
	x := if chrome_mirrored {
		padding_rect.x
	} else {
		padding_rect.right() - metrics.resize_gripper_size
	}
	y := padding_rect.bottom() - metrics.resize_gripper_size
	return Rect{x, y, metrics.resize_gripper_size, metrics.resize_gripper_size}
}

pub enum MouseAction {
	none
	capture_input
	swallow_event
	capture_input_and_swallow_event
}

pub fn (action MouseAction) captures_input() bool {
	return action == .capture_input || action == .capture_input_and_swallow_event
}

pub fn (action MouseAction) swallows_event() bool {
	return action == .swallow_event || action == .capture_input_and_swallow_event
}

pub struct ScrollbarInteractionInput {
pub:
	geometry        ScrollbarGeometryInput
	visual_to_local Affine
}

// Direct state translation of Scrollbar. PaintableBox owns this state in C++;
// callers pass its current geometry because the renderer-independent Painting
// module cannot retain a Layout box without creating a module cycle.
pub struct Scrollbar {
mut:
	direction_              ScrollDirection
	hovered                 bool
	thumb_grab_position     ?f64
	requested_scroll_offset ?Point
	repaint_requested       bool
}

pub fn Scrollbar.create(direction ScrollDirection) Scrollbar {
	return Scrollbar{
		direction_: direction
	}
}

pub fn (scrollbar &Scrollbar) direction() ScrollDirection {
	return scrollbar.direction_
}

pub fn (scrollbar &Scrollbar) is_enlarged() bool {
	return scrollbar.hovered || scrollbar.thumb_grab_position != none
}

pub fn (scrollbar &Scrollbar) contains(position Point, geometry ScrollbarGeometryInput) bool {
	input := ScrollbarGeometryInput{
		...geometry
		direction: scrollbar.direction_
		with_gutter: scrollbar.is_enlarged()
	}
	return paintable_box_absolute_scrollbar_rect(input).contains(position)
}

pub fn (mut scrollbar Scrollbar) handle_pointer_event(event_type string, button int,
	visual_viewport_position Point, input ScrollbarInteractionInput) MouseAction {
	if event_type == 'pointermove' {
		if scrollbar.thumb_grab_position == none {
			return .none
		}
	} else if button != 0 {
		return .none
	}

	position := input.visual_to_local.map_point(visual_viewport_position)
	scrollbar.scroll_to_mouse_position(position, input.geometry)
	scrollbar.repaint_requested = true

	if event_type == 'pointerup' {
		scrollbar.thumb_grab_position = none
		return .none
	}

	return .capture_input
}

fn (mut scrollbar Scrollbar) mouse_move(position Point,
	input ScrollbarInteractionInput) MouseAction {
	if scrollbar.thumb_grab_position != none {
		local_position := input.visual_to_local.map_point(position)
		scrollbar.scroll_to_mouse_position(local_position, input.geometry)
		return .swallow_event
	}
	return .none
}

fn (mut scrollbar Scrollbar) mouse_up(_ Point, _ int) MouseAction {
	scrollbar.thumb_grab_position = none
	scrollbar.repaint_requested = true
	return .none
}

pub fn (mut scrollbar Scrollbar) mouse_enter() {
	if scrollbar.hovered {
		return
	}
	scrollbar.hovered = true
	scrollbar.repaint_requested = true
}

pub fn (mut scrollbar Scrollbar) mouse_leave() {
	if !scrollbar.hovered {
		return
	}
	scrollbar.hovered = false
	scrollbar.repaint_requested = true
}

fn (mut scrollbar Scrollbar) scroll_to_mouse_position(position Point,
	geometry ScrollbarGeometryInput) {
	input := ScrollbarGeometryInput{
		...geometry
		direction: scrollbar.direction_
		with_gutter: scrollbar.is_enlarged()
	}
	scrollbar_data := paintable_box_compute_scrollbar_data(input) or {
		panic('Scrollbar::scroll_to_mouse_position requires scrollbar data')
	}
	is_horizontal := scrollbar.direction_ == .horizontal
	offset_relative_to_gutter := if is_horizontal {
		position.x - scrollbar_data.gutter_rect.x
	} else {
		position.y - scrollbar_data.gutter_rect.y
	}
	gutter_size := if is_horizontal {
		scrollbar_data.gutter_rect.width
	} else {
		scrollbar_data.gutter_rect.height
	}
	thumb_size := if is_horizontal {
		scrollbar_data.thumb_rect.width
	} else {
		scrollbar_data.thumb_rect.height
	}

	if gutter_size < thumb_size {
		return
	}

	if scrollbar.thumb_grab_position == none {
		thumb_origin := if is_horizontal {
			scrollbar_data.thumb_rect.x
		} else {
			scrollbar_data.thumb_rect.y
		}
		pointer_position := if is_horizontal { position.x } else { position.y }
		grab_position := if scrollbar_data.thumb_rect.contains(position) {
			pointer_position - thumb_origin
		} else {
			math.max(math.min(offset_relative_to_gutter, thumb_size / 2.0), offset_relative_to_gutter - gutter_size + thumb_size)
		}
		scrollbar.thumb_grab_position = grab_position
	}

	grab_position := scrollbar.thumb_grab_position or { return }
	constrained_offset := math.max(0.0, math.min(gutter_size - thumb_size, offset_relative_to_gutter - grab_position))
	scroll_position := constrained_offset / (gutter_size - thumb_size)
	scrollable_overflow_size := if is_horizontal {
		input.scrollable_overflow.width
	} else {
		input.scrollable_overflow.height
	}
	padding_size := if is_horizontal { input.padding_rect.width } else { input.padding_rect.height }
	scroll_position_in_pixels := css.CSSPixels.nearest_value_for(scroll_position * (scrollable_overflow_size - padding_size)).to_double()
	scrollbar.requested_scroll_offset = if is_horizontal {
		Point{scroll_position_in_pixels, input.scroll_offset.y}
	} else {
		Point{input.scroll_offset.x, scroll_position_in_pixels}
	}
}

pub fn (mut scrollbar Scrollbar) take_requested_scroll_offset() ?Point {
	requested := scrollbar.requested_scroll_offset
	scrollbar.requested_scroll_offset = none
	return requested
}

pub fn (mut scrollbar Scrollbar) take_repaint_request() bool {
	requested := scrollbar.repaint_requested
	scrollbar.repaint_requested = false
	return requested
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

pub struct ResizeHandle {
pub mut:
	is_resizing bool
	origin      Point
	last_point  Point
}

pub fn ResizeHandle.create() ResizeHandle {
	return ResizeHandle{}
}

pub fn (_ &ResizeHandle) cursor(axes PhysicalResizeAxes,
	chrome_mirrored bool) ResizeCursor {
	if axes.vertical {
		if axes.horizontal {
			return if chrome_mirrored { .sw_resize } else { .se_resize }
		}
		return .ns_resize
	}
	return .ew_resize
}

pub fn (_ &ResizeHandle) mouse_enter() {}

pub fn (_ &ResizeHandle) mouse_leave() {}

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
	} else {
		handle.last_point = position
	}
	if event_type == 'pointerup' {
		handle.is_resizing = false
		return .none
	}
	return .capture_input
}

pub type BackingStoreShrinkCallback = fn (voidptr)

@[heap]
pub struct BackingStoreManager {
pub mut:
	allocated_size  IntSize
	front_bitmap_id u64
	back_bitmap_id  u64
	next_bitmap_id  u64 = 1
mut:
	backing_store_shrink_timer &platform.Timer = unsafe { nil }
	shrink_callback_target     voidptr = unsafe { nil }
	shrink_callback            BackingStoreShrinkCallback = unsafe { nil }
	has_shrink_callback        bool
}

// Direct translation of BackingStoreManager's single-shot shrink timer. The
// callback keeps Painting independent of HTML::Navigable while preserving the
// source ownership: restarting and firing the timer remain manager operations.
pub fn BackingStoreManager.create(callback_target voidptr,
	callback BackingStoreShrinkCallback) &BackingStoreManager {
	mut manager := &BackingStoreManager{
		shrink_callback_target: callback_target
		shrink_callback: callback
		has_shrink_callback: true
	}
	manager_pointer := voidptr(manager)
	manager.backing_store_shrink_timer = platform.Timer.create_single_shot(3000, fn [manager_pointer] () {
		mut mutable_manager := unsafe { &BackingStoreManager(manager_pointer) }
		if mutable_manager.has_shrink_callback {
			mutable_manager.shrink_callback(mutable_manager.shrink_callback_target)
		}
	})
	return manager
}

pub fn (mut manager BackingStoreManager) restart_resize_timer() {
	if manager.backing_store_shrink_timer != unsafe { nil } {
		manager.backing_store_shrink_timer.restart()
	}
}

// Timer scheduling belongs to the host. This is its deterministic timeout edge
// and is also used by tests in the same way as Platform::Timer::fire().
pub fn (mut manager BackingStoreManager) fire_resize_timer() {
	if manager.backing_store_shrink_timer != unsafe { nil } {
		manager.backing_store_shrink_timer.fire()
	}
}

pub fn (manager &BackingStoreManager) resize_timer_is_active() bool {
	return manager.backing_store_shrink_timer != unsafe { nil }
		&& manager.backing_store_shrink_timer.is_active()
}

pub fn (manager &BackingStoreManager) resize_timer_interval() int {
	if manager.backing_store_shrink_timer == unsafe { nil } {
		return 0
	}
	return manager.backing_store_shrink_timer.interval()
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
