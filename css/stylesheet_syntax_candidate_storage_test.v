module css

import platform

fn test_uncached_stylesheet_candidates_retire_with_their_document_owner() {
	text := '.item{color:red;--value:f([tail],"β😀");width:calc(1px + 2%)}'.repeat(100)
	for maximum_entries in [0, 2] {
		mut cache := &StylesheetSyntaxCache{ max_entries: maximum_entries, max_nodes: 8 }
		mut before := i64(0)
		for iteration in 0 .. 4 {
			if iteration == 1 { before = platform.thread_arena_usage().used }
			mut owner := platform.new_retained_arena('uncached stylesheet owner fixture')
			mut entry := owner.enter()
			values := cache.parse(text)
			$if prealloc {
				assert owner.arena.contains(values.data)
			}
			assert ParserTokenStream.from_values(values).dump_string().contains('color:red')
			assert cache.entries.len == 0
			entry.finish()
			owner.release()
		}
		$if prealloc {
			assert platform.thread_arena_usage().used - before < 8192
		}
	}
}

fn test_published_stylesheet_candidate_owns_its_source_and_values_after_caller_retirement() {
	text := '/*' + 'candidate input '.repeat(300) + '*/a{content:"β😀";--value:f([tail],url("a b"))}'
	expected := ParserTokenStream.from_source(text, 'utf-8').dump_string()
	mut cache := &StylesheetSyntaxCache{}
	mut owner := platform.new_retained_arena('cached stylesheet caller fixture')
	mut entry := owner.enter()
	input := text.clone()
	values := cache.parse(input)
	$if prealloc {
		assert !owner.arena.contains(values.data)
	}
	entry.finish()
	owner.release()
	assert ParserTokenStream.from_values(values).dump_string() == expected
	assert cache.parse(text).data == values.data
	assert cache.entries.len == 1 && cache.entries[0].input == text
}
