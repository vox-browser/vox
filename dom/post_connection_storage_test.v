module dom

import platform

fn test_post_connection_steps_retire_their_private_node_snapshot() {
	mut document := Document.create(url_about_blank())
	defer { document.finalize() }
	root := document.create_element_ns(namespace_html_uri, 'div')!
	mut root_node := root.as_node()
	for _ in 0 .. 128 { root_node.append_child(document.create_text_node('child').as_node())! }
	mut document_node := document.as_node()
	document_node.append_child(root_node)!
	roots := [root_node]
	storage := root_node.children.data
	run_post_connection_steps(roots)
	before := platform.thread_arena_usage().used
	for _ in 0 .. 128 { run_post_connection_steps(roots) }
	$if prealloc { assert platform.thread_arena_usage().used - before < 4096 }
	assert root_node.is_connected()
	assert root_node.children.len == 128 && root_node.children.data == storage
	assert root_node.children[127].text_content()? == 'child'
}
