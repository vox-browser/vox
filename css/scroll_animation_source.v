// Anonymous scroll() clocks read the last committed layout without invoking
// layout recursively during animated-style sampling.
module css

import dom
import math

pub struct ScrollAnimationRange {
pub mut:
	start LengthPercentage = LengthPercentage.from_percentage(Percentage.new(0))
	end LengthPercentage = LengthPercentage.from_percentage(Percentage.new(100))
	has_named_range bool
}

struct ScrollAttachmentTiming {
	start f64
	duration f64
}

fn scroll_animation_range_endpoint(property PropertyID, raw &dom.StyleValue) ?LengthPercentage {
	value := style_value_logic_from_dom(property, raw) or { return none }
	entry := if value is StyleValueList && value.size() == 1 { value.value_at(0, false) } else { value }
	if entry.to_keyword() == .normal {
		return LengthPercentage.from_percentage(Percentage.new(if property == .animation_range_start { 0 } else { 100 }))
	}
	if entry is LengthStyleValue || entry is PercentageStyleValue || entry is CalculatedStyleValue {
		return LengthPercentage.from_style_value_logic(entry)
	}
	// Named ranges belong to view progress timelines, which have a separate
	// unresolved source model. Do not substitute a document-clock animation.
	return none
}

fn scroll_animation_range_from_values(start &dom.StyleValue, end &dom.StyleValue) ScrollAnimationRange {
	start_offset := scroll_animation_range_endpoint(.animation_range_start, start) or {
		return ScrollAnimationRange{has_named_range: true}
	}
	end_offset := scroll_animation_range_endpoint(.animation_range_end, end) or {
		return ScrollAnimationRange{has_named_range: true}
	}
	return ScrollAnimationRange{start: start_offset, end: end_offset}
}

fn (range ScrollAnimationRange) timing(extent f64, context LengthResolutionContext, iterations f64) ?ScrollAttachmentTiming {
	if range.has_named_range || extent <= 0 { return none }
	basis := CSSPixels.nearest_value_for(extent)
	start := 1000 * range.start.to_px(context, basis).to_double() / extent
	end := 1000 * range.end.to_px(context, basis).to_double() / extent
	return ScrollAttachmentTiming{
		start: start
		duration: if iterations > 0 && !math.is_inf(iterations, 0) { math.max(0.0, end - start) / iterations } else { 0 }
	}
}

fn scroll_axis_is_horizontal(axis Axis, mode WritingMode) bool {
	return match axis {
		.x { true }
		.y { false }
		.inline_ { inline_axis_is_horizontal(mode) }
		.block { !inline_axis_is_horizontal(mode) }
	}
}

fn scroll_axis_is_reversed(horizontal bool, mode WritingMode, direction Direction) bool {
	if horizontal {
		return match mode {
			.horizontal_tb { direction == .rtl }
			.vertical_rl, .sideways_rl { true }
			else { false }
		}
	}
	return match mode {
		.horizontal_tb { false }
		.sideways_lr { direction == .ltr }
		else { direction == .rtl }
	}
}

fn scroll_timeline_source_supports_axis(source &dom.Element, axis Axis) bool {
	if source.is_document_element() { return true }
	style := computed_properties_for_element(source) or { return false }
	overflow := if scroll_axis_is_horizontal(axis, style.writing_mode()) { style.overflow_x() } else { style.overflow_y() }
	return overflow !in [.visible, .clip]
}

fn (timeline &AnimationTimeline) anonymous_scroll_source(subject &dom.Element) ?&dom.Element {
	if timeline.scroll_scroller == .root { return subject.document().document_element() }
	if timeline.scroll_scroller == .self_ {
		return if scroll_timeline_source_supports_axis(subject, timeline.scroll_axis) { ?&dom.Element(subject) } else { none }
	}
	for parent := subject.as_node().flat_tree_parent_element(); parent != none; {
		candidate := parent or { break }
		if scroll_timeline_source_supports_axis(candidate, timeline.scroll_axis) { return candidate }
		parent = candidate.as_node().flat_tree_parent_element()
	}
	return none
}

fn (mut timeline AnimationTimeline) sample_anonymous_scroll_source() ?f64 {
	timeline.current_time_ms_ = none
	id := timeline.scroll_subject_id or { return none }
	node := dom.Node.from_unique_id(id) or { return none }
	if !node.is_connected() || node.paintable_box() == none { return none }
	subject := node.as_element() or { return none }
	document := timeline.associated_document or { return none }
	if voidptr(document) != voidptr(subject.document()) || !document.is_active() { return none }
	source := timeline.anonymous_scroll_source(subject) or { return none }
	style := computed_properties_for_element(source) or { return none }
	root := source.is_document_element()
	paintable := if root { document.as_node().paintable_box() or { return none } } else { source.paintable_box() or { return none } }
	horizontal := scroll_axis_is_horizontal(timeline.scroll_axis, style.writing_mode())
	reversed := scroll_axis_is_reversed(horizontal, style.writing_mode(), style.direction())
	minimum := paintable.minimum_scroll_offset()
	maximum := paintable.maximum_scroll_offset()
	offset := if root {
		viewport := document.viewport_rect()
		dom.CSSPixelPoint_{x_: viewport.x, y_: viewport.y}
	} else { paintable.scroll_offset() }
	extent := if reversed { -(if horizontal { minimum.x() } else { minimum.y() }) } else { if horizontal { maximum.x() } else { maximum.y() } }
	if extent <= 0 { return none }
	position := (if horizontal { offset.x() } else { offset.y() }) * (if reversed { -1.0 } else { 1.0 })
	timeline.current_time_ms_ = 1000 * math.max(0.0, math.min(1.0, position / extent))
	return extent
}
