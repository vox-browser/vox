// Copyright (c) 2026, Ladybird contributors
// SPDX-License-Identifier: BSD-2-Clause

// Browser input compatibility for V's standard XML parser. This module owns
// no element parser or DOM; vlib validates and constructs the XML tree.
module xmlcompat

import encoding.xml as vxml
import io
import strings

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

// Only marked attribute values are indirect. Short ordinary values stay in
// vlib's tree, avoiding a side-table lookup on the common small-SVG path.
pub fn (document &Document) attribute_value(value string) !string {
	if !value.starts_with('@') { return value }
	index := value[1..].int()
	if index < 0 || index >= document.attribute_values.len {
		return error('invalid XML attribute marker')
	}
	return document.attribute_values[index]
}

pub fn (document &Document) special_node(comment vxml.XMLComment) ?SpecialNode {
	if !comment.text.starts_with(document.marker) { return none }
	index := comment.text[document.marker.len..].int()
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
	if name == '' || name.starts_with(':') || name.ends_with(':') || name.count(':') > 1 {
		return error('invalid qualified XML name ${name}')
	}
	for index, byte in name {
		if byte == `:` || byte == `_` || byte >= 0x80 || (byte >= `A` && byte <= `Z`)
			|| (byte >= `a` && byte <= `z`) || (index > 0 && ((byte >= `0` && byte <= `9`) || byte in [
			`-`,
			`.`,
		])) {
			continue
		}
		return error('invalid qualified XML name ${name}')
	}
}

// Keep the browser's HTML entity vocabulary while letting vlib decode and
// validate all character references. Numeric replacements are not decoded a
// second time, even when an entity's value contains an ampersand.
fn expand_html_references(value string, resolve_entity EntityResolver) !string {
	if !value.contains('&') {
		return value
	}
	mut output := strings.new_builder(value.len)
	mut position := 0
	for position < value.len {
		if value[position] != `&` {
			output.write_u8(value[position])
			position++
			continue
		}
		end := value.index_after(';', position + 1) or {
			return error('unterminated XML entity reference')
		}
		name := value[position + 1..end]
		if name.starts_with('#') || name in vxml.default_entities {
			// The previous browser parser also accepted uppercase hexadecimal X.
			output.write_string(if name.starts_with('#X') {
				'&#x${name[2..]};'
			} else {
				value[position..end + 1]
			})
		} else {
			decoded := resolve_entity(name) or {
				return error('unknown XML entity &${name};')
			}
			for character in decoded.runes() {
				output.write_string('&#${int(character)};')
			}
		}
		position = end + 1
	}
	return output.str()
}

fn decode_references(value string, resolve_entity EntityResolver) !string {
	if !value.contains('&') { return value }
	return vxml.unescape_text(expand_html_references(value, resolve_entity)!)
}

// vlib currently stops tags at the first '>', requires a quote immediately
// after '=', and requires closing tags without trailing whitespace. Normalize
// just these lexical forms; attribute parsing and duplicate detection stay in
// vlib. Quoted contents remain opaque to the markup scanner.
fn xml_normalize_tag(tag string, resolve_entity EntityResolver, mut attribute_values []string, declaration bool) !string {
	if tag.starts_with('</') {
		return tag[..tag.len - 1].trim_right(' \t\r\n') + '>'
	}
	mut output := strings.new_builder(if tag.len < 256 { tag.len } else { 256 })
	mut position := 0
	for position < tag.len {
		byte := tag[position]
		output.write_u8(byte)
		position++
		if byte in [`'`, `"`] {
			start := position
			for position < tag.len && tag[position] != byte {
				position++
			}
			if position == tag.len {
				return error('unterminated XML attribute value')
			}
			value := tag[start..position]
			if value.contains('<') { return error('XML attribute values may not contain <') }
			if !declaration && (value.len > 64 || value.contains_any(' \t\r\n&>') || value.starts_with('@')) {
				// vlib scans attributes byte by byte and splits the entire tag on
				// whitespace to find its name. Keep long SVG paths and decoded
				// values out of that scan; vlib still parses attribute syntax and
				// rejects duplicate names. The owning payload survives DOM mapping.
				output.write_string('@${attribute_values.len}')
				attribute_values << decode_references(value, resolve_entity)!
			} else {
				expanded := expand_html_references(value, resolve_entity)!
				output.write_string(if expanded.contains('>') {
					expanded.replace('>', '&gt;')
				} else {
					expanded
				})
			}
			output.write_u8(byte)
			position++
		} else if byte == `=` {
			for position < tag.len && xml_is_space(tag[position]) {
				position++
			}
		}
	}
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
	mut position := 0
	mut depth := 0
	mut saw_element := false
	mut saw_doctype := false
	for position < source.len {
		if source[position] != `<` {
			start := position
			for position < source.len && source[position] != `<` { position++ }
			text := source[start..position]
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
				special_nodes << SpecialNode{ is_text: true, data: decode_references(text, resolve_entity)! }
			} else {
				output.write_string(text)
			}
			continue
		}
		if xml_has_prefix(source, position, '<!--') {
			end := source.index_after('-->', position + 4) or { return error('unterminated XML comment') }
			data := source[position + 4..end]
			if data.contains('--') || data.ends_with('-') { return error('invalid XML comment') }
			if data.starts_with(marker) || data.len > 64 {
				output.write_string('<!--${marker}${special_nodes.len}-->')
				special_nodes << SpecialNode{ is_comment: true, data: data }
			} else {
				output.write_string(source[position..end + 3])
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
				declaration = xml_normalize_tag(source[position..end + 2], resolve_entity, mut attribute_values, true)!
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
			if !tag.ends_with('/>') && tag[..tag.len - 1].trim_right(' \t\r\n').ends_with('/') {
				return error('whitespace in XML empty-element delimiter')
			}
			if tag.starts_with('</') {
				depth--
				if depth < 0 { return error('unexpected XML closing tag') }
			} else {
				saw_element = true
				if !tag.ends_with('/>') { depth++ }
			}
			output.write_string(xml_normalize_tag(tag, resolve_entity, mut attribute_values, false)!)
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
