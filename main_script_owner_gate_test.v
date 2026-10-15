module main

import browserjs
import dom
import html
import page

fn script_gate_owner_document(value string) !(&page.Page, &dom.Document) {
	owner := page.Page.create(1)!
	document := parse_browser_navigation_document_for_page_with_response_time('<!doctype html><div id="result">initial</div>', dom.URL{value: value}, none, none, unsafe { &dom.Page(owner) }, 123456700000)
	return owner, document
}

fn test_compact_script_gate_skips_disabled_author_code_and_syntax_diagnostics_in_both_engines() {
	for engine in [browserjs.Engine.javascriptcore, browserjs.Engine.libjs] {
		$if !darwin {
			if engine == .javascriptcore { continue }
		}
		mut owner, mut document := script_gate_owner_document('https://script-owner.example/')!
		owner.set_is_scripting_enabled(false)
		mut runtime := browserjs.Runtime.create_with_engine(engine)
		defer {
			runtime.close()
			document.finalize()
		}
		mut messages := []string{}
		navigation := run_document_javascript(document, document.url.serialize(), [
			'globalThis.disabledExecuted=1;',
			'let duplicate;let duplicate;',
		], runtime, mut messages)
		assert navigation == none && messages == []
		assert runtime.evaluate_host('typeof disabledExecuted')! == 'undefined'
		assert document.get_element_by_id('result')?.as_node().text_content()? == 'initial'
	}
}

fn test_compact_script_gate_uses_actual_settings_activity_and_sandbox_before_evaluation() {
	$if !darwin {
		return
	}
	mut owner, mut document := script_gate_owner_document('https://script-owner.example/')!
	mut runtime := browserjs.Runtime.create()
	defer {
		runtime.close()
		document.finalize()
	}
	mut messages := []string{}
	document.set_active_sandboxing_flag_bits(u32(html.SandboxingFlag.sandboxed_scripts))
	run_document_javascript(document, document.url.serialize(), ['globalThis.sandboxExecuted=1;'], runtime, mut messages)
	assert runtime.evaluate_host('typeof sandboxExecuted')! == 'undefined' && messages == []
	document.set_active_sandboxing_flag_bits(0)
	mut navigable := document.navigable()?
	navigable.is_top_level_traversable_ = false
	run_document_javascript(document, document.url.serialize(), ['globalThis.inactiveExecuted=1;'], runtime, mut messages)
	assert runtime.evaluate_host('typeof inactiveExecuted')! == 'undefined' && messages == []
	navigable.is_top_level_traversable_ = true
	owner.set_is_scripting_enabled(true)
	run_document_javascript(document, document.url.serialize(), ['result.textContent="enabled owner";'], runtime, mut messages)
	assert document.get_element_by_id('result')?.as_node().text_content()? == 'enabled owner'
	assert messages == []
}

fn test_compact_script_gate_rechecks_owner_between_scripts_and_readiness_handlers() {
	$if !darwin {
		return
	}
	mut owner, mut document := script_gate_owner_document('https://script-owner.example/')!
	mut runtime := browserjs.Runtime.create()
	defer {
		runtime.close()
		document.finalize()
	}
	runtime.define_host_function('__disableActualPage', fn [owner] (_ string) !string {
		mut actual_owner := unsafe { &page.Page(owner) }
		actual_owner.set_is_scripting_enabled(false)
		return ''
	})!
	mut messages := []string{}
	run_document_javascript(document, document.url.serialize(), [
		'globalThis.ownerEntries=["first"];result.textContent="first effect";addEventListener("load",()=>ownerEntries.push("load"));__disableActualPage("");',
		'ownerEntries.push("second");result.textContent="second effect";',
		'let duplicate;let duplicate;',
	], runtime, mut messages)
	assert runtime.evaluate_host('ownerEntries.join(",")')! == 'first'
	assert document.get_element_by_id('result')?.as_node().text_content()? == 'first effect'
	assert messages == []
}

fn test_compact_script_gate_preserves_exact_source_webui_preference_exemption() {
	$if !darwin {
		return
	}
	mut owner, mut document := script_gate_owner_document('about:settings')!
	owner.set_is_scripting_enabled(false)
	mut runtime := browserjs.Runtime.create()
	defer {
		runtime.close()
		document.finalize()
	}
	mut messages := []string{}
	run_document_javascript(document, document.url.serialize(), ['result.textContent="internal script";'], runtime, mut messages)
	assert document.get_element_by_id('result')?.as_node().text_content()? == 'internal script' && messages == []
	document.set_url(dom.URL{value: 'about:settings#'})
	run_document_javascript(document, document.url.serialize(), ['globalThis.fragmentExecuted=1;'], runtime, mut messages)
	assert runtime.evaluate_host('typeof fragmentExecuted')! == 'undefined'
}

fn test_compact_readiness_entry_rechecks_owner_after_dom_content_loaded() {
	$if !darwin {
		return
	}
	mut owner, mut document := script_gate_owner_document('https://script-owner.example/')!
	mut runtime := browserjs.Runtime.create()
	defer {
		runtime.close()
		document.finalize()
	}
	runtime.define_host_function('__disableActualPage', fn [owner] (_ string) !string {
		mut actual_owner := unsafe { &page.Page(owner) }
		actual_owner.set_is_scripting_enabled(false)
		return ''
	})!
	mut messages := []string{}
	run_document_javascript(document, document.url.serialize(), [
		'globalThis.readyEntries=[];addEventListener("DOMContentLoaded",()=>{readyEntries.push("dom");__disableActualPage("")});addEventListener("load",()=>readyEntries.push("load"));',
	], runtime, mut messages)
	assert runtime.evaluate_host('readyEntries.join(",")')! == 'dom'
	assert messages == []
}

fn test_native_loaded_page_does_not_run_scripts_with_disabled_actual_page() {
	$if !darwin {
		return
	}
	mut owner := page.Page.create(1)!
	owner.set_is_scripting_enabled(false)
	mut app := BrowserApp{ page_model: owner, layout_tree_only: true, viewport_width: 320, viewport_height: 200 }
	app.install_loaded_page(LoadedPage{
		url:          'https://script-owner.example/page'
		content_type: 'text/html'
		markup:       '<!doctype html><div id="result">initial</div><noscript><b id="fallback">disabled</b></noscript><script>document.getElementById("result").textContent="executed";globalThis.disabledNativeExecuted=1;</script>'
	}, false)
	mut document := app.document
	defer {
		document.finalize()
	}
	assert document.get_element_by_id('fallback') != none
	assert document.get_element_by_id('result')?.as_node().text_content()? == 'initial'
	assert app.js_messages == []
	assert app.js_runtime == unsafe { nil }
}
