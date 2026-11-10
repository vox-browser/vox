module layout

import css
import dom

// Ladybird 4b67eca777a99f1d2018d9a27d214d3d83e524cc.
fn test_out_of_flow_change_keeps_ancestor_intrinsic_sizes_but_marks_layout_dirty() {
	for position in ['absolute', 'fixed', 'static'] {
		mut document := dom.Document.create(dom.url_about_blank())
		defer { document.finalize() }
		style := css.ComputedProperties.new()
		mut child_style := css.ComputedProperties.new()
		child_style.set_property_without_modifying_flags(.position, &dom.StyleValue{
			css_text: position
		})
		mut root := BlockContainer.new(document, none, style)
		mut parent := BlockContainer.new(document, none, style)
		mut child := BlockContainer.new(document, none, child_style)
		root.append_child(unsafe { &Node(parent) })
		parent.append_child(unsafe { &Node(child) })
		root.cached_intrinsic_sizes().min_content_width = CSSPixels.new(10)
		parent.cached_intrinsic_sizes().min_content_width = CSSPixels.new(20)
		child.cached_intrinsic_sizes().min_content_width = CSSPixels.new(30)
		original_root_cache := root.cached_intrinsic_sizes_ or { panic('root cache') }
		original_parent_cache := parent.cached_intrinsic_sizes_ or { panic('parent cache') }
		mut child_node := unsafe { &Node(child) }
		child_node.set_needs_layout_update(true)
		assert child_node.needs_layout_update()
		assert unsafe { &Node(parent) }.needs_layout_update()
		assert unsafe { &Node(root) }.needs_layout_update()
		assert child.cached_intrinsic_sizes_ == none
		if position == 'static' {
			assert parent.cached_intrinsic_sizes_ == none
			assert root.cached_intrinsic_sizes_ == none
		} else {
			parent_cache := parent.cached_intrinsic_sizes_ or { panic('${position}: parent cache lost') }
			root_cache := root.cached_intrinsic_sizes_ or { panic('${position}: root cache lost') }
			assert voidptr(parent_cache) == voidptr(original_parent_cache)
			assert voidptr(root_cache) == voidptr(original_root_cache)
			assert parent_cache.min_content_width or { panic('parent width') } == CSSPixels.new(20)
			assert root_cache.min_content_width or { panic('root width') } == CSSPixels.new(10)
		}
	}
}
