module webdriver

import x.json2

fn test_capabilities_validation_merge_and_matching() {
	payload := json_value_from_text('{"capabilities":{"alwaysMatch":{"browserName":"ladybird","pageLoadStrategy":"normal"},"firstMatch":[{"platformName":"mac"}]}}')
	endpoint := EndpointCapabilities{
		browser_version: '1'
		platform_name: 'macos'
		http_session: true
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

fn test_upstream_capability_and_window_projection_details() {
	mut options := {
		'ladybird:headless': json2.Any(true)
	}
	set_default_interface_mode(.graphical)
	set_default_ladybird_capabilities(mut options)
	assert (options['ladybird:headless'] or { panic('headless missing') }) as bool == false
	unknown_extension := deserialize_as_ladybird_capability('ladybird:future', json2.Any('retained'))
	assert !unknown_extension.is_error()
	assert unknown_extension.value as string == 'retained'
	// Current upstream represents_a_web_frame() checks the window key.
	assert represents_a_web_frame(json2.Any(window_reference_object('window')))
	assert !represents_a_web_frame(json2.Any(frame_reference_object('frame')))
	assert represents_web_element(json_value_from_text('{"element-6066-11e4-a52e-4f735466cecf":null}'))
	assert represents_shadow_root(json_value_from_text('{"shadow-6066-11e4-a52e-4f735466cecf":false}'))
	deserialize_web_window(json_value_from_text('{"window-fcc6-11e5-b4f8-330a88ab9d7f":7}'), []) or {
		assert err.msg().contains('invalid argument')
	}
	assert !is_collection(json2.Any(map[string]json2.Any{}))
	assert is_collection(json2.Any([]json2.Any{}))

	context := BrowsingContext{ handle: 'state-window' }
	mut first_state := get_input_state(context)
	first_state.actions_queue << 'token'
	assert get_input_state(context).actions_queue == ['token']
	reset_input_state(context)
	assert get_input_state(context).actions_queue.len == 0

	mut pointer_state := InputState{}
	pointer_state.input_state_map['mouse'] = InputSource{
		type_: .pointer
		pointer_subtype: .mouse
		pointer_id: 0
	}
	assert get_pointer_id(pointer_state, .mouse) == 1
	assert get_pointer_id(pointer_state, .pen) == 2
}

fn test_reference_store_staleness_and_shadow_identity() {
	context := BrowsingContext{
		handle: 'window'
		group_id: 'group'
		document_id: 'doc'
		viewport: Rect{
			width: 100
			height: 100
		}
	}
	mut store := ReferenceStore{}
	element := ElementRecord{
		node_id: 'node'
		document_id: 'doc'
		tag_name: 'button'
		focusable: true
		rect: Rect{
			x: 90
			y: 90
			width: 30
			height: 30
		}
	}
	reference := store.element_reference(context, element)
	assert store.element_reference(context, element) == reference
	known := get_known_element(store, context, reference) or { panic(err) }
	assert known.node_id == 'node'
	x, y := in_view_center_point(element.rect, context.viewport)
	assert x == 95 && y == 95
	assert is_element_pointer_interactable(element, context)
	get_known_element(store, BrowsingContext{
		handle: context.handle
		group_id: context.group_id
		document_id: 'other'
	}, reference) or {
		assert err.msg().contains('stale')
		return
	}
	assert false
}

fn test_location_strategies_match_rendered_link_text_and_css() {
	elements := [
		ElementRecord{
			node_id: '1'
			tag_name: 'a'
			text: '  Ladybird '
			attributes: {
				'class': 'nav hero'
			}
		},
		ElementRecord{
			node_id: '2'
			tag_name: 'button'
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
	set_user_prompt_handler(prompt_handler)
	assert !match_capabilities(requested, EndpointCapabilities{}).matched
	set_user_prompt_handler(map[PromptType]PromptHandlerConfiguration{})
}

fn test_capability_matching_uses_the_endpoint_proxy_configuration_flag() {
	requested := validate_capabilities(json_value_from_text('{"proxy":{"proxyType":"direct"}}')) or {
		panic(err)
	}
	reset_has_proxy_configuration()
	assert !match_capabilities(requested, EndpointCapabilities{}).matched
	set_has_proxy_configuration(false)
	assert match_capabilities(requested, EndpointCapabilities{}).matched
	reset_has_proxy_configuration()
}

fn test_node_references_are_scoped_by_group_and_seen_navigable() {
	context := BrowsingContext{
		handle: 'window-a'
		group_id: 'group-a'
		document_id: 'doc-a'
	}
	element := ElementRecord{
		node_id: 'node-a'
		document_id: 'doc-a'
	}
	mut store := ReferenceStore{}
	reference := get_or_create_a_node_reference(mut store, context, element)
	assert node_reference_is_known(store, context, reference)
	assert get_node(store, context, reference) != none
	assert !node_reference_is_known(store, BrowsingContext{
		handle: 'window-b'
		group_id: 'group-a'
		document_id: 'doc-b'
	}, reference)
	assert get_node(store, BrowsingContext{
		handle: 'window-a'
		group_id: 'group-b'
		document_id: 'doc-a'
	}, reference) == none
}

fn test_pointer_interactable_tree_uses_target_center_and_paint_order() {
	context := BrowsingContext{
		document_id: 'doc'
		viewport: Rect{ width: 100, height: 100 }
	}
	target := ElementRecord{
		node_id: 'target'
		document_id: 'doc'
		rect: Rect{ x: 10, y: 10, width: 20, height: 20 }
	}
	cover := ElementRecord{
		node_id: 'cover'
		document_id: 'doc'
		rect: Rect{ x: 15, y: 15, width: 10, height: 10 }
	}
	outside := ElementRecord{
		node_id: 'outside'
		document_id: 'doc'
		rect: Rect{ x: 80, y: 80, width: 10, height: 10 }
	}
	tree := pointer_interactable_tree([cover, target, outside], context, target)
	assert tree.map(it.node_id) == ['cover', 'target']
}

fn test_center_point_handles_negative_dimensions_and_floors() {
	x, y := in_view_center_point(Rect{ x: 10, y: 20, width: -5, height: -7 }, Rect{
		width: 100
		height: 100
	})
	assert x == 7
	assert y == 16
}

fn test_editable_and_non_typeable_form_control_classification() {
	assert is_element_editable(ElementRecord{ tag_name: 'input', input_type: 'email' })
	assert !is_element_editable(ElementRecord{
		tag_name: 'input'
		input_type: 'email'
		read_only: true
	})
	assert is_element_editable(ElementRecord{ tag_name: 'div', content_editable: true })
	assert is_element_non_typeable_form_control(ElementRecord{
		tag_name: 'input'
		input_type: 'checkbox'
	})
}
