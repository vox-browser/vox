module layout

import css
import dom

// A minimal block formatting context: it consumes the css computed-value layer (computed lengths,
// percentages) to produce real box geometry, including the box model — margins, padding, and
// borders. Block boxes stack vertically; each is sized within its containing block's content width;
// a box with `height: auto` takes the height of its stacked children. This is the first layout code
// that actually runs on the cascade output — and where percentage widths (which computed_length_px
// can't resolve without a containing block) get resolved.
//
// Adjoining vertical margins of in-flow siblings collapse (CSS 2.1 §8.3.1). A box with no block-level
// children but with text content gets a height from a coarse inline pass (line count × line-height).
// `box-sizing: border-box` makes a specified width/height include padding+border. Used width and
// height are clamped by min/max-width and min/max-height.
//
// FIXME (deliberately out of scope for this slice): a real inline formatting context (glyph metrics,
// word-boundary wrapping, inline box geometry), mixed block+inline content (anonymous block boxes),
// floats, parent/child and self (empty-block) margin collapsing, `auto` margin resolution (centering
// / distributing remaining space — `auto` margins are treated as 0 here), and definite % heights.

// The used thickness of a box's four edges (margin / padding / border), in CSS px.
pub struct BoxEdges {
pub:
	top    f64
	right  f64
	bottom f64
	left   f64
}

// A laid-out block box: `x`/`y`/`width`/`height` are the *content box* geometry in CSS px, relative
// to the top-left of the initial containing block; `margin`/`border`/`padding` surround it.
pub struct BlockBox {
pub:
	tag_name string
pub mut:
	x        f64
	y        f64
	width    f64
	height   f64
	margin   BoxEdges
	border   BoxEdges
	padding  BoxEdges
	children []BlockBox
}

// The margin-box height: the vertical space this box occupies in its parent's flow.
pub fn (b &BlockBox) margin_box_height() f64 {
	return b.margin.top + b.border.top + b.padding.top + b.height + b.padding.bottom +
		b.border.bottom + b.margin.bottom
}

// The margin-box width: content plus padding, border, and margin on both sides.
pub fn (b &BlockBox) margin_box_width() f64 {
	return b.margin.left + b.border.left + b.padding.left + b.width + b.padding.right +
		b.border.right + b.margin.right
}

// The used margins of `element` (each `auto`/absent margin is 0 — no centering yet). Percentages
// resolve against the containing block's width. Factored out so the parent can peek a child's top
// margin before laying it out, to position it with margin collapsing.
fn used_margins(element &dom.Element, containing_width f64, author_rules []&css.CSSRule) BoxEdges {
	return BoxEdges{
		top:    used_length_or_zero(element, 'margin-top', containing_width, author_rules)
		right:  used_length_or_zero(element, 'margin-right', containing_width, author_rules)
		bottom: used_length_or_zero(element, 'margin-bottom', containing_width, author_rules)
		left:   used_length_or_zero(element, 'margin-left', containing_width, author_rules)
	}
}

// Collapse a set of adjoining vertical margins into one, per CSS 2.1 §8.3.1: the largest positive
// margin plus the most negative margin (so max positive when all positive; their difference when
// mixed; the most negative when all negative).
fn collapse_margins(margins []f64) f64 {
	mut max_positive := 0.0
	mut min_negative := 0.0
	for m in margins {
		if m > max_positive {
			max_positive = m
		}
		if m < min_negative {
			min_negative = m
		}
	}
	return max_positive + min_negative
}

// A length/percentage property resolved to px, or 0 when it's `auto`/absent/other. Percentages
// resolve against `basis` (for margins and padding that's the containing block's width, per spec).
fn used_length_or_zero(element &dom.Element, property_name string, basis f64, author_rules []&css.CSSRule) f64 {
	id := css.property_id_from_string(property_name) or { return 0 }
	if px := css.computed_length_px(element, id, author_rules) {
		return px
	}
	if pct := css.computed_percentage(element, id, author_rules) {
		return basis * pct / 100.0
	}
	return 0
}

// The used border width for one side. Per spec the computed border width is 0 when the corresponding
// border-style is `none`/`hidden`; otherwise it's the border-width length, or the thin/medium/thick
// keyword scale (1/3/5 px).
fn used_border(element &dom.Element, side string, author_rules []&css.CSSRule) f64 {
	style_id := css.property_id_from_string('border-${side}-style') or { return 0 }
	style := css.cascaded_value_with_ua(element, style_id, author_rules)
	if style == 'none' || style == 'hidden' {
		return 0
	}
	width_id := css.property_id_from_string('border-${side}-width') or { return 0 }
	if px := css.computed_length_px(element, width_id, author_rules) {
		return px
	}
	return match css.cascaded_value_with_ua(element, width_id, author_rules) {
		'thin' { 1.0 }
		'thick' { 5.0 }
		else { 3.0 } // 'medium' (the initial value) and any unresolved keyword
	}
}

// Whether a computed `display` value generates a block-level box in this engine. `none` generates
// no box at all; inline-level values (inline / inline-block / inline-*) are skipped because there is
// no inline formatting context yet. Everything else (block, list-item, flow-root, and — as a coarse
// approximation — flex/grid/table, which are block-level in their parent's flow) is laid out as a
// block. FIXME: `display: contents` should hoist the children rather than generate a box.
fn is_block_level_display(display string) bool {
	if display == 'none' {
		return false
	}
	return !display.starts_with('inline')
}

// The block-level element children of `node`, in document order. Text and other node types are
// skipped (no inline formatting context yet), as are elements whose computed `display` is `none` or
// inline-level — so `<head>`/`<script>`/`<style>` and inline elements no longer generate boxes.
fn block_child_elements(node &dom.Node, author_rules []&css.CSSRule) []&dom.Element {
	display_id := css.property_id_from_string('display') or { return []&dom.Element{} }
	mut elements := []&dom.Element{}
	for child in node.children_as_vector() {
		if element := child.as_element() {
			display := css.cascaded_value_with_ua(element, display_id, author_rules)
			if is_block_level_display(display) {
				elements << element
			}
		}
	}
	return elements
}

// The height of a block whose content is inline (text) rather than block-level children: the number
// of line boxes times the line-height. Line count is a coarse estimate — text is measured at ~0.5em
// per glyph (no real font metrics) and wrapped against the content width — so it is at least one line
// when there is any non-whitespace text.
//
// FIXME: this stands in for a real inline formatting context. It ignores real glyph advances, breaks
// only on width (not at word boundaries, so it can over/under-count near the wrap point), and uses
// the block's own font/line-height for all text rather than each inline box's.
fn inline_content_height(element &dom.Element, text string, content_width f64, author_rules []&css.CSSRule) f64 {
	glyphs := text.fields().join(' ').runes().len // collapse whitespace runs, count code points
	if glyphs == 0 {
		return 0.0
	}
	line_height := css.computed_line_height_px(element, author_rules)
	font_px := css.computed_font_size_px(element, author_rules)
	text_width := f64(glyphs) * 0.5 * font_px
	mut lines := 1
	if content_width > 0 {
		exact := text_width / content_width
		lines = int(exact)
		if f64(lines) < exact {
			lines++ // ceil
		}
		if lines < 1 {
			lines = 1
		}
	}
	return f64(lines) * line_height
}

// Whether `element` uses the border-box box model (specified width/height include padding+border)
// rather than the default content-box.
fn box_sizing_is_border_box(element &dom.Element, author_rules []&css.CSSRule) bool {
	id := css.property_id_from_string('box-sizing') or { return false }
	return css.cascaded_value_with_ua(element, id, author_rules) == 'border-box'
}

// The used *content* width for `element` in a containing block `containing_width` px wide. A length
// or percentage sets the width per the box model: content-box uses it directly; border-box subtracts
// the horizontal border+padding (`border_padding_lr`). `auto` fills the space left after the
// horizontal margins, border, and padding. All results are clamped at 0.
fn used_content_width(element &dom.Element, containing_width f64, margins_lr f64, border_padding_lr f64, border_box bool, author_rules []&css.CSSRule) f64 {
	width_id := css.property_id_from_string('width') or {
		return non_negative(containing_width - margins_lr - border_padding_lr)
	}
	if px := css.computed_length_px(element, width_id, author_rules) {
		return non_negative(if border_box { px - border_padding_lr } else { px })
	}
	if pct := css.computed_percentage(element, width_id, author_rules) {
		specified := containing_width * pct / 100.0
		return non_negative(if border_box { specified - border_padding_lr } else { specified })
	}
	return non_negative(containing_width - margins_lr - border_padding_lr)
}

// Resolve a min-/max-size property to a *content-space* px constraint, or none when it imposes no
// limit (`none`/`auto`/unset, or a percentage with no basis). `basis` is the containing measure for
// percentages (none to skip them, as for heights with no definite containing height); border-box
// subtracts the relevant border+padding (`border_padding`), matching how width/height are treated.
fn resolve_size_constraint(element &dom.Element, property_name string, basis ?f64, border_padding f64, border_box bool, author_rules []&css.CSSRule) ?f64 {
	id := css.property_id_from_string(property_name) or { return none }
	if px := css.computed_length_px(element, id, author_rules) {
		return non_negative(if border_box { px - border_padding } else { px })
	}
	if b := basis {
		if pct := css.computed_percentage(element, id, author_rules) {
			specified := b * pct / 100.0
			return non_negative(if border_box { specified - border_padding } else { specified })
		}
	}
	return none
}

// Clamp a used size by its min/max constraints (CSS 2.1 §10.4/§10.7): apply max first, then min, so
// min wins when the two cross. `max` is none when there is no upper limit.
fn clamp_size(value f64, min f64, max ?f64) f64 {
	mut v := value
	if m := max {
		if v > m {
			v = m
		}
	}
	if v < min {
		v = min
	}
	return v
}

fn non_negative(v f64) f64 {
	return if v > 0 { v } else { 0.0 }
}

// Lay out `element` and its block descendants. `x`/`y` is the top-left of this box's *margin box*;
// the returned box's content origin is inset by its margin, border, and padding. Children stack
// vertically within the content box, each advancing the cursor by its own margin-box height; the
// parent's content height is that stacked total unless it declares an explicit height.
pub fn layout_block(element &dom.Element, x f64, y f64, containing_width f64, author_rules []&css.CSSRule) BlockBox {
	margin := used_margins(element, containing_width, author_rules)
	border := BoxEdges{
		top:    used_border(element, 'top', author_rules)
		right:  used_border(element, 'right', author_rules)
		bottom: used_border(element, 'bottom', author_rules)
		left:   used_border(element, 'left', author_rules)
	}
	padding := BoxEdges{
		top:    used_length_or_zero(element, 'padding-top', containing_width, author_rules)
		right:  used_length_or_zero(element, 'padding-right', containing_width, author_rules)
		bottom: used_length_or_zero(element, 'padding-bottom', containing_width, author_rules)
		left:   used_length_or_zero(element, 'padding-left', containing_width, author_rules)
	}
	border_box := box_sizing_is_border_box(element, author_rules)
	margins_lr := margin.left + margin.right
	border_padding_lr := border.left + border.right + padding.left + padding.right
	tentative_width := used_content_width(element, containing_width, margins_lr, border_padding_lr,
		border_box, author_rules)
	// Clamp the width by min-width/max-width (both box-sizing-aware, resolved in content space).
	min_width := resolve_size_constraint(element, 'min-width', containing_width, border_padding_lr,
		border_box, author_rules) or { 0.0 }
	max_width := resolve_size_constraint(element, 'max-width', containing_width, border_padding_lr,
		border_box, author_rules)
	width := clamp_size(tentative_width, min_width, max_width)

	content_x := x + margin.left + border.left + padding.left
	content_y := y + margin.top + border.top + padding.top

	block_children := block_child_elements(element.as_node(), author_rules)

	// A box with block-level children establishes a block formatting context; a box with none but
	// with inline (text) content establishes an inline one. FIXME: a box with BOTH would wrap its
	// inline runs in anonymous block boxes — here block children win and inline text is ignored.
	mut children := []BlockBox{}
	mut content_height := 0.0
	if block_children.len > 0 {
		// Lay children out in flow. Adjoining vertical margins collapse (CSS 2.1 §8.3.1): the gap
		// between a child's top border edge and the previous child's bottom border edge is the
		// collapse of the previous child's bottom margin with this child's top margin, not their sum.
		// `flow_bottom` tracks the previous child's bottom *border* edge; each child's margin box is
		// positioned so its border-box top lands at `flow_bottom + collapsed_gap`.
		mut flow_bottom := content_y
		mut prev_bottom_margin := 0.0
		mut has_prev := false
		for child in block_children {
			child_margins := used_margins(child, width, author_rules)
			gap := if has_prev {
				collapse_margins([prev_bottom_margin, child_margins.top])
			} else {
				child_margins.top // first child: no sibling above to collapse with
			}
			margin_box_top := flow_bottom + gap - child_margins.top
			child_box := layout_block(child, content_x, margin_box_top, width, author_rules)
			flow_bottom = margin_box_top + child_box.margin.top + child_box.border.top +
				child_box.padding.top + child_box.height + child_box.padding.bottom +
				child_box.border.bottom
			prev_bottom_margin = child_box.margin.bottom
			has_prev = true
			children << child_box
		}
		// Auto height spans the children's margin box (the last child's bottom margin is included; it
		// would collapse with the parent's own bottom margin only if there were no bottom
		// border/padding — parent/child collapsing is a FIXME, so we keep it inside for now).
		content_height = flow_bottom + prev_bottom_margin - content_y
	} else {
		text := element.as_node().text_content() or { '' }
		content_height = inline_content_height(element, text, width, author_rules)
	}

	// An explicit height sets the content height (content-box) or the border-box height (border-box,
	// so subtract the vertical border+padding); `auto` uses the flowed content height.
	border_padding_tb := border.top + border.bottom + padding.top + padding.bottom
	height_id := css.property_id_from_string('height') or { return BlockBox{} }
	tentative_height := if px := css.computed_length_px(element, height_id, author_rules) {
		if border_box { non_negative(px - border_padding_tb) } else { px }
	} else {
		content_height
	}
	// Clamp the height by min-height/max-height. Percentages need a definite containing height we
	// don't track, so only length constraints apply here (basis none).
	min_height := resolve_size_constraint(element, 'min-height', none, border_padding_tb, border_box,
		author_rules) or { 0.0 }
	max_height := resolve_size_constraint(element, 'max-height', none, border_padding_tb, border_box,
		author_rules)
	height := clamp_size(tentative_height, min_height, max_height)

	return BlockBox{
		tag_name: element.local_name()
		x:        content_x
		y:        content_y
		width:    width
		height:   height
		margin:   margin
		border:   border
		padding:  padding
		children: children
	}
}
