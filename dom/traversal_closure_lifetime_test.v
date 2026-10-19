@[has_globals]
module dom

import platform

#include "@DIR/../platform/closure_release_test.h"

$if gcboehm ? {
	fn C.vox_closure_release_watch(owner voidptr)
	fn C.vox_closure_release_run_worker(work fn ())
	fn C.vox_closure_release_owner_alive() u32
}

__global (
	traversal_lifetime_kind    int
	traversal_lifetime_calls   int
	traversal_lifetime_root    = unsafe { &Node(nil) }
	traversal_lifetime_control = unsafe { voidptr(nil) }
)

@[heap]
struct TraversalLifetimeCapture {
	bytes []u8
}

fn traversal_lifetime_run() {
	mut document := Document.create(url_about_blank())
	mut document_node := document.as_node()
	element := document.create_element_ns(namespace_html_uri, 'div') or { panic(err) }
	mut root := element.as_node()
	document_node.append_child(root) or { panic(err) }
	root.append_child(document.create_text_node('first').as_node()) or { panic(err) }
	root.append_child(document.create_text_node('second').as_node()) or { panic(err) }
	traversal_lifetime_root = root
	capture := &TraversalLifetimeCapture{ bytes: []u8{len: 4096} }
	$if gcboehm ? {
		C.vox_closure_release_watch(voidptr(capture))
	}
	callback := fn [capture] (_ &Node) TraversalDecision {
		assert capture.bytes.len == 4096
		traversal_lifetime_calls++
		return .@break
	}
	decision := match traversal_lifetime_kind {
		0 { root.visit_subtree(callback) }
		1 { root.visit_inclusive_subtree(callback) }
		2 { root.visit_shadow_including_descendants(callback) }
		3 { root.visit_shadow_including_inclusive_descendants(callback) }
		else {
			traversal_lifetime_control = voidptr(callback)
			root.for_each_in_subtree(callback)
		}
	}
	assert decision == .@break
}

fn test_owned_visitors_release_captures_after_early_break_without_releasing_the_tree() {
	for kind in 0 .. 5 {
		traversal_lifetime_kind = kind
		traversal_lifetime_calls = 0
		$if gcboehm ? {
			C.vox_closure_release_run_worker(traversal_lifetime_run)
			assert C.vox_closure_release_owner_alive() == if kind == 4 { u32(1) } else { u32(0) }
		} $else {
			traversal_lifetime_run()
		}
		assert traversal_lifetime_calls == 1
		assert traversal_lifetime_root.children.len == 2
		if kind == 4 {
			platform.release_closure(traversal_lifetime_control)
			traversal_lifetime_control = unsafe { nil }
		}
		mut document := traversal_lifetime_root.document()
		document.finalize()
		traversal_lifetime_root = unsafe { nil }
	}
}
