@[has_globals]
module html

import dom
import css
import encoding
import platform

__global html_parser_non_append_insertions u64

pub fn parser_non_append_insertions() u64 {
	return html_parser_non_append_insertions
}

fn record_parser_insertion_location(location AdjustedInsertionLocation) {
	if location.insert_before_sibling != none {
		html_parser_non_append_insertions++
	}
}

// Public identifier prefixes which select quirks mode. Kept in the same order as
// HTMLParser.cpp's s_quirks_public_ids.
const quirks_public_id_prefixes = ['+//Silmaril//dtd html Pro v0r11 19970101//',
	'-//AS//DTD HTML 3.0 asWedit + extensions//',
	'-//AdvaSoft Ltd//DTD HTML 3.0 asWedit + extensions//', '-//IETF//DTD HTML 2.0 Level 1//',
	'-//IETF//DTD HTML 2.0 Level 2//', '-//IETF//DTD HTML 2.0 Strict Level 1//',
	'-//IETF//DTD HTML 2.0 Strict Level 2//', '-//IETF//DTD HTML 2.0 Strict//',
	'-//IETF//DTD HTML 2.0//', '-//IETF//DTD HTML 2.1E//', '-//IETF//DTD HTML 3.0//',
	'-//IETF//DTD HTML 3.2 Final//', '-//IETF//DTD HTML 3.2//', '-//IETF//DTD HTML 3//',
	'-//IETF//DTD HTML Level 0//', '-//IETF//DTD HTML Level 1//', '-//IETF//DTD HTML Level 2//',
	'-//IETF//DTD HTML Level 3//', '-//IETF//DTD HTML Strict Level 0//',
	'-//IETF//DTD HTML Strict Level 1//', '-//IETF//DTD HTML Strict Level 2//',
	'-//IETF//DTD HTML Strict Level 3//', '-//IETF//DTD HTML Strict//', '-//IETF//DTD HTML//',
	'-//Metrius//DTD Metrius Presentational//',
	'-//Microsoft//DTD Internet Explorer 2.0 HTML Strict//',
	'-//Microsoft//DTD Internet Explorer 2.0 HTML//',
	'-//Microsoft//DTD Internet Explorer 2.0 Tables//',
	'-//Microsoft//DTD Internet Explorer 3.0 HTML Strict//',
	'-//Microsoft//DTD Internet Explorer 3.0 HTML//',
	'-//Microsoft//DTD Internet Explorer 3.0 Tables//', '-//Netscape Comm. Corp.//DTD HTML//',
	'-//Netscape Comm. Corp.//DTD Strict HTML//', "-//O'Reilly and Associates//DTD HTML 2.0//",
	"-//O'Reilly and Associates//DTD HTML Extended 1.0//",
	"-//O'Reilly and Associates//DTD HTML Extended Relaxed 1.0//",
	'-//SQ//DTD HTML 2.0 HoTMetaL + extensions//',
	'-//SoftQuad Software//DTD HoTMetaL PRO 6.0::19990601::extensions to HTML 4.0//',
	'-//SoftQuad//DTD HoTMetaL PRO 4.0::19971010::extensions to HTML 4.0//',
	'-//Spyglass//DTD HTML 2.0 Extended//', '-//Sun Microsystems Corp.//DTD HotJava HTML//',
	'-//Sun Microsystems Corp.//DTD HotJava Strict HTML//', '-//W3C//DTD HTML 3 1995-03-24//',
	'-//W3C//DTD HTML 3.2 Draft//', '-//W3C//DTD HTML 3.2 Final//', '-//W3C//DTD HTML 3.2//',
	'-//W3C//DTD HTML 3.2S Draft//', '-//W3C//DTD HTML 4.0 Frameset//',
	'-//W3C//DTD HTML 4.0 Transitional//', '-//W3C//DTD HTML Experimental 19960712//',
	'-//W3C//DTD HTML Experimental 970421//', '-//W3C//DTD W3 HTML//', '-//W3O//DTD W3 HTML 3.0//',
	'-//WebTechs//DTD Mozilla HTML 2.0//', '-//WebTechs//DTD Mozilla HTML//']

// Translation of the core of Libraries/LibWeb/HTML/Parser/HTMLParser.cpp — the tree-construction
// stage that turns tokens into a DOM tree.
//
// This covers the tree-construction insertion modes, foster parenting, template contents, foreign
// (SVG/MathML) content, active formatting elements, the adoption agency algorithm, parser-inserted
// script preparation, and declarative shadow roots. JavaScript evaluation and network fetching are
// explicit host hooks, as they are owned by LibJS and Fetch rather than the HTML parser.
pub enum InsertionMode {
	initial
	before_html
	before_head
	in_head
	in_head_noscript
	after_head
	in_body
	text
	in_table
	in_table_text
	in_caption
	in_column_group
	in_table_body
	in_row
	in_cell
	in_template
	after_body
	in_frameset
	after_frameset
	after_after_body
	after_after_frameset
}

pub type HTMLParserChangeEncodingCallback = fn (string) bool

pub type HTMLParserCallback = fn ()

pub struct AdjustedInsertionLocation {
pub:
	parent                ?&dom.Node
	insert_before_sibling ?&dom.Node
}

@[heap]
pub struct HTMLParser {
pub mut:
	document_                          &dom.Document = unsafe { nil }
	realm_                             &ScriptingRealm = unsafe { nil }
	tokenizer                          HTMLTokenizer
	tokenizer_storage                  &platform.Arena = unsafe { nil }
	insertion_mode                     InsertionMode = .initial
	original_insertion_mode            InsertionMode = .initial
	stack_of_open_elements             StackOfOpenElements
	list_of_active_formatting_elements ListOfActiveFormattingElements
	stack_of_template_insertion_modes  []InsertionMode
	head_element                       ?&dom.Element
	form_element                       ?&dom.Element
	frameset_ok                        bool = true
	parsing_fragment                   bool
	// Embedder-owned, discarded resource-discovery trees need DOM/namespace
	// parsing but never expose CSSOM or render their style sheets.
	resource_discovery_only            bool
	scripting_mode                     dom.ParserScriptingMode
	script_created                     bool
	next_line_feed_can_be_ignored      bool
	foster_parenting                   bool
	stop_parsing                       bool
	aborted                            bool
	parser_pause_flag                  bool
	resume_check_pending               bool
	finish_loading_after_parse         bool
	the_end_started                    bool
	context_element                    ?&dom.Element
	script_nesting_level               uint
	script_models                      map[i64]&HTMLScriptElementModel
	script_fetch_hook                  ?ScriptElementFetchHook
	script_execute_hook                ?ScriptElementExecuteHook
	speculative_fetch_hook             ?SpeculativeFetchHook
	active_speculative_html_parser     ?&SpeculativeHTMLParser
	encoding_confidence                EncodingConfidence = .irrelevant
	change_encoding_callback           ?HTMLParserChangeEncodingCallback
	ready_for_more_input_callback      ?HTMLParserCallback
	parsing_complete_callback          ?HTMLParserCallback

	character_insertion_node    ?&dom.Text
	character_insertion_builder []rune

	pending_table_character_tokens []HTMLToken
}

// Parse `input` into `document`. The document is marked as an HTML document so that HTML-namespaced
// elements report uppercase tag names, matching a real parse.
pub fn HTMLParser.create(document &dom.Document, input string) &HTMLParser {
	mode := if unsafe { &dom.Node(document) }.is_scripting_enabled() {
		dom.ParserScriptingMode.normal
	} else {
		dom.ParserScriptingMode.disabled
	}
	return HTMLParser.create_with_scripting_mode(document, input, mode)
}

pub fn HTMLParser.create_with_scripting_mode(document &dom.Document, input string, scripting_mode dom.ParserScriptingMode) &HTMLParser {
	$if prealloc {
		owner := document.native_storage()
		if owner != unsafe { nil } {
			// Keep the original source with the document. Only tokenizer payloads
			// go in the short-lived arena; the tree builder publishes owned DOM data.
			source := input.clone()
			persistent := platform.enter_persistent()
			mut storage := platform.new_arena('HTML tokenizer')
			platform.leave_persistent(persistent)
			entry := storage.enter()
			tokenizer := HTMLTokenizer.new(source)
			storage.leave(entry)
			mut parser := HTMLParser.create_with_tokenizer(document, tokenizer, scripting_mode)
			parser.tokenizer_storage = storage
			parser.list_of_active_formatting_elements.parser_storage = storage
			mut retained_owner := owner
			retained_owner.add_cleanup(fn [storage] () {
				mut retired := unsafe { &platform.Arena(storage) }
				retired.release()
			})
			return parser
		}
	}
	return HTMLParser.create_with_tokenizer(document, HTMLTokenizer.new(input), scripting_mode)
}

fn parser_element_popped_callback(context voidptr, element &dom.Element) {
	mut parser := unsafe { &HTMLParser(context) }
	parser.handle_element_popped(element)
}

fn HTMLParser.create_with_tokenizer(document &dom.Document, tokenizer HTMLTokenizer,
	scripting_mode dom.ParserScriptingMode) &HTMLParser {
	mut doc := unsafe { document }
	doc.set_document_type(.html)
	realm := &ScriptingRealm{
		scripting_enabled: scripting_mode != .disabled
	}
	mut parser := &HTMLParser{
		document_: document
		realm_: realm
		tokenizer: tokenizer
		scripting_mode: scripting_mode
	}
	parser.tokenizer.set_parser(parser)
	if scripting_mode != .fragment {
		doc.set_parser(make_dom_html_parser_handle(parser))
	}
	parser.stack_of_open_elements.set_on_element_popped_with_context(voidptr(parser), parser_element_popped_callback)
	return parser
}

// HTMLParser::document().
pub fn (p &HTMLParser) document() &dom.Document {
	return p.document_
}

pub fn (mut p HTMLParser) tokenizer() &HTMLTokenizer {
	return &p.tokenizer
}

pub fn (p &HTMLParser) aborted() bool {
	return p.aborted
}

pub fn (p &HTMLParser) stopped() bool {
	return p.stop_parsing
}

pub fn (p &HTMLParser) is_script_created() bool {
	return p.script_created
}

pub fn (p &HTMLParser) paused() bool {
	return p.parser_pause_flag
}

fn (mut p HTMLParser) stop_parsing() {
	p.stop_parsing = true
}

// HTMLParser::realm(). LibJS is represented by ScriptingRealm in this port;
// the parser retains the same realm for its complete lifetime.
pub fn (p &HTMLParser) realm() &ScriptingRealm {
	return p.realm_
}

// HTMLParser::create_for_scripting(). Input is supplied later through the
// tokenizer's insertion point by Document.write().
pub fn HTMLParser.create_for_scripting(document &dom.Document) &HTMLParser {
	mut parser := HTMLParser.create_with_open_input_stream(document)
	parser.script_created = true
	return parser
}

pub fn HTMLParser.create_with_open_input_stream(document &dom.Document) &HTMLParser {
	return HTMLParser.create_with_open_input_stream_and_confidence(document, .irrelevant)
}

pub fn HTMLParser.create_with_open_input_stream_and_confidence(document &dom.Document, confidence EncodingConfidence) &HTMLParser {
	mode := if unsafe { &dom.Node(document) }.is_scripting_enabled() {
		dom.ParserScriptingMode.normal
	} else {
		dom.ParserScriptingMode.disabled
	}
	mut parser := HTMLParser.create_with_tokenizer(document, HTMLTokenizer.create(), mode)
	parser.encoding_confidence = confidence
	return parser
}

// HTMLParser::create_with_uncertain_encoding().
pub fn HTMLParser.create_with_uncertain_encoding(document &dom.Document, input []u8, transport_encoding ?string) !&HTMLParser {
	result := if document_encoding := document.get_encoding() {
		EncodingSniffingResult{
			encoding: document_encoding
			confidence: .certain
		}
	} else {
		run_html_encoding_sniffing_algorithm_with_confidence(input, transport_encoding)
	}
	return HTMLParser.create_from_bytes_with_confidence(document, input, result.encoding, result.confidence)!
}

// Byte-input counterpart of HTMLParser::create(document, input, encoding).
pub fn HTMLParser.create_from_bytes(document &dom.Document, input []u8, encoding_name string) !&HTMLParser {
	return HTMLParser.create_from_bytes_with_confidence(document, input, encoding_name, .certain)!
}

fn HTMLParser.create_from_bytes_with_confidence(document &dom.Document, input []u8, encoding_name string, confidence EncodingConfidence) !&HTMLParser {
	decoder := encoding.TextDecoder.construct(encoding_name, encoding.TextDecoderOptions{})!
	decoded_input := decoder.decode(input, encoding.TextDecodeOptions{})!
	mut mutable_document := unsafe { &dom.Document(document) }
	standardized_encoding := encoding.get_an_encoding(encoding_name) or { encoding_name }
	mutable_document.set_encoding(standardized_encoding)
	mut parser := HTMLParser.create(document, decoded_input)
	parser.encoding_confidence = confidence
	return parser
}

pub fn (p &HTMLParser) get_encoding_confidence() EncodingConfidence {
	return p.encoding_confidence
}

pub fn (mut p HTMLParser) set_change_encoding_callback(callback HTMLParserChangeEncodingCallback) {
	p.change_encoding_callback = callback
}

pub fn (mut p HTMLParser) set_ready_for_more_input_callback(callback HTMLParserCallback) {
	p.ready_for_more_input_callback = callback
}

pub fn (mut p HTMLParser) set_parsing_complete_callback(callback HTMLParserCallback) {
	p.parsing_complete_callback = callback
}

// https://html.spec.whatwg.org/multipage/parsing.html#parsing-main-inhead
fn (mut p HTMLParser) process_meta_element(element &dom.Element) {
	if p.active_speculative_html_parser != none || p.encoding_confidence != .tentative {
		return
	}
	if charset := element.get_attribute('charset') {
		if standardized := standardized_html_encoding(charset) {
			p.change_the_encoding(standardized)
			return
		}
	}
	if ascii_lowercase_string(element.get_attribute_value('http-equiv')) != 'content-type' {
		return
	}
	content := element.get_attribute('content') or { return }
	if standardized := extract_character_encoding_from_meta_element(content) {
		p.change_the_encoding(standardized)
	}
}

// https://html.spec.whatwg.org/multipage/parsing.html#change-the-encoding
fn (mut p HTMLParser) change_the_encoding(requested_encoding string) {
	if p.encoding_confidence != .tentative {
		return
	}
	current_encoding := p.document_.get_encoding() or {
		p.encoding_confidence = .certain
		return
	}
	current_standardized := encoding.get_an_encoding(current_encoding) or { current_encoding }
	if current_standardized.to_lower() in ['utf-16be', 'utf-16le'] {
		p.encoding_confidence = .certain
		return
	}

	mut new_encoding := encoding.get_an_encoding(requested_encoding) or { requested_encoding }
	if new_encoding.to_lower() in ['utf-16be', 'utf-16le'] {
		new_encoding = 'UTF-8'
	} else if new_encoding.to_lower() == 'x-user-defined' {
		new_encoding = 'windows-1252'
	}
	if current_standardized.to_lower() == new_encoding.to_lower() {
		p.encoding_confidence = .certain
		return
	}
	if callback := p.change_encoding_callback {
		if callback(new_encoding) {
			mut document := unsafe { &dom.Document(p.document_) }
			document.set_encoding(new_encoding)
			p.encoding_confidence = .certain
			return
		}
	}
	// Restarting the navigation with the new encoding is not implemented.
	p.encoding_confidence = .certain
}

pub fn (mut p HTMLParser) set_script_hooks(fetch ?ScriptElementFetchHook, execute ?ScriptElementExecuteHook) {
	p.script_fetch_hook = fetch
	p.script_execute_hook = execute
}

pub fn (mut p HTMLParser) set_speculative_fetch_hook(hook ?SpeculativeFetchHook) {
	p.speculative_fetch_hook = hook
}

pub fn (p &HTMLParser) has_active_speculative_html_parser() bool {
	return p.active_speculative_html_parser != none
}

pub fn (p &HTMLParser) current_script_nesting_level() uint {
	return p.script_nesting_level
}

fn (p &HTMLParser) insertion_mode_name() string {
	return match p.insertion_mode {
		.initial { 'Initial' }
		.before_html { 'BeforeHTML' }
		.before_head { 'BeforeHead' }
		.in_head { 'InHead' }
		.in_head_noscript { 'InHeadNoscript' }
		.after_head { 'AfterHead' }
		.in_body { 'InBody' }
		.text { 'Text' }
		.in_table { 'InTable' }
		.in_table_text { 'InTableText' }
		.in_caption { 'InCaption' }
		.in_column_group { 'InColumnGroup' }
		.in_table_body { 'InTableBody' }
		.in_row { 'InRow' }
		.in_cell { 'InCell' }
		.in_template { 'InTemplate' }
		.after_body { 'AfterBody' }
		.in_frameset { 'InFrameset' }
		.after_frameset { 'AfterFrameset' }
		.after_after_body { 'AfterAfterBody' }
		.after_after_frameset { 'AfterAfterFrameset' }
	}
}

fn (mut p HTMLParser) increment_script_nesting_level() {
	p.script_nesting_level++
}

fn (mut p HTMLParser) decrement_script_nesting_level() {
	assert p.script_nesting_level > 0
	p.script_nesting_level--
}

fn (mut p HTMLParser) register_parser_inserted_script(element &dom.Element, token &HTMLToken) {
	// Keep raw DOM text without creating prepared-script records or source copies
	// for pages whose scripting has been disabled before parsing.
	if !p.document_.is_scripting_enabled_by_embedder() {
		return
	}
	mut script := HTMLScriptElementModel.create(p.document_.base_url())
	script_element := unsafe { &dom.HTMLScriptElement(element) }
	attach_html_script_element_model(script_element, script)
	if p.scripting_mode != .fragment {
		script.set_parser_document(p.document_)
	}
	if p.scripting_mode == .inert {
		script.set_already_started(true)
	}
	script.set_scripting_enabled(p.scripting_mode != .disabled)
	script.set_src(p.own_tokenizer_optional_string(token.attribute('src')))
	script.set_type(p.own_tokenizer_optional_string(token.attribute('type')))
	script.set_language(p.own_tokenizer_optional_string(token.attribute('language')))
	script.set_async(token.has_attribute('async'))
	script.set_nomodule(token.has_attribute('nomodule'))
	script.set_fetch_hook(p.script_fetch_hook)
	script.set_execute_hook(p.script_execute_hook)
	p.script_models[element.as_node().unique_id().value()] = script
}

fn (mut p HTMLParser) prepare_and_execute_parser_inserted_script(element &dom.Element) {
	mut script := p.script_models[element.as_node().unique_id().value()] or { return }
	script.set_text(element.as_node().descendant_text_content())
	// The translated DOM attaches the script model after inserting the node in
	// the temporary fragment document. Defer preparation in Fragment mode so
	// insertion into the destination document performs it, as upstream does.
	if p.scripting_mode == .fragment {
		return
	}
	p.increment_script_nesting_level()
	script.prepare_script(p.document_)
	p.decrement_script_nesting_level()
	if script.is_ready_to_be_parser_executed() {
		mut document := unsafe { &dom.Document(p.document_) }
		document.set_pending_parsing_blocking_script(unsafe { &dom.HTMLScriptElement(element) })
	}
}

fn (mut p HTMLParser) register_parser_inserted_svg_script(element &dom.Element, token &HTMLToken) &SVGScriptElementModel {
	svg_element := unsafe { &dom.SVGScriptElement(element) }
	mut script := svg_script_element_model_for_dom_element(svg_element)
	script.set_parser_inserted()
	script.set_source_line_number(uint(token.start_position().line + 1))
	script.set_fetch_hook(p.script_fetch_hook)
	script.set_execute_hook(p.script_execute_hook)
	return script
}

fn same_node(a &dom.Node, b &dom.Node) bool {
	return a.is_same_node(b)
}

fn node_as_text(n &dom.Node) &dom.Text {
	return unsafe { &dom.Text(n) }
}

// ===== the run loop =====
pub fn (mut p HTMLParser) run() {
	p.run_with_stop_at_insertion_point(.no)
}

// HTMLParser::run_until_completion(). The V parser performs the upstream
// post-parse action when the run loop consumes EOF, so this entry point shares
// that loop while making the completion intent explicit for streaming users.
pub fn (mut p HTMLParser) run_until_completion() {
	p.run_with_stop_at_insertion_point(.no)
}

pub fn (mut p HTMLParser) run_until_insertion_point() {
	p.run_with_stop_at_insertion_point(.yes)
}

fn (mut p HTMLParser) run_with_stop_at_insertion_point(stop_at_insertion_point StopAtInsertionPoint) {
	p.stop_parsing = false
	mut reached_end_of_file := false
	mut tokens_processed := 0
	for {
		tokens_processed++
		if tokens_processed % 256 == 0 { platform.cooperative_work_checkpoint() }
		if p.parser_pause_flag {
			break
		}
		if p.insert_text_run_if_available(stop_at_insertion_point) {
			platform.cooperative_work_checkpoint()
			if p.stop_parsing { break }
			continue
		}
		// The tokenizer reads a CDATA section only in foreign content.
		p.tokenizer.parser_in_foreign_content = p.adjusted_current_node_is_foreign()
		mut token := p.next_parser_token(stop_at_insertion_point) or { break }

		if p.next_line_feed_can_be_ignored {
			p.next_line_feed_can_be_ignored = false
			if token.is_character() && token.code_point == `\n` {
				continue
			}
		}

		// https://html.spec.whatwg.org/multipage/parsing.html#tree-construction-dispatcher
		if p.should_process_using_html_rules(token) {
			p.process_using_the_rules_for(p.insertion_mode, mut token)
		} else {
			p.process_using_the_rules_for_foreign_content(mut token)
		}

		if token.is_end_of_file() {
			reached_end_of_file = true
			break
		}
		if p.stop_parsing {
			break
		}
	}
	p.flush_character_insertions()
	p.tokenizer.parser_did_run()
	if stop_at_insertion_point == .no && p.document_.allow_declarative_shadow_roots() {
		materialize_declarative_shadow_roots(unsafe { &dom.Node(p.document_) })
	}
	if stop_at_insertion_point == .no && reached_end_of_file && !p.the_end_started
		&& (!p.tokenizer.is_insertion_point_defined() || p.tokenizer.is_eof_inserted()) {
		p.the_end_started = true
		p.invoke_parsing_complete_callback()
		HTMLParser.the_end(p.document_, p)
		p.retire_tokenizer_storage()
	}
}

fn (mut p HTMLParser) invoke_parsing_complete_callback() {
	if !p.tokenizer.is_input_stream_closed() {
		return
	}
	if callback := p.parsing_complete_callback {
		p.parsing_complete_callback = none
		callback()
	}
}

pub fn (mut p HTMLParser) schedule_resume_check() {
	if p.resume_check_pending || !p.parser_pause_flag || p.document_.has_been_destroyed() {
		return
	}
	p.resume_check_pending = true
	parser_pointer := voidptr(p)
	persistent := platform.enter_persistent()
	defer { platform.leave_persistent(persistent) }
	queue_a_task_with_storage(.unspecified, main_thread_event_loop(), none, fn [parser_pointer] () {
		perform_a_microtask_checkpoint()
		mut mutable_parser := unsafe { &HTMLParser(parser_pointer) }
		mutable_parser.resume_check_pending = false
		mutable_parser.resume_after_parser_blocking_script()
	}, p.document_.native_storage())
}

fn (mut p HTMLParser) resume_after_parser_blocking_script() {
	if !p.parser_pause_flag || p.aborted || p.stop_parsing {
		return
	}
	pending := p.document_.pending_parsing_blocking_script()
	pending_svg := p.document_.pending_parsing_blocking_svg_script()
	ready := if script := pending {
		html_script_element_is_ready_to_be_parser_executed(script)
	} else if script := pending_svg {
		svg_script_element_model_for_dom_element(script).is_ready_to_be_parser_executed()
	} else {
		return
	}
	if p.document_.has_a_style_sheet_that_is_blocking_scripts() || !ready {
		return
	}

	mut document := unsafe { &dom.Document(p.document_) }
	p.tokenizer.update_insertion_point()
	assert p.script_nesting_level == 0
	// A resumed script can synchronously reenter parsing through document.write().
	p.parser_pause_flag = false
	p.increment_script_nesting_level()
	if pending != none {
		the_script := document.take_pending_parsing_blocking_script()
		html_script_element_parser_execute_ready_script(the_script)
	} else {
		the_script := document.take_pending_parsing_blocking_svg_script()
		mut model := svg_script_element_model_for_dom_element(the_script)
		model.execute_pending_parser_blocking_script()
	}
	p.decrement_script_nesting_level()
	assert p.script_nesting_level == 0
	p.stop_the_speculative_html_parser()
	p.parser_pause_flag = false
	p.tokenizer.undefine_insertion_point()
	p.run()
	if !p.parser_pause_flag {
		if callback := p.ready_for_more_input_callback {
			callback()
		}
	}
	if p.parser_pause_flag {
		return
	}
	if p.finish_loading_after_parse {
		p.finish_loading_after_parse = false
		document.completely_finish_loading()
	}
}

// https://html.spec.whatwg.org/multipage/parsing.html#abort-a-parser
pub fn (mut p HTMLParser) abort() {
	p.aborted = true
	p.stop_parsing = true
	p.tokenizer.abort()
	p.stop_the_speculative_html_parser()
}

// https://html.spec.whatwg.org/multipage/parsing.html#start-the-speculative-html-parser
fn (mut p HTMLParser) start_the_speculative_html_parser() {
	if p.active_speculative_html_parser != none {
		p.stop_the_speculative_html_parser()
	}
	mut parser := SpeculativeHTMLParser.create(p.document_, p.tokenizer.unparsed_input(), p.document_.base_url(), p.speculative_fetch_hook)
	p.active_speculative_html_parser = parser
	parser.run()
}

// https://html.spec.whatwg.org/multipage/parsing.html#stop-the-speculative-html-parser
fn (mut p HTMLParser) stop_the_speculative_html_parser() {
	mut parser := p.active_speculative_html_parser or { return }
	parser.stop()
	p.active_speculative_html_parser = none
}

pub enum HTMLParserEndPhase {
	waiting_for_deferred_scripts
	waiting_for_asap_scripts
	waiting_for_load_event_delay
	completed
}

@[heap]
pub struct HTMLParserEndState {
mut:
	phase_        HTMLParserEndPhase = .waiting_for_deferred_scripts
	check_pending bool
	document      &dom.Document = unsafe { nil }
	parser        ?&HTMLParser
}

pub fn HTMLParserEndState.create(document &dom.Document, parser ?&HTMLParser) &HTMLParserEndState {
	return &HTMLParserEndState{
		document: document
		parser: parser
	}
}

pub fn (state &HTMLParserEndState) phase() HTMLParserEndPhase {
	return state.phase_
}

pub fn (state &HTMLParserEndState) has_pending_check() bool {
	return state.check_pending
}

fn html_parser_end_state_schedule_callback(target voidptr) {
	mut state := unsafe { &HTMLParserEndState(target) }
	state.schedule_progress_check()
}

pub fn (mut state HTMLParserEndState) schedule_progress_check() {
	if state.phase_ == .completed || state.check_pending || state.document.has_been_destroyed() {
		return
	}
	state.check_pending = true
	state_pointer := voidptr(state)
	persistent := platform.enter_persistent()
	defer { platform.leave_persistent(persistent) }
	queue_a_task_with_storage(.unspecified, main_thread_event_loop(), none, fn [state_pointer] () {
		perform_a_microtask_checkpoint()
		mut mutable_state := unsafe { &HTMLParserEndState(state_pointer) }
		mutable_state.check_progress()
		mutable_state.check_pending = false
	}, state.document.native_storage())
}

fn (mut state HTMLParserEndState) check_progress() {
	if !state.document.is_fully_active() {
		state.complete()
		return
	}
	if state.phase_ == .waiting_for_deferred_scripts {
		for {
			script := state.document.first_script_to_execute_when_parsing_has_finished() or {
				break
			}
			if !html_script_element_is_ready_to_be_parser_executed(script)
				|| state.document.has_a_style_sheet_that_is_blocking_scripts() {
				return
			}
			html_script_element_execute_script(script)
			mut mutable_document := unsafe { &dom.Document(state.document) }
			mutable_document.remove_first_script_to_execute_when_parsing_has_finished()
		}
		state.advance_to_asap_scripts_phase()
	}
	if state.phase_ == .waiting_for_asap_scripts {
		if state.document.has_scripts_to_execute_as_soon_as_possible() {
			return
		}
		state.phase_ = .waiting_for_load_event_delay
	}
	if state.phase_ == .waiting_for_load_event_delay {
		if parser_end_waits_for_rendering_fonts(state.document) {
			return
		}
		// Font faces are selected lazily by text shaping. Flush layout before the
		// readiness check so a selected download can delay the load event.
		mut mutable_document := unsafe { &dom.Document(state.document) }
		mutable_document.update_layout(.document_readiness_complete)
		if state.document.anything_is_delaying_the_load_event() {
			return
		}
		state.complete()
	}
}

fn parser_end_waits_for_rendering_fonts(document &dom.Document) bool {
	owner := document.existing_font_face_set() or { return false }
	if owner.font_face_set_record() == unsafe { nil } { return false }
	fonts := unsafe { &css.FontFaceSet(owner.font_face_set_record()) }
	// Layout has already selected these faces. A fallback-layout probe cannot
	// complete readiness while their existing load-event delay remains active.
	for face in fonts.loading_fonts() {
		if face.has_pending_rendering() {
			return document.anything_is_delaying_the_load_event()
		}
	}
	return false
}

fn (mut state HTMLParserEndState) advance_to_asap_scripts_phase() {
	document := state.document
	queue_a_task(.dom_manipulation, main_thread_event_loop(), document, fn [document] () {
		mut mutable_document := unsafe { &dom.Document(document) }
		if !mutable_document.claim_readiness_event('DOMContentLoaded') {
			return
		}
		mutable_document.mark_dom_content_loaded_event_start()
		mutable_document.dispatch_event_simple('DOMContentLoaded', true)
		mutable_document.mark_dom_content_loaded_event_end()
	})
	state.phase_ = .waiting_for_asap_scripts
}

fn (mut state HTMLParserEndState) complete() {
	if state.phase_ == .completed {
		return
	}
	state.phase_ = .completed
	mut mutable_document := unsafe { &dom.Document(state.document) }
	mutable_document.clear_html_parser_end_state(voidptr(state))
	document := state.document
	parser := state.parser
	queue_a_task(.dom_manipulation, main_thread_event_loop(), document, fn [document, parser] () {
		mut mutable_document := unsafe { &dom.Document(document) }
		mutable_document.update_readiness(.complete)
		if parser != none {
			mutable_document.detach_parser()
		}
		if mutable_document.get_browsing_context() == none {
			return
		}
		// The browser starts iframe navigations after parsing, so a child can
		// begin delaying the load event after the end check queued this task.
		// The scripting runtime then fires load once nothing delays it.
		if !mutable_document.anything_is_delaying_the_load_event()
			&& mutable_document.claim_readiness_event('load') {
			// Fire load at the Document's relevant global object, where the
			// scripting runtime's readiness dispatch also delivers it.
			if window := mutable_document.get_window() {
				target := unsafe { &dom.EventTarget(window) }
				target.dispatch_event(dom.Event.create('load', dom.EventInit{}))
			} else {
				mutable_document.dispatch_event_simple('load', false)
			}
		}
		mutable_document.set_page_showing(true)
		mutable_document.completely_finish_loading()
	})
	mutable_document.set_ready_for_post_load_tasks(true)
	if host := state.document.navigable() {
		if navigable := navigable_model_for_host(host) {
			mut mutable_navigable := unsafe { &NavigableModel(navigable) }
			mutable_navigable.clear_navigation_load_event_guard()
		}
	}
}

// https://html.spec.whatwg.org/multipage/parsing.html#the-end
pub fn HTMLParser.the_end(document &dom.Document, parser ?&HTMLParser) {
	if concrete_parser := parser {
		if concrete_parser.parsing_fragment {
			return
		}
		mut mutable_parser := unsafe { &HTMLParser(concrete_parser) }
		if mutable_parser.active_speculative_html_parser != none {
			mutable_parser.stop_the_speculative_html_parser()
			return
		}
		mutable_parser.tokenizer.undefine_insertion_point()
	}
	mut mutable_document := unsafe { &dom.Document(document) }
	mutable_document.update_readiness(.interactive)
	if concrete_parser := parser {
		mut mutable_parser := unsafe { &HTMLParser(concrete_parser) }
		for !mutable_parser.stack_of_open_elements.is_empty() {
			mutable_parser.stack_of_open_elements.pop()
		}
	}
	if document.get_browsing_context() == none {
		mutable_document.update_readiness(.complete)
		return
	}
	mut state := HTMLParserEndState.create(document, parser)
	mutable_document.set_html_parser_end_state(voidptr(state), html_parser_end_state_schedule_callback)
	state.schedule_progress_check()
}

// The tree-construction rules parse a template's contents into its inert
// DocumentFragment. Once parsing is complete, materialize declarative shadow
// roots by attaching that fragment to the template's parent and removing the
// template element. Processing the fragment first also handles nested roots.
// This read-only walk invokes no DOM hooks, so it can follow sibling links
// without owning snapshots. Most documents have no templates to materialize.
fn has_declarative_shadow_templates(node &dom.Node) bool {
	mut child := node.first_child()
	for child != none {
		current := child or { break }
		if element := current.as_element() {
			if element.local_name() == 'template' { return true }
			if root := element.shadow_root() {
				if has_declarative_shadow_templates(root.as_node()) { return true }
			}
		}
		if has_declarative_shadow_templates(current) { return true }
		child = current.next_sibling()
	}
	return false
}

fn materialize_declarative_shadow_roots(node &dom.Node) {
	if !has_declarative_shadow_templates(node) { return }
	materialize_declarative_shadow_roots_with_templates(node)
}

fn materialize_declarative_shadow_roots_with_templates(node &dom.Node) {
	// A leaf has no templates or descendants to inspect. Its parent's walk
	// still visits any shadow root attached to it separately below.
	if !node.has_children() { return }
	// Descendant processing can attach roots and invoke DOM hooks. Keep the
	// pointer snapshot alive across that work, but allocate DOM changes in the
	// caller's owner rather than the snapshot workspace.
	children_scratch := platform.begin_thread_scratch('declarative shadow descendants')
	children := node.children_as_vector()
	children_scratch.leave()
	defer { children_scratch.finish() }
	for child in children {
		if element := child.as_element() {
			if element.local_name() == 'template' {
				template := unsafe { &dom.HTMLTemplateElement(element) }
				materialize_declarative_shadow_roots_with_templates(template.content().as_node())
			} else {
				materialize_declarative_shadow_roots_with_templates(child)
			}
			if shadow_root := element.shadow_root() {
				materialize_declarative_shadow_roots_with_templates(unsafe { &dom.Node(shadow_root) })
			}
		} else {
			materialize_declarative_shadow_roots_with_templates(child)
		}
	}
	templates_scratch := platform.begin_thread_scratch('declarative shadow templates')
	templates := node.children_as_vector()
	templates_scratch.leave()
	defer { templates_scratch.finish() }
	for child in templates {
		template_element := child.as_element() or { continue }
		if template_element.local_name() != 'template' {
			continue
		}
		mode_name := template_element.get_attribute_value('shadowrootmode').to_lower()
		if mode_name !in ['open', 'closed'] {
			continue
		}
		mut host := node.as_element() or { continue }
		mode := if mode_name == 'closed' { dom.ShadowRootMode.closed } else { .open }
		keeps_registry_null := template_element.has_attribute('shadowrootcustomelementregistry')
		mut registry := voidptr(0)
		if !keeps_registry_null {
			registry = host.document().custom_element_registry()
		}
		host.attach_a_shadow_root_with_registry(mode, template_element.has_attribute('shadowrootclonable'), template_element.has_attribute('shadowrootserializable'), template_element.has_attribute('shadowrootdelegatesfocus'), .named, registry) or {
			continue
		}
		mut shadow_root := host.shadow_root() or { continue }
		shadow_root.set_declarative(true)
		shadow_root.set_keep_custom_element_registry_null(keeps_registry_null)
		template := unsafe { &dom.HTMLTemplateElement(template_element) }
		mut content := template.content().as_node()
		mut shadow_node := unsafe { &dom.Node(shadow_root) }
		content_scratch := platform.begin_thread_scratch('declarative shadow content')
		content_children := content.children_as_vector()
		content_scratch.leave()
		for content_child in content_children {
			moved := content.remove_child(content_child) or { continue }
			shadow_node.append_child(moved) or {}
		}
		content_scratch.finish()
		mut host_node := host.as_node()
		host_node.remove_child(template_element.as_node()) or {}
	}
}

fn (mut p HTMLParser) process_using_the_rules_for(mode InsertionMode, mut token HTMLToken) {
	match mode {
		.initial { p.handle_initial(mut token) }
		.before_html { p.handle_before_html(mut token) }
		.before_head { p.handle_before_head(mut token) }
		.in_head { p.handle_in_head(mut token) }
		.in_head_noscript { p.handle_in_head_noscript(mut token) }
		.after_head { p.handle_after_head(mut token) }
		.in_body { p.handle_in_body(mut token) }
		.text { p.handle_text(mut token) }
		.after_body { p.handle_after_body(mut token) }
		.after_after_body { p.handle_after_after_body(mut token) }
		.in_table { p.handle_in_table(mut token) }
		.in_table_text { p.handle_in_table_text(mut token) }
		.in_table_body { p.handle_in_table_body(mut token) }
		.in_row { p.handle_in_row(mut token) }
		.in_cell { p.handle_in_cell(mut token) }
		.in_caption { p.handle_in_caption(mut token) }
		.in_column_group { p.handle_in_column_group(mut token) }
		.in_template { p.handle_in_template(mut token) }
		.in_frameset { p.handle_in_frameset(mut token) }
		.after_frameset { p.handle_after_frameset(mut token) }
		.after_after_frameset { p.handle_after_after_frameset(mut token) }
	}
}

// ===== tree-building primitives =====
fn (p &HTMLParser) current_node() ?&dom.Element {
	if p.stack_of_open_elements.is_empty() {
		return none
	}
	return p.stack_of_open_elements.current_node()
}

// https://html.spec.whatwg.org/multipage/parsing.html#markup-declaration-open-state
// CDATA sections are allowed when the adjusted current node is a foreign
// element whose content is parsed as foreign content: integration points
// take HTML content, as WPT's cdata-in-integration-point-fragment requires.
fn (p &HTMLParser) adjusted_current_node_is_foreign() bool {
	node := p.adjusted_current_node() or { return false }
	return !node.is_html_element() && !is_mathml_text_integration_point(node)
		&& !is_html_integration_point(node)
}

fn (p &HTMLParser) adjusted_current_node() ?&dom.Element {
	if p.parsing_fragment && p.stack_of_open_elements.elements.len == 1 {
		return p.context_element
	}
	return p.current_node()
}

fn (p &HTMLParser) node_before_current_node() ?&dom.Element {
	if p.stack_of_open_elements.elements.len < 2 {
		return none
	}
	return p.stack_of_open_elements.elements[p.stack_of_open_elements.elements.len - 2]
}

// https://html.spec.whatwg.org/multipage/parsing.html#appropriate-place-for-inserting-a-node
fn (mut p HTMLParser) find_appropriate_place_for_inserting_node_with_override(override_target ?&dom.Element) AdjustedInsertionLocation {
	target := override_target or { p.current_node() or { return AdjustedInsertionLocation{} } }
	mut location := AdjustedInsertionLocation{
		parent: target.as_node()
		insert_before_sibling: none
	}
	if p.foster_parenting && target.local_name() in ['table', 'tbody', 'tfoot', 'thead', 'tr'] {
		last_template := p.stack_of_open_elements.last_element_with_tag_name('template')
		last_table := p.stack_of_open_elements.last_element_with_tag_name('table')
		if template := last_template.element {
			if last_table.element == none || last_template.index > last_table.index {
				template_element := unsafe { &dom.HTMLTemplateElement(template) }
				return AdjustedInsertionLocation{
					parent: template_element.content().as_node()
					insert_before_sibling: none
				}
			}
		}
		if lt := last_table.element {
			if parent := lt.as_node().parent_node() {
				// If last table has a parent node, insert immediately before last table.
				location = AdjustedInsertionLocation{
					parent: parent
					insert_before_sibling: lt.as_node()
				}
			} else if previous_element := p.stack_of_open_elements.element_immediately_above(lt) {
				// Otherwise, inside the element immediately above last table.
				location = AdjustedInsertionLocation{
					parent: previous_element.as_node()
					insert_before_sibling: none
				}
			}
		} else {
			// No last table (fragment case): inside the first element, after its last child.
			location = AdjustedInsertionLocation{
				parent: p.stack_of_open_elements.first().as_node()
				insert_before_sibling: none
			}
		}
	}
	// If the adjusted insertion location is inside a template element, redirect to its contents.
	if parent := location.parent {
		if el := parent.as_element() {
			if element_in_namespace(el, ns_html) && el.local_name() == 'template' {
				template_element := unsafe { &dom.HTMLTemplateElement(el) }
				return AdjustedInsertionLocation{
					parent: template_element.content().as_node()
					insert_before_sibling: none
				}
			}
		}
	}
	return location
}

fn (mut p HTMLParser) find_appropriate_place_for_inserting_node() AdjustedInsertionLocation {
	return p.find_appropriate_place_for_inserting_node_with_override(none)
}

// ===== table-context stack helpers =====
fn (mut p HTMLParser) clear_the_stack_back_to_a_table_context() {
	for {
		cn := p.current_node() or { break }
		if cn.local_name() in ['table', 'template', 'html'] {
			break
		}
		p.stack_of_open_elements.pop()
	}
}

fn (mut p HTMLParser) clear_the_stack_back_to_a_table_row_context() {
	for {
		cn := p.current_node() or { break }
		if cn.local_name() in ['tr', 'template', 'html'] {
			break
		}
		p.stack_of_open_elements.pop()
	}
}

fn (mut p HTMLParser) clear_the_stack_back_to_a_table_body_context() {
	for {
		cn := p.current_node() or { break }
		if cn.local_name() in ['tbody', 'tfoot', 'thead', 'template', 'html'] {
			break
		}
		p.stack_of_open_elements.pop()
	}
}

fn (mut p HTMLParser) close_the_cell() {
	p.generate_implied_end_tags('')
	for {
		cn := p.current_node() or { break }
		if cn.local_name() in ['td', 'th'] {
			break
		}
		p.stack_of_open_elements.pop()
	}
	p.stack_of_open_elements.pop()
	p.list_of_active_formatting_elements.clear_up_to_the_last_marker()
	p.insertion_mode = .in_row
}

// https://html.spec.whatwg.org/multipage/parsing.html#reset-the-insertion-mode-appropriately
fn (mut p HTMLParser) reset_the_insertion_mode_appropriately() {
	mut last := false
	for i := p.stack_of_open_elements.elements.len - 1; i >= 0; i-- {
		mut node := p.stack_of_open_elements.elements[i]
		if i == 0 {
			last = true
			if p.parsing_fragment {
				if ctx := p.context_element {
					node = ctx
				}
			}
		}
		if element_in_namespace(node, ns_html) {
			ln := node.local_name()
			if !last && ln in ['td', 'th'] {
				p.insertion_mode = .in_cell
				return
			}
			if ln == 'tr' {
				p.insertion_mode = .in_row
				return
			}
			if ln in ['tbody', 'thead', 'tfoot'] {
				p.insertion_mode = .in_table_body
				return
			}
			if ln == 'caption' {
				p.insertion_mode = .in_caption
				return
			}
			if ln == 'colgroup' {
				p.insertion_mode = .in_column_group
				return
			}
			if ln == 'table' {
				p.insertion_mode = .in_table
				return
			}
			if ln == 'template' {
				p.insertion_mode = if p.stack_of_template_insertion_modes.len > 0 {
					p.stack_of_template_insertion_modes[p.stack_of_template_insertion_modes.len - 1]
				} else {
					InsertionMode.in_body
				}
				return
			}
			if !last && ln == 'head' {
				p.insertion_mode = .in_head
				return
			}
			if ln == 'body' {
				p.insertion_mode = .in_body
				return
			}
			if ln == 'frameset' {
				p.insertion_mode = .in_frameset
				return
			}
			if ln == 'html' {
				p.insertion_mode = if p.head_element == none {
					InsertionMode.before_head
				} else {
					InsertionMode.after_head
				}
				return
			}
		}
		if last {
			p.insertion_mode = .in_body
			return
		}
	}
}

// https://html.spec.whatwg.org/multipage/parsing.html#create-an-element-for-the-token
fn (mut p HTMLParser) create_element_for(token &HTMLToken, namespace_ ?string, intended_parent &dom.Node) &dom.Element {
	// Steps 1-2 concern the optional speculative parser. This parser is the
	// active tree builder, so there is no speculative mock-element branch.
	document := intended_parent.document()
	local_name := p.own_tokenizer_string(token.tag_name)
	is_value := p.own_tokenizer_optional_string(token.attribute('is'))
	registry := dom.look_up_custom_element_registry(intended_parent)
	definition := dom.look_up_custom_element_definition(registry, namespace_, local_name, is_value)
	will_execute_script := definition != none && !p.parsing_fragment
	mut mutable_document := unsafe { &dom.Document(document) }
	if will_execute_script {
		mutable_document.increment_throw_on_dynamic_markup_insertion_counter()
	}
	mut element := dom.create_element_with_registry(document, local_name, namespace_, none, is_value, will_execute_script, registry) or {
		if will_execute_script {
			mutable_document.decrement_throw_on_dynamic_markup_insertion_counter()
		}
		panic('create_element_for(${local_name}): ${err}')
	}
	if token.had_duplicate_attribute {
		element.set_had_duplicate_attribute_during_tokenization()
	}
	// AD-HOC: Let style elements know which document they were originally parsed for.
	//         This is used for the render-blocking logic.
	if mut style_element := element.style_element_base() {
		style_element.set_parser_document(document)
	}
	// Append each attribute in the token to element. Foreign-content attributes
	// carry a prefix and namespace from adjust_foreign_attributes().
	for attribute in token.attributes {
		if attribute.prefix != none || attribute.namespace_ != none {
			element.set_attribute_value_ns(p.own_tokenizer_string(attribute.local_name), p.own_tokenizer_string(attribute.value), p.own_tokenizer_optional_string(attribute.prefix), p.own_tokenizer_optional_string(attribute.namespace_))
		} else if !element.has_attribute(attribute.local_name) {
			element.set_attribute_value(p.own_tokenizer_string(attribute.local_name), p.own_tokenizer_string(attribute.value))
		}
	}
	if will_execute_script {
		mutable_document.decrement_throw_on_dynamic_markup_insertion_counter()
	}
	return element
}

// https://html.spec.whatwg.org/multipage/parsing.html#insert-a-foreign-element
fn (mut p HTMLParser) insert_foreign_element(token &HTMLToken, namespace_ ?string, only_add_to_element_stack bool) &dom.Element {
	location := p.find_appropriate_place_for_inserting_node()
	parent := location.parent or { panic('insert_foreign_element with no insertion parent') }
	element := p.create_element_for(token, namespace_, parent)
	if !only_add_to_element_stack {
		p.insert_an_element_at_the_adjusted_insertion_location(element)
	}
	p.stack_of_open_elements.push(element)
	return element
}

// https://html.spec.whatwg.org/multipage/parsing.html#insert-an-html-element
fn (mut p HTMLParser) insert_html_element(token &HTMLToken) &dom.Element {
	return p.insert_foreign_element(token, ns_html, false)
}

fn (mut p HTMLParser) insert_an_element_at_the_adjusted_insertion_location(element &dom.Element) {
	location := p.find_appropriate_place_for_inserting_node()
	mut parent := location.parent or { return }
	record_parser_insertion_location(location)
	parent.insert_before(element.as_node(), location.insert_before_sibling, false)
}

fn (mut p HTMLParser) insert_comment(token &HTMLToken) {
	location := p.find_appropriate_place_for_inserting_node()
	mut parent := location.parent or { return }
	comment := p.document_.create_comment(p.own_tokenizer_string(token.comment()))
	record_parser_insertion_location(location)
	parent.insert_before(comment.as_node(), location.insert_before_sibling, false)
}

fn (mut p HTMLParser) find_character_insertion_node() ?&dom.Text {
	location := p.find_appropriate_place_for_inserting_node()
	mut parent := location.parent or { return none }
	if sibling := location.insert_before_sibling {
		if prev := sibling.previous_sibling() {
			if prev.is_text() {
				return node_as_text(prev)
			}
		}
		new_text := p.document_.create_text_node('')
		record_parser_insertion_location(location)
		parent.insert_before(new_text.as_node(), sibling, false)
		return new_text
	}
	if parent.is_document() {
		return none
	}
	if last := parent.last_child() {
		if last.is_text() {
			return node_as_text(last)
		}
	}
	mut new_text := p.document_.create_text_node('')
	parent.append_child(new_text.as_node()) or {}
	return new_text
}

fn (mut p HTMLParser) flush_character_insertions() {
	if p.character_insertion_builder.len == 0 {
		return
	}
	mut node := p.character_insertion_node or {
		p.character_insertion_builder.clear()
		return
	}

	data := p.character_insertion_text()
	if node.data() == '' {
		node.set_data(data)
	} else {
		node.append_data(data) or {}
	}
	// CharacterData owns the emitted text. The next text node can reuse this
	// private workspace without changing earlier nodes.
	p.character_insertion_builder.clear()
}

fn (mut p HTMLParser) handle_element_popped(element &dom.Element) {
	// https://html.spec.whatwg.org/multipage/semantics.html#update-a-style-block
	// When a style element is popped off the stack of open elements of an HTML parser or XML parser,
	// the user agent must run the update a style block algorithm.
	// NB: Upstream's tree builder flushes buffered text before invoking this hook, so the style block sees its
	//     complete text.
	if mut style_element := element.style_element_base() {
		p.flush_character_insertions()
		if p.resource_discovery_only {
			assert p.scripting_mode == .inert
			style_element.finish_resource_discovery_parsing()
		} else {
			style_element.did_pop_off_parser_stack_of_open_elements()
		}
	}

	// https://html.spec.whatwg.org/multipage/form-elements.html#the-option-element
	// When an option element is popped off the stack of open elements of an HTML parser or XML parser,
	// the user agent must run maybe clone an option into selectedcontent given the option element.
	// An option's buffered text must be visible before the selectedcontent
	// cloning algorithm observes it.
	if element_in_namespace(element, ns_html) && element.local_name() == 'option' {
		p.flush_character_insertions()
		html_option_element_maybe_clone_into_selectedcontent(unsafe {
			&dom.HTMLOptionElement(element)
		}) or {}
	}
}

fn (mut p HTMLParser) insert_character(data rune) {
	node := p.find_character_insertion_node() or { return }
	if cin := p.character_insertion_node {
		if same_node(node.as_node(), cin.as_node()) {
			p.append_character_insertion(data)
			return
		}
		p.flush_character_insertions()
		p.character_insertion_node = node
		p.append_character_insertion(data)
		return
	}
	p.character_insertion_node = node
	p.append_character_insertion(data)
}

// ===== implied end tags / p closing =====
const implied_end_tag_names = ['dd', 'dt', 'li', 'optgroup', 'option', 'p', 'rb', 'rp', 'rt', 'rtc']

fn (mut p HTMLParser) generate_implied_end_tags(exception string) {
	for {
		cn := p.current_node() or { break }
		if cn.local_name() == exception || cn.local_name() !in implied_end_tag_names {
			break
		}
		p.stack_of_open_elements.pop()
	}
}

fn (mut p HTMLParser) generate_all_implied_end_tags_thoroughly() {
	all := ['caption', 'colgroup', 'dd', 'dt', 'li', 'optgroup', 'option', 'p', 'rb', 'rp', 'rt',
		'rtc', 'tbody', 'td', 'tfoot', 'th', 'thead', 'tr']
	for {
		cn := p.current_node() or { break }
		if cn.local_name() !in all {
			break
		}
		p.stack_of_open_elements.pop()
	}
}

fn (mut p HTMLParser) close_a_p_element() {
	p.generate_implied_end_tags('p')
	p.stack_of_open_elements.pop_until_an_element_with_tag_name_has_been_popped('p')
}

// https://html.spec.whatwg.org/multipage/parsing.html#reconstruct-the-active-formatting-elements
fn (mut p HTMLParser) reconstruct_the_active_formatting_elements() {
	if p.list_of_active_formatting_elements.is_empty() {
		return
	}
	entries := p.list_of_active_formatting_elements.entries
	last := entries[entries.len - 1]
	if last.is_marker() {
		return
	}
	if last_el := last.element {
		if p.stack_of_open_elements.contains(last_el) {
			return
		}
	}

	mut index := entries.len - 1
	// Rewind.
	for {
		if index == 0 {
			break
		}
		index--
		entry := p.list_of_active_formatting_elements.entries[index]
		if entry.is_marker() {
			index++ // Advance.
			break
		}
		if el := entry.element {
			if p.stack_of_open_elements.contains(el) {
				index++ // Advance.
				break
			}
		}
	}

	// Create / Advance loop.
	for {
		entry := p.list_of_active_formatting_elements.entries[index]
		token := entry.token or { break }
		old_element := entry.element or { break }
		new_element := p.insert_html_element(token)
		p.list_of_active_formatting_elements.replace(old_element, new_element, token)
		if index == p.list_of_active_formatting_elements.entries.len - 1 {
			break
		}
		index++
	}
}

fn (mut p HTMLParser) parse_generic_raw_text_element(token &HTMLToken) {
	p.insert_html_element(token)
	p.tokenizer.switch_to(.rawtext)
	p.original_insertion_mode = p.insertion_mode
	p.insertion_mode = .text
}

fn (p &HTMLParser) which_quirks_mode(token &HTMLToken) dom.QuirksMode {
	_ = p
	if token.doctype.force_quirks {
		return .yes
	}
	// NOTE: the tokenizer lower-cases the name for us.
	if token.doctype.name != 'html' {
		return .yes
	}
	public_identifier := ascii_lowercase_string(token.doctype.public_identifier)
	system_identifier := ascii_lowercase_string(token.doctype.system_identifier)
	if public_identifier in ['-//w3o//dtd w3 html strict 3.0//en//',
		'-/w3c/dtd html 4.0 transitional/en', 'html'] {
		return .yes
	}
	if system_identifier == 'http://www.ibm.com/data/dtd/v11/ibmxhtml1-transitional.dtd' {
		return .yes
	}
	for public_id in quirks_public_id_prefixes {
		if public_identifier.starts_with(ascii_lowercase_string(public_id)) {
			return .yes
		}
	}
	if token.doctype.missing_system_identifier && (public_identifier.starts_with('-//w3c//dtd html 4.01 frameset//') || public_identifier.starts_with('-//w3c//dtd html 4.01 transitional//')) {
		return .yes
	}
	if public_identifier.starts_with('-//w3c//dtd xhtml 1.0 frameset//') || public_identifier.starts_with('-//w3c//dtd xhtml 1.0 transitional//') {
		return .limited
	}
	if !token.doctype.missing_system_identifier && (public_identifier.starts_with('-//w3c//dtd html 4.01 frameset//') || public_identifier.starts_with('-//w3c//dtd html 4.01 transitional//')) {
		return .limited
	}
	return .no
}

// ===== adoption agency algorithm =====
// https://html.spec.whatwg.org/multipage/parsing.html#adoption-agency-algorithm
enum AdoptionAgencyOutcome {
	do_nothing
	run_any_other_end_tag_steps
}

fn (mut p HTMLParser) run_the_adoption_agency_algorithm(token &HTMLToken) AdoptionAgencyOutcome {
	subject := token.tag_name

	// 2. If the current node is an HTML element whose tag name is subject, and is not in the list of
	//    active formatting elements, pop it and return.
	if cn := p.current_node() {
		if cn.local_name() == subject && !p.list_of_active_formatting_elements.contains(cn) {
			p.stack_of_open_elements.pop()
			return .do_nothing
		}
	}

	mut outer_loop_counter := 0
	for {
		if outer_loop_counter >= 8 {
			return .do_nothing
		}
		outer_loop_counter++

		// 3. formattingElement = last element with tag name subject before the last marker.
		formatting_element := p.list_of_active_formatting_elements.last_element_with_tag_name_before_marker(subject) or {
			return .run_any_other_end_tag_steps
		}

		// 4. Not in the stack of open elements -> remove from AFE and return.
		if !p.stack_of_open_elements.contains(formatting_element) {
			p.list_of_active_formatting_elements.remove(formatting_element)
			return .do_nothing
		}

		// 5. In the stack but not in scope -> return.
		if !p.stack_of_open_elements.has_in_scope_element(formatting_element) {
			return .do_nothing
		}

		// 7. furthestBlock = topmost special node below formattingElement.
		// 8. No furthestBlock: pop up to and including formattingElement, remove from AFE, return.
		furthest_block := p.stack_of_open_elements.topmost_special_node_below(formatting_element) or {
			for {
				cn := p.current_node() or { break }
				if same_element(cn, formatting_element) {
					break
				}
				p.stack_of_open_elements.pop()
			}
			p.stack_of_open_elements.pop()
			p.list_of_active_formatting_elements.remove(formatting_element)
			return .do_nothing
		}

		// 9. commonAncestor = element immediately above formattingElement.
		common_ancestor := p.stack_of_open_elements.element_immediately_above(formatting_element) or {
			return .do_nothing
		}

		// 10. bookmark.
		mut bookmark := p.list_of_active_formatting_elements.find_index(formatting_element) or { 0 }

		// 11. node and lastNode = furthestBlock.
		mut node := unsafe { furthest_block }
		mut last_node := unsafe { furthest_block }
		mut node_above_node := p.stack_of_open_elements.element_immediately_above(node)

		mut inner_loop_counter := 0
		for {
			inner_loop_counter++

			// 2. node = element immediately above node.
			node = node_above_node or { break }
			node_above_node = p.stack_of_open_elements.element_immediately_above(node)

			// 3. If node is formattingElement, break.
			if same_element(node, formatting_element) {
				break
			}

			mut node_index := p.list_of_active_formatting_elements.find_index(node)

			// 4. innerLoopCounter > 3 and node in AFE -> remove from AFE.
			if inner_loop_counter > 3 {
				if idx := node_index {
					if idx < bookmark {
						bookmark--
					}
					p.list_of_active_formatting_elements.remove(node)
					node_index = none
				}
			}

			// 5. node not in AFE -> remove from stack and continue.
			idx := node_index or {
				p.stack_of_open_elements.remove(node)
				continue
			}

			// 6. Create a new element for node's token, replace entries, node = new element.
			entry := p.list_of_active_formatting_elements.entries[idx]
			entry_token := entry.token or { continue }
			element := p.create_element_for(entry_token, ns_html, common_ancestor.as_node())
			p.list_of_active_formatting_elements.replace(node, element, entry_token)
			p.stack_of_open_elements.replace(node, element)
			node = element

			// 7. If lastNode is furthestBlock, move bookmark after new node.
			if same_element(last_node, furthest_block) {
				bookmark = (p.list_of_active_formatting_elements.find_index(node) or { 0 }) + 1
			}

			// 8. Append lastNode to node.
			mut node_dom := node.as_node()
			node_dom.append_child(last_node.as_node()) or {}

			// 9. lastNode = node.
			last_node = node
		}

		// 14. Insert lastNode at the appropriate place with commonAncestor as override target.
		adjusted_location := p.find_appropriate_place_for_inserting_node_with_override(common_ancestor)
		mut adjusted_parent := adjusted_location.parent or { return .do_nothing }
		record_parser_insertion_location(adjusted_location)
		adjusted_parent.insert_before(last_node.as_node(), adjusted_location.insert_before_sibling, false)

		// 15. Create a new element for formattingElement's token, with furthestBlock as intended parent.
		formatting_element_index := p.list_of_active_formatting_elements.find_index(formatting_element) or {
			return .do_nothing
		}
		fe_entry := p.list_of_active_formatting_elements.entries[formatting_element_index]
		fe_token := fe_entry.token or { return .do_nothing }
		token_data := p.list_of_active_formatting_elements.parser_owned_token(fe_token)
		new_element := p.create_element_for(token_data, ns_html, furthest_block.as_node())

		// 16. Move furthestBlock's children into the new element.
		mut fb_node := furthest_block.as_node()
		mut new_element_node := new_element.as_node()
		for child in fb_node.children_as_vector() {
			removed := fb_node.remove_child(child) or { continue }
			new_element_node.append_child(removed) or {}
		}

		// 17. Append the new element to furthestBlock.
		fb_node.append_child(new_element.as_node()) or {}

		// 18. Remove formattingElement from AFE, insert new element at bookmark.
		if formatting_element_index < bookmark {
			bookmark--
		}
		p.list_of_active_formatting_elements.remove(formatting_element)
		p.list_of_active_formatting_elements.insert_at(bookmark, new_element, token_data)

		// 19. Remove formattingElement from the stack, insert new element below furthestBlock.
		p.stack_of_open_elements.remove(formatting_element)
		p.stack_of_open_elements.insert_immediately_below(new_element, furthest_block)
	}
	return .do_nothing
}
