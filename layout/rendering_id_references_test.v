module layout

import dom
import html

// Only ids that layout or paint resolved from a URL fragment can change
// rendering when an element enters, leaves or renames them.
fn id_reference_document(markup string) &dom.Document {
	address := dom.URL{value: 'https://id-references.example/'}
	return html.parse_navigation_document(markup, address, address.origin(), none) or { panic(err) }
}

fn id_reference_paint(mut document dom.Document) string {
	document.update_layout(.debugging)
	return (document.record_display_list() or { panic('paint') }).dump()
}

fn id_reference_full_oracle(mut document dom.Document, painted string) {
	document.set_needs_full_layout_tree_update(true)
	assert id_reference_paint(mut document) == painted
}

fn test_unreferenced_ids_keep_the_layout_tree() {
	mut document := id_reference_document('<!doctype html><div id="changed">a</div><section id="stable"><p>text</p></section><svg width="10" height="10"><rect width="10" height="10" fill="url(#paint) red"/></svg>')
	defer { document.finalize() }
	_ = layout_document_typed_in_viewport(document, 200, 100)
	_ = id_reference_paint(mut document)
	assert document.rendering_references_id('paint')
	assert !document.rendering_references_id('changed')

	mut changed := document.get_element_by_id('changed') or { panic('changed') }
	changed.set_attribute_value('id', 'renamed')
	assert !document.needs_full_layout_tree_update()
	mut fresh := document.create_element('div') or { panic(err) }
	fresh.set_attribute_value('id', 'fresh')
	mut stable := document.get_element_by_id('stable') or { panic('stable') }
	mut stable_node := stable.as_node()
	stable_node.append_child(fresh.as_node()) or { panic(err) }
	assert !document.needs_full_layout_tree_update()
	mut fresh_node := fresh.as_node()
	fresh_node.remove(false)
	assert !document.needs_full_layout_tree_update()
	painted := id_reference_paint(mut document)
	id_reference_full_oracle(mut document, painted)

	// The referenced id resolves to the renamed element now.
	mut renamed := document.get_element_by_id('renamed') or { panic('renamed') }
	renamed.set_attribute_value('id', 'paint')
	assert document.needs_full_layout_tree_update()
	collided := id_reference_paint(mut document)
	id_reference_full_oracle(mut document, collided)
}

fn test_referenced_ids_rebuild_when_a_paint_server_takes_them() {
	mut document := id_reference_document('<!doctype html><svg width="10" height="10"><defs><linearGradient id="other"><stop stop-color="green"/></linearGradient></defs><rect width="10" height="10" fill="url(#late) red"/></svg>')
	defer { document.finalize() }
	_ = layout_document_typed_in_viewport(document, 200, 100)
	before := id_reference_paint(mut document)
	assert document.rendering_references_id('late')
	mut gradient := document.get_element_by_id('other') or { panic('gradient') }
	gradient.set_attribute_value('id', 'late')
	assert document.needs_full_layout_tree_update()
	after := id_reference_paint(mut document)
	assert after != before
	id_reference_full_oracle(mut document, after)

	// Removing the id again restores the fallback color.
	mut taken := document.get_element_by_id('late') or { panic('late') }
	taken.set_attribute_value('id', 'gone')
	assert id_reference_paint(mut document) == before
}

// typed_paint_adapter_test.v covers the same collision with command fields.
fn test_referenced_id_collisions_resolve_to_the_next_element_in_tree_order() {
	mut document := id_reference_document('<!doctype html><div id="paint" style="display:none"></div><svg width="10" height="10"><defs><linearGradient id="paint"><stop stop-color="green"/></linearGradient></defs><rect width="10" height="10" fill="url(#paint) red"/></svg>')
	defer { document.finalize() }
	_ = layout_document_typed_in_viewport(document, 200, 100)
	before := id_reference_paint(mut document)
	mut collision := document.get_element_by_id('paint') or { panic('collision') }
	collision.set_attribute_value('id', 'other')
	assert document.needs_full_layout_tree_update()
	after := id_reference_paint(mut document)
	assert after != before
	id_reference_full_oracle(mut document, after)
	mut moved := document.get_element_by_id('other') or { panic('other') }
	moved.set_attribute_value('id', 'paint')
	assert id_reference_paint(mut document) == before
}
