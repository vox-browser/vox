module main

import browserjs
import page

fn test_native_libjs_form_submission_uses_shell_navigation_and_preserves_active_document() {
	mut document := form_submit_document('<!doctype html><form id="form" action="/search"><input id="query" name="q" value="before"></form>')!
	mut runtime := browserjs.Runtime.create_with_engine(.libjs)
	defer { runtime.close(); document.finalize() }
	mut messages := []string{}
	run_document_javascript(document, document.url.serialize(), []string{}, runtime, mut messages)
	mut app := &BrowserApp{document: document, page_model: unsafe { &page.Page(document.page().target) }, js_runtime: runtime}
	app.install_compact_navigation_handler()
	runtime.evaluate_host('var submits=0,form=document.getElementById("form"),query=document.getElementById("query");form.addEventListener("submit",()=>submits++);query.value="native value";')!
	for method in ['submit', 'requestSubmit'] {
		focus_compact_browser_navigable(document)
		runtime.evaluate_host('form.${method}();')!
		assert app.pending_native_navigation? == 'https://form-submit.test/search?q=native+value'
		app.pending_native_navigation = none
		assert document.is_fully_active()
		assert voidptr(document.navigable()?.active_document()?) == voidptr(document)
	}
	assert runtime.evaluate_host('submits')! == '1'
	assert !runtime.native_context_initialized()
	assert messages == []string{}
}
