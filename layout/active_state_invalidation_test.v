module layout

import css
import dom
import html

fn activate_test_chain(element &dom.Element, active bool) {
	mut current := ?&dom.Node(element.as_node())
	for current != none {
		node := current or { break }
		if mut ancestor := node.as_element() { ancestor.set_being_activated(active) }
		current = node.parent()
	}
}

fn test_active_ancestor_chain_retains_unaffected_thread_styles() {
	mut document := html.parse_document('<!doctype html><style>a:active{color:red}</style><div id="thread"><a id="control">expand</a>' +
		'<p class="unrelated">unrelated comment</p>'.repeat(512) + '</div>')
	_ = layout_document_typed_in_viewport(document, 320, 240)
	control := document.get_element_by_id('control')?
	unrelated := css.query_selector_all(document.as_node(), '.unrelated')
	styles := unrelated.map(voidptr(css.computed_properties_for_element(it) or { panic('missing style') }))
	for active in [true, false, true, false] {
		activate_test_chain(control, active)
		document.update_layout(.event_handler_handle_mouse_down)
		for index, element in unrelated {
			assert voidptr(css.computed_properties_for_element(element)?) == styles[index]
		}
		commands := display_list_commands(document.record_display_list()?)
		assert commands.any(it.kind == 'draw_text' && it.text == 'expand' && it.color == 'rgb(255 0 0)') == active
	}
}

fn test_active_state_invalidation_preserves_descendant_sibling_relational_and_pseudo_rules() {
	mut document := html.parse_document('<!doctype html><style>
		a:active strong{color:red}a:not(:active)+p{color:blue}a:active+p{color:green}
		section:has(a:active) .status{color:purple}a:active::before{content:"pressed"}
	</style><section><a id="control"><strong id="label">expand</strong></a><p id="sibling">sibling</p><p class="status" id="status">status</p></section>')
	_ = layout_document_typed_in_viewport(document, 320, 240)
	control := document.get_element_by_id('control')?
	for active in [true, false, true, false] {
		activate_test_chain(control, active)
		document.update_layout(.event_handler_handle_mouse_down)
		commands := display_list_commands(document.record_display_list()?)
		assert commands.any(it.kind == 'draw_text' && it.text == 'expand' && it.color == 'rgb(255 0 0)') == active
		assert commands.any(it.kind == 'draw_text' && it.text == 'sibling' && it.color == if active {
			'rgb(0 128 0)'
		} else {
			'rgb(0 0 255)'
		})
		assert commands.any(it.kind == 'draw_text' && it.text == 'status' && it.color == 'rgb(128 0 128)') == active
		assert commands.any(it.kind == 'draw_text' && it.text == 'pressed') == active
	}
}
