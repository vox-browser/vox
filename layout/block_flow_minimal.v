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
// Adjoining vertical margins collapse (CSS 2.1 §8.3.1): between in-flow siblings, and between a box
// and its first/last child when no border/padding separates them (parent/child collapsing, via each
// box's propagated outer margins) — unless the box establishes a block formatting context
// (`overflow` != visible / `display: flow-root`), which contains its children's margins. A box with
// no block-level children but with text content gets a
// height from a coarse inline pass (line count × line-height). `box-sizing: border-box` makes a
// specified width/height include padding+border. Used width and height are clamped by min/max-width
// and min/max-height; `width` also accepts min-content/max-content/fit-content and abspos boxes
// shrink-to-fit. Horizontal `auto` margins absorb leftover space (both auto centers the box; a
// single one right/left-aligns). `position: relative` offsets a box (and its subtree) by its insets
// without disturbing the flow. Text-bearing blocks produce inline line boxes (word-wrapped, `<br>`-
// and `white-space`-aware) positioned per `text-align`. Floated children are placed at the content
// edges (out of flow); `clear` moves a block below them, a BFC grows to contain them, and inline
// content wraps around them. `BlockBox.paint_order()` flattens the tree into z-index paint order, and
// `paint_commands()` builds a display list (background fills + text draws) from it.
// FIXME: floats are placed at the container top, not their flow position.
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

// A laid-out inline fragment: one word positioned within a line, with its own box, text, and color
// (for selection, hit-testing, inline backgrounds, and painting).
pub struct TextFragment {
pub mut:
	x      f64
	y      f64
	width  f64
	height f64
pub:
	text  string
	color css.Color
}

// A laid-out line box within a block's inline formatting context: `x`/`y` is the top-left of the
// line's content in CSS px, `width` the used width of the content on the line (after wrapping), and
// `height` the line-height. `x` reflects `text-align` within the content box. `fragments` are the
// individual words placed left-to-right within the line.
pub struct TextLine {
pub mut:
	x         f64
	y         f64
	width     f64
	height    f64
	fragments []TextFragment
}

// Return a copy of `line` (and its fragments) shifted by (`dx`, `dy`).
fn translate_line(line TextLine, dx f64, dy f64) TextLine {
	return TextLine{
		x:      line.x + dx
		y:      line.y + dy
		width:  line.width
		height: line.height
		fragments: line.fragments.map(TextFragment{
			x:      it.x + dx
			y:      it.y + dy
			width:  it.width
			height: it.height
			text:   it.text
			color:  it.color
		})
	}
}

// A laid-out block box: `x`/`y`/`width`/`height` are the *content box* geometry in CSS px, relative
// to the top-left of the initial containing block; `margin`/`border`/`padding` surround it.
//
// `outer_top_margin`/`outer_bottom_margin` are the *collapsed* margins at the box's top/bottom edges:
// they equal `margin.top`/`margin.bottom` unless a first/last child's adjoining margin collapsed
// through the box (parent/child collapsing), in which case they may be larger. The parent uses them
// to collapse this box's margins against its siblings.
//
// `lines` are the inline line boxes of a text-bearing block (empty for a block with block children).
pub struct BlockBox {
pub:
	tag_name string
pub mut:
	x                   f64
	y                   f64
	width               f64
	height              f64
	margin              BoxEdges
	border              BoxEdges
	padding             BoxEdges
	outer_top_margin    f64
	outer_bottom_margin f64
	// The z-index used for paint ordering among siblings: the integer `z-index` of a positioned box,
	// else 0 (`auto` and non-positioned boxes don't reorder).
	z_index int
	// The computed background-color, text color, and border color, used to build the display list.
	background_color css.Color
	text_color       css.Color
	border_color     css.Color
	children         []BlockBox
	lines            []TextLine
}

// Flatten this box's subtree into paint order (CSS 2.1 Appendix E, simplified): a box paints before
// its children, and its children paint ordered by z-index — negative first, then z-index `auto`/0 in
// tree order, then positive. Each returned entry is a shallow box (no nested children) carrying the
// box's own geometry and line boxes.
//
// FIXME: z-index is compared only among siblings here, not hoisted to the stacking context a
// positioned ancestor establishes; opacity/transform/etc. stacking contexts aren't modeled.
pub fn (b &BlockBox) paint_order() []BlockBox {
	mut order := []BlockBox{}
	b.collect_paint_order(mut order)
	return order
}

fn (b &BlockBox) collect_paint_order(mut order []BlockBox) {
	mut entry := *b
	entry.children = []
	order << entry
	for child in stable_sort_by_z(b.children) {
		child.collect_paint_order(mut order)
	}
}

// A single entry in the display list produced from a laid-out box tree: either a filled rectangle
// (`fill_rect`, e.g. a background) or drawn text (`draw_text`). `color` is the serialized paint color.
pub struct PaintCommand {
pub:
	kind   string // 'fill_rect' | 'draw_text'
	x      f64
	y      f64
	width  f64
	height f64
	color  string
	text   string // for 'draw_text'
}

// Build the display list for this box tree: for each box in paint order — a background fill (when the
// background-color isn't transparent) over its border box, then one fill per non-zero border edge,
// then a draw-text command per inline fragment in that fragment's color. This is the layout →
// rendering bridge.
//
// FIXME: border edges overlap at the corners (no mitered corners) and share one color per box;
// outlines/images/gradients aren't emitted.
pub fn (b &BlockBox) paint_commands() []PaintCommand {
	mut commands := []PaintCommand{}
	for box in b.paint_order() {
		border_left := box.x - box.padding.left - box.border.left
		border_top := box.y - box.padding.top - box.border.top
		border_width := box.width + box.padding.left + box.padding.right + box.border.left +
			box.border.right
		border_height := box.height + box.padding.top + box.padding.bottom + box.border.top +
			box.border.bottom

		if box.background_color.a > 0 {
			commands << PaintCommand{
				kind:   'fill_rect'
				x:      border_left
				y:      border_top
				width:  border_width
				height: border_height
				color:  box.background_color.serialize()
			}
		}
		// Border edges (each along the border box; corners overlap).
		border := box.border_color.serialize()
		if box.border.top > 0 {
			commands << PaintCommand{
				kind: 'fill_rect'
				x: border_left
				y: border_top
				width: border_width
				height: box.border.top
				color: border
			}
		}
		if box.border.bottom > 0 {
			commands << PaintCommand{
				kind: 'fill_rect'
				x: border_left
				y: border_top + border_height - box.border.bottom
				width: border_width
				height: box.border.bottom
				color: border
			}
		}
		if box.border.left > 0 {
			commands << PaintCommand{
				kind: 'fill_rect'
				x: border_left
				y: border_top
				width: box.border.left
				height: border_height
				color: border
			}
		}
		if box.border.right > 0 {
			commands << PaintCommand{
				kind: 'fill_rect'
				x: border_left + border_width - box.border.right
				y: border_top
				width: box.border.right
				height: border_height
				color: border
			}
		}
		for line in box.lines {
			for fragment in line.fragments {
				commands << PaintCommand{
					kind:   'draw_text'
					x:      fragment.x
					y:      fragment.y
					width:  fragment.width
					height: fragment.height
					color:  fragment.color.serialize()
					text:   fragment.text
				}
			}
		}
	}
	return commands
}

// Stable insertion sort of `items` by z-index (preserving tree order among equal z-indexes).
fn stable_sort_by_z(items []BlockBox) []BlockBox {
	mut result := items.clone()
	for i := 1; i < result.len; i++ {
		mut j := i
		for j > 0 && result[j - 1].z_index > result[j].z_index {
			result[j - 1], result[j] = result[j], result[j - 1]
			j--
		}
	}
	return result
}

// Return a copy of `box` with its own geometry, every descendant's, and its line boxes shifted by
// (`dx`, `dy`). Used to reposition a subtree after margin collapsing / positioning decides where its
// border box actually lands.
fn translate_block(box BlockBox, dx f64, dy f64) BlockBox {
	mut moved := box
	moved.x += dx
	moved.y += dy
	moved.children = box.children.map(translate_block(it, dx, dy))
	moved.lines = box.lines.map(translate_line(it, dx, dy))
	return moved
}

// A readable indented dump of the box tree — `tag (x,y) WxH` per box, children nested — for
// snapshot tests and debugging. Whole numbers print without a trailing `.0`.
pub fn (b &BlockBox) tree_repr() string {
	mut lines := []string{}
	b.append_repr(0, mut lines)
	return lines.join('\n')
}

fn (b &BlockBox) append_repr(depth int, mut lines []string) {
	indent := '  '.repeat(depth)
	lines << '${indent}${b.tag_name} (${fmt_px(b.x)},${fmt_px(b.y)}) ${fmt_px(b.width)}x${fmt_px(b.height)}'
	for child in b.children {
		child.append_repr(depth + 1, mut lines)
	}
}

// Format a px value: drop the fractional part for whole numbers so snapshots read cleanly.
fn fmt_px(v f64) string {
	if v == f64(int(v)) {
		return int(v).str()
	}
	return v.str()
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

// The in-flow block-level element children of `node`, in document order. Text and other node types
// are skipped (no inline formatting context yet), as are elements whose computed `display` is `none`
// or inline-level, and absolutely positioned elements (out of flow — laid out separately against
// their containing block). So `<head>`/`<script>`/`<style>`, inline, and abspos elements don't flow.
fn block_child_elements(node &dom.Node, author_rules []&css.CSSRule) []&dom.Element {
	display_id := css.property_id_from_string('display') or { return []&dom.Element{} }
	mut elements := []&dom.Element{}
	for child in node.children_as_vector() {
		if element := child.as_element() {
			if is_absolutely_positioned(position_value(element, author_rules)) {
				continue // out of flow
			}
			if is_floating(element, author_rules) {
				continue // out of normal flow (placed separately at the container edge)
			}
			display := css.cascaded_value_with_ua(element, display_id, author_rules)
			if is_block_level_display(display) {
				elements << element
			}
		}
	}
	return elements
}

// The cascaded `float` value (`none` when absent); `is_floating` is float left/right.
fn float_side(element &dom.Element, author_rules []&css.CSSRule) string {
	id := css.property_id_from_string('float') or { return 'none' }
	return css.cascaded_value_with_ua(element, id, author_rules)
}

fn is_floating(element &dom.Element, author_rules []&css.CSSRule) bool {
	side := float_side(element, author_rules)
	return side == 'left' || side == 'right'
}

// The floated element children of `node`, in document order (skipping display:none). Absolutely
// positioned elements are handled elsewhere and take precedence over float.
fn float_children(node &dom.Node, author_rules []&css.CSSRule) []&dom.Element {
	display_id := css.property_id_from_string('display') or { return []&dom.Element{} }
	mut elements := []&dom.Element{}
	for child in node.children_as_vector() {
		if element := child.as_element() {
			if css.cascaded_value_with_ua(element, display_id, author_rules) == 'none' {
				continue
			}
			if is_absolutely_positioned(position_value(element, author_rules)) {
				continue
			}
			if is_floating(element, author_rules) {
				elements << element
			}
		}
	}
	return elements
}

// The y (local frame) an in-flow block must clear down to, given the current left/right float bottoms
// and the element's `clear` value: `left`/`right`/`both` clear the respective floats (0 = no clear).
fn clearance_bottom(element &dom.Element, left_floats_bottom f64, right_floats_bottom f64, author_rules []&css.CSSRule) f64 {
	id := css.property_id_from_string('clear') or { return 0.0 }
	return match css.cascaded_value_with_ua(element, id, author_rules) {
		'left' { left_floats_bottom }
		'right' { right_floats_bottom }
		'both' { if left_floats_bottom > right_floats_bottom { left_floats_bottom } else { right_floats_bottom } }
		else { 0.0 }
	}
}

// Lay out a floated `element` at the local origin, sized shrink-to-fit when its width is auto (else
// per the box model), within a `content_width`-wide containing block. Returned box is placed later.
fn layout_float(element &dom.Element, content_width f64, author_rules []&css.CSSRule) BlockBox {
	available_width := if size_is_auto(element, 'width', author_rules) {
		edges := horizontal_edges(element, content_width, author_rules)
		fit := shrink_to_fit(intrinsic_content_width(element, author_rules, true),
			intrinsic_content_width(element, author_rules, false), non_negative(content_width - edges))
		fit + edges
	} else {
		content_width
	}
	return layout_block(element, 0.0, 0.0, available_width, author_rules)
}

// A float's vertical band and the inner edge past which in-flow inline content sits: for a left
// float `inner_edge` is its right margin edge (content starts to the right); for a right float it is
// its left margin edge (content ends to the left). Coordinates are in the local (content-top = 0)
// frame, matching line boxes.
struct FloatBand {
	is_left    bool
	top        f64
	bottom     f64
	inner_edge f64
}

// Place floated boxes at the container's content-box edges (left floats packed from the left, right
// floats from the right), all at the content top (local y = 0). Returns the placed boxes, the lowest
// bottom reached by left and right floats (for `clear` and BFC height), and the float bands (so that
// inline content wraps around them).
//
// FIXME (v1): floats are placed at the container top, not interleaved at their in-flow position, and
// they don't wrap to a new row when a row is full.
fn place_floats(elements []&dom.Element, content_x f64, content_width f64, author_rules []&css.CSSRule) ([]BlockBox, f64, f64, []FloatBand) {
	mut placed := []BlockBox{}
	mut bands := []FloatBand{}
	mut left_edge := content_x
	mut right_edge := content_x + content_width
	mut left_bottom := 0.0
	mut right_bottom := 0.0
	for element in elements {
		mut box := layout_float(element, content_width, author_rules)
		margin_box_width := box.margin_box_width()
		margin_box_height := box.margin_box_height()
		// The provisional box's margin-box origin (floats establish a BFC, so no collapse-through).
		current_margin_x := box.x - box.padding.left - box.border.left - box.margin.left
		current_margin_y := box.y - box.padding.top - box.border.top - box.margin.top
		is_left := float_side(element, author_rules) == 'left'
		margin_left := if is_left { left_edge } else { right_edge - margin_box_width }
		box = translate_block(box, margin_left - current_margin_x, -current_margin_y)
		if is_left {
			left_edge += margin_box_width
			if margin_box_height > left_bottom {
				left_bottom = margin_box_height
			}
		} else {
			right_edge -= margin_box_width
			if margin_box_height > right_bottom {
				right_bottom = margin_box_height
			}
		}
		bands << FloatBand{
			is_left:    is_left
			top:        0.0
			bottom:     margin_box_height
			inner_edge: if is_left { margin_left + margin_box_width } else { margin_left }
		}
		placed << box
	}
	return placed, left_bottom, right_bottom, bands
}

// The horizontal bounds [left, right] available to a line box spanning [`y`, `y + line_height`],
// after subtracting floats whose bands overlap it.
fn line_bounds(y f64, line_height f64, bands []FloatBand, content_x f64, content_width f64) (f64, f64) {
	mut left := content_x
	mut right := content_x + content_width
	for band in bands {
		if band.top < y + line_height && band.bottom > y { // overlaps the line's band
			if band.is_left {
				if band.inner_edge > left {
					left = band.inner_edge
				}
			} else if band.inner_edge < right {
				right = band.inner_edge
			}
		}
	}
	return left, if right > left { right } else { left }
}

// The nearest float bottom strictly below `y` (so a line that can't fit beside a float can drop to
// clear it). Returns `y` when no float extends below.
fn next_float_bottom(y f64, bands []FloatBand) f64 {
	mut best := y
	for band in bands {
		if band.bottom > y && (best == y || band.bottom < best) {
			best = band.bottom
		}
	}
	return best
}

// Greedily break `words` into lines that fit `content_width`, returning the used content width of
// each line. Each glyph is `glyph_width` wide and inter-word spaces `space_width` (no real font
// metrics). A word that doesn't fit on the current line starts a new one; a word wider than the whole
// line still takes its own line (unbreakable — matching `overflow-wrap: normal`, it overflows rather
// than splitting mid-word). With no room to wrap (`content_width <= 0`) everything is one line.
fn wrap_line_widths(words []string, content_width f64, glyph_width f64, space_width f64) []f64 {
	if words.len == 0 {
		return []f64{}
	}
	mut widths := []f64{}
	mut line_width := 0.0
	mut started := false
	for word in words {
		word_width := f64(word.runes().len) * glyph_width
		if !started {
			line_width = word_width
			started = true
			continue
		}
		if content_width > 0 && line_width + space_width + word_width > content_width {
			widths << line_width
			line_width = word_width // the word starts a fresh line
		} else {
			line_width += space_width + word_width
		}
	}
	widths << line_width
	return widths
}

// The number of lines `words` wrap to (0 when empty).
fn wrapped_line_count(words []string, content_width f64, glyph_width f64, space_width f64) int {
	return wrap_line_widths(words, content_width, glyph_width, space_width).len
}

// Shrink-to-fit width: min(max(min-content, available), max-content) (CSS 2.1 §10.3.7).
fn shrink_to_fit(min_content f64, max_content f64, available f64) f64 {
	preferred := if available < max_content { available } else { max_content }
	return if preferred > min_content { preferred } else { min_content }
}

// Horizontal margins + borders + padding of `element` (auto margins count as 0; percentages resolve
// against `containing_width`).
fn horizontal_edges(element &dom.Element, containing_width f64, author_rules []&css.CSSRule) f64 {
	return used_length_or_zero(element, 'margin-left', containing_width, author_rules) +
		used_length_or_zero(element, 'margin-right', containing_width, author_rules) +
		used_border(element, 'left', author_rules) + used_border(element, 'right', author_rules) +
		used_length_or_zero(element, 'padding-left', containing_width, author_rules) +
		used_length_or_zero(element, 'padding-right', containing_width, author_rules)
}

// The intrinsic width of a block's inline (text) content: the widest single word (min-content) or the
// widest unbroken segment — words + spaces on one line (max-content). Words are measured with their
// own element's font.
fn inline_intrinsic_width(element &dom.Element, author_rules []&css.CSSRule, minimum bool) f64 {
	white_space := css.cascaded_value_with_ua(element, css.property_id_from_string('white-space') or {
		return 0.0
	}, author_rules)
	segments := collect_inline_segments(element, white_space_preserves_newlines(white_space),
		author_rules)
	mut widest := 0.0
	for segment in segments {
		if segment.len == 0 {
			continue
		}
		if minimum {
			for word in segment {
				if word.width > widest {
					widest = word.width
				}
			}
		} else {
			// max-content: the whole segment on one line (words + the spaces between them).
			mut total := segment[0].width
			for k := 1; k < segment.len; k++ {
				total += segment[k - 1].space_after + segment[k].width
			}
			if total > widest {
				widest = total
			}
		}
	}
	return widest
}

// The intrinsic *content* width of `element`: max-content (preferred, no wrapping) when `minimum` is
// false, min-content (narrowest without overflow) when true. A block with text measures its inline
// content; a block with block children takes the widest child's outer intrinsic width. A child with
// a definite length width contributes that (box-sizing aware); otherwise it recurses.
fn intrinsic_content_width(element &dom.Element, author_rules []&css.CSSRule, minimum bool) f64 {
	block_children := block_child_elements(element.as_node(), author_rules)
	if block_children.len == 0 {
		return inline_intrinsic_width(element, author_rules, minimum)
	}
	mut widest := 0.0
	for child in block_children {
		outer := horizontal_edges(child, 0.0, author_rules) +
			child_intrinsic_content_width(child, author_rules, minimum)
		if outer > widest {
			widest = outer
		}
	}
	return widest
}

// A child's contribution to its parent's intrinsic width: its definite length width if it has one
// (box-sizing aware), else its recursively computed intrinsic content width.
fn child_intrinsic_content_width(element &dom.Element, author_rules []&css.CSSRule, minimum bool) f64 {
	width_id := css.property_id_from_string('width') or {
		return intrinsic_content_width(element, author_rules, minimum)
	}
	if px := css.computed_length_px(element, width_id, author_rules) {
		if box_sizing_is_border_box(element, author_rules) {
			border_padding := used_border(element, 'left', author_rules) +
				used_border(element, 'right', author_rules) +
				used_length_or_zero(element, 'padding-left', 0.0, author_rules) +
				used_length_or_zero(element, 'padding-right', 0.0, author_rules)
			return non_negative(px - border_padding)
		}
		return px
	}
	return intrinsic_content_width(element, author_rules, minimum)
}

// Whether a `white-space` value wraps at soft line-break opportunities. `nowrap` and `pre` never
// wrap; `normal`, `pre-wrap`, `pre-line` do.
fn white_space_wraps(white_space string) bool {
	return white_space != 'nowrap' && white_space != 'pre'
}

// Whether a `white-space` value keeps newlines in text as forced line breaks (the `pre*` family).
fn white_space_preserves_newlines(white_space string) bool {
	return white_space == 'pre' || white_space == 'pre-wrap' || white_space == 'pre-line'
}

// A word of inline content with its own measured metrics, taken from the element it comes from — so
// a nested inline element with its own font-size measures its text at that size.
struct InlineWord {
	text        string
	width       f64 // rune count × 0.5em of the word's font
	space_after f64 // the space following this word (~0.5em of its font)
	height      f64 // this word's line-height contribution
	color       css.Color // this word's computed text color
}

// Gather a block's inline content as segments of styled words, split at `<br>` and (when
// `preserve_newlines`) at newlines. Each word is measured with the font/line-height of the element it
// comes from. `display: none` and out-of-flow descendants contribute nothing. The result always has
// at least one (possibly empty) segment.
fn collect_inline_segments(element &dom.Element, preserve_newlines bool, author_rules []&css.CSSRule) [][]InlineWord {
	mut segments := [[]InlineWord{}]
	append_inline_words(element, preserve_newlines, author_rules, mut segments)
	return segments
}

fn append_inline_words(element &dom.Element, preserve_newlines bool, author_rules []&css.CSSRule, mut segments [][]InlineWord) {
	display_id := css.property_id_from_string('display') or { return }
	glyph_width := 0.5 * css.computed_font_size_px(element, author_rules)
	line_height := css.computed_line_height_px(element, author_rules)
	color := css.computed_color(element, css.property_id_from_string('color') or { return },
		author_rules) or { css.Color{0, 0, 0, 255} }
	for child in element.as_node().children_as_vector() {
		if child.is_text() {
			data := unsafe { &dom.Text(child) }.data()
			parts := if preserve_newlines { data.split('\n') } else { [data] }
			for i, part in parts {
				if i > 0 {
					segments << []InlineWord{} // a preserved newline starts a new segment
				}
				for word in part.fields() {
					segments[segments.len - 1] << InlineWord{
						text:        word
						width:       f64(word.runes().len) * glyph_width
						space_after: glyph_width
						height:      line_height
						color:       color
					}
				}
			}
		} else if el := child.as_element() {
			if css.cascaded_value_with_ua(el, display_id, author_rules) == 'none' {
				continue
			}
			if is_absolutely_positioned(position_value(el, author_rules)) || is_floating(el, author_rules) {
				continue // out of flow — its text is its own content, not the container's
			}
			if el.local_name() == 'br' {
				segments << []InlineWord{} // forced line break starts a new segment
			} else {
				append_inline_words(el, preserve_newlines, author_rules, mut segments)
			}
		}
	}
}

// The `text-align`-adjusted left edge of a line whose content is `line_width` wide, within a content
// box that starts at `content_x` and is `content_width` wide. `center` centers it, `right`/`end` push
// it to the right edge; everything else (left/start/justify — no per-word justification yet) is left.
fn aligned_line_x(content_x f64, content_width f64, line_width f64, align string) f64 {
	return match align {
		'center' { content_x + (content_width - line_width) / 2.0 }
		'right', 'end' { content_x + content_width - line_width }
		else { content_x }
	}
}

// Lay out a block's inline (text) content as line boxes in a LOCAL frame (the first line's top at
// y = 0), to be translated to the content-box top by the caller. Content is split into segments at
// `<br>` (and, under `white-space: pre*`, at newlines); each segment wraps at word boundaries against
// `content_width` unless `white-space` forbids wrapping (`nowrap`/`pre`, in which case a segment is a
// single line). Every line is placed at `content_x` adjusted for `text-align`. An empty segment
// between breaks is still an (empty) line; truly empty content yields no lines.
//
// Line boxes flow around `float_bands`: each line uses the horizontal room left at its vertical
// position (offset past left floats, shortened by right floats), and a line whose first word can't
// fit beside a float drops below it.
//
// Each line carries its words as positioned fragments, each measured with its own element's font; a
// line's height is the tallest word on it; `text-align: justify` spreads slack across word gaps.
// FIXME: still stands in for a real inline formatting context — glyph advances are estimated, `pre*`
// whitespace runs are collapsed (widths approximate), and there is no bidi.
fn layout_inline_lines(element &dom.Element, content_x f64, content_width f64, float_bands []FloatBand, author_rules []&css.CSSRule) []TextLine {
	white_space := css.cascaded_value_with_ua(element, css.property_id_from_string('white-space') or {
		return []TextLine{}
	}, author_rules)

	segments := collect_inline_segments(element, white_space_preserves_newlines(white_space),
		author_rules)
	if segments.len == 1 && segments[0].len == 0 {
		return []TextLine{} // no inline content at all
	}

	block_line_height := css.computed_line_height_px(element, author_rules)
	align := css.cascaded_value_with_ua(element, css.property_id_from_string('text-align') or {
		return []TextLine{}
	}, author_rules)
	wraps := white_space_wraps(white_space)

	mut lines := []TextLine{}
	mut y := 0.0
	for segment in segments {
		if segment.len == 0 {
			left, right := line_bounds(y, block_line_height, float_bands, content_x, content_width)
			lines << TextLine{
				x:      aligned_line_x(left, right - left, 0.0, align)
				y:      y
				width:  0.0
				height: block_line_height
			}
			y += block_line_height
			continue
		}
		mut i := 0
		for i < segment.len {
			mut left, mut right := line_bounds(y, segment[i].height, float_bands, content_x,
				content_width)
			// If the first word can't fit beside a float, drop the line below the nearest float.
			if wraps && segment[i].width > right - left {
				dropped := next_float_bottom(y, float_bands)
				if dropped > y {
					y = dropped
					continue
				}
			}
			available := right - left
			mut line_width := segment[i].width
			mut line_height := segment[i].height
			mut j := i + 1
			for j < segment.len {
				needed := segment[j - 1].space_after + segment[j].width
				if wraps && line_width + needed > available {
					break
				}
				line_width += needed
				if segment[j].height > line_height {
					line_height = segment[j].height
				}
				j++
			}
			// `text-align: justify` spreads the slack across the word gaps of every line except the
			// last of a segment (and lines with a single word).
			is_last_line := j == segment.len
			mut extra_per_gap := 0.0
			if align == 'justify' && !is_last_line && j - i > 1 {
				extra_per_gap = (available - line_width) / f64(j - i - 1)
				if extra_per_gap < 0.0 {
					extra_per_gap = 0.0
				}
			}
			justified := extra_per_gap > 0.0
			line_x := aligned_line_x(left, right - left, line_width, align) // justify -> left edge
			// Place each word left-to-right within the line, advancing by the word, its space, and
			// (when justified) the distributed slack between words.
			mut fragments := []TextFragment{}
			mut fragment_x := line_x
			for k := i; k < j; k++ {
				fragments << TextFragment{
					x:      fragment_x
					y:      y
					width:  segment[k].width
					height: segment[k].height
					text:   segment[k].text
					color:  segment[k].color
				}
				fragment_x += segment[k].width + segment[k].space_after
				if k < j - 1 {
					fragment_x += extra_per_gap
				}
			}
			lines << TextLine{
				x:         line_x
				y:         y
				width:     if justified { available } else { line_width }
				height:    line_height
				fragments: fragments
			}
			i = j
			y += line_height
		}
	}
	return lines
}

// Whether `element` uses the border-box box model (specified width/height include padding+border)
// rather than the default content-box.
fn box_sizing_is_border_box(element &dom.Element, author_rules []&css.CSSRule) bool {
	id := css.property_id_from_string('box-sizing') or { return false }
	return css.cascaded_value_with_ua(element, id, author_rules) == 'border-box'
}

// The used *content* width for `element` in a containing block `containing_width` px wide. A length
// or percentage sets the width per the box model: content-box uses it directly; border-box subtracts
// the horizontal border+padding (`border_padding_lr`). The intrinsic keywords resolve to the element's
// min/max-content (fit-content shrinks to fit the available space). `auto` fills the space left after
// the horizontal margins, border, and padding. All results are clamped at 0.
fn used_content_width(element &dom.Element, containing_width f64, margins_lr f64, border_padding_lr f64, border_box bool, author_rules []&css.CSSRule) f64 {
	width_id := css.property_id_from_string('width') or {
		return non_negative(containing_width - margins_lr - border_padding_lr)
	}
	match css.cascaded_value_with_ua(element, width_id, author_rules) {
		'max-content' {
			return intrinsic_content_width(element, author_rules, false)
		}
		'min-content' {
			return intrinsic_content_width(element, author_rules, true)
		}
		'fit-content' {
			available := non_negative(containing_width - margins_lr - border_padding_lr)
			return shrink_to_fit(intrinsic_content_width(element, author_rules, true),
				intrinsic_content_width(element, author_rules, false), available)
		}
		else {}
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

// Whether `element` establishes a new block formatting context, in which case its margins do not
// collapse with its in-flow children. Detects `display: flow-root`, absolute/fixed positioning,
// floats, and a non-visible `overflow` on either axis (`hidden`/`scroll`/`auto`/`clip`). FIXME:
// inline-block, table cells, and the document root also establish BFCs.
fn establishes_block_formatting_context(element &dom.Element, author_rules []&css.CSSRule) bool {
	if is_absolutely_positioned(position_value(element, author_rules)) {
		return true
	}
	if is_floating(element, author_rules) {
		return true
	}
	display_id := css.property_id_from_string('display') or { return false }
	if css.cascaded_value_with_ua(element, display_id, author_rules) == 'flow-root' {
		return true
	}
	for axis in ['overflow-x', 'overflow-y'] {
		id := css.property_id_from_string(axis) or { continue }
		value := css.cascaded_value_with_ua(element, id, author_rules)
		if value != 'visible' && value != '' {
			return true
		}
	}
	return false
}

// The rectangle (in absolute px) that an absolutely positioned element resolves its insets, size, and
// position against — the padding box of its nearest positioned ancestor, or the initial containing
// block (viewport) if none.
struct PositionedContainingBlock {
	x      f64
	y      f64
	width  f64
	height f64
}

// The cascaded `position` value (`static` when absent).
fn position_value(element &dom.Element, author_rules []&css.CSSRule) string {
	id := css.property_id_from_string('position') or { return 'static' }
	return css.cascaded_value_with_ua(element, id, author_rules)
}

// Absolutely positioned = out of flow, laid out against a containing block. `fixed` is treated like
// `absolute` here (its containing block is the viewport rather than a positioned ancestor — FIXME).
fn is_absolutely_positioned(position string) bool {
	return position == 'absolute' || position == 'fixed'
}

// Positioned = anything but `static`; a positioned box is a containing block for abspos descendants.
fn is_positioned(position string) bool {
	return position != 'static' && position != ''
}

// Whether a size property (width/height) has no definite value (`auto`/absent/unresolvable).
fn size_is_auto(element &dom.Element, property_name string, author_rules []&css.CSSRule) bool {
	id := css.property_id_from_string(property_name) or { return true }
	if _ := css.computed_length_px(element, id, author_rules) {
		return false
	}
	if _ := css.computed_percentage(element, id, author_rules) {
		return false
	}
	return true
}

// Collect the absolutely positioned elements whose nearest positioned ancestor is `node` — i.e. walk
// `node`'s descendants but do not descend past any positioned box (which is itself a containing block
// and lays out its own abspos descendants). Skips `display: none` subtrees.
fn collect_abspos_in_scope(node &dom.Node, author_rules []&css.CSSRule) []&dom.Element {
	display_id := css.property_id_from_string('display') or { return []&dom.Element{} }
	mut result := []&dom.Element{}
	for child_node in node.children_as_vector() {
		child := child_node.as_element() or { continue }
		if css.cascaded_value_with_ua(child, display_id, author_rules) == 'none' {
			continue
		}
		position := position_value(child, author_rules)
		if is_absolutely_positioned(position) {
			result << child // belongs to this scope; its own abspos descendants are handled when it lays out
		} else if is_positioned(position) {
			continue // a positioned (e.g. relative) box establishes its own scope — skip its subtree
		} else {
			result << collect_abspos_in_scope(child.as_node(), author_rules)
		}
	}
	return result
}

// Lay out an absolutely positioned `element` against its containing block `cb` (CSS 2.1 §9.6/§10.3.7/
// §10.6.4). The element's own content (and nested abspos) is laid out via layout_block with a
// containing width chosen so the normal width algorithm yields the abspos width; the result is then
// translated to the position implied by the insets.
//
// FIXME: auto-margin centering between insets isn't done; the static position (when top/left are
// auto) is approximated by the containing block's origin.
fn layout_absolute(element &dom.Element, cb PositionedContainingBlock, author_rules []&css.CSSRule) BlockBox {
	left := offset_length(element, 'left', cb.width, author_rules)
	right := offset_length(element, 'right', cb.width, author_rules)
	top := offset_length(element, 'top', cb.height, author_rules)
	bottom := offset_length(element, 'bottom', cb.height, author_rules)
	width_auto := size_is_auto(element, 'width', author_rules)
	height_auto := size_is_auto(element, 'height', author_rules)

	// Choose the containing width fed to layout_block so its width algorithm produces the abspos width.
	// width:auto between both left and right fills the gap; width:auto otherwise is shrink-to-fit (the
	// content's min/max-content clamped to the space left after insets and edges); a definite width
	// resolves against the containing block.
	available_width := if !width_auto {
		cb.width
	} else if left != none && right != none {
		non_negative(cb.width - left - right)
	} else {
		edges := horizontal_edges(element, cb.width, author_rules)
		available_content := non_negative(cb.width - (left or { 0.0 }) - (right or { 0.0 }) - edges)
		fit := shrink_to_fit(intrinsic_content_width(element, author_rules, true),
			intrinsic_content_width(element, author_rules, false), available_content)
		fit + edges
	}
	mut box := layout_block(element, 0.0, 0.0, available_width, author_rules)

	// height:auto with both top and bottom set fills the gap between them.
	if height_auto {
		if t := top {
			if b := bottom {
				border_padding_tb := box.border.top + box.border.bottom + box.padding.top +
					box.padding.bottom
				box.height = non_negative(cb.height - t - b - box.margin.top - box.margin.bottom -
					border_padding_tb)
			}
		}
	}

	margin_box_width := box.margin_box_width()
	margin_box_height := box.margin_box_height()
	margin_x := if l := left {
		cb.x + l
	} else if r := right {
		cb.x + cb.width - r - margin_box_width
	} else {
		cb.x // static-position approximation
	}
	margin_y := if t := top {
		cb.y + t
	} else if b := bottom {
		cb.y + cb.height - b - margin_box_height
	} else {
		cb.y // static-position approximation
	}
	// The provisional box's margin-box origin (it was laid out at (0,0), and abspos establishes a BFC
	// so no margin collapsed through — its margin-box origin is exactly (0,0)).
	current_margin_x := box.x - box.padding.left - box.border.left - box.margin.left
	current_margin_y := box.y - box.padding.top - box.border.top - box.margin.top
	return translate_block(box, margin_x - current_margin_x, margin_y - current_margin_y)
}

// An inset property (top/right/bottom/left) resolved to px, or none when `auto`/absent. Percentages
// resolve against `basis` (none to skip them). Unlike sizes, insets may be negative — no clamping.
fn offset_length(element &dom.Element, property_name string, basis ?f64, author_rules []&css.CSSRule) ?f64 {
	id := css.property_id_from_string(property_name) or { return none }
	if px := css.computed_length_px(element, id, author_rules) {
		return px
	}
	if b := basis {
		if pct := css.computed_percentage(element, id, author_rules) {
			return b * pct / 100.0
		}
	}
	return none
}

// The relative-positioning offset (dx, dy) for `element`: 0 unless `position: relative`. Then `left`
// (else `-right`) offsets horizontally and `top` (else `-bottom`) vertically, relative to the box's
// normal-flow position — without affecting siblings (CSS 2.1 §9.4.3). Percentage insets resolve
// against the containing block's width for left/right; top/bottom percentages need its height, which
// isn't tracked, so they're treated as auto.
fn relative_offset(element &dom.Element, containing_width f64, author_rules []&css.CSSRule) (f64, f64) {
	position_id := css.property_id_from_string('position') or { return 0.0, 0.0 }
	if css.cascaded_value_with_ua(element, position_id, author_rules) != 'relative' {
		return 0.0, 0.0
	}
	dx := if left := offset_length(element, 'left', containing_width, author_rules) {
		left
	} else if right := offset_length(element, 'right', containing_width, author_rules) {
		-right
	} else {
		0.0
	}
	dy := if top := offset_length(element, 'top', none, author_rules) {
		top
	} else if bottom := offset_length(element, 'bottom', none, author_rules) {
		-bottom
	} else {
		0.0
	}
	return dx, dy
}

// Whether a margin property's cascaded value is the keyword `auto`.
fn margin_is_auto(element &dom.Element, property_name string, author_rules []&css.CSSRule) bool {
	id := css.property_id_from_string(property_name) or { return false }
	return css.cascaded_value_with_ua(element, id, author_rules) == 'auto'
}

// Resolve the used left/right margins, distributing the horizontal space left over after the border
// box and the fixed (non-auto) margins to any `auto` margins (CSS 2.1 §10.3.3): both `auto` centers
// the box; a single `auto` margin absorbs the whole remainder (so margin-left:auto right-aligns);
// none `auto` leaves the fixed values (any over-constraint notionally lands on margin-right, which
// isn't rendered here). Overflow (negative space) spills onto the right margin in LTR.
fn resolve_horizontal_auto_margins(containing_width f64, border_box_width f64, left_fixed f64, right_fixed f64, left_auto bool, right_auto bool) (f64, f64) {
	space := containing_width - border_box_width - left_fixed - right_fixed
	if left_auto && right_auto {
		if space > 0 {
			return space / 2, space / 2
		}
		return 0.0, space
	}
	if left_auto {
		return space, right_fixed
	}
	if right_auto {
		return left_fixed, space
	}
	return left_fixed, right_fixed
}

// Lay out `element` and its block descendants. `x`/`y` is the top-left of this box's *margin box*;
// the returned box's content origin is inset by its margin, border, and padding. Children stack
// vertically within the content box, each advancing the cursor by its own margin-box height; the
// parent's content height is that stacked total unless it declares an explicit height.
pub fn layout_block(element &dom.Element, x f64, y f64, containing_width f64, author_rules []&css.CSSRule) BlockBox {
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
	border_padding_lr := border.left + border.right + padding.left + padding.right

	// Vertical margins resolve directly (auto -> 0). Horizontal margins may be `auto`, which absorbs
	// leftover space once the width is known (below).
	margin_top := used_length_or_zero(element, 'margin-top', containing_width, author_rules)
	margin_bottom := used_length_or_zero(element, 'margin-bottom', containing_width, author_rules)
	margin_left_auto := margin_is_auto(element, 'margin-left', author_rules)
	margin_right_auto := margin_is_auto(element, 'margin-right', author_rules)
	margin_left_fixed := used_length_or_zero(element, 'margin-left', containing_width, author_rules)
	margin_right_fixed := used_length_or_zero(element, 'margin-right', containing_width, author_rules)

	// Used content width: `auto` margins count as 0 while the width fills; then clamp by min/max.
	tentative_width := used_content_width(element, containing_width, margin_left_fixed +
		margin_right_fixed, border_padding_lr, border_box, author_rules)
	min_width := resolve_size_constraint(element, 'min-width', containing_width, border_padding_lr,
		border_box, author_rules) or { 0.0 }
	max_width := resolve_size_constraint(element, 'max-width', containing_width, border_padding_lr,
		border_box, author_rules)
	width := clamp_size(tentative_width, min_width, max_width)

	// Distribute leftover horizontal space to `auto` margins (centering / one-sided absorb).
	margin_left, margin_right := resolve_horizontal_auto_margins(containing_width, width +
		border_padding_lr, margin_left_fixed, margin_right_fixed, margin_left_auto, margin_right_auto)
	margin := BoxEdges{
		top:    margin_top
		right:  margin_right
		bottom: margin_bottom
		left:   margin_left
	}

	// Relative positioning offsets this box (and its subtree) from the normal-flow position without
	// affecting siblings: the flow uses the un-offset metrics; the offset rides along here and through
	// the child translate below.
	rel_x, rel_y := relative_offset(element, containing_width, author_rules)
	content_x := x + margin.left + border.left + padding.left + rel_x

	// Whether this box's top/bottom margins can collapse with a first/last child's. They can't when a
	// border or padding separates them, nor when the box establishes a block formatting context (its
	// children's margins are contained rather than collapsing through). FIXME: the document root also
	// establishes a BFC (not detected here — it would need document-identity, and would wrongly fire
	// on detached elements); floats/abspos likewise establish BFCs but aren't modelled.
	establishes_bfc := establishes_block_formatting_context(element, author_rules)
	top_adjoins := !establishes_bfc && border.top == 0.0 && padding.top == 0.0
	// Whether the last child's bottom margin stays inside this box's content (rather than collapsing
	// out): true when bottom border/padding separates them, or when the box establishes a BFC.
	bottom_margin_contained := establishes_bfc || border.bottom != 0.0 || padding.bottom != 0.0

	// Floated children are taken out of normal flow and placed at the content-box edges; the lowest
	// bottom reached by left/right floats drives `clear` and (in a BFC) the container's height.
	float_elements := float_children(element.as_node(), author_rules)
	placed_floats, left_floats_bottom, right_floats_bottom, float_bands := place_floats(float_elements,
		content_x, width, author_rules)

	block_children := block_child_elements(element.as_node(), author_rules)

	// Lay children out in a LOCAL frame whose origin is this box's content-box top-left. Vertical
	// margins collapse (CSS 2.1 §8.3.1) using each child's OUTER (collapsed) margins: between siblings
	// the gap is collapse(prev outer bottom, this outer top); a first child whose top edge adjoins the
	// parent contributes its outer top margin to the parent instead of pushing itself down. Children
	// are laid out provisionally (border-box top at their own outer top margin) and translated into
	// place; the whole set is shifted to the real content-box top once the parent's outer top margin
	// is known.
	mut local_children := []BlockBox{}
	mut flow_bottom := 0.0 // border-box bottom of the last placed child, in the local frame
	mut prev_outer_bottom := 0.0
	mut first_child_outer_top := 0.0
	mut last_child_outer_bottom := 0.0
	mut has_children := false
	for child in block_children {
		mut cb := layout_block(child, content_x, 0.0, width, author_rules)
		mut desired_border_top := if has_children {
			flow_bottom + collapse_margins([prev_outer_bottom, cb.outer_top_margin])
		} else if top_adjoins {
			0.0 // first child's top margin collapses through into this box's outer top margin
		} else {
			cb.outer_top_margin // separated by border/padding: the margin sits inside the content
		}
		// `clear` moves the child below the relevant floats.
		clear_bottom := clearance_bottom(child, left_floats_bottom, right_floats_bottom, author_rules)
		if clear_bottom > desired_border_top {
			desired_border_top = clear_bottom
		}
		cb = translate_block(cb, 0.0, desired_border_top - cb.outer_top_margin)
		child_border_bottom := desired_border_top + cb.border.top + cb.padding.top + cb.height +
			cb.padding.bottom + cb.border.bottom
		if !has_children {
			first_child_outer_top = cb.outer_top_margin
		}
		last_child_outer_bottom = cb.outer_bottom_margin
		flow_bottom = child_border_bottom
		prev_outer_bottom = cb.outer_bottom_margin
		has_children = true
		local_children << cb
	}

	// Auto content height: from the content-box top (local 0) to the last child's border-box bottom,
	// plus that child's outer bottom margin only when it stays inside the box (otherwise it collapses
	// out). A box with no block children lays out inline line boxes (also in the local frame) and its
	// height is the stack of those lines.
	mut content_height := 0.0
	mut local_lines := []TextLine{}
	if has_children {
		content_height = if bottom_margin_contained {
			flow_bottom + last_child_outer_bottom
		} else {
			flow_bottom
		}
	} else {
		local_lines = layout_inline_lines(element, content_x, width, float_bands, author_rules)
		for line in local_lines {
			if line.y + line.height > content_height {
				content_height = line.y + line.height
			}
		}
	}
	// A box that establishes a BFC grows to contain its floats (the `overflow:hidden`/`flow-root`
	// clearfix). Otherwise floats can overflow the box's bottom.
	if establishes_bfc {
		if left_floats_bottom > content_height {
			content_height = left_floats_bottom
		}
		if right_floats_bottom > content_height {
			content_height = right_floats_bottom
		}
	}

	// An explicit height sets the content height (content-box) or the border-box height (border-box,
	// so subtract the vertical border+padding); `auto` uses the flowed content height.
	border_padding_tb := border.top + border.bottom + padding.top + padding.bottom
	height_id := css.property_id_from_string('height') or { return BlockBox{} }
	mut height_is_auto := true
	tentative_height := if px := css.computed_length_px(element, height_id, author_rules) {
		height_is_auto = false
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

	// This box's collapsed outer margins (propagated to the parent). The top collapses with the first
	// child's outer top margin when the top edges adjoin; the bottom collapses with the last child's
	// outer bottom margin when the bottom edges adjoin (no bottom border/padding AND auto height).
	// FIXME: empty-block self-collapse (a box's own top and bottom margins collapsing) isn't handled.
	bottom_adjoins := !bottom_margin_contained && height_is_auto && has_children
	outer_top_margin := if top_adjoins && has_children {
		collapse_margins([margin.top, first_child_outer_top])
	} else {
		margin.top
	}
	outer_bottom_margin := if bottom_adjoins {
		collapse_margins([margin.bottom, last_child_outer_bottom])
	} else {
		margin.bottom
	}

	// Place this box: its border-box top is `y` plus its collapsed outer top margin (plus any relative
	// offset, which does not participate in the flow computed above). Shift the children from the local
	// frame (content-box top = 0) to the real content-box top.
	content_top := y + outer_top_margin + border.top + padding.top + rel_y
	mut children := local_children.map(translate_block(it, 0.0, content_top))
	// Floats (also laid out in the local frame) join the children, shifted to the content-box top.
	for placed_float in placed_floats {
		children << translate_block(placed_float, 0.0, content_top)
	}
	lines := local_lines.map(translate_line(it, 0.0, content_top))

	// If this box is positioned, it is the containing block for its abspos descendants: lay them out
	// against its padding box (using its final, offset content origin). Their flow siblings above are
	// unaffected because abspos elements were excluded from the flow.
	if is_positioned(position_value(element, author_rules)) {
		this_cb := PositionedContainingBlock{
			x:      content_x - padding.left
			y:      content_top - padding.top
			width:  width + padding.left + padding.right
			height: height + padding.top + padding.bottom
		}
		for abspos in collect_abspos_in_scope(element.as_node(), author_rules) {
			children << layout_absolute(abspos, this_cb, author_rules)
		}
	}

	// z-index applies only to positioned boxes; `auto`/non-positioned sort as 0.
	z_index := if is_positioned(position_value(element, author_rules)) {
		css.cascaded_value_with_ua(element, css.property_id_from_string('z-index') or { return BlockBox{} },
			author_rules).int()
	} else {
		0
	}

	// Computed colors for the display list: background-color (default transparent) and text color
	// (default black).
	background_color := css.computed_color(element, css.property_id_from_string('background-color') or {
		return BlockBox{}
	}, author_rules) or { css.Color{0, 0, 0, 0} }
	text_color := css.computed_color(element, css.property_id_from_string('color') or {
		return BlockBox{}
	}, author_rules) or { css.Color{0, 0, 0, 255} }
	// Border color defaults to `currentColor` (the text color), which computed_color resolves.
	border_color := css.computed_color(element, css.property_id_from_string('border-top-color') or {
		return BlockBox{}
	}, author_rules) or { text_color }

	return BlockBox{
		tag_name:            element.local_name()
		x:                   content_x
		y:                   content_top
		width:               width
		height:              height
		margin:              margin
		border:              border
		padding:             padding
		outer_top_margin:    outer_top_margin
		outer_bottom_margin: outer_bottom_margin
		z_index:             z_index
		background_color:    background_color
		text_color:          text_color
		border_color:        border_color
		children:            children
		lines:               lines
	}
}
