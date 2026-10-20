module css

import platform

fn test_invalidation_projection_reads_selector_records_without_heap_copies() {
	selectors := selector_from_text('.class#identifier[tag]:hover').compound_selectors()[0].simple_selectors
	before := platform.thread_arena_usage().used
	mut matches := 0
	for _ in 0 .. 1024 {
		for index in 0 .. selectors.len {
			projected := simple_selector_for_invalidation(unsafe { &selectors[index] })
			if projected.type_ == .class && projected.name == 'class' { matches++ }
			if projected.type_ == .id && projected.name == 'identifier' { matches++ }
			if projected.type_ == .attribute && projected.name == 'tag' { matches++ }
			if projected.type_ == .pseudo_class && projected.pseudo_class == .hover { matches++ }
		}
	}
	$if prealloc { assert platform.thread_arena_usage().used - before < 1024 }
	assert matches == 4096
}

fn test_invalidation_projection_preserves_nested_and_slotted_selector_inputs() {
	selector := selector_from_text('a:is(.one, #two) > b:has(+ .next)')
	before := selector.serialize()
	groups := selector_groups_for_invalidation(selector)
	assert groups.len == 2
	assert groups[0].simple_selectors.last().nested_selectors[0].serialize().contains('.next')
	assert groups[1].simple_selectors.last().nested_selectors.len == 2
	assert selector.serialize() == before
	assert selector_contains_pseudo_class(selector, .has)
}
