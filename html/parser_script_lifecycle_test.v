module html

import dom
import fetch
import mimesniff

@[heap]
struct ParserScriptObservation {
mut:
	executed    []string
	requests    map[string]&HTMLScriptElementModel
	retained    ?&dom.Element
	clicks      int
	creations   int
	completions int
	load_delayer ?dom.DocumentLoadEventDelayer
	reopened     bool
}

fn parser_script_document() !&dom.Document {
	address := dom.URL{value: 'https://parser-script.test/page'}
	mut document := create_navigation_document(address, address.origin(), none)!
	document.set_document_type(.html)
	document.set_ready_to_run_scripts()
	install_document_fragment_parsing_hook(document)
	return document
}

fn parser_script_drain_tasks() {
	mut queue := main_thread_event_loop().task_queue()
	for _ in 0 .. 64 {
		task := queue.take_first_runnable() or { return }
		task.execute()
	}
	assert false, 'parser script fixture did not settle'
}

fn parser_script_track_readiness(document &dom.Document, observation &ParserScriptObservation) {
	for name in ['DOMContentLoaded', 'load'] {
		target := if name == 'load' {
			unsafe { &dom.EventTarget(document.get_window() or { panic('missing Window') }) }
		} else { unsafe { &dom.EventTarget(document) } }
		target.add_event_listener_without_options(name, dom.IDLEventListener.create(&dom.CallbackType{
			handle_event: fn [observation, document, name] (_ &dom.Event, _ ?&dom.EventTarget) dom.JSValue {
				assert document.current_script() == none
				mut observed := unsafe { &ParserScriptObservation(observation) }
				observed.executed << name
				return dom.js_undefined()
			}
		}))
	}
}

fn parser_script_record_fetch(observation &ParserScriptObservation) ScriptElementAsyncFetchHook {
	return fn [observation] (script &HTMLScriptElementModel, address dom.URL, _ ScriptElementType) ! {
		mut observed := unsafe { &ParserScriptObservation(observation) }
		observed.requests[address.serialize()] = script
		assert script.element() != none
	}
}

fn test_parser_scripts_observe_only_preceding_markup_and_actual_current_script() {
	mut document := parser_script_document()!
	defer { document.finalize() }
	observation := &ParserScriptObservation{}
	mut parser := HTMLParser.create(document,
		'<!doctype html><body><p id="before">before</p><script id="first">first</script><p id="after">after</p><script id="second">second</script>')
	parser.set_script_execute_hook_with_element(fn [document, observation] (element &dom.HTMLScriptElement, kind ScriptElementType, source string, _ dom.URL) ! {
		assert kind == .classic
		assert voidptr(document.current_script()?) == voidptr(element)
		assert document.readiness() == .loading
		assert document.get_element_by_id('before') != none
		if source == 'first' { assert document.get_element_by_id('after') == none }
		if source == 'second' { assert document.get_element_by_id('after') != none }
		mut observed := unsafe { &ParserScriptObservation(observation) }
		observed.executed << source
	})
	parser.run()
	assert observation.executed == ['first', 'second']
	assert document.current_script() == none
	assert parser.current_script_nesting_level() == 0
	parser_script_drain_tasks()
	assert document.readiness() == .complete
}

fn test_document_write_preserves_nodes_mutations_listeners_and_nested_insertion_points() {
	mut document := parser_script_document()!
	defer { document.finalize() }
	observation := &ParserScriptObservation{}
	mut parser := HTMLParser.create(document,
		'<!doctype html><body><script id="writer">outer</script><p id="after">after</p>')
	parser.set_script_execute_hook_with_element(fn [document, observation] (element &dom.HTMLScriptElement, _ ScriptElementType, source string, _ dom.URL) ! {
		mut owner := unsafe { &dom.Document(document) }
		mut observed := unsafe { &ParserScriptObservation(observation) }
		observed.executed << source
		assert owner.get_element_by_id('after') == none
		assert voidptr(owner.current_script()?) == voidptr(element)
		if source == 'nested' {
			owner.write_strings(['<b id="nested-write">nested</b>'])!
			return
		}
		// open() during a parser-inserted script leaves the active tree alone.
		assert voidptr(owner.open()!) == voidptr(owner)
		owner.write_strings(['<div id="written">one'])!
		mut written := owner.get_element_by_id('written')?
		observed.retained = written
		written.set_attribute_value('data-mutated', 'kept')
		unsafe { &dom.EventTarget(written) }.add_event_listener_without_options('click',
			dom.IDLEventListener.create(&dom.CallbackType{
				handle_event: fn [observation] (_ &dom.Event, _ ?&dom.EventTarget) dom.JSValue {
					mut state := unsafe { &ParserScriptObservation(observation) }
					state.clicks++
					return dom.js_undefined()
				}
			}))
		owner.write_strings(['<span>two</span></div>'])!
		assert voidptr(owner.get_element_by_id('written')?) == voidptr(written)
		assert written.get_attribute_value('data-mutated') == 'kept'
		assert written.as_node().text_content()? == 'onetwo'
		written.as_node().dispatch_event(dom.Event.create('click', dom.EventInit{}))
		owner.write_strings(['<script id="nested-script">nested</script>'])!
		assert voidptr(owner.current_script()?) == voidptr(element)
		assert owner.parser.is_insertion_point_defined()
		owner.write_strings([''])!
		owner.write_strings([''])!
		assert owner.parser.is_insertion_point_defined()
		assert voidptr(owner.get_element_by_id('written')?) == voidptr(written)
		owner.write_strings(['<i id="last-write">last</i>'])!
	})
	parser.run()
	assert observation.executed == ['outer', 'nested']
	assert observation.clicks == 1
	assert voidptr(document.get_element_by_id('written')?) == voidptr(observation.retained?)
	assert document.get_element_by_id('nested-write') != none
	assert document.get_element_by_id('last-write') != none
	assert document.get_element_by_id('after') != none
	assert !parser.tokenizer.is_insertion_point_defined()
	parser_script_drain_tasks()
}

fn test_external_parser_script_pauses_and_resumes_before_trailing_markup() {
	mut document := parser_script_document()!
	defer { document.finalize() }
	observation := &ParserScriptObservation{}
	mut parser := HTMLParser.create(document,
		'<!doctype html><body><script src="blocking.js"></script><p id="after">after</p>')
	parser.set_async_script_fetch_hook(parser_script_record_fetch(observation))
	parser.set_script_execute_hook_with_element(fn [document, observation] (element &dom.HTMLScriptElement, _ ScriptElementType, source string, address dom.URL) ! {
		assert address.serialize() == 'https://parser-script.test/blocking.js'
		assert voidptr(document.current_script()?) == voidptr(element)
		assert document.get_element_by_id('after') == none
		mut owner := unsafe { &dom.Document(document) }
		owner.write_strings(['<p id="written">written before the tail</p>'])!
		mut observed := unsafe { &ParserScriptObservation(observation) }
		observed.executed << source
	})
	parser.run()
	assert parser.paused()
	assert document.readiness() == .loading
	assert document.get_element_by_id('after') == none
	assert document.anything_is_delaying_the_load_event()
	mut script := observation.requests['https://parser-script.test/blocking.js']
	script.complete_external_fetch('blocking')
	assert observation.executed.len == 0
	parser_script_drain_tasks()
	assert observation.executed == ['blocking']
	assert !parser.paused()
	assert document.get_element_by_id('written') != none
	assert document.get_element_by_id('after') != none
	assert script.event_count('load') == 1
	assert document.readiness() == .complete
}

fn test_cached_external_script_written_by_a_script_waits_for_the_outer_evaluation() {
	mut document := parser_script_document()!
	defer { document.finalize() }
	observation := &ParserScriptObservation{}
	mut parser := HTMLParser.create(document,
		'<!doctype html><body><script>outer</script><p id="after">after</p>')
	parser.set_async_script_fetch_hook(fn (model &HTMLScriptElementModel, _ dom.URL, _ ScriptElementType) ! {
		mut cached := unsafe { &HTMLScriptElementModel(model) }
		cached.complete_external_fetch('cached')
	})
	parser.set_script_execute_hook_with_element(fn [document, observation] (element &dom.HTMLScriptElement, _ ScriptElementType, source string, _ dom.URL) ! {
		mut owner := unsafe { &dom.Document(document) }
		mut observed := unsafe { &ParserScriptObservation(observation) }
		assert voidptr(owner.current_script()?) == voidptr(element)
		assert owner.get_element_by_id('after') == none
		if source == 'outer' {
			observed.executed << 'outer-start'
			owner.write_strings(['<script src="cached.js"></script><p id="written-tail">tail</p>'])!
			assert observed.executed == ['outer-start']
			assert owner.get_element_by_id('written-tail') == none
			observed.executed << 'outer-end'
		} else {
			observed.executed << source
			assert owner.get_element_by_id('written-tail') == none
			owner.write_strings(['<b id="nested-output">nested</b>'])!
		}
	})
	parser.run()
	assert parser.paused()
	assert observation.executed == ['outer-start', 'outer-end']
	parser_script_drain_tasks()
	assert observation.executed == ['outer-start', 'outer-end', 'cached']
	assert !parser.paused()
	assert document.get_element_by_id('nested-output') != none
	assert document.get_element_by_id('written-tail') != none
	assert document.get_element_by_id('after') != none
}

fn test_initial_async_script_does_not_block_parsing_or_dom_content_loaded() {
	mut document := parser_script_document()!
	defer { document.finalize() }
	observation := &ParserScriptObservation{}
	parser_script_track_readiness(document, observation)
	mut parser := HTMLParser.create(document,
		'<!doctype html><body><script async src="slow.js"></script><script>inline</script><p id="after">after</p>')
	parser.set_async_script_fetch_hook(parser_script_record_fetch(observation))
	parser.set_script_execute_hook_with_element(fn [document, observation] (element &dom.HTMLScriptElement, _ ScriptElementType, source string, _ dom.URL) ! {
		assert voidptr(document.current_script()?) == voidptr(element)
		if source == 'async' {
			assert document.get_element_by_id('after') != none
			// No parser insertion point remains. External async writes must not
			// implicitly reopen and erase the completed document.
			mut owner := unsafe { &dom.Document(document) }
			owner.write_strings(['<p id="destructive">wrong</p>'])!
			assert owner.get_element_by_id('after') != none
			assert owner.get_element_by_id('destructive') == none
		}
		mut observed := unsafe { &ParserScriptObservation(observation) }
		observed.executed << source
	})
	parser.run()
	assert !parser.paused()
	assert document.get_element_by_id('after') != none
	parser_script_drain_tasks()
	assert observation.executed == ['inline', 'DOMContentLoaded']
	assert document.readiness() == .interactive
	mut script := observation.requests['https://parser-script.test/slow.js']
	script.complete_external_fetch('async')
	script.complete_external_fetch('must not run twice')
	assert observation.executed == ['inline', 'DOMContentLoaded']
	parser_script_drain_tasks()
	assert observation.executed == ['inline', 'DOMContentLoaded', 'async', 'load']
	assert script.event_count('load') == 1
	assert !document.anything_is_delaying_the_load_event()
	assert document.readiness() == .complete
}

fn test_load_delay_started_by_dom_content_loaded_keeps_parser_readiness_pending() {
	mut document := parser_script_document()!
	defer { document.finalize() }
	observation := &ParserScriptObservation{}
	parser_script_track_readiness(document, observation)
	unsafe { &dom.EventTarget(document) }.add_event_listener_without_options('DOMContentLoaded',
		dom.IDLEventListener.create(&dom.CallbackType{
			handle_event: fn [document, observation] (_ &dom.Event, _ ?&dom.EventTarget) dom.JSValue {
				mut owner := unsafe { &dom.Document(document) }
				mut observed := unsafe { &ParserScriptObservation(observation) }
				observed.load_delayer = dom.DocumentLoadEventDelayer.new(mut owner)
				return dom.js_undefined()
			}
		}))
	mut parser := HTMLParser.create(document, '<!doctype html><body><p>ready</p>')
	parser.run()
	parser_script_drain_tasks()
	assert observation.executed == ['DOMContentLoaded']
	assert document.readiness() == .interactive
	assert document.has_html_parser_end_state()
	assert !document.document_ready_for_post_load_tasks()
	mut delay := observation.load_delayer?
	delay.finish()
	parser_script_drain_tasks()
	assert observation.executed == ['DOMContentLoaded', 'load']
	assert document.readiness() == .complete
	assert !document.has_html_parser_end_state()
	assert document.document_ready_for_post_load_tasks()
}

fn test_deferred_scripts_keep_document_order_and_module_readiness_uses_parser_end_state() {
	mut document := parser_script_document()!
	defer { document.finalize() }
	observation := &ParserScriptObservation{}
	parser_script_track_readiness(document, observation)
	mut parser := HTMLParser.create(document,
		'<!doctype html><body><script defer src="first.js"></script><script type="module" id="module">module</script><script defer src="second.js"></script><script async defer>inline</script><p id="after">after</p>')
	parser.set_async_script_fetch_hook(parser_script_record_fetch(observation))
	parser.set_script_execute_hook_with_element(fn [document, observation] (element &dom.HTMLScriptElement, kind ScriptElementType, source string, _ dom.URL) ! {
		if kind == .module {
			assert document.current_script() == none
			assert unsafe { &dom.Element(element) }.get_attribute_value('id') == 'module'
			mut owner := unsafe { &dom.Document(document) }
			owner.begin_module_readiness_delay()
		} else {
			assert voidptr(document.current_script()?) == voidptr(element)
		}
		if source != 'inline' { assert document.get_element_by_id('after') != none }
		mut observed := unsafe { &ParserScriptObservation(observation) }
		observed.executed << source
	})
	parser.run()
	assert !parser.paused()
	assert observation.executed == ['inline']
	mut second := observation.requests['https://parser-script.test/second.js']
	second.complete_external_fetch('second')
	parser_script_drain_tasks()
	assert observation.executed == ['inline']
	mut first := observation.requests['https://parser-script.test/first.js']
	first.complete_external_fetch('first')
	parser_script_drain_tasks()
	assert observation.executed == ['inline', 'first', 'module']
	assert document.readiness() == .interactive
	// An unrelated resource completion must not advance past a module whose
	// graph is still loading.
	document.schedule_html_parser_end_check()
	parser_script_drain_tasks()
	assert observation.executed == ['inline', 'first', 'module']
	document.end_module_readiness_delay()
	parser_script_drain_tasks()
	assert observation.executed == ['inline', 'first', 'module', 'second', 'DOMContentLoaded', 'load']
	assert first.event_count('load') == 1 && second.event_count('load') == 1
}

fn test_failed_or_cancelled_parser_fetch_releases_the_parser_and_load_delay_once() {
	for cancel in [false, true] {
		mut document := parser_script_document()!
		defer { document.finalize() }
		observation := &ParserScriptObservation{}
		mut parser := HTMLParser.create(document,
			'<!doctype html><body><script src="missing.js"></script><p id="after">after</p>')
		parser.set_async_script_fetch_hook(parser_script_record_fetch(observation))
		parser.run()
		assert parser.paused()
		mut script := observation.requests['https://parser-script.test/missing.js']
		if cancel { script.cancel_external_fetch() } else { script.complete_external_fetch(none) }
		script.complete_external_fetch('late completion')
		parser_script_drain_tasks()
		assert document.get_element_by_id('after') != none
		assert !parser.paused()
		assert !document.anything_is_delaying_the_load_event()
		assert script.event_count('error') == if cancel { 0 } else { 1 }
		assert script.event_count('load') == 0
	}
}

fn test_adopted_async_script_does_not_execute_in_its_old_document() {
	mut document := parser_script_document()!
	mut destination := parser_script_document()!
	defer {
		document.finalize()
		destination.finalize()
	}
	observation := &ParserScriptObservation{}
	mut parser := HTMLParser.create(document, '<script async src="adopted.js"></script>')
	parser.set_async_script_fetch_hook(parser_script_record_fetch(observation))
	parser.set_script_hooks(none, fn (_ ScriptElementType, _ string, _ dom.URL) ! {
		return error('an adopted script must not be evaluated in its preparation document')
	})
	parser.run()
	mut script := observation.requests['https://parser-script.test/adopted.js']
	element := script.element()?
	destination.adopt_node(unsafe { &dom.Node(element) })
	script.complete_external_fetch('never execute')
	parser_script_drain_tasks()
	assert !document.anything_is_delaying_the_load_event()
	assert !destination.anything_is_delaying_the_load_event()
	assert !document.has_scripts_to_execute_as_soon_as_possible()
	assert script.event_count('load') == 0 && script.event_count('error') == 0
}

fn test_document_open_resets_readiness_and_ignores_previous_stream_tasks() {
	for finish_first_stream in [false, true] {
		mut document := parser_script_document()!
		defer { document.finalize() }
		mut first := HTMLParser.create(document, '<!doctype html><p id="first">first</p>')
		first.run()
		if finish_first_stream {
			parser_script_drain_tasks()
			assert document.readiness() == .complete
			assert document.is_completely_loaded()
		} else {
			// Leave both the first stream's DCL and load tasks queued.
			mut old_end := unsafe { &HTMLParserEndState(document.html_parser_end_state()) }
			old_end.check_progress()
			assert old_end.phase() == .completion_queued
		}
		generation := document.html_parser_stream_generation()
		document.open()!
		assert document.html_parser_stream_generation() == generation + 1
		assert document.readiness() == .loading
		assert !document.fired_dom_content_loaded && !document.fired_load_event
		assert !document.is_completely_loaded()
		assert !document.document_ready_for_post_load_tasks()
		observation := &ParserScriptObservation{}
		parser_script_track_readiness(document, observation)
		mut second := unsafe { &HTMLParser(document.parser.target) }
		second.set_async_script_fetch_hook(parser_script_record_fetch(observation))
		second.set_script_hooks(none, fn [observation] (_ ScriptElementType, source string, _ dom.URL) ! {
			mut observed := unsafe { &ParserScriptObservation(observation) }
			observed.executed << source
		})
		document.write_strings(['<!doctype html><body><script async src="second.js"></script><p id="second">second</p>'])!
		document.close()!
		parser_script_drain_tasks()
		assert observation.executed == ['DOMContentLoaded']
		assert document.readiness() == .interactive
		assert !document.is_completely_loaded()
		mut request := observation.requests['https://parser-script.test/second.js']
		request.complete_external_fetch('second-stream')
		parser_script_drain_tasks()
		assert observation.executed == ['DOMContentLoaded', 'second-stream', 'load']
		assert document.readiness() == .complete
		assert document.is_completely_loaded()
		assert document.get_element_by_id('first') == none
		assert document.get_element_by_id('second') != none
	}
}

fn test_reentrant_document_open_during_readiness_preserves_the_new_stream() {
	for stage in ['interactive', 'complete', 'load'] {
		mut document := parser_script_document()!
		defer { document.finalize() }
		observation := &ParserScriptObservation{}
		target := if stage == 'load' {
			unsafe { &dom.EventTarget(document.get_window()?) }
		} else { unsafe { &dom.EventTarget(document) } }
		target.add_event_listener_without_options(if stage == 'load' { 'load' } else { 'readystatechange' },
			dom.IDLEventListener.create(&dom.CallbackType{
				handle_event: fn [document, observation, stage] (_ &dom.Event, _ ?&dom.EventTarget) dom.JSValue {
					mut observed := unsafe { &ParserScriptObservation(observation) }
					if observed.reopened || (stage != 'load' && document.ready_state() != stage) {
						return dom.js_undefined()
					}
					observed.reopened = true
					mut owner := unsafe { &dom.Document(document) }
					owner.open() or { panic(err) }
					owner.write_strings(['<body><p id="replacement">new stream</p>']) or { panic(err) }
					return dom.js_undefined()
				}
			}))
		mut parser := HTMLParser.create(document, '<!doctype html><p id="first">first</p>')
		parser.run()
		parser_script_drain_tasks()
		assert observation.reopened
		assert document.readiness() == .loading
		assert document.parser != unsafe { nil }
		assert document.parser.is_script_created()
		assert !document.is_completely_loaded()
		assert !document.fired_load_event
		assert document.get_element_by_id('replacement') != none
		document.close()!
		parser_script_drain_tasks()
		assert document.readiness() == .complete
		assert document.is_completely_loaded()
	}
}

fn parser_script_configure_created(target voidptr, parser &HTMLParser) {
	observation := unsafe { &ParserScriptObservation(target) }
	mut observed := unsafe { &ParserScriptObservation(observation) }
	observed.creations++
	mut configured := unsafe { &HTMLParser(parser) }
	configured.set_script_hooks(none, fn [observation] (_ ScriptElementType, source string, _ dom.URL) ! {
		mut state := unsafe { &ParserScriptObservation(observation) }
		state.executed << source
	})
	configured.add_parsing_complete_callback(fn [observation] () {
		mut state := unsafe { &ParserScriptObservation(observation) }
		state.completions++
	})
}

fn test_document_parser_host_is_inherited_by_document_open_and_incremental_parsers() {
	mut document := parser_script_document()!
	defer { document.finalize() }
	observation := &ParserScriptObservation{}
	install_document_parser_creation_hook(document, observation, parser_script_configure_created)
	parse_html_from_a_string(document, '<body><script>navigation</script>')
	parser_script_drain_tasks()
	document.open()!
	document.write_strings(['<body><script>written</script>'])!
	document.close()!
	parser_script_drain_tasks()
	assert observation.creations == 2
	assert observation.completions == 2
	assert observation.executed == ['navigation', 'written']

	mut streamed := parser_script_document()!
	defer { streamed.finalize() }
	install_document_parser_creation_hook(streamed, observation, parser_script_configure_created)
	body := fetch.Body.from_bytes('<body><script>streamed</script>'.bytes(), .bytes)
	mime := mimesniff.MimeType.parse('text/html;charset=utf-8')?
	mut incremental := IncrementalDocumentParser.create(streamed, body, streamed.url, mime)
	incremental.start()
	parser_script_drain_tasks()
	assert observation.creations == 3
	assert observation.completions == 3
	assert observation.executed == ['navigation', 'written', 'streamed']
}
