module main

import dom
import html
import page

fn test_document_write_with_an_inline_svg_script_resumes_the_outer_parser_and_load() {
	address := dom.URL{value:'https://svg-write.test/'}
	owner := page.Page.create(1)!
	mut document := create_browser_navigation_document_input_with_source('UTF-8',address,none,none,unsafe { &dom.Page(owner) },1_000_000,true,none)
	owner.set_local_root_navigable(document.navigable() or { panic('navigable') })!
	mut service := new_browser_hosted_document(document,.javascriptcore)
	defer { service.close();document.finalize() }
	html.parse_html_from_a_string(document,r'<!doctype html><body><script>globalThis.loads=0;globalThis.svgRuns=0;addEventListener("load",()=>loads++);document.write("<svg><script>svgRuns++;<\/script></svg>");</script><p id="after">after</p>')
	mut messages := []string{}
	for _ in 0..15 {
		service.poll(mut messages)
		service.initialize(mut messages)
		html.main_thread_event_loop().process()
	}
	assert messages == []string{},messages.str()
	assert document.get_element_by_id('after') != none
	assert document.ready_state() == 'complete'
	assert !document.anything_is_delaying_the_load_event()
	assert service.runtime.evaluate_host('svgRuns===1&&loads===1')! == 'true'
}
