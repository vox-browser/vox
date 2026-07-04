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
