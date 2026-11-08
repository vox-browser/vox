@[has_globals]
module html

import dom
import platform

__global scripted_tokenizer_document_ &dom.Document
__global scripted_tokenizer_executed_ []string

fn scripted_tokenizer_retire_document(mut document dom.Document) {
	owner := document.native_storage()
	document.destroy()
	document.finalize()
	document.release_native_storage()
	// Progress checks have no task/document association, but hold an explicit
	// allocation lease until their final check observes the destroyed document.
	mut event_loop := main_thread_event_loop()
	for _ in 0 .. 8 { event_loop.process() }
	$if prealloc { assert owner.arena.usage().capacity == 0 }
}

fn scripted_tokenizer_execute(_ ScriptElementType, source string, _ dom.URL) ! {
	scripted_tokenizer_executed_ << source
	if source == 'write()' {
		mut document := scripted_tokenizer_document_
		document.write_strings(['<b id="written" data-value="日本語😀">inserted</b>'])!
		written := document.get_element_by_id('written') or {
			return error('document.write did not synchronously insert its element')
		}
		assert written.as_node().descendant_text_content() == 'inserted'
	}
}

fn test_native_scripted_tokenizer_retires_after_reentrant_document_write() {
	mut document := dom.Document.create(dom.URL{value:'https://scripted-tokenizer.test/'})
	_ = WindowModel.create_top_level(document, none, 'scripted-tokenizer')!
	document.set_ready_to_run_scripts()
	document.enable_native_storage()
	scripted_tokenizer_document_ = document
	scripted_tokenizer_executed_ = []string{}
	defer {
		scripted_tokenizer_document_ = unsafe { nil }
		scripted_tokenizer_executed_ = []string{}
		scripted_tokenizer_retire_document(mut document)
	}
	mut scope := document.enter_native_storage()
	defer { scope.finish() }
	mut parser := HTMLParser.create_with_scripting_mode(document,
		'<body><p id="before">before</p><script id="writer" type="text/javascript" language="javascript">write()</script><p id="after">after</p>', .normal)
	parser.set_script_hooks(none, scripted_tokenizer_execute)
	storage := parser.tokenizer_storage
	$if prealloc { assert voidptr(storage) != unsafe { nil } }
	parser.run()
	assert scripted_tokenizer_executed_ == ['write()']
	assert document.get_element_by_id('before')?.as_node().text_content()? == 'before'
	assert document.get_element_by_id('written')?.get_attribute_value('data-value') == '日本語😀'
	assert document.get_element_by_id('written')?.as_node().text_content()? == 'inserted'
	assert document.get_element_by_id('after')?.as_node().text_content()? == 'after'
	writer := document.get_element_by_id('writer')?
	model := parser.script_models[writer.as_node().unique_id().value()]
	assert model.text() == 'write()'
	assert model.type_attribute_? == 'text/javascript'
	assert model.language_attribute_? == 'javascript'
	$if prealloc {
		assert voidptr(parser.tokenizer_storage) == unsafe { nil }
		assert storage.usage().capacity == 0
	}
}

fn test_native_scripted_tokenizer_keeps_payloads_until_blocking_script_resumes() {
	mut document := dom.Document.create(dom.URL{value:'https://scripted-tokenizer.test/blocked'})
	_ = WindowModel.create_top_level(document, none, 'blocked-tokenizer')!
	document.set_ready_to_run_scripts()
	document.enable_native_storage()
	scripted_tokenizer_document_ = document
	scripted_tokenizer_executed_ = []string{}
	defer {
		scripted_tokenizer_document_ = unsafe { nil }
		scripted_tokenizer_executed_ = []string{}
		scripted_tokenizer_retire_document(mut document)
	}
	mut scope := document.enter_native_storage()
	defer { scope.finish() }
	document.script_blocking_style_sheet_set << document.create_element('style')!
	mut parser := HTMLParser.create_with_scripting_mode(document,
		'<body><script id="blocked" type="text/javascript">write()</script><p id="tail" data-value="&amp;日本語😀">tail</p>', .normal)
	parser.set_script_hooks(none, scripted_tokenizer_execute)
	storage := parser.tokenizer_storage
	parser.run()
	assert parser.paused() && document.has_pending_parsing_blocking_script()
	assert scripted_tokenizer_executed_.len == 0
	$if prealloc { assert storage.usage().capacity > 0 }
	document.script_blocking_style_sheet_set.clear()
	parser.resume_after_parser_blocking_script()
	assert !parser.paused()
	assert scripted_tokenizer_executed_ == ['write()']
	assert document.get_element_by_id('tail')?.get_attribute_value('data-value') == '&日本語😀'
	assert document.get_element_by_id('tail')?.as_node().text_content()? == 'tail'
	$if prealloc {
		assert voidptr(parser.tokenizer_storage) == unsafe { nil }
		assert storage.usage().capacity == 0
	}
}

@[heap]
struct ScriptedTokenizerPendingFetch {
mut:
	model ?&HTMLScriptElementModel
	executed bool
}

fn test_native_script_fetch_completion_and_resumed_dom_outlive_the_callers_scratch() {
	for async_ in [false, true] {
		mut document := dom.Document.create(dom.URL{value: 'https://scripted-tokenizer.test/resume'})
		_ = WindowModel.create_top_level(document, none, 'async-tokenizer-storage')!
		document.set_ready_to_run_scripts()
		document.enable_native_storage()
		defer { scripted_tokenizer_retire_document(mut document) }
		observation := &ScriptedTokenizerPendingFetch{}
		mut scope := document.enter_native_storage()
		mut parser := HTMLParser.create_with_scripting_mode(document,
			'<body><script ${if async_ { 'async' } else { '' }} src="pending.js"></script><p id="tail" data-value="日本語😀">retained tail</p>', .normal)
		parser.set_async_script_fetch_hook(fn [observation] (model &HTMLScriptElementModel, _ dom.URL, _ ScriptElementType) ! {
			mut pending := unsafe { &ScriptedTokenizerPendingFetch(observation) }
			pending.model = model
		})
		parser.set_script_execute_hook_with_element(fn [document, observation] (_ &dom.HTMLScriptElement, _ ScriptElementType, source string, _ dom.URL) ! {
			$if prealloc {
				assert voidptr(platform.current_retained_arena()) == voidptr(document.native_storage())
				assert !platform.transient_arena_entered()
			}
			assert source == 'source returned from temporary completion storage'
			mut pending := unsafe { &ScriptedTokenizerPendingFetch(observation) }
			pending.executed = true
		})
		parser.run()
		assert parser.paused() == !async_
		scope.finish()

		workspace := platform.begin_thread_scratch('parser external completion fixture')
		mut model := observation.model?
		model.complete_external_fetch('source returned from temporary completion storage'.clone())
		mut queue := main_thread_event_loop().task_queue()
		for _ in 0 .. 32 {
			task := queue.take_first_runnable() or { break }
			task.execute()
		}
		workspace.finish()

		assert observation.executed
		assert !parser.paused()
		assert document.get_element_by_id('tail')?.get_attribute_value('data-value') == '日本語😀'
		assert document.get_element_by_id('tail')?.as_node().text_content()? == 'retained tail'
		assert model.result_source_? == 'source returned from temporary completion storage'
		assert document.readiness() == .complete
		$if prealloc { assert parser.tokenizer_storage == unsafe { nil } }
	}
}
