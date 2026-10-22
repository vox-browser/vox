module dom

@[heap]
struct NodeHookProbe {
	proxy &WindowProxy = &WindowProxy{}
mut:
	delays       bool = true
	adoptions    int
	removals     int
	moves        int
	old_document voidptr
	old_ancestor voidptr
	old_root     voidptr
	subtree_root NodeIsSubtreeRoot
}

fn node_hook_delays(target voidptr) bool {
	return unsafe { &NodeHookProbe(target) }.delays
}

fn node_hook_proxy(target voidptr) ?&WindowProxy {
	return unsafe { &NodeHookProbe(target) }.proxy
}

fn node_hook_adopted(target voidptr, document &Document) {
	mut probe := unsafe { &NodeHookProbe(target) }
	probe.adoptions++
	probe.old_document = voidptr(document)
}

fn node_hook_removed(target voidptr, root NodeIsSubtreeRoot, ancestor ?&Node, old_root &Node) {
	mut probe := unsafe { &NodeHookProbe(target) }
	probe.removals++
	probe.subtree_root = root
	probe.old_ancestor = if node := ancestor { voidptr(node) } else { unsafe { nil } }
	probe.old_root = voidptr(old_root)
}

fn node_hook_moved(target voidptr, root NodeIsSubtreeRoot, ancestor ?&Node) {
	mut probe := unsafe { &NodeHookProbe(target) }
	probe.moves++
	probe.subtree_root = root
	probe.old_ancestor = if node := ancestor { voidptr(node) } else { unsafe { nil } }
}

fn test_nodes_without_behavior_do_not_allocate_hook_storage() {
	mut document := Document.create(url_about_blank())
	text := document.create_text_node('ordinary')
	mut node := text.as_node()
	assert node.hooks_ == unsafe { nil }
	node.set_load_event_delay_hook(none)
	node.set_active_window_proxy_hook(none)
	node.set_adopted_from_hook(none)
	node.set_lifecycle_hook(none)
	assert !node.currently_delays_the_load_event()
	assert node.active_window_proxy() == none
	node.adopted_from(document)
	node.removed_from_with_context(.yes, none, document.as_node())
	node.moved_from_with_context(.no, none)
	assert node.hooks_ == unsafe { nil }
}

fn test_optional_node_hooks_preserve_targets_and_lifecycle_arguments() {
	mut document := Document.create(url_about_blank())
	text := document.create_text_node('hooked')
	mut node := text.as_node()
	probe := &NodeHookProbe{}
	node.set_load_event_delay_hook(NodeLoadEventDelayHook{ target: probe, callback: node_hook_delays })
	storage := node.hooks_
	node.set_active_window_proxy_hook(NodeActiveWindowProxyHook{ target: probe, callback: node_hook_proxy })
	node.set_adopted_from_hook(NodeAdoptedFromHook{ target: probe, callback: node_hook_adopted })
	node.set_lifecycle_hook(NodeLifecycleHook{ target: probe, removed_from: node_hook_removed, moved_from: node_hook_moved })
	gc_collect()
	assert voidptr(storage) == voidptr(node.hooks_)
	assert node.currently_delays_the_load_event()
	proxy := node.active_window_proxy() or { panic('missing proxy') }
	assert voidptr(proxy) == voidptr(probe.proxy)
	node.adopted_from(document)
	assert probe.adoptions == 1
	assert probe.old_document == voidptr(document)
	node.removed_from_with_context(.no, document.as_node(), document.as_node())
	assert probe.removals == 1
	assert probe.subtree_root == .no
	assert probe.old_ancestor == voidptr(document.as_node())
	assert probe.old_root == voidptr(document.as_node())
	node.moved_from_with_context(.yes, none)
	assert probe.moves == 1
	assert probe.subtree_root == .yes
	assert probe.old_ancestor == unsafe { nil }
	node.set_load_event_delay_hook(none)
	node.set_lifecycle_hook(none)
	assert !node.currently_delays_the_load_event()
	node.removed_from_with_context(.yes, none, document.as_node())
	node.moved_from_with_context(.yes, none)
	assert probe.removals == 1
	assert probe.moves == 1
	// Clearing one hook leaves the other independently installed hooks live.
	assert node.active_window_proxy() != none
	node.adopted_from(document)
	assert probe.adoptions == 2
	node.set_adopted_from_hook(none)
	node.set_active_window_proxy_hook(none)
	node.adopted_from(document)
	assert probe.adoptions == 2
	assert node.active_window_proxy() == none
}

fn test_replacing_node_hooks_reuses_storage_and_ignores_empty_callbacks() {
	mut document := Document.create(url_about_blank())
	text := document.create_text_node('replacement')
	mut node := text.as_node()
	first := &NodeHookProbe{}
	second := &NodeHookProbe{}
	node.set_adopted_from_hook(NodeAdoptedFromHook{ target: first, callback: node_hook_adopted })
	storage := node.hooks_
	node.set_adopted_from_hook(NodeAdoptedFromHook{ target: second, callback: node_hook_adopted })
	gc_collect()
	node.adopted_from(document)
	assert first.adoptions == 0
	assert second.adoptions == 1
	assert voidptr(storage) == voidptr(node.hooks_)
	node.set_load_event_delay_hook(NodeLoadEventDelayHook{})
	node.set_active_window_proxy_hook(NodeActiveWindowProxyHook{})
	node.set_adopted_from_hook(NodeAdoptedFromHook{})
	node.set_lifecycle_hook(NodeLifecycleHook{})
	assert !node.currently_delays_the_load_event()
	assert node.active_window_proxy() == none
	node.adopted_from(document)
	node.removed_from_with_context(.yes, none, document.as_node())
	node.moved_from_with_context(.no, none)
	assert second.adoptions == 1
}
