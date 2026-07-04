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
// without disturbing the flow (as does `transform: translate(...)`). Text-bearing blocks produce inline line boxes (word-wrapped, `<br>`-
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
	// The computed `text-decoration-line` covering this word (`none`, or a space-separated set of
	// `underline`/`overline`/`line-through`); drawn in the fragment's color.
	decoration string = 'none'
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
			x:          it.x + dx
			y:          it.y + dy
			width:      it.width
			height:     it.height
			text:       it.text
			color:      it.color
			decoration: it.decoration
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
	// The uniform border-radius (px) applied when filling the background/border box.
	border_radius f64
	// The outline (painted outside the border box, not affecting layout): its width (0 = none), the
	// gap between the border edge and the outline (`outline-offset`, may be negative), and its color.
	outline_width  f64
	outline_offset f64
	outline_color  css.Color
	// The first `box-shadow` (drop shadow behind the box), or none. Offsets are relative to the border
	// box so the shadow follows the box when it is translated.
	shadow ?BoxShadow
	// A `linear-gradient` background image, painted over the background color, or none.
	background_gradient ?LinearGradient
	// `opacity` is this box's own opacity (0..1) in the tree; in a paint-order entry it holds the
	// cumulative opacity (this box's times its ancestors').
	opacity f64 = 1.0
	// Whether this box paints its own background/border/text (`visibility: visible`). A
	// `visibility: hidden` box still takes up space but is not painted; because `visibility` inherits,
	// each box carries its own resolved value, so a visible descendant of a hidden box still paints.
	visible bool = true
	// The `unique_id` of the element this box was laid out for, so a box can be found from its element
	// (backing getBoundingClientRect).
	node_id  i64
	children []BlockBox
	lines    []TextLine
}

// A rectangle in the layout coordinate space (document coordinates when laid out from the root).
pub struct LayoutRect {
pub:
	x      f64
	y      f64
	width  f64
	height f64
}

// This box's border box (content plus padding and border) as a rectangle.
pub fn (b &BlockBox) border_box() LayoutRect {
	return LayoutRect{
		x:      b.x - b.padding.left - b.border.left
		y:      b.y - b.padding.top - b.border.top
		width:  b.width + b.padding.left + b.padding.right + b.border.left + b.border.right
		height: b.height + b.padding.top + b.padding.bottom + b.border.top + b.border.bottom
	}
}

// Find the laid-out box for the element with `node_id` (its `unique_id`) anywhere in this subtree.
pub fn (b &BlockBox) find_box(node_id i64) ?BlockBox {
	if b.node_id == node_id {
		return *b
	}
	for child in b.children {
		if found := child.find_box(node_id) {
			return found
		}
	}
	return none
}

// The border-box rectangle of `element` within this laid-out tree — a working getBoundingClientRect
// (in document coordinates when the tree was laid out from the document root). None if not laid out.
pub fn (b &BlockBox) bounding_rect_for(element &dom.Element) ?LayoutRect {
	box := b.find_box(i64(element.as_node().unique_id())) or { return none }
	return box.border_box()
}

// The CSSOM *resolved* value of `property_name` for `element` (analogous to
// `getComputedStyle(element).getPropertyValue(name)`), backed by this laid-out box tree. The
// layout-dependent box metrics — width/height (used content-box size) and the used padding/margin/
// border widths — return their USED px from the box; every other property falls back to the
// layout-free computed value (`css.computed_style_value`). This closes the getComputedStyle FIXME
// where a percentage/`auto` width would otherwise return its specified value.
pub fn (b &BlockBox) resolved_style_value(element &dom.Element, property_name string, author_rules []&css.CSSRule) string {
	if box := b.find_box(i64(element.as_node().unique_id())) {
		used := match property_name {
			'width' { box.width }
			'height' { box.height }
			'padding-top' { box.padding.top }
			'padding-right' { box.padding.right }
			'padding-bottom' { box.padding.bottom }
			'padding-left' { box.padding.left }
			'margin-top' { box.margin.top }
			'margin-right' { box.margin.right }
			'margin-bottom' { box.margin.bottom }
			'margin-left' { box.margin.left }
			'border-top-width' { box.border.top }
			'border-right-width' { box.border.right }
			'border-bottom-width' { box.border.bottom }
			'border-left-width' { box.border.left }
			else { return css.computed_style_value(element, property_name, author_rules) }
		}
		return '${fmt_px(used)}px'
	}
	return css.computed_style_value(element, property_name, author_rules)
}

// Whether `x`/`y` falls within this box's border box.
fn (rect LayoutRect) contains(x f64, y f64) bool {
	return x >= rect.x && x < rect.x + rect.width && y >= rect.y && y < rect.y + rect.height
}

// Hit-test the point (`x`, `y`): the `node_id` of the topmost box whose border box contains it, or
// none. Walks the paint order back-to-front, so the last-painted (topmost, z-index-aware) box wins —
// backing document.elementFromPoint.
pub fn (b &BlockBox) hit_test(x f64, y f64) ?i64 {
	order := b.paint_order()
	for i := order.len - 1; i >= 0; i-- {
		box := order[i]
		if box.node_id != 0 && box.border_box().contains(x, y) {
			return box.node_id
		}
	}
	return none
}

// The element at the point (`x`, `y`) — hit-test the box tree, then resolve the box's `node_id` back
// to its element by walking `root`'s subtree. Analogous to document.elementFromPoint.
pub fn (b &BlockBox) element_at_point(x f64, y f64, root &dom.Node) ?&dom.Element {
	node_id := b.hit_test(x, y) or { return none }
	return find_element_by_node_id(root, node_id)
}

fn find_element_by_node_id(node &dom.Node, node_id i64) ?&dom.Element {
	if element := node.as_element() {
		if i64(element.as_node().unique_id()) == node_id {
			return element
		}
	}
	for child in node.children_as_vector() {
		if found := find_element_by_node_id(child, node_id) {
			return found
		}
	}
	return none
}

// The border-box width/height of `element` (its `offsetWidth`/`offsetHeight`), or none if not laid out.
pub fn (b &BlockBox) offset_width_for(element &dom.Element) ?f64 {
	return (b.bounding_rect_for(element) or { return none }).width
}

pub fn (b &BlockBox) offset_height_for(element &dom.Element) ?f64 {
	return (b.bounding_rect_for(element) or { return none }).height
}

// `element`'s offsetParent: the nearest ancestor that is positioned or is a table cell/table/body,
// else none. (Simplified from the HTML spec — no display:none / rooted-in-document checks.)
pub fn offset_parent_element(element &dom.Element, author_rules []&css.CSSRule) ?&dom.Element {
	mut current := element.as_node().parent_element() or { return none }
	for {
		local := current.local_name()
		if is_positioned(position_value(current, author_rules)) || local == 'body' || local == 'td'
			|| local == 'th' || local == 'table' {
			return current
		}
		current = current.as_node().parent_element() or { return none }
	}
	return none
}

// `element`'s offsetTop: its border-box top relative to its offsetParent's padding-box top (or the
// document top when there is no offsetParent).
pub fn (b &BlockBox) offset_top_for(element &dom.Element, author_rules []&css.CSSRule) ?f64 {
	element_box := b.find_box(i64(element.as_node().unique_id())) or { return none }
	element_border_top := element_box.y - element_box.padding.top - element_box.border.top
	parent := offset_parent_element(element, author_rules) or { return element_border_top }
	parent_box := b.find_box(i64(parent.as_node().unique_id())) or { return element_border_top }
	return element_border_top - (parent_box.y - parent_box.padding.top)
}

// `element`'s offsetLeft: its border-box left relative to its offsetParent's padding-box left.
pub fn (b &BlockBox) offset_left_for(element &dom.Element, author_rules []&css.CSSRule) ?f64 {
	element_box := b.find_box(i64(element.as_node().unique_id())) or { return none }
	element_border_left := element_box.x - element_box.padding.left - element_box.border.left
	parent := offset_parent_element(element, author_rules) or { return element_border_left }
	parent_box := b.find_box(i64(parent.as_node().unique_id())) or { return element_border_left }
	return element_border_left - (parent_box.x - parent_box.padding.left)
}

// An item produced by the rendered-text collection: either a run of text or a *required line break
// count* (a positive integer, held as a negative-tagged marker). We model the variant as a struct
// with a `line_breaks` count of 0 meaning "this is a text item" and >0 meaning "this is a run of N
// required line breaks" (the `text` field is then empty).
struct TextItem {
	text        string
	line_breaks int
}

// The rendered text of `element` — the `innerText`/`outerText` getter, i.e. the HTML "get the text
// steps" (https://html.spec.whatwg.org/multipage/dom.html#get-the-text-steps). Unlike `textContent`
// it reflects rendering: `display:none` and `visibility:hidden` subtrees are omitted, runs of
// collapsible white-space are collapsed to single spaces, `<br>` and block boundaries introduce line
// breaks, and `<p>` is surrounded by blank lines.
//
// FIXME: this is a layout-free approximation of the spec (which collects text from the laid-out CSS
// boxes): white-space collapsing does not trim at block/line edges, and table-cell/`\t` and
// table-row breaks are not modeled.
pub fn inner_text(element &dom.Element, author_rules []&css.CSSRule) string {
	// Steps 3–6 of "get the text steps", run over the element's children.
	mut results := []TextItem{}
	for child in element.as_node().children_as_vector() {
		results << rendered_text_items(child, author_rules)
	}
	// 4. Remove empty-string items.
	results = results.filter(it.line_breaks > 0 || it.text != '')
	// 5. Drop runs of required-line-break items at the start and end.
	for results.len > 0 && results[0].line_breaks > 0 {
		results.delete(0)
	}
	for results.len > 0 && results[results.len - 1].line_breaks > 0 {
		results.delete(results.len - 1)
	}
	// 6. Replace each remaining run of required-line-break items with LFs (the run's maximum count).
	mut out := ''
	mut i := 0
	for i < results.len {
		item := results[i]
		if item.line_breaks == 0 {
			out += item.text
			i++
			continue
		}
		mut max_breaks := item.line_breaks
		mut j := i + 1
		for j < results.len && results[j].line_breaks > 0 {
			if results[j].line_breaks > max_breaks {
				max_breaks = results[j].line_breaks
			}
			j++
		}
		out += '\n'.repeat(max_breaks)
		i = j
	}
	return out
}

// The rendered-text collection steps for a single node
// (https://html.spec.whatwg.org/multipage/dom.html#rendered-text-collection-steps).
fn rendered_text_items(node &dom.Node, author_rules []&css.CSSRule) []TextItem {
	// A text node contributes its data after white-space processing (using the parent's white-space,
	// which is inherited). It has no children and is only reached inside a rendered subtree.
	if node.is_text() {
		text := unsafe { &dom.Text(node) }.data()
		white_space := if parent := node.parent_element() {
			css.cascaded_value_with_ua(parent, css.property_id_from_string('white-space') or {
				return []TextItem{}
			}, author_rules)
		} else {
			'normal'
		}
		return [TextItem{
			text: collapse_rendered_whitespace(text, white_space)
		}]
	}

	element := node.as_element() or { return []TextItem{} }

	// 3. A `display:none` subtree is not rendered and contributes nothing.
	display := css.cascaded_value_with_ua(element, css.property_id_from_string('display') or {
		return []TextItem{}
	}, author_rules)
	if display == 'none' {
		return []TextItem{}
	}

	// 1. Collect the children's items first (tree order).
	mut items := []TextItem{}
	for child in node.children_as_vector() {
		items << rendered_text_items(child, author_rules)
	}

	// 2. A `visibility:hidden` box hides its own contribution but not its (possibly re-shown) children.
	visibility := css.cascaded_value_with_ua(element, css.property_id_from_string('visibility') or {
		return items
	}, author_rules)
	if visibility != 'visible' {
		return items
	}

	local := element.local_name()

	// 5. `<br>` contributes a single line feed.
	if local == 'br' {
		items << TextItem{
			text: '\n'
		}
		return items
	}

	// 8. `<p>` is surrounded by 2 required line breaks (a blank line).
	if local == 'p' {
		items.prepend(TextItem{ line_breaks: 2 })
		items << TextItem{ line_breaks: 2 }
		return items
	}

	// 9. A block-level box is surrounded by 1 required line break.
	if is_block_level_display(display) {
		items.prepend(TextItem{ line_breaks: 1 })
		items << TextItem{ line_breaks: 1 }
	}
	return items
}

// Apply the CSS white-space collapsing that `innerText` observes. For collapsible white-space
// (`normal`/`nowrap`) every run of ASCII whitespace collapses to a single space. `pre`/`pre-wrap`
// preserve spaces and newlines verbatim; `pre-line` collapses spaces but keeps newlines.
fn collapse_rendered_whitespace(text string, white_space string) string {
	if white_space == 'pre' || white_space == 'pre-wrap' {
		return text
	}
	preserve_newlines := white_space == 'pre-line'
	mut out := []u8{}
	mut in_space := false
	for c in text {
		is_ws := c == ` ` || c == `\t` || c == `\n` || c == `\r` || c == 12 // FF
		if preserve_newlines && c == `\n` {
			// Flush any pending collapsed space run as nothing (a newline absorbs adjacent spaces).
			in_space = false
			out << `\n`
			continue
		}
		if is_ws {
			in_space = true
			continue
		}
		if in_space {
			out << ` `
			in_space = false
		}
		out << c
	}
	if in_space {
		out << ` `
	}
	return out.bytestr()
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
	b.collect_paint_order(mut order, 1.0)
	return order
}

fn (b &BlockBox) collect_paint_order(mut order []BlockBox, inherited_opacity f64) {
	effective_opacity := inherited_opacity * b.opacity
	mut entry := *b
	entry.children = []
	entry.opacity = effective_opacity // the entry carries the cumulative opacity
	order << entry
	for child in stable_sort_by_z(b.children) {
		child.collect_paint_order(mut order, effective_opacity)
	}
}

// A single entry in the display list produced from a laid-out box tree: either a filled rectangle
// (`fill_rect`, e.g. a background) or drawn text (`draw_text`). `color` is the serialized paint color.
pub struct PaintCommand {
pub:
	kind    string // 'fill_rect' | 'draw_text'
	x       f64
	y       f64
	width   f64
	height  f64
	color   string
	text    string // for 'draw_text'
	opacity f64 = 1.0 // the box's cumulative opacity (this box × its ancestors')
	radius  f64 // corner radius for a rounded 'fill_rect' (0 = square)
	blur    f64 // Gaussian blur radius for a 'fill_rect' (0 = hard edges), used by box-shadow
	// The gradient for a 'fill_gradient' command (a linear-gradient background).
	gradient ?LinearGradient
}

// A resolved `box-shadow`: pixel offsets from the border box, blur and spread radii, and the color.
// `inset` shadows aren't modeled. Offsets/radii are already resolved to px.
pub struct BoxShadow {
pub:
	offset_x f64
	offset_y f64
	blur     f64
	spread   f64
	color    css.Color
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
		// A `visibility: hidden` box takes up space but paints nothing (its visible descendants are
		// separate paint-order entries and still paint).
		if !box.visible {
			continue
		}
		opacity := box.opacity
		border_left := box.x - box.padding.left - box.border.left
		border_top := box.y - box.padding.top - box.border.top
		border_width := box.width + box.padding.left + box.padding.right + box.border.left +
			box.border.right
		border_height := box.height + box.padding.top + box.padding.bottom + box.border.top +
			box.border.bottom

		// The corner radius, clamped so it never exceeds half the smaller border-box dimension.
		radius := clamp_radius(box.border_radius, border_width, border_height)
		// box-shadow: a blurred, spread rect offset behind the box, painted before the background.
		if shadow := box.shadow {
			shadow_left := border_left + shadow.offset_x - shadow.spread
			shadow_top := border_top + shadow.offset_y - shadow.spread
			shadow_width := border_width + 2.0 * shadow.spread
			shadow_height := border_height + 2.0 * shadow.spread
			commands << PaintCommand{
				kind: 'fill_rect'
				x: shadow_left
				y: shadow_top
				width: shadow_width
				height: shadow_height
				color: shadow.color.serialize()
				opacity: opacity
				radius: clamp_radius(box.border_radius, shadow_width, shadow_height)
				blur: shadow.blur
			}
		}
		if box.background_color.a > 0 {
			commands << PaintCommand{
				kind: 'fill_rect'
				x: border_left
				y: border_top
				width: border_width
				height: border_height
				color: box.background_color.serialize()
				opacity: opacity
				radius: radius
			}
		}
		// A linear-gradient background image paints over the background color.
		if grad := box.background_gradient {
			commands << PaintCommand{
				kind: 'fill_gradient'
				x: border_left
				y: border_top
				width: border_width
				height: border_height
				opacity: opacity
				radius: radius
				gradient: grad
			}
		}
		// Border edges (each along the border box; corners overlap). FIXME: with border-radius the
		// edges stay square (no arced corners) — only the background fill is rounded.
		border := box.border_color.serialize()
		if box.border.top > 0 {
			commands << PaintCommand{
				kind: 'fill_rect'
				x: border_left
				y: border_top
				width: border_width
				height: box.border.top
				color: border
				opacity: opacity
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
				opacity: opacity
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
				opacity: opacity
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
				opacity: opacity
			}
		}
		// The outline: four rects drawn outward from the border box expanded by `outline-offset`.
		// FIXME: outlines don't follow border-radius (drawn square) and share one color.
		if box.outline_width > 0 {
			ow := box.outline_width
			ex := border_left - box.outline_offset
			ey := border_top - box.outline_offset
			ew := border_width + 2.0 * box.outline_offset
			eh := border_height + 2.0 * box.outline_offset
			oc := box.outline_color.serialize()
			commands << PaintCommand{
				kind: 'fill_rect'
				x: ex - ow
				y: ey - ow
				width: ew + 2.0 * ow
				height: ow
				color: oc
				opacity: opacity
			} // top
			commands << PaintCommand{
				kind: 'fill_rect'
				x: ex - ow
				y: ey + eh
				width: ew + 2.0 * ow
				height: ow
				color: oc
				opacity: opacity
			} // bottom
			commands << PaintCommand{
				kind: 'fill_rect'
				x: ex - ow
				y: ey
				width: ow
				height: eh
				color: oc
				opacity: opacity
			} // left
			commands << PaintCommand{
				kind: 'fill_rect'
				x: ex + ew
				y: ey
				width: ow
				height: eh
				color: oc
				opacity: opacity
			} // right
		}
		for line in box.lines {
			for fragment in line.fragments {
				commands << PaintCommand{
					kind: 'draw_text'
					x: fragment.x
					y: fragment.y
					width: fragment.width
					height: fragment.height
					color: fragment.color.serialize()
					text: fragment.text
					opacity: opacity
				}
				commands << decoration_commands(fragment, opacity)
			}
		}
	}
	return commands
}

// The text-decoration lines for a fragment, drawn in its color: a thin `fill_rect` per decoration
// keyword (underline near the baseline, line-through through the middle, overline at the top).
// FIXME: positions/thickness are approximated from the line-height (no real font metrics), and
// text-decoration-color/style/thickness aren't modeled.
fn decoration_commands(fragment TextFragment, opacity f64) []PaintCommand {
	if fragment.decoration == '' || fragment.decoration == 'none' {
		return []PaintCommand{}
	}
	color := fragment.color.serialize()
	thickness := if fragment.height * 0.0625 > 1.0 { fragment.height * 0.0625 } else { 1.0 }
	mut commands := []PaintCommand{}
	if fragment.decoration.contains('underline') {
		commands << PaintCommand{
			kind: 'fill_rect'
			x: fragment.x
			y: fragment.y + fragment.height * 0.85
			width: fragment.width
			height: thickness
			color: color
			opacity: opacity
		}
	}
	if fragment.decoration.contains('overline') {
		commands << PaintCommand{
			kind: 'fill_rect'
			x: fragment.x
			y: fragment.y
			width: fragment.width
			height: thickness
			color: color
			opacity: opacity
		}
	}
	if fragment.decoration.contains('line-through') {
		commands << PaintCommand{
			kind: 'fill_rect'
			x: fragment.x
			y: fragment.y + fragment.height * 0.5
			width: fragment.width
			height: thickness
			color: color
			opacity: opacity
		}
	}
	return commands
}

// The marker line for a `display: list-item` element — a bullet or ordinal placed as a single-word
// line hanging one glyph-width to the left of the content box (list-style-position: outside). Returns
// none when the element is not a list item or its list-style-type is `none`.
//
// FIXME: only `outside` position is modeled (the marker always hangs left, never flows inside the
// first line); the marker is vertically aligned to the content top, not the first line's baseline.
fn list_marker_line(element &dom.Element, content_x f64, content_top f64, text_color css.Color, author_rules []&css.CSSRule) ?TextLine {
	display := css.cascaded_value_with_ua(element, css.property_id_from_string('display') or {
		return none
	}, author_rules)
	if display != 'list-item' {
		return none
	}
	marker := list_marker_text(element, author_rules)
	if marker == '' {
		return none
	}
	glyph := 0.5 * css.computed_font_size_px(element, author_rules)
	marker_width := f64(marker.runes().len) * glyph
	line_height := css.computed_line_height_px(element, author_rules)
	marker_x := content_x - marker_width - glyph // hang to the left, one glyph-width gap
	return TextLine{
		x:      marker_x
		y:      content_top
		width:  marker_width
		height: line_height
		fragments: [
			TextFragment{
				x:      marker_x
				y:      content_top
				width:  marker_width
				height: line_height
				text:   marker
				color:  text_color
			},
		]
	}
}

// The marker string for a list item from its computed `list-style-type`: a bullet glyph for
// disc/circle/square, or a counter (`ordinal.`) for the numeric/alphabetic/roman styles. `none` -> ''.
// FIXME: other list-style-types (e.g. CJK, Greek, Hebrew) fall back to a disc.
fn list_marker_text(element &dom.Element, author_rules []&css.CSSRule) string {
	kind := css.cascaded_value_with_ua(element, css.property_id_from_string('list-style-type') or {
		return ''
	}, author_rules)
	if kind in ['disc', 'circle', 'square', 'none'] {
		return match kind {
			'disc' { '•' }
			'circle' { '◦' }
			'square' { '▪' }
			else { '' } // none
		}
	}
	// Counter styles: the 1-based ordinal formatted per the style, followed by `.`.
	ordinal := list_item_ordinal(element, author_rules)
	return match kind {
		'decimal' { '${ordinal}.' }
		'decimal-leading-zero' { '${if ordinal < 10 { '0' } else { '' }}${ordinal}.' }
		'lower-alpha', 'lower-latin' { '${alphabetic_marker(ordinal, false)}.' }
		'upper-alpha', 'upper-latin' { '${alphabetic_marker(ordinal, true)}.' }
		'lower-roman' { '${roman_marker(ordinal, false)}.' }
		'upper-roman' { '${roman_marker(ordinal, true)}.' }
		else { '•' } // unknown -> disc
	}
}

// The bijective base-26 alphabetic marker for `n` (1->a, 26->z, 27->aa, ...), in the given case.
// Falls back to the decimal for n < 1.
fn alphabetic_marker(n int, upper bool) string {
	if n < 1 {
		return n.str()
	}
	base := if upper { u8(`A`) } else { u8(`a`) }
	mut num := n
	mut out := []u8{}
	for num > 0 {
		num--
		out.prepend(base + u8(num % 26))
		num /= 26
	}
	return out.bytestr()
}

// The Roman-numeral marker for `n` (1->i, 4->iv, 9->ix, ...), in the given case. Falls back to the
// decimal for n outside 1..3999.
fn roman_marker(n int, upper bool) string {
	if n < 1 || n > 3999 {
		return n.str()
	}
	values := [1000, 900, 500, 400, 100, 90, 50, 40, 10, 9, 5, 4, 1]
	symbols := ['m', 'cm', 'd', 'cd', 'c', 'xc', 'l', 'xl', 'x', 'ix', 'v', 'iv', 'i']
	mut num := n
	mut out := ''
	for i, value in values {
		for num >= value {
			out += symbols[i]
			num -= value
		}
	}
	return if upper { out.to_upper() } else { out }
}

// The 1-based position of `element` among its list-item siblings (for ordered markers).
fn list_item_ordinal(element &dom.Element, author_rules []&css.CSSRule) int {
	parent := element.as_node().parent_element() or { return 1 }
	display_id := css.property_id_from_string('display') or { return 1 }
	mut ordinal := 0
	for child in parent.as_node().children_as_vector() {
		if el := child.as_element() {
			if css.cascaded_value_with_ua(el, display_id, author_rules) == 'list-item' {
				ordinal++
				if el.as_node().is_same_node(element.as_node()) {
					return ordinal
				}
			}
		}
	}
	return if ordinal == 0 { 1 } else { ordinal }
}

// Escape the five XML metacharacters so text can go inside SVG markup.
fn escape_xml(text string) string {
	return text.replace('&', '&amp;').replace('<', '&lt;').replace('>', '&gt;').replace('"',
		'&quot;').replace("'", '&apos;')
}

// Render this box tree to an SVG document `width`×`height` px: each display-list command becomes a
// `<rect>` (fills, backgrounds, borders) or `<text>` (in paint order, honoring opacity). A blurred
// fill (box-shadow) gets a Gaussian-blur `<filter>`. This closes the pipeline — an HTML string laid
// out and turned into a viewable image.
//
// FIXME: SVG text uses its own font metrics, so text widths won't match this engine's estimates;
// baseline/font-size are approximated from the line-height.
pub fn (b &BlockBox) render_svg(width f64, height f64) string {
	mut defs := []string{}
	mut body := []string{}
	for command in b.paint_commands() {
		if command.kind == 'fill_rect' {
			corner := if command.radius > 0 { ' rx="${fmt_px(command.radius)}" ry="${fmt_px(command.radius)}"' } else { '' }
			mut filter := ''
			if command.blur > 0 {
				id := 'blur${defs.len}'
				// The blur can bleed past the rect, so give the filter region generous margins.
				defs << '<filter id="${id}" x="-50%" y="-50%" width="200%" height="200%"><feGaussianBlur stdDeviation="${fmt_px(command.blur / 2.0)}"/></filter>'
				filter = ' filter="url(#${id})"'
			}
			body << '<rect x="${fmt_px(command.x)}" y="${fmt_px(command.y)}" width="${fmt_px(command.width)}" height="${fmt_px(command.height)}"${corner}${filter} fill="${command.color}" fill-opacity="${fmt_px(command.opacity)}"/>'
		} else if command.kind == 'fill_gradient' {
			if grad := command.gradient {
				id := 'grad${defs.len}'
				mut stops := ''
				n := grad.colors.len
				for i, c in grad.colors {
					offset := if n > 1 { f64(i) / f64(n - 1) * 100.0 } else { 0.0 }
					stops += '<stop offset="${fmt_px(offset)}%" stop-color="${c.serialize()}"/>'
				}
				if grad.radial {
					defs << '<radialGradient id="${id}">${stops}</radialGradient>'
				} else {
					defs << '<linearGradient id="${id}" x1="${fmt_px(grad.x1 * 100.0)}%" y1="${fmt_px(grad.y1 * 100.0)}%" x2="${fmt_px(grad.x2 * 100.0)}%" y2="${fmt_px(grad.y2 * 100.0)}%">${stops}</linearGradient>'
				}
				corner := if command.radius > 0 { ' rx="${fmt_px(command.radius)}" ry="${fmt_px(command.radius)}"' } else { '' }
				body << '<rect x="${fmt_px(command.x)}" y="${fmt_px(command.y)}" width="${fmt_px(command.width)}" height="${fmt_px(command.height)}"${corner} fill="url(#${id})" fill-opacity="${fmt_px(command.opacity)}"/>'
			}
		} else if command.kind == 'draw_text' {
			font_size := command.height * 0.8 // approximate the font-size from the line-height
			baseline := command.y + font_size
			body << '<text x="${fmt_px(command.x)}" y="${fmt_px(baseline)}" font-size="${fmt_px(font_size)}" fill="${command.color}" fill-opacity="${fmt_px(command.opacity)}">${escape_xml(command.text)}</text>'
		}
	}
	mut parts := ['<svg xmlns="http://www.w3.org/2000/svg" width="${fmt_px(width)}" height="${fmt_px(height)}">']
	if defs.len > 0 {
		parts << '<defs>${defs.join('')}</defs>'
	}
	parts << body
	parts << '</svg>'
	return parts.join('\n')
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

// A length/percentage/calc() property resolved to px, or 0 when it's `auto`/absent/other. Percentages
// (and `%` inside a calc) resolve against `basis` (for margins and padding, the containing width).
//
// When the physical property is absent (no length/percentage/calc resolves), its CSS *logical*
// equivalent is tried (e.g. `padding-left` <- `padding-inline-start`), so the UA sheet's logical
// margins/padding (`p { margin-block: 1em }`, `ul { padding-inline-start: 40px }`, ...) take effect.
// This assumes a left-to-right, horizontal-tb writing mode (the only mode this engine supports).
fn used_length_or_zero(element &dom.Element, property_name string, basis f64, author_rules []&css.CSSRule) f64 {
	id := css.property_id_from_string(property_name) or { return 0 }
	// If the physical property was never declared, defer to its CSS logical equivalent (once; a logical
	// property has no further mapping). The cascade always yields the initial value for an unset
	// property, so "declared?" must be asked explicitly rather than inferred from the resolved value.
	if !css.is_property_specified(element, id, author_rules) {
		if logical := logical_equivalent(property_name) {
			return used_length_or_zero(element, logical, basis, author_rules)
		}
	}
	if px := css.computed_length_px(element, id, author_rules) {
		return px
	}
	if pct := css.computed_percentage(element, id, author_rules) {
		return basis * pct / 100.0
	}
	if calc := css.computed_calc_px(element, id, basis, author_rules) {
		return calc
	}
	return 0
}

// The CSS logical property that maps to `physical` in a left-to-right, horizontal-tb writing mode
// (inline-start = left, inline-end = right, block-start = top, block-end = bottom), or none when
// `physical` has no logical counterpart. FIXME: only this one writing mode is handled; an explicit
// physical `auto` margin is treated as absent here, so it wrongly falls back to a logical value.
fn logical_equivalent(physical string) ?string {
	return match physical {
		'padding-left' { 'padding-inline-start' }
		'padding-right' { 'padding-inline-end' }
		'padding-top' { 'padding-block-start' }
		'padding-bottom' { 'padding-block-end' }
		'margin-left' { 'margin-inline-start' }
		'margin-right' { 'margin-inline-end' }
		'margin-top' { 'margin-block-start' }
		'margin-bottom' { 'margin-block-end' }
		else { none }
	}
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

// The used outline width (px): 0 when `outline-style` is `none`/`hidden`; otherwise the outline-width
// length or the thin/medium/thick keyword scale (1/3/5 px), like a border.
fn used_outline_width(element &dom.Element, author_rules []&css.CSSRule) f64 {
	style_id := css.property_id_from_string('outline-style') or { return 0 }
	style := css.cascaded_value_with_ua(element, style_id, author_rules)
	if style == 'none' || style == 'hidden' {
		return 0
	}
	width_id := css.property_id_from_string('outline-width') or { return 0 }
	if px := css.computed_length_px(element, width_id, author_rules) {
		return px
	}
	return match css.cascaded_value_with_ua(element, width_id, author_rules) {
		'thin' { 1.0 }
		'thick' { 5.0 }
		else { 3.0 } // 'medium' (the initial value)
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

// Whether `element` is a row flex container: `display: flex` with a `row` (or default) direction.
// FIXME: `row-reverse` falls through to the row path (not reversed).
fn is_flex_row(element &dom.Element, author_rules []&css.CSSRule) bool {
	display_id := css.property_id_from_string('display') or { return false }
	if css.cascaded_value_with_ua(element, display_id, author_rules) != 'flex' {
		return false
	}
	dir_id := css.property_id_from_string('flex-direction') or { return true }
	dir := css.cascaded_value_with_ua(element, dir_id, author_rules)
	return dir == 'row' || dir == '' || dir == 'row-reverse'
}

// Whether `element` is a column flex container: `display: flex` with a `column` direction.
// FIXME: `column-reverse` is treated as `column` (not reversed).
fn is_flex_column(element &dom.Element, author_rules []&css.CSSRule) bool {
	display_id := css.property_id_from_string('display') or { return false }
	if css.cascaded_value_with_ua(element, display_id, author_rules) != 'flex' {
		return false
	}
	dir_id := css.property_id_from_string('flex-direction') or { return false }
	dir := css.cascaded_value_with_ua(element, dir_id, author_rules)
	return dir == 'column' || dir == 'column-reverse'
}

// The flex items of `node`: its in-flow element children (any display is blockified, so inline and
// floated children count too), excluding `display: none` and absolutely positioned elements.
fn flex_item_elements(node &dom.Node, author_rules []&css.CSSRule) []&dom.Element {
	display_id := css.property_id_from_string('display') or { return []&dom.Element{} }
	mut elements := []&dom.Element{}
	for child in node.children_as_vector() {
		if element := child.as_element() {
			if is_absolutely_positioned(position_value(element, author_rules)) {
				continue // out of flow
			}
			if css.cascaded_value_with_ua(element, display_id, author_rules) == 'none' {
				continue
			}
			elements << element
		}
	}
	return elements
}

// A flex item's flex base main size (content-box px): its `flex-basis` when that is a length/percentage
// (`0%` → 0), otherwise — for `auto`/`content` — the item's definite `width` if it has one, else its
// content size (max-content). This is the size grow/shrink then adjust.
// FIXME: box-sizing isn't applied to a definite width/basis here (treated as content-box).
fn flex_base_size(element &dom.Element, container_width f64, author_rules []&css.CSSRule) f64 {
	basis_id := css.property_id_from_string('flex-basis') or {
		return flex_content_base(element, container_width, author_rules)
	}
	if px := css.computed_length_px(element, basis_id, author_rules) {
		return px
	}
	if pct := css.computed_percentage(element, basis_id, author_rules) {
		return container_width * pct / 100.0
	}
	// `flex-basis: auto` uses the item's definite width (if any); `content`/unresolved uses content.
	if css.cascaded_value_with_ua(element, basis_id, author_rules) == 'auto'
		&& !size_is_auto(element, 'width', author_rules) {
		width_id := css.property_id_from_string('width') or {
			return flex_content_base(element, container_width, author_rules)
		}
		if wpx := css.computed_length_px(element, width_id, author_rules) {
			return wpx
		}
		if wpct := css.computed_percentage(element, width_id, author_rules) {
			return container_width * wpct / 100.0
		}
	}
	return flex_content_base(element, container_width, author_rules)
}

// A flex item's content-based main size: its max-content, shrink-to-fit clamped to the container.
fn flex_content_base(element &dom.Element, container_width f64, author_rules []&css.CSSRule) f64 {
	return shrink_to_fit(intrinsic_content_width(element, author_rules, true), intrinsic_content_width(element,
		author_rules, false), container_width)
}

// The `flex-grow` factor (default 0) and `flex-shrink` factor (default 1) of a flex item.
fn flex_grow_value(element &dom.Element, author_rules []&css.CSSRule) f64 {
	id := css.property_id_from_string('flex-grow') or { return 0.0 }
	return css.cascaded_value_with_ua(element, id, author_rules).f64()
}

fn flex_shrink_value(element &dom.Element, author_rules []&css.CSSRule) f64 {
	id := css.property_id_from_string('flex-shrink') or { return 1.0 }
	value := css.cascaded_value_with_ua(element, id, author_rules)
	return if value == '' { 1.0 } else { value.f64() }
}

// Resolve each flex item's final main (content) size from its base size and the container's `free`
// main space: positive free grows items by their flex-grow factors; negative free (overflow) shrinks
// them by flex-shrink weighted by base size (clamped ≥ 0). Zero free (or zero total factor) keeps the
// base sizes. FIXME: min/max main-size clamping and the freeze-and-repeat loop aren't modeled.
fn resolve_flex_main_sizes(items []&dom.Element, bases []f64, free f64, author_rules []&css.CSSRule) []f64 {
	mut finals := bases.clone()
	if free > 0 {
		mut total_grow := 0.0
		for item in items {
			total_grow += flex_grow_value(item, author_rules)
		}
		if total_grow > 0 {
			for i, item in items {
				finals[i] = bases[i] + free * flex_grow_value(item, author_rules) / total_grow
			}
		}
	} else if free < 0 {
		mut total_scaled := 0.0
		for i, item in items {
			total_scaled += flex_shrink_value(item, author_rules) * bases[i]
		}
		if total_scaled > 0 {
			for i, item in items {
				finals[i] = non_negative(bases[i] +
					free * (flex_shrink_value(item, author_rules) * bases[i]) / total_scaled)
			}
		}
	}
	return finals
}

// The main-axis gap between flex items (a row's `column-gap`; the `gap` shorthand sets it), in px.
// `normal`/absent is 0.
fn flex_column_gap(element &dom.Element, author_rules []&css.CSSRule) f64 {
	id := css.property_id_from_string('column-gap') or { return 0 }
	return css.computed_length_px(element, id, author_rules) or { 0 }
}

// The main-axis gap for a column flex container (`row-gap`; the `gap` shorthand sets it), in px.
fn flex_row_gap(element &dom.Element, author_rules []&css.CSSRule) f64 {
	id := css.property_id_from_string('row-gap') or { return 0 }
	return css.computed_length_px(element, id, author_rules) or { 0 }
}

// The cascaded `justify-content` value, normalized (`normal` and absent behave as `flex-start`).
fn justify_content_value(element &dom.Element, author_rules []&css.CSSRule) string {
	id := css.property_id_from_string('justify-content') or { return 'flex-start' }
	value := css.cascaded_value_with_ua(element, id, author_rules)
	return if value == '' || value == 'normal' { 'flex-start' } else { value }
}

// The main-axis distribution for `n` flex items given `free` px of leftover space: returns the leading
// offset before the first item and the gap added between adjacent items, so item `i` shifts by
// `leading + i*gap`. The `space-*` distributions only add space when there is free space (on overflow
// they pack at the start); `center`/`flex-end` shift by the raw free space (which may be negative).
fn justify_offsets(value string, free f64, n int) (f64, f64) {
	if n == 0 {
		return 0.0, 0.0
	}
	positive_free := if free > 0 { free } else { 0.0 }
	return match value {
		'flex-end', 'end', 'right' {
			free, 0.0
		}
		'center' {
			free / 2.0, 0.0
		}
		'space-between' {
			if n > 1 { 0.0, positive_free / f64(n - 1) } else { 0.0, 0.0 }
		}
		'space-around' {
			gap := positive_free / f64(n)
			gap / 2.0, gap
		}
		'space-evenly' {
			gap := positive_free / f64(n + 1)
			gap, gap
		}
		else {
			0.0, 0.0 // flex-start / start / normal
		}
	}
}

// The cascaded `align-items` value, normalized (`normal` and absent behave as `stretch`).
fn align_items_value(element &dom.Element, author_rules []&css.CSSRule) string {
	id := css.property_id_from_string('align-items') or { return 'stretch' }
	value := css.cascaded_value_with_ua(element, id, author_rules)
	return if value == '' || value == 'normal' { 'stretch' } else { value }
}

// The effective cross-axis alignment for a flex item: its `align-self` unless that is `auto`/`normal`,
// in which case the container's `align-items` (`container_align`) applies.
fn effective_align_self(element &dom.Element, container_align string, author_rules []&css.CSSRule) string {
	id := css.property_id_from_string('align-self') or { return container_align }
	value := css.cascaded_value_with_ua(element, id, author_rules)
	return if value == '' || value == 'auto' || value == 'normal' { container_align } else { value }
}

// The cross-axis (vertical, for a row) offset that aligns an item whose margin box is `item_cross` px
// tall within a `cross_size` px line, per its resolved alignment. `stretch` (already resized to the
// line), `flex-start`, and `baseline` top-align (0).
fn cross_axis_offset(align string, cross_size f64, item_cross f64) f64 {
	return match align {
		'flex-end', 'end' { cross_size - item_cross }
		'center' { (cross_size - item_cross) / 2.0 }
		else { 0.0 } // flex-start / start / stretch / baseline
	}
}

// The content height that stretches a flex item's box to fill a `cross_size` px line: the line minus
// the item's vertical margins, borders, and padding (so its margin box becomes `cross_size`).
fn flex_stretched_content_height(box BlockBox, cross_size f64) f64 {
	v_edges := box.margin.top + box.margin.bottom + box.border.top + box.border.bottom +
		box.padding.top + box.padding.bottom
	return non_negative(cross_size - v_edges)
}

// The flex container's cross size for aligning items: its explicit content-box height when set (box-
// sizing aware), otherwise the flowed content height (the tallest item).
fn align_cross_size(element &dom.Element, content_height f64, border BoxEdges, padding BoxEdges, border_box bool, author_rules []&css.CSSRule) f64 {
	height_id := css.property_id_from_string('height') or { return content_height }
	if px := css.computed_length_px(element, height_id, author_rules) {
		if border_box {
			return non_negative(px - border.top - border.bottom - padding.top - padding.bottom)
		}
		return px
	}
	return content_height
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
		0.0, author_rules)
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

// A `letter-spacing`/`word-spacing` value resolved to px (may be negative). `normal` (the initial) and
// unresolved keywords give 0; lengths (incl. em/rem, resolved against the element's font) give px.
fn resolve_spacing(element &dom.Element, property_name string, author_rules []&css.CSSRule) f64 {
	id := css.property_id_from_string(property_name) or { return 0 }
	return css.computed_length_px(element, id, author_rules) or { 0 }
}

// Resolve a single length/percentage TOKEN (px/em/rem/%, possibly negative) to px against `basis`
// (used for `%`). Returns 0 for an unrecognized token. Used for properties whose value-logic wraps
// the length in a composite type — text-indent, border-radius corners — that `computed_length_px`
// can't extract, so the cascaded string is parsed directly.
fn resolve_length_token(element &dom.Element, token string, basis f64, author_rules []&css.CSSRule) f64 {
	t := token.trim_space()
	if t.ends_with('px') {
		return t#[..-2].f64()
	}
	if t.ends_with('rem') {
		return t#[..-3].f64() * css.root_font_size_px(element, author_rules)
	}
	if t.ends_with('em') {
		return t#[..-2].f64() * css.computed_font_size_px(element, author_rules)
	}
	if t.ends_with('%') {
		return t#[..-1].f64() * basis / 100.0
	}
	return 0
}

// The `text-indent` value resolved to px (may be negative). `%` is of the content width.
fn resolve_text_indent(element &dom.Element, content_width f64, author_rules []&css.CSSRule) f64 {
	id := css.property_id_from_string('text-indent') or { return 0 }
	return resolve_length_token(element, css.cascaded_value_with_ua(element, id, author_rules),
		content_width, author_rules)
}

// The uniform border-radius (top-left corner's horizontal radius) resolved to px. `%` is of the
// `basis` (the border-box width). FIXME: per-corner and separate x/y radii aren't modeled — the first
// token of the top-left corner is used for all corners.
fn resolve_border_radius(element &dom.Element, basis f64, author_rules []&css.CSSRule) f64 {
	id := css.property_id_from_string('border-top-left-radius') or { return 0 }
	value := css.cascaded_value_with_ua(element, id, author_rules)
	first := value.trim_space().split(' ')[0] // a corner may be "<x> <y>"; use the x radius
	return resolve_length_token(element, first, basis, author_rules)
}

// Split `s` on `sep`, keeping parenthesized groups (e.g. `rgb(0, 0, 0)`) intact and trimming/dropping
// empty pieces. Used to tokenize a `box-shadow` value without breaking its color function.
fn split_top_level(s string, sep u8) []string {
	mut tokens := []string{}
	mut depth := 0
	mut cur := []u8{}
	for c in s {
		if c == `(` {
			depth++
		} else if c == `)` && depth > 0 {
			depth--
		}
		if c == sep && depth == 0 {
			tokens << cur.bytestr().trim_space()
			cur = []u8{}
		} else {
			cur << c
		}
	}
	tokens << cur.bytestr().trim_space()
	return tokens.filter(it != '')
}

// Whether `token` is a length/number (starts with a digit or sign/dot) rather than a color (which
// starts with a letter or `#`). A clean discriminator for box-shadow's mixed token list.
fn is_length_token(token string) bool {
	if token.len == 0 {
		return false
	}
	c := token[0]
	return c == `-` || c == `+` || c == `.` || (c >= `0` && c <= `9`)
}

// Parse `element`'s `box-shadow` (first shadow only) to a resolved BoxShadow, or none when it is
// `none`/absent/unparseable. Tokens: <offset-x> <offset-y> [<blur>] [<spread>] and a <color>;
// `inset` is ignored. FIXME: only the first shadow of a comma list; inset shadows aren't modeled.
fn parse_box_shadow(element &dom.Element, author_rules []&css.CSSRule) ?BoxShadow {
	id := css.property_id_from_string('box-shadow') or { return none }
	value := css.cascaded_value_with_ua(element, id, author_rules).trim_space()
	if value == '' || value == 'none' {
		return none
	}
	first := split_top_level(value, `,`)[0] // the first shadow of the list
	mut lengths := []f64{}
	mut color := css.Color{0, 0, 0, 255} // default to opaque black
	for token in split_top_level(first, ` `) {
		if token == 'inset' {
			continue // inset shadows aren't modeled
		}
		if is_length_token(token) {
			lengths << resolve_length_token(element, token, 0.0, author_rules)
		} else if c := css.parse_color_string(token) {
			color = c
		}
	}
	if lengths.len < 2 {
		return none // need at least offset-x and offset-y
	}
	return BoxShadow{
		offset_x: lengths[0]
		offset_y: lengths[1]
		blur:     if lengths.len > 2 { lengths[2] } else { 0.0 }
		spread:   if lengths.len > 3 { lengths[3] } else { 0.0 }
		color:    color
	}
}

// A resolved `linear-gradient` background image. The direction is baked into a gradient vector in
// objectBoundingBox fractions (0..1): (`x1`,`y1`)->(`x2`,`y2`). `colors` are the stop colors, spaced
// evenly.
pub struct LinearGradient {
pub:
	// A linear gradient's vector (objectBoundingBox fractions); unused when `radial`.
	x1     f64
	y1     f64
	x2     f64
	y2     f64
	colors []css.Color
	radial bool // a `radial-gradient` (centered, farthest-corner) rather than a linear one
}

// The evenly-spaced stop colors of a comma-separated gradient `args` list. The color is the first
// paren-aware token of each arg (any stop position is ignored). Returns none when fewer than 2 parse.
fn parse_gradient_stops(args []string) ?[]css.Color {
	mut colors := []css.Color{}
	for arg in args {
		tokens := split_top_level(arg, ` `)
		if tokens.len == 0 {
			continue
		}
		if c := css.parse_color_string(tokens[0]) {
			colors << c
		}
	}
	if colors.len < 2 {
		return none
	}
	return colors
}

// Parse a `linear-gradient(...)` value: an optional leading `to <side>` direction (the four sides;
// default `to bottom`) followed by 2+ comma-separated color stops (stop positions are ignored — the
// stops are spaced evenly). Returns none when the value isn't a parseable linear gradient.
// FIXME: angles, corner directions, explicit stop positions, and conic gradients aren't modeled.
fn parse_linear_gradient(value string) ?LinearGradient {
	v := value.trim_space()
	if !v.starts_with('linear-gradient(') || !v.ends_with(')') {
		return none
	}
	mut args := split_top_level(v['linear-gradient('.len..v.len - 1], `,`)
	if args.len < 2 {
		return none
	}
	// Direction (default top -> bottom).
	mut x1, mut y1, mut x2, mut y2 := 0.0, 0.0, 0.0, 1.0
	first := args[0].trim_space().to_lower()
	if first.starts_with('to ') {
		match first {
			'to right' { x1, y1, x2, y2 = 0.0, 0.0, 1.0, 0.0 }
			'to left' { x1, y1, x2, y2 = 1.0, 0.0, 0.0, 0.0 }
			'to top' { x1, y1, x2, y2 = 0.0, 1.0, 0.0, 0.0 }
			else { x1, y1, x2, y2 = 0.0, 0.0, 0.0, 1.0 } // 'to bottom' and corners (FIXME) -> down
		}
		args = args[1..]
	}
	colors := parse_gradient_stops(args)?
	return LinearGradient{
		x1:     x1
		y1:     y1
		x2:     x2
		y2:     y2
		colors: colors
	}
}

// Parse a `radial-gradient(...)` value: an optional leading shape/size/position (ignored — rendered
// centered, farthest-corner) followed by 2+ color stops. Returns none when it isn't a radial gradient.
// FIXME: shape (circle/ellipse), size, and position are ignored; explicit stop positions too.
fn parse_radial_gradient(value string) ?LinearGradient {
	v := value.trim_space()
	if !v.starts_with('radial-gradient(') || !v.ends_with(')') {
		return none
	}
	mut args := split_top_level(v['radial-gradient('.len..v.len - 1], `,`)
	if args.len < 2 {
		return none
	}
	// If the first arg isn't a color, it's the shape/size/position configuration — skip it.
	first_tokens := split_top_level(args[0], ` `)
	mut first_is_color := false
	if first_tokens.len > 0 {
		if _ := css.parse_color_string(first_tokens[0]) {
			first_is_color = true
		}
	}
	if !first_is_color {
		args = args[1..]
	}
	colors := parse_gradient_stops(args)?
	return LinearGradient{
		colors: colors
		radial: true
	}
}

// The `linear-gradient`/`radial-gradient` background image of `element`, or none when background-image
// isn't a gradient.
fn parse_background_gradient(element &dom.Element, author_rules []&css.CSSRule) ?LinearGradient {
	id := css.property_id_from_string('background-image') or { return none }
	value := css.cascaded_value_with_ua(element, id, author_rules)
	if g := parse_linear_gradient(value) {
		return g
	}
	return parse_radial_gradient(value)
}

// A word of inline content with its own measured metrics, taken from the element it comes from — so
// a nested inline element with its own font-size measures its text at that size.
struct InlineWord {
	text        string
	width       f64 // rune count × 0.5em of the word's font (or an atomic box's margin-box width)
	space_after f64 // the space following this word (~0.5em of its font)
	height      f64 // this word's line-height contribution (or an atomic box's margin-box height)
	color       css.Color // this word's computed text color
	decoration  string = 'none' // this word's computed text-decoration-line
	// For an atomic inline (an `inline-block`), the laid-out box (at margin-box origin (0,0)); the item
	// occupies `width`×`height` on the line and is painted as its own box rather than as text.
	box ?BlockBox
}

// Gather a block's inline content as segments of styled words, split at `<br>` and (when
// `preserve_newlines`) at newlines. Each word is measured with the font/line-height of the element it
// comes from. `display: none` and out-of-flow descendants contribute nothing. The result always has
// at least one (possibly empty) segment.
fn collect_inline_segments(element &dom.Element, preserve_newlines bool, containing_width f64, author_rules []&css.CSSRule) [][]InlineWord {
	mut segments := [[]InlineWord{}]
	append_inline_words(element, preserve_newlines, containing_width, author_rules, mut segments)
	return segments
}

fn append_inline_words(element &dom.Element, preserve_newlines bool, containing_width f64, author_rules []&css.CSSRule, mut segments [][]InlineWord) {
	display_id := css.property_id_from_string('display') or { return }
	glyph_width := 0.5 * css.computed_font_size_px(element, author_rules)
	line_height := css.computed_line_height_px(element, author_rules)
	color := css.computed_color(element, css.property_id_from_string('color') or { return },
		author_rules) or { css.Color{0, 0, 0, 255} }
	// `text-transform` (inherited) upper/lower/capitalizes this element's own text runs.
	text_transform := css.cascaded_value_with_ua(element, css.property_id_from_string('text-transform') or {
		return
	}, author_rules)
	// `text-decoration-line` (inherited in this port's metadata, matching the decorating-box
	// propagation) underlines/strikes/overlines this element's text runs.
	decoration := css.cascaded_value_with_ua(element, css.property_id_from_string('text-decoration-line') or {
		return
	}, author_rules)
	// `letter-spacing`/`word-spacing` (both inherited, `normal` = 0): letter-spacing widens each glyph
	// advance; word-spacing widens the inter-word gap.
	letter_spacing := resolve_spacing(element, 'letter-spacing', author_rules)
	word_spacing := resolve_spacing(element, 'word-spacing', author_rules)
	for child in element.as_node().children_as_vector() {
		if child.is_text() {
			data := unsafe { &dom.Text(child) }.data()
			parts := if preserve_newlines { data.split('\n') } else { [data] }
			for i, part in parts {
				if i > 0 {
					segments << []InlineWord{} // a preserved newline starts a new segment
				}
				for word in part.fields() {
					transformed := apply_text_transform(word, text_transform)
					runes := transformed.runes().len
					segments[segments.len - 1] << InlineWord{
						text:        transformed
						width:       f64(runes) * (glyph_width + letter_spacing)
						space_after: glyph_width + word_spacing
						height:      line_height
						color:       color
						decoration:  decoration
					}
				}
			}
		} else if el := child.as_element() {
			display := css.cascaded_value_with_ua(el, display_id, author_rules)
			if display == 'none' {
				continue
			}
			if is_absolutely_positioned(position_value(el, author_rules)) || is_floating(el, author_rules) {
				continue // out of flow — its text is its own content, not the container's
			}
			if el.local_name() == 'br' {
				segments << []InlineWord{} // forced line break starts a new segment
			} else if display == 'inline-block' {
				// An atomic inline: lay the box out (auto width -> shrink to max-content) and add it as a
				// single item that occupies its margin box on the line.
				forced := if size_is_auto(el, 'width', author_rules) {
					?f64(intrinsic_content_width(el, author_rules, false))
				} else {
					?f64(none)
				}
				box := layout_block_impl(el, 0, 0, containing_width, forced, author_rules)
				segments[segments.len - 1] << InlineWord{
					width:       box.margin_box_width()
					space_after: glyph_width
					height:      box.margin_box_height()
					color:       color
					box:         box
				}
			} else {
				append_inline_words(el, preserve_newlines, containing_width, author_rules, mut segments)
			}
		}
	}
}

// Apply the CSS `text-transform` to a rendered text run. `uppercase`/`lowercase` map the whole run;
// `capitalize` uppercases the first character of the run (each word arrives here separately, so this
// capitalizes every word). FIXME: `capitalize` should target the first *typographic letter unit*
// (skipping leading punctuation), and full-width/full-size-kana are not modeled.
fn apply_text_transform(text string, transform string) string {
	return match transform {
		'uppercase' { text.to_upper() }
		'lowercase' { text.to_lower() }
		'capitalize' { capitalize_first_letter(text) }
		else { text } // 'none' and unmodeled values
	}
}

// Uppercase the first character (rune) of `word`, leaving the rest unchanged.
fn capitalize_first_letter(word string) string {
	if word.len == 0 {
		return word
	}
	runes := word.runes()
	return runes[0].str().to_upper() + runes[1..].string()
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
// Returns the text line boxes AND the atomic inline (`inline-block`) boxes, both positioned in the
// content-box local frame; the caller translates them to the content-box top and paints the boxes as
// children.
fn layout_inline_lines(element &dom.Element, content_x f64, content_width f64, float_bands []FloatBand, author_rules []&css.CSSRule) ([]TextLine, []BlockBox) {
	white_space := css.cascaded_value_with_ua(element, css.property_id_from_string('white-space') or {
		return []TextLine{}, []BlockBox{}
	}, author_rules)

	segments := collect_inline_segments(element, white_space_preserves_newlines(white_space),
		content_width, author_rules)
	if segments.len == 1 && segments[0].len == 0 {
		return []TextLine{}, []BlockBox{} // no inline content at all
	}

	block_line_height := css.computed_line_height_px(element, author_rules)
	align := css.cascaded_value_with_ua(element, css.property_id_from_string('text-align') or {
		return []TextLine{}, []BlockBox{}
	}, author_rules)
	wraps := white_space_wraps(white_space)
	// `text-indent` (inherited) indents the start of the *first* line box (%: of the content width).
	text_indent := resolve_text_indent(element, content_width, author_rules)

	mut lines := []TextLine{}
	mut inline_boxes := []BlockBox{}
	mut y := 0.0
	mut first_line := true
	for segment in segments {
		if segment.len == 0 {
			mut left, right := line_bounds(y, block_line_height, float_bands, content_x, content_width)
			if first_line {
				left += text_indent
			}
			lines << TextLine{
				x:      aligned_line_x(left, right - left, 0.0, align)
				y:      y
				width:  0.0
				height: block_line_height
			}
			first_line = false
			y += block_line_height
			continue
		}
		mut i := 0
		for i < segment.len {
			mut left, mut right := line_bounds(y, segment[i].height, float_bands, content_x,
				content_width)
			if first_line {
				left += text_indent // indent the first line's content start
			}
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
				if b := segment[k].box {
					// An atomic inline (inline-block): place its box (margin-box top-left at the item's
					// position, top-aligned to the line), painted as its own box rather than as text.
					inline_boxes << translate_block(b, fragment_x, y)
				} else {
					fragments << TextFragment{
						x:          fragment_x
						y:          y
						width:      segment[k].width
						height:     segment[k].height
						text:       segment[k].text
						color:      segment[k].color
						decoration: segment[k].decoration
					}
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
			first_line = false
			i = j
			y += line_height
		}
	}
	return lines, inline_boxes
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
	// A calc() width, resolving any `%` inside against the containing width.
	if calc := css.computed_calc_px(element, width_id, containing_width, author_rules) {
		return non_negative(if border_box { calc - border_padding_lr } else { calc })
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

// Clamp a corner radius so it never exceeds half of the smaller box dimension (a larger specified
// radius is reduced proportionally to that limit, per CSS border-radius overflow handling).
fn clamp_radius(radius f64, width f64, height f64) f64 {
	if radius <= 0 {
		return 0
	}
	limit := (if width < height { width } else { height }) / 2.0
	return if radius > limit { limit } else { radius }
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
	display := css.cascaded_value_with_ua(element, display_id, author_rules)
	if display == 'flow-root' || display == 'flex' || display == 'inline-flex' {
		return true // a flow-root or flex container establishes an independent formatting context
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

// A px length token (`10px`, `-4px`, `0`) as f64. FIXME: only px is supported here (no %/em/calc).
fn parse_px_length(token string) f64 {
	trimmed := token.trim_space()
	if trimmed.ends_with('px') {
		return trimmed#[..-2].trim_space().f64()
	}
	if trimmed == '0' {
		return 0.0
	}
	return 0.0
}

// The `transform: translate(...)` offset (dx, dy) in px for `element`, or (0, 0) for `none`/other
// transforms. Handles translate(x[, y]) / translateX(x) / translateY(y). Like relative positioning,
// this offsets the box (and its subtree) visually without affecting the flow.
//
// FIXME: only px translation is modelled — no %, scale/rotate/matrix, or transform-origin.
fn transform_translate(element &dom.Element, author_rules []&css.CSSRule) (f64, f64) {
	id := css.property_id_from_string('transform') or { return 0.0, 0.0 }
	value := css.cascaded_value_with_ua(element, id, author_rules)
	if value.starts_with('translate(') && value.ends_with(')') {
		args := value['translate('.len..value.len - 1].split(',')
		dx := parse_px_length(args[0])
		dy := if args.len > 1 { parse_px_length(args[1]) } else { 0.0 }
		return dx, dy
	}
	if value.starts_with('translateX(') && value.ends_with(')') {
		return parse_px_length(value['translateX('.len..value.len - 1]), 0.0
	}
	if value.starts_with('translateY(') && value.ends_with(')') {
		return 0.0, parse_px_length(value['translateY('.len..value.len - 1])
	}
	return 0.0, 0.0
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
// Lay out `element` as a block box within a containing block `containing_width` px wide, at
// margin-box origin (`x`, `y`).
pub fn layout_block(element &dom.Element, x f64, y f64, containing_width f64, author_rules []&css.CSSRule) BlockBox {
	return layout_block_impl(element, x, y, containing_width, none, author_rules)
}

// Core block layout. When `forced_content_width` is set it overrides the computed content width —
// used to give a flex item its shrink-to-fit main size instead of filling the line.
fn layout_block_impl(element &dom.Element, x f64, y f64, containing_width f64, forced_content_width ?f64, author_rules []&css.CSSRule) BlockBox {
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
	// A flex item passes a forced width (its shrink-to-fit / main size) that overrides the box model.
	tentative_width := if fw := forced_content_width {
		fw
	} else {
		used_content_width(element, containing_width, margin_left_fixed + margin_right_fixed,
			border_padding_lr, border_box, author_rules)
	}
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
	// `transform: translate(...)` offsets the box (and its subtree) like relative positioning, without
	// disturbing the flow.
	transform_x, transform_y := transform_translate(element, author_rules)
	content_x := x + margin.left + border.left + padding.left + rel_x + transform_x

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
	mut local_lines := []TextLine{}
	mut content_height := 0.0
	mut first_child_outer_top := 0.0
	mut last_child_outer_bottom := 0.0
	mut has_children := false

	if is_flex_row(element, author_rules) {
		// FLEX (row): lay items along the main axis from the content-left, packed by margin box; the
		// container's content height is the tallest item's margin box. Flex containers establish a
		// formatting context (no margin collapse). Each item's main size is its flex base size adjusted
		// by flex-grow/shrink over the free space; `justify-content` distributes any leftover; `gap`
		// spaces items; `align-items`/`align-self` align each on the cross axis.
		// FIXME: no wrap, no row-reverse/column (those fall to block flow).
		gap_main := flex_column_gap(element, author_rules)
		items := flex_item_elements(element.as_node(), author_rules)
		// Flex base sizes and outer edges, then the free space to grow/shrink over.
		mut bases := []f64{}
		mut total_used := if items.len > 1 { f64(items.len - 1) * gap_main } else { 0.0 }
		for item in items {
			base := flex_base_size(item, width, author_rules)
			bases << base
			total_used += base + horizontal_edges(item, width, author_rules)
		}
		finals := resolve_flex_main_sizes(items, bases, width - total_used, author_rules)
		// Lay each item out at its final main size, packed along the row (gap between adjacent items).
		mut cursor := 0.0
		mut item_boxes := []BlockBox{}
		for i, item in items {
			if i > 0 {
				cursor += gap_main
			}
			ib := layout_block_impl(item, content_x + cursor, 0.0, width, finals[i], author_rules)
			cursor += ib.margin_box_width()
			if ib.margin_box_height() > content_height {
				content_height = ib.margin_box_height()
			}
			item_boxes << ib
		}
		// Main axis: distribute free space per justify-content. Cross axis: align each item within the
		// container's cross size (the tallest item / content height) per align-items (or its align-self).
		leading, gap := justify_offsets(justify_content_value(element, author_rules), width - cursor,
			item_boxes.len)
		container_align := align_items_value(element, author_rules)
		// Align within the container's cross size: its explicit height if set, else the tallest item.
		cross_size := align_cross_size(element, content_height, border, padding, border_box,
			author_rules)
		for i, ib in item_boxes {
			align := effective_align_self(items[i], container_align, author_rules)
			mut item := ib
			// `align-items/self: stretch` grows an auto-height item's box to the line's cross size
			// (its content stays top-positioned, so no re-layout is needed).
			if align == 'stretch' && size_is_auto(items[i], 'height', author_rules) {
				item.height = flex_stretched_content_height(item, cross_size)
			}
			cross := cross_axis_offset(align, cross_size, item.margin_box_height())
			local_children << translate_block(item, leading + f64(i) * gap, cross)
		}
		has_children = item_boxes.len > 0
	} else if is_flex_column(element, author_rules) {
		// FLEX (column): stack items along the vertical MAIN axis. The cross axis is horizontal, so an
		// item's width fills the container for `align: stretch` (block sizing) and shrink-to-fits
		// otherwise; `justify-content` distributes vertical free space; `row-gap` spaces items;
		// `align-items`/`align-self` align items horizontally. Reuses justify_offsets (main) and
		// cross_axis_offset (cross) with the axes swapped.
		// FIXME: no main-axis flex-grow/shrink (items keep their natural heights), no wrap.
		gap_main := flex_row_gap(element, author_rules)
		items := flex_item_elements(element.as_node(), author_rules)
		container_align := align_items_value(element, author_rules)
		mut item_boxes := []BlockBox{}
		mut aligns := []string{}
		mut total_main := if items.len > 1 { f64(items.len - 1) * gap_main } else { 0.0 }
		for item in items {
			align := effective_align_self(item, container_align, author_rules)
			aligns << align
			// Cross size (width): stretch fills the container; a definite width is used as-is; otherwise
			// (non-stretch, auto width) the item shrink-to-fits its content.
			forced := if align != 'stretch' && size_is_auto(item, 'width', author_rules) {
				?f64(flex_content_base(item, width, author_rules))
			} else {
				?f64(none)
			}
			ib := layout_block_impl(item, content_x, 0.0, width, forced, author_rules)
			total_main += ib.margin_box_height()
			item_boxes << ib
		}
		// Main axis (vertical): distribute free space up to the container's explicit height, if any.
		main_size := align_cross_size(element, total_main, border, padding, border_box, author_rules)
		leading, gap := justify_offsets(justify_content_value(element, author_rules), main_size - total_main,
			item_boxes.len)
		mut cursor := 0.0
		for i, ib in item_boxes {
			if i > 0 {
				cursor += gap_main
			}
			cross := cross_axis_offset(aligns[i], width, ib.margin_box_width()) // horizontal alignment
			local_children << translate_block(ib, cross, cursor + leading + f64(i) * gap)
			cursor += ib.margin_box_height()
		}
		content_height = total_main
		has_children = item_boxes.len > 0
	} else {
		// BLOCK FLOW: lay children out in a LOCAL frame whose origin is this box's content-box top-left.
		// Vertical margins collapse (CSS 2.1 §8.3.1) using each child's OUTER (collapsed) margins.
		mut flow_bottom := 0.0 // border-box bottom of the last placed child, in the local frame
		mut prev_outer_bottom := 0.0
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
			clear_bottom := clearance_bottom(child, left_floats_bottom, right_floats_bottom,
				author_rules)
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
		// plus that child's outer bottom margin only when it stays inside the box. A box with no block
		// children lays out inline line boxes (also in the local frame).
		if has_children {
			content_height = if bottom_margin_contained {
				flow_bottom + last_child_outer_bottom
			} else {
				flow_bottom
			}
		} else {
			lines, inline_boxes := layout_inline_lines(element, content_x, width, float_bands,
				author_rules)
			local_lines = lines.clone()
			// Atomic inline (inline-block) boxes join the children so they are painted and measured.
			local_children << inline_boxes
			for line in local_lines {
				if line.y + line.height > content_height {
					content_height = line.y + line.height
				}
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
	// offset / transform translate, which don't participate in the flow computed above). Shift the
	// children from the local frame (content-box top = 0) to the real content-box top.
	content_top := y + outer_top_margin + border.top + padding.top + rel_y + transform_y
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
	// Opacity (0..1) — this box's own; the display list accumulates it down the tree.
	mut opacity := css.cascaded_value_with_ua(element, css.property_id_from_string('opacity') or {
		return BlockBox{}
	}, author_rules).f64()
	if opacity < 0.0 {
		opacity = 0.0
	} else if opacity > 1.0 {
		opacity = 1.0
	}
	// `visibility` (inherited): a hidden box still occupies space but paints nothing.
	visible := css.cascaded_value_with_ua(element, css.property_id_from_string('visibility') or {
		return BlockBox{}
	}, author_rules) == 'visible'

	// A `display: list-item` box gets a marker (bullet or ordinal) hanging to the left of its content.
	mut lines_with_marker := lines.clone()
	if marker_line := list_marker_line(element, content_x, content_top, text_color, author_rules) {
		lines_with_marker.prepend(marker_line)
	}

	// border-radius (% is of the border-box width) rounds the background/border box when painted.
	border_box_width := width + padding.left + padding.right + border.left + border.right
	border_radius := resolve_border_radius(element, border_box_width, author_rules)

	// Outline (painted outside the border box, no effect on layout): width, offset, and color
	// (outline-color defaults to `currentColor`, which resolves to the text color).
	outline_width := used_outline_width(element, author_rules)
	outline_offset := css.computed_length_px(element, css.property_id_from_string('outline-offset') or {
		return BlockBox{}
	}, author_rules) or { 0.0 }
	outline_color := css.computed_color(element, css.property_id_from_string('outline-color') or {
		return BlockBox{}
	}, author_rules) or { text_color }
	// box-shadow (first shadow only) — a drop shadow painted behind the box.
	mut shadow := ?BoxShadow(none)
	if s := parse_box_shadow(element, author_rules) {
		shadow = s
	}
	// A linear-gradient background image (painted over the background color).
	mut background_gradient := ?LinearGradient(none)
	if g := parse_background_gradient(element, author_rules) {
		background_gradient = g
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
		z_index:             z_index
		background_color:    background_color
		text_color:          text_color
		border_color:        border_color
		border_radius:       border_radius
		outline_width:       outline_width
		outline_offset:      outline_offset
		outline_color:       outline_color
		shadow:              shadow
		background_gradient: background_gradient
		opacity:             opacity
		visible:             visible
		node_id:             i64(element.as_node().unique_id())
		children:            children
		lines:               lines_with_marker
	}
}
