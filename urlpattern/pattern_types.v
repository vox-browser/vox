// Copyright (c) 2025-2026, Ladybird contributors
// SPDX-License-Identifier: BSD-2-Clause

// Translation of LibURL/Pattern/{Options,Part,Tokenizer}.h.
module urlpattern

enum PatternPartType {
	fixed_text
	regexp
	segment_wildcard
	full_wildcard
}

enum PatternPartModifier {
	none
	optional
	zero_or_more
	one_or_more
}

fn (modifier PatternPartModifier) serialize() string {
	return match modifier {
		.none { '' }
		.optional { '?' }
		.zero_or_more { '*' }
		.one_or_more { '+' }
	}
}

struct PatternPart {
	type_    PatternPartType
	value    string
	modifier PatternPartModifier
	name     string
	prefix   string
	suffix   string
}

struct PatternCompileOptions {
	delimiter_code_point ?rune
	prefix_code_point    ?rune
	ignore_case          bool
}

fn default_pattern_options() PatternCompileOptions {
	return PatternCompileOptions{}
}

fn hostname_pattern_options() PatternCompileOptions {
	return PatternCompileOptions{
		delimiter_code_point: `.`
	}
}

fn pathname_pattern_options(ignore_case bool) PatternCompileOptions {
	return PatternCompileOptions{
		delimiter_code_point: `/`
		prefix_code_point: `/`
		ignore_case: ignore_case
	}
}

enum PatternTokenType {
	open
	close
	regexp
	name
	char_
	escaped_char
	other_modifier
	asterisk
	end
	invalid_char
}

struct PatternToken {
	type_ PatternTokenType
	index int
	value string
}

enum PatternTokenizerPolicy {
	strict
	lenient
}

const full_wildcard_regexp_value = '.*'

enum PatternCanonicalization {
	protocol
	username
	password
	hostname
	ipv6_hostname
	port
	pathname
	opaque_pathname
	search
	hash
}
