module dom

#include "insertion_lifetime_test.h"

$if gcboehm ? {
	fn C.vox_node_lifetime_watch_owner(index u32, owner voidptr)
	fn C.vox_node_lifetime_owners_alive() u32
	fn C.vox_node_lifetime_collect(depth u32)
	fn C.vox_node_lifetime_run_worker(work fn ())
}

@[noinline]
fn insertion_lifetime_create_mutated_document() {
	mut document := Document.create(URL{value: 'https://example.test/inserted-owner'})
	mut container := document.create_element_ns(namespace_html_uri, 'section') or { panic(err) }
	text := document.create_text_node('before')
	mut container_node := container.as_node()
	container_node.append_child(text.as_node()) or { panic(err) }
	mut document_node := document.as_node()
	document_node.append_child(container_node) or { panic(err) }
	container.set_attribute_value('class', 'after')
	mut mutable_text := unsafe { &Text(text) }
	mutable_text.set_data('after')
	// Exercise both the insertion invalidation and same-parent scheduling path
	// without adding an unrelated move/removal callback owner to this fixture.
	document.set_needs_full_style_update(false)
	container_node.invalidate_style(.node_insert_before)
	invalidate_style_after_same_parent_move(text.as_node(), .node_insert_before)
	assert container.get_attribute('class') or { '' } == 'after'
	assert text.data() == 'after'
	assert voidptr(text.as_node().document()) == voidptr(document)
	$if gcboehm ? {
		C.vox_node_lifetime_watch_owner(0, voidptr(document))
		C.vox_node_lifetime_watch_owner(1, voidptr(text))
	}
	document.finalize()
}

fn test_inserted_and_mutated_document_graph_has_no_temporary_visitor_owner() {
	$if gcboehm ? {
		C.vox_node_lifetime_run_worker(insertion_lifetime_create_mutated_document)
		C.vox_node_lifetime_collect(8)
		C.vox_node_lifetime_collect(8)
		assert C.vox_node_lifetime_owners_alive() == 0
	} $else {
		insertion_lifetime_create_mutated_document()
	}
}

fn test_post_connection_snapshot_retains_shadow_including_tree_order() {
	document := Document.create(url_about_blank())
	mut host := document.create_element_ns(namespace_html_uri, 'div') or { panic(err) }
	light := document.create_element_ns(namespace_html_uri, 'span') or { panic(err) }
	mut host_node := host.as_node()
	host_node.append_child(light.as_node()) or { panic(err) }
	shadow := host.attach_shadow(ShadowRootInit{mode: .closed}) or { panic(err) }
	mut shadow_node := shadow_root_as_node(shadow)
	mut nested_host := document.create_element_ns(namespace_html_uri, 'span') or { panic(err) }
	shadow_node.append_child(nested_host.as_node()) or { panic(err) }
	nested := nested_host.attach_shadow(ShadowRootInit{mode: .open}) or { panic(err) }
	mut nested_node := shadow_root_as_node(nested)
	text := document.create_text_node('nested')
	nested_node.append_child(text.as_node()) or { panic(err) }
	mut snapshot := []&Node{}
	collect_nodes_for_post_connection(host_node, mut snapshot)
	expected := [host_node, shadow_node, nested_host.as_node(), nested_node, text.as_node(), light.as_node()]
	assert snapshot.len == expected.len
	for index, node in expected { assert voidptr(snapshot[index]) == voidptr(node) }
	// The list is a complete pre-connection snapshot, independent of later
	// mutations to the live child arrays.
	new_child := document.create_text_node('later')
	host_node.append_child(new_child.as_node()) or { panic(err) }
	assert snapshot.len == 6 && voidptr(snapshot[5]) == voidptr(light.as_node())
}

struct InsertionScopeScheduleLog {
mut:
	calls []int
	parents []voidptr
}

struct InsertionScopeScheduleState {
	id int
	log &InsertionScopeScheduleLog
}

fn insertion_scope_yes(_ voidptr) bool { return true }

fn insertion_scope_record(context voidptr, parent &Node, child_list bool) {
	state := unsafe { &InsertionScopeScheduleState(context) }
	assert child_list
	mut log := unsafe { &InsertionScopeScheduleLog(state.log) }
	log.calls << state.id
	log.parents << voidptr(parent)
}

fn test_parent_scope_scheduling_keeps_first_additional_order_and_identity() {
	mut document := Document.create(url_about_blank())
	mut outer_host := document.create_element_ns(namespace_html_uri, 'div') or { panic(err) }
	outer := outer_host.attach_shadow(ShadowRootInit{mode: .open}) or { panic(err) }
	mut outer_node := shadow_root_as_node(outer)
	mut inner_host := document.create_element_ns(namespace_html_uri, 'span') or { panic(err) }
	outer_node.append_child(inner_host.as_node()) or { panic(err) }
	inner := inner_host.attach_shadow(ShadowRootInit{mode: .closed}) or { panic(err) }
	mut inner_node := shadow_root_as_node(inner)
	child := document.create_text_node('mutation')
	inner_node.append_child(child.as_node()) or { panic(err) }
	log := &InsertionScopeScheduleLog{}
	scopes := inner_node.observing_style_scopes()
	assert scopes.additional.len == 2
	mut all := [scopes.first]
	all << scopes.additional
	for index, scope in all {
		mut mutable_scope := unsafe { &StyleScope(scope) }
		mutable_scope.css_handle = voidptr(&InsertionScopeScheduleState{id: index, log: log})
		mutable_scope.may_have_has_selectors_callback = insertion_scope_yes
		mutable_scope.has_featureless_sensitive_callback = insertion_scope_yes
		mutable_scope.record_conservative_has_callback = insertion_scope_record
	}
	schedule_has_walk_for_parent_scopes(child.as_node(), inner_node, .node_insert_before)
	assert log.calls == [0, 1, 2]
	assert log.parents.len == 3
	for parent in log.parents { assert parent == voidptr(inner_node) }
}
