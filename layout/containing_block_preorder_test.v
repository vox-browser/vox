module layout

import css
import dom
import html

fn containing_preorder_compare(root &Node) {
	recompute_containing_blocks(root)
	viewport_root := if viewport := root.root_viewport() {
		unsafe { &Node(viewport) }
	} else {
		root
	}
	mut lookup := InlineContainingBlockLookup{}
	collect_inline_containing_block_nodes(viewport_root, mut lookup)
	root.for_each_in_inclusive_subtree(fn [lookup] (node &Node) dom.TraversalDecision {
		before := node.containing_block_
		inline_before := node.inline_containing_block_
		mut mutable_node := unsafe { &Node(node) }
		mutable_node.recompute_containing_block_with_inline_lookup(&lookup)
		if parent := before {
			assert voidptr(node.containing_block_ or { panic('missing containing box') }) == voidptr(parent)
		} else {
			assert node.containing_block_ == none
		}
		if inline := inline_before {
			assert voidptr(node.inline_containing_block_ or { panic('missing inline containing box') }) == voidptr(inline)
		} else {
			assert node.inline_containing_block_ == none
		}
		return .@continue
	})
}

fn test_containing_block_preorder_matches_ancestor_resolution_for_mixed_layout_roles() {
	mut document := html.parse_document('<!doctype html><div style="position:relative"><span style="position:relative">inline <b style="position:absolute">absolute</b><i style="display:block">interruption</i><em style="position:absolute">continuation</em></span><div style="transform:translateX(2px)"><span style="position:fixed">fixed</span></div><div style="float:left">float <span>text</span></div><div style="display:flex"><p>flex <span>inline</span></p><div style="display:grid"><span>grid</span></div></div><table><tr><td>cell <strong>text</strong></td></tr></table></div>')
	defer { document.finalize() }
	_ = layout_document_typed_in_viewport(document, 400, 300)
	containing_preorder_compare(document_layout_result(document)?.root)
}

fn test_containing_block_preorder_subtree_uses_its_existing_outside_parent() {
	mut document := html.parse_document('<!doctype html><div style="position:relative"><section id="part"><p>normal <span style="position:absolute">positioned</span></p></section></div>')
	defer { document.finalize() }
	_ = layout_document_typed_in_viewport(document, 400, 300)
	element := document.get_element_by_id('part')?
	node := unsafe { &Node(element.as_node().unsafe_layout_node()?.real_layout_handle()) }
	containing_preorder_compare(node)
}

fn test_containing_block_preorder_preserves_staged_parent_link_resolution() {
	mut document := dom.Document.create(dom.url_about_blank())
	defer { document.finalize() }
	style := css.ComputedProperties.new()
	mut root := unsafe { &Node(BlockContainer.new(document, none, style)) }
	mut outside := unsafe { &Node(BlockContainer.new(document, none, style)) }
	child := unsafe { &Node(BlockContainer.new(document, none, style)) }
	root.append_child(child)
	outside.append_child(child)
	containing_preorder_compare(root)
	assert voidptr(child.containing_block()?) == voidptr(outside)
}
