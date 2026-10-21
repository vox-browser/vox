module html

import dom
import platform

fn test_declarative_shadow_traversal_retires_ordinary_child_snapshots() {
	mut document := parse_document('<main id="content">' + '<section><b>text</b><i>more</i></section>'.repeat(64) + '</main>')
	defer { document.finalize() }
	mut arena := platform.new_arena('declarative shadow traversal')
	entry := arena.enter()
	for _ in 0 .. 16 {
		materialize_declarative_shadow_roots(document.as_node())
	}
	arena.leave(entry)
	$if prealloc {
		assert arena.usage().used == 0
	}
	content := document.get_element_by_id('content') or { panic('missing content') }
	assert content.as_node().children_as_vector().len == 64
	assert document.as_node().descendant_text_content() == 'textmore'.repeat(64)
	arena.release()
}

fn test_declarative_shadow_content_survives_snapshot_retirement() {
	mut document := parse_document('<main id="outer"><template shadowrootmode="open">before<section id="inner"><template shadowrootmode="closed"><b>nested</b></template>light</section>after</template><i>outside</i></main>')
	defer { document.finalize() }
	outer := document.get_element_by_id('outer') or { panic('missing outer') }
	root := outer.shadow_root() or { panic('missing outer root') }
	root_node := unsafe { &dom.Node(root) }
	assert root_node.descendant_text_content() == 'beforelightafter'
	inner := root_node.children_as_vector()[1].as_element() or { panic('missing inner') }
	nested := inner.shadow_root() or { panic('missing nested root') }
	assert nested.mode() == .closed
	assert unsafe { &dom.Node(nested) }.descendant_text_content() == 'nested'
	assert outer.as_node().descendant_text_content() == 'outside'
	// Revisit the surviving nodes after the parser snapshots have gone away.
	materialize_declarative_shadow_roots(document.as_node())
	assert root_node.descendant_text_content() == 'beforelightafter'
	assert unsafe { &dom.Node(nested) }.descendant_text_content() == 'nested'
}
