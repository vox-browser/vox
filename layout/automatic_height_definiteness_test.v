module layout

import css
import dom

fn automatic_height_node(document &dom.Document, declarations string) &NodeWithStyle {
	mut element := document.create_element_ns('http://www.w3.org/1999/xhtml', 'div') or { panic(err) }
	element.set_attribute_value('style', 'display:block;${declarations}')
	computed := css.css_style_computer_for(document).compute_style(dom.AbstractElement.new(element, none))
	return unsafe { &NodeWithStyle(BlockContainer.new(document, none, computed)) }
}

fn test_automatic_height_stays_indefinite_across_parents_and_containing_blocks() {
	mut document := dom.Document.create(dom.url_about_blank())
	defer { document.finalize() }
	for parent_style in ['', 'display:block', 'display:flow-root', 'display:flex', 'display:grid', 'float:left'] {
		for child_style in ['', 'float:left', 'position:absolute', 'display:inline-block', 'display:flex'] {
			for attached in [false, true] {
				node := automatic_height_node(document, 'height:auto;${child_style}')
				if attached {
					parent := automatic_height_node(document, parent_style)
					mut parent_node := unsafe { &Node(parent) }
					parent_node.append_child(unsafe { &Node(node) })
				}
				for mode in 0 .. 5 {
					mut basis := &UsedValues{}
					basis.set_content_width(CSSPixels.new(240))
					basis.set_content_height(CSSPixels.new(120))
					basis.set_has_definite_width(mode % 2 == 0)
					basis.set_has_definite_height(mode >= 2)
					containing := if mode == 4 { ?&UsedValues(none) } else { ?&UsedValues(basis) }
					computed := node.computed_values()
					values := UsedValues{content_height_: CSSPixels.new(37)}
					assert resolve_definite_size(node, computed, computed.size_value(.height), containing, false, values) == none
					assert values.content_height() == CSSPixels.new(37)
				}
			}
		}
	}
}

fn test_automatic_width_keeps_parent_flags_edges_and_containing_block_rules() {
	mut document := dom.Document.create(dom.url_about_blank())
	defer { document.finalize() }
	for index, styles in [
		['display:block', 'display:block'],
		['display:flow-root', 'display:block'],
		['float:left', 'display:block'],
		['display:flex', 'display:block'],
		['display:block', 'float:left'],
		['display:block', 'position:absolute'],
		['display:block', 'display:inline-block'],
	] {
		node := automatic_height_node(document, 'width:auto;${styles[1]}')
		parent := automatic_height_node(document, styles[0])
		mut parent_node := unsafe { &Node(parent) }
		parent_node.append_child(unsafe { &Node(node) })
		computed := node.computed_values()
		for mode in 0 .. 3 {
			mut basis := &UsedValues{}
			basis.set_content_width(CSSPixels.new(240))
			basis.set_has_definite_width(mode == 0)
			containing := if mode == 2 { ?&UsedValues(none) } else { ?&UsedValues(basis) }
			values := UsedValues{
				margin_left: CSSPixels.new(3)
				margin_right: CSSPixels.new(5)
				padding_left: CSSPixels.new(7)
				padding_right: CSSPixels.new(11)
				border_left: CSSPixels.new(13)
				border_right: CSSPixels.new(17)
			}
			if index < 2 && mode == 0 {
				resolved := resolve_definite_size(node, computed, computed.size_value(.width), containing, true, values) or { panic('automatic flow width must resolve') }
				assert resolved == CSSPixels.new(184)
			} else {
				assert resolve_definite_size(node, computed, computed.size_value(.width), containing, true, values) == none
			}
		}
	}
	root := automatic_height_node(document, 'width:auto')
	assert resolve_definite_size(root, root.computed_values(), css.Size.make_auto(), none, true, &UsedValues{}) == none
}
