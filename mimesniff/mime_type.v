// Copyright (c) 2023, Kenneth Myhra <kennethmyhra@serenityos.org>
//
// SPDX-License-Identifier: BSD-2-Clause

// Translation of Libraries/LibWeb/MimeSniff/MimeType.cpp (the WHATWG MIME Sniffing standard's
// MIME type record: parse, serialize, and the type predicates). The GenericLexer and the
// LibHTTP `collect an HTTP quoted string` helper it relies on are translated inline here so the
// module stays self-contained. OrderedHashMap → a V map (insertion-ordered).
// https://mimesniff.spec.whatwg.org/#mime-type
module mimesniff

// https://mimesniff.spec.whatwg.org/#javascript-mime-type
pub const javascript_mime_type_essence_strings = [
	'application/ecmascript',
	'application/javascript',
	'application/x-ecmascript',
	'application/x-javascript',
	'text/ecmascript',
	'text/javascript',
	'text/javascript1.0',
	'text/javascript1.1',
	'text/javascript1.2',
	'text/javascript1.3',
	'text/javascript1.4',
	'text/javascript1.5',
	'text/jscript',
	'text/livescript',
	'text/x-ecmascript',
	'text/x-javascript',
]

// LibHTTP: HTTP_WHITESPACE = "\n\r\t ".
const http_whitespace = '\n\r\t '

// --- Small ASCII / code-point helpers ---

fn is_ascii_alphanumeric(ch u8) bool {
	return (ch >= `0` && ch <= `9`) || (ch >= `a` && ch <= `z`) || (ch >= `A` && ch <= `Z`)
}

fn ascii_lowercase(input string) string {
	mut bytes := input.bytes()
	for i, ch in bytes {
		if ch >= `A` && ch <= `Z` {
			bytes[i] = ch + 0x20
		}
	}
	return bytes.bytestr()
}

// Append the UTF-16 encoding of a valid UTF-8 string. Utf16StringBuilder in
// LibWeb performs this conversion one Unicode scalar value at a time.
fn append_utf8_as_utf16(mut builder []u16, input string) {
	for code_point in input.runes() {
		value := u32(code_point)
		if value <= 0xffff {
			builder << u16(value)
			continue
		}
		supplementary := value - 0x10000
		builder << u16(0xd800 + (supplementary >> 10))
		builder << u16(0xdc00 + (supplementary & 0x3ff))
	}
}

// https://mimesniff.spec.whatwg.org/#http-token-code-point
fn is_http_token_code_point(ch u8) bool {
	return ch in [u8(`!`), `#`, `$`, `%`, `&`, `'`, `*`, `+`, `-`, `.`, `^`, `_`, `\``, `|`, `~`]
		|| is_ascii_alphanumeric(ch)
}

fn contains_only_http_token_code_points(string_ string) bool {
	for ch in string_.bytes() {
		if !is_http_token_code_point(ch) {
			return false
		}
	}
	return true
}

fn http_token_to_ascii_lowercase_string(input string) string {
	mut result := []u8{cap: input.len}
	for ch in input.bytes() {
		assert is_http_token_code_point(ch)
		result << if ch >= `A` && ch <= `Z` { ch + 0x20 } else { ch }
	}
	return result.bytestr()
}

// https://mimesniff.spec.whatwg.org/#http-quoted-string-token-code-point
fn contains_only_http_quoted_string_token_code_points(string_ string) bool {
	// U+0009 TAB, U+0020..U+007E, or U+0080..U+00FF.
	for code_point in string_.runes() {
		cp := u32(code_point)
		if !(cp == 0x09 || (cp >= 0x20 && cp <= 0x7E) || (cp >= 0x80 && cp <= 0xFF)) {
			return false
		}
	}
	return true
}

// Utf8View::validate rejects malformed byte sequences before the MIME parser examines code points.
fn is_valid_utf8(string_ string) bool {
	bytes := string_.bytes()
	mut i := 0
	for i < bytes.len {
		first := bytes[i]
		if first < 0x80 {
			i++
			continue
		}
		mut continuation_count := 0
		mut code_point := u32(0)
		mut minimum := u32(0)
		if first >= 0xc2 && first <= 0xdf {
			continuation_count = 1
			code_point = u32(first & 0x1f)
			minimum = 0x80
		} else if first >= 0xe0 && first <= 0xef {
			continuation_count = 2
			code_point = u32(first & 0x0f)
			minimum = 0x800
		} else if first >= 0xf0 && first <= 0xf4 {
			continuation_count = 3
			code_point = u32(first & 0x07)
			minimum = 0x10000
		} else {
			return false
		}
		if i + continuation_count >= bytes.len {
			return false
		}
		for offset in 1 .. continuation_count + 1 {
			continuation := bytes[i + offset]
			if continuation & 0xc0 != 0x80 {
				return false
			}
			code_point = (code_point << 6) | u32(continuation & 0x3f)
		}
		if code_point < minimum || code_point > 0x10ffff
			|| (code_point >= 0xd800 && code_point <= 0xdfff) {
			return false
		}
		i += continuation_count + 1
	}
	return true
}

// https://mimesniff.spec.whatwg.org/#javascript-mime-type-essence-match
pub fn is_javascript_mime_type_essence_match(string_ string) bool {
	lowered := ascii_lowercase(string_)
	for javascript_essence in javascript_mime_type_essence_strings {
		if lowered == javascript_essence {
			return true
		}
	}
	return false
}

// --- GenericLexer (minimal, as used by the MIME parser) ---

struct Lexer {
	input string
mut:
	position int
}

fn (l &Lexer) is_eof() bool {
	return l.position >= l.input.len
}

fn (l &Lexer) tell() int {
	return l.position
}

fn (l &Lexer) peek() u8 {
	return if l.position < l.input.len { l.input[l.position] } else { u8(0) }
}

fn (mut l Lexer) ignore(count int) {
	l.position += count
	if l.position > l.input.len {
		l.position = l.input.len
	}
}

fn (mut l Lexer) consume() u8 {
	ch := l.peek()
	l.position++
	return ch
}

fn (mut l Lexer) consume_until_char(delimiter u8) string {
	start := l.position
	for l.position < l.input.len && l.input[l.position] != delimiter {
		l.position++
	}
	return l.input[start..l.position]
}

fn (mut l Lexer) consume_until_pred(pred fn (u8) bool) string {
	start := l.position
	for l.position < l.input.len && !pred(l.input[l.position]) {
		l.position++
	}
	return l.input[start..l.position]
}

fn (mut l Lexer) ignore_while(pred fn (u8) bool) {
	for l.position < l.input.len && pred(l.input[l.position]) {
		l.position++
	}
}

fn (mut l Lexer) ignore_until_char(delimiter u8) {
	for l.position < l.input.len && l.input[l.position] != delimiter {
		l.position++
	}
}

fn is_http_whitespace(ch u8) bool {
	return ch == `\n` || ch == `\r` || ch == `\t` || ch == ` `
}

enum HttpQuotedStringExtractValue {
	no
	yes
}

// LibHTTP: collect an HTTP quoted string.
fn collect_an_http_quoted_string(mut lexer Lexer, extract_value HttpQuotedStringExtractValue) string {
	// 1. Let positionStart be position.
	position_start := lexer.tell()
	// 2. Let value be the empty string.
	mut value := ''
	// 3-4. Assert the code point is '"' and advance past it.
	lexer.ignore(1)
	// 5. While true:
	for {
		// 1. Collect code points that are not '"' or '\\'.
		value += lexer.consume_until_pred(fn (ch u8) bool {
			return ch == `"` || ch == `\\`
		})
		// 2. If past the end of input, break.
		if lexer.is_eof() {
			break
		}
		// 3-4. Let quoteOrBackslash be the code point; advance.
		quote_or_backslash := lexer.consume()
		if quote_or_backslash == `\\` {
			// 5.1. If past the end, append '\\' and break.
			if lexer.is_eof() {
				value += '\\'
				break
			}
			// 5.2-5.3. Append the next code point; advance.
			value += lexer.consume().ascii_str()
		} else {
			// 6. quoteOrBackslash is '"': break.
			break
		}
	}
	// 6. If the extract-value flag is set, return value.
	if extract_value == .yes {
		return value
	}
	// 7. Return the code points from positionStart to position, inclusive.
	return lexer.input[position_start..lexer.tell()]
}

// --- MimeType ---

pub struct MimeType {
mut:
	// A MIME type's type/subtype are non-empty ASCII strings.
	type_    string
	subtype_ string
	// Parameters: an ordered map (V maps preserve insertion order).
	parameters_ map[string]string
	// Non-standard, computed once upfront.
	cached_essence_ string
}

// https://mimesniff.spec.whatwg.org/#mime-type
pub fn MimeType.create(type_ string, subtype_ string) MimeType {
	return MimeType{
		type_: type_
		subtype_: subtype_
		cached_essence_: '${type_}/${subtype_}'
	}
}

pub fn (m &MimeType) type_() string {
	return m.type_
}

pub fn (m &MimeType) subtype() string {
	return m.subtype_
}

pub fn (m &MimeType) parameters() map[string]string {
	return m.parameters_.clone()
}

// https://mimesniff.spec.whatwg.org/#parse-a-mime-type
pub fn MimeType.parse(string_ string) ?MimeType {
	// Verify the input is valid UTF-8 first.
	if !is_valid_utf8(string_) {
		return none
	}
	// 1. Remove leading and trailing HTTP whitespace.
	trimmed_string := string_.trim(http_whitespace)
	// 2. Let position be a position variable, initially at the start.
	mut lexer := Lexer{
		input: trimmed_string
	}
	// 3. Let type be the code points up to U+002F (/).
	type_ := lexer.consume_until_char(`/`)
	// 4. If type is empty or not solely HTTP token code points, return failure.
	if type_.len == 0 || !contains_only_http_token_code_points(type_) {
		return none
	}
	// 5. If position is past the end, return failure.
	if lexer.is_eof() {
		return none
	}
	// 6. Advance past U+002F (/).
	lexer.ignore(1)
	// 7. Let subtype be the code points up to U+003B (;).
	mut subtype := lexer.consume_until_char(`;`)
	// 8. Remove trailing HTTP whitespace from subtype.
	subtype = subtype.trim_right(http_whitespace)
	// 9. If subtype is empty or not solely HTTP token code points, return failure.
	if subtype.len == 0 || !contains_only_http_token_code_points(subtype) {
		return none
	}
	// 10. Let mimeType be a new MIME type record; type/subtype in ASCII lowercase.
	mut mime_type := MimeType.create(http_token_to_ascii_lowercase_string(type_), http_token_to_ascii_lowercase_string(subtype))
	// 11. While not past the end of input:
	for !lexer.is_eof() {
		// 1. Advance past U+003B (;).
		lexer.ignore(1)
		// 2. Collect HTTP whitespace.
		lexer.ignore_while(is_http_whitespace)
		// 3. Let parameterName be the code points up to ';' or '='.
		parameter_name_view := lexer.consume_until_pred(fn (ch u8) bool {
			return ch == `;` || ch == `=`
		})
		// 4. Set parameterName to ASCII lowercase.
		mut parameter_name := ''
		if contains_only_http_token_code_points(parameter_name_view) {
			parameter_name = http_token_to_ascii_lowercase_string(parameter_name_view)
		}
		// 5. If not past the end:
		if !lexer.is_eof() {
			// 1. If the code point is ';', continue.
			if lexer.peek() == `;` {
				continue
			}
			// 2. Advance past U+003D (=).
			lexer.ignore(1)
		}
		// 6. If past the end, break.
		if lexer.is_eof() {
			break
		}
		// 7. Let parameterValue be null.
		mut parameter_value := ''
		// 8. If the code point is '"':
		if lexer.peek() == `"` {
			// 1. Collect an HTTP quoted string with the extract-value flag.
			parameter_value = collect_an_http_quoted_string(mut lexer, .yes)
			// 2. Collect code points that are not ';'.
			lexer.ignore_until_char(`;`)
		} else {
			// 9.1. Collect code points that are not ';'.
			parameter_value = lexer.consume_until_char(`;`)
			// 9.2. Remove trailing HTTP whitespace.
			parameter_value = parameter_value.trim_right(http_whitespace)
			// 9.3. If empty, continue.
			if parameter_value.len == 0 {
				continue
			}
		}
		// 10. If all conditions hold, set mimeType's parameters[parameterName] to parameterValue.
		if parameter_name.len != 0 && contains_only_http_token_code_points(parameter_name)
			&& contains_only_http_quoted_string_token_code_points(parameter_value)
			&& parameter_name !in mime_type.parameters_ {
			mime_type.parameters_[parameter_name] = parameter_value
		}
	}
	// 12. Return mimeType.
	return mime_type
}

// https://mimesniff.spec.whatwg.org/#mime-type-essence
pub fn (m &MimeType) essence() string {
	return m.cached_essence_
}

// https://mimesniff.spec.whatwg.org/#serialize-a-mime-type
pub fn (m &MimeType) serialized() string {
	// 1. serialization = type + "/" + subtype.
	mut serialization := '${m.type_}/${m.subtype_}'
	// 2. For each name → value of parameters:
	for name, value in m.parameters_ {
		mut serialized_value := value
		// 1-3. Append ";name=".
		serialization += ';${name}='
		// 4. If value is not solely HTTP token code points, or is empty, quote it.
		if !contains_only_http_token_code_points(serialized_value) || serialized_value.len == 0 {
			// 1. Escape '\\' and '"'.
			serialized_value = serialized_value.replace('\\', '\\\\')
			serialized_value = serialized_value.replace('"', '\\"')
			// 2-3. Wrap in quotes.
			serialized_value = '"${serialized_value}"'
		}
		// 5. Append value.
		serialization += serialized_value
	}
	// 3. Return serialization.
	return serialization
}

// https://mimesniff.spec.whatwg.org/#serialize-a-mime-type
pub fn (m &MimeType) serialized_as_utf16() []u16 {
	mut serialization := []u16{}
	append_utf8_as_utf16(mut serialization, m.type_)
	serialization << u16(`/`)
	append_utf8_as_utf16(mut serialization, m.subtype_)
	for name, parameter_value in m.parameters_ {
		serialization << u16(`;`)
		append_utf8_as_utf16(mut serialization, name)
		serialization << u16(`=`)
		if !contains_only_http_token_code_points(parameter_value) || parameter_value.len == 0 {
			serialization << u16(`\"`)
			for code_point in parameter_value.runes() {
				if code_point == `\"` || code_point == `\\` {
					serialization << u16(`\\`)
				}
				append_utf8_as_utf16(mut serialization, code_point.str())
			}
			serialization << u16(`\"`)
			continue
		}
		append_utf8_as_utf16(mut serialization, parameter_value)
	}
	return serialization
}

pub fn (mut m MimeType) set_parameter(name string, value string) {
	m.parameters_[name] = value
}

// https://mimesniff.spec.whatwg.org/#image-mime-type
pub fn (m &MimeType) is_image() bool {
	return m.type_ == 'image'
}

// https://mimesniff.spec.whatwg.org/#audio-or-video-mime-type
pub fn (m &MimeType) is_audio_or_video() bool {
	return m.type_ in ['audio', 'video'] || m.essence() == 'application/ogg'
}

// https://mimesniff.spec.whatwg.org/#font-mime-type
pub fn (m &MimeType) is_font() bool {
	if m.type_ == 'font' {
		return true
	}
	return m.essence() in [
		'application/font-cff',
		'application/font-otf',
		'application/font-sfnt',
		'application/font-ttf',
		'application/font-woff',
		'application/vnd.ms-fontobject',
		'application/vnd.ms-opentype',
	]
}

// https://mimesniff.spec.whatwg.org/#zip-based-mime-type
pub fn (m &MimeType) is_zip_based() bool {
	return m.subtype_.ends_with('+zip') || m.essence() == 'application/zip'
}

// https://mimesniff.spec.whatwg.org/#archive-mime-type
pub fn (m &MimeType) is_archive() bool {
	return m.essence() in ['application/x-rar-compressed', 'application/zip', 'application/x-gzip']
}

// https://mimesniff.spec.whatwg.org/#xml-mime-type
pub fn (m &MimeType) is_xml() bool {
	return m.subtype_.ends_with('+xml') || m.essence() in ['text/xml', 'application/xml']
}

// https://mimesniff.spec.whatwg.org/#html-mime-type
pub fn (m &MimeType) is_html() bool {
	return m.essence() == 'text/html'
}

// https://mimesniff.spec.whatwg.org/#scriptable-mime-type
pub fn (m &MimeType) is_scriptable() bool {
	return m.is_xml() || m.is_html() || m.essence() == 'application/pdf'
}

// https://mimesniff.spec.whatwg.org/#javascript-mime-type
pub fn (m &MimeType) is_javascript() bool {
	return m.essence() in javascript_mime_type_essence_strings
}

// https://mimesniff.spec.whatwg.org/#json-mime-type
pub fn (m &MimeType) is_json() bool {
	return m.subtype_.ends_with('+json') || m.essence() in ['application/json', 'text/json']
}

// https://mimesniff.spec.whatwg.org/#minimize-a-supported-mime-type
pub fn minimise_a_supported_mime_type(mime_type &MimeType) string {
	// 1. If mimeType is a JavaScript MIME type, return "text/javascript".
	if mime_type.is_javascript() {
		return 'text/javascript'
	}
	// 2. If mimeType is a JSON MIME type, return "application/json".
	if mime_type.is_json() {
		return 'application/json'
	}
	// 3. If mimeType's essence is "image/svg+xml", return "image/svg+xml".
	if mime_type.essence() == 'image/svg+xml' {
		return 'image/svg+xml'
	}
	// 4. If mimeType is an XML MIME type, return "application/xml".
	if mime_type.is_xml() {
		return 'application/xml'
	}
	// FIXME: 5. If mimeType is supported by the user agent, return mimeType's essence.
	// 6. Return the empty string.
	return ''
}
