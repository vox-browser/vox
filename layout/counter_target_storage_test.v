module layout

import css
import dom
import platform

fn test_counter_free_target_queries_do_not_box_an_abstract_element_copy() {
	mut document := dom.Document.create(dom.url_about_blank())
	defer { document.finalize() }
	element := document.create_element_ns(dom.namespace_html_uri, 'div')!
	target := dom.AbstractElement.new(element, none)
	style := css.css_style_computer_for(document).compute_style(target)
	mut builder := TreeBuilderState{}
	resolve_layout_counters(mut builder, target, style)
	before := platform.thread_arena_usage().used
	for _ in 0 .. 256 { resolve_layout_counters(mut builder, target, style) }
	$if prealloc { assert platform.thread_arena_usage().used - before < 4096 }
	assert builder.counter_tree_order_index == 257
	assert builder.counter_sets.len == 0 && builder.last_child_by_parent.len == 0
	assert builder.last_processed_key == abstract_element_counter_key(target)
}
