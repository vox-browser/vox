module html

import dom

struct XMLLifecycleObservation {
mut:
	events []string
}

fn test_xml_document_builds_namespaces_character_data_and_readiness() {
	source := '<?xml version="1.0"?><root xmlns="urn:root" xmlns:x="urn:x"><x:item a="1">A &amp; B<![CDATA[<c>]]></x:item><!--tail--></root>'
	mut document := dom.Document.create(dom.URL{ value: 'https://example.test/data.xml' })
	defer { document.finalize() }
	parse_xml_document(document, source)!
	assert document.get_source() == source
	assert document.document_type() == .xml
	assert document.readiness() == .complete
	root := document.document_element() or { panic('missing root') }
	assert root.namespace_uri()? == 'urn:root'
	item := (root.as_node().first_child() or { panic('missing item') }).as_element() or {
		panic('not an element')
	}
	assert item.namespace_uri()? == 'urn:x'
	assert item.get_attribute('a')? == '1'
	assert item.as_node().text_content()? == 'A & B<c>'
}

fn test_xml_document_rejects_malformed_xml_without_completing_loading() {
	mut document := dom.Document.create(dom.url_about_blank())
	defer { document.finalize() }
	parse_xml_document(document, '<a><b></a>') or {
		assert document.document_type() == .xml
		assert document.readiness() == .loading
		return
	}
	assert false
}

fn test_xml_document_preserves_utf8_and_decodes_full_named_entity_table() {
	mut document := dom.Document.create(dom.url_about_blank())
	defer { document.finalize() }
	parse_xml_document(document, '<root>Привет &AElig; &NotEqualTilde;</root>')!
	root := document.document_element() or { panic('missing root') }
	assert root.as_node().text_content()? == 'Привет Æ ≂̸'
}

fn test_xml_document_creates_doctype_external_identifiers() {
	mut document := dom.Document.create(dom.url_about_blank())
	defer { document.finalize() }
	parse_xml_document(document, '<?xml version="1.0"?><!DOCTYPE root PUBLIC "-//TEST//DTD Root//EN" "root.dtd"><root/>')!
	doctype := document.doctype() or { panic('missing doctype') }
	assert doctype.name() == 'root'
	assert doctype.public_id() == '-//TEST//DTD Root//EN'
	assert doctype.system_id() == 'root.dtd'
}

fn test_xml_document_preserves_character_data_and_processing_instruction_nodes() {
	mut document := dom.Document.create(dom.url_about_blank())
	defer { document.finalize() }
	parse_xml_document(document, '<root xmlns="urn:root" xmlns:x="urn:item"><x:item xml:lang="en">hello world<![CDATA[<raw>]]></x:item><!--tail--><?work data?></root>')!
	root := document.document_element() or { panic('missing root') }
	assert root.namespace_uri()? == 'urn:root'
	children := root.as_node().children_as_vector()
	assert children.len == 3
	item := children[0].as_element() or { panic('missing item') }
	assert item.namespace_uri()? == 'urn:item'
	assert item.get_attribute_ns('http://www.w3.org/XML/1998/namespace', 'lang')? == 'en'
	assert item.as_node().text_content()? == 'hello world<raw>'
	assert children[1].is_comment()
	assert children[2].as_processing_instruction()?.target() == 'work'
	assert children[2].as_processing_instruction()?.data() == 'data'
}

fn test_xml_document_queues_browsing_context_lifecycle_events() {
	mut document := dom.Document.create(dom.URL{ value: 'https://example.test/data.xml' })
	defer {
		document.destroy()
		document.finalize()
	}
	window := WindowModel.create_top_level(document, none, 'xml-lifecycle')!
	document.set_load_timing_info(dom.DocumentLoadTimingInfo{
		load_event_start_time: -1
		load_event_end_time: -1
	})
	observation := &XMLLifecycleObservation{}
	listener := dom.IDLEventListener.create(&dom.CallbackType{
		handle_event: fn [observation, document] (event &dom.Event, _ ?&dom.EventTarget) dom.JSValue {
			mut mutable_observation := unsafe { &XMLLifecycleObservation(observation) }
			mutable_observation.events << event.type_name()
			timing := document.document_load_timing_info()
			if event.type_name() == 'load' {
				assert timing.load_event_start_time >= 0
				assert timing.load_event_end_time == -1
			} else if event.type_name() == 'pageshow' {
				assert timing.load_event_end_time >= timing.load_event_start_time
				assert document.document_page_showing()
			}
			return dom.js_undefined()
		}
	})
	document_target := unsafe { &dom.EventTarget(document) }
	document_target.add_event_listener_without_options('DOMContentLoaded', listener)
	window.this_impl().add_event_listener_without_options('load', listener)
	window.this_impl().add_event_listener_without_options('pageshow', listener)

	parse_xml_document(document, '<root/>')!
	assert document.readiness() == .interactive
	assert !document.document_ready_for_post_load_tasks()
	assert observation.events.len == 0
	// A second readiness notification must share the pending completion.
	finish_xml_document_parsing(document)

	mut event_loop := main_thread_event_loop()
	for _ in 0 .. 10 {
		if document.readiness() == .complete { break }
		event_loop.process()
	}
	assert document.readiness() == .complete
	assert observation.events == ['DOMContentLoaded', 'load', 'pageshow']
	assert document.document_ready_for_post_load_tasks()
	assert document.is_completely_loaded()
}
