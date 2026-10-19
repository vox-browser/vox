// Copyright (c) 2026, Ladybird contributors
// SPDX-License-Identifier: BSD-2-Clause

// Translation of WebDriver/Capabilities.{h,cpp}.
module webdriver

import x.json2

pub enum PageLoadStrategy {
	none
	eager
	normal
}

pub enum InterfaceMode {
	graphical
	headless
}

pub struct EndpointCapabilities {
pub:
	browser_name    string = 'ladybird'
	browser_version string
	platform_name   string
	user_agent      string = 'Ladybird'
	interface_mode  InterfaceMode
	http_session    bool
}

fn validate_capability(name string, value json2.Any) !json2.Any {
	if value is json2.Null {
		return json2.null
	}
	match name {
		'acceptInsecureCerts', 'strictFileInteractability', 'webSocketUrl', 'ladybird:headless' {
			if value !is bool {
				return error(WebDriverError.from_code(.invalid_argument, 'Capability ${name} must be a boolean').msg())
			}
			return value as bool
		}
		'browserName', 'browserVersion', 'platformName' {
			if value !is string {
				return error(WebDriverError.from_code(.invalid_argument, 'Capability ${name} must be a string').msg())
			}
			return value as string
		}
		'pageLoadStrategy' {
			if value !is string || value as string !in ['none', 'eager', 'normal'] {
				return error(WebDriverError.from_code(.invalid_argument, 'Invalid pageLoadStrategy').msg())
			}
			return value as string
		}
		'proxy' {
			return deserialize_proxy(value)!
		}
		'timeouts' {
			return deserialize_timeouts(value)!.to_object()
		}
		'unhandledPromptBehavior' {
			handler := deserialize_unhandled_prompt_behavior(value)!
			return prompt_handler_map_to_internal_object(handler)
		}
		else {
			if !name.contains(':') {
				return error(WebDriverError.from_code(.invalid_argument, 'Unrecognized capability: ${name}').msg())
			}
			// Unknown extension capabilities are intentionally elided by Ladybird.
			if !name.starts_with('ladybird:') {
				return json2.null
			}
		}
	}
	return json2.null
}

fn validate_capabilities(value json2.Any) !map[string]json2.Any {
	if value !is map[string]json2.Any {
		return error(WebDriverError.from_code(.invalid_argument, 'Capability is not an Object').msg())
	}
	mut result := map[string]json2.Any{}
	object := value as map[string]json2.Any
	for name, item in object {
		if item is json2.Null {
			continue
		}
		match name {
			'acceptInsecureCerts', 'strictFileInteractability', 'webSocketUrl', 'ladybird:headless' {
				if item !is bool {
					return error(WebDriverError.from_code(.invalid_argument, 'Capability ${name} must be a boolean').msg())
				}
				result[name] = item as bool
			}
			'browserName', 'browserVersion', 'platformName', 'pageLoadStrategy' {
				if item !is string {
					return error(WebDriverError.from_code(.invalid_argument, 'Capability ${name} must be a string').msg())
				}
				if name == 'pageLoadStrategy' && item as string !in ['none', 'eager', 'normal'] {
					return error(WebDriverError.from_code(.invalid_argument, 'Invalid pageLoadStrategy').msg())
				}
				result[name] = (item as string).clone()
			}
			'proxy' {
				result[name] = deserialize_proxy(item)!
			}
			'timeouts' {
				result[name] = deserialize_timeouts(item)!.to_object()
			}
			'unhandledPromptBehavior' {
				result[name] = prompt_handler_map_to_internal_object(deserialize_unhandled_prompt_behavior(item)!)
			}
			else {
				if !name.contains(':') {
					return error(WebDriverError.from_code(.invalid_argument, 'Unrecognized capability: ${name}').msg())
				}
				if name.starts_with('ladybird:') {
					result[name] = item
				}
			}
		}
	}
	return result
}

fn merge_capabilities(primary map[string]json2.Any, secondary map[string]json2.Any) !map[string]json2.Any {
	mut result := map[string]json2.Any{}
	for name, value in primary {
		result[name] = value
	}
	for name, value in secondary {
		if name in primary {
			return error(WebDriverError.from_code(.invalid_argument, 'Unable to merge capability ${name}').msg())
		}
		result[name] = value
	}
	return result
}

fn string_matches(object map[string]json2.Any, key string, required string) bool {
	value := object[key] or { return true }
	if value !is string {
		return false
	}
	return (value as string) == required
}

fn platform_matches(requested string, actual string) bool {
	return requested == actual || (requested == 'mac' && actual == 'macos') || (requested == 'serenity' && actual == 'serenityos')
}

fn match_capabilities(requested map[string]json2.Any, endpoint EndpointCapabilities) CapabilitiesResult {
	if !string_matches(requested, 'browserName', endpoint.browser_name) || !string_matches(requested, 'browserVersion', endpoint.browser_version) {
		return CapabilitiesResult{}
	}
	if 'platformName' in requested {
		platform := requested['platformName'] or { return CapabilitiesResult{} }
		if platform !is string || !platform_matches(platform as string, endpoint.platform_name) {
			return CapabilitiesResult{}
		}
	}
	if 'acceptInsecureCerts' in requested {
		insecure := requested['acceptInsecureCerts'] or { return CapabilitiesResult{} }
		if insecure is bool {
			if insecure {
				return CapabilitiesResult{}
			}
		}
	}
	if 'proxy' in requested && has_proxy_configuration() {
		return CapabilitiesResult{}
	}
	if 'webSocketUrl' in requested {
		return CapabilitiesResult{}
	}
	if prompt_value := requested['unhandledPromptBehavior'] {
		requested_handler := prompt_handler_map_from_internal_object(prompt_value) or {
			return CapabilitiesResult{}
		}
		if !check_user_prompt_handler_matches(requested_handler) {
			return CapabilitiesResult{}
		}
	}
	mut matched := map[string]json2.Any{}
	matched['browserName'] = endpoint.browser_name
	matched['browserVersion'] = endpoint.browser_version
	matched['platformName'] = endpoint.platform_name
	matched['acceptInsecureCerts'] = false
	matched['setWindowRect'] = true
	matched['userAgent'] = endpoint.user_agent
	matched['ladybird:headless'] = endpoint.interface_mode == .headless
	if endpoint.http_session {
		matched['strictFileInteractability'] = false
	}
	for name, value in requested {
		if value !is json2.Null {
			matched[name] = value
		}
	}
	return CapabilitiesResult{
		matched: true
		capabilities: matched
	}
}

pub struct CapabilitiesResult {
pub:
	matched      bool
	capabilities map[string]json2.Any
}

pub fn process_capabilities(parameters json2.Any, endpoint EndpointCapabilities) !CapabilitiesResult {
	if parameters !is map[string]json2.Any {
		return error(WebDriverError.from_code(.invalid_argument, 'Session parameters is not an object').msg())
	}
	root := parameters as map[string]json2.Any
	capability_value := root['capabilities'] or {
		return error(WebDriverError.from_code(.invalid_argument, 'Capabilities is not an object').msg())
	}
	if capability_value !is map[string]json2.Any {
		return error(WebDriverError.from_code(.invalid_argument, 'Capabilities is not an object').msg())
	}
	capabilities_request := capability_value as map[string]json2.Any
	mut required := map[string]json2.Any{}
	if 'alwaysMatch' in capabilities_request {
		always := capabilities_request['alwaysMatch'] or { return error('missing alwaysMatch') }
		required = validate_capabilities(always)!
	}
	mut alternatives := []json2.Any{}
	alternatives << map[string]json2.Any{}
	if 'firstMatch' in capabilities_request {
		first := capabilities_request['firstMatch'] or { return error('missing firstMatch') }
		if first !is []json2.Any || (first as []json2.Any).len == 0 {
			return error(WebDriverError.from_code(.invalid_argument, 'Capability firstMatch must be an array with at least one entry').msg())
		}
		alternatives = first as []json2.Any
	}
	for alternative in alternatives {
		candidate := merge_capabilities(required, validate_capabilities(alternative)!)!
		matched := match_capabilities(candidate, endpoint)
		if matched.matched {
			return matched
		}
	}
	return CapabilitiesResult{}
}

pub struct LadybirdOptions {
pub:
	headless bool
}

pub fn LadybirdOptions.from_capabilities(capabilities map[string]json2.Any) LadybirdOptions {
	value := capabilities['ladybird:headless'] or { return LadybirdOptions{} }
	return LadybirdOptions{
		headless: value is bool && value
	}
}
