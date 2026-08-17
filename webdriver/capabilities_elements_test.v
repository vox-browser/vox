module webdriver

import x.json2

fn test_capabilities_validation_merge_and_matching() {
	payload :=
		json_value_from_text('{"capabilities":{"alwaysMatch":{"browserName":"ladybird","pageLoadStrategy":"normal"},"firstMatch":[{"platformName":"mac"}]}}')
	endpoint := EndpointCapabilities{
		browser_version: '1'
		platform_name:   'macos'
		http_session:    true
	}
	assert endpoint.browser_name == 'ladybird'
	assert platform_matches('mac', 'macos')
	root := payload as map[string]json2.Any
	capability_value := root['capabilities'] or { panic('missing') }
	capability_object := capability_value as map[string]json2.Any
	required_value := capability_object['alwaysMatch'] or { panic('missing') }
	required := validate_capabilities(required_value) or { panic(err) }
	browser_value := required['browserName'] or { panic('missing') }
	assert browser_value is string
	assert browser_value as string == 'ladybird'
	result := process_capabilities(payload, endpoint) or { panic(err) }
	assert result.matched
	assert (result.capabilities['browserName'] or { panic('missing') }) as string == 'ladybird'
	assert (result.capabilities['strictFileInteractability'] or { panic('missing') }) as bool == false
	process_capabilities(json_value_from_text('{"capabilities":{"alwaysMatch":{"browserName":"ladybird"},"firstMatch":[{"browserName":"ladybird"}]}}'), EndpointCapabilities{}) or {
		assert err.msg().contains('Unable to merge')
		return
	}
	assert false
}

fn test_reference_store_staleness_and_shadow_identity() {
	context := BrowsingContext{
		handle:      'window'
		group_id:    'group'
		document_id: 'doc'
		viewport:    Rect{
			width:  100
			height: 100
		}
	}
	mut store := ReferenceStore{}
	element := ElementRecord{
		node_id:     'node'
		document_id: 'doc'
		tag_name:    'button'
		focusable:   true
		rect:        Rect{
			x:      90
			y:      90
			width:  30
			height: 30
		}
	}
	reference := store.element_reference(element)
	assert store.element_reference(element) == reference
	known := get_known_element(store, context, reference) or { panic(err) }
	assert known.node_id == 'node'
	x, y := in_view_center_point(element.rect, context.viewport)
	assert x == 95 && y == 95
	assert is_element_pointer_interactable(element, context)
	get_known_element(store, BrowsingContext{ document_id: 'other' }, reference) or {
		assert err.msg().contains('stale')
		return
	}
	assert false
}

fn test_location_strategies_match_rendered_link_text_and_css() {
	elements := [
		ElementRecord{
			node_id:    '1'
			tag_name:   'a'
			text:       '  Ladybird '
			attributes: {
				'class': 'nav hero'
			}
		},
		ElementRecord{
			node_id:    '2'
			tag_name:   'button'
			attributes: {
				'id': 'go'
			}
		},
	]
	assert (invoke_location_strategy(.link_text, elements, 'Ladybird') or { panic(err) }).len == 1
	assert (invoke_location_strategy(.partial_link_text, elements, 'bird') or { panic(err) }).len == 1
	assert (invoke_location_strategy(.css_selector, elements, '.hero') or { panic(err) }).len == 1
	invoke_location_strategy(.xpath, elements, '//a') or {
		assert err.msg().contains('Not implemented')
		return
	}
	assert false
}

fn test_capability_matching_respects_existing_prompt_configuration() {
	requested := validate_capabilities(json_value_from_text('{"unhandledPromptBehavior":{"alert":"dismiss"}}')) or {
		panic(err)
	}
	prompt_handler := {
		PromptType.alert: PromptHandlerConfiguration{
			handler: .accept
		}
	}
	endpoint := EndpointCapabilities{
		prompt_handler: prompt_handler
	}
	assert !match_capabilities(requested, endpoint).matched
}

fn test_center_point_handles_negative_dimensions_and_floors() {
	x, y := in_view_center_point(Rect{ x: 10, y: 20, width: -5, height: -7 }, Rect{
		width:  100
		height: 100
	})
	assert x == 7
	assert y == 16
}

fn test_editable_and_non_typeable_form_control_classification() {
	assert is_element_editable(ElementRecord{ tag_name: 'input', input_type: 'email' })
	assert !is_element_editable(ElementRecord{
		tag_name:   'input'
		input_type: 'email'
		read_only:  true
	})
	assert is_element_editable(ElementRecord{ tag_name: 'div', content_editable: true })
	assert is_element_non_typeable_form_control(ElementRecord{
		tag_name:   'input'
		input_type: 'checkbox'
	})
}
