module html

import dom

fn test_cors_setting_attribute() {
	assert cors_setting_attribute_from_keyword(none) == .no_cors
	assert cors_setting_attribute_from_keyword('USE-CREDENTIALS') == .use_credentials
	assert cors_setting_attribute_from_keyword('invalid') == .anonymous
	assert cors_settings_attribute_credentials_mode(.anonymous) == .same_origin
	assert cors_settings_attribute_credentials_mode(.use_credentials) == .include
}

fn test_valid_custom_element_name() {
	assert is_valid_custom_element_name('x-widget')
	assert is_valid_custom_element_name('é-widget') == false
	assert !is_valid_custom_element_name('Widget-name')
	assert !is_valid_custom_element_name('widget')
	assert !is_valid_custom_element_name('annotation-xml')
}

fn test_time_ranges() {
	mut ranges := TimeRanges{}
	ranges.add_range(1.5, 3.0)
	ranges.add_range(5.0, 8.0)
	assert ranges.length() == 2
	assert ranges.start(0)! == 1.5
	assert ranges.end(1)! == 8.0
	assert ranges.in_range(3.0)
	assert !ranges.in_range(4.0)
	if _ := ranges.start(2) {
		assert false
	} else {
		assert err.msg().starts_with('Index argument')
	}
}

fn test_dom_string_list() {
	list := DOMStringList.create(['one', 'two'])
	assert list.length() == 2
	assert list.item(0)? == 'one'
	assert list.item(2) == none
	assert list.contains('two')
	assert !list.contains('three')
}

fn test_parse_a_sandboxing_directive() {
	flags := parse_a_sandboxing_directive('allow-scripts allow-forms ALLOW-SAME-ORIGIN')
	assert flags.contains(.sandboxed_navigation)
	assert !flags.contains(.sandboxed_scripts)
	assert !flags.contains(.sandboxed_automatic_features)
	assert !flags.contains(.sandboxed_forms)
	assert !flags.contains(.sandboxed_origin)
	assert flags.contains(.sandboxed_document_domain)

	preparsed := parse_a_sandboxing_directive(SandboxingDirective(['ALLOW-POPUPS']))
	assert !preparsed.contains(.sandboxed_auxiliary_navigation)
	assert !preparsed.contains(.sandboxed_custom_protocols)
}

fn test_file_filter_deduplicates_filters() {
	mut filter := FileFilter{}
	filter.add_filter(FileFilterFileType.image)
	filter.add_filter(FileFilterFileType.image)
	filter.add_filter(FileFilterMimeType{'image/png'})
	filter.add_filter(FileFilterMimeType{'image/png'})
	filter.add_filter(FileFilterExtension{'.png'})
	assert filter.filters.len == 3
}

fn test_embedder_policy_value_conversion() {
	assert EmbedderPolicyValue.unsafe_none.to_string() == 'unsafe-none'
	assert EmbedderPolicyValue.require_corp.to_string() == 'require-corp'
	assert embedder_policy_value_from_string('CredentialLess')? == .credentialless
	assert embedder_policy_value_from_string('invalid') == none
	policy := EmbedderPolicy{}
	assert policy.value == .unsafe_none
	assert policy.report_only_value == .unsafe_none
}

fn test_create_potential_cors_request() {
	anonymous := create_potential_cors_request(dom.URL{ value: 'https://example.com/image.png' },
		RequestDestination.image, .anonymous, .no)
	assert anonymous.mode == .cors
	assert anonymous.credentials_mode == .same_origin
	assert anonymous.destination? == .image
	assert anonymous.use_url_credentials

	fallback := create_potential_cors_request(dom.URL{ value: 'https://example.com/style.css' },
		RequestDestination.style, .no_cors, .yes)
	assert fallback.mode == .same_origin
	assert fallback.credentials_mode == .include
}

fn test_drag_data_store_has_text_item() {
	mut store := DragDataStore{}
	assert store.mode == .protected
	assert store.allowed_effects_state == 'uninitialized'
	store.add_item(DragDataStoreItem{ kind: .file, type_string: 'text/plain' })
	store.add_item(DragDataStoreItem{ kind: .text, type_string: 'text/html' })
	assert !store.has_text_item()
	store.add_item(DragDataStoreItem{ kind: .text, type_string: 'text/plain' })
	assert store.has_text_item()
	assert store.size() == 3
	store.remove_item_at(0)
	assert store.size() == 2
}

fn test_web_view_hints_from_tokenised_features() {
	features := tokenize_open_features('popup,left=-20,top=50,width=20,height=900')
	hints := WebViewHints.from_tokenised_features(features, WebExposedScreenArea{
		x:      0
		y:      0
		width:  800
		height: 600
	}, 2.0)
	assert hints.popup
	assert hints.screen_x? == -10.0
	assert hints.screen_y? == 0.0
	assert hints.width? == 50.0
	assert hints.height? == 300.0

	invalid := WebViewHints.from_tokenised_features(tokenize_open_features('left=nope,width=nope'), WebExposedScreenArea{
		width:  800
		height: 600
	}, 1.0)
	assert invalid.screen_x? == 0.0
	assert invalid.width? == 0.0
}
