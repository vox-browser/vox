module html

import dom

fn trusted_types_test_document(markup string) &dom.Document {
	document := parse_document(markup)
	mut mutable_document := unsafe { &dom.Document(document) }
	mutable_document.enforce_meta_csp("require-trusted-types-for 'script'")
	return document
}

fn test_dom_html_mutation_sinks_use_translated_trusted_types_policy() {
	document := trusted_types_test_document('<!doctype html><div id="target"></div>')
	mut target := document.get_element_by_id('target') or { panic('missing target') }
	mut rejected := false
	target.set_inner_html('<script>unsafe()</script>') or {
		rejected = true
		assert err.msg().contains('requires a TrustedType')
	}
	assert rejected
	assert target.as_node().child_count() == 0

	mut allowed_document := parse_document('<!doctype html><div id="target"></div>')
	mut allowed_target := allowed_document.get_element_by_id('target') or { panic('missing target') }
	allowed_target.set_inner_html('<span id="inserted">safe without a policy</span>')!
	assert allowed_target.as_node().child_count() == 1
	assert allowed_target.inner_html()!.contains('safe without a policy')
}

fn test_dom_attribute_mutation_uses_translated_trusted_types_policy() {
	document := trusted_types_test_document('<!doctype html><button id="target"></button>')
	mut target := document.get_element_by_id('target') or { panic('missing target') }
	mut rejected := false
	target.set_attribute_for_bindings('onclick', 'unsafe()') or {
		rejected = true
		assert err.msg().contains('requires a TrustedType')
	}
	assert rejected
	assert !target.has_attribute('onclick')
}

fn test_range_contextual_fragment_uses_translated_trusted_types_policy() {
	document := trusted_types_test_document('<!doctype html><div id="target"></div>')
	target := document.get_element_by_id('target') or { panic('missing target') }
	mut range := document.create_range()
	range.select_node_contents(target.as_node())!
	mut rejected := false
	range.create_contextual_fragment('<script>unsafe()</script>') or {
		rejected = true
		assert err.msg().contains('requires a TrustedType')
		unsafe { nil }
	}
	assert rejected
}

fn test_dom_parser_uses_translated_trusted_types_policy() {
	document := trusted_types_test_document('<!doctype html>')
	parser := DOMParser.create(document)
	mut rejected := false
	parser.parse_from_string('<script>unsafe()</script>', .text_html) or {
		rejected = true
		assert err.msg().contains('requires a TrustedType')
		unsafe { nil }
	}
	assert rejected
}

fn test_document_parse_html_unsafe_uses_associated_document_realm() {
	mut associated := parse_document('<!doctype html>')
	associated.set_origin(dom.Origin{ value: 'https://example.test' })

	document := dom.Document.parse_html_unsafe(associated,
		'<main id="parsed"><template shadowrootmode="open"></template></main>')!
	assert document.get_content_type() == 'text/html'
	assert document.allow_declarative_shadow_roots
	assert document.origin() == associated.origin()
	assert document.get_element_by_id('parsed') != none

	protected := trusted_types_test_document('<!doctype html>')
	mut rejected := false
	dom.Document.parse_html_unsafe(protected, '<script>unsafe()</script>') or {
		rejected = true
		assert err.msg().contains('requires a TrustedType')
		unsafe { nil }
	}
	assert rejected
}

fn test_document_write_preserves_trusted_html_identity() {
	mut document := parse_document('<!doctype html>')
	document.enforce_meta_csp("require-trusted-types-for 'script'")
	document.open_document()!

	mut untrusted := []dom.TrustedHTMLOrString{}
	untrusted << dom.TrustedHTMLOrString('<main>rejected</main>')
	mut rejected := false
	document.write(untrusted) or {
		rejected = true
		assert err.msg().contains('requires a TrustedType')
	}
	assert rejected

	mut trusted := []dom.TrustedHTMLOrString{}
	trusted << dom.TrustedHTMLValue{
		data: '<main id="trusted">accepted</main>'
	}
	document.write(trusted)!
	document.close()!
	assert document.get_element_by_id('trusted') != none
}
