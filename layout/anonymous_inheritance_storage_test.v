module layout

import css
import dom
import platform

fn test_repeated_anonymous_style_propagation_preserves_snapshots_without_document_growth() {
	mut document := dom.Document.create(dom.url_about_blank())
	document.enable_native_storage()
	owner := document.native_storage()
	mut allocations := document.enter_native_storage()
	mut source := css.ComputedProperties.new()
	_ = css.resolve_computed_values_for_document(source, document)
	mut root := BlockContainer.with_resolved_values(document, none, source)
	mut root_node := unsafe { &Node(root) }
	child := create_anonymous_block_wrapper(document, source)
	root_node.append_child(child)
	mut parent := unsafe { &NodeWithStyle(root) }
	parent.propagate_style_to_anonymous_wrappers()
	mut styled_child := unsafe { &NodeWithStyle(child) }
	assert css.layout_inheritance_is_current(styled_child.inherited_style_proof_,
		styled_child.computed_values_, source, document)
	before := if owner != unsafe { nil } { owner.arena.usage().used } else { i64(0) }
	for _ in 0 .. 1024 { parent.propagate_style_to_anonymous_wrappers() }
	$if prealloc { assert owner.arena.usage().used - before < 8 * 1024 }
	previous := *styled_child.computed_values_
	previous_color := previous.color()
	mut source_values := unsafe { &css.MutableComputedValues(source) }
	source_values.set_color(css.Color{12, 34, 56, 255})
	parent.propagate_style_to_anonymous_wrappers()
	assert styled_child.computed_values_.color() == css.Color{12, 34, 56, 255}
	assert previous.color() == previous_color
	mut child_values := unsafe { &css.MutableComputedValues(styled_child.computed_values_) }
	child_values.set_color(css.Color{99, 88, 77, 255})
	parent.propagate_style_to_anonymous_wrappers()
	assert styled_child.computed_values_.color() == css.Color{12, 34, 56, 255}
	allocations.finish()
	document.finalize()
	document.release_native_storage()
	$if prealloc {
		for _ in 0 .. 100 {
			if owner.arena.usage().capacity == 0 { break }
			platform.pump_native_events(0.01)
		}
		assert owner.arena.usage().capacity == 0
	}
}
