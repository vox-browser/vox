module layout

import dom
import html
import os

fn escalation_handle(document &dom.Document, id string) voidptr {
	element := document.get_element_by_id(id) or { panic(id) }
	node := element.as_node()
	mirror := node.unsafe_layout_node() or { panic('no box for ${id}') }
	return mirror.real_layout_handle()
}

fn escalation_matches_full_rebuild(mut document dom.Document, label string) {
	before := (document.record_display_list() or { panic('paint') }).dump()
	document.set_needs_full_layout_tree_update(true)
	document.update_layout(.debugging)
	assert (document.record_display_list() or { panic('full paint') }).dump() == before, label
}

// A flagged element whose own box cannot keep a re-synced child list (an
// inline span, a button, a text node whose text became white space) is
// rebuilt by its nearest ancestor that can: the update stays in place.
fn test_unsupported_flagged_elements_are_rebuilt_by_their_parent() {
	for step in ['inline', 'button', 'whitespace'] {
		mut document := html.parse_document('<!doctype html><style>body{margin:0;font:16px/20px sans-serif}button{font:inherit}</style><body><div id="bar"><p id="para">Hello <span id="name">world</span><i id="gap">x</i>!</p><button id="btn"><span id="label">Code</span></button></div><p id="tail">tail</p></body>')
		defer { document.finalize() }
		_ = layout_document_typed_in_viewport(document, 400, 300)
		enabled := os.getenv('VOX_DISABLE_IN_PLACE_TREE_UPDATE') == ''
			&& os.getenv('VOX_DISABLE_IN_PLACE_ESCALATION') == ''
		kept_tail := escalation_handle(document, 'tail')
		updated_before, _ := in_place_tree_update_statistics()
		match step {
			'inline' {
				mut name := document.get_element_by_id('name') or { panic('name') }
				mut bold := document.create_element('b') or { panic(err) }
				mut bold_node := bold.as_node()
				bold_node.append_child(document.create_text_node(' again').as_node()) or { panic(err) }
				mut name_node := name.as_node()
				name_node.append_child(bold_node) or { panic(err) }
			}
			'button' {
				mut label := document.get_element_by_id('label') or { panic('label') }
				mut label_node := label.as_node()
				label_node.append_child(document.create_text_node(' 12').as_node()) or { panic(err) }
			}
			else {
				gap := document.get_element_by_id('gap') or { panic('gap') }
				mut text := gap.as_node().first_child() or { panic('text') }
				mut data := text.as_character_data() or { panic('data') }
				data.set_data(' ')
			}
		}
		document.update_layout(.debugging)
		updated_after, _ := in_place_tree_update_statistics()
		if enabled {
			assert updated_after == updated_before + 1, step
			assert escalation_handle(document, 'tail') == kept_tail, step
		}
		escalation_matches_full_rebuild(mut document, step)
	}
}
