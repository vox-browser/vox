module layout

import css
import dom
import html
import platform

fn test_counter_free_layout_prefix_allocates_no_temporary_target_handles() {
	mut document := html.parse_document('<!doctype html><main>' + '<div class="plain">text</div>'.repeat(256) + '</main>')
	defer { document.finalize() }
	_ = layout_document_typed_in_viewport(document, 320, 200)
	elements := css.query_selector_all(document.as_node(), '.plain')
	mut targets := []dom.AbstractElement{cap:elements.len}
	mut styles := []&css.ComputedProperties{cap:elements.len}
	for element in elements {
		targets << dom.AbstractElement.new(element, none)
		styles << css.computed_properties_for_element(element) or { panic('missing style') }
	}
	mut builder := TreeBuilderState{}
	mut storage := platform.new_arena('counter-free target handles')
	entry := storage.enter()
	for index in 0 .. targets.len { resolve_layout_counters(mut builder, targets[index], styles[index]) }
	storage.leave(entry)
	$if prealloc { assert storage.usage().used == 0, '${storage.usage().used} bytes for empty counter targets' }
	storage.release()
	assert builder.counter_tree_order_index == targets.len
	assert builder.counter_sets.len == 0 && builder.last_child_by_parent.len == 0
	for target in targets { assert target.counters_set() == none }
}
