module html

import css
import dom

#include "parser_stack_context_test.h"

$if gcboehm ? {
	fn C.vox_parser_stack_watch(index u32, owner voidptr)
	fn C.vox_parser_stack_collect(depth u32)
	fn C.vox_parser_stack_run_worker(work fn ())
	fn C.vox_parser_stack_run_with_parser(work fn (voidptr))
	fn C.vox_parser_stack_owners_alive() u32
}

struct ParserStackPopObservation {
mut:
	stack &StackOfOpenElements = unsafe { nil }
	tags []string
	lengths []int
	reentrant bool
}

__global parser_stack_legacy_pops int
__global parser_stack_nil_pops int
__global parser_stack_retained_owner &StackOfOpenElements

fn parser_stack_record_pop(context voidptr, element &dom.Element) {
	mut observation := unsafe { &ParserStackPopObservation(context) }
	observation.tags << element.local_name()
	observation.lengths << observation.stack.elements().len
	if observation.reentrant && observation.stack.elements().len > 0 {
		observation.stack.pop()
	}
}

fn parser_stack_legacy_pop(_ &dom.Element) {
	parser_stack_legacy_pops++
}

fn parser_stack_nil_pop(context voidptr, _ &dom.Element) {
	assert context == unsafe { nil }
	parser_stack_nil_pops++
}

fn test_context_stack_pop_preserves_removal_order_and_reentrant_callbacks() {
	document := dom.Document.create(dom.url_about_blank())
	mut stack := &StackOfOpenElements{}
	mut observation := &ParserStackPopObservation{stack: stack, reentrant: true}
	stack.set_on_element_popped_with_context(voidptr(observation), parser_stack_record_pop)
	first := document.create_element_ns(ns_html, 'section') or { panic(err) }
	last := document.create_element_ns(ns_html, 'span') or { panic(err) }
	stack.push(first)
	stack.push(last)
	assert same_element(stack.pop(), last)
	assert stack.is_empty()
	assert observation.tags == ['span', 'section']
	assert observation.lengths == [1, 0]
}

fn test_context_and_legacy_pop_setters_replace_each_other_without_duplicate_delivery() {
	document := dom.Document.create(dom.url_about_blank())
	mut stack := &StackOfOpenElements{}
	first := &ParserStackPopObservation{stack: stack}
	second := &ParserStackPopObservation{stack: stack}
	element := document.create_element_ns(ns_html, 'section') or { panic(err) }
	parser_stack_legacy_pops = 0
	stack.set_on_element_popped_with_context(voidptr(first), parser_stack_record_pop)
	stack.push(element)
	stack.pop()
	stack.set_on_element_popped(parser_stack_legacy_pop)
	stack.push(element)
	stack.pop()
	stack.set_on_element_popped_with_context(voidptr(second), parser_stack_record_pop)
	stack.push(element)
	stack.pop()
	assert first.tags == ['section'] && second.tags == ['section']
	assert parser_stack_legacy_pops == 1
	parser_stack_nil_pops = 0
	stack.set_on_element_popped_with_context(unsafe { nil }, parser_stack_nil_pop)
	stack.push(element)
	stack.pop()
	assert parser_stack_nil_pops == 1 && parser_stack_legacy_pops == 1
	assert first.tags.len == 1 && second.tags.len == 1
}

fn test_parser_context_callback_publishes_complete_style_and_selected_option_text() {
	mut document := dom.Document.create(dom.url_about_blank())
	document.set_scripting_enabled_by_embedder(false)
	mut parser := HTMLParser.create_with_scripting_mode(document,
		'<!doctype html><style id="sheet">p{color:red}div{color:blue}</style><select><button><selectedcontent id="chosen"></selectedcontent></button><option selected><b>Complete choice</b></option></select>', .disabled)
	parser.run()
	style := document.get_element_by_id('sheet') or { panic('missing style') }
	assert style.as_node().descendant_text_content() == 'p{color:red}div{color:blue}'
	sheet := css.style_element_sheet(style) or { panic('pop did not install style sheet') }
	assert sheet.css_rules().length() == 2
	assert document.get_element_by_id('chosen')?.as_node().descendant_text_content() == 'Complete choice'
	assert parser.character_insertion_builder.len == 0
	assert parser.stack_of_open_elements.is_empty()
	assert document.readiness() == .complete
}

fn parser_stack_watch_pair(document &dom.Document, parser &HTMLParser) {
	$if gcboehm ? {
		C.vox_parser_stack_watch(0, voidptr(document))
		C.vox_parser_stack_watch(1, voidptr(parser))
	}
}

fn parser_stack_create_unretained_parser() {
	mut document := dom.Document.create(dom.url_about_blank())
	document.set_scripting_enabled_by_embedder(false)
	parser := HTMLParser.create_with_scripting_mode(document, '<!doctype html><p>unparsed</p>', .disabled)
	parser_stack_watch_pair(document, parser)
	document.finalize()
}

fn parser_stack_parse_unretained_discovery_document() {
	mut document := dom.Document.create(dom.URL{value: 'https://parser-lifetime.test/'})
	document.set_scripting_enabled_by_embedder(false)
	document.set_allow_declarative_shadow_roots(true)
	mut parser := HTMLParser.create_with_scripting_mode(document,
		'<!doctype html><html><head><base href="assets/"></head><body><section><p>Detached discovery</p><span class="retained">complete text</span></section></body></html>', .disabled)
	parser.run()
	assert document.readiness() == .complete
	assert document.get_browsing_context() == none
	assert document.base_url().serialize() == 'https://parser-lifetime.test/assets/'
	// Do not create live collections here: those own separate callback graphs.
	assert document.document_element() != none
	parser_stack_watch_pair(document, parser)
	document.finalize()
}

fn test_unretained_parser_callback_cycle_is_collectible() {
	$if gcboehm ? {
		C.vox_parser_stack_run_worker(parser_stack_create_unretained_parser)
		C.vox_parser_stack_collect(8)
		C.vox_parser_stack_collect(8)
		assert C.vox_parser_stack_owners_alive() == 0
	} $else {
		parser_stack_create_unretained_parser()
	}
}

fn test_completed_discovery_parser_and_document_are_collectible() {
	$if gcboehm ? {
		C.vox_parser_stack_run_worker(parser_stack_parse_unretained_discovery_document)
		C.vox_parser_stack_collect(8)
		C.vox_parser_stack_collect(8)
		assert C.vox_parser_stack_owners_alive() == 0
	} $else {
		parser_stack_parse_unretained_discovery_document()
	}
}

fn parser_stack_retain_only_callback_receiver() {
	mut document := dom.Document.create(dom.url_about_blank())
	parser := HTMLParser.create_with_scripting_mode(document, '', .disabled)
	// Empty elements storage has no DOM edge. Only the copied callback receiver
	// keeps this parser/document alive after this worker thread exits.
	parser_stack_retained_owner = &StackOfOpenElements{...parser.stack_of_open_elements}
	parser_stack_watch_pair(document, parser)
	document.finalize()
}

fn parser_stack_fire_retained_callback(owner voidptr) {
	mut parser := unsafe { &HTMLParser(owner) }
	text := parser.document().create_text_node('')
	parser.character_insertion_node = text
	parser.character_insertion_builder = [`o`, `k`]
	option := parser.document().create_element_ns(ns_html, 'option') or { panic(err) }
	parser_stack_retained_owner.push(option)
	parser_stack_retained_owner.pop()
	assert text.data() == 'ok'
	assert parser.character_insertion_builder.len == 0
}

fn parser_stack_drop_retained_callback() {
	parser_stack_retained_owner = unsafe { nil }
}

fn test_live_stack_traces_its_parser_context_and_releases_it_with_the_stack() {
	$if gcboehm ? {
		C.vox_parser_stack_run_worker(parser_stack_retain_only_callback_receiver)
		C.vox_parser_stack_collect(8)
		assert C.vox_parser_stack_owners_alive() == 3
		C.vox_parser_stack_run_with_parser(parser_stack_fire_retained_callback)
		C.vox_parser_stack_run_worker(parser_stack_drop_retained_callback)
		C.vox_parser_stack_collect(8)
		C.vox_parser_stack_collect(8)
		assert C.vox_parser_stack_owners_alive() == 0
	} $else {
		parser_stack_retain_only_callback_receiver()
		parser_stack_drop_retained_callback()
	}
}
