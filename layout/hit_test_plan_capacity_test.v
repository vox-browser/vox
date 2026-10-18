module layout

import html

fn test_preallocated_hit_plan_preserves_every_phase_and_transparent_context() {
	mut document := html.parse_document('<!doctype html><style>html,body{margin:0}.float{float:left}.inline{display:inline-block}.positioned{position:relative}.transparent{opacity:0}.singular{transform:scale(0)}.negative{position:relative;z-index:-2}.positive{position:relative;z-index:2}</style><div><div class="float">float</div><span class="inline">inline</span><div class="positioned"><div class="transparent">transparent</div></div><div class="singular">singular</div><div class="negative">negative</div><div class="positive">positive</div></div>')
	defer { document.finalize() }
	result := run_document_layout(document, 400, 200) or { panic('missing layout') }
	box := renderer_box_from_document_layout_result(result, 400, 200)
	entries := box.paint_order_entries()
	mut previous := []CompatibilityPaintStep{}
	box.collect_compatibility_stacking_context_paint_steps(mut previous, true)
	actual := box.compatibility_hit_test_steps(entries.len)
	assert actual.len == previous.len
	assert actual.cap == entries.len * compatibility_paint_phase_count
	for index, step in actual {
		assert step.box == previous[index].box
		assert step.phase == previous[index].phase
	}
}

fn test_document_sized_hit_plan_uses_one_phase_allocation_without_excess_capacity() {
	mut document := html.parse_document('<!doctype html><main>' + '<div><span>comment</span><br>reply</div>'.repeat(300) + '</main>')
	defer { document.finalize() }
	result := run_document_layout(document, 400, 200) or { panic('missing layout') }
	box := renderer_box_from_document_layout_result(result, 400, 200)
	entries := box.paint_order_entries()
	actual := box.compatibility_hit_test_steps(entries.len)
	assert actual.len > 1000
	assert actual.len <= entries.len * compatibility_paint_phase_count
	assert actual.cap == entries.len * compatibility_paint_phase_count
	assert actual.len > actual.cap / 2
}
