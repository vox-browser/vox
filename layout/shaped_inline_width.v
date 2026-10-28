module layout

import math
import platform

// ShapeResultView::SnappedWidth() rounds an entire shaped item upward to a
// LayoutUnit. Glyph positions stay precise; this rounding belongs to the
// inline item's outer advance, rather than to each glyph or word.
fn inline_advance_to_css_pixels(value f64, font &platform.Font) CSSPixels {
	if font.font_rendering_policy == .chromium {
		return CSSPixels.nearest_value_for(math.ceil(value * 64) / 64)
	}
	return CSSPixels.nearest_value_for(value)
}

fn shaped_inline_width(run &platform.GlyphRun, additional f64) CSSPixels {
	return inline_advance_to_css_pixels(f64(run.width()) + additional, run.font())
}

struct ProjectedTextAdvance {
mut:
	node           &Node              = unsafe { nil }
	run            &platform.GlyphRun = unsafe { nil }
	end            int
	precise        f64
	rounded        CSSPixels
	segment_start  int
	segment_length int
	segment_width  f64
}

fn (mut projection ProjectedTextAdvance) append(item &InlineLevelItem) CSSPixels {
	mut contribution := item.width
	run := item.glyph_run or {
		projection.node = unsafe { nil }
		return item.border_box_width()
	}
	node := item.node or {
		projection.node = unsafe { nil }
		return item.border_box_width()
	}
	if run.font().font_rendering_policy != .chromium || run.text_type() == .rtl
		|| item.width != shaped_inline_width(run, 0) || run.glyphs_.len == 0
		|| node.computed_values().text_align() == .justify {
		projection.node = unsafe { nil }
		return item.border_box_width()
	}
	// A chunk continuing the same text node joins its text item, even across a
	// fallback font or a line-break opportunity, as append_text_item() does.
	continues_item := projection.node != unsafe { nil } && layout_nodes_same(projection.node, node)
		&& projection.end == item.offset_in_node
	if !continues_item && run.glyphs_[0].position.x != 0 {
		projection.node = unsafe { nil }
		return item.border_box_width()
	}
	continues_segment := continues_item && projection.run != unsafe { nil }
		&& voidptr(projection.run.font()) == voidptr(run.font())
		&& projection.run.face() == run.face()
		&& item.border_box_width() == item.width && item.margin_start.raw_value() == 0
	if continues_segment {
		projection.segment_length += item.length_in_node
		projection.segment_width += f64(run.width())
	} else {
		projection.segment_start = item.offset_in_node
		projection.segment_length = item.length_in_node
		projection.segment_width = f64(run.width())
	}
	mut covered := 0
	mut has_glyph_indices := false
	for glyph in run.glyphs_ {
		covered += glyph.length_in_code_units
		has_glyph_indices = has_glyph_indices || glyph.glyph_index != 0
	}
	if covered != item.length_in_node || !has_glyph_indices {
		projection.segment_length = 0
	}
	if continues_item && item.border_box_width() == item.width && item.margin_start.raw_value() == 0 {
		projection.precise += f64(run.width())
		width := inline_advance_to_css_pixels(projection.precise, run.font())
		contribution = width.minus(projection.rounded)
		projection.rounded = width
	} else {
		projection.precise = f64(run.width())
		projection.rounded = item.width
	}
	projection.node = node
	projection.run = run
	projection.end = item.offset_in_node + item.length_in_node
	return item.border_box_width().minus(item.width).plus(contribution)
}

// Fitting must use the same merged advance as append_text_item(). Adding
// individually rounded word widths can otherwise wrap a shrink-to-fit box
// whose max-content width already fits the complete shaped text.
fn (mut builder LineBuilder) projected_text_sequence_width(item &InlineLevelItem,
	following []InlineLevelItem) CSSPixels {
	line := builder.ensure_last_line_box()
	mut projection := ProjectedTextAdvance{}
	if line.direction_ == .ltr && line.fragments_.len > 0 {
		last := line.fragments_.last()
		if last.chains_item_ && last.inline_offset_.plus(last.inline_length_) == line.inline_length_ {
			if run := last.glyph_run_ {
				projection = ProjectedTextAdvance{
					node:           last.layout_node_
					run:            unsafe { run }
					end:            last.start_ + last.length_in_code_units_
					precise:        last.item_prefix_ + last.item_width_
					rounded:        last.item_offset_.plus(last.inline_length_)
					segment_start:  last.start_
					segment_length: last.length_in_code_units_
					segment_width:  last.item_width_
				}
			}
		}
	}
	mut width := projection.append(item)
	for next in following {
		width = width.plus(projection.append(next))
	}
	return width.plus(projection.chromium_line_end_correction())
}

// Intrinsic constraints decide soft wrapping without consulting a measured
// advance: min-content always breaks, while max-content and indefinite never
// do. Keep the ordinary projected width for definite lines, including widths
// reduced by floats. Overflow splitting still uses the full measurement.
fn (mut builder LineBuilder) projected_text_sequence_width_for_line_break(item &InlineLevelItem,
	following []InlineLevelItem) CSSPixels {
	if !builder.available_width_for_current_line.is_definite() {
		return CSSPixels.new(0)
	}
	return builder.projected_text_sequence_width(item, following)
}
