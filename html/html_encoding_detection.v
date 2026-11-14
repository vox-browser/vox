// Copyright (c) 2021-2025, Ladybird contributors
//
// SPDX-License-Identifier: BSD-2-Clause

// Translation of Libraries/LibWeb/HTML/Parser/HTMLEncodingDetection.cpp.
module html

// https://html.spec.whatwg.org/multipage/parsing.html#concept-encoding-confidence
pub enum EncodingConfidence {
	tentative
	certain
	irrelevant
}

pub struct EncodingSniffingResult {
pub:
	encoding   string
	confidence EncodingConfidence
}

fn standardized_html_encoding(label string) ?string {
	encoding := ascii_lowercase_string(label.trim('\t\n\f\r '))
	if encoding in ['unicode-1-1-utf-8', 'unicode11utf8', 'unicode20utf8', 'utf-8', 'utf8',
		'x-unicode20utf8'] {
		return 'UTF-8'
	}
	if encoding in ['866', 'cp866', 'csibm866', 'ibm866'] {
		return 'IBM866'
	}
	if encoding in ['csisolatin2', 'iso-8859-2', 'iso-ir-101', 'iso8859-2', 'iso88592', 'iso_8859-2',
		'iso_8859-2:1987', 'l2', 'latin2'] {
		return 'ISO-8859-2'
	}
	if encoding in ['csisolatin3', 'iso-8859-3', 'iso-ir-109', 'iso8859-3', 'iso88593', 'iso_8859-3',
		'iso_8859-3:1988', 'l3', 'latin3'] {
		return 'ISO-8859-3'
	}
	if encoding in ['csisolatin4', 'iso-8859-4', 'iso-ir-110', 'iso8859-4', 'iso88594', 'iso_8859-4',
		'iso_8859-4:1988', 'l4', 'latin4'] {
		return 'ISO-8859-4'
	}
	if encoding in ['csisolatincyrillic', 'cyrillic', 'iso-8859-5', 'iso-ir-144', 'iso8859-5',
		'iso88595', 'iso_8859-5', 'iso_8859-5:1988'] {
		return 'ISO-8859-5'
	}
	if encoding in ['arabic', 'asmo-708', 'csiso88596e', 'csiso88596i', 'csisolatinarabic', 'ecma-114',
		'iso-8859-6', 'iso-8859-6-e', 'iso-8859-6-i', 'iso-ir-127', 'iso8859-6', 'iso88596',
		'iso_8859-6', 'iso_8859-6:1987'] {
		return 'ISO-8859-6'
	}
	if encoding in ['csisolatingreek', 'ecma-118', 'elot_928', 'greek', 'greek8', 'iso-8859-7',
		'iso-ir-126', 'iso8859-7', 'iso88597', 'iso_8859-7', 'iso_8859-7:1987', 'sun_eu_greek'] {
		return 'ISO-8859-7'
	}
	if encoding in ['csiso88598e', 'csisolatinhebrew', 'hebrew', 'iso-8859-8', 'iso-8859-8-e',
		'iso-ir-138', 'iso8859-8', 'iso88598', 'iso_8859-8', 'iso_8859-8:1988', 'visual'] {
		return 'ISO-8859-8'
	}
	if encoding in ['csiso88598i', 'iso-8859-8-i', 'logical'] {
		return 'ISO-8859-8-I'
	}
	if encoding in ['csisolatin6', 'iso-8859-10', 'iso-ir-157', 'iso8859-10', 'iso885910', 'l6',
		'latin6'] {
		return 'ISO-8859-10'
	}
	if encoding in ['iso-8859-13', 'iso8859-13', 'iso885913'] {
		return 'ISO-8859-13'
	}
	if encoding in ['iso-8859-14', 'iso8859-14', 'iso885914'] {
		return 'ISO-8859-14'
	}
	if encoding in ['csisolatin9', 'iso-8859-15', 'iso8859-15', 'iso885915', 'iso_8859-15', 'l9'] {
		return 'ISO-8859-15'
	}
	if encoding == 'iso-8859-16' {
		return 'ISO-8859-16'
	}
	if encoding in ['cskoi8r', 'koi', 'koi8', 'koi8-r', 'koi8_r', 'koi8r'] {
		return 'KOI8-R'
	}
	if encoding in ['koi8-ru', 'koi8-u'] {
		return 'KOI8-U'
	}
	if encoding in ['csmacintosh', 'mac', 'macintosh', 'x-mac-roman'] {
		return 'macintosh'
	}
	if encoding == 'pdfdocencoding' {
		return 'PDFDocEncoding'
	}
	if encoding in ['dos-874', 'iso-8859-11', 'iso8859-11', 'iso885911', 'tis-620', 'windows-874'] {
		return 'windows-874'
	}
	if encoding in ['cp1250', 'windows-1250', 'x-cp1250'] {
		return 'windows-1250'
	}
	if encoding in ['cp1251', 'windows-1251', 'x-cp1251'] {
		return 'windows-1251'
	}
	if encoding in ['ansi_x3.4-1968', 'ascii', 'cp1252', 'cp819', 'csisolatin1', 'ibm819',
		'iso-8859-1', 'iso-ir-100', 'iso8859-1', 'iso88591', 'iso_8859-1', 'iso_8859-1:1987', 'l1',
		'latin1', 'us-ascii', 'windows-1252', 'x-cp1252'] {
		return 'windows-1252'
	}
	if encoding in ['cp1253', 'windows-1253', 'x-cp1253'] {
		return 'windows-1253'
	}
	if encoding in ['cp1254', 'csisolatin5', 'iso-8859-9', 'iso-ir-148', 'iso8859-9', 'iso88599',
		'iso_8859-9', 'iso_8859-9:1989', 'l5', 'latin5', 'windows-1254', 'x-cp1254'] {
		return 'windows-1254'
	}
	if encoding in ['cp1255', 'windows-1255', 'x-cp1255'] {
		return 'windows-1255'
	}
	if encoding in ['cp1256', 'windows-1256', 'x-cp1256'] {
		return 'windows-1256'
	}
	if encoding in ['cp1257', 'windows-1257', 'x-cp1257'] {
		return 'windows-1257'
	}
	if encoding in ['cp1258', 'windows-1258', 'x-cp1258'] {
		return 'windows-1258'
	}
	if encoding in ['x-mac-cyrillic', 'x-mac-ukrainian'] {
		return 'x-mac-cyrillic'
	}
	if encoding in ['chinese', 'csgb2312', 'csiso58gb231280', 'gb2312', 'gb_2312', 'gb_2312-80',
		'gbk', 'iso-ir-58', 'x-gbk'] {
		return 'GBK'
	}
	if encoding == 'gb18030' {
		return 'gb18030'
	}
	if encoding in ['big5', 'big5-hkscs', 'cn-big5', 'csbig5', 'x-x-big5'] {
		return 'Big5'
	}
	if encoding in ['cseucpkdfmtjapanese', 'euc-jp', 'x-euc-jp'] {
		return 'EUC-JP'
	}
	if encoding in ['csiso2022jp', 'iso-2022-jp'] {
		return 'ISO-2022-JP'
	}
	if encoding in ['csshiftjis', 'ms932', 'ms_kanji', 'shift-jis', 'shift_jis', 'sjis', 'windows-31j',
		'x-sjis'] {
		return 'Shift_JIS'
	}
	if encoding in ['cseuckr', 'csksc56011987', 'euc-kr', 'iso-ir-149', 'korean', 'ks_c_5601-1987',
		'ks_c_5601-1989', 'ksc5601', 'ksc_5601', 'windows-949'] {
		return 'EUC-KR'
	}
	if encoding in ['csiso2022kr', 'hz-gb-2312', 'iso-2022-cn', 'iso-2022-cn-ext', 'iso-2022-kr',
		'replacement'] {
		return 'replacement'
	}
	if encoding in ['unicodefffe', 'utf-16be'] {
		return 'UTF-16BE'
	}
	if encoding in ['csunicode', 'iso-10646-ucs-2', 'ucs-2', 'unicode', 'unicodefeff', 'utf-16',
		'utf-16le'] {
		return 'UTF-16LE'
	}
	if encoding == 'x-user-defined' {
		return 'x-user-defined'
	}
	return none
}

fn html_encoding_whitespace(byte u8) bool {
	return byte in [`\t`, `\n`, `\x0c`, `\r`, ` `]
}

// https://html.spec.whatwg.org/multipage/urls-and-fetching.html#algorithm-for-extracting-a-character-encoding-from-a-meta-element
pub fn extract_character_encoding_from_meta_element(input string) ?string {
	lowercase_input := ascii_lowercase_string(input)
	mut position := 0
	for {
		relative_index := lowercase_input[position..].index('charset') or { return none }
		position += relative_index + 7
		for position < lowercase_input.len && html_encoding_whitespace(lowercase_input[position]) {
			position++
		}
		if position < lowercase_input.len && lowercase_input[position] == `=` {
			break
		}
		if position >= lowercase_input.len {
			return none
		}
	}
	position++
	for position < lowercase_input.len && html_encoding_whitespace(lowercase_input[position]) {
		position++
	}
	if position >= lowercase_input.len {
		return none
	}
	if lowercase_input[position] in [`"`, `'`] {
		quote := lowercase_input[position]
		position++
		end_offset := lowercase_input[position..].index_u8(quote)
		if end_offset < 0 {
			return none
		}
		return standardized_html_encoding(lowercase_input[position..position + end_offset])
	}
	start := position
	for position < lowercase_input.len && !html_encoding_whitespace(lowercase_input[position])
		&& lowercase_input[position] != `;` {
		position++
	}
	return standardized_html_encoding(lowercase_input[start..position])
}

pub struct PrescanAttribute {
pub:
	name  string
	value string
}

fn prescan_should_abort(input []u8, position int) bool {
	return position >= input.len || position >= 1024
}

struct PrescanCursor {
mut:
	position int
}

fn prescan_skip_whitespace_and_slashes(input []u8, mut cursor PrescanCursor) bool {
	for !prescan_should_abort(input, cursor.position)
		&& (html_encoding_whitespace(input[cursor.position]) || input[cursor.position] == `/`) {
		cursor.position++
	}
	return !prescan_should_abort(input, cursor.position)
}

fn append_prescan_byte(mut bytes []u8, byte u8) {
	bytes << if byte >= `A` && byte <= `Z` { byte + 0x20 } else { byte }
}

// https://html.spec.whatwg.org/multipage/parsing.html#concept-get-attributes-when-sniffing
pub fn prescan_get_attribute(input []u8, mut cursor PrescanCursor) ?PrescanAttribute {
	if !prescan_skip_whitespace_and_slashes(input, mut cursor) || input[cursor.position] == `>` {
		return none
	}
	mut name := []u8{}
	for {
		if input[cursor.position] == `=` && name.len > 0 {
			cursor.position++
			break
		}
		if html_encoding_whitespace(input[cursor.position]) {
			if !prescan_skip_whitespace_and_slashes(input, mut cursor) {
				return none
			}
			if input[cursor.position] != `=` {
				return PrescanAttribute{name.bytestr(), ''}
			}
			cursor.position++
			break
		}
		if input[cursor.position] in [`/`, `>`] {
			return PrescanAttribute{name.bytestr(), ''}
		}
		append_prescan_byte(mut name, input[cursor.position])
		cursor.position++
		if prescan_should_abort(input, cursor.position) {
			return none
		}
	}

	if !prescan_skip_whitespace_and_slashes(input, mut cursor) {
		return none
	}
	mut value := []u8{}
	if input[cursor.position] in [`"`, `'`] {
		quote := input[cursor.position]
		cursor.position++
		for !prescan_should_abort(input, cursor.position) {
			if input[cursor.position] == quote {
				cursor.position++
				return PrescanAttribute{name.bytestr(), value.bytestr()}
			}
			append_prescan_byte(mut value, input[cursor.position])
			cursor.position++
		}
		return none
	}
	if input[cursor.position] == `>` {
		return PrescanAttribute{name.bytestr(), ''}
	}
	append_prescan_byte(mut value, input[cursor.position])
	cursor.position++
	if prescan_should_abort(input, cursor.position) {
		return none
	}
	for !prescan_should_abort(input, cursor.position) {
		if html_encoding_whitespace(input[cursor.position]) || input[cursor.position] == `>` {
			return PrescanAttribute{name.bytestr(), value.bytestr()}
		}
		append_prescan_byte(mut value, input[cursor.position])
		cursor.position++
	}
	return none
}

fn prescan_ascii_alpha(byte u8) bool {
	return (byte >= `A` && byte <= `Z`) || (byte >= `a` && byte <= `z`)
}

fn html_encoding_ascii_lower_byte(byte u8) u8 {
	return if byte >= `A` && byte <= `Z` { byte + 0x20 } else { byte }
}

// https://html.spec.whatwg.org/multipage/parsing.html#concept-get-xml-encoding-when-sniffing
fn get_an_xml_encoding(input []u8) ?string {
	if input.len < 5 || input[..5].bytestr() != '<?xml' { return none }
	declaration_end := input.bytestr().index('>') or { return none }
	declaration := input[..declaration_end].bytestr()
	encoding_index := declaration.index('encoding') or { return none }
	mut position := encoding_index + 'encoding'.len
	for position < input.len && input[position] <= 0x20 { position++ }
	if position >= input.len || input[position] != `=` { return none }
	position++
	for position < input.len && input[position] <= 0x20 { position++ }
	if position >= input.len { return none }
	quote := input[position]
	if quote != `"` && quote != `'` { return none }
	position++
	start := position
	for position < input.len && input[position] != quote { position++ }
	if position >= input.len { return none }
	potential_encoding := input[start..position]
	for byte in potential_encoding {
		if byte <= 0x20 { return none }
	}
	encoding := standardized_html_encoding(potential_encoding.bytestr()) or { return none }
	if encoding in ['UTF-16BE', 'UTF-16LE'] { return 'UTF-8' }
	return encoding
}

// https://html.spec.whatwg.org/multipage/parsing.html#prescan-a-byte-stream-to-determine-its-encoding
pub fn run_prescan_byte_stream_algorithm(input []u8) ?string {
	if encoding := run_prescan_byte_stream_algorithm_steps(input) { return encoding }
	return get_an_xml_encoding(input)
}

fn run_prescan_byte_stream_algorithm_steps(input []u8) ?string {
	mut position := 0
	if !prescan_should_abort(input, position + 5) {
		if input[..6] == [u8(0x3c), 0, 0x3f, 0, 0x78, 0] {
			return 'utf-16le'
		}
		if input[..6] == [u8(0), 0x3c, 0, 0x3f, 0, 0x78] {
			return 'utf-16be'
		}
	}
	for !prescan_should_abort(input, position) {
		if !prescan_should_abort(input, position + 3)
			&& input[position..position + 4].bytestr() == '<!--' {
			position += 2
			for !prescan_should_abort(input, position + 2) {
				if input[position..position + 3].bytestr() == '-->' {
					position += 2
					break
				}
				position++
			}
		} else if !prescan_should_abort(input, position + 5) && input[position] == `<`
			&& html_encoding_ascii_lower_byte(input[position + 1]) == `m`
			&& html_encoding_ascii_lower_byte(input[position + 2]) == `e`
			&& html_encoding_ascii_lower_byte(input[position + 3]) == `t`
			&& html_encoding_ascii_lower_byte(input[position + 4]) == `a`
			&& (html_encoding_whitespace(input[position + 5])
				|| input[position + 5] == `/`) {
			position += 6
			mut attribute_names := []string{}
			mut got_pragma := false
			mut need_pragma := ?bool(none)
			mut charset := ?string(none)
			mut cursor := PrescanCursor{
				position: position
			}
			for {
				attribute := prescan_get_attribute(input, mut cursor) or { break }
				if attribute.name in attribute_names {
					continue
				}
				attribute_names << attribute.name
				if attribute.name == 'http-equiv' {
					got_pragma = attribute.value == 'content-type'
				} else if attribute.name == 'content' {
					if encoding := extract_character_encoding_from_meta_element(attribute.value) {
						if charset == none {
							charset = encoding
							need_pragma = true
						}
					}
				} else if attribute.name == 'charset' {
					if encoding := standardized_html_encoding(attribute.value) {
						charset = encoding
						need_pragma = false
					}
				}
			}
			position = cursor.position
			pragma_required := need_pragma or { continue }
			if pragma_required && !got_pragma {
				continue
			}
			encoding := charset or { continue }
			if encoding in ['UTF-16BE', 'UTF-16LE'] {
				return 'UTF-8'
			}
			if encoding == 'x-user-defined' {
				return 'windows-1252'
			}
			return encoding
		} else if !prescan_should_abort(input, position + 2) && input[position] == `<`
			&& ((input[position + 1] == `/` && prescan_ascii_alpha(input[position + 2]))
				|| prescan_ascii_alpha(input[position + 1])) {
			for !prescan_should_abort(input, position) && !html_encoding_whitespace(input[position])
				&& input[position] != `>` {
				position++
			}
			mut cursor := PrescanCursor{
				position: position
			}
			for {
				_ := prescan_get_attribute(input, mut cursor) or { break }
			}
			position = cursor.position
			continue
		} else if !prescan_should_abort(input, position + 1) && input[position] == `<`
			&& input[position + 1] in [`!`, `/`, `?`] {
			position += 2
			for !prescan_should_abort(input, position) && input[position] != `>` {
				position++
			}
		}
		position++
	}
	return none
}

// https://encoding.spec.whatwg.org/#bom-sniff
pub fn run_html_bom_sniff(input []u8) ?string {
	if input.len >= 3 {
		if input[0] == 0xef && input[1] == 0xbb && input[2] == 0xbf {
			return 'UTF-8'
		}
		if input[0] == 0xfe && input[1] == 0xff {
			return 'UTF-16BE'
		}
		if input[0] == 0xff && input[1] == 0xfe {
			return 'UTF-16LE'
		}
	}
	return none
}

fn html_encoding_valid_utf8(data []u8) bool {
	mut index := 0
	for index < data.len {
		first := data[index]
		if first <= 0x7f {
			index++
			continue
		}
		mut trailing := 0
		mut lower := u8(0x80)
		mut upper := u8(0xbf)
		if first >= 0xc2 && first <= 0xdf {
			trailing = 1
		} else if first == 0xe0 {
			trailing = 2
			lower = 0xa0
		} else if first >= 0xe1 && first <= 0xec {
			trailing = 2
		} else if first == 0xed {
			trailing = 2
			upper = 0x9f
		} else if first >= 0xee && first <= 0xef {
			trailing = 2
		} else if first == 0xf0 {
			trailing = 3
			lower = 0x90
		} else if first >= 0xf1 && first <= 0xf3 {
			trailing = 3
		} else if first == 0xf4 {
			trailing = 3
			upper = 0x8f
		} else {
			return false
		}
		if index + trailing >= data.len || data[index + 1] < lower || data[index + 1] > upper {
			return false
		}
		for offset := 2; offset <= trailing; offset++ {
			if data[index + offset] < 0x80 || data[index + offset] > 0xbf {
				return false
			}
		}
		index += trailing + 1
	}
	return true
}

// https://html.spec.whatwg.org/multipage/parsing.html#determining-the-character-encoding
pub fn run_html_encoding_sniffing_algorithm_with_confidence(input []u8, transport_encoding ?string) EncodingSniffingResult {
	if bom := run_html_bom_sniff(input) {
		return EncodingSniffingResult{
			encoding: bom
			confidence: .certain
		}
	}
	if transport := transport_encoding {
		if encoding := standardized_html_encoding(transport) {
			return EncodingSniffingResult{
				encoding: encoding
				confidence: .certain
			}
		}
	}
	if prescan := run_prescan_byte_stream_algorithm(input) {
		return EncodingSniffingResult{
			encoding: prescan
			confidence: .tentative
		}
	}
	if !html_encoding_valid_utf8(input) {
		return EncodingSniffingResult{
			encoding: 'windows-1252'
			confidence: .tentative
		}
	}
	return EncodingSniffingResult{
		encoding: 'UTF-8'
		confidence: .tentative
	}
}

// Compatibility wrapper for callers which only need the selected encoding.
pub fn run_html_encoding_sniffing_algorithm(input []u8, transport_encoding ?string) string {
	return run_html_encoding_sniffing_algorithm_with_confidence(input, transport_encoding).encoding
}
