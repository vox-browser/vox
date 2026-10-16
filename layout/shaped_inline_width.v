module layout

import css
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
	node    &Node              = unsafe { nil }
	run     &platform.GlyphRun = unsafe { nil }
	end     int
	precise f64
	rounded CSSPixels
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
		|| run.glyphs_[0].position.x != 0 || node.computed_values().text_align() == .justify {
		projection.node = unsafe { nil }
		return item.border_box_width()
	}
	if projection.node != unsafe { nil } && layout_nodes_same(projection.node, node)
		&& projection.end == item.offset_in_node
		&& voidptr(projection.run.font()) == voidptr(run.font())
		&& projection.run.face() == run.face() {
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
		if precise := last.precise_inline_length_ {
			if run := last.glyph_run_ {
				if !last.has_soft_wrap_opportunity_after() {
					projection = ProjectedTextAdvance{
						node:    last.layout_node_
						run:     unsafe { run }
						end:     last.start_ + last.length_in_code_units_
						precise: precise
						rounded: last.inline_length_
					}
				}
			}
		}
	}
	mut width := projection.append(item)
	for next in following {
		width = width.plus(projection.append(next))
	}
	return width
}
