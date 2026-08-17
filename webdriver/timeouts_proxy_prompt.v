// Copyright (c) 2026, Ladybird contributors
// SPDX-License-Identifier: BSD-2-Clause

// Translation of TimeoutsConfiguration, Proxy, and UserPrompt.
module webdriver

import x.json2

pub const maximum_safe_integer = u64(9_007_199_254_740_991)

pub struct TimeoutsConfiguration {
pub mut:
	script_timeout        ?u64 = u64(30_000)
	page_load_timeout     ?u64 = u64(300_000)
	implicit_wait_timeout ?u64 = u64(0)
}

struct ParsedTimeout {
	is_null bool
	value   u64
}

fn timeout_number(value json2.Any) !ParsedTimeout {
	if value is json2.Null {
		return ParsedTimeout{
			is_null: true
		}
	}
	mut number := i64(-1)
	if value is i64 {
		number = value
	} else if value is f64 && (value as f64) == f64(i64(value as f64)) {
		number = i64(value as f64)
	}
	if number < 0 || u64(number) > maximum_safe_integer {
		return error(WebDriverError.from_code(.invalid_argument, 'Invalid timeout value').msg())
	}
	return ParsedTimeout{
		value: u64(number)
	}
}

pub fn deserialize_timeouts(value json2.Any) !TimeoutsConfiguration {
	mut configuration := TimeoutsConfiguration{}
	deserialize_timeouts_into(value, mut configuration)!
	return configuration
}

pub fn deserialize_timeouts_into(value json2.Any, mut configuration TimeoutsConfiguration) ! {
	if value !is map[string]json2.Any {
		return error(WebDriverError.from_code(.invalid_argument, 'Payload is not a JSON object').msg())
	}
	for key, item in value as map[string]json2.Any {
		parsed := timeout_number(item) or {
			if key in ['script', 'pageLoad', 'implicit'] { return err }
			continue
		}
		optional := if parsed.is_null { ?u64(none) } else { ?u64(parsed.value) }
		match key {
			'script' { configuration.script_timeout = optional }
			'pageLoad' { configuration.page_load_timeout = optional }
			'implicit' { configuration.implicit_wait_timeout = optional }
			else {}
		}
	}
}

pub fn (configuration TimeoutsConfiguration) to_object() map[string]json2.Any {
	mut object := map[string]json2.Any{}
	object['script'] = if value := configuration.script_timeout { i64(value) } else { json2.null }
	object['pageLoad'] = if value := configuration.page_load_timeout {
		i64(value)
	} else {
		json2.null
	}
	object['implicit'] = if value := configuration.implicit_wait_timeout {
		i64(value)
	} else {
		json2.null
	}
	return object
}

fn url_has_scheme(value string, expected ?string) bool {
	colon := value.index(':') or { return false }
	if colon == 0 {
		return false
	}
	if !value[0].is_letter() {
		return false
	}
	for byte in value[..colon].bytes() {
		if !(byte.is_alnum() || byte in [`+`, `-`, `.`]) {
			return false
		}
	}
	if scheme := expected {
		return value[..colon].to_lower() == scheme
	}
	return true
}

pub fn deserialize_proxy(value json2.Any) !map[string]json2.Any {
	if value !is map[string]json2.Any {
		return error(WebDriverError.from_code(.invalid_argument,
			'Capability proxy must be an object').msg())
	}
	object := value as map[string]json2.Any
	for key, item in object {
		match key {
			'proxyType' {
				if item !is string
					|| item as string !in ['pac', 'direct', 'autodetect', 'system', 'manual'] {
					return error(WebDriverError.from_code(.invalid_argument,
						"Invalid 'proxyType' value").msg())
				}
			}
			'proxyAutoconfigUrl', 'socksProxy' {
				if item !is string || !url_has_scheme(item as string, none) {
					return error(WebDriverError.from_code(.invalid_argument,
						"Proxy configuration item '${key}' must be a valid URL").msg())
				}
			}
			'ftpProxy', 'httpProxy', 'sslProxy' {
				scheme := if key == 'ftpProxy' {
					'ftp'
				} else if key == 'httpProxy' {
					'http'
				} else {
					'https'
				}
				if item !is string || !url_has_scheme(item as string, scheme) {
					return error(WebDriverError.from_code(.invalid_argument,
						"Proxy configuration item '${key}' has the wrong URL scheme").msg())
				}
			}
			'noProxy' {
				if item !is []json2.Any {
					return error(WebDriverError.from_code(.invalid_argument,
						"Proxy configuration item 'noProxy' must be a list").msg())
				}
				for entry in item as []json2.Any {
					if entry !is string {
						return error(WebDriverError.from_code(.invalid_argument,
							"Proxy configuration item 'noProxy' must be a list of strings").msg())
					}
				}
			}
			'socksVersion' {
				mut number := i64(-1)
				if item is i64 {
					number = item
				} else if item is f64 && (item as f64) == f64(i64(item as f64)) {
					number = i64(item as f64)
				}
				if number < 0 || number > 255 {
					return error(WebDriverError.from_code(.invalid_argument,
						"Proxy configuration item 'socksVersion' must be an integer in the range [0, 255]").msg())
				}
			}
			else {
				return error(WebDriverError.from_code(.invalid_argument,
					'Invalid proxy configuration item').msg())
			}
		}
	}
	return object.clone()
}

pub enum PromptHandler {
	dismiss
	accept
	ignore
}
pub enum PromptType {
	alert
	before_unload
	confirm
	default_
	file
	prompt
	fallback_default
}

pub struct PromptHandlerConfiguration {
pub:
	handler PromptHandler
	notify  bool
}

pub struct UserPromptState {
pub mut:
	handler ?map[PromptType]PromptHandlerConfiguration
}

pub fn (state UserPromptState) matches(requested map[PromptType]PromptHandlerConfiguration) bool {
	if current := state.handler {
		for type_, configuration in requested {
			if existing := current[type_] {
				if existing != configuration { return false }
			}
		}
	}
	return true
}

pub fn (mut state UserPromptState) update(requested map[PromptType]PromptHandlerConfiguration) {
	mut current := if actual := state.handler {
		actual.clone()
	} else {
		map[PromptType]PromptHandlerConfiguration{}
	}
	for type_, configuration in requested {
		current[type_] = configuration
	}
	state.handler = current.clone()
}

pub fn (state UserPromptState) serialize() json2.Any {
	return serialize_user_prompt_handler(state.handler)
}

pub struct ProxyState {
pub mut:
	has_configuration bool = true
}

pub fn (mut state ProxyState) reset() {
	state.has_configuration = true
}

pub fn (configuration PromptHandlerConfiguration) serialize() string {
	return match configuration.handler {
		.dismiss {
			if configuration.notify {
				'dismiss and notify'
			} else {
				'dismiss'
			}
		}
		.accept {
			if configuration.notify {
				'accept and notify'
			} else {
				'accept'
			}
		}
		.ignore {
			'ignore'
		}
	}
}

pub fn parse_prompt_configuration(value string) !PromptHandlerConfiguration {
	return match value {
		'dismiss' {
			PromptHandlerConfiguration{
				handler: .dismiss
			}
		}
		'accept' {
			PromptHandlerConfiguration{
				handler: .accept
			}
		}
		'dismiss and notify' {
			PromptHandlerConfiguration{
				handler: .dismiss
				notify:  true
			}
		}
		'accept and notify' {
			PromptHandlerConfiguration{
				handler: .accept
				notify:  true
			}
		}
		'ignore' {
			PromptHandlerConfiguration{
				handler: .ignore
				notify:  true
			}
		}
		else {
			error(WebDriverError.from_code(.invalid_argument,
				"'${value}' is not a known prompt handler").msg())
		}
	}
}

fn prompt_type_from_name(name string) !PromptType {
	return match name {
		'alert' {
			.alert
		}
		'beforeUnload' {
			.before_unload
		}
		'confirm' {
			.confirm
		}
		'default' {
			.default_
		}
		'file' {
			.file
		}
		'prompt' {
			.prompt
		}
		'fallbackDefault' {
			.fallback_default
		}
		else {
			error(WebDriverError.from_code(.invalid_argument,
				"'${name}' is not a valid prompt type").msg())
		}
	}
}

pub fn deserialize_unhandled_prompt_behavior(value json2.Any) !map[PromptType]PromptHandlerConfiguration {
	is_string_value := value is string
	mut object := map[string]json2.Any{}
	if is_string_value {
		object['fallbackDefault'] = value
	} else if value is map[string]json2.Any {
		object = value.clone()
	} else {
		return error(WebDriverError.from_code(.invalid_argument,
			'Capability unhandledPromptBehavior must be a string or object').msg())
	}
	mut result := map[PromptType]PromptHandlerConfiguration{}
	for name, item in object {
		if !is_string_value && name == 'fallbackDefault' {
			return error(WebDriverError.from_code(.invalid_argument,
				"'fallbackDefault' is not a valid prompt type").msg())
		}
		type_ := prompt_type_from_name(name)!
		if item !is string {
			return error(WebDriverError.from_code(.invalid_argument,
				'Prompt handler must be a string').msg())
		}
		result[type_] = parse_prompt_configuration(item as string)!
	}
	return result
}

pub fn serialize_user_prompt_handler(handler ?map[PromptType]PromptHandlerConfiguration) json2.Any {
	if actual := handler {
		if actual.len == 1 && PromptType.fallback_default in actual {
			return actual[PromptType.fallback_default].serialize()
		}
		mut object := map[string]json2.Any{}
		for type_, configuration in actual {
			name := match type_ {
				.alert { 'alert' }
				.before_unload { 'beforeUnload' }
				.confirm { 'confirm' }
				.default_ { 'default' }
				.file { 'file' }
				.prompt { 'prompt' }
				.fallback_default { 'fallbackDefault' }
			}
			object[name] = configuration.serialize()
		}
		return object
	}
	return 'dismiss and notify'
}
