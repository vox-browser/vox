module layout

import css
import dom
import html

fn snap_candidate(offset f64, area_id i64, always_stop bool) SnapPositionCandidate {
	return SnapPositionCandidate{
		offset:                         offset
		area:                           SnapAreaReference{ element_id: area_id }
		cross_axis_visible_range_start: -1000
		cross_axis_visible_range_end:   1000
		always_stop:                    always_stop
	}
}

fn test_scroll_snap_axis_choice_obeys_mandatory_proximity_and_always_stop() {
	candidates := [
		snap_candidate(0, 1, false),
		snap_candidate(100, 2, true),
		snap_candidate(300, 3, false),
	]
	end_choice := choose_snap_offset_for_axis(candidates, SnapAxisSelection{
		destination: 260
		start:       260
	}, 90, .mandatory, none, none) or { panic('missing mandatory choice') }
	assert end_choice.offset == 300

	assert choose_snap_offset_for_axis(candidates, SnapAxisSelection{
		destination: 250
		start:       250
	}, 90, .proximity, none, none) == none

	directional_choice := choose_snap_offset_for_axis(candidates, SnapAxisSelection{
		destination:                 300
		start:                       0
		direction:                   300
		starting_positions_boundary: 0
	}, 90, .mandatory, none, none) or { panic('missing directional choice') }
	assert directional_choice.offset == 100
}

fn test_scroll_snap_covering_area_contributes_destination_inside_valid_range() {
	mut candidates := [SnapPositionCandidate{
		offset:                         0
		area:                           SnapAreaReference{ element_id: 1 }
		covering_ranges:                [CoveringRange{0, 200}]
		cross_axis_visible_range_start: -1000
		cross_axis_visible_range_end:   1000
	}]
	restrict_covering_ranges_to_valid_snap_positions(mut candidates, 100)
	choice := choose_snap_offset_for_axis(candidates, SnapAxisSelection{
		destination: 135
		start:       135
	}, 100, .mandatory, none, none) or { panic('missing covering choice') }
	assert choice.offset == 135
}

fn test_scroll_snap_axes_follow_logical_writing_mode() {
	assert snap_axes_of_scroll_container(&BlockBox{
		writing_mode:     .horizontal_tb

		scroll_snap_data: retained_block_box_scroll_snap(BlockBoxScrollSnapData{
			scroll_snap_type: css.ScrollSnapType{ axis: .inline_, strictness: .mandatory }
		})
	}) == SnapAxes{ x: true }
	assert snap_axes_of_scroll_container(&BlockBox{
		writing_mode:     .vertical_rl

		scroll_snap_data: retained_block_box_scroll_snap(BlockBoxScrollSnapData{
			scroll_snap_type: css.ScrollSnapType{ axis: .inline_, strictness: .mandatory }
		})
	}) == SnapAxes{ y: true }
	assert snap_axes_of_scroll_container(&BlockBox{
		writing_mode:     .vertical_lr

		scroll_snap_data: retained_block_box_scroll_snap(BlockBoxScrollSnapData{
			scroll_snap_type: css.ScrollSnapType{ axis: .block, strictness: .mandatory }
		})
	}) == SnapAxes{ x: true }
}

fn test_element_programmatic_scroll_uses_committed_snap_areas() {
	document := html.parse_document('<!doctype html><style>html,body{margin:0}#scroller{width:100px;height:100px;overflow:auto;scroll-snap-type:y mandatory}.area{height:100px;scroll-snap-align:start}</style><div id="scroller"><div id="first" class="area"></div><div id="second" class="area"></div><div id="third" class="area"></div></div>')
	_ = layout_document_typed_in_viewport(document, 320, 240)
	scroller := document.get_element_by_id('scroller') or { panic('missing scroller') }
	mut paintable := scroller.paintable_box() or { panic('missing scroller paintable') }
	assert paintable.set_scroll_offset(dom.CSSPixelPoint_{ y_: 138 })
	assert paintable.scroll_offset().y() == 100
	second := document.get_element_by_id('second') or { panic('missing second area') }
	assert paintable.snapped_areas().y.len == 1
	assert paintable.snapped_areas().y[0].element_id == i64(second.as_node().unique_id())
}

fn test_element_scroll_snaps_after_initial_layout() {
	document := html.parse_document('<!doctype html><style>html,body{margin:0}#scroller{width:100px;height:100px;overflow:hidden;scroll-snap-type:y mandatory}#spacer{height:50px}#target{height:100px;scroll-snap-align:start}</style><div id="scroller"><div id="spacer"></div><div id="target"></div></div>')
	_ = layout_document_typed_in_viewport(document, 320, 240)
	scroller := document.get_element_by_id('scroller') or { panic('missing scroller') }
	paintable := scroller.paintable_box() or { panic('missing scroller paintable') }
	assert paintable.scroll_offset().y() == 50
	target := document.get_element_by_id('target') or { panic('missing snap target') }
	assert paintable.snapped_areas().y.len == 1
	assert paintable.snapped_areas().y[0].element_id == i64(target.as_node().unique_id())
}

fn test_directional_element_scroll_honors_always_stop() {
	document := html.parse_document('<!doctype html><style>html,body{margin:0}#scroller{width:100px;height:100px;overflow:auto;scroll-snap-type:y mandatory}.area{height:100px;scroll-snap-align:start}#second{scroll-snap-stop:always}</style><div id="scroller"><div class="area"></div><div id="second" class="area"></div><div class="area"></div><div class="area"></div></div>')
	_ = layout_document_typed_in_viewport(document, 320, 240)
	scroller := document.get_element_by_id('scroller') or { panic('missing scroller') }
	mut paintable := scroller.paintable_box() or { panic('missing scroller paintable') }
	assert paintable.set_scroll_offset_with_snap_strategy(dom.CSSPixelPoint_{ y_: 300 },
		dom.ScrollSnapSelectionStrategy_{
			type_: .end_position_and_direction
			start_offset: dom.CSSPixelPoint_{}
			displacement: dom.CSSPixelPoint_{ y_: 300 }
		})
	assert paintable.scroll_offset().y() == 100
}

fn test_scroll_snap_reselects_remembered_area_after_relayout() {
	document := html.parse_document('<!doctype html><style>html,body{margin:0}#scroller{width:100px;height:100px;overflow:auto;scroll-snap-type:y mandatory}.area{height:100px;scroll-snap-align:start}</style><div id="scroller"><div id="first" class="area"></div><div id="second" class="area"></div><div id="third" class="area"></div></div>')
	_ = layout_document_typed_in_viewport(document, 320, 240)
	scroller := document.get_element_by_id('scroller') or { panic('missing scroller') }
	mut paintable := scroller.paintable_box() or { panic('missing scroller paintable') }
	assert paintable.set_scroll_offset(dom.CSSPixelPoint_{ y_: 120 })
	assert paintable.scroll_offset().y() == 100

	mut first := document.get_element_by_id('first') or { panic('missing first area') }
	first.set_attribute_value('style', 'height:150px')
	mut mutable_document := unsafe { &dom.Document(document) }
	mutable_document.update_layout(.debugging)
	updated := scroller.paintable_box() or { panic('missing updated scroller paintable') }
	assert updated.scroll_offset().y() == 150
	second := document.get_element_by_id('second') or { panic('missing second area') }
	assert updated.snapped_areas().y.len == 1
	assert updated.snapped_areas().y[0].element_id == i64(second.as_node().unique_id())
}

fn test_viewport_scroll_uses_document_element_snap_type() {
	document := html.parse_document('<!doctype html><style>html,body{margin:0}html{scroll-snap-type:y mandatory}.area{height:100px;scroll-snap-align:start}</style><body><div class="area"></div><div id="second" class="area"></div><div class="area"></div></body>')
	_ = layout_document_typed_in_viewport(document, 100, 100)
	mut mutable_document := unsafe { &dom.Document(document) }
	destination := mutable_document.adjust_viewport_scroll_destination(dom.CSSPixelPoint_{ y_: 138 }, dom.ScrollSnapSelectionStrategy_{})
	assert destination.position.y() == 100
	second := document.get_element_by_id('second') or { panic('missing second area') }
	assert destination.snapped_areas_y.len == 1
	assert destination.snapped_areas_y[0].element_id == i64(second.as_node().unique_id())
}

fn test_viewport_scroll_snaps_after_initial_layout() {
	document := html.parse_document('<!doctype html><style>html,body{margin:0}html{scroll-snap-type:y mandatory}#spacer{height:50px}#target{height:100px;scroll-snap-align:start}</style><body><div id="spacer"></div><div id="target"></div></body>')
	_ = layout_document_typed_in_viewport(document, 100, 100)
	assert document.viewport_rect().y == 50
	target := document.get_element_by_id('target') or { panic('missing snap target') }
	assert document.viewport_snapped_areas_y().len == 1
	assert document.viewport_snapped_areas_y()[0].element_id == i64(target.as_node().unique_id())
}

fn test_viewport_scroll_reselects_remembered_area_after_relayout() {
	document := html.parse_document('<!doctype html><style>html,body{margin:0}html{scroll-snap-type:y mandatory}.area{height:100px;scroll-snap-align:start}</style><body><div id="first" class="area"></div><div id="second" class="area"></div><div class="area"></div></body>')
	_ = layout_document_typed_in_viewport(document, 100, 100)
	mut mutable_document := unsafe { &dom.Document(document) }
	destination := mutable_document.adjust_viewport_scroll_destination(dom.CSSPixelPoint_{ y_: 120 },
		dom.ScrollSnapSelectionStrategy_{})
	assert destination.position.y() == 100
	mutable_document.set_viewport_rect(dom.Rect{0, destination.position.y(), 100, 100})

	mut first := document.get_element_by_id('first') or { panic('missing first area') }
	first.set_attribute_value('style', 'height:150px')
	mutable_document.update_layout(.debugging)
	assert document.viewport_rect().y == 150
	second := document.get_element_by_id('second') or { panic('missing second area') }
	assert document.viewport_snapped_areas_y().len == 1
	assert document.viewport_snapped_areas_y()[0].element_id == i64(second.as_node().unique_id())
}
