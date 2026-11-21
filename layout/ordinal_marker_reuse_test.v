module layout

import dom
import html
import os

fn ordinal_marker_matches_full_rebuild(mut document dom.Document) string {
	before := (document.record_display_list() or { panic('missing paint') }).dump()
	document.set_needs_full_layout_tree_update(true)
	document.update_layout(.debugging)
	after := (document.record_display_list() or { panic('missing full paint') }).dump()
	assert after == before
	return after
}

fn ordinal_marker_document() &dom.Document {
	return html.parse_document('<!doctype html><style>
		body{margin:0;font:16px/20px sans-serif}
		section{display:flow-root}
		ol.roman{list-style-type:upper-roman}
	</style><body><div id="changed"><p id="text">first</p></div>
		<section id="stable"><ol id="list"><li>one</li><li>two</li><li>three</li></ol>
		<ol class="roman"><li>alpha</li><li>beta</li></ol></section><p>tail</p></body>')
}

fn ordinal_marker_texts(document &dom.Document, id string) []string {
	list := document.get_element_by_id(id) or { panic(id) }
	list_node := list.as_node()
	mut texts := []string{}
	for child in list_node.children {
		mirror := child.unsafe_layout_node() or { continue }
		box := unsafe { &Node(mirror.real_layout_handle()) }
		item := box.as_list_item_box() or { continue }
		marker := item.marker() or { continue }
		text_child := marker.first_child() or { continue }
		text := text_child.as_text_node() or { continue }
		texts << text.text_for_rendering()
	}
	return texts
}

fn ordinal_marker_text(document &dom.Document) &dom.Node {
	paragraph := document.get_element_by_id('text') or { panic('text') }
	node := paragraph.as_node()
	return node.first_child() or { panic('text node') }
}

// Ordered list markers are built alike for every ordinal and get their text
// in layout. A clean subtree of ordered lists keeps its boxes across a tree
// rebuild and its committed layout across a change elsewhere, while an
// inserted item still renumbers the markers after it.
fn test_ordered_list_subtrees_are_reused_until_their_ordinals_change() {
	mut document := ordinal_marker_document()
	defer { document.finalize() }
	_ = layout_document_typed_in_viewport(document, 400, 300)
	section := document.get_element_by_id('stable') or { panic('section') }
	section_node := section.as_node()
	kept_mirror := section_node.unsafe_layout_node() or { panic('section box') }
	kept := kept_mirror.real_layout_handle()
	assert ordinal_marker_texts(document, 'list') == ['1. ', '2. ', '3. ']
	mut changed := document.get_element_by_id('changed')?
	for index in 0 .. 2 {
		reused_before := incremental_layout_reused_subtree_count()
		if index == 0 {
			// A layout tree update next to the lists.
			changed.set_inner_html('<p id="text">line<br>line</p>') or { panic(err) }
		} else {
			// A text change, laid out incrementally.
			mut text := ordinal_marker_text(document)
			text.set_node_value('x') or { panic(err) }
		}
		document.update_layout(.debugging)
		reused := incremental_layout_reused_subtree_count() - reused_before
		if os.getenv('VOX_RETAIN_ORDINAL_MARKER_BLOCKING') == '' {
			assert reused >= 1, 'pass ${index}'
			if index == 0 {
				mirror := section_node.unsafe_layout_node() or { panic('section box') }
				assert mirror.real_layout_handle() == kept
			}
		} else {
			assert reused == 0, 'pass ${index}'
		}
		assert ordinal_marker_texts(document, 'list') == ['1. ', '2. ', '3. '], 'pass ${index}'
		ordinal_marker_matches_full_rebuild(mut document)
	}
	// A new first item renumbers the clean items after it.
	mut list := document.get_element_by_id('list')?
	mut first := document.create_element('li') or { panic(err) }
	mut first_node := first.as_node()
	first_node.append_child(document.create_text_node('zero').as_node()) or { panic(err) }
	mut list_node := list.as_node()
	list_node.insert_before(first_node, list_node.first_child(), false)
	document.update_layout(.debugging)
	assert ordinal_marker_texts(document, 'list') == ['1. ', '2. ', '3. ', '4. ']
	ordinal_marker_matches_full_rebuild(mut document)
	assert ordinal_marker_texts(document, 'list') == ['1. ', '2. ', '3. ', '4. ']
}
