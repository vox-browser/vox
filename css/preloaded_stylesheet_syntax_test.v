module css

import platform

fn preloaded_stylesheet_test_source(rules string) string {
	return '/*' + 'padding'.repeat(640) + '*/' + rules
}

fn prepare_stylesheet_in_retiring_fetch_scratch(source string) {
	scratch := platform.begin_thread_scratch('test stylesheet fetch response')
	defer { scratch.finish() }
	prepare_preloaded_stylesheet_syntax(source.clone())
}

fn test_preloaded_syntax_owns_worker_input_and_converts_in_the_consumers_context() {
	release_unused_stylesheet_syntax()
	defer { release_unused_stylesheet_syntax() }
	source := preloaded_stylesheet_test_source('@namespace s url("urn:probe"); s|a { --size: calc(2px + 3px); color: red } @media (width > 1px) { .parent { & > .child { width: 11px } } }')
	if !preloaded_stylesheet_syntax_eligible(source) { return }
	location := 'https://styles.test/a.css'
	reference := parse_css_stylesheet_in_workspace(ParsingParams{}, source, location, none, true)
	worker := spawn prepare_stylesheet_in_retiring_fetch_scratch(source)
	worker.wait()
	changed := source.replace('color: red', 'color: tan')
	assert preloaded_stylesheet_syntax_.take(changed) == none
	actual := parse_css_stylesheet_in_workspace(ParsingParams{}, source, location, none, true)
	assert preloaded_stylesheet_syntax_.take(source) == none
	assert actual.rules.length() == 3
	assert actual.rules.length() == reference.rules.length()
	for index, rule in actual.rules.rules {
		assert rule.css_text() == reference.rules.rules[index].css_text()
	}
}

fn test_preloaded_syntax_evicts_old_leases_and_clears_idle_entries() {
	release_unused_stylesheet_syntax()
	defer { release_unused_stylesheet_syntax() }
	first := preloaded_stylesheet_test_source('.probe-0 { color: red }')
	if !preloaded_stylesheet_syntax_eligible(first) { return }
	for index in 0 .. preloaded_stylesheet_syntax_slots + 1 {
		source := preloaded_stylesheet_test_source('.probe-${index} { color: red }')
		worker := spawn prepare_stylesheet_in_retiring_fetch_scratch(source)
		worker.wait()
	}
	assert preloaded_stylesheet_syntax_.take(first) == none
	last := preloaded_stylesheet_test_source('.probe-${preloaded_stylesheet_syntax_slots} { color: red }')
	mut staged := preloaded_stylesheet_syntax_.take(last) or { panic('missing latest stylesheet') }
	release_unused_stylesheet_syntax()
	assert staged.rules.len == 1
	assert staged.input == last
	assert staged.storage.capacity() > 0
	staged.storage.discard(preloaded_stylesheet_syntax_label)
	assert staged.storage.capacity() == 0
	for index in 1 .. preloaded_stylesheet_syntax_slots {
		assert preloaded_stylesheet_syntax_.take(preloaded_stylesheet_test_source('.probe-${index} { color: red }')) == none
	}
}

fn test_preloaded_syntax_accepts_concurrent_producers() {
	release_unused_stylesheet_syntax()
	defer { release_unused_stylesheet_syntax() }
	mut inputs := []string{}
	for index in 0 .. preloaded_stylesheet_syntax_slots {
		inputs << preloaded_stylesheet_test_source('.probe-${index} { width: ${index + 1}px }')
	}
	if !preloaded_stylesheet_syntax_eligible(inputs[0]) { return }
	mut workers := []thread{}
	for source in inputs { workers << spawn prepare_stylesheet_in_retiring_fetch_scratch(source) }
	for worker in workers { worker.wait() }
	for source in inputs {
		mut staged := preloaded_stylesheet_syntax_.take(source) or { panic('missing stylesheet') }
		assert staged.rules.len == 1
		staged.storage.discard(preloaded_stylesheet_syntax_label)
	}
}
