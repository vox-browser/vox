module layout

import dom
import css
import math
import painting

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

fn test_display_contents_hoists_block_children_without_generating_a_box() {
	doc := dom.Document.create(dom.url_about_blank())
	root := styled(doc, 'div', 'width: 200px')
	wrapper := styled(doc, 'section', 'display: contents; width: 10px; padding: 30px; background-color: red')
	first := styled(doc, 'div', 'height: 20px')
	second := styled(doc, 'div', 'height: 30px')
	mut wrapper_node := wrapper.as_node()
	wrapper_node.append_child(first.as_node()) or { panic('${err}') }
	wrapper_node.append_child(second.as_node()) or { panic('${err}') }
	mut root_node := root.as_node()
	root_node.append_child(wrapper.as_node()) or { panic('${err}') }

	box := layout_block(root, 0, 0, 800, []&css.CSSRule{})
	assert box.children.len == 2
	assert box.children[0].tag_name == 'div'
	assert box.children[0].width == 200.0
	assert box.children[0].y == 0.0
	assert box.children[1].y == 20.0
	assert box.height == 50.0
}

fn test_display_contents_hoists_flex_items() {
	doc := dom.Document.create(dom.url_about_blank())
	root := styled(doc, 'div', 'display: flex; width: 200px; height: 20px')
	wrapper := styled(doc, 'section', 'display: contents')
	first := styled(doc, 'div', 'width: 60px; height: 20px')
	second := styled(doc, 'div', 'width: 40px; height: 20px')
	mut wrapper_node := wrapper.as_node()
	wrapper_node.append_child(first.as_node()) or { panic('${err}') }
	wrapper_node.append_child(second.as_node()) or { panic('${err}') }
	mut root_node := root.as_node()
	root_node.append_child(wrapper.as_node()) or { panic('${err}') }

	box := layout_block(root, 0, 0, 800, []&css.CSSRule{})
	assert box.children.len == 2
	assert box.children[0].x == 0.0
	assert box.children[1].x == 60.0
}

fn test_positioned_display_contents_does_not_capture_absolute_descendants() {
	doc := dom.Document.create(dom.url_about_blank())
	root := styled(doc, 'div', 'position: relative; width: 200px; height: 100px')
	wrapper := styled(doc, 'section', 'display: contents; position: relative')
	absolute := styled(doc, 'div', 'position: absolute; right: 10px; bottom: 15px; width: 20px; height: 25px')
	mut wrapper_node := wrapper.as_node()
	wrapper_node.append_child(absolute.as_node()) or { panic('${err}') }
	mut root_node := root.as_node()
	root_node.append_child(wrapper.as_node()) or { panic('${err}') }

	box := layout_block(root, 0, 0, 800, []&css.CSSRule{})
	assert box.children.len == 1
	assert box.children[0].x == 170.0
	assert box.children[0].y == 60.0
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

fn test_empty_block_collapses_its_margins_into_the_sibling_margin_chain() {
	doc := dom.Document.create(dom.url_about_blank())
	root := styled(doc, 'div', 'width: 200px')
	first := styled(doc, 'div', 'height: 40px; margin-bottom: 30px')
	empty := styled(doc, 'div', 'margin-top: 10px; margin-bottom: 20px')
	last := styled(doc, 'div', 'height: 60px; margin-top: 15px')
	mut root_node := root.as_node()
	root_node.append_child(first.as_node()) or { panic('${err}') }
	root_node.append_child(empty.as_node()) or { panic('${err}') }
	root_node.append_child(last.as_node()) or { panic('${err}') }

	box := layout_block(root, 0, 0, 800, []&css.CSSRule{})
	assert box.children[2].y == 70.0
	assert box.height == 130.0
}

fn test_empty_block_preserves_positive_and_negative_margins_across_the_chain() {
	doc := dom.Document.create(dom.url_about_blank())
	root := styled(doc, 'div', 'width: 200px')
	first := styled(doc, 'div', 'height: 40px; margin-bottom: 30px')
	empty := styled(doc, 'div', 'margin-top: -50px; margin-bottom: 20px')
	last := styled(doc, 'div', 'height: 60px; margin-top: 10px')
	mut root_node := root.as_node()
	root_node.append_child(first.as_node()) or { panic('${err}') }
	root_node.append_child(empty.as_node()) or { panic('${err}') }
	root_node.append_child(last.as_node()) or { panic('${err}') }

	box := layout_block(root, 0, 0, 800, []&css.CSSRule{})
	assert box.children[2].y == 20.0
	assert box.height == 80.0
}

fn test_empty_child_margin_chain_collapses_through_an_empty_parent() {
	doc := dom.Document.create(dom.url_about_blank())
	root := styled(doc, 'div', 'width: 200px; margin-top: 5px; margin-bottom: 7px')
	empty := styled(doc, 'div', 'margin-top: 20px; margin-bottom: 30px')
	mut root_node := root.as_node()
	root_node.append_child(empty.as_node()) or { panic('${err}') }

	box := layout_block(root, 0, 0, 800, []&css.CSSRule{})
	assert box.height == 0.0
	assert box.outer_top_margin == 30.0
	assert box.outer_bottom_margin == 30.0
}

fn test_document_element_establishes_a_block_formatting_context() {
	doc := dom.Document.create(dom.url_about_blank())
	html := styled(doc, 'html', 'width: 200px')
	child := styled(doc, 'div', 'height: 10px; margin-top: 20px')
	mut html_node := html.as_node()
	html_node.append_child(child.as_node()) or { panic('${err}') }
	mut document_node := unsafe { &dom.Node(doc) }
	document_node.append_child(html.as_node()) or { panic('${err}') }

	box := layout_block(html, 0, 0, 800, []&css.CSSRule{})
	assert box.y == 0.0
	assert box.children[0].y == 20.0
	assert box.height == 30.0
}

fn test_inline_block_and_table_cell_establish_block_formatting_contexts() {
	doc := dom.Document.create(dom.url_about_blank())
	for tag, display in {
		'span': 'inline-block'
		'td':   'table-cell'
	} {
		container := styled(doc, tag, 'display: ${display}; width: 100px; padding: 0; border: 0')
		child := styled(doc, 'div', 'height: 10px; margin-top: 20px; margin-bottom: 30px')
		mut container_node := container.as_node()
		container_node.append_child(child.as_node()) or { panic('${err}') }

		box := layout_block(container, 0, 0, 100, []&css.CSSRule{})
		assert box.outer_top_margin == 0.0
		assert box.children[0].y == 20.0
		assert box.height == 60.0
	}
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
	assert !is_block_level_display('contents')
	assert !is_block_level_display('inline')
	assert !is_block_level_display('inline-block')
}

// A text-only block gets a height from line count x line-height.
fn test_inline_text_single_line_height() {
	doc := dom.Document.create(dom.url_about_blank())
	el := styled(doc, 'div', 'width: 200px; font-size: 20px; line-height: 30px')
	mut n := el.as_node()
	n.append_child(doc.create_text_node('Hello').as_node()) or { panic('${err}') }

	box := layout_block(el, 0, 0, 800, []&css.CSSRule{})
	assert box.height == 30.0
	assert box.children.len == 0 // text isn't a block box
}

// Text wraps at word boundaries. The width admits two shaped four-letter words per line, so six
// words produce three lines.
fn test_inline_text_wraps_to_multiple_lines() {
	doc := dom.Document.create(dom.url_about_blank())
	el := styled(doc, 'div', 'width: 110px; font-size: 20px; line-height: 30px')
	mut n := el.as_node()
	n.append_child(doc.create_text_node('aaaa bbbb cccc dddd eeee ffff').as_node()) or {
		panic('${err}')
	}

	box := layout_block(el, 0, 0, 800, []&css.CSSRule{})
	assert box.height == 90.0
}

// A block with block children ignores its own stray text (the remaining anonymous-block gap): the text does not
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

// line-height: normal uses the selected font's metrics.
fn test_inline_normal_line_height() {
	doc := dom.Document.create(dom.url_about_blank())
	el := styled(doc, 'div', 'width: 500px; font-size: 20px') // line-height defaults to normal
	mut n := el.as_node()
	n.append_child(doc.create_text_node('hi').as_node()) or { panic('${err}') }
	box := layout_block(el, 0, 0, 800, []&css.CSSRule{})
	assert box.height == 23.0
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

fn test_attached_inner_text_uses_retained_computed_display_and_rendered_text() {
	doc := dom.Document.create(dom.url_about_blank())
	html_el := styled(doc, 'html', '')
	body := styled(doc, 'body', '')
	root := styled(doc, 'div', 'text-transform: uppercase')
	first := styled(doc, 'span', 'display: block')
	second := styled(doc, 'span', 'display: block')
	mut first_node := first.as_node()
	first_node.append_child(doc.create_text_node('one').as_node()) or { panic('${err}') }
	mut second_node := second.as_node()
	second_node.append_child(doc.create_text_node('two').as_node()) or { panic('${err}') }
	mut root_node := root.as_node()
	root_node.append_child(first.as_node()) or { panic('${err}') }
	root_node.append_child(second.as_node()) or { panic('${err}') }
	mut body_node := body.as_node()
	body_node.append_child(root.as_node()) or { panic('${err}') }
	mut html_node := html_el.as_node()
	html_node.append_child(body.as_node()) or { panic('${err}') }
	mut document_node := unsafe { &dom.Node(doc) }
	document_node.append_child(html_el.as_node()) or { panic('${err}') }

	layout_document(doc, 800)
	assert root.as_node().layout_node() != none
	assert inner_text(root, []&css.CSSRule{}) == 'ONE\nTWO'
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

// BlockFormattingContext retains the current border-box flow cursor for an abspos child's static
// position. A pending bottom margin is not part of that cursor, and the static inline start is the
// containing block's content edge rather than its padding edge.
fn test_absolute_position_auto_insets_use_block_flow_static_position() {
	doc := dom.Document.create(dom.url_about_blank())
	root := styled(doc, 'div', 'position: relative; width: 200px; padding: 7px')
	flow := styled(doc, 'div', 'height: 20px; margin-bottom: 15px')
	abs := styled(doc, 'div', 'position: absolute; width: 10px; height: 10px')
	mut rn := root.as_node()
	rn.append_child(flow.as_node()) or { panic('${err}') }
	rn.append_child(abs.as_node()) or { panic('${err}') }

	box := layout_block(root, 0, 0, 800, []&css.CSSRule{})
	abs_box := box.find_box(i64(abs.as_node().unique_id())) or { panic('no abspos box') }
	assert abs_box.x == 7.0
	assert abs_box.y == 27.0
}

// Static position is established in the formatting context where the abspos box occurred, then
// converted through unpositioned ancestors to the actual containing block's coordinate space.
fn test_absolute_position_static_position_crosses_static_ancestor() {
	doc := dom.Document.create(dom.url_about_blank())
	root := styled(doc, 'div', 'position: relative; width: 200px; padding: 3px')
	middle := styled(doc, 'div', 'padding: 5px')
	flow := styled(doc, 'div', 'height: 20px')
	abs := styled(doc, 'div', 'position: absolute; width: 10px; height: 10px')
	mut middle_node := middle.as_node()
	middle_node.append_child(flow.as_node()) or { panic('${err}') }
	middle_node.append_child(abs.as_node()) or { panic('${err}') }
	mut root_node := root.as_node()
	root_node.append_child(middle.as_node()) or { panic('${err}') }

	box := layout_block(root, 0, 0, 800, []&css.CSSRule{})
	abs_box := box.find_box(i64(abs.as_node().unique_id())) or { panic('no abspos box') }
	assert abs_box.x == 8.0
	assert abs_box.y == 28.0
}

// FlexFormattingContext retains the container's content rectangle and resolves both axes only after
// the abspos child's final margin-box size is known.
fn test_flex_absolute_static_position_uses_alignment_rectangle() {
	doc := dom.Document.create(dom.url_about_blank())
	root := styled(doc, 'div', 'position: relative; display: flex; width: 100px; height: 60px; justify-content: center; align-items: flex-end')
	abs := styled(doc, 'div', 'position: absolute; width: 20px; height: 10px; margin-left: 10px; margin-top: 5px')
	mut root_node := root.as_node()
	root_node.append_child(abs.as_node()) or { panic('${err}') }

	box := layout_block(root, 0, 0, 800, []&css.CSSRule{})
	abs_box := box.find_box(i64(abs.as_node().unique_id())) or { panic('no abspos box') }
	assert abs_box.x == 45.0 // centered 30px margin box starts at 35, then 10px left margin
	assert abs_box.y == 50.0 // 15px margin box ends at 60, then 5px top margin
}

// For reversed main directions, flex-start selects the physical end of the static-position rect.
fn test_flex_absolute_static_position_honors_reversed_main_axis() {
	doc := dom.Document.create(dom.url_about_blank())
	root := styled(doc, 'div', 'position: relative; display: flex; flex-direction: row-reverse; width: 100px; height: 40px; justify-content: flex-start; align-items: flex-start')
	abs := styled(doc, 'div', 'position: absolute; width: 20px; height: 10px')
	mut root_node := root.as_node()
	root_node.append_child(abs.as_node()) or { panic('${err}') }

	box := layout_block(root, 0, 0, 800, []&css.CSSRule{})
	abs_box := box.find_box(i64(abs.as_node().unique_id())) or { panic('no abspos box') }
	assert abs_box.x == 80.0
	assert abs_box.y == 0.0
}

// A column flex container swaps the main/cross alignments onto the vertical/horizontal axes.
fn test_column_flex_absolute_static_position_swaps_alignment_axes() {
	doc := dom.Document.create(dom.url_about_blank())
	root := styled(doc, 'div', 'position: relative; display: flex; flex-direction: column; width: 100px; height: 80px; justify-content: flex-end; align-items: center')
	abs := styled(doc, 'div', 'position: absolute; width: 20px; height: 10px')
	mut root_node := root.as_node()
	root_node.append_child(abs.as_node()) or { panic('${err}') }

	box := layout_block(root, 0, 0, 800, []&css.CSSRule{})
	abs_box := box.find_box(i64(abs.as_node().unique_id())) or { panic('no abspos box') }
	assert abs_box.x == 40.0
	assert abs_box.y == 70.0
}

fn test_flex_absolute_explicit_normal_align_self_stays_at_cross_start() {
	doc := dom.Document.create(dom.url_about_blank())
	root := styled(doc, 'div', 'position: relative; display: flex; width: 100px; height: 60px; align-items: center')
	abs := styled(doc, 'div', 'position: absolute; width: 20px; height: 10px; align-self: normal')
	mut root_node := root.as_node()
	root_node.append_child(abs.as_node()) or { panic('${err}') }

	box := layout_block(root, 0, 0, 800, []&css.CSSRule{})
	abs_box := box.find_box(i64(abs.as_node().unique_id())) or { panic('no abspos box') }
	assert abs_box.y == 0.0
}

// A static flex container calculates the rectangle, while the actual positioned ancestor still
// supplies the abspos containing block. Retained coordinates must survive that traversal.
fn test_flex_absolute_static_rectangle_crosses_static_flex_container() {
	doc := dom.Document.create(dom.url_about_blank())
	root := styled(doc, 'div', 'position: relative; width: 200px; height: 100px')
	flex := styled(doc, 'div', 'display: flex; width: 100px; height: 60px; margin-left: 20px; justify-content: center; align-items: center')
	abs := styled(doc, 'div', 'position: absolute; width: 20px; height: 10px')
	mut flex_node := flex.as_node()
	flex_node.append_child(abs.as_node()) or { panic('${err}') }
	mut root_node := root.as_node()
	root_node.append_child(flex.as_node()) or { panic('${err}') }

	box := layout_block(root, 0, 0, 800, []&css.CSSRule{})
	abs_box := box.find_box(i64(abs.as_node().unique_id())) or { panic('no abspos box') }
	assert abs_box.x == 60.0
	assert abs_box.y == 25.0
}

// GridFormattingContext likewise retains its content-box rectangle when the actual containing block
// is an outer positioned ancestor; the grid's own flow offset must not be replaced by that ancestor's
// origin.
fn test_absolute_static_rectangle_crosses_static_grid_container() {
	doc := dom.Document.create(dom.url_about_blank())
	root := styled(doc, 'div', 'position: relative; width: 200px; height: 100px')
	flow := styled(doc, 'div', 'height: 15px')
	grid := styled(doc, 'div', 'display: grid; width: 100px; height: 60px; margin-left: 20px')
	abs := styled(doc, 'div', 'position: absolute; width: 10px; height: 10px')
	mut grid_node := grid.as_node()
	grid_node.append_child(abs.as_node()) or { panic('${err}') }
	mut root_node := root.as_node()
	root_node.append_child(flow.as_node()) or { panic('${err}') }
	root_node.append_child(grid.as_node()) or { panic('${err}') }

	box := layout_block(root, 0, 0, 800, []&css.CSSRule{})
	abs_box := box.find_box(i64(abs.as_node().unique_id())) or { panic('no abspos box') }
	assert abs_box.x == 20.0
	assert abs_box.y == 15.0
}

// InlineFormattingContext positions an inline-outside abspos box at the previous fragment's
// top-right corner after line construction has settled.
fn test_inline_absolute_position_follows_previous_fragment() {
	doc := dom.Document.create(dom.url_about_blank())
	root := styled(doc, 'div', 'position: relative; width: 200px; padding: 4px')
	inline_box_element := styled(doc, 'span', 'display: inline-block; width: 20px; height: 10px')
	abs := styled(doc, 'span', 'position: absolute; width: 10px; height: 10px')
	mut root_node := root.as_node()
	root_node.append_child(inline_box_element.as_node()) or { panic('${err}') }
	root_node.append_child(abs.as_node()) or { panic('${err}') }

	box := layout_block(root, 0, 0, 800, []&css.CSSRule{})
	abs_box := box.find_box(i64(abs.as_node().unique_id())) or { panic('no abspos box') }
	assert abs_box.x == 24.0
	assert abs_box.y == 4.0
}

// A block-outside abspos item encountered by an IFC uses the bottom of the previous fragment.
fn test_block_outside_absolute_position_follows_previous_inline_fragment_bottom() {
	doc := dom.Document.create(dom.url_about_blank())
	root := styled(doc, 'div', 'position: relative; width: 200px; padding: 4px')
	inline_box_element := styled(doc, 'span', 'display: inline-block; width: 20px; height: 10px')
	abs := styled(doc, 'div', 'position: absolute; width: 10px; height: 10px')
	mut root_node := root.as_node()
	root_node.append_child(inline_box_element.as_node()) or { panic('${err}') }
	root_node.append_child(abs.as_node()) or { panic('${err}') }

	box := layout_block(root, 0, 0, 800, []&css.CSSRule{})
	abs_box := box.find_box(i64(abs.as_node().unique_id())) or { panic('no abspos box') }
	assert abs_box.x == 4.0
	assert abs_box.y == 14.0
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

fn test_absolute_position_equal_auto_margins_center_between_insets() {
	doc := dom.Document.create(dom.url_about_blank())
	root := styled(doc, 'div', 'position: relative; width: 300px; height: 200px')
	child := styled(doc, 'div', 'position: absolute; left: 10px; right: 10px; top: 10px; bottom: 10px; width: 100px; height: 50px; margin: auto')
	mut root_node := root.as_node()
	root_node.append_child(child.as_node()) or { panic('${err}') }

	box := layout_block(root, 0, 0, 800, []&css.CSSRule{})
	absolute := box.children[0]
	assert absolute.margin.left == 90.0
	assert absolute.margin.right == 90.0
	assert absolute.x == 100.0
	assert absolute.margin.top == 65.0
	assert absolute.margin.bottom == 65.0
	assert absolute.y == 75.0
}

fn test_absolute_position_single_auto_margin_absorbs_the_axis_remainder() {
	doc := dom.Document.create(dom.url_about_blank())
	root := styled(doc, 'div', 'position: relative; width: 300px; height: 200px')
	child := styled(doc, 'div', 'position: absolute; left: 10px; right: 10px; top: 10px; bottom: 10px; width: 100px; height: 50px; margin-left: auto; margin-right: 20px; margin-top: 15px; margin-bottom: auto')
	mut root_node := root.as_node()
	root_node.append_child(child.as_node()) or { panic('${err}') }

	box := layout_block(root, 0, 0, 800, []&css.CSSRule{})
	absolute := box.children[0]
	assert absolute.margin.left == 160.0
	assert absolute.margin.right == 20.0
	assert absolute.x == 170.0
	assert absolute.margin.top == 15.0
	assert absolute.margin.bottom == 115.0
	assert absolute.y == 25.0
}

fn test_absolute_position_auto_margin_is_zero_when_an_inset_is_auto() {
	doc := dom.Document.create(dom.url_about_blank())
	root := styled(doc, 'div', 'position: relative; width: 300px; height: 100px')
	child := styled(doc, 'div', 'position: absolute; right: 10px; width: 50px; height: 20px; margin-left: auto')
	mut root_node := root.as_node()
	root_node.append_child(child.as_node()) or { panic('${err}') }

	box := layout_block(root, 0, 0, 800, []&css.CSSRule{})
	absolute := box.children[0]
	assert absolute.margin.left == 0.0
	assert absolute.x == 240.0
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

fn test_fixed_position_is_hoisted_and_uses_the_initial_containing_block() {
	doc := dom.Document.create(dom.url_about_blank())
	mut mutable_doc := unsafe { &dom.Document(doc) }
	mutable_doc.set_viewport_rect(dom.Rect{0, 0, 300, 200})
	html := styled(doc, 'html', 'width: 300px')
	positioned := styled(doc, 'div', 'position: relative; left: 50px; top: 25px; height: 40px')
	fixed := styled(doc, 'div', 'position: fixed; right: 10px; bottom: 15px; width: 30px; height: 20px')
	mut positioned_node := positioned.as_node()
	positioned_node.append_child(fixed.as_node()) or { panic('${err}') }
	mut html_node := html.as_node()
	html_node.append_child(positioned.as_node()) or { panic('${err}') }
	mut document_node := unsafe { &dom.Node(doc) }
	document_node.append_child(html.as_node()) or { panic('${err}') }

	box := layout_block(html, 0, 0, 300, []&css.CSSRule{})
	assert box.children.len == 2
	assert box.children[0].node_id == i64(positioned.as_node().unique_id())
	assert box.children[0].children.len == 0
	assert box.children[1].node_id == i64(fixed.as_node().unique_id())
	assert box.children[1].x == 260.0
	assert box.children[1].y == 165.0
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
	el := styled(doc, 'div', 'width: 110px; font-size: 20px; line-height: 30px')
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
	n.append_child(doc.create_text_node('Hi').as_node()) or { panic('${err}') }

	box := layout_block(el, 0, 0, 800, []&css.CSSRule{})
	assert box.lines.len == 1
	assert box.lines[0].x == 0.0 // left

	assert box.lines[0].y == 0.0
	assert box.lines[0].width == 21.0
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
	assert box.lines[0].x == 89.5 // (200 - 21) / 2
}

// text-align: right pushes the line to the content's right edge.
fn test_line_box_right_aligned() {
	doc := dom.Document.create(dom.url_about_blank())
	el := styled(doc, 'div', 'width: 200px; font-size: 20px; line-height: 30px; text-align: right')
	mut n := el.as_node()
	n.append_child(doc.create_text_node('Hi').as_node()) or { panic('${err}') }

	box := layout_block(el, 0, 0, 800, []&css.CSSRule{})
	assert box.lines[0].x == 179.0 // 200 - 21, rounded to CSS pixels
}

// Wrapped text produces a line box per line, stacked by line-height, each with its own used width.
fn test_line_boxes_stacked() {
	doc := dom.Document.create(dom.url_about_blank())
	el := styled(doc, 'div', 'width: 110px; font-size: 20px; line-height: 30px')
	mut n := el.as_node()
	n.append_child(doc.create_text_node('aaaa bbbb cccc').as_node()) or { panic('${err}') }

	box := layout_block(el, 0, 0, 800, []&css.CSSRule{})
	assert box.lines.len == 2
	assert box.lines[0].y == 0.0
	assert box.lines[0].width == 104.125
	assert box.lines[1].y == 30.0
	assert box.lines[1].width == 44.4375
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
	assert box.lines[0].width == 158.5625
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
	assert box.lines[0].width == 104.125
	assert box.lines[1].width == 44.4375
}

fn test_white_space_pre_preserves_exact_space_and_tab_advances_in_paint_run() {
	doc := dom.Document.create(dom.url_about_blank())
	el := styled(doc, 'div', 'width: 200px; font-size: 20px; line-height: 30px; white-space: pre; tab-size: 4')
	mut node := el.as_node()
	node.append_child(doc.create_text_node(' a  \tb ').as_node()) or { panic('${err}') }

	box := layout_block(el, 0, 0, 800, []&css.CSSRule{})
	assert box.lines.len == 1
	assert box.lines[0].width == 103.53125
	assert box.lines[0].fragments.map(it.x) == [0.0, 10.0, 81.6875]
	commands := box.paint_commands().filter(it.kind == 'draw_text')
	assert commands.len == 1
	assert commands[0].text == ' a  \tb '
	assert commands[0].x == 0.0
	assert commands[0].width == 103.53125
}

fn test_direction_rtl_places_logical_fragments_from_the_right_and_marks_text_run() {
	doc := dom.Document.create(dom.url_about_blank())
	el := styled(doc, 'div', 'width: 100px; font-size: 20px; direction: rtl; text-align: start')
	mut node := el.as_node()
	node.append_child(doc.create_text_node('aa bb').as_node()) or { panic('${err}') }

	box := layout_block(el, 0, 0, 800, []&css.CSSRule{})
	assert box.lines.len == 1
	assert box.lines[0].x == 42.9375
	assert box.lines[0].fragments.map(it.x) == [76.625, 42.9375]
	commands := box.paint_commands().filter(it.kind == 'draw_text')
	assert commands.len == 1
	assert commands[0].text == 'aa bb'
	assert commands[0].x == 42.9375
	assert commands[0].width == 57.0625
	assert commands[0].rtl
	svg := box.render_svg(100, 30)
	assert svg.contains('<text x="100"')
	assert svg.contains('direction="rtl" unicode-bidi="plaintext"')
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
	normal := white_space_behavior_from_longhands('collapse', 'wrap', 'none')
	pre := white_space_behavior_from_longhands('preserve', 'nowrap', 'none')
	pre_wrap := white_space_behavior_from_longhands('preserve', 'wrap', 'none')
	pre_line := white_space_behavior_from_longhands('preserve-breaks', 'wrap', 'none')
	assert normal.wraps()
	assert pre_wrap.wraps()
	assert !pre.wraps()
	assert pre.preserves_newlines()
	assert pre_line.preserves_newlines()
	assert !normal.preserves_newlines()
	assert !normal.preserves_spaces()
	assert pre.preserves_spaces()
}

fn test_white_space_direct_longhands_match_shorthand_behavior() {
	doc := dom.Document.create(dom.url_about_blank())
	el := styled(doc, 'div', 'width: 100px; font-size: 20px; line-height: 30px; white-space-collapse: preserve; text-wrap-mode: nowrap')
	mut node := el.as_node()
	node.append_child(doc.create_text_node('one two\nthree').as_node()) or { panic('${err}') }
	box := layout_block(el, 0, 0, 100, []&css.CSSRule{})
	assert box.lines.len == 2
	assert box.lines[0].fragments.map(it.text).join(' ') == 'one two'
	assert box.lines[1].fragments.map(it.text).join(' ') == 'three'
}

// width: max-content sizes the block to its widest unbroken line. "hello world" at 20px =
// 50 + 10 (space) + 50 = 110.
fn test_width_max_content() {
	doc := dom.Document.create(dom.url_about_blank())
	el := styled(doc, 'div', 'width: max-content; font-size: 20px')
	mut n := el.as_node()
	n.append_child(doc.create_text_node('hello world').as_node()) or { panic('${err}') }
	box := layout_block(el, 0, 0, 800, []&css.CSSRule{})
	assert box.width == 109.21875
}

// width: min-content sizes the block to its widest single word (50).
fn test_width_min_content() {
	doc := dom.Document.create(dom.url_about_blank())
	el := styled(doc, 'div', 'width: min-content; font-size: 20px')
	mut n := el.as_node()
	n.append_child(doc.create_text_node('hello world').as_node()) or { panic('${err}') }
	box := layout_block(el, 0, 0, 800, []&css.CSSRule{})
	assert box.width == 53.140625
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
	assert layout_block(el, 0, 0, 500, []&css.CSSRule{}).width == 109.21875
}

// intrinsic_content_width directly, and over a block-children tree (widest child wins).
fn test_intrinsic_content_width() {
	doc := dom.Document.create(dom.url_about_blank())
	text := styled(doc, 'div', 'font-size: 20px')
	mut tn := text.as_node()
	tn.append_child(doc.create_text_node('hello world').as_node()) or { panic('${err}') }
	assert intrinsic_content_width(text, []&css.CSSRule{}, false) == 109.21875 // max-content

	assert intrinsic_content_width(text, []&css.CSSRule{}, true) == 53.140625 // min-content

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
	assert intrinsic_content_width(parent, []&css.CSSRule{}, false) == 159.6875 // widest child
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
	assert box.children[0].width == 80.375 // shrink-to-fit to max-content (fits in the 500px CB)
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

fn test_floats_move_down_until_their_margin_box_fits() {
	doc := dom.Document.create(dom.url_about_blank())
	root := styled(doc, 'div', 'width: 150px; overflow: hidden')
	mut root_node := root.as_node()
	for _ in 0 .. 3 {
		float := styled(doc, 'div', 'float: left; width: 80px; height: 20px')
		root_node.append_child(float.as_node()) or { panic('${err}') }
	}

	box := layout_block(root, 0, 0, 800, []&css.CSSRule{})
	assert box.children[0].x == 0.0 && box.children[0].y == 0.0
	assert box.children[1].x == 0.0 && box.children[1].y == 20.0
	assert box.children[2].x == 0.0 && box.children[2].y == 40.0
	assert box.height == 60.0
}

fn test_float_is_placed_at_its_tree_order_block_opportunity() {
	doc := dom.Document.create(dom.url_about_blank())
	root := styled(doc, 'div', 'width: 200px; overflow: hidden')
	before := styled(doc, 'div', 'height: 30px')
	float := styled(doc, 'div', 'float: left; width: 80px; height: 20px')
	after := styled(doc, 'div', 'height: 10px; clear: left')
	mut root_node := root.as_node()
	root_node.append_child(before.as_node()) or { panic('${err}') }
	root_node.append_child(float.as_node()) or { panic('${err}') }
	root_node.append_child(after.as_node()) or { panic('${err}') }

	box := layout_block(root, 0, 0, 800, []&css.CSSRule{})
	assert box.children[0].node_id == i64(before.as_node().unique_id())
	assert box.children[0].y == 0.0
	// Floats paint after the in-flow list in this transport, but their geometry is anchored at the
	// tree-order opportunity where the float was encountered.
	assert box.children[2].node_id == i64(float.as_node().unique_id())
	assert box.children[2].y == 30.0
	assert box.children[1].y == 50.0
	assert box.height == 60.0
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
	rn.append_child(doc.create_text_node('verylongword').as_node()) or { panic('${err}') }

	box := layout_block(root, 0, 0, 800, []&css.CSSRule{})
	assert box.lines.len == 1
	assert box.lines[0].y == 30.0 // dropped below the 30px float (couldn't fit in the 30px gap)

	assert box.lines[0].x == 0.0 // full width below the float

	assert box.lines[0].width == 128.71875
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

fn test_descendant_stacking_context_is_hoisted_through_z_auto_ancestor() {
	doc := dom.Document.create(dom.url_about_blank())
	root := styled(doc, 'div', 'position: relative; width: 500px; height: 100px')
	parent := styled(doc, 'div', 'position: relative; width: 100px; height: 40px')
	nested := styled(doc, 'div', 'position: absolute; z-index: 10; width: 10px; height: 10px')
	sibling := styled(doc, 'div', 'position: absolute; z-index: 1; width: 20px; height: 20px')
	mut parent_node := parent.as_node()
	parent_node.append_child(nested.as_node()) or { panic('${err}') }
	mut root_node := root.as_node()
	root_node.append_child(parent.as_node()) or { panic('${err}') }
	root_node.append_child(sibling.as_node()) or { panic('${err}') }

	order := layout_block(root, 0, 0, 800, []&css.CSSRule{}).paint_order()
	assert order.map(it.width) == [f64(500), 100, 20, 10]
	assert order.map(it.z_index) == [0, 0, 1, 10]
}

fn test_opacity_and_transform_make_descendant_stacking_contexts_atomic() {
	for context_style in ['opacity: 0.5', 'transform: translateX(0px)'] {
		doc := dom.Document.create(dom.url_about_blank())
		root := styled(doc, 'div', 'position: relative; width: 500px; height: 100px')
		parent := styled(doc, 'div', 'position: relative; width: 100px; height: 40px; ${context_style}')
		nested := styled(doc, 'div', 'position: absolute; z-index: 10; width: 10px; height: 10px')
		sibling := styled(doc, 'div', 'position: absolute; z-index: 1; width: 20px; height: 20px')
		mut parent_node := parent.as_node()
		parent_node.append_child(nested.as_node()) or { panic('${err}') }
		mut root_node := root.as_node()
		root_node.append_child(parent.as_node()) or { panic('${err}') }
		root_node.append_child(sibling.as_node()) or { panic('${err}') }

		order := layout_block(root, 0, 0, 800, []&css.CSSRule{}).paint_order()
		assert order.map(it.width) == [f64(500), 100, 10, 20]
		assert order[1].stacking_context
	}
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
	n.append_child(doc.create_text_node('Hi there').as_node()) or { panic('${err}') }

	box := layout_block(el, 0, 0, 800, []&css.CSSRule{})
	line := box.lines[0]
	assert line.fragments.len == 2
	assert line.fragments[0].text == 'Hi'
	assert line.fragments[0].x == 0.0
	assert line.fragments[0].width == 21.0
	assert line.fragments[1].text == 'there'
	assert line.fragments[1].x == 31.0
	assert line.fragments[1].width == 53.046875
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
	assert box.lines[0].fragments[0].x == 89.5 // (200 - 21) / 2
}

// Fragments span wrapped lines, each line's words positioned from its own left edge.
fn test_inline_fragments_across_wrapped_lines() {
	doc := dom.Document.create(dom.url_about_blank())
	el := styled(doc, 'div', 'width: 110px; font-size: 20px; line-height: 30px')
	mut n := el.as_node()
	n.append_child(doc.create_text_node('aaaa bbbb cccc').as_node()) or { panic('${err}') }

	box := layout_block(el, 0, 0, 800, []&css.CSSRule{})
	assert box.lines[0].fragments.len == 2 // "aaaa bbbb"

	assert box.lines[0].fragments[1].x == 56.75
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
	n.append_child(doc.create_text_node('small ').as_node()) or { panic('${err}') } // 5*10 + space
	span := styled(doc, 'span', 'font-size: 40px') // line-height normal -> 48
	mut sn := span.as_node()
	sn.append_child(doc.create_text_node('BIG').as_node()) or { panic('${err}') } // 3*20 = 60
	n.append_child(span.as_node()) or { panic('${err}') }

	box := layout_block(el, 0, 0, 800, []&css.CSSRule{})
	line := box.lines[0]
	assert line.fragments.len == 2
	assert line.fragments[0].text == 'small'
	assert line.fragments[0].width == 49.21875
	assert line.fragments[0].height == 23.0
	assert line.fragments[1].text == 'BIG'
	assert line.fragments[1].width == 67.9375
	assert line.fragments[1].height == 46.0
	assert line.fragments[1].x == 59.21875
	assert line.height == 46.0 // the tallest word sets the line height

	assert box.height == 46.0
}

// Intrinsic width accounts for per-inline fonts: max-content sums mixed-font words + spaces;
// min-content is the widest single (mixed-font) word.
fn test_per_inline_intrinsic_width() {
	doc := dom.Document.create(dom.url_about_blank())
	el := styled(doc, 'div', 'font-size: 20px')
	mut n := el.as_node()
	n.append_child(doc.create_text_node('ab ').as_node()) or { panic('${err}') } // 2*10 + space
	span := styled(doc, 'span', 'font-size: 40px')
	mut sn := span.as_node()
	sn.append_child(doc.create_text_node('cd').as_node()) or { panic('${err}') } // 2*20 = 40
	n.append_child(span.as_node()) or { panic('${err}') }

	assert intrinsic_content_width(el, []&css.CSSRule{}, false) == 75.421875
	assert intrinsic_content_width(el, []&css.CSSRule{}, true) == 41.890625
}

// text-align: justify spreads slack across the word gaps of every line but the last.
fn test_text_align_justify() {
	doc := dom.Document.create(dom.url_about_blank())
	el := styled(doc, 'div', 'width: 110px; font-size: 20px; line-height: 30px; text-align: justify')
	mut n := el.as_node()
	n.append_child(doc.create_text_node('aaaa bbbb cccc').as_node()) or { panic('${err}') }

	box := layout_block(el, 0, 0, 800, []&css.CSSRule{})
	// Line 0 "aaaa bbbb" is stretched across the available width.
	assert box.lines[0].width == 110.0
	assert box.lines[0].fragments[0].x == 0.0
	assert box.lines[0].fragments[1].x == 62.625
	// Line 1 "cccc" is the last line -> left-aligned, not justified.
	assert box.lines[1].fragments.len == 1
	assert box.lines[1].fragments[0].x == 0.0
	assert box.lines[1].width == 44.4375
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
	assert box.lines[0].fragments[1].x == 33.375 // natural shaping; no slack added

	assert box.lines[0].width == 57.0625 // natural width, not the 500px available
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

// Naturally spaced words from one text node produce one shaped draw_text run; transparent
// background emits no fill.
fn test_paint_draw_text() {
	doc := dom.Document.create(dom.url_about_blank())
	el := styled(doc, 'div', 'width: 500px; font-size: 20px; line-height: 30px; color: green')
	mut n := el.as_node()
	n.append_child(doc.create_text_node('hi there').as_node()) or { panic('${err}') }

	cmds := layout_block(el, 0, 0, 800, []&css.CSSRule{}).paint_commands()
	assert cmds.len == 1 // no background fill (transparent)

	assert cmds[0].kind == 'draw_text'
	assert cmds[0].text == 'hi there'
	assert cmds[0].x == 0.0
	assert cmds[0].width == 80.375
	assert cmds[0].color == 'rgb(0 128 0)'
}

// DOM element boundaries do not invent whitespace. Only whitespace present in a text node creates
// an inter-word gap, and punctuation adjacent to an inline element remains adjacent.
fn test_inline_boundaries_preserve_collapsed_source_whitespace() {
	doc := dom.Document.create(dom.url_about_blank())
	root := styled(doc, 'div', 'width: 500px; font-size: 20px')
	span := styled(doc, 'span', '')
	mut span_node := span.as_node()
	span_node.append_child(doc.create_text_node('b').as_node()) or { panic('${err}') }
	mut root_node := root.as_node()
	root_node.append_child(doc.create_text_node('a').as_node()) or { panic('${err}') }
	root_node.append_child(span.as_node()) or { panic('${err}') }
	root_node.append_child(doc.create_text_node(', c').as_node()) or { panic('${err}') }

	fragments := layout_block(root, 0, 0, 800, []&css.CSSRule{}).lines[0].fragments
	assert fragments.map(it.text) == ['a', 'b', ',', 'c']
	assert fragments.map(it.x) == [0.0, 11.6875, 23.53125, 39.84375]
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

// A visible same-color border is one joined even-odd path, matching paint_all_borders().
fn test_paint_border_edges() {
	doc := dom.Document.create(dom.url_about_blank())
	el := styled(doc, 'div', 'width: 100px; height: 50px; border: 5px solid red')
	cmds := layout_block(el, 0, 0, 800, []&css.CSSRule{}).paint_commands()
	assert cmds.len == 1
	assert cmds[0].kind == 'draw_svg_path'
	assert cmds[0].width == 110.0 && cmds[0].height == 60.0
	assert cmds[0].color == 'rgb(255 0 0)'
	assert cmds[0].fill_even_odd
	assert cmds[0].path_data.len > 0
	assert cmds[0].path_polygons.len == 4
}

// Physical border colors remain independent through layout and are painted as mitered polygons, so
// differently colored sides meet at a shared diagonal instead of overwriting one another's corners.
fn test_paint_independent_border_side_colors_without_corner_overlap() {
	doc := dom.Document.create(dom.url_about_blank())
	el := styled(doc, 'div', 'width: 100px; height: 50px; border-top: 2px solid red; border-right: 3px solid green; border-bottom: 4px solid blue; border-left: 5px solid black')
	box := layout_block(el, 0, 0, 800, []&css.CSSRule{})
	assert box.border_colors.top.serialize() == 'rgb(255 0 0)'
	assert box.border_colors.right.serialize() == 'rgb(0 128 0)'
	assert box.border_colors.bottom.serialize() == 'rgb(0 0 255)'
	assert box.border_colors.left.serialize() == 'rgb(0 0 0)'

	borders := box.paint_commands().filter(it.kind == 'draw_svg_path')
	assert borders.len == 4
	// C++ starts after the first color transition, then walks clockwise.
	assert borders.map(it.color) == ['rgb(0 128 0)', 'rgb(0 0 255)', 'rgb(0 0 0)', 'rgb(255 0 0)']
	assert borders.all(it.path_data.len > 0 && it.path_polygons.len == 1 && it.fill_even_odd)
}

fn test_inline_border_side_colors_reach_the_display_list() {
	doc := dom.Document.create(dom.url_about_blank())
	root := styled(doc, 'div', 'width: 200px')
	span := styled(doc, 'span', 'border-top: 1px solid red; border-right: 1px solid green; border-bottom: 1px solid blue; border-left: 1px solid black')
	mut span_node := span.as_node()
	span_node.append_child(doc.create_text_node('x').as_node()) or { panic('${err}') }
	mut root_node := root.as_node()
	root_node.append_child(span.as_node()) or { panic('${err}') }

	box := layout_block(root, 0, 0, 800, []&css.CSSRule{})
	fragment := box.lines[0].fragments[0]
	assert fragment.border_colors.right.serialize() == 'rgb(0 128 0)'
	borders := box.paint_commands().filter(it.kind == 'draw_svg_path')
	assert borders.len == 4
	assert borders.map(it.color) == ['rgb(0 128 0)', 'rgb(0 0 255)', 'rgb(0 0 0)', 'rgb(255 0 0)']
}

// Background paints first, then borders.
fn test_paint_background_then_border() {
	doc := dom.Document.create(dom.url_about_blank())
	el := styled(doc, 'div', 'width: 100px; height: 50px; border: 2px solid black; background-color: yellow')
	cmds := layout_block(el, 0, 0, 800, []&css.CSSRule{}).paint_commands()
	assert cmds.len == 2 // background + one joined border path
	assert cmds[0].color == 'rgb(255 255 0)' // yellow background first
	assert cmds[1].color == 'rgb(0 0 0)' // then black border
	assert cmds[1].kind == 'draw_svg_path'
}

fn test_uniform_rounded_border_is_a_single_joined_path() {
	doc := dom.Document.create(dom.url_about_blank())
	el := styled(doc, 'div', 'width: 100px; height: 50px; border: 3px solid red; border-radius: 12px; background: white')
	commands := layout_block(el, 0, 0, 800, []&css.CSSRule{}).paint_commands()
	borders := commands.filter(it.kind == 'draw_svg_path' && it.color == 'rgb(255 0 0)')
	assert borders.len == 1
	assert borders[0].path.contains('A 12 12')
	assert borders[0].path_data.len > 0
	assert borders[0].path_polygons.len == 4
	assert borders[0].fill_even_odd
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

// transform is a paint-time matrix and therefore leaves normal-flow geometry untouched.
fn test_transform_translate() {
	doc := dom.Document.create(dom.url_about_blank())
	root := styled(doc, 'div', 'width: 200px')
	first := styled(doc, 'div', 'height: 30px; transform: translate(15px, 25px)')
	second := styled(doc, 'div', 'height: 20px')
	mut rn := root.as_node()
	rn.append_child(first.as_node()) or { panic('${err}') }
	rn.append_child(second.as_node()) or { panic('${err}') }

	box := layout_block(root, 0, 0, 800, []&css.CSSRule{})
	assert box.children[0].x == 0.0
	assert box.children[0].y == 0.0
	assert box.children[0].paint_transform == [f64(1), 0, 0, 1, 15, 25]!
	assert box.children[1].y == 30.0 // second still flows after first's UNTRANSFORMED box

	assert box.height == 50.0 // container height from the flow, ignoring the transform
}

// translateX / translateY offset one axis only.
fn test_transform_translate_single_axis() {
	doc := dom.Document.create(dom.url_about_blank())
	x := styled(doc, 'div', 'width: 100px; height: 50px; transform: translateX(12px)')
	xb := layout_block(x, 0, 0, 800, []&css.CSSRule{})
	assert xb.x == 0.0
	assert xb.y == 0.0
	assert xb.paint_transform == [f64(1), 0, 0, 1, 12, 0]!

	y := styled(doc, 'div', 'width: 100px; height: 50px; transform: translateY(8px)')
	yb := layout_block(y, 0, 0, 800, []&css.CSSRule{})
	assert yb.x == 0.0
	assert yb.y == 0.0
	assert yb.paint_transform == [f64(1), 0, 0, 1, 0, 8]!
}

// The transform carries the box's text fragments along.
fn test_transform_moves_subtree() {
	doc := dom.Document.create(dom.url_about_blank())
	el := styled(doc, 'div', 'width: 200px; font-size: 20px; line-height: 30px; transform: translate(10px, 20px)')
	mut n := el.as_node()
	n.append_child(doc.create_text_node('hi').as_node()) or { panic('${err}') }
	box := layout_block(el, 0, 0, 800, []&css.CSSRule{})
	assert box.x == 0.0
	assert box.y == 0.0
	assert box.lines[0].fragments[0].x == 0.0
	assert box.lines[0].fragments[0].y == 0.0
	commands := box.paint_commands().filter(it.kind == 'draw_text')
	assert commands.len == 1
	assert commands[0].transform == [f64(1), 0, 0, 1, 10, 20]!
}

// transform_translate + parse_px_length parsing.
fn test_transform_translate_parse() {
	doc := dom.Document.create(dom.url_about_blank())
	assert parse_px_length('10px') == 10.0
	assert parse_px_length('-4px') == -4.0
	assert parse_px_length('0') == 0.0

	tx, ty := transform_translate(styled(doc, 'div', 'transform: translate(10px, 20px)'), 100, 100, []&css.CSSRule{})
	assert tx == 10.0 && ty == 20.0
	tx2, ty2 := transform_translate(styled(doc, 'div', 'transform: translateX(15px)'), 100, 100, []&css.CSSRule{})
	assert tx2 == 15.0 && ty2 == 0.0
	tx3, ty3 := transform_translate(styled(doc, 'div', ''), 100, 100, []&css.CSSRule{}) // none
	assert tx3 == 0.0 && ty3 == 0.0
}

fn test_transform_translate_resolves_percent_font_units_and_calc() {
	doc := dom.Document.create(dom.url_about_blank())
	element := styled(doc, 'div', 'width: 200px; height: 100px; font-size: 20px; transform: translate(10%, calc(1em + 5px))')
	tx, ty := transform_translate(element, 200, 100, []&css.CSSRule{})
	assert tx == 20
	assert ty == 25
	box := layout_block(element, 0, 0, 800, []&css.CSSRule{})
	assert box.x == 0
	assert box.y == 0
	assert box.paint_transform == [f64(1), 0, 0, 1, 20, 25]!

	assert resolve_length_token(element, '2em', 200, []&css.CSSRule{}) == 40
	assert resolve_length_token(element, 'calc(50% - 10px)', 200, []&css.CSSRule{}) == 90
}

fn test_transform_scale_rotate_matrix_lists_and_origin_are_transport_matrices() {
	doc := dom.Document.create(dom.url_about_blank())
	scaled := styled(doc, 'div', 'width: 100px; height: 50px; background: red; transform: scale(2); transform-origin: center')
	scaled_box := layout_block(scaled, 0, 0, 800, []&css.CSSRule{})
	assert scaled_box.paint_transform == [f64(2), 0, 0, 2, -50, -25]!
	assert scaled_box.paint_commands()[0].transform == scaled_box.paint_transform

	rotated := styled(doc, 'div', 'width: 100px; height: 50px; transform: rotate(90deg); transform-origin: left top')
	rotation := layout_block(rotated, 0, 0, 800, []&css.CSSRule{}).paint_transform
	assert math.abs(rotation[0]) < 0.000001
	assert math.abs(rotation[1] - 1) < 0.000001
	assert math.abs(rotation[2] + 1) < 0.000001
	assert math.abs(rotation[3]) < 0.000001
	assert rotation[4] == 0 && rotation[5] == 0

	listed := styled(doc, 'div', 'width: 100px; height: 50px; transform: translate(10px, 20px) scale(2); transform-origin: 0 0')
	assert layout_block(listed, 0, 0, 800, []&css.CSSRule{}).paint_transform == [
		f64(2),
		0,
		0,
		2,
		10,
		20,
	]!

	matrix := styled(doc, 'div', 'width: 100px; height: 50px; transform: matrix(1, 2, 3, 4, 5, 6); transform-origin: 0 0')
	assert layout_block(matrix, 0, 0, 800, []&css.CSSRule{}).paint_transform == [
		f64(1),
		2,
		3,
		4,
		5,
		6,
	]!
}

fn test_parent_transform_is_composed_into_descendant_paint_commands() {
	doc := dom.Document.create(dom.url_about_blank())
	root := styled(doc, 'div', 'width: 100px; transform: translateX(10px); transform-origin: 0 0')
	child := styled(doc, 'div', 'width: 20px; height: 20px; background: red; transform: scale(2); transform-origin: 0 0')
	mut root_node := root.as_node()
	root_node.append_child(child.as_node()) or { panic('${err}') }
	box := layout_block(root, 0, 0, 800, []&css.CSSRule{})
	assert box.children[0].paint_transform == [f64(2), 0, 0, 2, 10, 0]!
	commands := box.paint_commands().filter(it.kind == 'fill_rect')
	assert commands.len == 1
	assert commands[0].transform == [f64(2), 0, 0, 2, 10, 0]!
	svg := box.render_svg(100, 40)
	assert svg.contains('<g transform="matrix(2 0 0 2 10 0)">')
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

	assert svg.contains('font-size="20" textLength="17.328125" lengthAdjust="spacingAndGlyphs"')
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

fn test_inner_text_collapses_across_text_nodes_and_trims_line_edges() {
	doc := dom.Document.create(dom.url_about_blank())
	root := styled(doc, 'div', '')
	block := styled(doc, 'div', '')
	mut block_node := block.as_node()
	block_node.append_child(doc.create_text_node('  alpha ').as_node()) or { panic('${err}') }
	block_node.append_child(doc.create_text_node('   beta  ').as_node()) or { panic('${err}') }
	mut root_node := root.as_node()
	root_node.append_child(block.as_node()) or { panic('${err}') }

	assert inner_text(root, []&css.CSSRule{}) == 'alpha beta'
}

fn test_inner_text_applies_text_transform_and_inherited_visibility() {
	doc := dom.Document.create(dom.url_about_blank())
	root := styled(doc, 'div', 'text-transform: uppercase')
	hidden := styled(doc, 'span', 'visibility: hidden')
	reshown := styled(doc, 'span', 'visibility: visible')
	mut hidden_node := hidden.as_node()
	hidden_node.append_child(doc.create_text_node('hidden').as_node()) or { panic('${err}') }
	mut reshown_node := reshown.as_node()
	reshown_node.append_child(doc.create_text_node('shown').as_node()) or { panic('${err}') }
	hidden_node.append_child(reshown.as_node()) or { panic('${err}') }
	mut root_node := root.as_node()
	root_node.append_child(doc.create_text_node('before ').as_node()) or { panic('${err}') }
	root_node.append_child(hidden.as_node()) or { panic('${err}') }

	assert inner_text(root, []&css.CSSRule{}) == 'BEFORE SHOWN'
}

fn test_inner_text_table_cell_and_row_separators() {
	doc := dom.Document.create(dom.url_about_blank())
	table := styled(doc, 'table', '')
	mut table_node := table.as_node()
	for row_texts in [['a', 'b'], ['c', 'd']] {
		row := styled(doc, 'tr', '')
		mut row_node := row.as_node()
		for cell_text in row_texts {
			cell := styled(doc, 'td', '')
			mut cell_node := cell.as_node()
			cell_node.append_child(doc.create_text_node(cell_text).as_node()) or { panic('${err}') }
			row_node.append_child(cell.as_node()) or { panic('${err}') }
		}
		table_node.append_child(row.as_node()) or { panic('${err}') }
	}

	assert inner_text(table, []&css.CSSRule{}) == 'a\tb\nc\td'
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

fn test_text_transform_capitalize_skips_leading_punctuation() {
	assert capitalize_first_letter('“hello”') == '“Hello”'
	assert capitalize_first_letter('...élan') == '...Élan'
	assert capitalize_first_letter('123') == '123'
}

fn test_text_transform_full_width_and_full_size_kana() {
	assert apply_text_transform('Az 19!', 'full-width') == 'Ａｚ　１９！'
	assert apply_text_transform('ぁっゃァッャㇰ', 'full-size-kana') == 'あつやアツヤク'
	assert apply_text_transform('hello!', 'uppercase full-width') == 'ＨＥＬＬＯ！'
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

// text-decoration: underline (shorthand) marks the fragment and emits an underline near the
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
	underlines := cmds.filter(it.kind == 'draw_line')
	assert underlines.len == 1
	assert underlines[0].points[1] > frag.y + frag.height * 0.5 // near the baseline, below the middle

	assert underlines[0].points[2] - underlines[0].points[0] == math.round(frag.x + frag.width) - math.round(frag.x)
}

// text-decoration-line: line-through emits a strike through the middle of the text.
fn test_text_decoration_line_through() {
	doc := dom.Document.create(dom.url_about_blank())
	root := styled(doc, 'div', 'width: 500px; font-size: 20px; text-decoration-line: line-through')
	mut rn := root.as_node()
	rn.append_child(doc.create_text_node('gone').as_node()) or { panic('${err}') }

	box := layout_block(root, 0, 0, 800, []&css.CSSRule{})
	frag := box.lines[0].fragments[0]
	strikes := box.paint_commands().filter(it.kind == 'draw_line')
	assert strikes.len == 1
	// The strike sits around the vertical middle of the line.
	assert strikes[0].points[1] > frag.y && strikes[0].points[1] < frag.y + frag.height * 0.85
}

fn test_text_decoration_color_style_and_thickness() {
	doc := dom.Document.create(dom.url_about_blank())
	root := styled(doc, 'div', 'width: 500px; font-size: 20px; color: blue; text-decoration-line: underline; text-decoration-color: red; text-decoration-style: dashed; text-decoration-thickness: 3px')
	mut root_node := root.as_node()
	root_node.append_child(doc.create_text_node('decorated').as_node()) or { panic('${err}') }

	box := layout_block(root, 0, 0, 800, []&css.CSSRule{})
	fragment := box.lines[0].fragments[0]
	assert fragment.decoration_color.serialize() == 'rgb(255 0 0)'
	assert fragment.decoration_style == 'dashed'
	assert fragment.decoration_thickness == 3.0
	dashes := box.paint_commands().filter(it.kind == 'draw_line' && it.color == 'rgb(255 0 0)')
	assert dashes.len == 1
	assert dashes[0].line_style == 'dashed'
	assert dashes[0].stroke_width == 3.0
}

fn test_double_and_dotted_text_decoration_emit_their_distinct_geometry() {
	double_fragment := TextFragment{
		x: 0
		y: 0
		width: 30
		height: 20
		font_size: 20
		color: css.Color{0, 0, 0, 255}
		decoration: 'underline'
		decoration_color: css.Color{255, 0, 0, 255}
		decoration_color_set: true
		decoration_style: 'double'
		decoration_thickness: 2
	}
	double_commands := decoration_commands(double_fragment, 1)
	assert double_commands.len == 2
	assert double_commands.all(it.kind == 'draw_line' && it.stroke_width == 2)
	assert double_commands[1].points[1] - double_commands[0].points[1] == 3

	dotted_fragment := TextFragment{
		...double_fragment
		decoration_style: 'dotted'
	}
	dots := decoration_commands(dotted_fragment, 1)
	assert dots.len == 1
	assert dots[0].kind == 'draw_line'
	assert dots[0].line_style == 'dotted'
}

fn test_triangle_wave_path_matches_upstream_full_and_partial_wave_geometry() {
	path := build_triangle_wave_path(painting.IntPoint{0, 0}, painting.IntPoint{18, 0}, 6)
	assert path.segments.len == 6
	assert path.segments[0].kind == .move_to
	assert path.segments[1..].all(it.kind == .line_to)
	assert path.polygon == [
		painting.Point{0, 0},
		painting.Point{3, -3},
		painting.Point{9, 3},
		painting.Point{12, 0},
		painting.Point{15, -3},
		painting.Point{18, 0},
	]
}

fn test_spelling_and_grammar_error_decorations_use_upstream_ua_styles() {
	base := TextFragment{
		x: 0
		y: 0
		width: 30
		height: 20
		font_size: 20
		color: css.Color{0, 0, 0, 255}
		decoration_color: css.Color{0, 0, 255, 255}
		decoration_color_set: true
		decoration_style: 'double'
		decoration_thickness: 4
	}
	spelling := decoration_commands(TextFragment{
		...base
		decoration: 'spelling-error'
	}, 1)
	assert spelling.len == 1
	assert spelling[0].kind == 'draw_svg_path'
	assert spelling[0].stroke_color == 'rgb(255 0 0)'
	assert spelling[0].stroke_width == 1
	assert spelling[0].path_data.len > 0

	grammar := decoration_commands(TextFragment{
		...base
		decoration: 'grammar-error'
	}, 1)
	assert grammar.len == 1
	assert grammar[0].kind == 'draw_svg_path'
	assert grammar[0].stroke_color == 'rgb(0 100 0)'
	assert grammar[0].stroke_width == 1
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

fn test_inside_list_marker_flows_at_the_start_of_the_first_line() {
	doc := dom.Document.create(dom.url_about_blank())
	li := styled(doc, 'li', 'width: 300px; font-size: 20px; list-style-position: inside; text-align: left')
	mut li_node := li.as_node()
	li_node.append_child(doc.create_text_node('item').as_node()) or { panic('${err}') }

	box := layout_block(li, 0, 0, 300, []&css.CSSRule{})
	assert box.lines.len == 1
	assert box.lines[0].fragments.len == 2
	assert box.lines[0].fragments[0].text == '•'
	assert box.lines[0].fragments[0].x == box.x
	assert box.lines[0].fragments[1].text == 'item'
	assert box.lines[0].fragments[1].x > box.lines[0].fragments[0].x + box.lines[0].fragments[0].width
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

// Ordered-list HTML attributes control the list-item ordinal: start chooses the initial counter,
// value resets it, and reversed makes subsequent values decrease.
fn test_ordered_list_attribute_markers() {
	doc := dom.Document.create(dom.url_about_blank())
	mut root := styled(doc, 'ol', 'width: 300px; font-size: 20px')
	root.set_attribute_value('start', '20')
	mut rn := root.as_node()
	for i in 0 .. 5 {
		mut li := styled(doc, 'li', '')
		if i == 2 {
			li.set_attribute_value('value', '5')
		}
		rn.append_child(li.as_node()) or { panic('${err}') }
	}

	box := layout_block(root, 0, 0, 800, []&css.CSSRule{})
	mut markers := []string{}
	for child in box.children {
		markers << child.lines[0].fragments[0].text
	}
	assert markers == ['20.', '21.', '5.', '6.', '7.']
}

fn test_reversed_ordered_list_attribute_markers() {
	doc := dom.Document.create(dom.url_about_blank())
	mut root := styled(doc, 'ol', 'width: 300px; font-size: 20px')
	root.set_attribute_value('reversed', '')
	mut rn := root.as_node()
	for i in 0 .. 5 {
		mut li := styled(doc, 'li', '')
		if i == 2 {
			li.set_attribute_value('value', '5')
		}
		rn.append_child(li.as_node()) or { panic('${err}') }
	}

	box := layout_block(root, 0, 0, 800, []&css.CSSRule{})
	mut markers := []string{}
	for child in box.children {
		markers << child.lines[0].fragments[0].text
	}
	assert markers == ['5.', '4.', '5.', '4.', '3.']
}

fn test_ordered_list_invalid_integer_attributes_are_ignored() {
	doc := dom.Document.create(dom.url_about_blank())
	mut root := styled(doc, 'ol', 'width: 300px; font-size: 20px')
	root.set_attribute_value('start', 'not a number')
	first := styled(doc, 'li', '')
	mut second := styled(doc, 'li', '')
	second.set_attribute_value('value', '+')
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
	assert frag.width == 31.53125
}

// Negative letter-spacing tightens the advance.
fn test_negative_letter_spacing_tightens() {
	doc := dom.Document.create(dom.url_about_blank())
	root := styled(doc, 'div', 'width: 500px; font-size: 20px; letter-spacing: -2px')
	mut rn := root.as_node()
	rn.append_child(doc.create_text_node('ab').as_node()) or { panic('${err}') }

	box := layout_block(root, 0, 0, 800, []&css.CSSRule{})
	assert box.lines[0].fragments[0].width == 19.53125
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
	assert frags[1].x - frags[0].x == 27.6875
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

fn test_logical_edges_follow_direction_and_vertical_writing_mode() {
	doc := dom.Document.create(dom.url_about_blank())
	horizontal_rtl := styled(doc, 'div', 'direction: rtl; width: 100px; margin-inline-start: 13px; padding-inline-end: 7px')
	horizontal_box := layout_block(horizontal_rtl, 0, 0, 200, []&css.CSSRule{})
	assert horizontal_box.margin.right == 13.0
	assert horizontal_box.padding.left == 7.0

	vertical_ltr := styled(doc, 'div', 'writing-mode: vertical-rl; direction: ltr; width: 100px; padding-inline-start: 5px; padding-block-start: 11px')
	vertical_ltr_box := layout_block(vertical_ltr, 0, 0, 200, []&css.CSSRule{})
	assert vertical_ltr_box.padding.top == 5.0
	assert vertical_ltr_box.padding.right == 11.0

	vertical_rtl := styled(doc, 'div', 'writing-mode: vertical-lr; direction: rtl; width: 100px; padding-inline-start: 9px; padding-block-start: 3px')
	vertical_rtl_box := layout_block(vertical_rtl, 0, 0, 200, []&css.CSSRule{})
	assert vertical_rtl_box.padding.bottom == 9.0
	assert vertical_rtl_box.padding.left == 3.0
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

// A rounded background retains its corner geometry in the display list and SVG path.
fn test_border_radius_rounds_background() {
	doc := dom.Document.create(dom.url_about_blank())
	root := styled(doc, 'div', 'width: 100px; height: 50px; background-color: rgb(0, 128, 0); border-radius: 8px')
	box := layout_block(root, 0, 0, 800, []&css.CSSRule{})

	assert box.border_radius == 8.0
	fills := box.paint_commands().filter(it.kind == 'fill_rect' && it.radius > 0)
	assert fills.len == 1
	assert fills[0].radius == 8.0

	svg := box.render_svg(200, 200)
	assert svg.contains('rx="8" ry="8"')
}

// A radius larger than half the smaller dimension is clamped (a 50% pill on a 100x40 box -> 20px).
fn test_border_radius_clamped() {
	doc := dom.Document.create(dom.url_about_blank())
	root := styled(doc, 'div', 'width: 100px; height: 40px; background-color: rgb(0, 0, 0); border-radius: 999px')
	box := layout_block(root, 0, 0, 800, []&css.CSSRule{})

	fills := box.paint_commands().filter(it.kind == 'fill_rect' && it.radius > 0)
	assert fills[0].radius == 20.0 // clamped to min(100, 40)/2
}

// border-radius: 50% resolves against the border-box width, then clamps to half the smaller side.
fn test_border_radius_percentage() {
	doc := dom.Document.create(dom.url_about_blank())
	root := styled(doc, 'div', 'width: 80px; height: 80px; background-color: rgb(1, 2, 3); border-radius: 50%')
	box := layout_block(root, 0, 0, 800, []&css.CSSRule{})

	// 50% of 80 = 40, clamped to min(80,80)/2 = 40.
	fills := box.paint_commands().filter(it.kind == 'fill_rect' && it.radius > 0)
	assert fills[0].radius == 40.0
}

fn test_independent_elliptical_border_radii_are_resolved_and_painted() {
	doc := dom.Document.create(dom.url_about_blank())
	root := styled(doc, 'div', 'width: 100px; height: 50px; background: red; border: 2px solid black; border-radius: 10px 20px 30px 40px / 5px 10px 15px 20px')
	box := layout_block(root, 0, 0, 800, []&css.CSSRule{})
	assert box.border_radii.top_left == CornerRadius{10, 5}
	assert box.border_radii.top_right == CornerRadius{20, 10}
	assert box.border_radii.bottom_right == CornerRadius{30, 15}
	assert box.border_radii.bottom_left == CornerRadius{40, 20}
	commands := box.paint_commands()
	background := commands.filter(it.kind == 'fill_rounded_rect' && it.color == 'rgb(255 0 0)')
	assert background.len == 1
	assert background[0].corner_radii == box.border_radii
	border := commands.filter(it.kind == 'draw_svg_path' && it.color == 'rgb(0 0 0)')
	assert border.len == 1
	assert border[0].path.contains('A 10 5')
	assert border[0].path_data.len > 0
	assert border[0].path_polygons.len == 4
	assert border[0].fill_even_odd
	svg := box.render_svg(120, 70)
	assert svg.contains('<path d="M 10 0 L 84 0 A 20 10 0 0 1 104 10')
}

fn test_overlapping_corner_radii_are_scaled_by_one_common_factor() {
	doc := dom.Document.create(dom.url_about_blank())
	root := styled(doc, 'div', 'width: 100px; height: 40px; border-radius: 80px')
	box := layout_block(root, 0, 0, 800, []&css.CSSRule{})
	assert box.border_radii.top_left == CornerRadius{20, 20}
	assert box.border_radii.bottom_right == CornerRadius{20, 20}
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

// A solid outline uses BorderPainting.cpp's joined path outside the offset border box.
fn test_outline_paints_one_joined_path() {
	doc := dom.Document.create(dom.url_about_blank())
	root := styled(doc, 'div', 'width: 100px; height: 50px; outline: 3px solid rgb(255, 0, 0); outline-offset: 2px')
	box := layout_block(root, 0, 0, 800, []&css.CSSRule{})

	assert box.outline_width == 3.0
	assert box.outline_offset == 2.0
	outlines := box.paint_commands().filter(it.kind == 'draw_svg_path')
	assert outlines.len == 1
	assert outlines[0].color == 'rgb(255 0 0)'
	assert outlines[0].x == -5.0 // border_left(0) - offset(2) - width(3)
	assert outlines[0].y == -5.0
	assert outlines[0].width == 110.0 // 100 + 2*offset(2) + 2*width(3)
	assert outlines[0].height == 60.0
	assert outlines[0].path_polygons.len == 4
	assert outlines[0].fill_even_odd
}

// No outline by default (outline-style: none) -> only the background is painted.
fn test_no_outline_by_default() {
	doc := dom.Document.create(dom.url_about_blank())
	root := styled(doc, 'div', 'width: 50px; height: 50px; background-color: rgb(0, 0, 0)')
	box := layout_block(root, 0, 0, 800, []&css.CSSRule{})

	assert box.outline_width == 0.0
	assert box.paint_commands().filter(it.kind == 'fill_rect').len == 1 // just the background
}

// outline-width defaults to medium (3px) and outline-color defaults to currentColor (the text color).
fn test_outline_medium_and_current_color() {
	doc := dom.Document.create(dom.url_about_blank())
	root := styled(doc, 'div', 'width: 40px; height: 40px; outline-style: solid; color: rgb(0, 200, 0)')
	box := layout_block(root, 0, 0, 800, []&css.CSSRule{})

	assert box.outline_width == 3.0 // 'medium'

	outlines := box.paint_commands().filter(it.kind == 'draw_svg_path')
	assert outlines.len == 1
	assert outlines[0].color == 'rgb(0 200 0)' // currentColor
}

fn test_outline_styles_and_negative_offset_follow_border_painting() {
	doc := dom.Document.create(dom.url_about_blank())
	dashed := styled(doc, 'div', 'width: 100px; height: 50px; outline: 6px dashed rgb(10 90 40); outline-offset: -100px')
	dashed_box := layout_block(dashed, 0, 0, 800, []&css.CSSRule{})
	assert dashed_box.outline_style == .dashed
	dashed_commands := dashed_box.paint_commands().filter(it.color == 'rgb(10 90 40)')
	assert dashed_commands.len == 4
	assert dashed_commands.all(it.kind == 'draw_line' && it.line_style == 'dashed')
	// C++ clamps a too-negative offset to half the border-box size independently per axis.
	assert dashed_commands[0].points == [47.0, 22.0, 52.0, 22.0]
	assert dashed_commands[1].points[0] == 52.0

	double := styled(doc, 'div', 'width: 100px; height: 50px; outline: 9px double rgb(120 20 30); border-radius: 12px 6px')
	double_box := layout_block(double, 0, 0, 800, []&css.CSSRule{})
	assert double_box.outline_style == .double
	double_commands := double_box.paint_commands().filter(it.color == 'rgb(120 20 30)')
	assert double_commands.len == 8
	assert double_commands.all(it.kind == 'draw_svg_path' && it.path.contains('A '))

	automatic := styled(doc, 'div', 'width: 40px; height: 20px; outline-style: auto; outline-width: 10px; outline-color: red')
	automatic_box := layout_block(automatic, 0, 0, 800, []&css.CSSRule{})
	assert automatic_box.outline_width == 2
	assert automatic_box.outline_style == .solid
	automatic_commands := automatic_box.paint_commands().filter(it.paint_phase == .outline)
	assert automatic_commands.len == 1
	assert automatic_commands[0].color == 'rgb(61 174 233)'
}

// box-shadow: a source-shaped outer command carries the shadow and content geometry.
fn test_box_shadow_basic() {
	doc := dom.Document.create(dom.url_about_blank())
	root := styled(doc, 'div', 'width: 100px; height: 50px; box-shadow: 4px 6px 8px rgb(0, 0, 0)')
	box := layout_block(root, 0, 0, 800, []&css.CSSRule{})

	sh := box.shadow or { panic('no shadow') }
	assert sh.offset_x == 4.0
	assert sh.offset_y == 6.0
	assert sh.blur == 8.0

	shadows := box.paint_commands().filter(it.kind == 'paint_outer_box_shadow')
	assert shadows.len == 1

	assert shadows[0].x == 4.0
	assert shadows[0].y == 6.0
	assert shadows[0].blur == 8.0
	assert shadows[0].color == 'rgb(0 0 0)'
	assert shadows[0].shadow_content_width == 100.0
	assert shadows[0].shadow_content_height == 50.0
}

// PaintableBox::paint() records the background before its box-shadow list.
fn test_box_shadow_is_recorded_after_background_like_source() {
	doc := dom.Document.create(dom.url_about_blank())
	root := styled(doc, 'div', 'width: 50px; height: 50px; background-color: rgb(0, 128, 0); box-shadow: 2px 2px rgb(0, 0, 0)')
	box := layout_block(root, 0, 0, 800, []&css.CSSRule{})

	commands := box.paint_commands()
	mut background_index := -1
	mut shadow_index := -1
	for index, command in commands {
		if command.kind == 'fill_rect' && command.color == 'rgb(0 128 0)' {
			background_index = index
		} else if command.kind == 'paint_outer_box_shadow' {
			shadow_index = index
		}
	}
	assert background_index >= 0
	assert shadow_index > background_index
	assert commands[shadow_index].color == 'rgb(0 0 0)'
	assert commands[shadow_index].blur == 0.0
}

fn test_multiple_outer_box_shadows_are_parsed_and_painted_in_order() {
	doc := dom.Document.create(dom.url_about_blank())
	root := styled(doc, 'div', 'width: 50px; height: 40px; box-shadow: 1px 2px 3px red, -4px 5px 0 2px blue')
	box := layout_block(root, 0, 0, 800, []&css.CSSRule{})

	assert box.shadows.len == 2
	assert box.shadows[0].offset_x == 1.0
	assert box.shadows[1].offset_x == -4.0
	assert box.shadows[1].spread == 2.0
	shadows := box.paint_commands().filter(it.kind == 'paint_outer_box_shadow')
	assert shadows.len == 2
	// CSS stores layers front-to-back; ShadowPainting paints them in reverse.
	assert shadows[0].color == 'rgb(0 0 255)'
	assert shadows[1].color == 'rgb(255 0 0)'
}

fn test_inset_box_shadow_is_clipped_to_the_padding_edge() {
	doc := dom.Document.create(dom.url_about_blank())
	root := styled(doc, 'div', 'width: 50px; height: 40px; border: 2px solid black; border-radius: 8px; background: white; box-shadow: inset 3px -2px 4px 1px red')
	box := layout_block(root, 0, 0, 800, []&css.CSSRule{})
	assert box.shadows.len == 1 && box.shadows[0].inset
	commands := box.paint_commands()
	assert commands.filter(it.kind == 'paint_inner_box_shadow').len == 1
	shadow := commands.filter(it.kind == 'paint_inner_box_shadow')[0]
	assert shadow.shadow_content_x == 2.0 && shadow.shadow_content_y == 2.0
	assert shadow.shadow_content_width == 50.0 && shadow.shadow_content_height == 40.0
	assert shadow.shadow_inner_x == 6.0 && shadow.shadow_inner_y == 1.0
	assert shadow.shadow_inner_width == 48.0 && shadow.shadow_inner_height == 38.0
	// An inset shadow is not emitted as an outer fill behind the box.
	assert commands.filter(it.kind == 'paint_outer_box_shadow').len == 0
	svg := box.render_svg(100, 100)
	assert svg.contains('<clipPath id="inner-shadow-scoped')
	assert svg.contains('<filter id="inner-shadow-blur')
}

// The spread radius expands the shadow rect outward on all sides.
fn test_box_shadow_spread() {
	doc := dom.Document.create(dom.url_about_blank())
	root := styled(doc, 'div', 'width: 100px; height: 40px; box-shadow: 0px 0px 0px 5px rgb(1, 2, 3)')
	box := layout_block(root, 0, 0, 800, []&css.CSSRule{})

	sh := box.shadow or { panic('no shadow') }
	assert sh.spread == 5.0
	shadows := box.paint_commands().filter(it.kind == 'paint_outer_box_shadow')
	assert shadows[0].x == -5.0 // 0 - spread

	assert shadows[0].width == 110.0 // 100 + 2*spread
}

// A blurred shadow gets a Gaussian-blur filter in the SVG; no shadow -> no filter.
fn test_box_shadow_svg_blur_filter() {
	doc := dom.Document.create(dom.url_about_blank())
	shadowed := styled(doc, 'div', 'width: 50px; height: 50px; box-shadow: 2px 2px 6px rgb(0, 0, 0)')
	svg := layout_block(shadowed, 0, 0, 800, []&css.CSSRule{}).render_svg(200, 200)
	assert svg.contains('<filter id="outer-shadow-blur')
	assert svg.contains('feGaussianBlur')
	assert svg.contains('filter="url(#outer-shadow-blur')

	plain := styled(doc, 'div', 'width: 50px; height: 50px; background-color: rgb(0, 0, 0)')
	plain_box := layout_block(plain, 0, 0, 800, []&css.CSSRule{})
	assert plain_box.paint_commands().filter(it.kind == 'fill_rect').len == 1 // no shadow rect

	assert !plain_box.render_svg(100, 100).contains('feGaussianBlur')
}

// A linear-gradient background parses to a gradient (direction + stop colors) and emits a
// fill_gradient command that renders to an SVG <linearGradient>.
fn test_linear_gradient_background() {
	doc := dom.Document.create(dom.url_about_blank())
	root := styled(doc, 'div', 'width: 100px; height: 50px; background: linear-gradient(to right, rgb(255, 0, 0), rgb(0, 0, 255))')
	box := layout_block(root, 0, 0, 800, []&css.CSSRule{})

	grad := box.background_gradient or { panic('no gradient') }
	assert grad.x1 == 0.0 && grad.x2 == 1.0 && grad.y1 == 0.0 && grad.y2 == 0.0 // to right

	assert grad.colors.len == 2
	assert grad.colors[0].serialize() == 'rgb(255 0 0)'
	assert grad.colors[1].serialize() == 'rgb(0 0 255)'

	cmds := box.paint_commands()
	assert cmds.filter(it.kind == 'fill_gradient').len == 1

	svg := box.render_svg(200, 200)
	assert svg.contains('<linearGradient id="grad0"')
	assert svg.contains('stop-color="rgb(255 0 0)"')
	assert svg.contains('stop-color="rgb(0 0 255)"')
	assert svg.contains('fill="url(#grad0)"')
}

fn test_url_background_image_layers_reach_display_list_with_box_metadata() {
	doc := dom.Document.create(dom.url_about_blank())
	el := styled(doc, 'div', 'width: 100px; height: 50px; padding: 10px; border: 5px solid; border-radius: 20px / 10px; background-image: url("data:image/png;base64,AA=="); background-repeat: no-repeat; background-size: contain; background-position: center; background-origin: content-box; background-clip: padding-box')
	box := layout_block(el, 0, 0, 800, []&css.CSSRule{})
	assert box.background_images.len == 1
	commands := box.paint_commands().filter(it.kind == 'draw_background_image')
	assert commands.len == 1
	assert commands[0].image_url == 'data:image/png;base64,AA=='
	assert commands[0].image_repeat_x == 'no-repeat'
	assert commands[0].image_repeat_y == 'no-repeat'
	assert commands[0].image_size == 'contain'
	assert commands[0].x == 15 && commands[0].y == 15
	assert commands[0].width == 100 && commands[0].height == 50
	assert commands[0].image_clip_x == 5 && commands[0].image_clip_y == 5
	assert commands[0].image_clip_width == 120 && commands[0].image_clip_height == 70
	assert commands[0].image_clip_radii.top_left == CornerRadius{15, 5}
	assert commands[0].image_clip_radii.bottom_right == CornerRadius{15, 5}
	svg := box.render_svg(140, 90)
	assert svg.contains('<image href="data:image/png;base64,AA=="')
	assert svg.contains('preserveAspectRatio="xMidYMid meet"')
	assert svg.contains('<clipPath id="imageclip0"><path d="M')
}

fn test_background_attachment_offsets_are_refreshed_during_retained_replay() {
	box := &BlockBox{
		overlay: CompatibilityOverlayData{
			scroll_offset_x: 7
			scroll_offset_y: 9
		}
	}
	mut command := PaintCommand{ kind: 'draw_background_image' }
	apply_live_background_offsets(mut command, box, painting.Point{11, 13})
	assert command.image_scroll_offset_x == 7
	assert command.image_scroll_offset_y == 9
	assert command.image_viewport_offset_x == 11
	assert command.image_viewport_offset_y == 13
	mut gradient_command := PaintCommand{
		kind: 'fill_gradient'
		gradient_background_layer: true
	}
	apply_live_background_offsets(mut gradient_command, box, painting.Point{11, 13})
	assert gradient_command.image_scroll_offset_x == 7
	assert gradient_command.image_scroll_offset_y == 9
	assert gradient_command.image_viewport_offset_x == 11
	assert gradient_command.image_viewport_offset_y == 13
}

fn text_clip_test_box(text string) BlockBox {
	return BlockBox{
		paintable_with_lines: true
		lines: [
			TextLine{
				fragments: [
					TextFragment{
						x: 10
						y: 12
						width: 40
						height: 20
						text: text
						color: css.Color{0, 0, 0, 255}
						font_size: 16
					},
				]
			},
		]
	}
}

fn test_background_clip_text_uses_inclusive_in_flow_and_floating_glyph_runs() {
	mut in_flow := text_clip_test_box('flow')
	mut floating := text_clip_test_box('float')
	floating.floating = true
	mut absolute := text_clip_test_box('absolute')
	absolute.absolutely_positioned = true
	absolute.children = [text_clip_test_box('absolute-child')]
	box := BlockBox{
		width: 100
		height: 60
		background_color: css.Color{255, 0, 0, 255}
		background_color_clip: 'text'
		paintable_with_lines: true
		lines: text_clip_test_box('own').lines
		children: [in_flow, floating, absolute]
	}
	commands := box.paint_commands()
	begin_commands := commands.filter(it.kind == 'begin_background_text_clip')
	assert begin_commands.len == 1
	run_text := begin_commands[0].text_clip_runs.map(it.text)
	assert run_text == ['own', 'flow', 'float']
	mut background_sequence := []string{}
	for command in commands {
		if command.kind in ['begin_background_text_clip', 'end_background_text_clip']
			|| (command.kind == 'fill_rect' && command.color == 'rgb(255 0 0)') {
			background_sequence << command.kind
		}
	}
	assert background_sequence == ['begin_background_text_clip', 'fill_rect',
		'end_background_text_clip']
	svg := box.render_svg(120, 80)
	assert svg.contains('<mask id="background-text-mask0"')
	assert svg.contains('fill="white">own</text>')
	assert svg.contains('<g mask="url(#background-text-mask0)">')

	root := BlockBox{
		width: 100
		height: 60
		background_color: css.Color{255, 0, 0, 255}
		background_color_clip: 'text'
		paints_canvas_background: true
		canvas_width: 120
		canvas_height: 80
		paintable_with_lines: true
		lines: text_clip_test_box('root').lines
	}
	assert root.paint_commands().all(it.kind != 'begin_background_text_clip')
}

fn test_multiple_url_background_layers_paint_back_to_front_and_coordinate_lists() {
	doc := dom.Document.create(dom.url_about_blank())
	el := styled(doc, 'div', 'width: 40px; height: 40px; background-image: url("back.png"), url("front.png"); background-repeat: no-repeat, repeat-x')
	box := layout_block(el, 0, 0, 800, []&css.CSSRule{})
	assert box.background_images.len == 2
	commands := box.paint_commands().filter(it.kind == 'draw_background_image')
	assert commands.len == 2
	assert commands[0].image_url.ends_with('front.png')
	assert commands[0].image_repeat_x == 'repeat'
	assert commands[0].image_repeat_y == 'no-repeat'
	assert commands[1].image_url.ends_with('back.png')
	assert commands[1].image_repeat_x == 'no-repeat'
	assert commands[1].image_repeat_y == 'no-repeat'
}

// The `to bottom` direction is the default and gives a top-to-bottom vector; three stops space evenly.
fn test_linear_gradient_default_direction_and_stops() {
	doc := dom.Document.create(dom.url_about_blank())
	root := styled(doc, 'div', 'width: 40px; height: 40px; background-image: linear-gradient(red, green, blue)')
	box := layout_block(root, 0, 0, 800, []&css.CSSRule{})

	grad := box.background_gradient or { panic('no gradient') }
	assert grad.x1 == 0.0 && grad.y1 == 0.0 && grad.x2 == 0.0 && grad.y2 == 1.0 // default: to bottom

	assert grad.colors.len == 3

	svg := box.render_svg(100, 100)
	// Three stops at 0%, 50%, 100%.
	assert svg.contains('offset="0%"')
	assert svg.contains('offset="50%"')
	assert svg.contains('offset="100%"')
}

fn test_linear_gradient_angles_corners_and_explicit_stop_positions() {
	doc := dom.Document.create(dom.url_about_blank())
	corner := styled(doc, 'div', 'width: 100px; height: 50px; background-image: linear-gradient(to top right, red 10%, green, blue 80% 90%)')
	corner_gradient := layout_block(corner, 0, 0, 800, []&css.CSSRule{}).background_gradient or {
		panic('no corner gradient')
	}

	assert corner_gradient.x1 == 0.0 && corner_gradient.y1 == 1.0
	assert corner_gradient.x2 == 1.0 && corner_gradient.y2 == 0.0
	assert corner_gradient.stops.len == 4
	assert corner_gradient.stops[0].offset > 0.099 && corner_gradient.stops[0].offset < 0.101
	assert corner_gradient.stops[1].offset > 0.449 && corner_gradient.stops[1].offset < 0.451
	assert corner_gradient.stops[2].offset > 0.799 && corner_gradient.stops[2].offset < 0.801
	assert corner_gradient.stops[3].offset > 0.899 && corner_gradient.stops[3].offset < 0.901

	angled := styled(doc, 'div', 'width: 100px; height: 50px; background-image: linear-gradient(90deg, red, blue)')
	angle_gradient := layout_block(angled, 0, 0, 800, []&css.CSSRule{}).background_gradient or {
		panic('no angle gradient')
	}

	assert angle_gradient.x1 > -0.001 && angle_gradient.x1 < 0.001
	assert angle_gradient.x2 > 0.999 && angle_gradient.x2 < 1.001
	assert angle_gradient.y1 > 0.499 && angle_gradient.y1 < 0.501
	assert angle_gradient.y2 > 0.499 && angle_gradient.y2 < 0.501
}

// No gradient by default -> no fill_gradient command, no <linearGradient>.
fn test_no_gradient_by_default() {
	doc := dom.Document.create(dom.url_about_blank())
	root := styled(doc, 'div', 'width: 40px; height: 40px; background-color: rgb(1, 2, 3)')
	box := layout_block(root, 0, 0, 800, []&css.CSSRule{})

	assert box.paint_commands().filter(it.kind == 'fill_gradient').len == 0
	assert !box.render_svg(100, 100).contains('<linearGradient')
}

// resolved_style_value returns USED px for layout-dependent box metrics (a percentage width resolves
// against the container), and delegates other properties to the computed value.
fn test_resolved_style_value_used_metrics() {
	doc := dom.Document.create(dom.url_about_blank())
	root := styled(doc, 'div', 'width: 200px')
	child := styled(doc, 'div', 'width: 50%; height: 30px; padding: 10px; margin-left: 5px; border-top: 2px solid; color: rgb(1, 2, 3)')
	mut rn := root.as_node()
	rn.append_child(child.as_node()) or { panic('${err}') }
	no := []&css.CSSRule{}

	box := layout_block(root, 0, 0, 800, no)
	// Layout-dependent -> used px (width:50% of the 200px container = 100px).
	assert box.resolved_style_value(child, 'width', no) == '100px'
	assert box.resolved_style_value(child, 'height', no) == '30px'
	assert box.resolved_style_value(child, 'padding-left', no) == '10px'
	assert box.resolved_style_value(child, 'margin-left', no) == '5px'
	assert box.resolved_style_value(child, 'border-top-width', no) == '2px'
	// A non-layout property delegates to the computed value.
	assert box.resolved_style_value(child, 'color', no) == 'rgb(1 2 3)'
}

// For an element not in the box tree, resolved_style_value falls back to the layout-free computed
// value (so width returns the specified `auto`, font-size its computed px).
fn test_resolved_style_value_orphan_falls_back() {
	doc := dom.Document.create(dom.url_about_blank())
	orphan := styled(doc, 'div', 'font-size: 24px')
	no := []&css.CSSRule{}
	box := layout_block(styled(doc, 'div', 'width: 100px'), 0, 0, 800, no)

	assert box.resolved_style_value(orphan, 'font-size', no) == '24px'
	assert box.resolved_style_value(orphan, 'width', no) == 'auto'
}

// display: flex lays items along a row (side by side) instead of stacking them.
fn test_flex_row_basic() {
	doc := dom.Document.create(dom.url_about_blank())
	root := styled(doc, 'div', 'display: flex; width: 400px; height: 50px')
	a := styled(doc, 'div', 'width: 100px; height: 30px')
	b := styled(doc, 'div', 'width: 80px; height: 40px')
	mut rn := root.as_node()
	rn.append_child(a.as_node()) or { panic('${err}') }
	rn.append_child(b.as_node()) or { panic('${err}') }

	box := layout_block(root, 0, 0, 800, []&css.CSSRule{})
	assert box.children.len == 2
	assert box.children[0].x == 0.0 && box.children[0].width == 100.0
	assert box.children[1].x == 100.0 && box.children[1].width == 80.0 // after a's 100px

	assert box.children[0].y == 0.0 && box.children[1].y == 0.0 // both at the cross-start (top)
}

fn test_flex_row_reverse_places_main_start_at_the_right_edge() {
	doc := dom.Document.create(dom.url_about_blank())
	root := styled(doc, 'div', 'display: flex; flex-direction: row-reverse; gap: 10px; width: 300px; height: 20px')
	a := styled(doc, 'div', 'width: 60px; height: 20px')
	b := styled(doc, 'div', 'width: 40px; height: 20px')
	mut rn := root.as_node()
	rn.append_child(a.as_node()) or { panic('${err}') }
	rn.append_child(b.as_node()) or { panic('${err}') }

	box := layout_block(root, 0, 0, 800, []&css.CSSRule{})
	assert box.children[0].x == 240.0
	assert box.children[1].x == 190.0
}

fn test_flex_row_reverse_justifies_from_the_reversed_main_start() {
	doc := dom.Document.create(dom.url_about_blank())
	root := styled(doc, 'div', 'display: flex; flex-direction: row-reverse; justify-content: flex-end; width: 300px; height: 20px')
	a := styled(doc, 'div', 'width: 100px; height: 20px')
	b := styled(doc, 'div', 'width: 100px; height: 20px')
	mut rn := root.as_node()
	rn.append_child(a.as_node()) or { panic('${err}') }
	rn.append_child(b.as_node()) or { panic('${err}') }

	box := layout_block(root, 0, 0, 800, []&css.CSSRule{})
	assert box.children[0].x == 100.0
	assert box.children[1].x == 0.0
}

// An auto-width flex item shrinks to its content (max-content) rather than filling the container.
fn test_flex_item_auto_width_shrinks_to_fit() {
	doc := dom.Document.create(dom.url_about_blank())
	root := styled(doc, 'div', 'display: flex; width: 400px; font-size: 20px')
	item := styled(doc, 'div', '')
	mut inode := item.as_node()
	inode.append_child(doc.create_text_node('hi').as_node()) or { panic('${err}') }
	mut rn := root.as_node()
	rn.append_child(item.as_node()) or { panic('${err}') }

	box := layout_block(root, 0, 0, 800, []&css.CSSRule{})
	assert box.children[0].width == 17.328125 // shaped max-content width, not the container
}

// Flex items pack by their margin box.
fn test_flex_items_pack_by_margin_box() {
	doc := dom.Document.create(dom.url_about_blank())
	root := styled(doc, 'div', 'display: flex; width: 400px; height: 50px')
	a := styled(doc, 'div', 'width: 50px; height: 20px; margin-right: 10px')
	b := styled(doc, 'div', 'width: 60px; height: 20px')
	mut rn := root.as_node()
	rn.append_child(a.as_node()) or { panic('${err}') }
	rn.append_child(b.as_node()) or { panic('${err}') }

	box := layout_block(root, 0, 0, 800, []&css.CSSRule{})
	assert box.children[0].x == 0.0
	assert box.children[1].x == 60.0 // after a's margin box (50 + 10)
}

// A flex container with auto height takes the tallest item's margin-box height.
fn test_flex_container_height_is_tallest_item() {
	doc := dom.Document.create(dom.url_about_blank())
	root := styled(doc, 'div', 'display: flex; width: 400px')
	a := styled(doc, 'div', 'width: 50px; height: 30px')
	b := styled(doc, 'div', 'width: 50px; height: 45px')
	mut rn := root.as_node()
	rn.append_child(a.as_node()) or { panic('${err}') }
	rn.append_child(b.as_node()) or { panic('${err}') }

	box := layout_block(root, 0, 0, 800, []&css.CSSRule{})
	assert box.height == 45.0
}

// Build a 300px flex row with two 100px items and the given justify-content, returning the item xs.
fn jc_item_xs(justify string) (f64, f64) {
	doc := dom.Document.create(dom.url_about_blank())
	root := styled(doc, 'div', 'display: flex; justify-content: ${justify}; width: 300px; height: 20px')
	a := styled(doc, 'div', 'width: 100px; height: 20px')
	b := styled(doc, 'div', 'width: 100px; height: 20px')
	mut rn := root.as_node()
	rn.append_child(a.as_node()) or { panic('${err}') }
	rn.append_child(b.as_node()) or { panic('${err}') }
	box := layout_block(root, 0, 0, 800, []&css.CSSRule{})
	return box.children[0].x, box.children[1].x
}

// justify-content distributes the 100px of free space (300 container - 200 items) along the row.
fn test_justify_content_distributions() {
	// flex-end packs both items at the end.
	a0, a1 := jc_item_xs('flex-end')
	assert a0 == 100.0 && a1 == 200.0
	// center offsets both by half the free space.
	b0, b1 := jc_item_xs('center')
	assert b0 == 50.0 && b1 == 150.0
	// space-between: first at start, last at end.
	c0, c1 := jc_item_xs('space-between')
	assert c0 == 0.0 && c1 == 200.0
	// space-around: half-gaps at the ends (free/n/2 = 25 leading, then a 50 gap).
	d0, d1 := jc_item_xs('space-around')
	assert d0 == 25.0 && d1 == 175.0
	// default (normal -> flex-start): packed at the start.
	e0, e1 := jc_item_xs('flex-start')
	assert e0 == 0.0 && e1 == 100.0
}

// Build a 60px-tall flex row with a 20px and a 40px item and the given align-items; return item ys.
fn ai_item_ys(align string) (f64, f64) {
	doc := dom.Document.create(dom.url_about_blank())
	root := styled(doc, 'div', 'display: flex; align-items: ${align}; width: 300px; height: 60px')
	a := styled(doc, 'div', 'width: 50px; height: 20px')
	b := styled(doc, 'div', 'width: 50px; height: 40px')
	mut rn := root.as_node()
	rn.append_child(a.as_node()) or { panic('${err}') }
	rn.append_child(b.as_node()) or { panic('${err}') }
	box := layout_block(root, 0, 0, 800, []&css.CSSRule{})
	return box.children[0].y, box.children[1].y
}

// align-items positions items on the cross axis within the container's 60px height.
fn test_align_items() {
	// stretch (default, minimal top-aligns): both at the top.
	s0, s1 := ai_item_ys('stretch')
	assert s0 == 0.0 && s1 == 0.0
	// center: each centered within the 60px cross size.
	c0, c1 := ai_item_ys('center')
	assert c0 == 20.0 && c1 == 10.0 // (60-20)/2, (60-40)/2

	// flex-end: bottom-aligned.
	e0, e1 := ai_item_ys('flex-end')
	assert e0 == 40.0 && e1 == 20.0 // 60-20, 60-40

	// flex-start: top-aligned.
	f0, f1 := ai_item_ys('flex-start')
	assert f0 == 0.0 && f1 == 0.0
}

// align-self on an item overrides the container's align-items.
fn test_align_self_overrides_align_items() {
	doc := dom.Document.create(dom.url_about_blank())
	root := styled(doc, 'div', 'display: flex; align-items: flex-start; width: 300px; height: 60px')
	a := styled(doc, 'div', 'width: 50px; height: 20px')
	b := styled(doc, 'div', 'width: 50px; height: 20px; align-self: flex-end')
	mut rn := root.as_node()
	rn.append_child(a.as_node()) or { panic('${err}') }
	rn.append_child(b.as_node()) or { panic('${err}') }

	box := layout_block(root, 0, 0, 800, []&css.CSSRule{})
	assert box.children[0].y == 0.0 // container flex-start

	assert box.children[1].y == 40.0 // align-self flex-end -> 60 - 20
}

// gap adds fixed spacing between flex items along the main axis.
fn test_flex_gap_basic() {
	doc := dom.Document.create(dom.url_about_blank())
	root := styled(doc, 'div', 'display: flex; gap: 20px; width: 300px; height: 20px')
	a := styled(doc, 'div', 'width: 100px; height: 20px')
	b := styled(doc, 'div', 'width: 100px; height: 20px')
	mut rn := root.as_node()
	rn.append_child(a.as_node()) or { panic('${err}') }
	rn.append_child(b.as_node()) or { panic('${err}') }

	box := layout_block(root, 0, 0, 800, []&css.CSSRule{})
	assert box.children[0].x == 0.0
	assert box.children[1].x == 120.0 // 100px item + 20px gap
}

// gap and justify-content compose: the gap is fixed spacing, justify distributes the remaining space.
fn test_flex_gap_with_center() {
	doc := dom.Document.create(dom.url_about_blank())
	root := styled(doc, 'div', 'display: flex; gap: 20px; justify-content: center; width: 300px; height: 20px')
	a := styled(doc, 'div', 'width: 100px; height: 20px')
	b := styled(doc, 'div', 'width: 100px; height: 20px')
	mut rn := root.as_node()
	rn.append_child(a.as_node()) or { panic('${err}') }
	rn.append_child(b.as_node()) or { panic('${err}') }

	box := layout_block(root, 0, 0, 800, []&css.CSSRule{})
	// items+gap = 220; free = 80; center leading = 40.
	assert box.children[0].x == 40.0
	assert box.children[1].x == 160.0 // 40 + 100 + 20 gap
}

// flex-grow distributes the free main space to items in proportion to their grow factors.
fn test_flex_grow_distributes_free_space() {
	doc := dom.Document.create(dom.url_about_blank())
	// Container 300px; two items with flex-grow 1 and 2, base 0 (flex: N -> basis 0%). Free = 300.
	root := styled(doc, 'div', 'display: flex; width: 300px; height: 20px')
	a := styled(doc, 'div', 'flex: 1; height: 20px')
	b := styled(doc, 'div', 'flex: 2; height: 20px')
	mut rn := root.as_node()
	rn.append_child(a.as_node()) or { panic('${err}') }
	rn.append_child(b.as_node()) or { panic('${err}') }

	box := layout_block(root, 0, 0, 800, []&css.CSSRule{})
	// 300 split 1:2 -> 100 and 200; they fill the container edge to edge.
	assert box.children[0].width == 100.0
	assert box.children[1].width == 200.0
	assert box.children[0].x == 0.0 && box.children[1].x == 100.0
}

// flex-grow adds to a non-zero base size (flex-basis) rather than replacing it.
fn test_flex_grow_adds_to_basis() {
	doc := dom.Document.create(dom.url_about_blank())
	// Container 300; two items, base 50px each (100 used), free 200 split 1:1 -> +100 each -> 150 each.
	root := styled(doc, 'div', 'display: flex; width: 300px; height: 20px')
	a := styled(doc, 'div', 'flex: 1 1 50px; height: 20px')
	b := styled(doc, 'div', 'flex: 1 1 50px; height: 20px')
	mut rn := root.as_node()
	rn.append_child(a.as_node()) or { panic('${err}') }
	rn.append_child(b.as_node()) or { panic('${err}') }

	box := layout_block(root, 0, 0, 800, []&css.CSSRule{})
	assert box.children[0].width == 150.0
	assert box.children[1].width == 150.0
}

fn test_flex_border_box_basis_is_converted_to_content_space() {
	doc := dom.Document.create(dom.url_about_blank())
	root := styled(doc, 'div', 'display: flex; width: 300px; height: 40px')
	a := styled(doc, 'div', 'box-sizing: border-box; flex: 0 0 100px; padding: 10px; border: 5px solid; height: 40px')
	b := styled(doc, 'div', 'flex: 0 0 50px; height: 40px')
	mut rn := root.as_node()
	rn.append_child(a.as_node()) or { panic('${err}') }
	rn.append_child(b.as_node()) or { panic('${err}') }

	box := layout_block(root, 0, 0, 800, []&css.CSSRule{})
	assert box.children[0].width == 70.0
	assert box.children[0].margin_box_width() == 100.0
	assert box.children[1].x == 100.0
}

fn test_flex_minimum_violation_freezes_and_redistributes_remaining_space() {
	doc := dom.Document.create(dom.url_about_blank())
	root := styled(doc, 'div', 'display: flex; width: 100px; height: 20px')
	a := styled(doc, 'div', 'flex: 0 1 80px; min-width: 70px; height: 20px')
	b := styled(doc, 'div', 'flex: 0 1 80px; min-width: 0; height: 20px')
	mut rn := root.as_node()
	rn.append_child(a.as_node()) or { panic('${err}') }
	rn.append_child(b.as_node()) or { panic('${err}') }

	box := layout_block(root, 0, 0, 800, []&css.CSSRule{})
	assert box.children[0].width == 70.0
	assert box.children[1].width == 30.0
}

fn test_flex_grow_factor_below_one_leaves_part_of_free_space_unfilled() {
	doc := dom.Document.create(dom.url_about_blank())
	root := styled(doc, 'div', 'display: flex; width: 100px; height: 20px')
	item := styled(doc, 'div', 'flex: 0.5 1 20px; min-width: 0; height: 20px')
	mut rn := root.as_node()
	rn.append_child(item.as_node()) or { panic('${err}') }

	box := layout_block(root, 0, 0, 800, []&css.CSSRule{})
	assert box.children[0].width == 60.0
}

fn test_flex_automatic_minimum_is_content_based_unless_item_scrolls() {
	doc := dom.Document.create(dom.url_about_blank())
	root := styled(doc, 'div', 'display: flex; width: 100px; font-size: 20px')
	a := styled(doc, 'div', 'flex: 1 1 0')
	b := styled(doc, 'div', 'flex: 1 1 0; overflow: auto')
	mut an := a.as_node()
	an.append_child(doc.create_text_node('abcdefgh').as_node()) or { panic('${err}') }
	mut bn := b.as_node()
	bn.append_child(doc.create_text_node('abcdefgh').as_node()) or { panic('${err}') }
	mut rn := root.as_node()
	rn.append_child(a.as_node()) or { panic('${err}') }
	rn.append_child(b.as_node()) or { panic('${err}') }

	box := layout_block(root, 0, 0, 800, []&css.CSSRule{})
	assert box.children[0].width == 84.5
	assert box.children[1].width == 15.5
}

// flex-shrink reduces items (weighted by base size) when they overflow the container.
fn test_flex_shrink_on_overflow() {
	doc := dom.Document.create(dom.url_about_blank())
	// Container 300; two 200px items (400 total, overflow 100). Equal base+shrink -> each loses 50 -> 150.
	root := styled(doc, 'div', 'display: flex; width: 300px; height: 20px')
	a := styled(doc, 'div', 'width: 200px; flex-shrink: 1; height: 20px')
	b := styled(doc, 'div', 'width: 200px; flex-shrink: 1; height: 20px')
	mut rn := root.as_node()
	rn.append_child(a.as_node()) or { panic('${err}') }
	rn.append_child(b.as_node()) or { panic('${err}') }

	box := layout_block(root, 0, 0, 800, []&css.CSSRule{})
	assert box.children[0].width == 150.0
	assert box.children[1].width == 150.0
}

// flex-grow: 0 (the default) items don't grow — free space is left for justify-content.
fn test_flex_no_grow_leaves_free_space() {
	doc := dom.Document.create(dom.url_about_blank())
	root := styled(doc, 'div', 'display: flex; justify-content: flex-end; width: 300px; height: 20px')
	a := styled(doc, 'div', 'width: 100px; height: 20px')
	mut rn := root.as_node()
	rn.append_child(a.as_node()) or { panic('${err}') }

	box := layout_block(root, 0, 0, 800, []&css.CSSRule{})
	assert box.children[0].width == 100.0 // not grown

	assert box.children[0].x == 200.0 // pushed to the end (300 - 100)
}

// align-items: stretch (the default) grows auto-height items to the container's cross size.
fn test_align_items_stretch_fills_height() {
	doc := dom.Document.create(dom.url_about_blank())
	root := styled(doc, 'div', 'display: flex; width: 300px; height: 80px') // default align-items: stretch
	a := styled(doc, 'div', 'width: 100px')
	b := styled(doc, 'div', 'width: 100px')
	mut rn := root.as_node()
	rn.append_child(a.as_node()) or { panic('${err}') }
	rn.append_child(b.as_node()) or { panic('${err}') }

	box := layout_block(root, 0, 0, 800, []&css.CSSRule{})
	assert box.children[0].height == 80.0 // stretched to the 80px container

	assert box.children[1].height == 80.0
}

// With an auto-height container, stretch grows auto-height items to match the tallest item (equal rows).
fn test_align_items_stretch_to_tallest() {
	doc := dom.Document.create(dom.url_about_blank())
	root := styled(doc, 'div', 'display: flex; width: 300px') // auto height
	a := styled(doc, 'div', 'width: 100px; height: 50px') // explicit -> the tallest
	b := styled(doc, 'div', 'width: 100px') // auto -> stretches to 50
	mut rn := root.as_node()
	rn.append_child(a.as_node()) or { panic('${err}') }
	rn.append_child(b.as_node()) or { panic('${err}') }

	box := layout_block(root, 0, 0, 800, []&css.CSSRule{})
	assert box.height == 50.0
	assert box.children[0].height == 50.0 // explicit, unchanged

	assert box.children[1].height == 50.0 // stretched to match
}

// A definite-height item is not stretched (stretch has no effect on its size) and top-aligns.
fn test_align_items_stretch_skips_definite_height() {
	doc := dom.Document.create(dom.url_about_blank())
	root := styled(doc, 'div', 'display: flex; align-items: stretch; width: 300px; height: 80px')
	a := styled(doc, 'div', 'width: 100px; height: 30px')
	mut rn := root.as_node()
	rn.append_child(a.as_node()) or { panic('${err}') }

	box := layout_block(root, 0, 0, 800, []&css.CSSRule{})
	assert box.children[0].height == 30.0 // unchanged

	assert box.children[0].y == 0.0 // top-aligned
}

// flex-direction: column stacks items vertically; auto-width items fill the container (stretch).
fn test_flex_column_basic() {
	doc := dom.Document.create(dom.url_about_blank())
	root := styled(doc, 'div', 'display: flex; flex-direction: column; width: 200px; height: 300px')
	a := styled(doc, 'div', 'height: 50px')
	b := styled(doc, 'div', 'height: 60px')
	mut rn := root.as_node()
	rn.append_child(a.as_node()) or { panic('${err}') }
	rn.append_child(b.as_node()) or { panic('${err}') }

	box := layout_block(root, 0, 0, 800, []&css.CSSRule{})
	assert box.children[0].y == 0.0 && box.children[1].y == 50.0 // stacked

	assert box.children[0].width == 200.0 && box.children[1].width == 200.0 // stretch fills
}

fn test_flex_column_reverse_places_main_start_at_the_bottom_edge() {
	doc := dom.Document.create(dom.url_about_blank())
	root := styled(doc, 'div', 'display: flex; flex-direction: column-reverse; width: 200px; height: 300px')
	a := styled(doc, 'div', 'height: 50px')
	b := styled(doc, 'div', 'height: 60px')
	mut rn := root.as_node()
	rn.append_child(a.as_node()) or { panic('${err}') }
	rn.append_child(b.as_node()) or { panic('${err}') }

	box := layout_block(root, 0, 0, 800, []&css.CSSRule{})
	assert box.children[0].y == 250.0
	assert box.children[1].y == 190.0
}

// Column justify-content centers items vertically within the container's height.
fn test_flex_column_justify_center() {
	doc := dom.Document.create(dom.url_about_blank())
	root := styled(doc, 'div', 'display: flex; flex-direction: column; justify-content: center; width: 200px; height: 300px')
	a := styled(doc, 'div', 'height: 50px')
	b := styled(doc, 'div', 'height: 60px')
	mut rn := root.as_node()
	rn.append_child(a.as_node()) or { panic('${err}') }
	rn.append_child(b.as_node()) or { panic('${err}') }

	box := layout_block(root, 0, 0, 800, []&css.CSSRule{})
	// total 110, free 190, center leading 95.
	assert box.children[0].y == 95.0 && box.children[1].y == 145.0
}

// Column align-items centers items horizontally (their width shrink-to-fits or is definite).
fn test_flex_column_align_center() {
	doc := dom.Document.create(dom.url_about_blank())
	root := styled(doc, 'div', 'display: flex; flex-direction: column; align-items: center; width: 200px; height: 300px')
	a := styled(doc, 'div', 'width: 80px; height: 50px')
	mut rn := root.as_node()
	rn.append_child(a.as_node()) or { panic('${err}') }

	box := layout_block(root, 0, 0, 800, []&css.CSSRule{})
	assert box.children[0].width == 80.0 // definite width kept

	assert box.children[0].x == 60.0 // centered: (200 - 80) / 2
}

// A column with auto height flows to the total item height (plus gaps).
fn test_flex_column_auto_height() {
	doc := dom.Document.create(dom.url_about_blank())
	root := styled(doc, 'div', 'display: flex; flex-direction: column; row-gap: 10px; width: 200px')
	a := styled(doc, 'div', 'height: 30px')
	b := styled(doc, 'div', 'height: 40px')
	mut rn := root.as_node()
	rn.append_child(a.as_node()) or { panic('${err}') }
	rn.append_child(b.as_node()) or { panic('${err}') }

	box := layout_block(root, 0, 0, 800, []&css.CSSRule{})
	assert box.height == 80.0 // 30 + 10 gap + 40

	assert box.children[1].y == 40.0 // 30 + 10 gap
}

fn test_flex_column_grow_distributes_main_axis_space() {
	doc := dom.Document.create(dom.url_about_blank())
	root := styled(doc, 'div', 'display: flex; flex-direction: column; width: 100px; height: 300px')
	a := styled(doc, 'div', 'flex: 1 1 50px; min-height: 0')
	b := styled(doc, 'div', 'flex: 1 1 50px; min-height: 0')
	mut root_node := root.as_node()
	root_node.append_child(a.as_node()) or { panic('${err}') }
	root_node.append_child(b.as_node()) or { panic('${err}') }

	box := layout_block(root, 0, 0, 800, []&css.CSSRule{})
	assert box.children[0].height == 150.0
	assert box.children[1].height == 150.0
	assert box.children[1].y == 150.0
}

fn test_flex_column_shrink_freezes_minimum_violations() {
	doc := dom.Document.create(dom.url_about_blank())
	root := styled(doc, 'div', 'display: flex; flex-direction: column; width: 100px; height: 100px')
	a := styled(doc, 'div', 'flex: 0 1 80px; min-height: 70px')
	b := styled(doc, 'div', 'flex: 0 1 80px; min-height: 0')
	mut root_node := root.as_node()
	root_node.append_child(a.as_node()) or { panic('${err}') }
	root_node.append_child(b.as_node()) or { panic('${err}') }

	box := layout_block(root, 0, 0, 800, []&css.CSSRule{})
	assert box.children[0].height == 70.0
	assert box.children[1].height == 30.0
	assert box.children[1].y == 70.0
}

fn test_flex_column_border_box_basis_is_converted_to_content_space() {
	doc := dom.Document.create(dom.url_about_blank())
	root := styled(doc, 'div', 'display: flex; flex-direction: column; width: 100px; height: 200px')
	a := styled(doc, 'div', 'box-sizing: border-box; flex: 0 0 100px; min-height: 0; padding: 10px; border: 5px solid')
	b := styled(doc, 'div', 'flex: 0 0 50px; min-height: 0')
	mut root_node := root.as_node()
	root_node.append_child(a.as_node()) or { panic('${err}') }
	root_node.append_child(b.as_node()) or { panic('${err}') }

	box := layout_block(root, 0, 0, 800, []&css.CSSRule{})
	assert box.children[0].height == 70.0
	assert box.children[0].margin_box_height() == 100.0
	assert box.children[1].y == 100.0
}

fn test_flex_column_automatic_minimum_is_content_based_unless_item_scrolls() {
	doc := dom.Document.create(dom.url_about_blank())
	root := styled(doc, 'div', 'display: flex; flex-direction: column; width: 100px; height: 100px')
	a := styled(doc, 'div', 'flex: 1 1 0')
	b := styled(doc, 'div', 'flex: 1 1 0; overflow: auto')
	a_content := styled(doc, 'div', 'height: 80px')
	b_content := styled(doc, 'div', 'height: 80px')
	mut a_node := a.as_node()
	a_node.append_child(a_content.as_node()) or { panic('${err}') }
	mut b_node := b.as_node()
	b_node.append_child(b_content.as_node()) or { panic('${err}') }
	mut root_node := root.as_node()
	root_node.append_child(a.as_node()) or { panic('${err}') }
	root_node.append_child(b.as_node()) or { panic('${err}') }

	box := layout_block(root, 0, 0, 800, []&css.CSSRule{})
	assert box.children[0].height == 80.0
	assert box.children[1].height == 20.0
}

fn test_flex_column_wrap_forms_vertical_lines() {
	doc := dom.Document.create(dom.url_about_blank())
	root := styled(doc, 'div', 'display: flex; flex-direction: column; flex-wrap: wrap; align-content: flex-start; width: 200px; height: 100px; column-gap: 10px')
	mut root_node := root.as_node()
	for _ in 0 .. 4 {
		item := styled(doc, 'div', 'width: 20px; height: 40px; flex-shrink: 0')
		root_node.append_child(item.as_node()) or { panic('${err}') }
	}

	box := layout_block(root, 0, 0, 800, []&css.CSSRule{})
	assert box.children[0].x == 0.0 && box.children[0].y == 0.0
	assert box.children[1].x == 0.0 && box.children[1].y == 40.0
	assert box.children[2].x == 30.0 && box.children[2].y == 0.0
	assert box.children[3].x == 30.0 && box.children[3].y == 40.0
}

fn test_flex_column_wrap_resolves_flexible_lengths_per_line() {
	doc := dom.Document.create(dom.url_about_blank())
	root := styled(doc, 'div', 'display: flex; flex-direction: column; flex-wrap: wrap; align-content: flex-start; width: 200px; height: 100px; column-gap: 10px')
	mut root_node := root.as_node()
	for _ in 0 .. 4 {
		item := styled(doc, 'div', 'width: 20px; flex: 1 1 40px; min-height: 0')
		root_node.append_child(item.as_node()) or { panic('${err}') }
	}

	box := layout_block(root, 0, 0, 800, []&css.CSSRule{})
	for child in box.children {
		assert child.height == 50.0
	}
	assert box.children[1].y == 50.0
	assert box.children[2].x == 30.0 && box.children[2].y == 0.0
}

fn test_flex_column_wrap_reverse_and_column_reverse_swap_both_axes() {
	doc := dom.Document.create(dom.url_about_blank())
	root := styled(doc, 'div', 'display: flex; flex-direction: column-reverse; flex-wrap: wrap-reverse; align-content: flex-start; width: 200px; height: 100px; column-gap: 10px')
	mut root_node := root.as_node()
	for _ in 0 .. 4 {
		item := styled(doc, 'div', 'width: 20px; height: 40px; flex-shrink: 0')
		root_node.append_child(item.as_node()) or { panic('${err}') }
	}

	box := layout_block(root, 0, 0, 800, []&css.CSSRule{})
	assert box.children[0].x == 180.0 && box.children[0].y == 60.0
	assert box.children[1].x == 180.0 && box.children[1].y == 20.0
	assert box.children[2].x == 150.0 && box.children[2].y == 60.0
	assert box.children[3].x == 150.0 && box.children[3].y == 20.0
}

// radial-gradient background renders to an SVG <radialGradient> with the stop colors.
fn test_radial_gradient_background() {
	doc := dom.Document.create(dom.url_about_blank())
	root := styled(doc, 'div', 'width: 100px; height: 100px; background: radial-gradient(rgb(255, 0, 0), rgb(0, 0, 255))')
	box := layout_block(root, 0, 0, 800, []&css.CSSRule{})

	grad := box.background_gradient or { panic('no gradient') }
	assert grad.radial == true
	assert grad.colors.len == 2

	svg := box.render_svg(200, 200)
	assert svg.contains('<radialGradient id="grad0"')
	assert svg.contains('stop-color="rgb(255 0 0)"')
	assert svg.contains('fill="url(#grad0)"')
	assert !svg.contains('<linearGradient')
}

// A leading shape/size keyword (e.g. `circle`) is skipped; the color stops still parse.
fn test_radial_gradient_skips_shape() {
	doc := dom.Document.create(dom.url_about_blank())
	root := styled(doc, 'div', 'width: 60px; height: 60px; background-image: radial-gradient(circle, rgb(1, 2, 3), rgb(4, 5, 6))')
	box := layout_block(root, 0, 0, 800, []&css.CSSRule{})

	grad := box.background_gradient or { panic('no gradient') }
	assert grad.radial == true
	assert grad.colors.len == 2
	assert grad.colors[0].serialize() == 'rgb(1 2 3)'
}

fn test_radial_gradient_shape_extent_position_and_stops() {
	doc := dom.Document.create(dom.url_about_blank())
	root := styled(doc, 'div', 'width: 100px; height: 80px; background-image: radial-gradient(circle closest-side at 25% 75%, red 20%, blue 80%)')
	box := layout_block(root, 0, 0, 800, []&css.CSSRule{})
	grad := box.background_gradient or { panic('no radial gradient') }
	assert grad.kind == 'radial'
	assert grad.center_x == 0.25 && grad.center_y == 0.75
	assert grad.radius_x == 0.25 && grad.radius_y == 0.25
	assert grad.stops[0].offset == 0.2 && grad.stops[1].offset == 0.8
	svg := box.render_svg(200, 200)
	assert svg.contains('cx="25%"') && svg.contains('cy="75%"')
	assert svg.contains('offset="20%"') && svg.contains('offset="80%"')
}

fn test_conic_gradient_is_preserved_and_rendered() {
	doc := dom.Document.create(dom.url_about_blank())
	root := styled(doc, 'div', 'width: 100px; height: 100px; background-image: conic-gradient(from 45deg at 25% 75%, red 0%, blue 100%)')
	box := layout_block(root, 0, 0, 800, []&css.CSSRule{})
	grad := box.background_gradient or { panic('no conic gradient') }
	assert grad.kind == 'conic'
	assert grad.start_degrees == 45.0
	assert grad.center_x == 0.25 && grad.center_y == 0.75
	assert gradient_color_at(grad, 0.5).serialize() == 'rgb(128 0 128)'
	svg := box.render_svg(200, 200)
	assert svg.contains('<clipPath id="gradient-clip')
	assert svg.contains('<polygon points=')
}

// linear-gradient still parses as non-radial and renders a <linearGradient>.
fn test_linear_gradient_still_linear() {
	doc := dom.Document.create(dom.url_about_blank())
	root := styled(doc, 'div', 'width: 60px; height: 60px; background: linear-gradient(to right, rgb(1, 1, 1), rgb(2, 2, 2))')
	box := layout_block(root, 0, 0, 800, []&css.CSSRule{})

	grad := box.background_gradient or { panic('no gradient') }
	assert grad.radial == false
	assert box.render_svg(100, 100).contains('<linearGradient')
}

fn test_sampled_gradient_stops_preserve_interpolation_and_hard_boundaries() {
	gradient := LinearGradient{
		stops: [
			GradientStop{css.Color{255, 0, 0, 255}, 0.0},
			GradientStop{css.Color{255, 0, 0, 255}, 0.5},
			GradientStop{css.Color{0, 0, 255, 255}, 0.5},
			GradientStop{css.Color{0, 0, 255, 255}, 1.0},
		]
		interpolation_method: css.ColorInterpolationMethod(css.RectangularColorSpace.oklab)
	}
	sampled := sampled_gradient_stops(gradient, 16)
	assert sampled[0] == GradientStop{css.Color{255, 0, 0, 255}, 0.0}
	assert sampled[sampled.len - 1] == GradientStop{css.Color{0, 0, 255, 255}, 1.0}
	hard_edge := sampled.filter(math.abs(it.offset - 0.5) < 0.000001)
	assert hard_edge.len == 2
	assert hard_edge[0].color == css.Color{255, 0, 0, 255}
	assert hard_edge[1].color == css.Color{0, 0, 255, 255}
}

fn test_sampled_gradient_stops_clip_out_of_range_stops_to_rendered_interval() {
	gradient := LinearGradient{
		stops: [
			GradientStop{css.Color{255, 0, 0, 255}, -1.0},
			GradientStop{css.Color{0, 0, 255, 255}, 2.0},
		]
	}
	sampled := sampled_gradient_stops(gradient, 16)
	assert sampled[0].offset == 0
	assert sampled[sampled.len - 1].offset == 1
	assert sampled.all(it.offset >= 0 && it.offset <= 1)
	assert sampled[0].color == gradient_color_at(gradient, 0)
	assert sampled[sampled.len - 1].color == gradient_color_at(gradient, 1)
}

fn test_sampled_gradient_stops_keep_clamped_leading_and_trailing_ranges() {
	gradient := LinearGradient{
		stops: [
			GradientStop{css.Color{255, 0, 0, 255}, 0.25},
			GradientStop{css.Color{0, 0, 255, 255}, 0.75},
		]
	}
	sampled := sampled_gradient_stops(gradient, 4)
	assert sampled[0] == GradientStop{css.Color{255, 0, 0, 255}, 0.0}
	assert sampled[1] == GradientStop{css.Color{255, 0, 0, 255}, 0.25}
	assert sampled[sampled.len - 2] == GradientStop{css.Color{0, 0, 255, 255}, 0.75}
	assert sampled[sampled.len - 1] == GradientStop{css.Color{0, 0, 255, 255}, 1.0}
}

fn test_gradient_color_at_interpolates_compatibility_color_arrays() {
	gradient := LinearGradient{
		colors: [css.Color{255, 0, 0, 255}, css.Color{0, 0, 255, 255}]
	}
	assert gradient_color_at(gradient, 0.5) == css.Color{128, 0, 128, 255}
}

// Bijective base-26 alphabetic markers.
fn test_alphabetic_marker() {
	assert alphabetic_marker(1, false) == 'a'
	assert alphabetic_marker(26, false) == 'z'
	assert alphabetic_marker(27, false) == 'aa'
	assert alphabetic_marker(28, false) == 'ab'
	assert alphabetic_marker(3, true) == 'C'
}

// Roman-numeral markers.
fn test_roman_marker() {
	assert roman_marker(1, false) == 'i'
	assert roman_marker(4, false) == 'iv'
	assert roman_marker(9, false) == 'ix'
	assert roman_marker(14, false) == 'xiv'
	assert roman_marker(40, false) == 'xl'
	assert roman_marker(2024, true) == 'MMXXIV'
}

// Build an <ol> with the given list-style-type and n empty <li>s; return the li markers.
fn ol_markers(kind string, n int) []string {
	doc := dom.Document.create(dom.url_about_blank())
	root := styled(doc, 'ol', 'width: 300px; font-size: 20px; list-style-type: ${kind}')
	mut rn := root.as_node()
	for _ in 0 .. n {
		li := styled(doc, 'li', '')
		rn.append_child(li.as_node()) or { panic('${err}') }
	}
	box := layout_block(root, 0, 0, 800, []&css.CSSRule{})
	mut out := []string{}
	for child in box.children {
		out << child.lines[0].fragments[0].text
	}
	return out
}

// list-style-type: lower-alpha / upper-roman / decimal-leading-zero produce the right ordered markers.
fn test_list_marker_counter_styles() {
	assert ol_markers('lower-alpha', 3) == ['a.', 'b.', 'c.']
	assert ol_markers('upper-roman', 3) == ['I.', 'II.', 'III.']
	assert ol_markers('decimal-leading-zero', 2) == ['01.', '02.']
}

// Layout delegates all predefined counter styles to the translated CSS CounterStyle registry rather
// than limiting markers to decimal/alphabetic/Roman shortcuts.
fn test_list_marker_ua_counter_styles() {
	assert ol_markers('lower-greek', 3) == ['α.', 'β.', 'γ.']
	assert ol_markers('hebrew', 3) == ['א.', 'ב.', 'ג.']
	assert ol_markers('cjk-decimal', 3) == ['一、', '二、', '三、']
}

// A styled inline generates one decorating box per line around all its word fragments, including
// their collapsed inter-word space, followed by the text commands.
fn test_inline_background_border_and_shadow_paint() {
	doc := dom.Document.create(dom.url_about_blank())
	root := styled(doc, 'div', 'width: 500px; font-size: 20px')
	span := styled(doc, 'span', 'background-color: orange; border: 2px solid green; border-radius: 6px; box-shadow: 4px 4px 4px darkgreen')
	mut span_node := span.as_node()
	span_node.append_child(doc.create_text_node('two words').as_node()) or { panic('${err}') }
	mut root_node := root.as_node()
	root_node.append_child(span.as_node()) or { panic('${err}') }

	box := layout_block(root, 0, 0, 800, []&css.CSSRule{})
	fragments := box.lines[0].fragments
	assert fragments.len == 2
	commands := box.paint_commands()
	backgrounds := commands.filter(it.kind == 'fill_rect' && it.color == 'rgb(255 165 0)' && it.radius > 0)
	assert backgrounds.len == 1
	assert backgrounds[0].x == fragments[0].x - 2.0
	assert backgrounds[0].width == fragments[1].x + fragments[1].width - fragments[0].x + 4.0
	assert backgrounds[0].radius == 6.0
	borders := commands.filter(it.kind == 'draw_svg_path' && it.color == 'rgb(0 128 0)')
	assert borders.len == 1
	assert borders[0].path.contains('A 6 6')
	assert borders[0].fill_even_odd
	shadows := commands.filter(it.kind == 'fill_rect' && it.color == 'rgb(0 100 0)')
	assert shadows.len == 1
	assert shadows[0].blur == 4.0
	assert shadows[0].outer_shadow
	assert shadows[0].shadow_offset_x == 4.0
	assert shadows[0].shadow_offset_y == 4.0
	text_commands := commands.filter(it.kind == 'draw_text')
	assert text_commands.len == 1
	assert text_commands[0].text == 'two words'
}

// An inline-block is an atomic item on the line: its box is laid out and placed as a child, occupying
// its own width; surrounding text flows around it on the line.
fn test_inline_block_atomic() {
	doc := dom.Document.create(dom.url_about_blank())
	root := styled(doc, 'div', 'width: 500px; font-size: 20px')
	ib := styled(doc, 'span', 'display: inline-block; width: 40px; height: 30px; background-color: rgb(0, 128, 0)')
	mut rn := root.as_node()
	rn.append_child(doc.create_text_node('a ').as_node()) or { panic('${err}') }
	rn.append_child(ib.as_node()) or { panic('${err}') }
	rn.append_child(doc.create_text_node(' b').as_node()) or { panic('${err}') }

	box := layout_block(root, 0, 0, 800, []&css.CSSRule{})
	// The inline-block box becomes a child (painted as its own box), 40x30.
	assert box.children.len == 1
	assert box.children[0].width == 40.0
	assert box.children[0].height == 30.0
	// 'a' is at x=0; the inline-block sits after 'a' + a space (10px each at font-size 20).
	assert box.children[0].x == 21.6875
	// Line height grows to the inline-block's 30px (taller than the 20px text line-height... actually
	// line-height for 20px font is ~24; the 30px box wins).
	assert box.height == 30.0
}

// An inline-block with auto width shrink-to-fits its own content.
fn test_inline_block_auto_width_shrink_to_fit() {
	doc := dom.Document.create(dom.url_about_blank())
	root := styled(doc, 'div', 'width: 500px; font-size: 20px')
	ib := styled(doc, 'span', 'display: inline-block; height: 20px')
	mut ibn := ib.as_node()
	ibn.append_child(doc.create_text_node('hi').as_node()) or { panic('${err}') }
	mut rn := root.as_node()
	rn.append_child(ib.as_node()) or { panic('${err}') }

	box := layout_block(root, 0, 0, 800, []&css.CSSRule{})
	assert box.children.len == 1
	assert box.children[0].width == 17.328125 // shaped max-content width, not the container
}

// The inline-block box paints (its background reaches the display list).
fn test_inline_block_paints() {
	doc := dom.Document.create(dom.url_about_blank())
	root := styled(doc, 'div', 'width: 500px; font-size: 20px')
	ib := styled(doc, 'span', 'display: inline-block; width: 30px; height: 30px; background-color: rgb(1, 2, 3)')
	mut rn := root.as_node()
	rn.append_child(ib.as_node()) or { panic('${err}') }

	box := layout_block(root, 0, 0, 800, []&css.CSSRule{})
	fills := box.paint_commands().filter(it.kind == 'fill_rect')
	assert fills.len == 1
	assert fills[0].color == 'rgb(1 2 3)'
}

// A table arranges its cells in a grid: columns are content-proportional (scaled to the table width),
// rows stack, and each cell is a child of the table box.
fn test_table_grid_layout() {
	doc := dom.Document.create(dom.url_about_blank())
	table := styled(doc, 'table', 'width: 300px; font-size: 20px; border-collapse: collapse')
	tbody := styled(doc, 'tbody', '')
	mut tn := tbody.as_node()
	// Row 1: "a" (10px max-content) | "bbbb" (40px).
	r1 := styled(doc, 'tr', '')
	c1 := styled(doc, 'td', 'padding: 0')
	mut c1n := c1.as_node()
	c1n.append_child(doc.create_text_node('a').as_node()) or { panic('${err}') }
	c2 := styled(doc, 'td', 'padding: 0')
	mut c2n := c2.as_node()
	c2n.append_child(doc.create_text_node('bbbb').as_node()) or { panic('${err}') }
	mut r1n := r1.as_node()
	r1n.append_child(c1.as_node()) or { panic('${err}') }
	r1n.append_child(c2.as_node()) or { panic('${err}') }
	// Row 2: "c" | "d".
	r2 := styled(doc, 'tr', '')
	c3 := styled(doc, 'td', 'padding: 0')
	mut c3n := c3.as_node()
	c3n.append_child(doc.create_text_node('c').as_node()) or { panic('${err}') }
	c4 := styled(doc, 'td', 'padding: 0')
	mut c4n := c4.as_node()
	c4n.append_child(doc.create_text_node('d').as_node()) or { panic('${err}') }
	mut r2n := r2.as_node()
	r2n.append_child(c3.as_node()) or { panic('${err}') }
	r2n.append_child(c4.as_node()) or { panic('${err}') }
	tn.append_child(r1.as_node()) or { panic('${err}') }
	tn.append_child(r2.as_node()) or { panic('${err}') }
	mut tabn := table.as_node()
	tabn.append_child(tbody.as_node()) or { panic('${err}') }

	box := layout_block(table, 0, 0, 800, []&css.CSSRule{})
	assert box.children.len == 4 // 4 cells (rows/tbody not materialized)

	// Columns content-proportional (10:40) scaled to 300 -> 60 and 240.
	assert box.children[0].x == 0.0
	assert box.children[0].width == 59.36507936507937
	assert box.children[1].x == 59.36507936507937
	assert box.children[1].width == 240.63492063492063
	// Row 2 cells sit below row 1 (row height = a text line).
	line := box.children[0].height // one line of text
	assert box.children[2].x == 0.0
	assert box.children[2].y == box.children[0].y + line
	assert box.height == 2.0 * line // two rows
}

fn test_table_colspan_reserves_and_sizes_all_covered_columns() {
	doc := dom.Document.create(dom.url_about_blank())
	table := styled(doc, 'table', 'width: 300px; border-collapse: collapse')
	first_row := styled(doc, 'tr', '')
	mut spanning := styled(doc, 'td', 'padding: 0; height: 20px')
	spanning.set_attribute_value('colspan', '2')
	last_column := styled(doc, 'td', 'padding: 0; height: 20px')
	mut first_row_node := first_row.as_node()
	first_row_node.append_child(spanning.as_node()) or { panic('${err}') }
	first_row_node.append_child(last_column.as_node()) or { panic('${err}') }
	second_row := styled(doc, 'tr', '')
	mut second_row_node := second_row.as_node()
	for _ in 0 .. 3 {
		cell := styled(doc, 'td', 'padding: 0; height: 20px')
		second_row_node.append_child(cell.as_node()) or { panic('${err}') }
	}
	mut table_node := table.as_node()
	table_node.append_child(first_row.as_node()) or { panic('${err}') }
	table_node.append_child(second_row.as_node()) or { panic('${err}') }

	box := layout_block(table, 0, 0, 800, []&css.CSSRule{})
	assert box.children.len == 5
	assert box.children[0].x == 0.0
	assert box.children[0].width == 200.0
	assert box.children[1].x == 200.0
	assert box.children[1].width == 100.0
	assert box.children[2].y == 20.0
}

fn test_table_rowspan_reserves_following_row_slots_and_distributes_height() {
	doc := dom.Document.create(dom.url_about_blank())
	table := styled(doc, 'table', 'width: 200px; border-collapse: collapse')
	first_row := styled(doc, 'tr', '')
	mut spanning := styled(doc, 'td', 'padding: 0; height: 60px')
	spanning.set_attribute_value('rowspan', '2')
	first_peer := styled(doc, 'td', 'padding: 0; height: 20px')
	mut first_row_node := first_row.as_node()
	first_row_node.append_child(spanning.as_node()) or { panic('${err}') }
	first_row_node.append_child(first_peer.as_node()) or { panic('${err}') }
	second_row := styled(doc, 'tr', '')
	second_peer := styled(doc, 'td', 'padding: 0; height: 20px')
	mut second_row_node := second_row.as_node()
	second_row_node.append_child(second_peer.as_node()) or { panic('${err}') }
	mut table_node := table.as_node()
	table_node.append_child(first_row.as_node()) or { panic('${err}') }
	table_node.append_child(second_row.as_node()) or { panic('${err}') }

	box := layout_block(table, 0, 0, 800, []&css.CSSRule{})
	assert box.children.len == 3
	assert box.children[0].x == 0.0
	assert box.children[0].width == 100.0
	assert box.children[0].height == 60.0
	assert box.children[1].x == 100.0
	assert box.children[1].y == 0.0
	assert box.children[2].x == 100.0
	assert box.children[2].y == 30.0
	assert box.height == 60.0
}

fn test_table_cells_stretch_to_their_row_and_rowspan_heights() {
	doc := dom.Document.create(dom.url_about_blank())
	table := styled(doc, 'table', 'width: 200px; border-collapse: collapse')
	first_row := styled(doc, 'tr', '')
	mut spanning := styled(doc, 'td', 'padding: 0; height: 10px')
	spanning.set_attribute_value('rowspan', '2')
	tall := styled(doc, 'td', 'padding: 0; height: 40px')
	mut first_row_node := first_row.as_node()
	first_row_node.append_child(spanning.as_node()) or { panic('${err}') }
	first_row_node.append_child(tall.as_node()) or { panic('${err}') }
	second_row := styled(doc, 'tr', '')
	short := styled(doc, 'td', 'padding: 0; height: 20px')
	mut second_row_node := second_row.as_node()
	second_row_node.append_child(short.as_node()) or { panic('${err}') }
	mut table_node := table.as_node()
	table_node.append_child(first_row.as_node()) or { panic('${err}') }
	table_node.append_child(second_row.as_node()) or { panic('${err}') }

	box := layout_block(table, 0, 0, 800, []&css.CSSRule{})
	assert box.children[0].height == 60.0
	assert box.children[1].height == 40.0
	assert box.children[2].height == 20.0
	assert box.children[2].y == 40.0
	assert box.height == 60.0
}

fn test_table_captions_are_laid_out_above_and_below_the_grid() {
	doc := dom.Document.create(dom.url_about_blank())
	table := styled(doc, 'table', 'width: 200px; border-collapse: collapse')
	top_caption := styled(doc, 'caption', 'height: 30px; margin: 0; padding: 0')
	bottom_caption := styled(doc, 'caption', 'caption-side: bottom; height: 40px; margin: 0; padding: 0')
	row := styled(doc, 'tr', '')
	cell := styled(doc, 'td', 'height: 20px; margin: 0; padding: 0')
	mut row_node := row.as_node()
	row_node.append_child(cell.as_node()) or { panic('${err}') }
	mut table_node := table.as_node()
	table_node.append_child(bottom_caption.as_node()) or { panic('${err}') }
	table_node.append_child(row.as_node()) or { panic('${err}') }
	table_node.append_child(top_caption.as_node()) or { panic('${err}') }

	box := layout_block(table, 0, 0, 800, []&css.CSSRule{})
	assert box.children.len == 3
	assert box.children[0].node_id == i64(top_caption.as_node().unique_id())
	assert box.children[0].y == 0.0 && box.children[0].height == 30.0
	assert box.children[1].node_id == i64(cell.as_node().unique_id())
	assert box.children[1].y == 30.0 && box.children[1].height == 20.0
	assert box.children[2].node_id == i64(bottom_caption.as_node().unique_id())
	assert box.children[2].y == 50.0 && box.children[2].height == 40.0
	assert box.height == 90.0
}

fn test_table_column_group_widths_constrain_tracks_before_intrinsic_distribution() {
	doc := dom.Document.create(dom.url_about_blank())
	table := styled(doc, 'table', 'width: 300px; border-collapse: collapse')
	column_group := styled(doc, 'colgroup', '')
	first_column := styled(doc, 'col', 'width: 80px')
	second_column := styled(doc, 'col', '')
	mut column_group_node := column_group.as_node()
	column_group_node.append_child(first_column.as_node()) or { panic('${err}') }
	column_group_node.append_child(second_column.as_node()) or { panic('${err}') }
	row := styled(doc, 'tr', '')
	first_cell := styled(doc, 'td', 'height: 20px; padding: 0')
	second_cell := styled(doc, 'td', 'height: 20px; padding: 0')
	mut row_node := row.as_node()
	row_node.append_child(first_cell.as_node()) or { panic('${err}') }
	row_node.append_child(second_cell.as_node()) or { panic('${err}') }
	mut table_node := table.as_node()
	table_node.append_child(column_group.as_node()) or { panic('${err}') }
	table_node.append_child(row.as_node()) or { panic('${err}') }

	box := layout_block(table, 0, 0, 800, []&css.CSSRule{})
	assert box.children[0].width == 80.0
	assert box.children[1].x == 80.0
	assert box.children[1].width == 220.0
}

fn test_auto_table_width_uses_intrinsic_shrink_to_fit_size() {
	doc := dom.Document.create(dom.url_about_blank())
	table := styled(doc, 'table', 'border-collapse: collapse')
	row := styled(doc, 'tr', '')
	mut row_node := row.as_node()
	for _ in 0 .. 2 {
		cell := styled(doc, 'td', 'width: 50px; height: 20px; padding: 0')
		row_node.append_child(cell.as_node()) or { panic('${err}') }
	}
	mut table_node := table.as_node()
	table_node.append_child(row.as_node()) or { panic('${err}') }
	box := layout_block(table, 0, 0, 500, []&css.CSSRule{})
	assert box.width == 100
	assert box.children[0].width == 50
	assert box.children[1].x == 50
}

fn test_separate_table_border_spacing_surrounds_and_separates_tracks() {
	doc := dom.Document.create(dom.url_about_blank())
	table := styled(doc, 'table', 'width: 220px; border-collapse: separate; border-spacing: 10px 5px')
	row := styled(doc, 'tr', '')
	mut row_node := row.as_node()
	for _ in 0 .. 2 {
		cell := styled(doc, 'td', 'height: 20px; padding: 0')
		row_node.append_child(cell.as_node()) or { panic('${err}') }
	}
	mut table_node := table.as_node()
	table_node.append_child(row.as_node()) or { panic('${err}') }
	box := layout_block(table, 0, 0, 500, []&css.CSSRule{})
	assert box.children[0].x == 10
	assert box.children[0].width == 95
	assert box.children[1].x == 115
	assert box.children[1].width == 95
	assert box.children[0].y == 5
	assert box.height == 30
}

fn test_collapsed_table_ignores_border_spacing() {
	doc := dom.Document.create(dom.url_about_blank())
	table := styled(doc, 'table', 'width: 220px; border-collapse: collapse; border-spacing: 10px 5px')
	row := styled(doc, 'tr', '')
	mut row_node := row.as_node()
	for _ in 0 .. 2 {
		cell := styled(doc, 'td', 'height: 20px; padding: 0')
		row_node.append_child(cell.as_node()) or { panic('${err}') }
	}
	mut table_node := table.as_node()
	table_node.append_child(row.as_node()) or { panic('${err}') }
	box := layout_block(table, 0, 0, 500, []&css.CSSRule{})
	assert box.children[0].x == 0
	assert box.children[1].x == 110
	assert box.height == 20
}

// Build a grid with the given template + gap and n items (each 20px tall); return their (x, width, y).
struct GridCell {
	x     f64
	width f64
	y     f64
}

fn grid_cells(template string, gap string, n int) []GridCell {
	doc := dom.Document.create(dom.url_about_blank())
	root := styled(doc, 'div', 'display: grid; width: 300px; grid-template-columns: ${template}; gap: ${gap}')
	mut rn := root.as_node()
	for _ in 0 .. n {
		item := styled(doc, 'div', 'height: 20px')
		rn.append_child(item.as_node()) or { panic('${err}') }
	}
	box := layout_block(root, 0, 0, 800, []&css.CSSRule{})
	mut out := []GridCell{}
	for child in box.children {
		out << GridCell{child.x, child.width, child.y}
	}
	return out
}

// grid-template-columns with fr units splits the width; items auto-place across columns then wrap.
fn test_grid_fr_columns_and_autoplacement() {
	// 1fr 2fr in 300px -> columns 100 and 200. 4 items -> 2 rows of 2.
	cells := grid_cells('1fr 2fr', '0px', 4)
	assert cells.len == 4
	assert cells[0].x == 0.0 && cells[0].width == 100.0
	assert cells[1].x == 100.0 && cells[1].width == 200.0
	// item 3 wraps to row 2, column 0.
	assert cells[2].x == 0.0 && cells[2].width == 100.0
	assert cells[2].y == 20.0 // below row 1 (row height 20)

	assert cells[3].x == 100.0 && cells[3].y == 20.0
}

// A fixed track plus an fr track: the fr takes the remaining width (minus the gap).
fn test_grid_fixed_and_fr_with_gap() {
	// 100px 1fr in 300px with a 20px gap -> col0 100, col1 = 300 - 100 - 20 = 180.
	cells := grid_cells('100px 1fr', '20px', 2)
	assert cells[0].x == 0.0 && cells[0].width == 100.0
	assert cells[1].x == 120.0 && cells[1].width == 180.0 // 100 + 20 gap
}

// repeat(n, track) expands to n columns.
fn test_grid_repeat() {
	// repeat(3, 1fr) in 300px -> three 100px columns.
	cells := grid_cells('repeat(3, 1fr)', '0px', 3)
	assert cells.len == 3
	assert cells[0].x == 0.0 && cells[0].width == 100.0
	assert cells[1].x == 100.0 && cells[1].width == 100.0
	assert cells[2].x == 200.0 && cells[2].width == 100.0
}

fn test_grid_minmax_and_intrinsic_track_sizing() {
	doc := dom.Document.create(dom.url_about_blank())
	root := styled(doc, 'div', 'display: grid; width: 300px')
	assert parse_grid_tracks('minmax(100px, 1fr) 2fr', root, 300, 0, []&css.CSSRule{}) == [
		f64(100),
		200,
	]

	first := styled(doc, 'div', 'font-size: 20px')
	mut first_node := first.as_node()
	first_node.append_child(doc.create_text_node('aaaa bbbbb').as_node()) or { panic('${err}') }
	second := styled(doc, 'div', '')
	mut root_node := root.as_node()
	root_node.append_child(first.as_node()) or { panic('${err}') }
	root_node.append_child(second.as_node()) or { panic('${err}') }
	tracks := parse_grid_tracks('fit-content(80px) 1fr', root, 300, 0, []&css.CSSRule{})
	assert tracks == [f64(80), 220]
}

fn test_grid_auto_fit_collapses_empty_repeated_tracks() {
	doc := dom.Document.create(dom.url_about_blank())
	root := styled(doc, 'div', 'display: grid; width: 260px')
	for _ in 0 .. 2 {
		item := styled(doc, 'div', '')
		mut root_node := root.as_node()
		root_node.append_child(item.as_node()) or { panic('${err}') }
	}
	auto_fit := parse_grid_tracks('repeat(auto-fit, minmax(80px, 1fr))', root, 260, 10, []&css.CSSRule{})
	assert auto_fit == [f64(125), 125]
	auto_fill := parse_grid_tracks('repeat(auto-fill, minmax(80px, 1fr))', root, 260, 10, []&css.CSSRule{})
	assert auto_fill == [f64(80), 80, 80]
}

fn test_grid_named_column_lines_place_items() {
	doc := dom.Document.create(dom.url_about_blank())
	root := styled(doc, 'div', 'display: grid; width: 300px; grid-template-columns: [start] 100px [content] 100px [end] 100px')
	item := styled(doc, 'div', 'grid-column: content / end; height: 20px')
	mut root_node := root.as_node()
	root_node.append_child(item.as_node()) or { panic('${err}') }
	box := layout_block(root, 0, 0, 800, []&css.CSSRule{})
	assert box.children[0].x == 100
	assert box.children[0].width == 100
}

// flex-wrap: wrap breaks items onto multiple lines when they overflow the main size; lines stack.
fn test_flex_wrap() {
	doc := dom.Document.create(dom.url_about_blank())
	root := styled(doc, 'div', 'display: flex; flex-wrap: wrap; width: 200px')
	// Three 80x30 items: two fit on line 1 (160 <= 200), the third wraps to line 2.
	for _ in 0 .. 3 {
		it := styled(doc, 'div', 'width: 80px; height: 30px')
		mut rn := root.as_node()
		rn.append_child(it.as_node()) or { panic('${err}') }
	}
	box := layout_block(root, 0, 0, 800, []&css.CSSRule{})
	assert box.children.len == 3
	assert box.children[0].x == 0.0 && box.children[0].y == 0.0
	assert box.children[1].x == 80.0 && box.children[1].y == 0.0
	assert box.children[2].x == 0.0 && box.children[2].y == 30.0 // wrapped to line 2

	assert box.height == 60.0 // two 30px lines
}

fn test_flex_wrap_reverse_reverses_the_cross_axis_line_order() {
	doc := dom.Document.create(dom.url_about_blank())
	root := styled(doc, 'div', 'display: flex; flex-wrap: wrap-reverse; width: 160px')
	a := styled(doc, 'div', 'width: 80px; height: 20px')
	b := styled(doc, 'div', 'width: 80px; height: 20px')
	c := styled(doc, 'div', 'width: 80px; height: 30px')
	mut rn := root.as_node()
	rn.append_child(a.as_node()) or { panic('${err}') }
	rn.append_child(b.as_node()) or { panic('${err}') }
	rn.append_child(c.as_node()) or { panic('${err}') }

	box := layout_block(root, 0, 0, 800, []&css.CSSRule{})
	assert box.height == 50.0
	assert box.children[0].y == 30.0
	assert box.children[1].y == 30.0
	assert box.children[2].y == 0.0
}

fn test_flex_align_content_stretch_expands_wrapped_line_cross_sizes() {
	doc := dom.Document.create(dom.url_about_blank())
	root := styled(doc, 'div', 'display: flex; flex-wrap: wrap; width: 160px; height: 100px')
	for _ in 0 .. 3 {
		item := styled(doc, 'div', 'width: 80px')
		mut root_node := root.as_node()
		root_node.append_child(item.as_node()) or { panic('${err}') }
	}

	box := layout_block(root, 0, 0, 800, []&css.CSSRule{})
	assert box.children[0].height == 50.0
	assert box.children[1].height == 50.0
	assert box.children[2].height == 50.0
	assert box.children[2].y == 50.0
}

fn test_flex_align_content_end_packs_wrapped_lines_at_cross_end() {
	doc := dom.Document.create(dom.url_about_blank())
	root := styled(doc, 'div', 'display: flex; flex-wrap: wrap; align-content: flex-end; width: 160px; height: 100px')
	for _ in 0 .. 3 {
		item := styled(doc, 'div', 'width: 80px; height: 20px')
		mut root_node := root.as_node()
		root_node.append_child(item.as_node()) or { panic('${err}') }
	}

	box := layout_block(root, 0, 0, 800, []&css.CSSRule{})
	assert box.children[0].y == 60.0
	assert box.children[1].y == 60.0
	assert box.children[2].y == 80.0
}

fn test_flex_align_content_space_between_distributes_cross_space() {
	doc := dom.Document.create(dom.url_about_blank())
	root := styled(doc, 'div', 'display: flex; flex-wrap: wrap; align-content: space-between; width: 160px; height: 100px')
	for _ in 0 .. 3 {
		item := styled(doc, 'div', 'width: 80px; height: 20px')
		mut root_node := root.as_node()
		root_node.append_child(item.as_node()) or { panic('${err}') }
	}

	box := layout_block(root, 0, 0, 800, []&css.CSSRule{})
	assert box.children[0].y == 0.0
	assert box.children[1].y == 0.0
	assert box.children[2].y == 80.0
}

fn test_flex_wrap_reverse_flips_aligned_lines_within_definite_cross_size() {
	doc := dom.Document.create(dom.url_about_blank())
	root := styled(doc, 'div', 'display: flex; flex-wrap: wrap-reverse; align-content: flex-start; width: 160px; height: 100px')
	for _ in 0 .. 3 {
		item := styled(doc, 'div', 'width: 80px; height: 20px')
		mut root_node := root.as_node()
		root_node.append_child(item.as_node()) or { panic('${err}') }
	}

	box := layout_block(root, 0, 0, 800, []&css.CSSRule{})
	assert box.children[0].y == 80.0
	assert box.children[1].y == 80.0
	assert box.children[2].y == 60.0
}

// A grid item spanning multiple columns occupies their combined width and shifts auto-flow.
fn test_grid_column_span() {
	doc := dom.Document.create(dom.url_about_blank())
	// 3 columns of 100px each (repeat(3, 1fr) of 300px).
	root := styled(doc, 'div', 'display: grid; width: 300px; grid-template-columns: repeat(3, 1fr)')
	mut rn := root.as_node()
	// item A spans 2 columns; B and C are single. A+B fill row 1 (2+1=3 cols); C wraps to row 2.
	a := styled(doc, 'div', 'grid-column: span 2; height: 20px')
	b := styled(doc, 'div', 'height: 20px')
	c := styled(doc, 'div', 'height: 20px')
	rn.append_child(a.as_node()) or { panic('${err}') }
	rn.append_child(b.as_node()) or { panic('${err}') }
	rn.append_child(c.as_node()) or { panic('${err}') }

	box := layout_block(root, 0, 0, 800, []&css.CSSRule{})
	assert box.children.len == 3
	// A at column 0, spanning 2 -> width 200, x 0.
	assert box.children[0].x == 0.0 && box.children[0].width == 200.0
	// B at column 2 -> x 200, width 100.
	assert box.children[1].x == 200.0 && box.children[1].width == 100.0
	// C wraps to row 2, column 0.
	assert box.children[2].x == 0.0 && box.children[2].y == 20.0
}

fn test_grid_explicit_integer_column_lines_place_before_auto_flow() {
	doc := dom.Document.create(dom.url_about_blank())
	root := styled(doc, 'div', 'display: grid; width: 300px; grid-template-columns: repeat(3, 1fr)')
	explicit := styled(doc, 'div', 'grid-column: 2 / 4; height: 20px')
	auto := styled(doc, 'div', 'height: 20px')
	mut root_node := root.as_node()
	root_node.append_child(explicit.as_node()) or { panic('${err}') }
	root_node.append_child(auto.as_node()) or { panic('${err}') }

	box := layout_block(root, 0, 0, 800, []&css.CSSRule{})
	assert box.children[0].x == 100.0
	assert box.children[0].width == 200.0
	assert box.children[0].y == 0.0
	assert box.children[1].x == 0.0
	assert box.children[1].y == 0.0
}

fn test_grid_colliding_explicit_columns_advance_to_the_next_available_row() {
	doc := dom.Document.create(dom.url_about_blank())
	root := styled(doc, 'div', 'display: grid; width: 300px; grid-template-columns: repeat(3, 1fr)')
	first := styled(doc, 'div', 'grid-column: 2; height: 20px')
	second := styled(doc, 'div', 'grid-column: 2; height: 30px')
	mut root_node := root.as_node()
	root_node.append_child(first.as_node()) or { panic('${err}') }
	root_node.append_child(second.as_node()) or { panic('${err}') }

	box := layout_block(root, 0, 0, 800, []&css.CSSRule{})
	assert box.children[0].x == 100.0
	assert box.children[0].y == 0.0
	assert box.children[1].x == 100.0
	assert box.children[1].y == 20.0
}

fn test_grid_negative_integer_lines_resolve_from_the_explicit_grid_end() {
	doc := dom.Document.create(dom.url_about_blank())
	root := styled(doc, 'div', 'display: grid; width: 300px; grid-template-columns: repeat(3, 1fr)')
	item := styled(doc, 'div', 'grid-column: -2 / -1; height: 20px')
	mut root_node := root.as_node()
	root_node.append_child(item.as_node()) or { panic('${err}') }

	box := layout_block(root, 0, 0, 800, []&css.CSSRule{})
	assert box.children[0].x == 200.0
	assert box.children[0].width == 100.0
}

fn test_grid_justify_items_and_justify_self_align_within_cells() {
	doc := dom.Document.create(dom.url_about_blank())
	root := styled(doc, 'div', 'display: grid; width: 200px; grid-template-columns: 100px 100px; justify-items: center')
	centered := styled(doc, 'div', 'width: 40px; height: 20px')
	ended := styled(doc, 'div', 'width: 40px; height: 20px; justify-self: end')
	mut root_node := root.as_node()
	root_node.append_child(centered.as_node()) or { panic('${err}') }
	root_node.append_child(ended.as_node()) or { panic('${err}') }

	box := layout_block(root, 0, 0, 800, []&css.CSSRule{})
	assert box.children[0].x == 30.0
	assert box.children[1].x == 160.0
}

fn test_grid_align_items_and_align_self_align_within_rows() {
	doc := dom.Document.create(dom.url_about_blank())
	root := styled(doc, 'div', 'display: grid; width: 200px; grid-template-columns: 100px 100px; align-items: end')
	short := styled(doc, 'div', 'height: 20px')
	tall := styled(doc, 'div', 'height: 50px; align-self: start')
	mut root_node := root.as_node()
	root_node.append_child(short.as_node()) or { panic('${err}') }
	root_node.append_child(tall.as_node()) or { panic('${err}') }

	box := layout_block(root, 0, 0, 800, []&css.CSSRule{})
	assert box.children[0].y == 30.0
	assert box.children[1].y == 0.0
	assert box.height == 50.0
}

fn test_grid_auto_sized_items_stretch_to_their_grid_area() {
	doc := dom.Document.create(dom.url_about_blank())
	root := styled(doc, 'div', 'display: grid; width: 200px; grid-template-columns: 100px 100px')
	auto_sized := styled(doc, 'div', '')
	tall := styled(doc, 'div', 'height: 50px')
	mut root_node := root.as_node()
	root_node.append_child(auto_sized.as_node()) or { panic('${err}') }
	root_node.append_child(tall.as_node()) or { panic('${err}') }

	box := layout_block(root, 0, 0, 800, []&css.CSSRule{})
	assert box.children[0].width == 100.0
	assert box.children[0].height == 50.0
	assert box.children[1].x == 100.0
}

fn test_grid_auto_margin_absorbs_only_its_cell_free_space() {
	doc := dom.Document.create(dom.url_about_blank())
	root := styled(doc, 'div', 'display: grid; width: 200px; grid-template-columns: 100px 100px')
	item := styled(doc, 'div', 'width: 40px; height: 20px; margin-left: auto')
	mut root_node := root.as_node()
	root_node.append_child(item.as_node()) or { panic('${err}') }

	box := layout_block(root, 0, 0, 800, []&css.CSSRule{})
	assert box.children[0].margin.left == 60.0
	assert box.children[0].x == 60.0
}

fn test_nested_viewport_commands_compose_translation_transform_clip_and_opacity() {
	clip := PaintClip{
		rect: LayoutRect{1, 2, 30, 40}
		is_svg_mask: true
		transform: [f64(1), 0, 0, 1, 5, 6]!
		path_components: [PaintPath{
			transform: [f64(1), 0, 0, 1, 7, 8]!
		}]
		mask_operations: [PaintMaskOperation{
			kind: .path
			transform: [f64(1), 0, 0, 1, 9, 10]!
		}]
	}
	command := PaintCommand{
		x: 1
		y: 2
		opacity: 0.5
		transform: [f64(1), 0, 0, 1, 3, 4]!
		has_clip: true
		clip_x: 1
		clip_y: 2
		clip_width: 30
		clip_height: 40
		clip_list: &PaintClipList{ items: [clip] }
		mask_clip: clip
	}
	transformed := paint_command_for_nested_viewport(command, [f64(2), 0, 0, 2, 7, 8]!, painting.IntPoint{10, 20}, 0.5)
	assert transformed.transform == [f64(2), 0, 0, 2, 33, 56]!
	assert transformed.opacity == 0.25
	assert transformed.clip_x == 29
	assert transformed.clip_y == 52
	assert transformed.clip_width == 60
	assert transformed.clip_height == 80
	assert transformed.clip_list.items[0].transform == [f64(2), 0, 0, 2, 37, 60]!
	assert transformed.clip_list.items[0].path_components[0].transform == [f64(2), 0, 0, 2, 41,
		64]!
	assert transformed.mask_clip.mask_operations[0].transform == [f64(2), 0, 0, 2, 45, 68]!
	assert transformed.mask_clip.cache_key != command.mask_clip.cache_key
}
