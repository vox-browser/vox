module html

import dom

@[heap]
struct ShadowTimingObservation {
mut:
	values []bool
}

fn test_declarative_shadow_roots_exist_before_the_next_parser_script() {
	url := dom.URL{value:'https://shadow-timing.test/'}
	mut document := create_navigation_document(url,url.origin(),none)!
	defer { document.finalize() }
	document.set_document_type(.html)
	document.set_allow_declarative_shadow_roots(true)
	document.set_ready_to_run_scripts()
	observed := &ShadowTimingObservation{}
	mut parser := HTMLParser.create(document,'<!doctype html><div id="host"><template shadowrootmode="open"><span id="inside">text</span></template></div><script>observe()</script>')
	parser.set_script_hooks(none,fn [document,observed] (_ ScriptElementType, _ string, _ dom.URL) ! {
		host := document.get_element_by_id('host') or { panic('host') }
		mut observation := unsafe { &ShadowTimingObservation(observed) }
		observation.values << (host.shadow_root() != none)
	})
	parser.run()
	assert observed.values == [true]
}
