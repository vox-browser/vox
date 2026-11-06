module layout

import dom
import css

fn test_clamped_inline_workspace_retires_full_line_building_before_publishing_clamped_output() {
	$if !prealloc { return }
	mut document := dom.Document.create(dom.url_about_blank())
	document.enable_native_storage()
	mut owner := document.enter_native_storage()
	defer { owner.finish(); document.finalize(); document.release_native_storage() }
	container, mut state, mut used := inline_workspace_fixture(document,
		'one two three four five six seven eight '.repeat(64), 'max-lines:2;continue:collapse')
	root := unsafe { &Node(container) }
	space := AvailableSpace.new(AvailableSize.make_definite(CSSPixels.new(180)), AvailableSize.make_indefinite())
	mut context := BlockFormattingContext.for_root(root, .normal, true)
	_ = run_uncached_inline_formatting_context(mut state, container, mut used, .normal, space, &context)
	context = BlockFormattingContext.for_root(root, .normal, true)
	_ = run_inline_formatting_context_internal(mut state, container, mut used, .normal, space, &context)
	used.line_boxes = []LineBox{}
	context = BlockFormattingContext.for_root(root, .normal, true)
	before_reference := document.native_storage().arena.usage().used
	expected_result := run_uncached_inline_formatting_context(mut state, container, mut used, .normal, space, &context)
	reference_bytes := document.native_storage().arena.usage().used - before_reference
	expected := clamped_workspace_fingerprint(used)
	assert used.line_boxes.len == 2
	used.line_boxes = []LineBox{}
	context = BlockFormattingContext.for_root(root, .normal, true)
	before_owned := document.native_storage().arena.usage().used
	actual := run_inline_formatting_context_internal(mut state, container, mut used, .normal, space, &context)
	owned_bytes := document.native_storage().arena.usage().used - before_owned
	assert actual == expected_result
	assert clamped_workspace_fingerprint(used) == expected
	assert reference_bytes > 4096
	if !retain_clamped_inline_allocations {
		assert owned_bytes < reference_bytes * 9 / 10, 'owned=${owned_bytes} reference=${reference_bytes}'
	}
}
