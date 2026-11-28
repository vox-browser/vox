// Copyright (c) 2026, Ladybird contributors
// SPDX-License-Identifier: BSD-2-Clause

// Browser input compatibility for V's standard XML parser. This module owns
// no element parser or DOM; vlib validates and constructs the XML tree.
module xmlcompat

import encoding.xml as vxml
import strings

// A name must resolve to a stable value within one parse. The parser caches
// each distinct HTML name and calls the resolver only on its first occurrence.
pub type EntityResolver = fn (string) ?string

pub struct Document {
pub:
	children         []vxml.XMLNodeContents
	marker           string
	special_nodes    []SpecialNode
	attribute_values []string
}

pub struct SpecialNode {
pub:
	target     string
	is_comment bool
	is_text    bool
	is_cdata   bool
	data       string
	doctype    ?vxml.DocumentType
}

struct XMLPreparedSource {
	source           string
	marker           string
	special_nodes    []SpecialNode
	attribute_values []string
}

struct XMLReferenceContext {
	resolve_entity EntityResolver @[required]
mut:
	// Even an empty map allocates a header. Ordinary XML references need no
	// private map; create one only when the first HTML name is encountered.
	entities ?map[string]string
	recent_references [2]string
	recent_replacements [2]string
	next_reference int
}

// Only marked attribute values are indirect. Short ordinary values stay in
// vlib's tree, avoiding a side-table lookup on the common small-SVG path.
pub fn (document &Document) attribute_value(value string) !string {
	if document.attribute_values.len == 0 || !value.starts_with('@') { return value }
	index := value.substr_unsafe(1, value.len).int()
	if index < 0 || index >= document.attribute_values.len {
		return error('invalid XML attribute marker')
	}
	return document.attribute_values[index]
}

pub fn (document &Document) special_node(comment vxml.XMLComment) ?SpecialNode {
	if !comment.text.starts_with(document.marker) { return none }
	mut index := 0
	for position in document.marker.len .. comment.text.len {
		byte := comment.text[position]
		if byte < `0` || byte > `9` || index >= document.special_nodes.len {
			return none
		}
		index = index * 10 + int(byte - `0`)
	}
	return document.special_nodes[index] or { none }
}

fn xml_has_prefix(source string, position int, prefix string) bool {
	if position + prefix.len > source.len { return false }
	for index, byte in prefix {
		if source[position + index] != byte { return false }
	}
	return true
}

fn xml_is_space(byte u8) bool {
	return byte in [` `, `\t`, `\n`, `\r`]
}

fn xml_is_only_space(value string) bool {
	for byte in value {
		if !xml_is_space(byte) {
			return false
		}
	}
	return true
}

pub fn check_name(name string) ! {
	check_name_colon(name)!
}

// Validate the browser's XML name rules while locating the optional prefix.
// DOM name validation is broader, so XML callers must retain this check.
pub fn check_name_colon(name string) !int {
	if name == '' {
		return error('invalid qualified XML name ${name}')
	}
	mut colon := -1
	for index, byte in name {
		if byte == `:` {
			if index == 0 || index == name.len - 1 || colon >= 0 {
				return error('invalid qualified XML name ${name}')
			}
			colon = index
			continue
		}
		if byte == `_` || byte >= 0x80 || (byte >= `A` && byte <= `Z`)
			|| (byte >= `a` && byte <= `z`) || (index > 0 && ((byte >= `0` && byte <= `9`) || byte in [
			`-`,
			`.`,
		])) {
			continue
		}
		return error('invalid qualified XML name ${name}')
	}
	return colon
}

fn xml_numeric_references(value string) string {
	mut output := strings.new_builder(value.len)
	for character in value.runes() {
		output.write_string('&#${int(character)};')
	}
	return output.str()
}

fn (mut context XMLReferenceContext) html_entity(name string) !string {
	if entities := context.entities {
		if cached := entities[name] { return cached }
	}
	resolved := context.resolve_entity(name.clone()) or {
		return error('unknown XML entity &${name};')
	}
	// Preserve vlib's character validation even for a custom resolver. This
	// conversion happens once per distinct HTML name, rather than once per
	// occurrence, and cached replacements are never decoded recursively.
	decoded := vxml.unescape_text(xml_numeric_references(resolved))!
	// This context alone owns the cache. Alias its header during insertion and
	// restore it afterwards, avoiding an implicit map clone on each new name.
	mut entities := unsafe { context.entities or { vxml.default_entities.clone() } }
	entities[name] = decoded
	context.entities = unsafe { entities }
	return decoded
}

// Discover only the HTML names used by this document. Normal payloads stay
// unchanged for vlib's decoder; the declaration path needs numeric references
// because vlib parses its prolog with the standard XML entity map.
fn prepare_references(value string, mut context XMLReferenceContext, expand_html bool) !string {
	mut output := strings.new_builder(0)
	mut position := 0
	mut copied := 0
	for {
		start := value.index_after('&', position) or { break }
		end := value.index_after(';', start + 1) or {
			return error('unterminated XML entity reference')
		}
		name := value.substr_unsafe(start + 1, end)
		if name.starts_with('#X') {
			// The previous browser parser also accepted uppercase hexadecimal X.
			output.write_string(value.substr_unsafe(copied, start + 2))
			output.write_u8(`x`)
			copied = start + 3
		} else if !name.starts_with('#') && name !in vxml.default_entities {
			decoded := context.html_entity(name)!
			if expand_html {
				output.write_string(value.substr_unsafe(copied, start))
				output.write_string(xml_numeric_references(decoded))
				copied = end + 1
			}
		}
		position = end + 1
	}
	if copied == 0 { return value }
	output.write_string(value.substr_unsafe(copied, value.len))
	return output.str()
}

fn expand_html_references(value string, mut context XMLReferenceContext) !string {
	return prepare_references(value, mut context, true)
}

fn decode_references(value string, mut context XMLReferenceContext) !string {
	if !value.contains_u8(`&`) { return value }
	for index, previous in context.recent_references {
		if value == previous {
			return context.recent_replacements[index]
		}
	}
	prepared := prepare_references(value, mut context, false)!
	decoded := if entities := context.entities {
		vxml.unescape_text(prepared, entities: entities)!
	} else {
		vxml.unescape_text(prepared)!
	}
	context.recent_references[context.next_reference] = value
	context.recent_replacements[context.next_reference] = decoded
	context.next_reference = (context.next_reference + 1) % context.recent_references.len
	return decoded
}

// Ordinary inline values need no side table. Scan each short value once.
fn xml_attribute_needs_marker(value string) bool {
	if value.len > 64 || (value.len > 0 && value[0] == `@`) {
		return true
	}
	for byte in value {
		if xml_is_space(byte) || byte == `&` || byte == `>` {
			return true
		}
	}
	return false
}

// vlib currently stops tags at the first '>', requires a quote immediately
// after '=', and requires closing tags without trailing whitespace. Normalize
// just these lexical forms; attribute parsing and duplicate detection stay in
// vlib. Quoted contents remain opaque to the markup scanner.
fn xml_normalize_tag(tag string, mut references XMLReferenceContext, mut attribute_values []string, declaration bool) !string {
	if tag.starts_with('</') {
		mut end := tag.len - 1
		for end > 0 && xml_is_space(tag[end - 1]) { end-- }
		if end == tag.len - 1 { return tag }
		return tag[..end] + '>'
	}
	// Most tags already have vlib-compatible syntax. Allocate a replacement
	// only when a value or whitespace actually needs normalization. Borrowed
	// spans are consumed synchronously; side-table values take owning copies.
	mut output := strings.new_builder(0)
	mut position := 0
	mut copied := 0
	for position < tag.len {
		byte := tag[position]
		position++
		if byte in [`'`, `"`] {
			start := position
			end := tag.substr_unsafe(position, tag.len).index_u8(byte)
			if end < 0 {
				return error('unterminated XML attribute value')
			}
			position += end
			value := tag.substr_unsafe(start, position)
			if value.contains_u8(`<`) { return error('XML attribute values may not contain <') }
			if !declaration && xml_attribute_needs_marker(value) {
				// Keep long SVG paths and decoded values out of vlib's byte-by-byte
				// scan. vlib still parses attribute syntax and rejects duplicate
				// names. The owning payload survives DOM mapping.
				output.write_string(tag.substr_unsafe(copied, start))
				output.write_u8(`@`)
				output.write_decimal(attribute_values.len)
				attribute_values << if value.contains_u8(`&`) {
					decode_references(value, mut references)!
				} else {
					value.clone()
				}
				copied = position
			} else if declaration && value.contains_any('&>') {
				expanded := expand_html_references(value, mut references)!
				output.write_string(tag.substr_unsafe(copied, start))
				output.write_string(if expanded.contains('>') {
					expanded.replace('>', '&gt;')
				} else {
					expanded
				})
				copied = position
			}
			position++
		} else if byte == `=` {
			start := position
			for position < tag.len && xml_is_space(tag[position]) {
				position++
			}
			if position != start {
				output.write_string(tag.substr_unsafe(copied, start))
				copied = position
			}
		}
	}
	if copied == 0 { return tag }
	output.write_string(tag.substr_unsafe(copied, tag.len))
	return output.str()
}

// Return the closing '>' and the start of an optional internal DTD subset.
// Internal subsets remain inert, as in the previous browser parser. In
// particular, external resources and DTD entity declarations are not loaded.
fn xml_markup_end(source string, start int, doctype bool) !(int, int) {
	mut position := start + 1
	mut depth := 0
	mut subset := -1
	for position < source.len {
		byte := source[position]
		if byte in [`'`, `"`] {
			closing := source.substr_unsafe(position + 1, source.len).index_u8(byte)
			if closing < 0 { return error('unterminated XML markup') }
			position += closing + 2
			continue
		} else if doctype && xml_has_prefix(source, position, '<!--') {
			position = (source.index_after('-->', position + 4) or {
				return error('unterminated XML doctype comment')
			}) + 3
			continue
		} else if doctype && byte == `[` {
			if subset < 0 { subset = position }
			depth++
		} else if doctype && byte == `]` {
			depth--
			if depth < 0 { return error('invalid XML doctype subset') }
		} else if byte == `>` && depth == 0 {
			return position, subset
		}
		position++
	}
	return error('unterminated XML markup')
}

// Adapt features not represented by vlib's XML tree, without implementing a
// second element parser. A synthetic root retains prolog/epilog order and lets
// us validate the entire input. Author comments that resemble a marker are
// escaped through the same side table, so they cannot impersonate other nodes.
fn write_special_node_marker(mut output strings.Builder, index int) {
	output.write_string('<!--!')
	output.write_decimal(index)
	output.write_string('-->')
}

fn xml_prepare_source(input string, resolve_entity EntityResolver) !XMLPreparedSource {
	source := if input.starts_with('\xef\xbb\xbf') { input[3..] } else { input }
	marker := '!'
	mut output := strings.new_builder(if source.len < 4096 { source.len } else { 4096 })
	output.write_string('<vox-xml-document>')
	mut declaration := ''
	mut special_nodes := []SpecialNode{}
	mut attribute_values := []string{}
	mut references := XMLReferenceContext{ resolve_entity: resolve_entity }
	mut position := 0
	mut depth := 0
	mut saw_element := false
	mut saw_doctype := false
	for position < source.len {
		if source[position] != `<` {
			start := position
			next_markup := source.substr_unsafe(position, source.len).index_u8(`<`)
			position = if next_markup < 0 { source.len } else { position + next_markup }
			text := source.substr_unsafe(start, position)
			if depth == 0 {
				if !xml_is_only_space(text) {
					return error('text outside the XML document element')
				}
				continue
			}
			if text.contains(']]>') { return error('CDATA terminator in XML text') }
			if text.len > 64 || text.contains_any('&\r') || xml_is_space(text[0]) || xml_is_space(text[text.len - 1]) {
				// Preserve text verbatim without expanding each whitespace byte
				// into a reference. That expansion sorted every whitespace match
				// and made vlib allocate an entity buffer for every single space.
				write_special_node_marker(mut output, special_nodes.len)
				special_nodes << SpecialNode{
					is_text: true
					data:    if text.contains_u8(`&`) {
						decode_references(text, mut references)!
					} else {
						text.clone()
					}
				}
			} else {
				output.write_string(text)
			}
			continue
		}
		if xml_has_prefix(source, position, '<!--') {
			end := source.index_after('-->', position + 4) or { return error('unterminated XML comment') }
			data := source.substr_unsafe(position + 4, end)
			if data.contains('--') || data.ends_with('-') { return error('invalid XML comment') }
			if data.starts_with(marker) || data.len > 64 {
				write_special_node_marker(mut output, special_nodes.len)
				special_nodes << SpecialNode{ is_comment: true, data: data.clone() }
			} else {
				output.write_string(source.substr_unsafe(position, end + 3))
			}
			position = end + 3
			continue
		}
		if xml_has_prefix(source, position, '<![CDATA[') {
			if depth == 0 { return error('CDATA outside the XML document element') }
			end := source.index_after(']]>', position + 9) or { return error('unterminated CDATA section') }
			write_special_node_marker(mut output, special_nodes.len)
			special_nodes << SpecialNode{ is_cdata: true, data: source.substr_unsafe(position + 9, end).clone() }
			position = end + 3
			continue
		}
		if xml_has_prefix(source, position, '<?') {
			end := source.index_after('?>', position + 2) or { return error('unterminated XML processing instruction') }
			mut target_end := position + 2
			for target_end < end && !xml_is_space(source[target_end]) { target_end++ }
			target := source[position + 2..target_end]
			check_name(target)!
			if target.len == 3 && target.to_lower() == 'xml' {
				if target != 'xml' || target_end == end || !xml_is_only_space(source[..position]) {
					return error('XML declaration is only permitted at the beginning of the document')
				}
				declaration = xml_normalize_tag(source[position..end + 2], mut references, mut attribute_values, true)!
			} else {
				write_special_node_marker(mut output, special_nodes.len)
				special_nodes << SpecialNode{ target: target, data: source[target_end..end].trim_space() }
			}
			position = end + 2
			continue
		}
		is_doctype := xml_has_prefix(source, position, '<!DOCTYPE')
		end, subset := xml_markup_end(source, position, is_doctype)!
		if is_doctype {
			if depth != 0 || saw_element || saw_doctype || position + 9 >= source.len || !xml_is_space(source[position + 9]) {
				return error('invalid XML doctype position')
			}
			header_end := if subset >= 0 { subset } else { end }
			header := source[position..header_end] + '>'
			parsed := vxml.XMLDocument.from_string(header + '<vox-xml-doctype/>')!
			check_name(parsed.doctype.name)!
			write_special_node_marker(mut output, special_nodes.len)
			special_nodes << SpecialNode{ doctype: parsed.doctype }
			saw_doctype = true
		} else {
			// The tag is used only during normalization. Attribute payloads take
			// their own copies, so borrowing this scan avoids duplicating a large
			// SVG path before extracting its owning value.
			tag := source.substr_unsafe(position, end + 1)
			if tag.starts_with('<!') { return error('unsupported XML declaration') }
			if tag.len < 3 || xml_is_space(tag[1]) { return error('invalid XML opening tag') }
			if !tag.ends_with('/>') {
				mut last := tag.len - 2
				for last > 0 && xml_is_space(tag[last]) { last-- }
				if tag[last] == `/` { return error('whitespace in XML empty-element delimiter') }
			}
			if tag.starts_with('</') {
				depth--
				if depth < 0 { return error('unexpected XML closing tag') }
			} else {
				saw_element = true
				if !tag.ends_with('/>') { depth++ }
			}
			output.write_string(xml_normalize_tag(tag, mut references, mut attribute_values, false)!)
		}
		position = end + 1
	}
	if depth != 0 { return error('unclosed XML document element') }
	output.write_string('</vox-xml-document>')
	normalized := output.str()
	return XMLPreparedSource{
		source:           if declaration == '' { normalized } else { declaration + normalized }
		marker:           marker
		special_nodes:    special_nodes
		attribute_values: attribute_values
	}
}

@[heap]
struct XMLLiteralParseState {
mut:
	special_nodes []SpecialNode
}

fn (mut state XMLLiteralParseState) inline_markup(source string, start int) !vxml.XMLInlineMarkupResult {
	if xml_has_prefix(source, start, '<!--') {
		end := source.index_after('-->', start + 4) or { return error('unterminated XML comment') }
		data := source.substr_unsafe(start + 4, end)
		if data.contains('--') || data.ends_with('-') { return error('invalid XML comment') }
		if !data.starts_with('!') {
			return vxml.XMLInlineMarkupResult{node: vxml.XMLComment{data.clone()}, end: end + 3}
		}
		index := state.special_nodes.len
		state.special_nodes << SpecialNode{ is_comment: true, data: data.clone() }
		return vxml.XMLInlineMarkupResult{node: vxml.XMLComment{'!${index}'}, end: end + 3}
	}
	if xml_has_prefix(source, start, '<![CDATA[') {
		end := source.index_after(']]>', start + 9) or { return error('unterminated CDATA') }
		return vxml.XMLInlineMarkupResult{node: vxml.XMLCData{source[start + 9..end]}, end: end + 3}
	}
	if xml_has_prefix(source, start, '<?') {
		end := source.index_after('?>', start + 2) or { return error('unterminated XML processing instruction') }
		mut target_end := start + 2
		for target_end < end && !xml_is_space(source[target_end]) { target_end++ }
		target := source[start + 2..target_end]
		check_name(target)!
		if target.len == 3 && target.to_lower() == 'xml' {
			return error('XML declaration is only permitted at the beginning of the document')
		}
		index := state.special_nodes.len
		state.special_nodes << SpecialNode{ target: target, data: source[target_end..end].trim_space() }
		return vxml.XMLInlineMarkupResult{node: vxml.XMLComment{'!${index}'}, end: end + 2}
	}
	return error('unsupported inline XML declaration')
}

// Try the standard cursor directly when the root and payload need no
// normalization. Complex inputs use the existing compatibility scanner.
fn xml_parse_literal_document(source string, borrow_text bool) ?Document {
	// Large payloads already take the compatibility scanner's bulk text path.
	if source.len > 256 * 1024 || !source.starts_with('<') || source.len < 3
		|| source[1] in [`/`, `!`, `?`]
		|| source.contains_u8(`&`) {
		return none
	}
	mut state := ?&XMLLiteralParseState(none)
	mut handler := ?vxml.XMLInlineMarkup(none)
	// An inline declaration or processing instruction requires one of these
	// bytes. Plain documents can skip allocating a callback and its state.
	if source.contains_u8(`!`) || source.contains_u8(`?`) {
		mut inline_state := &XMLLiteralParseState{}
		callback := fn [mut inline_state] (input string, start int) !vxml.XMLInlineMarkupResult {
			return inline_state.inline_markup(input, start)
		}
		state = inline_state
		handler = callback
	}
	parsed, consumed := vxml.XMLDocument.from_string_with_consumed(source,
		preserve_text: true
		strict_markup: true
		inline_markup: handler
		borrow_text:   borrow_text
	) or { return none }
	if !xml_is_only_space(source.substr_unsafe(consumed, source.len)) {
		return none
	}
	return Document{
		children:      [vxml.XMLNodeContents(parsed.root)]
		marker:        '!'
		special_nodes: if inline_state := state {
			inline_state.special_nodes
		} else {
			[]SpecialNode{}
		}
	}
}

// parse reads the entire XML document using vlib. The returned children retain
// document order. Resolve marked comments through special_node and attributes
// through attribute_value before consuming the tree. Large/verbatim payloads
// bypass vlib's per-byte reader, while structure and reference decoding still
// use the standard XML module.
@[params]
pub struct ParseOptions {
pub:
	// Plain character data and ASCII attribute values may borrow this input.
	// Keep the input alive until consumers finish reading or copy the values.
	borrow_text bool
}

pub fn parse(source string, resolve_entity EntityResolver, options ParseOptions) !Document {
	if literal := xml_parse_literal_document(source, options.borrow_text) {
		return literal
	}
	prepared := xml_prepare_source(source, resolve_entity)!
	parsed, consumed := vxml.XMLDocument.from_string_with_consumed(prepared.source, preserve_text: true)!
	if consumed != prepared.source.len {
		return error('content after the XML document element')
	}
	mut roots := 0
	for child in parsed.root.children {
		if child is vxml.XMLNode { roots++ }
	}
	if roots != 1 { return error('XML document must have exactly one document element') }
	return Document{
		children:         parsed.root.children
		marker:           prepared.marker
		special_nodes:    prepared.special_nodes
		attribute_values: prepared.attribute_values
	}
}
