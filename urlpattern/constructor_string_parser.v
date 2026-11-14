// Copyright (c) 2025-2026, Ladybird contributors
// SPDX-License-Identifier: BSD-2-Clause

// Translation of LibURL/Pattern/ConstructorStringParser.cpp.
module urlpattern

struct PatternInitRecord {
mut:
	protocol ?string
	username ?string
	password ?string
	hostname ?string
	port     ?string
	pathname ?string
	search   ?string
	hash     ?string
	base_url ?string
}

enum ConstructorParserState {
	initial
	protocol
	authority
	username
	password
	hostname
	port
	pathname
	search
	hash
	done
}

struct ConstructorStringParser {
	input      []rune
	token_list []PatternToken
mut:
	result                          PatternInitRecord
	component_start                 int
	token_index                     int
	token_increment                 int = 1
	group_depth                     int
	hostname_ipv6_bracket_depth     int
	protocol_matches_special_scheme bool
	state                           ConstructorParserState
}

fn parse_constructor_string(input string) !PatternInitRecord {
	mut parser := ConstructorStringParser{
		input: input.runes()
		token_list: tokenize_pattern(input, .lenient)!
	}
	for parser.token_index < parser.token_list.len {
		parser.token_increment = 1
		if parser.token_list[parser.token_index].type_ == .end {
			if parser.state == .initial {
				parser.rewind()
				if parser.is_hash_prefix() {
					parser.change_state(.hash, 1)
				} else if parser.is_search_prefix() {
					parser.change_state(.search, 1)
				} else {
					parser.change_state(.pathname, 0)
				}
				parser.token_index += parser.token_increment
				continue
			}
			if parser.state == .authority {
				parser.rewind_and_set_state(.hostname)
				parser.token_index += parser.token_increment
				continue
			}
			parser.change_state(.done, 0)
			break
		}
		if parser.is_group_open() {
			parser.group_depth++
			parser.token_index += parser.token_increment
			continue
		}
		if parser.group_depth > 0 {
			if parser.is_group_close() {
				parser.group_depth--
			} else {
				parser.token_index += parser.token_increment
				continue
			}
		}
		match parser.state {
			.initial {
				if parser.is_protocol_suffix() {
					parser.rewind_and_set_state(.protocol)
				}
			}
			.protocol {
				if parser.is_protocol_suffix() {
					parser.compute_protocol_matches_special_scheme()!
					mut next_state := ConstructorParserState.pathname
					mut skip := 1
					if parser.next_is_authority_slashes() {
						next_state = .authority
						skip = 3
					} else if parser.protocol_matches_special_scheme {
						next_state = .authority
					}
					parser.change_state(next_state, skip)
				}
			}
			.authority {
				if parser.is_identity_terminator() {
					parser.rewind_and_set_state(.username)
				} else if parser.is_pathname_start() || parser.is_search_prefix() || parser.is_hash_prefix() {
					parser.rewind_and_set_state(.hostname)
				}
			}
			.username {
				if parser.is_password_prefix() {
					parser.change_state(.password, 1)
				} else if parser.is_identity_terminator() {
					parser.change_state(.hostname, 1)
				}
			}
			.password {
				if parser.is_identity_terminator() {
					parser.change_state(.hostname, 1)
				}
			}
			.hostname {
				if parser.is_ipv6_open() {
					parser.hostname_ipv6_bracket_depth++
				} else if parser.is_ipv6_close() {
					parser.hostname_ipv6_bracket_depth--
				} else if parser.is_port_prefix() && parser.hostname_ipv6_bracket_depth == 0 {
					parser.change_state(.port, 1)
				} else if parser.is_pathname_start() {
					parser.change_state(.pathname, 0)
				} else if parser.is_search_prefix() {
					parser.change_state(.search, 1)
				} else if parser.is_hash_prefix() {
					parser.change_state(.hash, 1)
				}
			}
			.port {
				if parser.is_pathname_start() {
					parser.change_state(.pathname, 0)
				} else if parser.is_search_prefix() {
					parser.change_state(.search, 1)
				} else if parser.is_hash_prefix() {
					parser.change_state(.hash, 1)
				}
			}
			.pathname {
				if parser.is_search_prefix() {
					parser.change_state(.search, 1)
				} else if parser.is_hash_prefix() {
					parser.change_state(.hash, 1)
				}
			}
			.search {
				if parser.is_hash_prefix() {
					parser.change_state(.hash, 1)
				}
			}
			.hash {}
			.done {}
		}
		parser.token_index += parser.token_increment
	}
	if parser.result.hostname != none && parser.result.port == none {
		parser.result.port = ''
	}
	return parser.result
}

fn (parser &ConstructorStringParser) make_component_string() string {
	token := parser.token_list[parser.token_index]
	component_start_token := parser.safe_token(parser.component_start)
	return parser.input[component_start_token.index..token.index].string()
}

fn (mut parser ConstructorStringParser) compute_protocol_matches_special_scheme() ! {
	component := compile_pattern_component(parser.make_component_string(), .protocol, default_pattern_options())!
	if protocol_component_matches_special_scheme(&component) {
		parser.protocol_matches_special_scheme = true
	}
}

fn (mut parser ConstructorStringParser) set_result_for_active_state(value string) {
	match parser.state {
		.protocol {
			parser.result.protocol = value
		}
		.username {
			parser.result.username = value
		}
		.password {
			parser.result.password = value
		}
		.hostname {
			parser.result.hostname = value
		}
		.port {
			parser.result.port = value
		}
		.pathname {
			parser.result.pathname = value
		}
		.search {
			parser.result.search = value
		}
		.hash {
			parser.result.hash = value
		}
		else {}
	}
}

fn constructor_state_in(state ConstructorParserState, values []ConstructorParserState) bool {
	return state in values
}

fn (mut parser ConstructorStringParser) change_state(new_state ConstructorParserState, skip int) {
	if parser.state !in [.initial, .authority, .done] {
		parser.set_result_for_active_state(parser.make_component_string())
	}
	if parser.state != .initial && new_state != .done {
		if constructor_state_in(parser.state, [.protocol, .authority, .username, .password]) && constructor_state_in(new_state, [
			.port,
			.pathname,
			.search,
			.hash,
		]) && parser.result.hostname == none {
			parser.result.hostname = ''
		}
		if constructor_state_in(parser.state, [.protocol, .authority, .username, .password, .hostname,
			.port]) && new_state in [.search, .hash] && parser.result.pathname == none {
			parser.result.pathname = if parser.protocol_matches_special_scheme { '/' } else { '' }
		}
		if constructor_state_in(parser.state, [.protocol, .authority, .username, .password, .hostname,
			.port, .pathname]) && new_state == .hash && parser.result.search == none {
			parser.result.search = ''
		}
	}
	parser.state = new_state
	parser.token_index += skip
	parser.component_start = parser.token_index
	parser.token_increment = 0
}

fn (parser &ConstructorStringParser) next_is_authority_slashes() bool {
	return parser.is_non_special_pattern_char(parser.token_index + 1, `/`) && parser.is_non_special_pattern_char(parser.token_index + 2, `/`)
}

fn (parser &ConstructorStringParser) is_identity_terminator() bool {
	return parser.is_non_special_pattern_char(parser.token_index, `@`)
}

fn (parser &ConstructorStringParser) is_password_prefix() bool {
	return parser.is_non_special_pattern_char(parser.token_index, `:`)
}

fn (parser &ConstructorStringParser) is_port_prefix() bool {
	return parser.is_non_special_pattern_char(parser.token_index, `:`)
}

fn (parser &ConstructorStringParser) is_pathname_start() bool {
	return parser.is_non_special_pattern_char(parser.token_index, `/`)
}

fn (parser &ConstructorStringParser) is_protocol_suffix() bool {
	return parser.is_non_special_pattern_char(parser.token_index, `:`)
}

fn (parser &ConstructorStringParser) is_hash_prefix() bool {
	return parser.is_non_special_pattern_char(parser.token_index, `#`)
}

fn (parser &ConstructorStringParser) is_group_open() bool {
	return parser.token_list[parser.token_index].type_ == .open
}

fn (parser &ConstructorStringParser) is_group_close() bool {
	return parser.token_list[parser.token_index].type_ == .close
}

fn (parser &ConstructorStringParser) is_ipv6_open() bool {
	return parser.is_non_special_pattern_char(parser.token_index, `[`)
}

fn (parser &ConstructorStringParser) is_ipv6_close() bool {
	return parser.is_non_special_pattern_char(parser.token_index, `]`)
}

fn (parser &ConstructorStringParser) is_search_prefix() bool {
	if parser.is_non_special_pattern_char(parser.token_index, `?`) {
		return true
	}
	if parser.token_list[parser.token_index].value != '?' {
		return false
	}
	if parser.token_index == 0 {
		return true
	}
	previous := parser.safe_token(parser.token_index - 1)
	return previous.type_ !in [.name, .regexp, .close, .asterisk]
}

fn (parser &ConstructorStringParser) safe_token(index int) PatternToken {
	if index < parser.token_list.len {
		return parser.token_list[index]
	}
	return parser.token_list[parser.token_list.len - 1]
}

fn (parser &ConstructorStringParser) is_non_special_pattern_char(index int, value u8) bool {
	token := parser.safe_token(index)
	return token.value.len > 0 && token.value[0] == value && token.type_ in [.char_, .escaped_char,
		.invalid_char]
}

fn (mut parser ConstructorStringParser) rewind() {
	parser.token_index = parser.component_start
	parser.token_increment = 0
}

fn (mut parser ConstructorStringParser) rewind_and_set_state(state ConstructorParserState) {
	parser.rewind()
	parser.state = state
}
