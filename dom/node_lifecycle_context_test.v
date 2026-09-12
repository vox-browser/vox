module dom

struct NodeLifecycleObservation {
mut:
	removed_is_subtree_root NodeIsSubtreeRoot
	removed_old_ancestor    ?&Node
	moved_is_subtree_root   NodeIsSubtreeRoot
	moved_old_ancestor      ?&Node
}

fn record_node_removed(target voidptr, is_subtree_root NodeIsSubtreeRoot, old_ancestor ?&Node, _ &Node) {
	mut observation := unsafe { &NodeLifecycleObservation(target) }
	observation.removed_is_subtree_root = is_subtree_root
	observation.removed_old_ancestor = old_ancestor
}

fn record_node_moved(target voidptr, is_subtree_root NodeIsSubtreeRoot, old_ancestor ?&Node) {
	mut observation := unsafe { &NodeLifecycleObservation(target) }
	observation.moved_is_subtree_root = is_subtree_root
	observation.moved_old_ancestor = old_ancestor
}

fn test_move_and_remove_lifecycle_steps_receive_subtree_root_and_old_ancestor() {
	mut document := Document.create(URL{ value: 'https://example.test/' })
	container := document.create_element('main')!
	old_parent := document.create_element('section')!
	new_parent := document.create_element('section')!
	moved := document.create_element('div')!
	descendant := document.create_element('span')!
	mut container_node := container.as_node()
	container_node.append_child(old_parent.as_node())!
	container_node.append_child(new_parent.as_node())!
	mut old_parent_node := old_parent.as_node()
	old_parent_node.append_child(moved.as_node())!
	mut moved_node := moved.as_node()
	moved_node.append_child(descendant.as_node())!

	mut moved_observation := &NodeLifecycleObservation{}
	mut descendant_observation := &NodeLifecycleObservation{}
	moved_node.set_lifecycle_hook(NodeLifecycleHook{
		target: moved_observation
		removed_from: record_node_removed
		moved_from: record_node_moved
	})
	mut descendant_node := descendant.as_node()
	descendant_node.set_lifecycle_hook(NodeLifecycleHook{
		target: descendant_observation
		removed_from: record_node_removed
		moved_from: record_node_moved
	})

	mut new_parent_node := new_parent.as_node()
	moved_node.move_node(mut new_parent_node, none)!
	assert moved_observation.moved_is_subtree_root == .yes
	assert moved_observation.moved_old_ancestor? == old_parent.as_node()
	assert descendant_observation.moved_is_subtree_root == .no
	assert descendant_observation.moved_old_ancestor? == old_parent.as_node()

	moved_node.remove(false)
	assert moved_observation.removed_is_subtree_root == .yes
	assert moved_observation.removed_old_ancestor? == new_parent.as_node()
	assert descendant_observation.removed_is_subtree_root == .no
	assert descendant_observation.removed_old_ancestor? == new_parent.as_node()
}
