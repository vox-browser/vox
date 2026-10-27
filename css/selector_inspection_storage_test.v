module css

import platform

$if gcboehm ? {
	fn C.GC_get_total_bytes() uint
}

fn test_uncached_target_pseudo_element_reads_retained_selectors_without_allocating() {
	mut compounds := [][]CompoundSelector{}
	for source in ['.ordinary', '.host > ::part(label)::before', '.host::after'] {
		list := parse_selector_with_parser(source, map[string]bool{}) or { panic('invalid selector') }
		compounds << list.selectors[0].compound_selectors()
	}
	before_arena := platform.thread_arena_usage().used
	mut before_gc := uint(0)
	$if gcboehm ? {
		before_gc = C.GC_get_total_bytes()
	}
	for _ in 0 .. 64 {
		assert selector_pseudo_element_uncached([]CompoundSelector{}) == none
		assert selector_pseudo_element_uncached(compounds[0]) == none
		before := selector_pseudo_element_uncached(compounds[1]) or { panic('missing before') }
		after := selector_pseudo_element_uncached(compounds[2]) or { panic('missing after') }
		assert before.type_ == .before
		assert after.type_ == .after
	}
	$if prealloc {
		assert platform.thread_arena_usage().used == before_arena
	}
	$if gcboehm ? {
		assert C.GC_get_total_bytes() == before_gc
	}
}
