// Copyright (c) 2025-2026, Ladybird contributors
// SPDX-License-Identifier: BSD-2-Clause

// Translation of LibURL/Pattern/Init.cpp.
module urlpattern

import url as liburl

enum PatternProcessType {
	pattern
	url
}

fn process_base_url_string(input string, type_ PatternProcessType) string {
	return if type_ == .pattern { escape_pattern_string(input) } else { input }
}

fn is_absolute_pattern_pathname(input string, type_ PatternProcessType) bool {
	if input == '' {
		return false
	}
	if input[0] == `/` {
		return true
	}
	if type_ == .url || input.len < 2 {
		return false
	}
	return input[0] in [`\\`, `{`] && input[1] == `/`
}

fn process_pattern_protocol(value string, type_ PatternProcessType) !string {
	stripped := if value.ends_with(':') { value[..value.len - 1] } else { value }
	return if type_ == .pattern { stripped } else { canonicalize_pattern_protocol(stripped)! }
}

fn process_pattern_hostname(value string, type_ PatternProcessType) !string {
	return if type_ == .pattern { value } else { canonicalize_pattern_hostname(value)! }
}

fn process_pattern_port(value string, protocol string, type_ PatternProcessType) !string {
	return if type_ == .pattern { value } else { canonicalize_pattern_port(value, protocol)! }
}

fn process_pattern_pathname(value string, protocol string, type_ PatternProcessType) !string {
	if type_ == .pattern {
		return value
	}
	if protocol == '' || liburl.is_special_scheme(protocol) {
		return canonicalize_pattern_pathname(value)!
	}
	return canonicalize_pattern_opaque_pathname(value)!
}

fn process_pattern_search(value string, type_ PatternProcessType) !string {
	stripped := if value.starts_with('?') { value[1..] } else { value }
	return if type_ == .pattern {
		stripped
	} else {
		canonicalize_pattern_component(stripped, .search)!
	}
}

fn process_pattern_hash(value string, type_ PatternProcessType) !string {
	stripped := if value.starts_with('#') { value[1..] } else { value }
	return if type_ == .pattern {
		stripped
	} else {
		canonicalize_pattern_component(stripped, .hash)!
	}
}

fn process_url_pattern_init(init PatternInitRecord, type_ PatternProcessType, protocol ?string, username ?string, password ?string, hostname ?string, port ?string, pathname ?string, search ?string, hash ?string) !PatternInitRecord {
	mut result := PatternInitRecord{
		protocol: protocol
		username: username
		password: password
		hostname: hostname
		port: port
		pathname: pathname
		search: search
		hash: hash
	}
	mut base_url := ?liburl.URL(none)
	if base_url_string := init.base_url {
		base_url = liburl.parse(base_url_string) or {
			return error('TypeError: invalid base URL `${base_url_string}` provided for URLPattern')
		}
		base := base_url or { return error('TypeError: invalid base URL') }
		if init.protocol == none {
			result.protocol = process_base_url_string(base.scheme, type_)
		}
		if type_ != .pattern && init.protocol == none && init.hostname == none && init.port == none && init.username == none {
			result.username = process_base_url_string(base.username, type_)
		}
		if type_ != .pattern && init.protocol == none && init.hostname == none && init.port == none && init.username == none && init.password == none {
			result.password = process_base_url_string(base.password, type_)
		}
		if init.protocol == none && init.hostname == none {
			base_host := if host_record := base.host { host_record.serialize() } else { '' }
			result.hostname = process_base_url_string(base_host, type_)
		}
		if init.protocol == none && init.hostname == none && init.port == none {
			result.port = if base_port := base.port { base_port.str() } else { '' }
		}
		if init.protocol == none && init.hostname == none && init.port == none && init.pathname == none {
			result.pathname = process_base_url_string(base.serialize_path(), type_)
		}
		if init.protocol == none && init.hostname == none && init.port == none && init.pathname == none && init.search == none {
			result.search = process_base_url_string(base.query or { '' }, type_)
		}
		if init.protocol == none && init.hostname == none && init.port == none && init.pathname == none && init.search == none && init.hash == none {
			result.hash = process_base_url_string(base.fragment or { '' }, type_)
		}
	}
	if value := init.protocol {
		result.protocol = process_pattern_protocol(value, type_)!
	}
	if value := init.username {
		result.username = if type_ == .pattern {
			value
		} else {
			canonicalize_pattern_component(value, .username)!
		}
	}
	if value := init.password {
		result.password = if type_ == .pattern {
			value
		} else {
			canonicalize_pattern_component(value, .password)!
		}
	}
	if value := init.hostname {
		result.hostname = process_pattern_hostname(value, type_)!
	}
	result_protocol := result.protocol or { '' }
	if value := init.port {
		result.port = process_pattern_port(value, result_protocol, type_)!
	}
	if value := init.pathname {
		mut result_pathname := value
		if base := base_url {
			if !base.has_an_opaque_path && !is_absolute_pattern_pathname(result_pathname, type_) {
				base_path := process_base_url_string(base.serialize_path(), type_)
				if slash := base_path.last_index('/') {
					result_pathname = base_path[..slash + 1] + result_pathname
				}
			}
		}
		result.pathname = process_pattern_pathname(result_pathname, result_protocol, type_)!
	}
	if value := init.search {
		result.search = process_pattern_search(value, type_)!
	}
	if value := init.hash {
		result.hash = process_pattern_hash(value, type_)!
	}
	return result
}
