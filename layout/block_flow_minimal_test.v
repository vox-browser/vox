module layout

import dom
import css

const html_ns = 'http://www.w3.org/1999/xhtml'

fn styled(doc &dom.Document, tag string, style string) &dom.Element {
	mut e := doc.create_element_ns(html_ns, tag) or { panic('${err}') }
	if style != '' {
		e.set_attribute_value('style', style)
	}
	return e
}

// A root `width: 200px` with two block children: one `height: 30px` (width auto -> 200),
// one `width: 50%; height: 20px` (width 100). The root has `height: auto` so it takes the
// stacked content height (30 + 20 = 50). Children stack vertically at x = 0.
fn test_block_flow_widths_heights_and_stacking() {
	doc := dom.Document.create(dom.url_about_blank())
	root := styled(doc, 'div', 'width: 200px')
	first := styled(doc, 'div', 'height: 30px')
	second := styled(doc, 'div', 'width: 50%; height: 20px')
	mut root_node := root.as_node()
	root_node.append_child(first.as_node()) or { panic('${err}') }
	root_node.append_child(second.as_node()) or { panic('${err}') }

	no_author := []&css.CSSRule{}
	box := layout_block(root, 0, 0, 800, no_author)

	assert box.tag_name == 'div'
	assert box.width == 200.0 // explicit px, not the 800 available width
	assert box.height == 50.0 // auto -> sum of children (30 + 20)
	assert box.children.len == 2

	assert box.children[0].width == 200.0 // auto -> fills the 200px containing block
	assert box.children[0].height == 30.0
	assert box.children[0].x == 0.0
	assert box.children[0].y == 0.0

	assert box.children[1].width == 100.0 // 50% of the 200px containing block
	assert box.children[1].height == 20.0
	assert box.children[1].y == 30.0 // stacked below the first child
}

// A leaf block with no explicit height and no children has content height 0.
fn test_block_flow_empty_leaf_height_zero() {
	doc := dom.Document.create(dom.url_about_blank())
	leaf := styled(doc, 'div', 'width: 120px')
	box := layout_block(leaf, 0, 0, 800, []&css.CSSRule{})
	assert box.width == 120.0
	assert box.height == 0.0
	assert box.children.len == 0
}

// em widths resolve through the css computed-value layer: 10em at the default 16px font-size = 160px.
fn test_block_flow_em_width_resolves() {
	doc := dom.Document.create(dom.url_about_blank())
	el := styled(doc, 'div', 'width: 10em')
	box := layout_block(el, 0, 0, 800, []&css.CSSRule{})
	assert box.width == 160.0
}

// Box model on an explicit-width box: content origin is inset by margin+border+padding, and the
// margin box surrounds it. margin 20, border 5 (solid, so it counts), padding 10, width 100.
fn test_block_box_model_explicit_width() {
	doc := dom.Document.create(dom.url_about_blank())
	el := styled(doc, 'div', 'width: 100px; padding: 10px; border: 5px solid; margin: 20px')
	box := layout_block(el, 0, 0, 800, []&css.CSSRule{})

	assert box.margin.top == 20.0
	assert box.border.left == 5.0
	assert box.padding.right == 10.0
	assert box.width == 100.0 // explicit content width
	assert box.x == 35.0 // 20 margin + 5 border + 10 padding
	assert box.y == 35.0
	assert box.height == 0.0 // no children
	assert box.margin_box_height() == 70.0 // 20+5+10+0+10+5+20
	assert box.margin_box_width() == 170.0 // 20+5+10+100+10+5+20
}

// Box model with width:auto: content width fills what's left after margins, borders, padding.
fn test_block_box_model_auto_width_subtracts_edges() {
	doc := dom.Document.create(dom.url_about_blank())
	el := styled(doc, 'div', 'padding: 10px; border: 5px solid; margin: 20px')
	box := layout_block(el, 0, 0, 800, []&css.CSSRule{})
	assert box.width == 730.0 // 800 - (40 margin + 10 border + 20 padding)
	assert box.x == 35.0
}

// Vertical stacking with parent/child margin collapsing: the root has no border/padding, so the
// first child's 10px top margin collapses THROUGH the root (it appears above the root's border box
// rather than inside), and the root's bottom likewise collapses with... the second child has no
// bottom margin, so nothing there.
fn test_block_box_model_stacking_with_margins() {
	doc := dom.Document.create(dom.url_about_blank())
	root := styled(doc, 'div', 'width: 200px')
	first := styled(doc, 'div', 'height: 30px; margin: 10px')
	second := styled(doc, 'div', 'height: 20px')
	mut root_node := root.as_node()
	root_node.append_child(first.as_node()) or { panic('${err}') }
	root_node.append_child(second.as_node()) or { panic('${err}') }

	box := layout_block(root, 0, 0, 800, []&css.CSSRule{})
	assert box.y == 10.0 // root pushed down by the child's collapsed-through 10px top margin
	assert box.outer_top_margin == 10.0 // that margin becomes the root's outer top margin
	assert box.children[0].x == 10.0 // margin-left (horizontal margins never collapse)
	assert box.children[0].y == 10.0 // sits at the root's content top (its top margin collapsed out)
	assert box.children[0].width == 180.0 // 200 - 20 (auto width minus margins)
	assert box.children[0].margin_box_height() == 50.0 // 10 + 30 + 10
	assert box.children[1].y == 50.0 // 40 (first's border bottom) + 10 (first's bottom margin)
	assert box.children[1].width == 200.0
	assert box.height == 60.0 // content: 30 + 10 gap + 20; first's top margin collapsed out
}

// Border width is 0 unless a border-style is set; keywords resolve on the thin/medium/thick scale.
fn test_block_border_style_gating_and_keywords() {
	doc := dom.Document.create(dom.url_about_blank())
	no_style := styled(doc, 'div', 'border-top-width: 5px')
	assert layout_block(no_style, 0, 0, 800, []&css.CSSRule{}).border.top == 0.0 // style defaults to none

	with_style := styled(doc, 'div', 'border-top-width: 5px; border-top-style: solid')
	assert layout_block(with_style, 0, 0, 800, []&css.CSSRule{}).border.top == 5.0

	thick := styled(doc, 'div', 'border: thick solid')
	assert layout_block(thick, 0, 0, 800, []&css.CSSRule{}).border.top == 5.0 // thick = 5px

	medium := styled(doc, 'div', 'border: solid')
	assert layout_block(medium, 0, 0, 800, []&css.CSSRule{}).border.top == 3.0 // medium (initial) = 3px
}

// Adjoining sibling margins collapse to their maximum (not their sum): a 30px bottom margin meeting
// a 20px top margin yields a 30px gap, so the second child's border-box top is 30px below the first.
fn test_block_sibling_margin_collapse_positive() {
	doc := dom.Document.create(dom.url_about_blank())
	root := styled(doc, 'div', 'width: 200px')
	first := styled(doc, 'div', 'height: 40px; margin-bottom: 30px')
	second := styled(doc, 'div', 'height: 60px; margin-top: 20px')
	mut root_node := root.as_node()
	root_node.append_child(first.as_node()) or { panic('${err}') }
	root_node.append_child(second.as_node()) or { panic('${err}') }

	box := layout_block(root, 0, 0, 800, []&css.CSSRule{})
	assert box.children[0].y == 0.0
	// gap between first's bottom border edge (40) and second's top border edge is max(30, 20) = 30.
	assert box.children[1].y == 70.0 // 40 + 30 (collapsed), not 40 + 30 + 20 = 90
	assert box.height == 130.0 // 40 + 30 + 60 (no trailing margin)
}

// A negative margin offsets a positive one: max(positive) + min(negative) = 30 + (-50) = -20.
fn test_block_sibling_margin_collapse_negative() {
	doc := dom.Document.create(dom.url_about_blank())
	root := styled(doc, 'div', 'width: 200px')
	first := styled(doc, 'div', 'height: 40px; margin-bottom: 30px')
	second := styled(doc, 'div', 'height: 60px; margin-top: -50px')
	mut root_node := root.as_node()
	root_node.append_child(first.as_node()) or { panic('${err}') }
	root_node.append_child(second.as_node()) or { panic('${err}') }

	box := layout_block(root, 0, 0, 800, []&css.CSSRule{})
	// collapsed gap = 30 + (-50) = -20, so the second child overlaps upward.
	assert box.children[1].y == 20.0 // 40 + (-20)
	assert box.height == 80.0 // 40 + (-20) + 60
}

// collapse_margins directly: max positive + most negative.
fn test_collapse_margins_helper() {
	assert collapse_margins([30.0, 20.0]) == 30.0
	assert collapse_margins([30.0, -50.0]) == -20.0
	assert collapse_margins([-10.0, -30.0]) == -30.0
	assert collapse_margins([-10.0, 20.0]) == 10.0
	assert collapse_margins([]f64{}) == 0.0
}

// display:none and inline-level children generate no block box; block-level ones (block, list-item)
// do. The skipped children's geometry must not leak into the parent.
fn test_display_none_and_inline_children_skipped() {
	doc := dom.Document.create(dom.url_about_blank())
	root := styled(doc, 'div', 'width: 200px')
	visible := styled(doc, 'div', 'height: 10px')
	hidden := styled(doc, 'div', 'display: none; height: 999px')
	inline := styled(doc, 'span', 'height: 999px') // <span> is inline via the UA sheet
	item := styled(doc, 'li', 'height: 20px') // list-item is block-level
	mut rn := root.as_node()
	rn.append_child(visible.as_node()) or { panic('${err}') }
	rn.append_child(hidden.as_node()) or { panic('${err}') }
	rn.append_child(inline.as_node()) or { panic('${err}') }
	rn.append_child(item.as_node()) or { panic('${err}') }

	box := layout_block(root, 0, 0, 800, []&css.CSSRule{})
	assert box.children.len == 2 // only the visible div and the li
	assert box.children[0].tag_name == 'div'
	assert box.children[1].tag_name == 'li'
	assert box.children[1].y == 10.0 // li stacks directly under the 10px div
	assert box.height == 30.0 // 10 + 20; none/inline children contribute nothing
}

// is_block_level_display classification.
fn test_is_block_level_display() {
	assert is_block_level_display('block')
	assert is_block_level_display('list-item')
	assert is_block_level_display('flow-root')
	assert is_block_level_display('flex')
	assert !is_block_level_display('none')
	assert !is_block_level_display('inline')
	assert !is_block_level_display('inline-block')
}

// A text-only block gets a height from line count x line-height. "Hello" = 5 glyphs at 0.5*20 =
// 10px each = 50px < 200px content width -> 1 line * 30px line-height.
fn test_inline_text_single_line_height() {
	doc := dom.Document.create(dom.url_about_blank())
	el := styled(doc, 'div', 'width: 200px; font-size: 20px; line-height: 30px')
	mut n := el.as_node()
	n.append_child(doc.create_text_node('Hello').as_node()) or { panic('${err}') }

	box := layout_block(el, 0, 0, 800, []&css.CSSRule{})
	assert box.height == 30.0
	assert box.children.len == 0 // text isn't a block box
}

// Text wraps at WORD boundaries: six 4-char words (40px each) + spaces (10px) over a 100px line fit
// two per line ("word word" = 40+10+40 = 90 <= 100; a third would be 140) -> 3 lines * 30px = 90px.
fn test_inline_text_wraps_to_multiple_lines() {
	doc := dom.Document.create(dom.url_about_blank())
	el := styled(doc, 'div', 'width: 100px; font-size: 20px; line-height: 30px')
	mut n := el.as_node()
	n.append_child(doc.create_text_node('aaaa bbbb cccc dddd eeee ffff').as_node()) or { panic('${err}') }

	box := layout_block(el, 0, 0, 800, []&css.CSSRule{})
	assert box.height == 90.0
}

// A block with block children ignores its own stray text (anonymous-block FIXME): the text does not
// add a line box; height comes from the children.
fn test_block_children_win_over_stray_text() {
	doc := dom.Document.create(dom.url_about_blank())
	root := styled(doc, 'div', 'width: 200px; line-height: 30px')
	mut rn := root.as_node()
	rn.append_child(doc.create_text_node('stray').as_node()) or { panic('${err}') }
	child := styled(doc, 'div', 'height: 25px')
	rn.append_child(child.as_node()) or { panic('${err}') }

	box := layout_block(root, 0, 0, 800, []&css.CSSRule{})
	assert box.children.len == 1
	assert box.height == 25.0 // just the child; stray text contributes no line box
}

// Whitespace-only text collapses to nothing -> no line box -> height 0.
fn test_inline_whitespace_only_is_empty() {
	doc := dom.Document.create(dom.url_about_blank())
	el := styled(doc, 'div', 'width: 200px; line-height: 30px')
	mut n := el.as_node()
	n.append_child(doc.create_text_node('   \n  ').as_node()) or { panic('${err}') }
	box := layout_block(el, 0, 0, 800, []&css.CSSRule{})
	assert box.height == 0.0
}

// line-height: normal approximates 1.2 * font-size.
fn test_inline_normal_line_height() {
	doc := dom.Document.create(dom.url_about_blank())
	el := styled(doc, 'div', 'width: 500px; font-size: 20px') // line-height defaults to normal
	mut n := el.as_node()
	n.append_child(doc.create_text_node('hi').as_node()) or { panic('${err}') }
	box := layout_block(el, 0, 0, 800, []&css.CSSRule{})
	assert box.height == 24.0 // 1.2 * 20
}

// layout_document on an empty document (no root element) returns an empty box.
fn test_layout_document_no_root() {
	doc := dom.Document.create(dom.url_about_blank())
	box := layout_document(doc, 800)
	assert box.tag_name == ''
	assert box.width == 0.0
}

// layout_document over a manually built html>body>div tree: root fills the viewport, body keeps its
// explicit width, the div's height flows through.
fn test_layout_document_manual_root() {
	doc := dom.Document.create(dom.url_about_blank())
	html_el := styled(doc, 'html', '')
	body := styled(doc, 'body', 'width: 300px')
	child := styled(doc, 'div', 'height: 50px')
	mut bn := body.as_node()
	bn.append_child(child.as_node()) or { panic('${err}') }
	mut hn := html_el.as_node()
	hn.append_child(body.as_node()) or { panic('${err}') }
	mut docn := unsafe { &dom.Node(doc) }
	docn.append_child(html_el.as_node()) or { panic('${err}') }

	box := layout_document(doc, 800)
	assert box.tag_name == 'html'
	assert box.width == 800.0 // fills the viewport
	assert box.children.len == 1
	assert box.children[0].tag_name == 'body'
	assert box.children[0].width == 300.0
	assert box.children[0].children[0].height == 50.0
}

// collect_document_author_rules parses each <style> element's text into rules.
fn test_collect_document_author_rules() {
	doc := dom.Document.create(dom.url_about_blank())
	html_el := styled(doc, 'html', '')
	style_el := styled(doc, 'style', '')
	mut sn := style_el.as_node()
	sn.append_child(doc.create_text_node('div { color: red } .x { width: 5px }').as_node()) or {
		panic('${err}')
	}
	mut hn := html_el.as_node()
	hn.append_child(style_el.as_node()) or { panic('${err}') }
	mut docn := unsafe { &dom.Node(doc) }
	docn.append_child(html_el.as_node()) or { panic('${err}') }

	rules := collect_document_author_rules(doc)
	assert rules.len == 2
}

// box-sizing: border-box makes the specified width include padding+border, so the content shrinks.
// width 100, padding 10, border 5 -> content width 100 - 2*(10+5) = 70; border box stays 100.
fn test_box_sizing_border_box_width() {
	doc := dom.Document.create(dom.url_about_blank())
	el := styled(doc, 'div', 'box-sizing: border-box; width: 100px; padding: 10px; border: 5px solid')
	box := layout_block(el, 0, 0, 800, []&css.CSSRule{})
	assert box.width == 70.0 // content
	assert box.margin_box_width() == 100.0 // border box == specified width (no margins here)
}

// content-box (the default) leaves the specified width as the content width.
fn test_box_sizing_content_box_default() {
	doc := dom.Document.create(dom.url_about_blank())
	el := styled(doc, 'div', 'width: 100px; padding: 10px; border: 5px solid')
	box := layout_block(el, 0, 0, 800, []&css.CSSRule{})
	assert box.width == 100.0 // content
	assert box.margin_box_width() == 130.0 // 100 + 2*(10+5)
}

// border-box height subtracts vertical padding+border from the specified height.
fn test_box_sizing_border_box_height() {
	doc := dom.Document.create(dom.url_about_blank())
	el := styled(doc, 'div', 'box-sizing: border-box; height: 100px; padding: 10px; border: 5px solid')
	box := layout_block(el, 0, 0, 800, []&css.CSSRule{})
	assert box.height == 70.0 // 100 - 2*(10+5)
	assert box.margin_box_height() == 100.0 // border box == specified height
}

// A border-box percentage width also has its edges subtracted: 50% of 400 = 200, minus 2*(10+5).
fn test_box_sizing_border_box_percentage() {
	doc := dom.Document.create(dom.url_about_blank())
	el := styled(doc, 'div', 'box-sizing: border-box; width: 50%; padding: 10px; border: 5px solid')
	box := layout_block(el, 0, 0, 400, []&css.CSSRule{})
	assert box.width == 170.0 // 200 - 30
}

// border-box never drives the content width negative when edges exceed the specified size.
fn test_box_sizing_border_box_clamps_to_zero() {
	doc := dom.Document.create(dom.url_about_blank())
	el := styled(doc, 'div', 'box-sizing: border-box; width: 10px; padding: 20px')
	box := layout_block(el, 0, 0, 800, []&css.CSSRule{})
	assert box.width == 0.0 // 10 - 40 clamped
}

// max-width clamps an auto (full-fill) width down: 800 available, max-width 100 -> 100.
fn test_max_width_clamps_auto() {
	doc := dom.Document.create(dom.url_about_blank())
	el := styled(doc, 'div', 'max-width: 100px')
	box := layout_block(el, 0, 0, 800, []&css.CSSRule{})
	assert box.width == 100.0
}

// min-width raises a smaller specified width: width 50, min-width 120 -> 120.
fn test_min_width_raises() {
	doc := dom.Document.create(dom.url_about_blank())
	el := styled(doc, 'div', 'width: 50px; min-width: 120px')
	box := layout_block(el, 0, 0, 800, []&css.CSSRule{})
	assert box.width == 120.0
}

// min-width wins when it crosses max-width (min applied last): width 500, max 100, min 200 -> 200.
fn test_min_width_beats_max_width() {
	doc := dom.Document.create(dom.url_about_blank())
	el := styled(doc, 'div', 'width: 500px; max-width: 100px; min-width: 200px')
	box := layout_block(el, 0, 0, 800, []&css.CSSRule{})
	assert box.width == 200.0
}

// min-height raises an empty box's height: no content, min-height 50 -> 50.
fn test_min_height_raises_empty_box() {
	doc := dom.Document.create(dom.url_about_blank())
	el := styled(doc, 'div', 'min-height: 50px')
	box := layout_block(el, 0, 0, 800, []&css.CSSRule{})
	assert box.height == 50.0
}

// max-height clamps a taller explicit height: height 200, max-height 80 -> 80.
fn test_max_height_clamps() {
	doc := dom.Document.create(dom.url_about_blank())
	el := styled(doc, 'div', 'height: 200px; max-height: 80px')
	box := layout_block(el, 0, 0, 800, []&css.CSSRule{})
	assert box.height == 80.0
}

// max-width percentage resolves against the containing width: 25% of 400 = 100.
fn test_max_width_percentage() {
	doc := dom.Document.create(dom.url_about_blank())
	el := styled(doc, 'div', 'max-width: 25%')
	box := layout_block(el, 0, 0, 400, []&css.CSSRule{})
	assert box.width == 100.0
}

// min/max-width are box-sizing-aware: border-box max-width 100 leaves content 100 - 2*(10+5) = 70.
fn test_min_max_width_border_box_aware() {
	doc := dom.Document.create(dom.url_about_blank())
	el := styled(doc, 'div', 'box-sizing: border-box; max-width: 100px; padding: 10px; border: 5px solid')
	box := layout_block(el, 0, 0, 800, []&css.CSSRule{})
	assert box.width == 70.0
	assert box.margin_box_width() == 100.0 // border box hits the max-width
}

// margin: 0 auto centers a fixed-width block: (800 - 200) / 2 = 300 on each side.
fn test_auto_margins_center_fixed_width() {
	doc := dom.Document.create(dom.url_about_blank())
	el := styled(doc, 'div', 'width: 200px; margin: 0 auto')
	box := layout_block(el, 0, 0, 800, []&css.CSSRule{})
	assert box.margin.left == 300.0
	assert box.margin.right == 300.0
	assert box.x == 300.0 // content origin is centered
	assert box.margin_box_width() == 800.0 // fills the containing block
}

// A single auto margin absorbs the whole remainder: margin-left:auto right-aligns (600 to the left).
fn test_single_auto_margin_right_aligns() {
	doc := dom.Document.create(dom.url_about_blank())
	el := styled(doc, 'div', 'width: 200px; margin-left: auto')
	box := layout_block(el, 0, 0, 800, []&css.CSSRule{})
	assert box.margin.left == 600.0 // 800 - 200
	assert box.margin.right == 0.0
	assert box.x == 600.0
}

// auto margins on an auto-width box collapse to 0 (the width fills, nothing to center).
fn test_auto_margins_with_auto_width_are_zero() {
	doc := dom.Document.create(dom.url_about_blank())
	el := styled(doc, 'div', 'margin: 0 auto') // width auto
	box := layout_block(el, 0, 0, 800, []&css.CSSRule{})
	assert box.margin.left == 0.0
	assert box.margin.right == 0.0
	assert box.width == 800.0 // fills
}

// Centering respects the box model: a fixed margin on one side and auto on the other absorbs the
// rest. width 200, margin-left 100 fixed, margin-right auto -> right = 800 - 200 - 100 = 500.
fn test_one_fixed_one_auto_margin() {
	doc := dom.Document.create(dom.url_about_blank())
	el := styled(doc, 'div', 'width: 200px; margin-left: 100px; margin-right: auto')
	box := layout_block(el, 0, 0, 800, []&css.CSSRule{})
	assert box.margin.left == 100.0
	assert box.margin.right == 500.0
	assert box.x == 100.0
}

// Centering composes with max-width: an auto width capped by max-width, then centered.
fn test_auto_margins_center_max_width_clamped() {
	doc := dom.Document.create(dom.url_about_blank())
	el := styled(doc, 'div', 'max-width: 400px; margin: 0 auto') // width auto -> clamped to 400
	box := layout_block(el, 0, 0, 1000, []&css.CSSRule{})
	assert box.width == 400.0
	assert box.margin.left == 300.0 // (1000 - 400) / 2
	assert box.margin.right == 300.0
}

// Parent/child top collapsing: with no border/padding between them, the parent's top margin and the
// first child's top margin collapse to their max, appearing above the parent's border box.
fn test_parent_child_top_margin_collapse() {
	doc := dom.Document.create(dom.url_about_blank())
	root := styled(doc, 'div', 'width: 200px; margin-top: 20px')
	child := styled(doc, 'div', 'height: 30px; margin-top: 40px')
	mut rn := root.as_node()
	rn.append_child(child.as_node()) or { panic('${err}') }

	box := layout_block(root, 0, 0, 800, []&css.CSSRule{})
	assert box.outer_top_margin == 40.0 // max(20, 40)
	assert box.y == 40.0 // root border box pushed down by the collapsed margin
	assert box.children[0].y == 40.0 // child sits at the root's content top (margin collapsed out)
}

// Top border/padding on the parent stops the collapse: the child's top margin stays inside.
fn test_parent_border_stops_top_collapse() {
	doc := dom.Document.create(dom.url_about_blank())
	root := styled(doc, 'div', 'width: 200px; margin-top: 20px; padding-top: 5px')
	child := styled(doc, 'div', 'height: 30px; margin-top: 40px')
	mut rn := root.as_node()
	rn.append_child(child.as_node()) or { panic('${err}') }

	box := layout_block(root, 0, 0, 800, []&css.CSSRule{})
	assert box.outer_top_margin == 20.0 // no collapse-through
	assert box.y == 25.0 // 20 margin + 5 padding
	assert box.children[0].y == 65.0 // 25 content top + 40 own margin, held inside
}

// Parent/child bottom collapsing: with auto height and no bottom border/padding, the parent's bottom
// margin collapses with the last child's, and the child's bottom margin leaves the parent's content.
fn test_parent_child_bottom_margin_collapse() {
	doc := dom.Document.create(dom.url_about_blank())
	root := styled(doc, 'div', 'width: 200px; margin-bottom: 15px')
	child := styled(doc, 'div', 'height: 30px; margin-bottom: 25px')
	mut rn := root.as_node()
	rn.append_child(child.as_node()) or { panic('${err}') }

	box := layout_block(root, 0, 0, 800, []&css.CSSRule{})
	assert box.height == 30.0 // child's bottom margin collapsed out of the content
	assert box.outer_bottom_margin == 25.0 // max(15, 25)
}

// Bottom border/padding keeps the last child's bottom margin inside the parent's content height.
fn test_parent_border_stops_bottom_collapse() {
	doc := dom.Document.create(dom.url_about_blank())
	root := styled(doc, 'div', 'width: 200px; margin-bottom: 15px; padding-bottom: 5px')
	child := styled(doc, 'div', 'height: 30px; margin-bottom: 25px')
	mut rn := root.as_node()
	rn.append_child(child.as_node()) or { panic('${err}') }

	box := layout_block(root, 0, 0, 800, []&css.CSSRule{})
	assert box.height == 55.0 // 30 + 25 (child bottom margin held inside)
	assert box.outer_bottom_margin == 15.0 // no collapse-through
}

// Top margins collapse through multiple nesting levels when nothing separates them.
fn test_nested_top_margin_collapse_through() {
	doc := dom.Document.create(dom.url_about_blank())
	root := styled(doc, 'div', 'width: 200px')
	child := styled(doc, 'div', '') // no border/padding/margin
	grandchild := styled(doc, 'div', 'height: 20px; margin-top: 30px')
	mut cn := child.as_node()
	cn.append_child(grandchild.as_node()) or { panic('${err}') }
	mut rn := root.as_node()
	rn.append_child(child.as_node()) or { panic('${err}') }

	box := layout_block(root, 0, 0, 800, []&css.CSSRule{})
	assert box.outer_top_margin == 30.0 // collapsed through root <- child <- grandchild
	assert box.y == 30.0
	assert box.children[0].y == 30.0 // child at root content top
	assert box.children[0].children[0].y == 30.0 // grandchild too; all three tops coincide
}

// overflow != visible establishes a BFC: the child's top margin is CONTAINED (does not collapse
// through the box). Compare test_parent_child_top_margin_collapse, where the same box without
// overflow lets the margin collapse out.
fn test_bfc_overflow_contains_child_top_margin() {
	doc := dom.Document.create(dom.url_about_blank())
	root := styled(doc, 'div', 'width: 200px; overflow: hidden')
	child := styled(doc, 'div', 'height: 30px; margin-top: 40px')
	mut rn := root.as_node()
	rn.append_child(child.as_node()) or { panic('${err}') }

	box := layout_block(root, 0, 0, 800, []&css.CSSRule{})
	assert box.outer_top_margin == 0.0 // margin contained, not collapsed through
	assert box.y == 0.0 // root NOT pushed down
	assert box.children[0].y == 40.0 // child's top margin held inside the box
	assert box.height == 70.0 // 40 (margin, inside) + 30
}

// display: flow-root is the modern explicit BFC trigger; same containment.
fn test_bfc_flow_root_contains_child_top_margin() {
	doc := dom.Document.create(dom.url_about_blank())
	root := styled(doc, 'div', 'width: 200px; display: flow-root')
	child := styled(doc, 'div', 'height: 30px; margin-top: 40px')
	mut rn := root.as_node()
	rn.append_child(child.as_node()) or { panic('${err}') }

	box := layout_block(root, 0, 0, 800, []&css.CSSRule{})
	assert box.y == 0.0
	assert box.children[0].y == 40.0
	assert box.height == 70.0
}

// A BFC also contains the last child's bottom margin (it doesn't collapse out of the box).
fn test_bfc_contains_child_bottom_margin() {
	doc := dom.Document.create(dom.url_about_blank())
	root := styled(doc, 'div', 'width: 200px; overflow: auto')
	child := styled(doc, 'div', 'height: 30px; margin-bottom: 25px')
	mut rn := root.as_node()
	rn.append_child(child.as_node()) or { panic('${err}') }

	box := layout_block(root, 0, 0, 800, []&css.CSSRule{})
	assert box.height == 55.0 // 30 + 25 (bottom margin contained)
	assert box.outer_bottom_margin == 0.0 // not collapsed out
}

// establishes_block_formatting_context classification.
fn test_establishes_bfc_classification() {
	doc := dom.Document.create(dom.url_about_blank())
	assert establishes_block_formatting_context(styled(doc, 'div', 'overflow: hidden'), []&css.CSSRule{})
	assert establishes_block_formatting_context(styled(doc, 'div', 'overflow-y: scroll'), []&css.CSSRule{})
	assert establishes_block_formatting_context(styled(doc, 'div', 'display: flow-root'), []&css.CSSRule{})
	assert !establishes_block_formatting_context(styled(doc, 'div', ''), []&css.CSSRule{})
	assert !establishes_block_formatting_context(styled(doc, 'div', 'overflow: visible'), []&css.CSSRule{})
}

// position: relative offsets the box by top/left from its normal-flow position.
fn test_relative_position_offsets_box() {
	doc := dom.Document.create(dom.url_about_blank())
	el := styled(doc, 'div', 'width: 100px; height: 50px; position: relative; top: 15px; left: 25px')
	box := layout_block(el, 0, 0, 800, []&css.CSSRule{})
	assert box.x == 25.0 // left
	assert box.y == 15.0 // top
	assert box.width == 100.0 // size unchanged
	assert box.height == 50.0
}

// left/top may be negative; and right/bottom offset the opposite way (used when left/top are auto).
fn test_relative_position_negative_and_bottom_right() {
	doc := dom.Document.create(dom.url_about_blank())
	neg := styled(doc, 'div', 'position: relative; top: -10px; left: -5px; width: 10px')
	nb := layout_block(neg, 0, 0, 800, []&css.CSSRule{})
	assert nb.x == -5.0
	assert nb.y == -10.0

	br := styled(doc, 'div', 'position: relative; bottom: 20px; right: 30px; width: 10px')
	bb := layout_block(br, 0, 0, 800, []&css.CSSRule{})
	assert bb.x == -30.0 // right offsets leftward
	assert bb.y == -20.0 // bottom offsets upward
}

// A relatively positioned child moves but does NOT affect its siblings' flow positions.
fn test_relative_position_does_not_affect_siblings() {
	doc := dom.Document.create(dom.url_about_blank())
	root := styled(doc, 'div', 'width: 200px')
	first := styled(doc, 'div', 'height: 30px; position: relative; top: 100px')
	second := styled(doc, 'div', 'height: 20px')
	mut rn := root.as_node()
	rn.append_child(first.as_node()) or { panic('${err}') }
	rn.append_child(second.as_node()) or { panic('${err}') }

	box := layout_block(root, 0, 0, 800, []&css.CSSRule{})
	assert box.children[0].y == 100.0 // first offset down by 100 from its flow position (0)
	assert box.children[1].y == 30.0 // second still flows right after first's NORMAL position
	assert box.height == 50.0 // container height uses the flow, not the offset
}

// The relative offset carries the box's whole subtree along.
fn test_relative_position_moves_subtree() {
	doc := dom.Document.create(dom.url_about_blank())
	root := styled(doc, 'div', 'width: 200px; position: relative; top: 40px; left: 10px')
	child := styled(doc, 'div', 'height: 20px')
	mut rn := root.as_node()
	rn.append_child(child.as_node()) or { panic('${err}') }

	box := layout_block(root, 0, 0, 800, []&css.CSSRule{})
	assert box.x == 10.0
	assert box.y == 40.0
	assert box.children[0].x == 10.0 // child moved with the parent
	assert box.children[0].y == 40.0
}

// position: static (the default) ignores insets.
fn test_static_position_ignores_insets() {
	doc := dom.Document.create(dom.url_about_blank())
	el := styled(doc, 'div', 'width: 100px; top: 15px; left: 25px') // no position -> static
	box := layout_block(el, 0, 0, 800, []&css.CSSRule{})
	assert box.x == 0.0
	assert box.y == 0.0
}

// An absolutely positioned child is placed by top/left against its containing block (the nearest
// positioned ancestor's padding box).
fn test_absolute_position_top_left() {
	doc := dom.Document.create(dom.url_about_blank())
	root := styled(doc, 'div', 'position: relative; width: 200px; height: 100px')
	abs := styled(doc, 'div', 'position: absolute; top: 10px; left: 20px; width: 50px; height: 30px')
	mut rn := root.as_node()
	rn.append_child(abs.as_node()) or { panic('${err}') }

	box := layout_block(root, 0, 0, 800, []&css.CSSRule{})
	assert box.children.len == 1
	assert box.children[0].x == 20.0
	assert box.children[0].y == 10.0
	assert box.children[0].width == 50.0
	assert box.children[0].height == 30.0
}

// An abspos element is out of flow: it doesn't push its in-flow siblings or grow the container.
fn test_absolute_position_removed_from_flow() {
	doc := dom.Document.create(dom.url_about_blank())
	root := styled(doc, 'div', 'position: relative; width: 200px')
	inflow1 := styled(doc, 'div', 'height: 30px')
	abs := styled(doc, 'div', 'position: absolute; top: 0; height: 999px')
	inflow2 := styled(doc, 'div', 'height: 40px')
	mut rn := root.as_node()
	rn.append_child(inflow1.as_node()) or { panic('${err}') }
	rn.append_child(abs.as_node()) or { panic('${err}') }
	rn.append_child(inflow2.as_node()) or { panic('${err}') }

	box := layout_block(root, 0, 0, 800, []&css.CSSRule{})
	assert box.children.len == 3 // 2 in-flow + 1 abspos (appended)
	assert box.children[0].y == 0.0 // inflow1
	assert box.children[1].y == 30.0 // inflow2 flows right after inflow1, ignoring abs
	assert box.height == 70.0 // 30 + 40; abs's 999 height doesn't count
	assert box.children[2].height == 999.0 // the abspos box itself
}

// right/bottom position the box's far edges against the containing block.
fn test_absolute_position_right_bottom() {
	doc := dom.Document.create(dom.url_about_blank())
	root := styled(doc, 'div', 'position: relative; width: 200px; height: 100px')
	abs := styled(doc, 'div', 'position: absolute; right: 10px; bottom: 15px; width: 40px; height: 20px')
	mut rn := root.as_node()
	rn.append_child(abs.as_node()) or { panic('${err}') }

	box := layout_block(root, 0, 0, 800, []&css.CSSRule{})
	assert box.children[0].x == 150.0 // 200 - 10 - 40
	assert box.children[0].y == 65.0 // 100 - 15 - 20
}

// width:auto with both left and right fills the gap between them.
fn test_absolute_position_auto_width_between_insets() {
	doc := dom.Document.create(dom.url_about_blank())
	root := styled(doc, 'div', 'position: relative; width: 300px; height: 100px')
	abs := styled(doc, 'div', 'position: absolute; left: 20px; right: 30px; height: 40px')
	mut rn := root.as_node()
	rn.append_child(abs.as_node()) or { panic('${err}') }

	box := layout_block(root, 0, 0, 800, []&css.CSSRule{})
	assert box.children[0].x == 20.0
	assert box.children[0].width == 250.0 // 300 - 20 - 30
}

// The containing block is the NEAREST positioned ancestor: a static intermediate is skipped.
fn test_absolute_position_nearest_positioned_ancestor() {
	doc := dom.Document.create(dom.url_about_blank())
	rel := styled(doc, 'div', 'position: relative; width: 200px; height: 100px')
	mid := styled(doc, 'div', 'padding: 5px') // static -- NOT a containing block
	abs := styled(doc, 'div', 'position: absolute; top: 0; left: 0; width: 10px; height: 10px')
	mut mn := mid.as_node()
	mn.append_child(abs.as_node()) or { panic('${err}') }
	mut rn := rel.as_node()
	rn.append_child(mid.as_node()) or { panic('${err}') }

	box := layout_block(rel, 0, 0, 800, []&css.CSSRule{})
	assert box.children.len == 2 // mid (in-flow) + abs (appended to rel, its CB)
	abs_box := box.children[1]
	assert abs_box.x == 0.0 // against rel's padding box, ignoring mid's 5px padding
	assert abs_box.y == 0.0
}

// An unbreakable long word does NOT split mid-word (overflow-wrap: normal): it stays on one line
// (and overflows the box), unlike the old width-only estimate that split it into 3.
fn test_inline_long_word_stays_on_one_line() {
	doc := dom.Document.create(dom.url_about_blank())
	el := styled(doc, 'div', 'width: 100px; font-size: 20px; line-height: 30px')
	mut n := el.as_node()
	n.append_child(doc.create_text_node('a'.repeat(30)).as_node()) or { panic('${err}') } // one 30-char word

	box := layout_block(el, 0, 0, 800, []&css.CSSRule{})
	assert box.height == 30.0 // one line, overflowing -- not 3
}

// wrapped_line_count: greedy word wrapping with an unbreakable overflow word.
fn test_wrapped_line_count() {
	// glyph 10, space 10, width 100. "aaaa"(40) fits 2 per line.
	six := ['aaaa', 'bbbb', 'cccc', 'dddd', 'eeee', 'ffff']
	assert wrapped_line_count(six, 100, 10, 10) == 3
	// single word (any width) is one line.
	assert wrapped_line_count(['hello'], 100, 10, 10) == 1
	// an overlong word still occupies exactly one line.
	assert wrapped_line_count(['aaaaaaaaaaaaaaa'], 50, 10, 10) == 1
	// empty -> zero lines.
	assert wrapped_line_count([]string{}, 100, 10, 10) == 0
	// no room to wrap -> single line regardless.
	assert wrapped_line_count(['a', 'b', 'c'], 0, 10, 10) == 1
}

// A <br> forces a line break: "one<br>two" is two lines even though both fit on one line width.
fn test_br_forces_line_break() {
	doc := dom.Document.create(dom.url_about_blank())
	el := styled(doc, 'div', 'width: 500px; font-size: 20px; line-height: 30px')
	mut n := el.as_node()
	n.append_child(doc.create_text_node('one').as_node()) or { panic('${err}') }
	n.append_child(styled(doc, 'br', '').as_node()) or { panic('${err}') }
	n.append_child(doc.create_text_node('two').as_node()) or { panic('${err}') }

	box := layout_block(el, 0, 0, 800, []&css.CSSRule{})
	assert box.height == 60.0 // 2 lines * 30, though "one two" would fit on one 500px line
}

// Consecutive <br><br> creates an empty line between segments.
fn test_double_br_empty_line() {
	doc := dom.Document.create(dom.url_about_blank())
	el := styled(doc, 'div', 'width: 500px; font-size: 20px; line-height: 30px')
	mut n := el.as_node()
	n.append_child(doc.create_text_node('a').as_node()) or { panic('${err}') }
	n.append_child(styled(doc, 'br', '').as_node()) or { panic('${err}') }
	n.append_child(styled(doc, 'br', '').as_node()) or { panic('${err}') }
	n.append_child(doc.create_text_node('b').as_node()) or { panic('${err}') }

	box := layout_block(el, 0, 0, 800, []&css.CSSRule{})
	assert box.height == 90.0 // "a" | (empty) | "b" -> 3 lines * 30
}

// A <br> combines with word wrapping: a wrapping segment then a forced break then another segment.
fn test_br_combines_with_wrapping() {
	doc := dom.Document.create(dom.url_about_blank())
	el := styled(doc, 'div', 'width: 100px; font-size: 20px; line-height: 30px')
	mut n := el.as_node()
	// "aaaa bbbb cccc" wraps to 2 lines (2 words + 1), then <br>, then "dddd" one line = 3 lines.
	n.append_child(doc.create_text_node('aaaa bbbb cccc').as_node()) or { panic('${err}') }
	n.append_child(styled(doc, 'br', '').as_node()) or { panic('${err}') }
	n.append_child(doc.create_text_node('dddd').as_node()) or { panic('${err}') }

	box := layout_block(el, 0, 0, 800, []&css.CSSRule{})
	assert box.height == 90.0 // 2 (wrapped) + 1 (after break) = 3 lines * 30
}

// <br> inside a nested inline element still breaks the block's line.
fn test_br_nested_in_inline() {
	doc := dom.Document.create(dom.url_about_blank())
	el := styled(doc, 'div', 'width: 500px; font-size: 20px; line-height: 30px')
	span := styled(doc, 'span', '')
	mut sn := span.as_node()
	sn.append_child(doc.create_text_node('x').as_node()) or { panic('${err}') }
	sn.append_child(styled(doc, 'br', '').as_node()) or { panic('${err}') }
	sn.append_child(doc.create_text_node('y').as_node()) or { panic('${err}') }
	mut n := el.as_node()
	n.append_child(span.as_node()) or { panic('${err}') }

	box := layout_block(el, 0, 0, 800, []&css.CSSRule{})
	assert box.height == 60.0 // the <br> inside the span breaks the div's inline flow -> 2 lines
}

// Text produces a line box with geometry; default alignment (start) puts it at the content's left.
fn test_line_box_left_aligned() {
	doc := dom.Document.create(dom.url_about_blank())
	el := styled(doc, 'div', 'width: 200px; font-size: 20px; line-height: 30px')
	mut n := el.as_node()
	n.append_child(doc.create_text_node('Hi').as_node()) or { panic('${err}') } // 2 glyphs * 10 = 20px

	box := layout_block(el, 0, 0, 800, []&css.CSSRule{})
	assert box.lines.len == 1
	assert box.lines[0].x == 0.0 // left
	assert box.lines[0].y == 0.0
	assert box.lines[0].width == 20.0
	assert box.lines[0].height == 30.0
	assert box.children.len == 0 // lines aren't block children
}

// text-align: center centers the line within the content box.
fn test_line_box_centered() {
	doc := dom.Document.create(dom.url_about_blank())
	el := styled(doc, 'div', 'width: 200px; font-size: 20px; line-height: 30px; text-align: center')
	mut n := el.as_node()
	n.append_child(doc.create_text_node('Hi').as_node()) or { panic('${err}') }

	box := layout_block(el, 0, 0, 800, []&css.CSSRule{})
	assert box.lines[0].x == 90.0 // (200 - 20) / 2
}

// text-align: right pushes the line to the content's right edge.
fn test_line_box_right_aligned() {
	doc := dom.Document.create(dom.url_about_blank())
	el := styled(doc, 'div', 'width: 200px; font-size: 20px; line-height: 30px; text-align: right')
	mut n := el.as_node()
	n.append_child(doc.create_text_node('Hi').as_node()) or { panic('${err}') }

	box := layout_block(el, 0, 0, 800, []&css.CSSRule{})
	assert box.lines[0].x == 180.0 // 200 - 20
}

// Wrapped text produces a line box per line, stacked by line-height, each with its own used width.
fn test_line_boxes_stacked() {
	doc := dom.Document.create(dom.url_about_blank())
	el := styled(doc, 'div', 'width: 100px; font-size: 20px; line-height: 30px')
	mut n := el.as_node()
	n.append_child(doc.create_text_node('aaaa bbbb cccc').as_node()) or { panic('${err}') }

	box := layout_block(el, 0, 0, 800, []&css.CSSRule{})
	assert box.lines.len == 2
	assert box.lines[0].y == 0.0
	assert box.lines[0].width == 90.0 // "aaaa bbbb" = 40 + 10 + 40
	assert box.lines[1].y == 30.0
	assert box.lines[1].width == 40.0 // "cccc"
	assert box.height == 60.0
}

// Line boxes are positioned in absolute coordinates: a relative offset carries them along.
fn test_line_boxes_follow_relative_offset() {
	doc := dom.Document.create(dom.url_about_blank())
	el := styled(doc, 'div', 'width: 200px; font-size: 20px; line-height: 30px; position: relative; top: 15px; left: 25px')
	mut n := el.as_node()
	n.append_child(doc.create_text_node('Hi').as_node()) or { panic('${err}') }

	box := layout_block(el, 0, 0, 800, []&css.CSSRule{})
	assert box.lines[0].x == 25.0 // content_x includes the left offset
	assert box.lines[0].y == 15.0 // content_top includes the top offset
}

// white-space: nowrap keeps text on a single line even when it would otherwise wrap.
fn test_white_space_nowrap() {
	doc := dom.Document.create(dom.url_about_blank())
	el := styled(doc, 'div', 'width: 100px; font-size: 20px; line-height: 30px; white-space: nowrap')
	mut n := el.as_node()
	n.append_child(doc.create_text_node('aaaa bbbb cccc').as_node()) or { panic('${err}') }

	box := layout_block(el, 0, 0, 800, []&css.CSSRule{})
	assert box.lines.len == 1 // no wrapping despite 3 words over a 100px box
	assert box.height == 30.0
	assert box.lines[0].width == 140.0 // 40 + 10 + 40 + 10 + 40, all on one line (overflowing)
}

// white-space: pre turns newlines in text into forced line breaks and does not wrap.
fn test_white_space_pre_newlines() {
	doc := dom.Document.create(dom.url_about_blank())
	el := styled(doc, 'div', 'width: 100px; font-size: 20px; line-height: 30px; white-space: pre')
	mut n := el.as_node()
	n.append_child(doc.create_text_node('aaaa bbbb\ncccc').as_node()) or { panic('${err}') }

	box := layout_block(el, 0, 0, 800, []&css.CSSRule{})
	assert box.lines.len == 2 // split at the newline; neither part wraps
	assert box.height == 60.0
	assert box.lines[0].width == 90.0 // "aaaa bbbb"
	assert box.lines[1].width == 40.0 // "cccc"
}

// normal white-space (default) collapses the newline and wraps normally.
fn test_white_space_normal_collapses_newline() {
	doc := dom.Document.create(dom.url_about_blank())
	el := styled(doc, 'div', 'width: 500px; font-size: 20px; line-height: 30px')
	mut n := el.as_node()
	n.append_child(doc.create_text_node('aaaa\nbbbb').as_node()) or { panic('${err}') }

	box := layout_block(el, 0, 0, 800, []&css.CSSRule{})
	assert box.lines.len == 1 // newline collapses to a space; both words fit the 500px line
}

// white_space helper classification.
fn test_white_space_helpers() {
	assert white_space_wraps('normal')
	assert white_space_wraps('pre-wrap')
	assert !white_space_wraps('nowrap')
	assert !white_space_wraps('pre')
	assert white_space_preserves_newlines('pre')
	assert white_space_preserves_newlines('pre-line')
	assert !white_space_preserves_newlines('normal')
	assert !white_space_preserves_newlines('nowrap')
}

// width: max-content sizes the block to its widest unbroken line. "hello world" at 20px =
// 50 + 10 (space) + 50 = 110.
fn test_width_max_content() {
	doc := dom.Document.create(dom.url_about_blank())
	el := styled(doc, 'div', 'width: max-content; font-size: 20px')
	mut n := el.as_node()
	n.append_child(doc.create_text_node('hello world').as_node()) or { panic('${err}') }
	box := layout_block(el, 0, 0, 800, []&css.CSSRule{})
	assert box.width == 110.0
}

// width: min-content sizes the block to its widest single word (50).
fn test_width_min_content() {
	doc := dom.Document.create(dom.url_about_blank())
	el := styled(doc, 'div', 'width: min-content; font-size: 20px')
	mut n := el.as_node()
	n.append_child(doc.create_text_node('hello world').as_node()) or { panic('${err}') }
	box := layout_block(el, 0, 0, 800, []&css.CSSRule{})
	assert box.width == 50.0
}

// width: fit-content clamps to the available space between min-content (50) and max-content (110).
fn test_width_fit_content() {
	doc := dom.Document.create(dom.url_about_blank())
	el := styled(doc, 'div', 'width: fit-content; font-size: 20px')
	mut n := el.as_node()
	n.append_child(doc.create_text_node('hello world').as_node()) or { panic('${err}') }
	// available 80 is between min (50) and max (110) -> 80.
	assert layout_block(el, 0, 0, 80, []&css.CSSRule{}).width == 80.0
	// available 500 exceeds max -> clamps to max-content (110).
	assert layout_block(el, 0, 0, 500, []&css.CSSRule{}).width == 110.0
}

// intrinsic_content_width directly, and over a block-children tree (widest child wins).
fn test_intrinsic_content_width() {
	doc := dom.Document.create(dom.url_about_blank())
	text := styled(doc, 'div', 'font-size: 20px')
	mut tn := text.as_node()
	tn.append_child(doc.create_text_node('hello world').as_node()) or { panic('${err}') }
	assert intrinsic_content_width(text, []&css.CSSRule{}, false) == 110.0 // max-content
	assert intrinsic_content_width(text, []&css.CSSRule{}, true) == 50.0 // min-content

	parent := styled(doc, 'div', 'font-size: 20px')
	child1 := styled(doc, 'div', '')
	child2 := styled(doc, 'div', '')
	mut c1 := child1.as_node()
	c1.append_child(doc.create_text_node('short').as_node()) or { panic('${err}') } // 50
	mut c2 := child2.as_node()
	c2.append_child(doc.create_text_node('muchlongerword').as_node()) or { panic('${err}') } // 140
	mut pn := parent.as_node()
	pn.append_child(child1.as_node()) or { panic('${err}') }
	pn.append_child(child2.as_node()) or { panic('${err}') }
	assert intrinsic_content_width(parent, []&css.CSSRule{}, false) == 140.0 // widest child
}

// An absolutely positioned box with no width shrinks to fit its content (was: stretched to the CB).
fn test_absolute_position_shrink_to_fit() {
	doc := dom.Document.create(dom.url_about_blank())
	root := styled(doc, 'div', 'position: relative; width: 500px; height: 100px')
	abs := styled(doc, 'div', 'position: absolute; top: 0; left: 0; font-size: 20px')
	mut an := abs.as_node()
	an.append_child(doc.create_text_node('hi there').as_node()) or { panic('${err}') } // max 80, min 50
	mut rn := root.as_node()
	rn.append_child(abs.as_node()) or { panic('${err}') }

	box := layout_block(root, 0, 0, 800, []&css.CSSRule{})
	assert box.children[0].width == 80.0 // shrink-to-fit to max-content (fits in the 500px CB)
}

// A left float is placed at the container's left edge; a BFC (overflow:hidden) grows to contain it.
fn test_float_left_placement_bfc_contains() {
	doc := dom.Document.create(dom.url_about_blank())
	root := styled(doc, 'div', 'width: 300px; overflow: hidden')
	fl := styled(doc, 'div', 'float: left; width: 100px; height: 50px')
	mut rn := root.as_node()
	rn.append_child(fl.as_node()) or { panic('${err}') }

	box := layout_block(root, 0, 0, 800, []&css.CSSRule{})
	assert box.children.len == 1
	assert box.children[0].x == 0.0
	assert box.children[0].y == 0.0
	assert box.children[0].width == 100.0
	assert box.children[0].height == 50.0
	assert box.height == 50.0 // BFC contains the float
}

// A right float is placed against the container's right edge.
fn test_float_right_placement() {
	doc := dom.Document.create(dom.url_about_blank())
	root := styled(doc, 'div', 'width: 300px; overflow: hidden')
	fr := styled(doc, 'div', 'float: right; width: 80px; height: 40px')
	mut rn := root.as_node()
	rn.append_child(fr.as_node()) or { panic('${err}') }

	box := layout_block(root, 0, 0, 800, []&css.CSSRule{})
	assert box.children[0].x == 220.0 // 300 - 80
	assert box.children[0].width == 80.0
	assert box.height == 40.0
}

// Two left floats pack horizontally.
fn test_two_left_floats_stack() {
	doc := dom.Document.create(dom.url_about_blank())
	root := styled(doc, 'div', 'width: 300px; overflow: hidden')
	f1 := styled(doc, 'div', 'float: left; width: 100px; height: 50px')
	f2 := styled(doc, 'div', 'float: left; width: 60px; height: 30px')
	mut rn := root.as_node()
	rn.append_child(f1.as_node()) or { panic('${err}') }
	rn.append_child(f2.as_node()) or { panic('${err}') }

	box := layout_block(root, 0, 0, 800, []&css.CSSRule{})
	assert box.children[0].x == 0.0
	assert box.children[1].x == 100.0 // packed to the right of the first float
	assert box.children[1].width == 60.0
	assert box.height == 50.0 // tallest float
}

// clear: left moves an in-flow block below a left float; without a BFC the float isn't contained.
fn test_clear_left() {
	doc := dom.Document.create(dom.url_about_blank())
	root := styled(doc, 'div', 'width: 300px')
	fl := styled(doc, 'div', 'float: left; width: 100px; height: 50px')
	cleared := styled(doc, 'div', 'height: 20px; clear: left')
	mut rn := root.as_node()
	rn.append_child(fl.as_node()) or { panic('${err}') }
	rn.append_child(cleared.as_node()) or { panic('${err}') }

	box := layout_block(root, 0, 0, 800, []&css.CSSRule{})
	assert box.children.len == 2 // the in-flow block + the float
	assert box.children[0].y == 50.0 // cleared below the float
	assert box.children[0].height == 20.0
	assert box.children[1].y == 0.0 // the float itself
	assert box.height == 70.0 // 50 (clearance) + 20; float not contained (no BFC)
}

// Without a BFC, a float overflows its container (the container's height ignores it).
fn test_float_overflows_without_bfc() {
	doc := dom.Document.create(dom.url_about_blank())
	root := styled(doc, 'div', 'width: 300px') // static, not a BFC
	fl := styled(doc, 'div', 'float: left; width: 100px; height: 80px')
	mut rn := root.as_node()
	rn.append_child(fl.as_node()) or { panic('${err}') }

	box := layout_block(root, 0, 0, 800, []&css.CSSRule{})
	assert box.children[0].height == 80.0 // float still placed
	assert box.height == 0.0 // but NOT contained -- no BFC, no in-flow content
}

// clearance_bottom classification.
fn test_clearance_bottom() {
	doc := dom.Document.create(dom.url_about_blank())
	assert clearance_bottom(styled(doc, 'div', 'clear: left'), 50, 30, []&css.CSSRule{}) == 50.0
	assert clearance_bottom(styled(doc, 'div', 'clear: right'), 50, 30, []&css.CSSRule{}) == 30.0
	assert clearance_bottom(styled(doc, 'div', 'clear: both'), 50, 30, []&css.CSSRule{}) == 50.0
	assert clearance_bottom(styled(doc, 'div', ''), 50, 30, []&css.CSSRule{}) == 0.0
}

// Inline text wraps around a left float: lines in the float's band are offset to its right and
// shortened; a line below the float returns to full width. Float 150 wide/40 tall; 200px box;
// 20px font/line-height so ~one 40px word fits beside the float (available 50).
fn test_inline_wraps_around_left_float() {
	doc := dom.Document.create(dom.url_about_blank())
	root := styled(doc, 'div', 'width: 200px; overflow: hidden; font-size: 20px; line-height: 20px')
	fl := styled(doc, 'div', 'float: left; width: 150px; height: 40px')
	mut rn := root.as_node()
	rn.append_child(fl.as_node()) or { panic('${err}') }
	rn.append_child(doc.create_text_node('aaaa bbbb cccc').as_node()) or { panic('${err}') }

	box := layout_block(root, 0, 0, 800, []&css.CSSRule{})
	assert box.lines.len == 3
	assert box.lines[0].x == 150.0 // offset past the float
	assert box.lines[0].y == 0.0
	assert box.lines[1].x == 150.0
	assert box.lines[1].y == 20.0
	assert box.lines[2].x == 0.0 // third line drops below the float -> full width
	assert box.lines[2].y == 40.0
	assert box.height == 60.0 // 3 lines * 20 (taller than the 40px float)
}

// A right float shortens the lines in its band (forcing wrapping) without offsetting them.
fn test_inline_wraps_around_right_float() {
	doc := dom.Document.create(dom.url_about_blank())
	root := styled(doc, 'div', 'width: 200px; overflow: hidden; font-size: 20px; line-height: 20px')
	fr := styled(doc, 'div', 'float: right; width: 150px; height: 40px')
	mut rn := root.as_node()
	rn.append_child(fr.as_node()) or { panic('${err}') }
	rn.append_child(doc.create_text_node('aaaa bbbb cccc').as_node()) or { panic('${err}') }

	box := layout_block(root, 0, 0, 800, []&css.CSSRule{})
	assert box.lines.len == 3 // without the float these 3 words fit on one 200px line
	assert box.lines[0].x == 0.0 // not offset (float is on the right); just shortened
	assert box.lines[2].y == 40.0 // third line clears the float
}

// A word too wide to fit beside a float drops below it rather than overflowing into it.
fn test_inline_wide_word_drops_below_float() {
	doc := dom.Document.create(dom.url_about_blank())
	root := styled(doc, 'div', 'width: 200px; overflow: hidden; font-size: 20px; line-height: 20px')
	fl := styled(doc, 'div', 'float: left; width: 170px; height: 30px')
	mut rn := root.as_node()
	rn.append_child(fl.as_node()) or { panic('${err}') }
	rn.append_child(doc.create_text_node('verylongword').as_node()) or { panic('${err}') } // 120px

	box := layout_block(root, 0, 0, 800, []&css.CSSRule{})
	assert box.lines.len == 1
	assert box.lines[0].y == 30.0 // dropped below the 30px float (couldn't fit in the 30px gap)
	assert box.lines[0].x == 0.0 // full width below the float
	assert box.lines[0].width == 120.0
}

// z-index orders positioned siblings in paint order: negative behind, auto/0 in tree order, positive
// in front. The box itself paints before its children.
fn test_paint_order_z_index() {
	doc := dom.Document.create(dom.url_about_blank())
	root := styled(doc, 'div', 'position: relative; width: 200px; height: 100px')
	front := styled(doc, 'div', 'position: absolute; z-index: 5; top: 0; left: 0; width: 10px; height: 10px')
	behind := styled(doc, 'div', 'position: absolute; z-index: -1; top: 0; left: 0; width: 10px; height: 10px')
	auto := styled(doc, 'div', 'position: absolute; top: 0; left: 0; width: 10px; height: 10px') // z auto
	mut rn := root.as_node()
	rn.append_child(front.as_node()) or { panic('${err}') }
	rn.append_child(behind.as_node()) or { panic('${err}') }
	rn.append_child(auto.as_node()) or { panic('${err}') }

	order := layout_block(root, 0, 0, 800, []&css.CSSRule{}).paint_order()
	assert order.len == 4
	assert order[0].z_index == 0 // the root (relative, z-index auto) paints first
	assert order[1].z_index == -1 // behind
	assert order[2].z_index == 0 // auto (paints in tree order at 0)
	assert order[3].z_index == 5 // front
}

// z-index is ignored for non-positioned boxes: they keep tree order.
fn test_paint_order_ignores_z_on_static() {
	doc := dom.Document.create(dom.url_about_blank())
	root := styled(doc, 'div', 'width: 200px')
	first := styled(doc, 'div', 'height: 10px; z-index: 5') // static -> z ignored
	second := styled(doc, 'div', 'height: 20px; z-index: -1') // static -> z ignored
	mut rn := root.as_node()
	rn.append_child(first.as_node()) or { panic('${err}') }
	rn.append_child(second.as_node()) or { panic('${err}') }

	order := layout_block(root, 0, 0, 800, []&css.CSSRule{}).paint_order()
	assert order.len == 3
	assert order[1].height == 10.0 // first stays first (z-index:5 has no effect when static)
	assert order[1].z_index == 0
	assert order[2].height == 20.0 // second stays second (z-index:-1 has no effect)
}

// A box's subtree is contiguous in paint order (self, then descendants, before the next sibling).
fn test_paint_order_subtree_contiguous() {
	doc := dom.Document.create(dom.url_about_blank())
	root := styled(doc, 'div', 'width: 200px')
	parent := styled(doc, 'div', '')
	grandchild := styled(doc, 'div', 'height: 10px')
	sibling := styled(doc, 'div', 'height: 20px')
	mut pn := parent.as_node()
	pn.append_child(grandchild.as_node()) or { panic('${err}') }
	mut rn := root.as_node()
	rn.append_child(parent.as_node()) or { panic('${err}') }
	rn.append_child(sibling.as_node()) or { panic('${err}') }

	order := layout_block(root, 0, 0, 800, []&css.CSSRule{}).paint_order()
	assert order.len == 4 // root, parent, grandchild, sibling
	assert order[2].height == 10.0 // grandchild comes right after its parent
	assert order[3].height == 20.0 // the sibling comes after the whole parent subtree
}

// z_index field: an integer for positioned boxes, 0 for auto/non-positioned.
fn test_z_index_field() {
	doc := dom.Document.create(dom.url_about_blank())
	assert layout_block(styled(doc, 'div', 'position: absolute; z-index: 3'), 0, 0, 800, []&css.CSSRule{}).z_index == 3
	assert layout_block(styled(doc, 'div', 'position: relative; z-index: -2'), 0, 0, 800, []&css.CSSRule{}).z_index == -2
	assert layout_block(styled(doc, 'div', 'z-index: 3'), 0, 0, 800, []&css.CSSRule{}).z_index == 0 // static
	assert layout_block(styled(doc, 'div', 'position: relative'), 0, 0, 800, []&css.CSSRule{}).z_index == 0 // auto
}

// A line carries its words as positioned fragments laid out left-to-right.
fn test_inline_fragments_positions() {
	doc := dom.Document.create(dom.url_about_blank())
	el := styled(doc, 'div', 'width: 200px; font-size: 20px; line-height: 30px')
	mut n := el.as_node()
	n.append_child(doc.create_text_node('Hi there').as_node()) or { panic('${err}') } // 20 + space + 50

	box := layout_block(el, 0, 0, 800, []&css.CSSRule{})
	line := box.lines[0]
	assert line.fragments.len == 2
	assert line.fragments[0].text == 'Hi'
	assert line.fragments[0].x == 0.0
	assert line.fragments[0].width == 20.0
	assert line.fragments[1].text == 'there'
	assert line.fragments[1].x == 30.0 // 20 (Hi) + 10 (space)
	assert line.fragments[1].width == 50.0
	assert line.fragments[1].y == line.fragments[0].y // same line
	assert line.fragments[1].height == 30.0
}

// Fragments start at the line's text-aligned x.
fn test_inline_fragments_follow_text_align() {
	doc := dom.Document.create(dom.url_about_blank())
	el := styled(doc, 'div', 'width: 200px; font-size: 20px; line-height: 30px; text-align: center')
	mut n := el.as_node()
	n.append_child(doc.create_text_node('Hi').as_node()) or { panic('${err}') } // width 20

	box := layout_block(el, 0, 0, 800, []&css.CSSRule{})
	assert box.lines[0].fragments[0].x == 90.0 // (200 - 20) / 2
}

// Fragments span wrapped lines, each line's words positioned from its own left edge.
fn test_inline_fragments_across_wrapped_lines() {
	doc := dom.Document.create(dom.url_about_blank())
	el := styled(doc, 'div', 'width: 100px; font-size: 20px; line-height: 30px')
	mut n := el.as_node()
	n.append_child(doc.create_text_node('aaaa bbbb cccc').as_node()) or { panic('${err}') }

	box := layout_block(el, 0, 0, 800, []&css.CSSRule{})
	assert box.lines[0].fragments.len == 2 // "aaaa bbbb"
	assert box.lines[0].fragments[1].x == 50.0 // aaaa(40) + space(10)
	assert box.lines[1].fragments.len == 1 // "cccc"
	assert box.lines[1].fragments[0].text == 'cccc'
	assert box.lines[1].fragments[0].x == 0.0
	assert box.lines[1].fragments[0].y == 30.0 // second line
}

// Fragments ride along when the box is repositioned (relative offset translates them).
fn test_inline_fragments_translate_with_box() {
	doc := dom.Document.create(dom.url_about_blank())
	el := styled(doc, 'div', 'width: 200px; font-size: 20px; line-height: 30px; position: relative; top: 15px; left: 25px')
	mut n := el.as_node()
	n.append_child(doc.create_text_node('Hi').as_node()) or { panic('${err}') }

	box := layout_block(el, 0, 0, 800, []&css.CSSRule{})
	assert box.lines[0].fragments[0].x == 25.0 // content_x includes the left offset
	assert box.lines[0].fragments[0].y == 15.0 // content_top includes the top offset
}

// Fragments follow the line's float offset (the first word sits past a left float).
fn test_inline_fragments_follow_float() {
	doc := dom.Document.create(dom.url_about_blank())
	el := styled(doc, 'div', 'width: 200px; overflow: hidden; font-size: 20px; line-height: 20px')
	fl := styled(doc, 'div', 'float: left; width: 150px; height: 40px')
	mut n := el.as_node()
	n.append_child(fl.as_node()) or { panic('${err}') }
	n.append_child(doc.create_text_node('aaaa bbbb cccc').as_node()) or { panic('${err}') }

	box := layout_block(el, 0, 0, 800, []&css.CSSRule{})
	assert box.lines[0].fragments[0].x == 150.0 // first word offset past the float
	assert box.lines[2].fragments[0].x == 0.0 // third line dropped below the float -> full width
}

// A nested <span> with a larger font measures its text at that size, and makes the line taller.
fn test_per_inline_font_size() {
	doc := dom.Document.create(dom.url_about_blank())
	el := styled(doc, 'div', 'width: 500px; font-size: 20px') // line-height normal -> 24
	mut n := el.as_node()
	n.append_child(doc.create_text_node('small').as_node()) or { panic('${err}') } // 5*10 = 50
	span := styled(doc, 'span', 'font-size: 40px') // line-height normal -> 48
	mut sn := span.as_node()
	sn.append_child(doc.create_text_node('BIG').as_node()) or { panic('${err}') } // 3*20 = 60
	n.append_child(span.as_node()) or { panic('${err}') }

	box := layout_block(el, 0, 0, 800, []&css.CSSRule{})
	line := box.lines[0]
	assert line.fragments.len == 2
	assert line.fragments[0].text == 'small'
	assert line.fragments[0].width == 50.0
	assert line.fragments[0].height == 24.0 // small font's line-height
	assert line.fragments[1].text == 'BIG'
	assert line.fragments[1].width == 60.0 // measured at 40px (3 glyphs * 20)
	assert line.fragments[1].height == 48.0 // big font's line-height
	assert line.fragments[1].x == 60.0 // 50 (small) + 10 (space at small's font)
	assert line.height == 48.0 // the tallest word sets the line height
	assert box.height == 48.0
}

// Intrinsic width accounts for per-inline fonts: max-content sums mixed-font words + spaces;
// min-content is the widest single (mixed-font) word.
fn test_per_inline_intrinsic_width() {
	doc := dom.Document.create(dom.url_about_blank())
	el := styled(doc, 'div', 'font-size: 20px')
	mut n := el.as_node()
	n.append_child(doc.create_text_node('ab').as_node()) or { panic('${err}') } // 2*10 = 20
	span := styled(doc, 'span', 'font-size: 40px')
	mut sn := span.as_node()
	sn.append_child(doc.create_text_node('cd').as_node()) or { panic('${err}') } // 2*20 = 40
	n.append_child(span.as_node()) or { panic('${err}') }

	assert intrinsic_content_width(el, []&css.CSSRule{}, false) == 70.0 // 20 + 10 space + 40
	assert intrinsic_content_width(el, []&css.CSSRule{}, true) == 40.0 // widest word (the 40px one)
}

// text-align: justify spreads slack across the word gaps of every line but the last.
fn test_text_align_justify() {
	doc := dom.Document.create(dom.url_about_blank())
	el := styled(doc, 'div', 'width: 100px; font-size: 20px; line-height: 30px; text-align: justify')
	mut n := el.as_node()
	n.append_child(doc.create_text_node('aaaa bbbb cccc').as_node()) or { panic('${err}') }

	box := layout_block(el, 0, 0, 800, []&css.CSSRule{})
	// Line 0 "aaaa bbbb": natural width 90, available 100 -> 10px slack over the single gap.
	assert box.lines[0].width == 100.0 // fills the line
	assert box.lines[0].fragments[0].x == 0.0
	assert box.lines[0].fragments[1].x == 60.0 // 40 (aaaa) + 10 (space) + 10 (justify slack)
	// Line 1 "cccc" is the last line -> left-aligned, not justified.
	assert box.lines[1].fragments.len == 1
	assert box.lines[1].fragments[0].x == 0.0
	assert box.lines[1].width == 40.0
}

// A single-line (last-line) justified paragraph is left-aligned, not stretched.
fn test_justify_single_line_not_stretched() {
	doc := dom.Document.create(dom.url_about_blank())
	el := styled(doc, 'div', 'width: 500px; font-size: 20px; line-height: 30px; text-align: justify')
	mut n := el.as_node()
	n.append_child(doc.create_text_node('aa bb').as_node()) or { panic('${err}') }

	box := layout_block(el, 0, 0, 800, []&css.CSSRule{})
	assert box.lines.len == 1
	assert box.lines[0].fragments[0].x == 0.0
	assert box.lines[0].fragments[1].x == 30.0 // 20 (aa) + 10 (space); no slack added
	assert box.lines[0].width == 50.0 // natural width, not the 500px available
}

// A background-color produces a fill_rect over the border box; no text -> no draw commands.
fn test_paint_background_fill() {
	doc := dom.Document.create(dom.url_about_blank())
	el := styled(doc, 'div', 'width: 100px; height: 50px; background-color: #ff0000')
	cmds := layout_block(el, 0, 0, 800, []&css.CSSRule{}).paint_commands()
	assert cmds.len == 1
	assert cmds[0].kind == 'fill_rect'
	assert cmds[0].x == 0.0
	assert cmds[0].y == 0.0
	assert cmds[0].width == 100.0
	assert cmds[0].height == 50.0
	assert cmds[0].color == 'rgb(255 0 0)'
}

// The background fill covers the border box (content + padding + border).
fn test_paint_background_covers_border_box() {
	doc := dom.Document.create(dom.url_about_blank())
	el := styled(doc, 'div', 'width: 100px; height: 50px; padding: 10px; border: 5px solid; background-color: blue')
	cmds := layout_block(el, 0, 0, 800, []&css.CSSRule{}).paint_commands()
	assert cmds[0].x == 0.0
	assert cmds[0].width == 130.0 // 100 + 2*10 padding + 2*5 border
	assert cmds[0].height == 80.0 // 50 + 20 + 10
	assert cmds[0].color == 'rgb(0 0 255)'
}

// Text produces a draw_text command per word, in the box's color; transparent background emits no fill.
fn test_paint_draw_text() {
	doc := dom.Document.create(dom.url_about_blank())
	el := styled(doc, 'div', 'width: 500px; font-size: 20px; line-height: 30px; color: green')
	mut n := el.as_node()
	n.append_child(doc.create_text_node('hi there').as_node()) or { panic('${err}') }

	cmds := layout_block(el, 0, 0, 800, []&css.CSSRule{}).paint_commands()
	assert cmds.len == 2 // no background fill (transparent)
	assert cmds[0].kind == 'draw_text'
	assert cmds[0].text == 'hi'
	assert cmds[0].x == 0.0
	assert cmds[0].color == 'rgb(0 128 0)'
	assert cmds[1].text == 'there'
	assert cmds[1].x == 30.0
}

// The display list follows z-index paint order: a negative-z box paints before a positive-z one.
fn test_paint_z_index_order() {
	doc := dom.Document.create(dom.url_about_blank())
	root := styled(doc, 'div', 'position: relative; width: 100px; height: 100px; background-color: white')
	behind := styled(doc, 'div', 'position: absolute; z-index: -1; width: 10px; height: 10px; background-color: red')
	front := styled(doc, 'div', 'position: absolute; z-index: 1; width: 10px; height: 10px; background-color: blue')
	mut rn := root.as_node()
	rn.append_child(behind.as_node()) or { panic('${err}') }
	rn.append_child(front.as_node()) or { panic('${err}') }

	cmds := layout_block(root, 0, 0, 800, []&css.CSSRule{}).paint_commands()
	assert cmds.len == 3 // three background fills
	assert cmds[0].color == 'rgb(255 255 255)' // root paints first
	assert cmds[1].color == 'rgb(255 0 0)' // behind (z -1)
	assert cmds[2].color == 'rgb(0 0 255)' // front (z 1)
}

// A visible border emits one fill_rect per edge in the border color.
fn test_paint_border_edges() {
	doc := dom.Document.create(dom.url_about_blank())
	el := styled(doc, 'div', 'width: 100px; height: 50px; border: 5px solid red')
	cmds := layout_block(el, 0, 0, 800, []&css.CSSRule{}).paint_commands()
	assert cmds.len == 4 // no background; 4 border edges
	assert cmds[0].width == 110.0 && cmds[0].height == 5.0 // top edge spans the border box
	assert cmds[0].color == 'rgb(255 0 0)'
	assert cmds[1].y == 55.0 // bottom edge at border-box bottom - 5
	assert cmds[2].width == 5.0 && cmds[2].height == 60.0 // left edge
	assert cmds[3].x == 105.0 // right edge at border-box right - 5
}

// Background paints first, then borders.
fn test_paint_background_then_border() {
	doc := dom.Document.create(dom.url_about_blank())
	el := styled(doc, 'div', 'width: 100px; height: 50px; border: 2px solid black; background-color: yellow')
	cmds := layout_block(el, 0, 0, 800, []&css.CSSRule{}).paint_commands()
	assert cmds.len == 5 // background + 4 edges
	assert cmds[0].color == 'rgb(255 255 0)' // yellow background first
	assert cmds[1].color == 'rgb(0 0 0)' // then black border
}

// A border with no explicit color uses currentColor (the text color).
fn test_paint_border_current_color() {
	doc := dom.Document.create(dom.url_about_blank())
	el := styled(doc, 'div', 'width: 100px; height: 50px; border: 3px solid; color: blue')
	cmds := layout_block(el, 0, 0, 800, []&css.CSSRule{}).paint_commands()
	assert cmds[0].color == 'rgb(0 0 255)' // border resolves currentColor to blue
}

// Each text fragment paints in its own element's color (per-inline color).
fn test_paint_per_inline_color() {
	doc := dom.Document.create(dom.url_about_blank())
	el := styled(doc, 'div', 'width: 500px; font-size: 20px; line-height: 30px') // color default black
	mut n := el.as_node()
	n.append_child(doc.create_text_node('hi').as_node()) or { panic('${err}') }
	span := styled(doc, 'span', 'color: red')
	mut sn := span.as_node()
	sn.append_child(doc.create_text_node('RED').as_node()) or { panic('${err}') }
	n.append_child(span.as_node()) or { panic('${err}') }

	cmds := layout_block(el, 0, 0, 800, []&css.CSSRule{}).paint_commands()
	assert cmds.len == 2 // two draw_text, no background/border
	assert cmds[0].text == 'hi'
	assert cmds[0].color == 'rgb(0 0 0)' // default text color
	assert cmds[1].text == 'RED'
	assert cmds[1].color == 'rgb(255 0 0)' // the span's own color
}

// A calc() width resolves against the containing width (calc(100% - 40px) in a 300px block -> 260).
fn test_calc_width() {
	doc := dom.Document.create(dom.url_about_blank())
	el := styled(doc, 'div', 'width: calc(100% - 40px)')
	box := layout_block(el, 0, 0, 300, []&css.CSSRule{})
	assert box.width == 260.0
}

// An absolute calc() margin resolves without a basis (calc(20px + 5px) -> 25).
fn test_calc_absolute_margin() {
	doc := dom.Document.create(dom.url_about_blank())
	el := styled(doc, 'div', 'width: 100px; margin-left: calc(20px + 5px)')
	box := layout_block(el, 0, 0, 800, []&css.CSSRule{})
	assert box.margin.left == 25.0
	assert box.x == 25.0
}

// A calc() with a percentage in a padding resolves against the containing width (10% of 800 + 5).
fn test_calc_percentage_padding() {
	doc := dom.Document.create(dom.url_about_blank())
	el := styled(doc, 'div', 'width: 100px; padding-left: calc(10% + 5px)')
	box := layout_block(el, 0, 0, 800, []&css.CSSRule{})
	assert box.padding.left == 85.0 // 80 (10% of 800) + 5
}

// opacity is emitted per paint command (color stays unscaled).
fn test_paint_opacity() {
	doc := dom.Document.create(dom.url_about_blank())
	el := styled(doc, 'div', 'width: 100px; height: 50px; background-color: red; opacity: 0.5')
	cmds := layout_block(el, 0, 0, 800, []&css.CSSRule{}).paint_commands()
	assert cmds[0].opacity == 0.5
	assert cmds[0].color == 'rgb(255 0 0)' // color itself is not scaled
}

// Opacity accumulates down the tree: a child's paint opacity is its own times its ancestors'.
fn test_paint_opacity_cumulative() {
	doc := dom.Document.create(dom.url_about_blank())
	root := styled(doc, 'div', 'width: 100px; height: 100px; background-color: white; opacity: 0.5')
	child := styled(doc, 'div', 'width: 50px; height: 50px; background-color: red; opacity: 0.5')
	mut rn := root.as_node()
	rn.append_child(child.as_node()) or { panic('${err}') }

	cmds := layout_block(root, 0, 0, 800, []&css.CSSRule{}).paint_commands()
	assert cmds[0].opacity == 0.5 // root
	assert cmds[1].opacity == 0.25 // child: 0.5 * 0.5
}

// Default opacity is 1; values are clamped to 0..1.
fn test_opacity_field_clamped() {
	doc := dom.Document.create(dom.url_about_blank())
	assert layout_block(styled(doc, 'div', 'background-color: blue'), 0, 0, 800, []&css.CSSRule{}).paint_commands()[0].opacity == 1.0
	assert layout_block(styled(doc, 'div', 'opacity: 0.3'), 0, 0, 800, []&css.CSSRule{}).opacity == 0.3
	assert layout_block(styled(doc, 'div', 'opacity: 2'), 0, 0, 800, []&css.CSSRule{}).opacity == 1.0
	assert layout_block(styled(doc, 'div', 'opacity: -0.5'), 0, 0, 800, []&css.CSSRule{}).opacity == 0.0
}

// transform: translate offsets a box (and its subtree) without disturbing the flow of its siblings.
fn test_transform_translate() {
	doc := dom.Document.create(dom.url_about_blank())
	root := styled(doc, 'div', 'width: 200px')
	first := styled(doc, 'div', 'height: 30px; transform: translate(15px, 25px)')
	second := styled(doc, 'div', 'height: 20px')
	mut rn := root.as_node()
	rn.append_child(first.as_node()) or { panic('${err}') }
	rn.append_child(second.as_node()) or { panic('${err}') }

	box := layout_block(root, 0, 0, 800, []&css.CSSRule{})
	assert box.children[0].x == 15.0 // translated right
	assert box.children[0].y == 25.0 // translated down
	assert box.children[1].y == 30.0 // second still flows after first's UNTRANSFORMED box
	assert box.height == 50.0 // container height from the flow, ignoring the transform
}

// translateX / translateY offset one axis only.
fn test_transform_translate_single_axis() {
	doc := dom.Document.create(dom.url_about_blank())
	x := styled(doc, 'div', 'width: 100px; height: 50px; transform: translateX(12px)')
	xb := layout_block(x, 0, 0, 800, []&css.CSSRule{})
	assert xb.x == 12.0
	assert xb.y == 0.0

	y := styled(doc, 'div', 'width: 100px; height: 50px; transform: translateY(8px)')
	yb := layout_block(y, 0, 0, 800, []&css.CSSRule{})
	assert yb.x == 0.0
	assert yb.y == 8.0
}

// The transform carries the box's text fragments along.
fn test_transform_moves_subtree() {
	doc := dom.Document.create(dom.url_about_blank())
	el := styled(doc, 'div', 'width: 200px; font-size: 20px; line-height: 30px; transform: translate(10px, 20px)')
	mut n := el.as_node()
	n.append_child(doc.create_text_node('hi').as_node()) or { panic('${err}') }
	box := layout_block(el, 0, 0, 800, []&css.CSSRule{})
	assert box.x == 10.0
	assert box.y == 20.0
	assert box.lines[0].fragments[0].x == 10.0 // fragment moved with the box
	assert box.lines[0].fragments[0].y == 20.0
}

// transform_translate + parse_px_length parsing.
fn test_transform_translate_parse() {
	doc := dom.Document.create(dom.url_about_blank())
	assert parse_px_length('10px') == 10.0
	assert parse_px_length('-4px') == -4.0
	assert parse_px_length('0') == 0.0

	tx, ty := transform_translate(styled(doc, 'div', 'transform: translate(10px, 20px)'), []&css.CSSRule{})
	assert tx == 10.0 && ty == 20.0
	tx2, ty2 := transform_translate(styled(doc, 'div', 'transform: translateX(15px)'), []&css.CSSRule{})
	assert tx2 == 15.0 && ty2 == 0.0
	tx3, ty3 := transform_translate(styled(doc, 'div', ''), []&css.CSSRule{}) // none
	assert tx3 == 0.0 && ty3 == 0.0
}

// render_svg turns the display list into an SVG document: a filled rect for the background and a
// <text> for the word.
fn test_render_svg() {
	doc := dom.Document.create(dom.url_about_blank())
	el := styled(doc, 'div', 'width: 100px; height: 40px; background-color: #ff0000; font-size: 20px; line-height: 30px; color: blue')
	mut n := el.as_node()
	n.append_child(doc.create_text_node('hi').as_node()) or { panic('${err}') }

	svg := layout_block(el, 0, 0, 800, []&css.CSSRule{}).render_svg(100, 40)
	assert svg.starts_with('<svg xmlns="http://www.w3.org/2000/svg" width="100" height="40">')
	assert svg.ends_with('</svg>')
	assert svg.contains('<rect x="0" y="0" width="100" height="40" fill="rgb(255 0 0)" fill-opacity="1"/>')
	assert svg.contains('fill="rgb(0 0 255)"') // the text in blue
	assert svg.contains('>hi</text>')
}

// SVG text is XML-escaped.
fn test_render_svg_escapes_text() {
	doc := dom.Document.create(dom.url_about_blank())
	el := styled(doc, 'div', 'width: 200px; font-size: 20px; line-height: 30px')
	mut n := el.as_node()
	n.append_child(doc.create_text_node('a<b>&c').as_node()) or { panic('${err}') } // one "word"

	svg := layout_block(el, 0, 0, 800, []&css.CSSRule{}).render_svg(200, 30)
	assert svg.contains('>a&lt;b&gt;&amp;c</text>')
}

// Opacity flows into the SVG as fill-opacity.
fn test_render_svg_opacity() {
	doc := dom.Document.create(dom.url_about_blank())
	el := styled(doc, 'div', 'width: 50px; height: 50px; background-color: green; opacity: 0.5')
	svg := layout_block(el, 0, 0, 800, []&css.CSSRule{}).render_svg(50, 50)
	assert svg.contains('fill="rgb(0 128 0)" fill-opacity="0.5"/>')
}

// bounding_rect_for finds a laid-out element's border box by its unique_id (a working
// getBoundingClientRect, in document coordinates when laid out from the root).
fn test_bounding_rect_for_element() {
	doc := dom.Document.create(dom.url_about_blank())
	root := styled(doc, 'div', 'width: 300px')
	first := styled(doc, 'div', 'height: 40px')
	second := styled(doc, 'div', 'height: 20px')
	mut rn := root.as_node()
	rn.append_child(first.as_node()) or { panic('${err}') }
	rn.append_child(second.as_node()) or { panic('${err}') }

	box := layout_block(root, 0, 0, 800, []&css.CSSRule{})
	first_rect := box.bounding_rect_for(first) or { panic('no first') }
	assert first_rect.x == 0.0 && first_rect.y == 0.0
	assert first_rect.width == 300.0 && first_rect.height == 40.0
	second_rect := box.bounding_rect_for(second) or { panic('no second') }
	assert second_rect.y == 40.0 // stacked below the first
	assert second_rect.height == 20.0

	// An element not in the tree has no rect.
	orphan := styled(doc, 'div', '')
	assert box.bounding_rect_for(orphan) == none
}

// border_box covers content + padding + border.
fn test_border_box_rect() {
	doc := dom.Document.create(dom.url_about_blank())
	el := styled(doc, 'div', 'width: 100px; height: 50px; padding: 10px; border: 5px solid')
	box := layout_block(el, 0, 0, 800, []&css.CSSRule{})
	rect := box.border_box()
	assert rect.x == 0.0 && rect.y == 0.0
	assert rect.width == 130.0 // 100 + 2*10 + 2*5
	assert rect.height == 80.0 // 50 + 2*10 + 2*5
	// Same via bounding_rect_for on the root element.
	assert (box.bounding_rect_for(el) or { panic('no el') }).width == 130.0
}

// Absolutely positioned elements are findable too (they're appended to their containing block).
fn test_bounding_rect_for_abspos() {
	doc := dom.Document.create(dom.url_about_blank())
	root := styled(doc, 'div', 'position: relative; width: 200px; height: 100px')
	badge := styled(doc, 'div', 'position: absolute; top: 10px; left: 20px; width: 30px; height: 30px')
	mut rn := root.as_node()
	rn.append_child(badge.as_node()) or { panic('${err}') }

	box := layout_block(root, 0, 0, 800, []&css.CSSRule{})
	rect := box.bounding_rect_for(badge) or { panic('no badge') }
	assert rect.x == 20.0 && rect.y == 10.0
	assert rect.width == 30.0 && rect.height == 30.0
}

// hit_test returns the topmost element's node_id under a point (document.elementFromPoint).
fn test_hit_test() {
	doc := dom.Document.create(dom.url_about_blank())
	root := styled(doc, 'div', 'width: 200px')
	first := styled(doc, 'div', 'height: 40px')
	second := styled(doc, 'div', 'height: 30px')
	mut rn := root.as_node()
	rn.append_child(first.as_node()) or { panic('${err}') }
	rn.append_child(second.as_node()) or { panic('${err}') }

	box := layout_block(root, 0, 0, 800, []&css.CSSRule{})
	assert box.hit_test(50, 20) or { -1 } == i64(first.as_node().unique_id()) // in the first block
	assert box.hit_test(50, 55) or { -1 } == i64(second.as_node().unique_id()) // in the second block
	assert box.hit_test(50, 200) == none // below everything
	assert box.hit_test(-5, 10) == none // left of everything

	// element_at_point resolves back to the element.
	hit := box.element_at_point(50, 20, root.as_node()) or { panic('no hit') }
	assert i64(hit.as_node().unique_id()) == i64(first.as_node().unique_id())
}

// A box painted on top (absolutely positioned) wins the hit test over what's beneath it.
fn test_hit_test_topmost_wins() {
	doc := dom.Document.create(dom.url_about_blank())
	root := styled(doc, 'div', 'position: relative; width: 200px; height: 100px')
	badge := styled(doc, 'div', 'position: absolute; top: 10px; left: 20px; width: 50px; height: 50px')
	mut rn := root.as_node()
	rn.append_child(badge.as_node()) or { panic('${err}') }

	box := layout_block(root, 0, 0, 800, []&css.CSSRule{})
	// Inside the badge -> the badge (topmost), not the container beneath it.
	assert box.hit_test(30, 30) or { -1 } == i64(badge.as_node().unique_id())
	// Outside the badge but inside the container -> the container.
	assert box.hit_test(5, 5) or { -1 } == i64(root.as_node().unique_id())
}

// offsetWidth/Height are the border-box dimensions; offsetTop/Left are relative to the offsetParent's
// padding box; offsetParent is the nearest positioned ancestor.
fn test_offset_properties() {
	doc := dom.Document.create(dom.url_about_blank())
	container := styled(doc, 'div', 'position: relative; width: 200px; height: 200px; padding: 10px')
	child := styled(doc, 'div', 'position: absolute; top: 30px; left: 40px; width: 50px; height: 20px; border: 5px solid')
	mut cn := container.as_node()
	cn.append_child(child.as_node()) or { panic('${err}') }

	no := []&css.CSSRule{}
	box := layout_block(container, 0, 0, 800, no)

	assert box.offset_width_for(child) or { -1 } == 60.0 // 50 + 2*5 border
	assert box.offset_height_for(child) or { -1 } == 30.0 // 20 + 2*5
	assert box.offset_top_for(child, no) or { -1 } == 30.0 // the `top` inset, vs offsetParent padding box
	assert box.offset_left_for(child, no) or { -1 } == 40.0 // the `left` inset
	parent := offset_parent_element(child, no) or { panic('no offsetParent') }
	assert i64(parent.as_node().unique_id()) == i64(container.as_node().unique_id()) // the relative container
}

// offsetParent skips a static intermediate ancestor.
fn test_offset_parent_skips_static() {
	doc := dom.Document.create(dom.url_about_blank())
	rel := styled(doc, 'div', 'position: relative')
	mid := styled(doc, 'div', '') // static
	child := styled(doc, 'div', 'position: absolute')
	mut mn := mid.as_node()
	mn.append_child(child.as_node()) or { panic('${err}') }
	mut rn := rel.as_node()
	rn.append_child(mid.as_node()) or { panic('${err}') }

	parent := offset_parent_element(child, []&css.CSSRule{}) or { panic('no offsetParent') }
	assert i64(parent.as_node().unique_id()) == i64(rel.as_node().unique_id()) // rel, not mid
}

// innerText: block children are separated by single line breaks, <p> by blank lines, and a
// display:none subtree is omitted entirely.
fn test_inner_text_block_breaks_and_display_none() {
	doc := dom.Document.create(dom.url_about_blank())
	root := styled(doc, 'div', '')
	one := styled(doc, 'div', '')
	two := styled(doc, 'div', '')
	hidden := styled(doc, 'div', 'display: none')
	para := styled(doc, 'p', '')
	mut on := one.as_node()
	on.append_child(doc.create_text_node('one').as_node()) or { panic('${err}') }
	mut tn := two.as_node()
	tn.append_child(doc.create_text_node('two').as_node()) or { panic('${err}') }
	mut hn := hidden.as_node()
	hn.append_child(doc.create_text_node('hidden').as_node()) or { panic('${err}') }
	mut pn := para.as_node()
	pn.append_child(doc.create_text_node('para').as_node()) or { panic('${err}') }
	mut rn := root.as_node()
	rn.append_child(one.as_node()) or { panic('${err}') }
	rn.append_child(two.as_node()) or { panic('${err}') }
	rn.append_child(hidden.as_node()) or { panic('${err}') }
	rn.append_child(para.as_node()) or { panic('${err}') }

	assert inner_text(root, []&css.CSSRule{}) == 'one\ntwo\n\npara'
}

// innerText: collapsible white-space collapses to single spaces and <br> forces a line break.
fn test_inner_text_whitespace_collapse_and_br() {
	doc := dom.Document.create(dom.url_about_blank())
	root := styled(doc, 'div', '')
	br := styled(doc, 'br', '')
	mut rn := root.as_node()
	rn.append_child(doc.create_text_node('a   b').as_node()) or { panic('${err}') }
	rn.append_child(br.as_node()) or { panic('${err}') }
	rn.append_child(doc.create_text_node('c').as_node()) or { panic('${err}') }

	assert inner_text(root, []&css.CSSRule{}) == 'a b\nc'
}

// innerText: `white-space: pre` preserves internal spaces and source newlines.
fn test_inner_text_pre_preserves_whitespace() {
	doc := dom.Document.create(dom.url_about_blank())
	root := styled(doc, 'div', 'white-space: pre')
	mut rn := root.as_node()
	rn.append_child(doc.create_text_node('x  y\nz').as_node()) or { panic('${err}') }

	assert inner_text(root, []&css.CSSRule{}) == 'x  y\nz'
}

// Collect the text of every inline fragment in a box's line boxes, in order.
fn tt_fragment_texts(box BlockBox) []string {
	mut texts := []string{}
	for line in box.lines {
		for frag in line.fragments {
			texts << frag.text
		}
	}
	return texts
}

// text-transform: uppercase maps each rendered word to upper case.
fn test_text_transform_uppercase() {
	doc := dom.Document.create(dom.url_about_blank())
	root := styled(doc, 'div', 'width: 500px; font-size: 20px; text-transform: uppercase')
	mut rn := root.as_node()
	rn.append_child(doc.create_text_node('hello world').as_node()) or { panic('${err}') }

	box := layout_block(root, 0, 0, 800, []&css.CSSRule{})
	assert tt_fragment_texts(box) == ['HELLO', 'WORLD']
}

// text-transform: lowercase maps each rendered word to lower case.
fn test_text_transform_lowercase() {
	doc := dom.Document.create(dom.url_about_blank())
	root := styled(doc, 'div', 'width: 500px; font-size: 20px; text-transform: lowercase')
	mut rn := root.as_node()
	rn.append_child(doc.create_text_node('HELLO World').as_node()) or { panic('${err}') }

	box := layout_block(root, 0, 0, 800, []&css.CSSRule{})
	assert tt_fragment_texts(box) == ['hello', 'world']
}

// text-transform: capitalize uppercases the first letter of each word.
fn test_text_transform_capitalize() {
	doc := dom.Document.create(dom.url_about_blank())
	root := styled(doc, 'div', 'width: 500px; font-size: 20px; text-transform: capitalize')
	mut rn := root.as_node()
	rn.append_child(doc.create_text_node('hello world').as_node()) or { panic('${err}') }

	box := layout_block(root, 0, 0, 800, []&css.CSSRule{})
	assert tt_fragment_texts(box) == ['Hello', 'World']
}

// text-transform is inherited: a nested inline element gets the container's transform, and can
// override it with its own value.
fn test_text_transform_inherits_and_overrides() {
	doc := dom.Document.create(dom.url_about_blank())
	root := styled(doc, 'div', 'width: 500px; font-size: 20px; text-transform: uppercase')
	inner := styled(doc, 'span', 'text-transform: lowercase')
	mut inner_n := inner.as_node()
	inner_n.append_child(doc.create_text_node('World').as_node()) or { panic('${err}') }
	mut rn := root.as_node()
	rn.append_child(doc.create_text_node('hi').as_node()) or { panic('${err}') }
	rn.append_child(inner.as_node()) or { panic('${err}') }

	box := layout_block(root, 0, 0, 800, []&css.CSSRule{})
	// 'hi' inherits uppercase from the div; the span's own text is forced lowercase.
	assert tt_fragment_texts(box) == ['HI', 'world']
}

// visibility: hidden still reserves layout space but paints nothing.
fn test_visibility_hidden_reserves_space_but_no_paint() {
	doc := dom.Document.create(dom.url_about_blank())
	root := styled(doc, 'div', 'width: 100px')
	hidden := styled(doc, 'div', 'visibility: hidden; height: 30px; background-color: rgb(255, 0, 0)')
	mut rn := root.as_node()
	rn.append_child(hidden.as_node()) or { panic('${err}') }

	box := layout_block(root, 0, 0, 800, []&css.CSSRule{})
	assert box.height == 30.0 // the hidden child still occupies its 30px
	assert box.paint_commands().len == 0 // ...but produces no paint commands
}

// A visibility: visible descendant of a visibility: hidden box still paints (visibility is inherited
// but each box carries its own resolved value).
fn test_visibility_visible_child_of_hidden_paints() {
	doc := dom.Document.create(dom.url_about_blank())
	root := styled(doc, 'div', 'width: 100px')
	hidden := styled(doc, 'div', 'visibility: hidden; background-color: rgb(255, 0, 0)')
	shown := styled(doc, 'div', 'visibility: visible; height: 20px; background-color: rgb(0, 128, 0)')
	mut hn := hidden.as_node()
	hn.append_child(shown.as_node()) or { panic('${err}') }
	mut rn := root.as_node()
	rn.append_child(hidden.as_node()) or { panic('${err}') }

	box := layout_block(root, 0, 0, 800, []&css.CSSRule{})
	fills := box.paint_commands().filter(it.kind == 'fill_rect')
	assert fills.len == 1 // only the visible child's background, not the hidden parent's red
	assert fills[0].color == 'rgb(0 128 0)'
}

// text-decoration: underline (shorthand) marks the fragment and emits an underline rect near the
// bottom of the text, in the text color.
fn test_text_decoration_underline() {
	doc := dom.Document.create(dom.url_about_blank())
	root := styled(doc, 'div', 'width: 500px; font-size: 20px; text-decoration: underline')
	mut rn := root.as_node()
	rn.append_child(doc.create_text_node('hello').as_node()) or { panic('${err}') }

	box := layout_block(root, 0, 0, 800, []&css.CSSRule{})
	frag := box.lines[0].fragments[0]
	assert frag.decoration.contains('underline')

	cmds := box.paint_commands()
	assert cmds.filter(it.kind == 'draw_text').len == 1
	underlines := cmds.filter(it.kind == 'fill_rect')
	assert underlines.len == 1
	assert underlines[0].y > frag.y + frag.height * 0.5 // near the baseline, below the middle
	assert underlines[0].width == frag.width
}

// text-decoration-line: line-through emits a strike rect through the middle of the text.
fn test_text_decoration_line_through() {
	doc := dom.Document.create(dom.url_about_blank())
	root := styled(doc, 'div', 'width: 500px; font-size: 20px; text-decoration-line: line-through')
	mut rn := root.as_node()
	rn.append_child(doc.create_text_node('gone').as_node()) or { panic('${err}') }

	box := layout_block(root, 0, 0, 800, []&css.CSSRule{})
	frag := box.lines[0].fragments[0]
	strikes := box.paint_commands().filter(it.kind == 'fill_rect')
	assert strikes.len == 1
	// The strike sits around the vertical middle of the line.
	assert strikes[0].y > frag.y && strikes[0].y < frag.y + frag.height * 0.85
}

// text-decoration propagates to descendant inline text (the decorating box): a span with no
// decoration of its own inherits the container's underline.
fn test_text_decoration_propagates_to_descendants() {
	doc := dom.Document.create(dom.url_about_blank())
	root := styled(doc, 'div', 'width: 500px; font-size: 20px; text-decoration: underline')
	span := styled(doc, 'span', '')
	mut span_n := span.as_node()
	span_n.append_child(doc.create_text_node('child').as_node()) or { panic('${err}') }
	mut rn := root.as_node()
	rn.append_child(doc.create_text_node('parent').as_node()) or { panic('${err}') }
	rn.append_child(span.as_node()) or { panic('${err}') }

	box := layout_block(root, 0, 0, 800, []&css.CSSRule{})
	mut all_decorated := true
	mut count := 0
	for line in box.lines {
		for frag in line.fragments {
			count++
			if !frag.decoration.contains('underline') {
				all_decorated = false
			}
		}
	}
	assert count == 2 // 'parent' and 'child'
	assert all_decorated // both underlined, including the span's text
}

// A display:list-item box gets a disc marker hanging to the left of its content box.
fn test_list_item_disc_marker() {
	doc := dom.Document.create(dom.url_about_blank())
	root := styled(doc, 'div', 'width: 300px; font-size: 20px; padding-left: 40px')
	li := styled(doc, 'li', '') // list-style-type inherits initial 'disc'
	mut li_n := li.as_node()
	li_n.append_child(doc.create_text_node('item').as_node()) or { panic('${err}') }
	mut rn := root.as_node()
	rn.append_child(li.as_node()) or { panic('${err}') }

	box := layout_block(root, 0, 0, 800, []&css.CSSRule{})
	li_box := box.children[0]
	marker := li_box.lines[0].fragments[0]
	assert marker.text == '•'
	assert marker.x < li_box.x // hangs to the left of the content box
	assert li_box.lines[1].fragments[0].text == 'item' // content follows the marker line
}

// An ordered list numbers its items (decimal via the UA sheet, inherited to the li).
fn test_ordered_list_decimal_markers() {
	doc := dom.Document.create(dom.url_about_blank())
	root := styled(doc, 'ol', 'width: 300px; font-size: 20px')
	first := styled(doc, 'li', '')
	mut fn_ := first.as_node()
	fn_.append_child(doc.create_text_node('a').as_node()) or { panic('${err}') }
	second := styled(doc, 'li', '')
	mut sn := second.as_node()
	sn.append_child(doc.create_text_node('b').as_node()) or { panic('${err}') }
	mut rn := root.as_node()
	rn.append_child(first.as_node()) or { panic('${err}') }
	rn.append_child(second.as_node()) or { panic('${err}') }

	box := layout_block(root, 0, 0, 800, []&css.CSSRule{})
	assert box.children[0].lines[0].fragments[0].text == '1.'
	assert box.children[1].lines[0].fragments[0].text == '2.'
}

// list-style-type: none suppresses the marker.
fn test_list_item_none_no_marker() {
	doc := dom.Document.create(dom.url_about_blank())
	root := styled(doc, 'div', 'width: 300px; font-size: 20px')
	li := styled(doc, 'li', 'list-style-type: none')
	mut li_n := li.as_node()
	li_n.append_child(doc.create_text_node('x').as_node()) or { panic('${err}') }
	mut rn := root.as_node()
	rn.append_child(li.as_node()) or { panic('${err}') }

	box := layout_block(root, 0, 0, 800, []&css.CSSRule{})
	li_box := box.children[0]
	// The only line is the content 'x' — no bullet was prepended.
	assert li_box.lines[0].fragments[0].text == 'x'
}

// letter-spacing widens each glyph advance: a 2-rune word gains 2 × spacing.
fn test_letter_spacing_widens_words() {
	doc := dom.Document.create(dom.url_about_blank())
	root := styled(doc, 'div', 'width: 500px; font-size: 20px; letter-spacing: 4px')
	mut rn := root.as_node()
	rn.append_child(doc.create_text_node('ab').as_node()) or { panic('${err}') }

	box := layout_block(root, 0, 0, 800, []&css.CSSRule{})
	frag := box.lines[0].fragments[0]
	assert frag.text == 'ab'
	assert frag.width == 28.0 // 2 runes × (10px glyph + 4px letter-spacing)
}

// Negative letter-spacing tightens the advance.
fn test_negative_letter_spacing_tightens() {
	doc := dom.Document.create(dom.url_about_blank())
	root := styled(doc, 'div', 'width: 500px; font-size: 20px; letter-spacing: -2px')
	mut rn := root.as_node()
	rn.append_child(doc.create_text_node('ab').as_node()) or { panic('${err}') }

	box := layout_block(root, 0, 0, 800, []&css.CSSRule{})
	assert box.lines[0].fragments[0].width == 16.0 // 2 × (10 - 2)
}

// word-spacing widens the gap between words (added to the inter-word space).
fn test_word_spacing_widens_gap() {
	doc := dom.Document.create(dom.url_about_blank())
	root := styled(doc, 'div', 'width: 500px; font-size: 20px; word-spacing: 6px')
	mut rn := root.as_node()
	rn.append_child(doc.create_text_node('a b').as_node()) or { panic('${err}') }

	box := layout_block(root, 0, 0, 800, []&css.CSSRule{})
	frags := box.lines[0].fragments
	assert frags.len == 2
	// gap from 'a' to 'b' = a.width(10) + space(10) + word-spacing(6) = 26.
	assert frags[1].x - frags[0].x == 26.0
}

// CSS logical properties: a bare <p> gets its UA margin-block (1em = 16px top and bottom) via the
// logical->physical fallback, even though only `p { margin-block: 1em }` (logical) is in the UA sheet.
fn test_logical_margin_block_on_paragraph() {
	doc := dom.Document.create(dom.url_about_blank())
	p := styled(doc, 'p', '')
	box := layout_block(p, 0, 0, 800, []&css.CSSRule{})
	assert box.margin.top == 16.0 // 1em of the default 16px font
	assert box.margin.bottom == 16.0
}

// A <ul> gets its UA padding-inline-start (40px) mapped to padding-left in LTR.
fn test_logical_padding_inline_on_list() {
	doc := dom.Document.create(dom.url_about_blank())
	ul := styled(doc, 'ul', '')
	box := layout_block(ul, 0, 0, 800, []&css.CSSRule{})
	assert box.padding.left == 40.0
}

// A physical property that is explicitly set wins over the logical fallback (per-side): an author
// margin-top:5px is used, while margin-bottom still falls back to the UA logical 1em.
fn test_physical_edge_wins_over_logical() {
	doc := dom.Document.create(dom.url_about_blank())
	p := styled(doc, 'p', 'margin-top: 5px')
	box := layout_block(p, 0, 0, 800, []&css.CSSRule{})
	assert box.margin.top == 5.0 // physical wins
	assert box.margin.bottom == 16.0 // still the UA logical margin-block-end
}

// text-indent shifts the first line's content start to the right.
fn test_text_indent_first_line() {
	doc := dom.Document.create(dom.url_about_blank())
	root := styled(doc, 'div', 'width: 500px; font-size: 20px; text-indent: 30px')
	mut rn := root.as_node()
	rn.append_child(doc.create_text_node('hi').as_node()) or { panic('${err}') }

	box := layout_block(root, 0, 0, 800, []&css.CSSRule{})
	assert box.lines[0].fragments[0].x == 30.0 // content_x (0) + 30px indent
}

// Only the first line is indented; wrapped lines start at the content edge.
fn test_text_indent_only_first_line() {
	doc := dom.Document.create(dom.url_about_blank())
	root := styled(doc, 'div', 'width: 100px; font-size: 20px; text-indent: 30px')
	mut rn := root.as_node()
	rn.append_child(doc.create_text_node('aaaaa bbbbb').as_node()) or { panic('${err}') }

	box := layout_block(root, 0, 0, 800, []&css.CSSRule{})
	assert box.lines.len == 2
	assert box.lines[0].fragments[0].x == 30.0 // first line indented
	assert box.lines[1].fragments[0].x == 0.0 // wrapped line not indented
}

// A negative text-indent outdents the first line.
fn test_negative_text_indent() {
	doc := dom.Document.create(dom.url_about_blank())
	root := styled(doc, 'div', 'width: 500px; font-size: 20px; text-indent: -10px')
	mut rn := root.as_node()
	rn.append_child(doc.create_text_node('x').as_node()) or { panic('${err}') }

	box := layout_block(root, 0, 0, 800, []&css.CSSRule{})
	assert box.lines[0].fragments[0].x == -10.0
}

// border-radius rounds the background fill: the fill_rect carries the radius and the SVG rect gets rx/ry.
fn test_border_radius_rounds_background() {
	doc := dom.Document.create(dom.url_about_blank())
	root := styled(doc, 'div', 'width: 100px; height: 50px; background-color: rgb(0, 128, 0); border-radius: 8px')
	box := layout_block(root, 0, 0, 800, []&css.CSSRule{})

	assert box.border_radius == 8.0
	fills := box.paint_commands().filter(it.kind == 'fill_rect')
	assert fills.len == 1
	assert fills[0].radius == 8.0

	svg := box.render_svg(200, 200)
	assert svg.contains('rx="8"')
	assert svg.contains('ry="8"')
}

// A radius larger than half the smaller dimension is clamped (a 50% pill on a 100x40 box -> 20px).
fn test_border_radius_clamped() {
	doc := dom.Document.create(dom.url_about_blank())
	root := styled(doc, 'div', 'width: 100px; height: 40px; background-color: rgb(0, 0, 0); border-radius: 999px')
	box := layout_block(root, 0, 0, 800, []&css.CSSRule{})

	fills := box.paint_commands().filter(it.kind == 'fill_rect')
	assert fills[0].radius == 20.0 // clamped to min(100, 40)/2
}

// border-radius: 50% resolves against the border-box width, then clamps to half the smaller side.
fn test_border_radius_percentage() {
	doc := dom.Document.create(dom.url_about_blank())
	root := styled(doc, 'div', 'width: 80px; height: 80px; background-color: rgb(1, 2, 3); border-radius: 50%')
	box := layout_block(root, 0, 0, 800, []&css.CSSRule{})

	// 50% of 80 = 40, clamped to min(80,80)/2 = 40.
	fills := box.paint_commands().filter(it.kind == 'fill_rect')
	assert fills[0].radius == 40.0
}

// No border-radius -> square fill (radius 0, no rx in SVG).
fn test_no_border_radius_is_square() {
	doc := dom.Document.create(dom.url_about_blank())
	root := styled(doc, 'div', 'width: 50px; height: 50px; background-color: rgb(9, 9, 9)')
	box := layout_block(root, 0, 0, 800, []&css.CSSRule{})

	fills := box.paint_commands().filter(it.kind == 'fill_rect')
	assert fills[0].radius == 0.0
	assert !box.render_svg(100, 100).contains('rx=')
}
