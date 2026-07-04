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

// Vertical stacking accounts for each child's margin box (no collapsing yet).
fn test_block_box_model_stacking_with_margins() {
	doc := dom.Document.create(dom.url_about_blank())
	root := styled(doc, 'div', 'width: 200px')
	first := styled(doc, 'div', 'height: 30px; margin: 10px')
	second := styled(doc, 'div', 'height: 20px')
	mut root_node := root.as_node()
	root_node.append_child(first.as_node()) or { panic('${err}') }
	root_node.append_child(second.as_node()) or { panic('${err}') }

	box := layout_block(root, 0, 0, 800, []&css.CSSRule{})
	assert box.children[0].x == 10.0 // margin-left
	assert box.children[0].y == 10.0 // margin-top
	assert box.children[0].width == 180.0 // 200 - 20 (auto width minus margins)
	assert box.children[0].margin_box_height() == 50.0 // 10 + 30 + 10
	assert box.children[1].y == 50.0 // stacked below the first child's margin box
	assert box.children[1].width == 200.0
	assert box.height == 70.0 // 50 + 20
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

// Text wider than the content box wraps to multiple lines. 30 glyphs * 10px = 300px over a 100px
// content width -> ceil(300/100) = 3 lines * 30px = 90px.
fn test_inline_text_wraps_to_multiple_lines() {
	doc := dom.Document.create(dom.url_about_blank())
	el := styled(doc, 'div', 'width: 100px; font-size: 20px; line-height: 30px')
	mut n := el.as_node()
	n.append_child(doc.create_text_node('a'.repeat(30)).as_node()) or { panic('${err}') }

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
