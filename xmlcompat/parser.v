// Copyright (c) 2026, Ladybird contributors
// SPDX-License-Identifier: BSD-2-Clause

// Browser input compatibility for V's standard XML parser. This module owns
// no element parser or DOM; vlib validates and constructs the XML tree.
module xmlcompat

import encoding.xml as vxml
import io
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
}

// Only marked attribute values are indirect. Short ordinary values stay in
// vlib's tree, avoiding a side-table lookup on the common small-SVG path.
pub fn (document &Document) attribute_value(value string) !string {
	if !value.starts_with('@') { return value }
	index := value.substr_unsafe(1, value.len).int()
	if index < 0 || index >= document.attribute_values.len {
		return error('invalid XML attribute marker')
	}
	return document.attribute_values[index]
}

pub fn (document &Document) special_node(comment vxml.XMLComment) ?SpecialNode {
	if !comment.text.starts_with(document.marker) { return none }
	index := comment.text.substr_unsafe(document.marker.len, comment.text.len).int()
	return document.special_nodes[index] or { none }
}

struct XMLSourceReader {
	source string
mut:
	position int
}

fn (mut reader XMLSourceReader) read(mut buffer []u8) !int {
	if reader.position == reader.source.len {
		return io.Eof{}
	}
	remaining := reader.source.len - reader.position
	count := if buffer.len < remaining { buffer.len } else { remaining }
	for index in 0 .. count {
		buffer[index] = reader.source[reader.position + index]
	}
	reader.position += count
	return count
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
	if !value.contains('&') { return value }
	prepared := prepare_references(value, mut context, false)!
	if entities := context.entities {
		return vxml.unescape_text(prepared, entities: entities)
	}
	return vxml.unescape_text(prepared)
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
			for position < tag.len && tag[position] != byte {
				position++
			}
			if position == tag.len {
				return error('unterminated XML attribute value')
			}
			value := tag.substr_unsafe(start, position)
			if value.contains('<') { return error('XML attribute values may not contain <') }
			if !declaration && (value.len > 64 || value.contains_any(' \t\r\n&>') || value.starts_with('@')) {
				// Keep long SVG paths and decoded values out of vlib's byte-by-byte
				// scan. vlib still parses attribute syntax and rejects duplicate
				// names. The owning payload survives DOM mapping.
				output.write_string(tag.substr_unsafe(copied, start))
				output.write_string('@${attribute_values.len}')
				attribute_values << if value.contains('&') {
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
	mut quote := u8(0)
	mut depth := 0
	mut subset := -1
	for position < source.len {
		byte := source[position]
		if quote != 0 {
			if byte == quote { quote = 0 }
		} else if byte in [`'`, `"`] {
			quote = byte
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
			for position < source.len && source[position] != `<` { position++ }
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
				output.write_string('<!--${marker}${special_nodes.len}-->')
				special_nodes << SpecialNode{
					is_text: true
					data:    if text.contains('&') {
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
				output.write_string('<!--${marker}${special_nodes.len}-->')
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
			output.write_string('<!--${marker}${special_nodes.len}-->')
			special_nodes << SpecialNode{ is_cdata: true, data: source[position + 9..end] }
			position = end + 3
			continue
		}
		if xml_has_prefix(source, position, '<?') {
			end := source.index_after('?>', position + 2) or { return error('unterminated XML processing instruction') }
			mut target_end := position + 2
			for target_end < end && !xml_is_space(source[target_end]) { target_end++ }
			target := source[position + 2..target_end]
			check_name(target)!
			if target.to_lower() == 'xml' {
				if target != 'xml' || target_end == end || !xml_is_only_space(source[..position]) {
					return error('XML declaration is only permitted at the beginning of the document')
				}
				declaration = xml_normalize_tag(source[position..end + 2], mut references, mut attribute_values, true)!
			} else {
				output.write_string('<!--${marker}${special_nodes.len}-->')
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
			output.write_string('<!--${marker}${special_nodes.len}-->')
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

// parse reads the entire XML document using vlib. The returned children retain
// document order. Resolve marked comments through special_node and attributes
// through attribute_value before consuming the tree. Large/verbatim payloads
// bypass vlib's per-byte reader, while structure and reference decoding still
// use the standard XML module.
pub fn parse(source string, resolve_entity EntityResolver) !Document {
	prepared := xml_prepare_source(source, resolve_entity)!
	// Keep the reader by reference: converting a value to io.Reader would copy
	// its position, defeating the whole-input consumption check below.
	mut reader := &XMLSourceReader{ source: prepared.source }
	parsed := vxml.XMLDocument.from_reader(mut reader)!
	if reader.position != prepared.source.len {
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
