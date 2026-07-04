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
