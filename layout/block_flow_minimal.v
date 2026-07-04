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
// and min/max-height. Horizontal `auto` margins absorb leftover space (both auto centers the box; a
// single one right/left-aligns). `position: relative` offsets a box (and its subtree) by its insets
// without disturbing the flow. Text-bearing blocks produce inline line boxes (word-wrapped, `<br>`
// aware) positioned per `text-align`.
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

// A laid-out line box within a block's inline formatting context: `x`/`y` is the top-left of the
// line's content in CSS px, `width` the used width of the content on the line (after wrapping), and
// `height` the line-height. `x` reflects `text-align` within the content box.
pub struct TextLine {
pub mut:
	x      f64
	y      f64
	width  f64
	height f64
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
	children            []BlockBox
	lines               []TextLine
}

// Return a copy of `box` with its own geometry, every descendant's, and its line boxes shifted by
// (`dx`, `dy`). Used to reposition a subtree after margin collapsing / positioning decides where its
// border box actually lands.
fn translate_block(box BlockBox, dx f64, dy f64) BlockBox {
	mut moved := box
	moved.x += dx
	moved.y += dy
	moved.children = box.children.map(translate_block(it, dx, dy))
	moved.lines = box.lines.map(TextLine{
		x:      it.x + dx
		y:      it.y + dy
		width:  it.width
		height: it.height
	})
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
			display := css.cascaded_value_with_ua(element, display_id, author_rules)
			if is_block_level_display(display) {
				elements << element
			}
		}
	}
	return elements
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

// Gather a block's inline content as text segments split at `<br>` forced line breaks: the text
// between consecutive `<br>`s (walking into inline descendants) forms one segment. `display: none`
// and out-of-flow (absolutely positioned) descendants contribute nothing.
fn append_inline_segments(node &dom.Node, author_rules []&css.CSSRule, mut segments []string) {
	display_id := css.property_id_from_string('display') or { return }
	for child in node.children_as_vector() {
		if child.is_text() {
			segments[segments.len - 1] += unsafe { &dom.Text(child) }.data()
		} else if element := child.as_element() {
			if css.cascaded_value_with_ua(element, display_id, author_rules) == 'none' {
				continue
			}
			if is_absolutely_positioned(position_value(element, author_rules)) {
				continue // out of flow
			}
			if element.local_name() == 'br' {
				segments << '' // forced line break starts a new segment
			} else {
				append_inline_segments(element.as_node(), author_rules, mut segments)
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
// y = 0), to be translated to the content-box top by the caller. Content is split at `<br>` breaks
// into segments, each wrapped at word boundaries against `content_width`; every line is placed at
// `content_x` adjusted for `text-align`. An empty segment between breaks is still an (empty) line;
// truly empty content yields no lines.
//
// FIXME: still stands in for a real inline formatting context — glyph advances are estimated, there
// is no per-inline font/line-height, no inline fragment geometry (individual word positions), no
// per-word justification, and no bidi.
fn layout_inline_lines(element &dom.Element, content_x f64, content_width f64, author_rules []&css.CSSRule) []TextLine {
	mut segments := ['']
	append_inline_segments(element.as_node(), author_rules, mut segments)
	if segments.len == 1 && segments[0].fields().len == 0 {
		return []TextLine{} // no inline content at all
	}

	line_height := css.computed_line_height_px(element, author_rules)
	glyph_width := 0.5 * css.computed_font_size_px(element, author_rules)
	align := css.cascaded_value_with_ua(element, css.property_id_from_string('text-align') or {
		return []TextLine{}
	}, author_rules)

	mut lines := []TextLine{}
	mut y := 0.0
	for segment in segments {
		words := segment.fields()
		line_widths := if words.len == 0 { [0.0] } else { wrap_line_widths(words, content_width,
				glyph_width, glyph_width) }
		for line_width in line_widths {
			lines << TextLine{
				x:      aligned_line_x(content_x, content_width, line_width, align)
				y:      y
				width:  line_width
				height: line_height
			}
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

// Whether `element` establishes a new block formatting context, in which case its margins do not
// collapse with its in-flow children. Detects `display: flow-root`, absolute/fixed positioning, and a
// non-visible `overflow` on either axis (`hidden`/`scroll`/`auto`/`clip`). FIXME: floats, inline-block,
// table cells, and the document root also establish BFCs.
fn establishes_block_formatting_context(element &dom.Element, author_rules []&css.CSSRule) bool {
	if is_absolutely_positioned(position_value(element, author_rules)) {
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
// FIXME: shrink-to-fit width (used when width is auto and left/right aren't both set) is approximated
// by stretching to the containing block; auto-margin centering between insets isn't done; the
// static position (when top/left are auto) is approximated by the containing block's origin.
fn layout_absolute(element &dom.Element, cb PositionedContainingBlock, author_rules []&css.CSSRule) BlockBox {
	left := offset_length(element, 'left', cb.width, author_rules)
	right := offset_length(element, 'right', cb.width, author_rules)
	top := offset_length(element, 'top', cb.height, author_rules)
	bottom := offset_length(element, 'bottom', cb.height, author_rules)
	width_auto := size_is_auto(element, 'width', author_rules)
	height_auto := size_is_auto(element, 'height', author_rules)

	// Choose the containing width fed to layout_block so its width algorithm produces the abspos width:
	// width:auto stretched between left and right fills the gap; otherwise the width resolves against cb.
	available_width := if width_auto {
		if l := left {
			if r := right {
				non_negative(cb.width - l - r)
			} else {
				cb.width
			}
		} else {
			cb.width
		}
	} else {
		cb.width
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
		desired_border_top := if has_children {
			flow_bottom + collapse_margins([prev_outer_bottom, cb.outer_top_margin])
		} else if top_adjoins {
			0.0 // first child's top margin collapses through into this box's outer top margin
		} else {
			cb.outer_top_margin // separated by border/padding: the margin sits inside the content
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
		local_lines = layout_inline_lines(element, content_x, width, author_rules)
		for line in local_lines {
			if line.y + line.height > content_height {
				content_height = line.y + line.height
			}
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
	lines := local_lines.map(TextLine{
		x:      it.x
		y:      it.y + content_top
		width:  it.width
		height: it.height
	})

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
		children:            children
		lines:               lines
	}
}
