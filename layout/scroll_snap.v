// Copyright (c) 2026-present, the Ladybird developers.
//
// SPDX-License-Identifier: BSD-2-Clause
module layout

import css
import dom
import math

// The element a snap area belongs to. Stable DOM node identities survive
// layout-tree reconstruction, matching upstream's weak Element reference.
pub struct SnapAreaReference {
pub:
	element_id     i64
	pseudo_element int = -1
}

pub enum SnapSelectionType {
	end_position
	direction
	end_position_and_direction
}

pub struct SnapSelectionStrategy {
pub:
	type_                       SnapSelectionType = .end_position
	start_offset                ?dom.CSSPixelPoint_
	displacement                dom.CSSPixelPoint_
	starting_positions_boundary ?dom.CSSPixelPoint_
}

pub struct SnapAxes {
pub:
	x bool
	y bool
}

pub fn (axes SnapAxes) is_empty() bool {
	return !axes.x && !axes.y
}

pub struct SnappedAreas {
pub mut:
	x []SnapAreaReference
	y []SnapAreaReference
}

pub fn (areas SnappedAreas) is_empty() bool {
	return areas.x.len == 0 && areas.y.len == 0
}

pub struct SnapDestination {
pub mut:
	position      dom.CSSPixelPoint_
	snapped_x     bool
	snapped_y     bool
	evaluated_x   bool
	evaluated_y   bool
	snapped_areas SnappedAreas
}

pub struct CoveringRange {
pub:
	start f64
	end   f64
}

pub struct SnapPositionCandidate {
pub mut:
	offset                         f64
	area                           SnapAreaReference
	covering_ranges                []CoveringRange
	cross_axis_visible_range_start f64
	cross_axis_visible_range_end   f64
	always_stop                    bool
}

pub struct SnapAxisCandidates {
pub mut:
	x_candidates []SnapPositionCandidate
	y_candidates []SnapPositionCandidate
}

struct SnapAxisGeometry {
	snapport_start f64
	snapport_size  f64
	min_offset     f64
	max_offset     f64
}

struct PhysicalSnapAlignment {
	x css.ScrollSnapAlign
	y css.ScrollSnapAlign
}

struct SnapAxisSelection {
	destination                 f64
	start                       f64
	direction                   f64
	starting_positions_boundary ?f64
}

struct SnapAxisChoice {
	offset f64
	area   SnapAreaReference
}

struct SnapCandidateCollection {
mut:
	snapport   LayoutRect
	x_geometry SnapAxisGeometry
	y_geometry SnapAxisGeometry
	snap_type  css.ScrollSnapType
	candidates SnapAxisCandidates
}

struct SnapContainerStyleSource {
	scroll_snap_type css.ScrollSnapType
	writing_mode     css.WritingMode
	direction        css.Direction
}

struct DescendantSnapArea {
	rect         LayoutRect
	reference    SnapAreaReference
	alignment    css.ScrollSnapAlignData
	always_stop  bool
	writing_mode css.WritingMode
	direction    css.Direction
}

const snap_position_boundary_tolerance = 1.0

fn clamp_snap_offset(value f64, minimum f64, maximum f64) f64 {
	return math.max(minimum, math.min(maximum, value))
}

fn has_snap_alignment(alignment css.ScrollSnapAlignData) bool {
	return alignment.block_alignment != .none_ || alignment.inline_alignment != .none_
}

fn style_source_for_snap_container(snap_container &BlockBox) SnapContainerStyleSource {
	// The viewport transport is the document element's box, so it already is
	// the style source upstream selects for a viewport snap container.
	return SnapContainerStyleSource{
		scroll_snap_type: snap_container.scroll_snap_type
		writing_mode: snap_container.writing_mode
		direction: snap_container.direction
	}
}

fn snap_area_reference_for(box &BlockBox) SnapAreaReference {
	if box.layout_handle != unsafe { nil } {
		node := unsafe { &Node(box.layout_handle) }
		if pseudo := node.generated_for_pseudo_element() {
			if generator := node.pseudo_element_generator() {
				return SnapAreaReference{
					element_id:     i64(generator.as_node().unique_id())
					pseudo_element: int(pseudo)
				}
			}
		}
	}
	return SnapAreaReference{ element_id: box.node_id }
}

fn is_captured_by_snap_container(snap_area &BlockBox, snap_container &BlockBox) bool {
	if snap_area.layout_handle == unsafe { nil } || snap_container.layout_handle == unsafe { nil } {
		return false
	}
	area_node := unsafe { &Node(snap_area.layout_handle) }
	mut containing_block := area_node.containing_block()
	for containing_block != none {
		block := containing_block or { break }
		block_node := unsafe { &Node(block) }
		if voidptr(block_node) == snap_container.layout_handle {
			return true
		}
		// A positioned area can skip a nested scroll container in the containing
		// block chain. Otherwise the nearest scroll container captures it.
		if block_node.is_scroll_container() {
			return false
		}
		containing_block = block_node.containing_block()
	}
	return false
}

fn for_each_descendant_snap_area(parent &BlockBox, snap_container &BlockBox,
	mut areas []DescendantSnapArea) {
	// Borrow each child: passing a loop copy's address would heap-allocate it.
	for i in 0 .. parent.children.len {
		child := &parent.children[i]
		if has_snap_alignment(child.scroll_snap_align)
			&& is_captured_by_snap_container(child, snap_container) {
			areas << DescendantSnapArea{
				rect: snap_area_rect(child)
				reference: snap_area_reference_for(child)
				alignment: child.scroll_snap_align
				always_stop: child.scroll_snap_stop == .always
				writing_mode: child.writing_mode
				direction: child.direction
			}
		}
		for_each_descendant_snap_area(child, snap_container, mut areas)
	}
}

// https://drafts.csswg.org/css-scroll-snap-1/#scroll-margin
fn snap_area_rect(snap_area &BlockBox) LayoutRect {
	mut rect := snap_area.border_box()
	if !affine_is_compact_identity(snap_area.paint_transform) {
		rect = compatibility_affine_map_rect(snap_area.paint_transform, rect)
	}
	scale := box_layout_coordinate_scale(snap_area)
	if scale != 1 {
		rect = LayoutRect{rect.x * scale, rect.y * scale, rect.width * scale, rect.height * scale}
	}
	return LayoutRect{
		x:      rect.x - snap_area.scroll_margin.left
		y:      rect.y - snap_area.scroll_margin.top
		width:  rect.width + snap_area.scroll_margin.left + snap_area.scroll_margin.right
		height: rect.height + snap_area.scroll_margin.top + snap_area.scroll_margin.bottom
	}
}

// https://drafts.csswg.org/css-scroll-snap-1/#scroll-snap-align
fn alignment_along_snap_axis(alignment css.ScrollSnapAlign, reverse bool) css.ScrollSnapAlign {
	if !reverse {
		return alignment
	}
	return match alignment {
		.start { css.ScrollSnapAlign.end_ }
		.end_ { css.ScrollSnapAlign.start }
		else { alignment }
	}
}

fn physical_snap_alignment(alignment css.ScrollSnapAlignData, writing_mode css.WritingMode,
	direction css.Direction) PhysicalSnapAlignment {
	horizontal := writing_mode == .horizontal_tb
	x_alignment := if horizontal { alignment.inline_alignment } else { alignment.block_alignment }
	y_alignment := if horizontal { alignment.block_alignment } else { alignment.inline_alignment }
	x_reverse := if horizontal {
		layout_inline_axis_is_reverse(writing_mode, direction)
	} else {
		layout_block_axis_is_reverse(writing_mode)
	}
	y_reverse := if horizontal {
		layout_block_axis_is_reverse(writing_mode)
	} else {
		layout_inline_axis_is_reverse(writing_mode, direction)
	}
	return PhysicalSnapAlignment{
		x: alignment_along_snap_axis(x_alignment, x_reverse)
		y: alignment_along_snap_axis(y_alignment, y_reverse)
	}
}

fn snap_position_candidate_for_axis(alignment css.ScrollSnapAlign, area_start f64,
	area_size f64, geometry SnapAxisGeometry) ?SnapPositionCandidate {
	mut offset := 0.0
	match alignment {
		.none_ {
			return none
		}
		.start {
			offset = area_start - geometry.snapport_start
		}
		.end_ {
			offset = area_start + area_size - (geometry.snapport_start + geometry.snapport_size)
		}
		.center {
			offset = area_start + area_size / 2.0 - (geometry.snapport_start + geometry.snapport_size / 2.0)
		}
	}
	mut candidate := SnapPositionCandidate{
		offset: clamp_snap_offset(offset, geometry.min_offset, geometry.max_offset)
	}
	if area_size > geometry.snapport_size {
		candidate.covering_ranges << CoveringRange{
			start: clamp_snap_offset(area_start - geometry.snapport_start, geometry.min_offset, geometry.max_offset)
			end:   clamp_snap_offset(area_start + area_size - (geometry.snapport_start + geometry.snapport_size), geometry.min_offset, geometry.max_offset)
		}
	}
	return candidate
}

fn restrict_covering_ranges_to_valid_snap_positions(mut candidates []SnapPositionCandidate,
	snapport_size f64) {
	mut snap_positions := []f64{cap: candidates.len}
	for candidate in candidates {
		snap_positions << candidate.offset
	}
	if snap_positions.len == 0 {
		return
	}
	snap_positions.sort()
	for mut candidate in candidates {
		if candidate.covering_ranges.len == 0 {
			continue
		}
		covering_range := candidate.covering_ranges[0]
		candidate.covering_ranges.clear()
		mut ranges := []CoveringRange{}
		append_valid_offsets_between(covering_range.start, snap_positions[0], covering_range, mut ranges)
		for index := 1; index < snap_positions.len; index++ {
			if snap_positions[index] - snap_positions[index - 1] > snapport_size {
				append_valid_offsets_between(snap_positions[index - 1], snap_positions[index], covering_range, mut ranges)
			}
		}
		append_valid_offsets_between(snap_positions.last(), covering_range.end, covering_range, mut ranges)
		candidate.covering_ranges = ranges
	}
}

fn append_valid_offsets_between(start_value f64, end_value f64, covering_range CoveringRange,
	mut ranges []CoveringRange) {
	start := math.max(start_value, covering_range.start)
	end := math.min(end_value, covering_range.end)
	if start <= end {
		ranges << CoveringRange{start, end}
	}
}

fn is_beyond_in_direction(offset f64, boundary f64, direction f64) bool {
	if direction > 0 {
		return offset >= boundary + snap_position_boundary_tolerance
	}
	return offset <= boundary - snap_position_boundary_tolerance
}

fn is_at_or_beyond_in_direction(offset f64, boundary f64, direction f64) bool {
	if direction > 0 {
		return offset >= boundary
	}
	return offset <= boundary
}

fn snap_area_is_visible_at_cross_axis_offset(candidate SnapPositionCandidate,
	cross_axis_offset f64) bool {
	return cross_axis_offset > candidate.cross_axis_visible_range_start
		&& cross_axis_offset < candidate.cross_axis_visible_range_end
}

fn candidate_has_snap_position_at(candidate SnapPositionCandidate, offset f64) bool {
	if candidate.offset == offset {
		return true
	}
	for covering_range in candidate.covering_ranges {
		if offset >= covering_range.start && offset <= covering_range.end {
			return true
		}
	}
	return false
}

fn chosen_offset_is_visible_at_cross_axis_offset(candidates []SnapPositionCandidate, offset f64,
	cross_axis_offset f64) bool {
	for candidate in candidates {
		if snap_area_is_visible_at_cross_axis_offset(candidate, cross_axis_offset)
			&& candidate_has_snap_position_at(candidate, offset) {
			return true
		}
	}
	return false
}

fn chosen_offsets_are_mutually_visible(candidates SnapAxisCandidates, x_offset f64,
	y_offset f64) bool {
	return chosen_offset_is_visible_at_cross_axis_offset(candidates.x_candidates, x_offset, y_offset)
		&& chosen_offset_is_visible_at_cross_axis_offset(candidates.y_candidates, y_offset, x_offset)
}

fn choose_snap_offset_for_axis(candidates []SnapPositionCandidate,
	selection SnapAxisSelection, snapport_size f64, strictness css.ScrollSnapStrictness,
	cross_axis_offset ?f64, only_area ?SnapAreaReference) ?SnapAxisChoice {
	proximity_range := snapport_size / 3.0
	mut best_choice := ?SnapAxisChoice(none)
	mut best_distance := 0.0
	mut first_always_stop_choice := ?SnapAxisChoice(none)

	for candidate in candidates {
		if area := only_area {
			if candidate.area != area {
				continue
			}
		}
		if cross_offset := cross_axis_offset {
			if !snap_area_is_visible_at_cross_axis_offset(candidate, cross_offset) {
				continue
			}
		}
		if selection.direction != 0 && candidate.always_stop
			&& is_beyond_in_direction(candidate.offset, selection.start, selection.direction) {
			if previous := first_always_stop_choice {
				if math.abs(candidate.offset - selection.start) < math.abs(previous.offset - selection.start) {
					first_always_stop_choice = SnapAxisChoice{candidate.offset, candidate.area}
				}
			} else {
				first_always_stop_choice = SnapAxisChoice{candidate.offset, candidate.area}
			}
		}
		if selection.starting_positions_boundary == none
			|| (is_beyond_in_direction(candidate.offset, selection.start, selection.direction)
				&& is_at_or_beyond_in_direction(candidate.offset, selection.starting_positions_boundary or { 0 }, selection.direction)) {
			best_choice, best_distance = consider_snap_candidate(candidate.offset, candidate, selection, strictness, proximity_range, best_choice, best_distance)
		}
		for covering_range in candidate.covering_ranges {
			mut range_start := covering_range.start
			mut range_end := covering_range.end
			if selection.starting_positions_boundary != none {
				if selection.direction > 0 {
					range_start = math.max(range_start, selection.start + snap_position_boundary_tolerance)
				} else if selection.direction < 0 {
					range_end = math.min(range_end, selection.start - snap_position_boundary_tolerance)
				}
			}
			if range_start <= range_end {
				best_choice, best_distance = consider_snap_candidate(clamp_snap_offset(selection.destination, range_start, range_end), candidate, selection, strictness, proximity_range, best_choice, best_distance)
			}
		}
	}

	if best_choice == none && selection.starting_positions_boundary != none
		&& strictness == .mandatory {
		best_choice = choose_snap_offset_for_axis(candidates, SnapAxisSelection{
			destination: selection.destination
			start:       selection.destination
		}, snapport_size, strictness, cross_axis_offset, only_area)
	}
	if mut choice := best_choice {
		if stop := first_always_stop_choice {
			passed := if selection.direction > 0 {
				choice.offset > stop.offset
			} else {
				choice.offset < stop.offset
			}
			if passed {
				choice = stop
				best_choice = choice
			}
		}
	}
	return best_choice
}

fn consider_snap_candidate(offset f64, candidate SnapPositionCandidate,
	selection SnapAxisSelection, strictness css.ScrollSnapStrictness, proximity_range f64,
	best_choice ?SnapAxisChoice, best_distance f64) (?SnapAxisChoice, f64) {
	distance := math.abs(offset - selection.destination)
	if strictness == .proximity && distance > proximity_range {
		return best_choice, best_distance
	}
	if best_choice == none || distance < best_distance {
		return SnapAxisChoice{offset, candidate.area}, distance
	}
	return best_choice, best_distance
}

pub fn snap_axes_of_scroll_container(snap_container &BlockBox) SnapAxes {
	type_ := snap_container.scroll_snap_type
	if type_.strictness == .none_ {
		return SnapAxes{}
	}
	horizontal := snap_container.writing_mode == .horizontal_tb
	return match type_.axis {
		.x { SnapAxes{ x: true } }
		.y { SnapAxes{ y: true } }
		.inline_ {
			if horizontal { SnapAxes{ x: true } } else { SnapAxes{ y: true } }
		}
		.block {
			if horizontal { SnapAxes{ y: true } } else { SnapAxes{ x: true } }
		}
		.both { SnapAxes{ x: true, y: true } }
	}
}

pub fn is_scroll_snap_container(node &BlockBox) bool {
	return (node.has_scrollable_overflow || node.is_viewport_scroller)
		&& !snap_axes_of_scroll_container(node).is_empty()
}

fn collect_snap_position_candidates(snap_container &BlockBox, collect_x bool,
	collect_y bool) ?SnapCandidateCollection {
	style_source := style_source_for_snap_container(snap_container)
	overflow := snap_container.scrollable_overflow or { return none }
	padding_box := compatibility_absolute_padding_box_rect(snap_container)
	snapport := LayoutRect{
		x:      padding_box.x + snap_container.scroll_padding.left
		y:      padding_box.y + snap_container.scroll_padding.top
		width:  math.max(0.0, padding_box.width - snap_container.scroll_padding.left - snap_container.scroll_padding.right)
		height: math.max(0.0, padding_box.height - snap_container.scroll_padding.top - snap_container.scroll_padding.bottom)
	}
	max_x := math.max(0.0, overflow.width - padding_box.width)
	max_y := math.max(0.0, overflow.height - padding_box.height)
	mut collection := SnapCandidateCollection{
		snapport:   snapport
		x_geometry: SnapAxisGeometry{snapport.x, snapport.width, 0, max_x}
		y_geometry: SnapAxisGeometry{snapport.y, snapport.height, 0, max_y}
		snap_type:  style_source.scroll_snap_type
	}
	mut areas := []DescendantSnapArea{}
	for_each_descendant_snap_area(snap_container, snap_container, mut areas)
	for snap_area in areas {
		area_is_larger_than_snapport := if snap_area.writing_mode == .horizontal_tb {
			snap_area.rect.width > snapport.width
		} else {
			snap_area.rect.height > snapport.height
		}
		writing_mode := if area_is_larger_than_snapport {
			snap_area.writing_mode
		} else {
			style_source.writing_mode
		}
		direction := if area_is_larger_than_snapport {
			snap_area.direction
		} else {
			style_source.direction
		}
		alignment := physical_snap_alignment(snap_area.alignment, writing_mode, direction)
		if collect_x {
			if mut candidate := snap_position_candidate_for_axis(alignment.x, snap_area.rect.x,
				snap_area.rect.width, collection.x_geometry) {
				candidate.area = snap_area.reference
				candidate.always_stop = snap_area.always_stop
				candidate.cross_axis_visible_range_start = snap_area.rect.y - collection.y_geometry.snapport_start - collection.y_geometry.snapport_size
				candidate.cross_axis_visible_range_end = snap_area.rect.y + snap_area.rect.height - collection.y_geometry.snapport_start
				collection.candidates.x_candidates << candidate
			}
		}
		if collect_y {
			if mut candidate := snap_position_candidate_for_axis(alignment.y, snap_area.rect.y,
				snap_area.rect.height, collection.y_geometry) {
				candidate.area = snap_area.reference
				candidate.always_stop = snap_area.always_stop
				candidate.cross_axis_visible_range_start = snap_area.rect.x - collection.x_geometry.snapport_start - collection.x_geometry.snapport_size
				candidate.cross_axis_visible_range_end = snap_area.rect.x + snap_area.rect.width - collection.x_geometry.snapport_start
				collection.candidates.y_candidates << candidate
			}
		}
	}
	if collect_x {
		restrict_covering_ranges_to_valid_snap_positions(mut collection.candidates.x_candidates, collection.x_geometry.snapport_size)
	}
	if collect_y {
		restrict_covering_ranges_to_valid_snap_positions(mut collection.candidates.y_candidates, collection.y_geometry.snapport_size)
	}
	return collection
}

fn snap_areas_at_offset(candidates []SnapPositionCandidate, offset f64,
	cross_axis_offset f64) []SnapAreaReference {
	mut areas := []SnapAreaReference{}
	for candidate in candidates {
		if snap_area_is_visible_at_cross_axis_offset(candidate, cross_axis_offset)
			&& candidate_has_snap_position_at(candidate, offset) && candidate.area.element_id != 0 {
			areas << candidate.area
		}
	}
	return areas
}

fn snap_destination_for(unsnapped dom.CSSPixelPoint_, x_offset ?f64, y_offset ?f64,
	evaluated_axes SnapAxes) SnapDestination {
	return SnapDestination{
		position:    dom.CSSPixelPoint_{
			x_: x_offset or { unsnapped.x() }
			y_: y_offset or { unsnapped.y() }
		}
		snapped_x:   x_offset != none
		snapped_y:   y_offset != none
		evaluated_x: evaluated_axes.x
		evaluated_y: evaluated_axes.y
	}
}

// https://drafts.csswg.org/css-scroll-snap-1/#choosing
pub fn adjust_scroll_destination_for_snapping(snap_container &BlockBox,
	destination dom.CSSPixelPoint_, strategy SnapSelectionStrategy) SnapDestination {
	snap_axes := snap_axes_of_scroll_container(snap_container)
	if snap_axes.is_empty() {
		return SnapDestination{ position: destination }
	}
	snaps_x := snap_axes.x && (strategy.displacement.is_zero()
		|| strategy.displacement.x() != 0)
	snaps_y := snap_axes.y && (strategy.displacement.is_zero()
		|| strategy.displacement.y() != 0)
	if !snaps_x && !snaps_y {
		return SnapDestination{ position: destination }
	}
	collection := collect_snap_position_candidates(snap_container, snaps_x, snaps_y) or {
		return SnapDestination{ position: destination }
	}

	x_selection := snap_axis_selection(destination.x(), strategy.displacement.x(), point_axis(strategy.start_offset, true), point_axis(strategy.starting_positions_boundary, true), strategy.type_)
	y_selection := snap_axis_selection(destination.y(), strategy.displacement.y(), point_axis(strategy.start_offset, false), point_axis(strategy.starting_positions_boundary, false), strategy.type_)
	mut x_choice := ?SnapAxisChoice(none)
	mut y_choice := ?SnapAxisChoice(none)
	if snaps_x && snaps_y {
		x_choice = choose_snap_offset_for_axis(collection.candidates.x_candidates, x_selection, collection.snapport.width, collection.snap_type.strictness, none, none)
		y_choice = choose_snap_offset_for_axis(collection.candidates.y_candidates, y_selection, collection.snapport.height, collection.snap_type.strictness, none, none)
		if x := x_choice {
			if y := y_choice {
				if !chosen_offsets_are_mutually_visible(collection.candidates, x.offset, y.offset) {
					x_choice, y_choice = reconcile_two_axis_choices(collection, x_selection, y_selection, x, y)
				}
			}
		}
		if x_choice != none && y_choice == none {
			x_choice = choose_snap_offset_for_axis(collection.candidates.x_candidates, x_selection, collection.snapport.width, collection.snap_type.strictness, destination.y(), none)
		} else if y_choice != none && x_choice == none {
			y_choice = choose_snap_offset_for_axis(collection.candidates.y_candidates, y_selection, collection.snapport.height, collection.snap_type.strictness, destination.x(), none)
		}
	} else if snaps_x {
		x_choice = choose_snap_offset_for_axis(collection.candidates.x_candidates, x_selection, collection.snapport.width, collection.snap_type.strictness, destination.y(), none)
	} else if snaps_y {
		y_choice = choose_snap_offset_for_axis(collection.candidates.y_candidates, y_selection, collection.snapport.height, collection.snap_type.strictness, destination.x(), none)
	}
	x_offset := if choice := x_choice { ?f64(choice.offset) } else { ?f64(none) }
	y_offset := if choice := y_choice { ?f64(choice.offset) } else { ?f64(none) }
	mut result := snap_destination_for(destination, x_offset, y_offset, SnapAxes{snaps_x, snaps_y})
	if value := x_offset {
		result.snapped_areas.x = snap_areas_at_offset(collection.candidates.x_candidates, value, result.position.y())
	}
	if value := y_offset {
		result.snapped_areas.y = snap_areas_at_offset(collection.candidates.y_candidates, value, result.position.x())
	}
	return result
}

fn point_axis(point ?dom.CSSPixelPoint_, horizontal bool) ?f64 {
	value := point or { return none }
	return if horizontal { value.x() } else { value.y() }
}

fn snap_axis_selection(destination f64, displacement f64, start ?f64, boundary ?f64,
	type_ SnapSelectionType) SnapAxisSelection {
	start_value := start or {
		return SnapAxisSelection{ destination: destination, start: destination }
	}
	if displacement == 0 {
		return SnapAxisSelection{ destination: destination, start: destination }
	}
	starting_boundary := if type_ != .end_position {
		?f64(boundary or { start_value })
	} else {
		?f64(none)
	}
	return SnapAxisSelection{
		destination:                 destination
		start:                       start_value
		direction:                   displacement
		starting_positions_boundary: starting_boundary
	}
}

fn reconcile_two_axis_choices(collection SnapCandidateCollection,
	x_selection SnapAxisSelection, y_selection SnapAxisSelection, initial_x SnapAxisChoice,
	initial_y SnapAxisChoice) (?SnapAxisChoice, ?SnapAxisChoice) {
	mut x_choice := ?SnapAxisChoice(initial_x)
	mut y_choice := ?SnapAxisChoice(initial_y)
	y_of_x := if initial_x.area.element_id != 0 {
		choose_snap_offset_for_axis(collection.candidates.y_candidates, y_selection, collection.snapport.height, collection.snap_type.strictness, initial_x.offset, initial_x.area)
	} else {
		?SnapAxisChoice(none)
	}
	x_of_y := if initial_y.area.element_id != 0 {
		choose_snap_offset_for_axis(collection.candidates.x_candidates, x_selection, collection.snapport.width, collection.snap_type.strictness, initial_y.offset, initial_y.area)
	} else {
		?SnapAxisChoice(none)
	}
	mut follows_x_area := y_of_x != none
	if y_for_x := y_of_x {
		if x_for_y := x_of_y {
			x_distance := math.hypot(initial_x.offset - x_selection.destination, y_for_x.offset - y_selection.destination)
			y_distance := math.hypot(x_for_y.offset - x_selection.destination, initial_y.offset - y_selection.destination)
			follows_x_area = x_distance < y_distance
		}
	}
	if follows_x_area {
		y_choice = y_of_x
	} else if x_of_y != none {
		x_choice = x_of_y
	} else if math.abs(initial_x.offset - x_selection.destination) <= math.abs(initial_y.offset - y_selection.destination) {
		y_choice = choose_snap_offset_for_axis(collection.candidates.y_candidates, y_selection, collection.snapport.height, collection.snap_type.strictness, initial_x.offset, none)
	} else {
		x_choice = choose_snap_offset_for_axis(collection.candidates.x_candidates, x_selection, collection.snapport.width, collection.snap_type.strictness, initial_y.offset, none)
	}
	return x_choice, y_choice
}

pub struct ResnapSelection {
pub:
	snapped_areas       SnappedAreas
	focused_node_id     i64
	targeted_element_id i64
}

struct SnappedAxisBoxes {
	x_candidate ?int
	y_candidate ?int
}

fn snap_area_contains_node(area SnapAreaReference, node_id i64) bool {
	if area.element_id == 0 || area.pseudo_element >= 0 || node_id == 0 {
		return false
	}
	area_node := dom.Node.from_unique_id(dom.UniqueNodeID(area.element_id)) or { return false }
	target := dom.Node.from_unique_id(dom.UniqueNodeID(node_id)) or { return false }
	return area_node.is_inclusive_ancestor_of(target)
}

fn resnap_offset_for_candidate(candidate SnapPositionCandidate, current_offset f64) f64 {
	if candidate_has_snap_position_at(candidate, current_offset) {
		return current_offset
	}
	return candidate.offset
}

fn area_list_contains(areas []SnapAreaReference, area SnapAreaReference) bool {
	for candidate in areas {
		if candidate == area {
			return true
		}
	}
	return false
}

fn aligned_snap_area_boxes(axis_candidates []SnapPositionCandidate,
	snapped_areas []SnapAreaReference, cross_axis_offset f64) []int {
	mut boxes := []int{}
	for index, candidate in axis_candidates {
		if candidate.area.element_id != 0 && area_list_contains(snapped_areas, candidate.area)
			&& snap_area_is_visible_at_cross_axis_offset(candidate, cross_axis_offset) {
			boxes << index
		}
	}
	return boxes
}

fn keep_snap_boxes_matching(boxes []int, candidates []SnapPositionCandidate,
	predicate fn (SnapAreaReference) bool) ([]int, bool) {
	mut any_matches := false
	for index in boxes {
		if predicate(candidates[index].area) {
			any_matches = true
			break
		}
	}
	if !any_matches {
		return boxes, false
	}
	mut kept := []int{}
	for index in boxes {
		if predicate(candidates[index].area) {
			kept << index
		}
	}
	return kept, true
}

fn snap_area_is_ancestor_of(first SnapAreaReference, second SnapAreaReference) bool {
	if first.pseudo_element >= 0 || first.element_id == second.element_id || first.element_id == 0
		|| second.element_id == 0 {
		return false
	}
	first_node := dom.Node.from_unique_id(dom.UniqueNodeID(first.element_id)) or { return false }
	second_node := dom.Node.from_unique_id(dom.UniqueNodeID(second.element_id)) or {
		return false
	}
	return first_node.is_inclusive_ancestor_of(second_node)
}

fn remove_superseded_snap_boxes(input []int, candidates []SnapPositionCandidate,
	selection ResnapSelection) []int {
	mut boxes := input.clone()
	if selection.focused_node_id != 0 {
		focused_boxes, focused := keep_snap_boxes_matching(boxes, candidates, fn [selection] (area SnapAreaReference) bool {
			return snap_area_contains_node(area, selection.focused_node_id)
		})
		boxes = focused_boxes.clone()
		if focused {
			return remove_ancestor_snap_boxes(boxes, candidates)
		}
	}
	if selection.targeted_element_id != 0 {
		boxes, _ = keep_snap_boxes_matching(boxes, candidates, fn [selection] (area SnapAreaReference) bool {
			return snap_area_contains_node(area, selection.targeted_element_id)
		})
	}
	return remove_ancestor_snap_boxes(boxes, candidates)
}

fn remove_ancestor_snap_boxes(boxes []int, candidates []SnapPositionCandidate) []int {
	mut kept := []int{}
	for index in boxes {
		area := candidates[index].area
		mut superseded := false
		for other_index in boxes {
			if snap_area_is_ancestor_of(area, candidates[other_index].area) {
				superseded = true
				break
			}
		}
		if !superseded {
			kept << index
		}
	}
	return kept
}

fn boxes_contain_area(boxes []int, candidates []SnapPositionCandidate,
	area SnapAreaReference) bool {
	for index in boxes {
		if candidates[index].area == area {
			return true
		}
	}
	return false
}

// https://drafts.csswg.org/css-scroll-snap-1/#multiple-aligned-snap-areas
fn select_between_multiple_aligned_snap_areas(candidates SnapAxisCandidates,
	selection ResnapSelection, scroll_position dom.CSSPixelPoint_) SnappedAxisBoxes {
	mut x_boxes := aligned_snap_area_boxes(candidates.x_candidates, selection.snapped_areas.x, scroll_position.y())
	mut y_boxes := aligned_snap_area_boxes(candidates.y_candidates, selection.snapped_areas.y, scroll_position.x())
	x_boxes = remove_superseded_snap_boxes(x_boxes, candidates.x_candidates, selection)
	y_boxes = remove_superseded_snap_boxes(y_boxes, candidates.y_candidates, selection)
	mut sets_overlap := false
	for index in x_boxes {
		if boxes_contain_area(y_boxes, candidates.y_candidates, candidates.x_candidates[index].area) {
			sets_overlap = true
			break
		}
	}
	if sets_overlap {
		x_boxes = x_boxes.filter(boxes_contain_area(y_boxes, candidates.y_candidates, candidates.x_candidates[it].area))
		y_boxes = y_boxes.filter(boxes_contain_area(x_boxes, candidates.x_candidates, candidates.y_candidates[it].area))
	}
	return SnappedAxisBoxes{
		x_candidate: if x_boxes.len > 0 { ?int(x_boxes[0]) } else { ?int(none) }
		y_candidate: if y_boxes.len > 0 { ?int(y_boxes[0]) } else { ?int(none) }
	}
}

fn fallback_resnap_offset(candidates []SnapPositionCandidate, current_offset f64,
	snapport_size f64, strictness css.ScrollSnapStrictness, cross_axis_offset f64) ?f64 {
	choice := choose_snap_offset_for_axis(candidates, SnapAxisSelection{
		destination: current_offset
		start:       current_offset
	}, snapport_size, strictness, cross_axis_offset, none) or { return none }
	return choice.offset
}

fn find_snap_area_candidate(candidates []SnapPositionCandidate, area SnapAreaReference) ?int {
	for index, candidate in candidates {
		if candidate.area == area {
			return index
		}
	}
	return none
}

fn record_resnapped_areas(chosen_candidate ?int, candidates []SnapPositionCandidate,
	previously_snapped []SnapAreaReference, offset f64, current_offset f64,
	cross_axis_offset f64) []SnapAreaReference {
	mut areas := snap_areas_at_offset(candidates, offset, cross_axis_offset)
	if chosen := chosen_candidate {
		if offset == current_offset {
			chosen_area := candidates[chosen].area
			areas = areas.filter(it == chosen_area || area_list_contains(previously_snapped, it))
		}
	}
	return areas
}

// https://drafts.csswg.org/css-scroll-snap-1/#re-snap
pub fn select_resnap_destination(snap_container &BlockBox,
	current_offset dom.CSSPixelPoint_, selection ResnapSelection) SnapDestination {
	snap_axes := snap_axes_of_scroll_container(snap_container)
	if snap_axes.is_empty() {
		return SnapDestination{ position: current_offset }
	}
	if selection.snapped_areas.is_empty() {
		return adjust_scroll_destination_for_snapping(snap_container, current_offset, SnapSelectionStrategy{})
	}
	collection := collect_snap_position_candidates(snap_container, snap_axes.x, snap_axes.y) or {
		return SnapDestination{ position: current_offset }
	}
	chosen := select_between_multiple_aligned_snap_areas(collection.candidates, selection, current_offset)
	if chosen.x_candidate == none && chosen.y_candidate == none {
		return adjust_scroll_destination_for_snapping(snap_container, current_offset, SnapSelectionStrategy{})
	}
	mut x_candidate := chosen.x_candidate
	mut y_candidate := chosen.y_candidate
	mut x_offset := if index := x_candidate {
		?f64(resnap_offset_for_candidate(collection.candidates.x_candidates[index], current_offset.x()))
	} else {
		?f64(none)
	}
	mut y_offset := if index := y_candidate {
		?f64(resnap_offset_for_candidate(collection.candidates.y_candidates[index], current_offset.y()))
	} else {
		?f64(none)
	}
	if snap_axes.x && x_candidate == none {
		x_offset = fallback_resnap_offset(collection.candidates.x_candidates, current_offset.x(), collection.x_geometry.snapport_size, collection.snap_type.strictness, y_offset or { current_offset.y() })
	}
	if snap_axes.y && y_candidate == none {
		y_offset = fallback_resnap_offset(collection.candidates.y_candidates, current_offset.y(), collection.y_geometry.snapport_size, collection.snap_type.strictness, x_offset or { current_offset.x() })
	}

	if x := x_offset {
		if y := y_offset {
			if !chosen_offsets_are_mutually_visible(collection.candidates, x, y) {
				x_area := if index := x_candidate {
					?SnapAreaReference(collection.candidates.x_candidates[index].area)
				} else {
					?SnapAreaReference(none)
				}
				y_area := if index := y_candidate {
					?SnapAreaReference(collection.candidates.y_candidates[index].area)
				} else {
					?SnapAreaReference(none)
				}
				focus_x := if area := x_area {
					snap_area_contains_node(area, selection.focused_node_id)
				} else {
					false
				}
				focus_y := if area := y_area {
					snap_area_contains_node(area, selection.focused_node_id)
				} else {
					false
				}
				target_x := if area := x_area {
					snap_area_contains_node(area, selection.targeted_element_id)
				} else {
					false
				}
				target_y := if area := y_area {
					snap_area_contains_node(area, selection.targeted_element_id)
				} else {
					false
				}
				block_axis_is_y := snap_container.writing_mode == .horizontal_tb
				preferred_x := if focus_x || focus_y {
					focus_x
				} else if target_x || target_y {
					target_x
				} else if (x_area != none) != (y_area != none) {
					x_area != none
				} else {
					!block_axis_is_y
				}
				if preferred_x {
					if area := x_area {
						if index := find_snap_area_candidate(collection.candidates.y_candidates, area) {
							y_offset = resnap_offset_for_candidate(collection.candidates.y_candidates[index], current_offset.y())
							y_candidate = index
						} else {
							y_offset = fallback_resnap_offset(collection.candidates.y_candidates, current_offset.y(), collection.y_geometry.snapport_size, collection.snap_type.strictness, x)
							y_candidate = none
						}
					}
				} else if area := y_area {
					if index := find_snap_area_candidate(collection.candidates.x_candidates, area) {
						x_offset = resnap_offset_for_candidate(collection.candidates.x_candidates[index], current_offset.x())
						x_candidate = index
					} else {
						x_offset = fallback_resnap_offset(collection.candidates.x_candidates, current_offset.x(), collection.x_geometry.snapport_size, collection.snap_type.strictness, y)
						x_candidate = none
					}
				}
			}
		}
	}

	mut destination := snap_destination_for(current_offset, x_offset, y_offset, snap_axes)
	if offset := x_offset {
		destination.snapped_areas.x = record_resnapped_areas(x_candidate, collection.candidates.x_candidates, selection.snapped_areas.x, offset, current_offset.x(), destination.position.y())
	}
	if offset := y_offset {
		destination.snapped_areas.y = record_resnapped_areas(y_candidate, collection.candidates.y_candidates, selection.snapped_areas.y, offset, current_offset.y(), destination.position.x())
	}
	return destination
}

fn snap_selection_strategy_from_dom(strategy dom.ScrollSnapSelectionStrategy_) SnapSelectionStrategy {
	return SnapSelectionStrategy{
		type_:                       match strategy.type_ {
			.end_position { SnapSelectionType.end_position }
			.direction { SnapSelectionType.direction }
			.end_position_and_direction { SnapSelectionType.end_position_and_direction }
		}
		start_offset:                strategy.start_offset
		displacement:                strategy.displacement
		starting_positions_boundary: strategy.starting_positions_boundary
	}
}

fn scroll_snap_destination_to_dom(destination SnapDestination) dom.ScrollSnapDestination_ {
	mut x_areas := []dom.ScrollSnapAreaReference_{cap: destination.snapped_areas.x.len}
	mut y_areas := []dom.ScrollSnapAreaReference_{cap: destination.snapped_areas.y.len}
	for area in destination.snapped_areas.x {
		x_areas << dom.ScrollSnapAreaReference_{
			element_id:     area.element_id
			pseudo_element: area.pseudo_element
		}
	}
	for area in destination.snapped_areas.y {
		y_areas << dom.ScrollSnapAreaReference_{
			element_id:     area.element_id
			pseudo_element: area.pseudo_element
		}
	}
	return dom.ScrollSnapDestination_{
		position:        destination.position
		snapped_x:       destination.snapped_x
		snapped_y:       destination.snapped_y
		evaluated_x:     destination.evaluated_x
		evaluated_y:     destination.evaluated_y
		snapped_areas_x: x_areas
		snapped_areas_y: y_areas
	}
}

fn snapped_areas_from_dom(x []dom.ScrollSnapAreaReference_,
	y []dom.ScrollSnapAreaReference_) SnappedAreas {
	mut x_areas := []SnapAreaReference{cap: x.len}
	mut y_areas := []SnapAreaReference{cap: y.len}
	for area in x {
		x_areas << SnapAreaReference{
			element_id:     area.element_id
			pseudo_element: area.pseudo_element
		}
	}
	for area in y {
		y_areas << SnapAreaReference{
			element_id:     area.element_id
			pseudo_element: area.pseudo_element
		}
	}
	return SnappedAreas{x_areas, y_areas}
}

fn resnap_committed_paintables(node &dom.LayoutNode, boxes_by_layout map[u64]&BlockBox,
	focused_node_id i64, targeted_element_id i64) {
	for paintable in node.paintables() {
		if !paintable.is_paintable_box() {
			continue
		}
		mut box_paintable := unsafe { &dom.PaintableBox(paintable) }
		previous := snapped_areas_from_dom(box_paintable.snapped_areas_x_, box_paintable.snapped_areas_y_)
		box := boxes_by_layout[u64(box_paintable.layout_handle)] or { continue }
		if previous.is_empty() && !is_scroll_snap_container(box) {
			continue
		}
		scale := box_layout_coordinate_scale(box)
		destination := select_resnap_destination(box, scaled_dom_point(box_paintable.scroll_offset(), scale), ResnapSelection{
			snapped_areas:       previous
			focused_node_id:     focused_node_id
			targeted_element_id: targeted_element_id
		})
		box_paintable.apply_scroll_snap_destination(scroll_snap_destination_in_css_coordinates(destination, scale))
	}
	for child in node.children_ {
		resnap_committed_paintables(child, boxes_by_layout, focused_node_id, targeted_element_id)
	}
}

fn paint_tree_has_scroll_snap_container(box &BlockBox) bool {
	if is_scroll_snap_container(box) { return true }
	for index in 0 .. box.children.len {
		if paint_tree_has_scroll_snap_container(unsafe { &box.children[index] }) { return true }
	}
	return false
}

fn layout_tree_has_remembered_snap_areas(node &dom.LayoutNode) bool {
	for paintable in node.paintables_ {
		if !paintable.is_paintable_box() { continue }
		box := unsafe { &dom.PaintableBox(paintable) }
		if box.snapped_areas_x_.len > 0 || box.snapped_areas_y_.len > 0 { return true }
	}
	for child in node.children_ {
		if layout_tree_has_remembered_snap_areas(child) { return true }
	}
	return false
}

fn resnap_document_scroll_containers(result &DocumentLayoutResult) {
	viewport := result.document.layout_node() or { return }
	root := viewport.root_layout_node() or { return }
	previous_viewport_areas := snapped_areas_from_dom(result.document.viewport_snapped_areas_x(),
		result.document.viewport_snapped_areas_y())
	// A page without snap containers or remembered destinations has no work.
	// Avoid constructing the box index and paintable snapshots in that case.
	// Actual snapping retains the existing snapshot across scroll callbacks.
	if previous_viewport_areas.is_empty() && !paint_tree_has_scroll_snap_container(&result.paint_tree)
		&& !layout_tree_has_remembered_snap_areas(root) { return }
	mut boxes_by_layout := map[u64]&BlockBox{}
	mut paint_tree := result.paint_tree
	collect_compatibility_boxes(mut paint_tree, mut boxes_by_layout)
	focused_node_id := if focused := result.document.focused_area() {
		i64(focused.unique_id())
	} else {
		i64(0)
	}
	targeted_element_id := if target := result.document.target_element() {
		i64(target.as_node().unique_id())
	} else {
		i64(0)
	}
	if !previous_viewport_areas.is_empty() || is_scroll_snap_container(&result.paint_tree) {
		viewport_rect := result.document.viewport_rect()
		destination := select_resnap_destination(&result.paint_tree, scaled_dom_point(dom.CSSPixelPoint_{
			x_: viewport_rect.x
			y_: viewport_rect.y
		}, result.document.layout_coordinate_scale()), ResnapSelection{
			snapped_areas: previous_viewport_areas
			focused_node_id: focused_node_id
			targeted_element_id: targeted_element_id
		})
		dom_destination := scroll_snap_destination_in_css_coordinates(destination, result.document.layout_coordinate_scale())
		mut mutable_document := unsafe { &dom.Document(result.document) }
		mutable_document.record_viewport_scroll_snap_destination(dom_destination)
		if dom_destination.position.x() != viewport_rect.x || dom_destination.position.y() != viewport_rect.y {
			if navigable := result.document.navigable() {
				navigable.perform_scroll_of_viewport_scrolling_box(dom_destination.position)
			}
			updated_viewport := result.document.viewport_rect()
			if updated_viewport.x == viewport_rect.x && updated_viewport.y == viewport_rect.y {
				mutable_document.set_viewport_rect(dom.Rect{
					x: dom_destination.position.x()
					y: dom_destination.position.y()
					width: viewport_rect.width
					height: viewport_rect.height
				})
				mutable_document.inform_all_viewport_clients_about_the_current_viewport_rect()
			}
		}
	}
	resnap_committed_paintables(root, boxes_by_layout, focused_node_id, targeted_element_id)
}

fn layout_paintable_adjust_scroll_destination(target voidptr, layout_handle voidptr,
	destination dom.CSSPixelPoint_, strategy dom.ScrollSnapSelectionStrategy_) dom.ScrollSnapDestination_ {
	if layout_handle == unsafe { nil } {
		return dom.ScrollSnapDestination_{ position: destination }
	}
	result := viewport_layout_result(target)
	mut boxes_by_layout := map[u64]&BlockBox{}
	mut paint_tree := result.paint_tree
	collect_compatibility_boxes(mut paint_tree, mut boxes_by_layout)
	box := boxes_by_layout[u64(layout_handle)] or {
		return dom.ScrollSnapDestination_{ position: destination }
	}
	scale := result.document.layout_coordinate_scale()
	return scroll_snap_destination_in_css_coordinates(adjust_scroll_destination_for_snapping(box,
		scaled_dom_point(destination, scale), snap_selection_strategy_in_layout_coordinates(strategy, scale)), scale)
}

fn layout_viewport_adjust_scroll_destination(target voidptr, destination dom.CSSPixelPoint_,
	strategy dom.ScrollSnapSelectionStrategy_) dom.ScrollSnapDestination_ {
	result := viewport_layout_result(target)
	scale := result.document.layout_coordinate_scale()
	return scroll_snap_destination_in_css_coordinates(adjust_scroll_destination_for_snapping(&result.paint_tree,
		scaled_dom_point(destination, scale), snap_selection_strategy_in_layout_coordinates(strategy, scale)), scale)
}
