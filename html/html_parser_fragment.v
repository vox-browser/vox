module html

import dom
import editing
import encoding
import fetch
import mimesniff

fn dom_html_fragment_parse_callback(target voidptr, context_element &dom.Element, markup string, allow_declarative_shadow_roots dom.AllowDeclarativeShadowRoots, scripting_mode dom.ParserScriptingMode) ![]&dom.Node {
	_ = target
	return parse_html_fragment_with_options(context_element, markup, allow_declarative_shadow_roots, scripting_mode)
}

fn dom_xml_fragment_parse_callback(target voidptr, context_element &dom.Element, markup string, allow_declarative_shadow_roots dom.AllowDeclarativeShadowRoots, _ dom.ParserScriptingMode) ![]&dom.Node {
	_ = target
	return parse_xml_fragment_with_options(context_element, markup, allow_declarative_shadow_roots == .yes)
}

fn dom_html_document_parse_callback(target voidptr, document &dom.Document, markup string) {
	_ = target
	mut parser := HTMLParser.create(document, markup)
	parser.run()
}

fn dom_html_parser_abort_callback(target voidptr) {
	mut parser := unsafe { &HTMLParser(target) }
	parser.abort()
}

fn dom_html_parser_feed_callback(target voidptr, input string) {
	mut parser := unsafe { &HTMLParser(target) }
	parser.tokenizer.feed(input)
}

fn dom_html_parser_run_callback(target voidptr, stop_at_insertion_point bool) {
	mut parser := unsafe { &HTMLParser(target) }
	if stop_at_insertion_point {
		parser.run_until_insertion_point()
	} else {
		parser.run()
	}
}

fn dom_html_parser_script_nesting_level_callback(target voidptr) uint {
	parser := unsafe { &HTMLParser(target) }
	return parser.current_script_nesting_level()
}

fn dom_html_parser_is_script_created_callback(target voidptr) bool {
	parser := unsafe { &HTMLParser(target) }
	return parser.is_script_created()
}

fn dom_html_parser_insertion_point_is_defined_callback(target voidptr) bool {
	parser := unsafe { &HTMLParser(target) }
	return parser.tokenizer.is_insertion_point_defined()
}

fn dom_html_parser_update_insertion_point_callback(target voidptr) {
	mut parser := unsafe { &HTMLParser(target) }
	parser.tokenizer.update_insertion_point()
}

fn dom_html_parser_insert_input_callback(target voidptr, input string) {
	mut parser := unsafe { &HTMLParser(target) }
	parser.tokenizer.insert_input_at_insertion_point(input)
}

fn dom_html_parser_insert_eof_callback(target voidptr) {
	mut parser := unsafe { &HTMLParser(target) }
	parser.tokenizer.insert_eof()
}

fn dom_html_parser_schedule_resume_check_callback(target voidptr) {
	mut parser := unsafe { &HTMLParser(target) }
	parser.schedule_resume_check()
}

fn dom_html_parser_finish_loading_after_parse_callback(target voidptr) {
	mut parser := unsafe { &HTMLParser(target) }
	parser.finish_loading_after_parse = true
}

fn make_dom_html_parser_handle(parser &HTMLParser) &dom.HTMLParser {
	return &dom.HTMLParser{
		target: voidptr(parser)
		abort_callback: dom_html_parser_abort_callback
		feed_callback: dom_html_parser_feed_callback
		run_callback: dom_html_parser_run_callback
		script_nesting_level_callback: dom_html_parser_script_nesting_level_callback
		is_script_created_callback: dom_html_parser_is_script_created_callback
		insertion_point_is_defined_callback: dom_html_parser_insertion_point_is_defined_callback
		update_insertion_point_callback: dom_html_parser_update_insertion_point_callback
		insert_input_callback: dom_html_parser_insert_input_callback
		insert_eof_callback: dom_html_parser_insert_eof_callback
		schedule_resume_check_callback: dom_html_parser_schedule_resume_check_callback
		finish_loading_after_parse_callback: dom_html_parser_finish_loading_after_parse_callback
	}
}

fn dom_html_parser_create_for_scripting_callback(target voidptr, document &dom.Document) &dom.HTMLParser {
	_ = target
	parser := HTMLParser.create_for_scripting(document)
	return make_dom_html_parser_handle(parser)
}

fn dom_encoding_sniff_callback(_ voidptr, _ &dom.Document, data []u8, transport_encoding ?string) string {
	return run_html_encoding_sniffing_algorithm(data, transport_encoding)
}

fn dom_loaded_html_parse_callback(_ voidptr, document &dom.Document, data []u8, transport_encoding ?string, url dom.URL) ! {
	mime_type := mimesniff.MimeType.parse(if charset := transport_encoding {
		'text/html;charset=${charset}'
	} else {
		'text/html'
	}) or { return error('invalid MIME type') }
	body := fetch.Body.from_bytes(data, .bytes)
	mut parser := IncrementalDocumentParser.create(document, body, url, mime_type)
	parser.start()
	if parser.error_ != '' {
		return error(parser.error_)
	}
}

fn dom_loaded_text_parse_callback(_ voidptr, document &dom.Document, data []u8, transport_encoding ?string, _ dom.URL) !string {
	encoding_name := run_html_encoding_sniffing_algorithm(data, transport_encoding)
	decoder := encoding.TextDecoder.construct(encoding_name, encoding.TextDecoderOptions{})!
	decoded_input := decoder.decode(data, encoding.TextDecodeOptions{})!
	mut parser := HTMLParser.create_with_open_input_stream(document)
	mut tokenizer := parser.tokenizer()
	tokenizer.update_insertion_point()
	tokenizer.insert_input_at_insertion_point('<meta name="color-scheme" content="light dark"><pre>\n')
	parser.run()
	if mut pre := document.get_elements_by_tag_name('pre').item(0) {
		// User-agent presentation must not be blocked by the response CSP.
		mut style := pre.style_for_bindings()
		style.set_declarations_from_text('word-wrap: break-word; white-space: pre-wrap;')
		pre.set_inline_style(style)
	}
	tokenizer = parser.tokenizer()
	tokenizer.switch_to(.plaintext)
	tokenizer.insert_input_at_insertion_point(decoded_input)
	tokenizer.insert_eof()
	parser.run()
	return encoding_name
}

fn dom_xml_document_parse_callback(_ voidptr, document &dom.Document, source string) bool {
	parse_xml_document_source(document, source) or { return false }
	return true
}

// Install the HTML tree builder behind DOM::Element.innerHTML/setHTMLUnsafe/insertAdjacentHTML.
// The callback avoids a module cycle: html imports dom, while dom only retains this function pointer.
pub fn install_document_fragment_parsing_hook(document &dom.Document) {
	install_document_accessibility_role_hook(document)
	install_document_csp_hook(document)
	install_document_fullscreen_hook(document)
	editing.install_dom_editing_bridge(document)
	mut mutable_document := unsafe { &dom.Document(document) }
	mutable_document.set_media_element_state_query(media_element_matches_pseudo_class)
	mutable_document.set_html_fragment_parsing_hook(dom.DocumentHTMLFragmentParsingHook{
		parse_fragment: dom_html_fragment_parse_callback
		parse_xml_fragment: dom_xml_fragment_parse_callback
		parse_document: dom_html_document_parse_callback
		create_parser_for_scripting: dom_html_parser_create_for_scripting_callback
		sniff_encoding: dom_encoding_sniff_callback
		parse_loaded_html: dom_loaded_html_parse_callback
		parse_loaded_text: dom_loaded_text_parse_callback
		parse_xml_document: dom_xml_document_parse_callback
	})
}

// https://html.spec.whatwg.org/multipage/parsing.html#html-fragment-parsing-algorithm
// The engine behind Element.innerHTML / Element.setHTMLUnsafe / the fragment parsing steps.
// Parses `markup` as if it were the contents of `context_element`, returning the parsed nodes (in
// tree order) which the caller inserts into the real tree.
pub fn parse_html_fragment(context_element &dom.Element, markup string) []&dom.Node {
	return parse_html_fragment_with_options(context_element, markup, .no, .inert)
}

pub fn parse_html_fragment_with_options(context_element &dom.Element, markup string, allow_declarative_shadow_roots dom.AllowDeclarativeShadowRoots, requested_scripting_mode dom.ParserScriptingMode) []&dom.Node {
	if requested_scripting_mode !in [.inert, .fragment] {
		panic('HTML fragment parsing requires Inert or Fragment scripting mode')
	}
	install_document_fragment_parsing_hook(context_element.document())
	context_document := context_element.document()
	mut allocations := context_document.enter_native_storage()
	defer { allocations.finish() }
	// 1. Let document be a Document node whose type is "html".
	mut temp_document := dom.Document.create_for_fragment_parsing()
	temp_document.borrow_native_storage(context_document)
	temp_document.set_document_type(.html)
	if allow_declarative_shadow_roots == .yes {
		temp_document.set_allow_declarative_shadow_roots(true)
	}

	// 2/3. Inherit quirks mode from the context's node document.
	temp_document.set_scripting_enabled_by_embedder(context_document.is_scripting_enabled_by_embedder())
	if context_document.in_quirks_mode() {
		temp_document.set_quirks_mode(.yes)
	} else if context_document.in_limited_quirks_mode() {
		temp_document.set_quirks_mode(.limited)
	}

	// 5. Create the parser and associate it with the temporary document.
	scripting_mode := if context_document.is_scripting_disabled() {
		dom.ParserScriptingMode.disabled
	} else {
		requested_scripting_mode
	}
	mut parser := HTMLParser.create_with_scripting_mode(temp_document, markup, scripting_mode)
	parser.context_element = context_element
	parser.parsing_fragment = true
	// Fragment nodes are adopted into the context document. Inline checks use
	// that document's policy and running realm while the temporary tree parses.
	temp_document.set_csp_hook(dom.DocumentCSPHook{target:voidptr(context_document),inline_check:dom_inline_csp_check})

	// 6. Set the tokenizer state based on the context element.
	context_name := context_element.local_name()
	if context_name in ['title', 'textarea'] {
		parser.tokenizer.switch_to(.rcdata)
	} else if context_name in ['style', 'xmp', 'iframe', 'noembed', 'noframes'] {
		parser.tokenizer.switch_to(.rawtext)
	} else if context_name == 'script' {
		parser.tokenizer.switch_to(.script_data)
	} else if context_name == 'noscript' {
		if scripting_mode != .disabled {
			parser.tokenizer.switch_to(.rawtext)
		}
	} else if context_name == 'plaintext' {
		parser.tokenizer.switch_to(.plaintext)
	}

	// 7/8. Create the root <html> element and append it to the temporary document.
	root := dom.create_element_with_registry(context_element.document(), 'html', ns_html, none, none, false, context_element.custom_element_registry()) or {
		panic('fragment root: ${err}')
	}
	mut temp_document_node := unsafe { &dom.Node(temp_document) }
	temp_document_node.append_child(root.as_node()) or {}

	// 9. The stack of open elements contains just root.
	parser.stack_of_open_elements.push(root)

	// 10. If the context is a template element, push "in template".
	if context_name == 'template' && element_in_namespace(context_element, ns_html) {
		parser.stack_of_template_insertion_modes << InsertionMode.in_template
	}

	// 12. Reset the insertion mode appropriately (this reads the context element in the fragment case).
	parser.reset_the_insertion_mode_appropriately()

	// 13. Set the form element pointer to the nearest form ancestor (inclusive).
	mut ancestor := ?&dom.Element(context_element)
	for {
		candidate := ancestor or { break }
		if element_in_namespace(candidate, ns_html) && candidate.local_name() == 'form' {
			parser.form_element = candidate
			break
		}
		ancestor = candidate.as_node().parent_element()
	}

	// 14/15. Run the parser to completion.
	parser.run()

	// 16. Return root's children (in tree order), adopting each into the context's document.
	mut children := []&dom.Node{}
	mut root_node := root.as_node()
	for {
		child := root_node.first_child() or { break }
		removed := root_node.remove_child(child) or { break }
		mut destination_document := context_element.document()
		destination_document.adopt_node(removed)
		children << removed
	}
	return children
}

// https://html.spec.whatwg.org/multipage/dynamic-markup-insertion.html#dom-element-innerhtml
// The Element.innerHTML setter: parse `markup` as a fragment with `element` as context, then
// replace all children of `element` (or of its template contents, if it is a template) with the
// result. (The dom module cannot call this — it would be an import cycle — so callers use this html
// free function, mirroring how css owns querySelector.)
pub fn set_inner_html(element &dom.Element, markup string) {
	install_document_fragment_parsing_hook(element.document())
	mut mutable_element := unsafe { &dom.Element(element) }
	mutable_element.set_inner_html(markup) or {}
}
