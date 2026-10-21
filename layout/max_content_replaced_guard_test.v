module layout

import css
import dom
import html

fn guarded_max_content_node(root &Node, id string) &Node {
	if dom_node := root.dom_node() {
		if element := dom_node.as_element() {
			if element.get_attribute_value('id') == id {
				return root
			}
		}
	}
	for child in root.children() {
		if found := guarded_max_content_find(child, id) {
			return found
		}
	}
	panic('missing #${id}')
}

fn guarded_max_content_find(root &Node, id string) ?&Node {
	if dom_node := root.dom_node() {
		if element := dom_node.as_element() {
			if element.get_attribute_value('id') == id {
				return root
			}
		}
	}
	for child in root.children() {
		if found := guarded_max_content_find(child, id) {
			return found
		}
	}
	return none
}

fn test_ordinary_max_content_preserves_content_and_cache_with_own_constraints() {
	document := html.parse_document('<!doctype html><style>
		body { margin:0 } .probe { display:block; min-width:calc(20px + 50%);
			max-width:25px; min-height:3em; max-height:10px; font-size:12px }
		.child { width:73px; height:7px }
	</style><div id="ordinary" class="probe"><div class="child"></div></div>')
	mut result := run_document_layout(document, 800, 600) or { panic('layout failed') }
	node := guarded_max_content_node(result.root, 'ordinary')
	assert !node.is_replaced_box()
	mut box := node.as_box() or { panic('missing box') }
	box.reset_cached_intrinsic_sizes()
	mut state := result.state
	for _ in 0 .. 3 {
		assert calculate_max_content_width(mut state, box).to_double() == 73
		assert box.cached_intrinsic_sizes().max_content_width or { panic('missing cache') } == CSSPixels.new(73)
	}
	box.reset_cached_intrinsic_sizes()
	assert calculate_max_content_width(mut state, box).to_double() == 73
}

fn test_empty_ordinary_max_content_keeps_lazy_used_values_initialization() {
	document := dom.Document.create(dom.url_about_blank())
	mut box := Box.new(document, none, css.ComputedProperties.new())
	box.set_layout_index(0)
	styled := unsafe { &NodeWithStyle(box) }
	mut state := LayoutState.new()
	assert state.try_get(styled) == none
	assert !unsafe { &Node(box) }.is_replaced_box()
	assert calculate_max_content_width(mut state, box).to_double() == 0
	assert state.try_get(styled) != none
	first := state.get(styled)
	assert calculate_max_content_width(mut state, box).to_double() == 0
	assert voidptr(state.get(styled)) == voidptr(first)
}

fn test_ordinary_max_content_keeps_nested_flex_and_percentage_constraints() {
	document := html.parse_document('<!doctype html><style>
		body { margin:0 } #outer { display:flex; flex-direction:column;
			min-width:90%; min-height:calc(2em + 25%); max-height:20px }
		#inner { min-width:200%; max-width:10px } #child { width:57px; height:9px }
	</style><div id="outer"><div id="inner"><div id="child"></div></div></div>')
	mut result := run_document_layout(document, 800, 600) or { panic('layout failed') }
	mut outer := guarded_max_content_node(result.root, 'outer').as_box() or { panic('missing outer') }
	mut inner := guarded_max_content_node(result.root, 'inner').as_box() or { panic('missing inner') }
	outer.reset_cached_intrinsic_sizes()
	inner.reset_cached_intrinsic_sizes()
	mut state := result.state
	assert calculate_max_content_width(mut state, outer).to_double() == 10
	assert calculate_max_content_width(mut state, outer).to_double() == 10
	assert calculate_min_content_width(mut state, outer).to_double() == 10
}
