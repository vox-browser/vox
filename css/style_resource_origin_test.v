module css

import dom

fn test_style_resource_fetch_retains_the_opaque_file_origin_object() {
	mut document := dom.Document.create(dom.URL{ value: 'file:///tmp/owner.html' })
	origin := dom.origin_create_opaque_file()
	document.set_origin(origin)
	environment := CSSFetchEnvironmentSettings.from_document(document)
	context := RuleOrDeclaration{
		value:                       RuleOrDeclarationRule{}
		environment_settings_object: environment
	}
	request := fetch_a_style_resource_impl('font.ttf', context, .font, .cors) or {
		panic('missing CSS font request')
	}
	font_request := css_request_to_fetch_request(request)
	font_origin := font_request.origin.origin or { panic('missing origin') }
	assert font_origin.is_opaque_file_origin()
	assert font_origin.is_same_origin(origin)
	assert font_origin.serialize() == 'null'
}

fn test_style_resource_fetch_preserves_typed_origin_for_data_documents() {
	mut document := dom.Document.create(dom.URL{ value: 'data:text/html,fixture' })
	origin := dom.origin_create_opaque()
	document.set_origin(origin)
	environment := CSSFetchEnvironmentSettings.from_document(document)
	context := RuleOrDeclaration{
		value:                       RuleOrDeclarationRule{}
		environment_settings_object: environment
	}
	request := fetch_a_style_resource_impl('https://example.test/font.ttf', context, .font, .cors) or {
		panic('missing CSS font request')
	}
	font_origin := css_request_to_fetch_request(request).origin.origin or {
		panic('missing origin')
	}
	assert font_origin.is_same_origin(origin)
	assert !font_origin.is_opaque_file_origin()
}
