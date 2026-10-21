module layout

import dom
import platform

fn test_layout_child_snapshots_keep_order_across_mutation_without_retaining_vectors() {
	mut document := dom.Document.create(dom.url_about_blank())
	defer { document.finalize() }
	host := document.create_element_ns(dom.namespace_html_uri, 'div')!
	mut host_node := host.as_node()
	for _ in 0 .. 128 { host_node.append_child(document.create_text_node('child').as_node())! }
	snapshot := layout_tree_children_for_element(host)
	last := snapshot.children[127]
	host_node.append_child(document.create_text_node('later').as_node())!
	assert snapshot.children.len == 128
	assert voidptr(snapshot.children[127]) == voidptr(last)
	snapshot.storage.finish()
	before := platform.thread_arena_usage().used
	for _ in 0 .. 128 {
		current := layout_tree_children_for_element(host)
		assert current.children.len == 129
		assert voidptr(current.children[127]) == voidptr(last)
		current.storage.finish()
	}
	$if prealloc { assert platform.thread_arena_usage().used - before < 4096 }
	assert host_node.children[128].text_content()? == 'later'
}

fn test_layout_child_snapshot_uses_shadow_and_assigned_slot_children() {
	mut document := dom.Document.create(dom.url_about_blank())
	defer { document.finalize() }
	mut host := document.create_element_ns(dom.namespace_html_uri, 'div')!
	mut host_node := host.as_node()
	light := document.create_element_ns(dom.namespace_html_uri, 'span')!
	host_node.append_child(light.as_node())!
	shadow := host.attach_shadow(dom.ShadowRootInit{mode:.open})!
	mut shadow_node := shadow.as_node()
	slot_element := document.create_element_ns(dom.namespace_html_uri, 'slot')!
	shadow_node.append_child(slot_element.as_node())!
	shadow_snapshot := layout_tree_children_for_element(host)
	assert shadow_snapshot.children.len == 1
	assert voidptr(shadow_snapshot.children[0]) == voidptr(slot_element.as_node())
	assigned_snapshot := layout_tree_children_for_element(slot_element)
	assert assigned_snapshot.children.len == 1
	assert voidptr(assigned_snapshot.children[0]) == voidptr(light.as_node())
	shadow_snapshot.storage.finish()
	assert voidptr(assigned_snapshot.children[0]) == voidptr(light.as_node())
	assigned_snapshot.storage.finish()
}
