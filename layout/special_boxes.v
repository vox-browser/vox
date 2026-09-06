// Copyright (c) 2018-2026, Ladybird contributors
//
// SPDX-License-Identifier: BSD-2-Clause
module layout

import css
import dom
import encoding.base64
import html
import math
import os
import platform
import stbi
import strconv
import svg
import url

fn special_box_base(document &dom.Document, dom_node ?&dom.Node, computed_values &css.ComputedProperties) Box {
	return Box{
		NodeWithStyleAndBoxModelMetrics: NodeWithStyleAndBoxModelMetrics{
			NodeWithStyle: NodeWithStyle{
				Node: Node{
					document_: document
					dom_node_: dom_node
					has_style_: true
					is_box_: true
				}
				computed_values_: css.resolve_computed_values_for_document(computed_values, document)
			}
		}
	}
}

fn special_block_container_base(document &dom.Document, dom_node ?&dom.Node, computed_values &css.ComputedProperties) BlockContainer {
	mut box := special_box_base(document, dom_node, computed_values)
	box.is_block_container_ = true
	return BlockContainer{
		Box: box
	}
}

fn replaced_box_base(document &dom.Document, element &dom.Element, computed_values &css.ComputedProperties) ReplacedBox {
	mut box := special_box_base(document, element.as_node(), computed_values)
	box.is_replaced_box_ = true
	box.has_auto_content_box_size_ = true
	return ReplacedBox{
		Box: box
	}
}

fn generated_replaced_box_base(document &dom.Document, computed_values &css.ComputedProperties) ReplacedBox {
	mut box := special_box_base(document, none, computed_values)
	box.is_replaced_box_ = true
	box.has_auto_content_box_size_ = true
	return ReplacedBox{
		Box: box
	}
}

fn size_with_optional_aspect_ratio(width CSSPixels, height CSSPixels) css.SizeWithAspectRatio {
	mut aspect_ratio := ?css.CSSPixelFraction(none)
	if width.raw_value() > 0 && height.raw_value() > 0 {
		aspect_ratio = CSSPixelFraction.new(width, height)
	}
	return css.SizeWithAspectRatio{
		width: width
		height: height
		aspect_ratio: aspect_ratio
	}
}

@[heap]
pub struct ReplacedBox {
	Box
}

pub fn ReplacedBox.new(document &dom.Document, element &dom.Element, computed_values &css.ComputedProperties) &ReplacedBox {
	return &ReplacedBox{
		Box: replaced_box_base(document, element, computed_values).Box
	}
}

// Layout::NavigableContainerViewport. The DOM port does not yet attach a
// concrete DOM::Document to HTML's metadata-only NavigableContainer model, so
// retain the active about:blank/srcdoc document on the layout box itself.
@[heap]
pub struct NavigableContainerViewport {
	ReplacedBox
mut:
	content_document_ &dom.Document = unsafe { nil }
}

pub fn NavigableContainerViewport.new(document &dom.Document, element &dom.Element, computed_values &css.ComputedProperties) &NavigableContainerViewport {
	source := element.get_attribute('srcdoc') or { '' }
	mut box := &NavigableContainerViewport{
		ReplacedBox: replaced_box_base(document, element, computed_values)
		content_document_: html.parse_document(source)
	}
	box.is_navigable_container_viewport_ = true
	return box
}

pub fn (box &NavigableContainerViewport) content_document() &dom.Document {
	return box.content_document_
}

@[heap]
pub struct CheckBox {
	ReplacedBox
}

pub fn CheckBox.new(document &dom.Document, element &dom.Element, computed_values &css.ComputedProperties) &CheckBox {
	mut box := &CheckBox{
		ReplacedBox: replaced_box_base(document, element, computed_values)
	}
	box.has_auto_content_box_size_ = true
	box.auto_content_box_size_ = css.SizeWithAspectRatio{
		width: CSSPixels.new(13)
		height: CSSPixels.new(13)
	}
	return box
}

@[heap]
pub struct RadioButton {
	ReplacedBox
}

pub fn RadioButton.new(document &dom.Document, element &dom.Element, computed_values &css.ComputedProperties) &RadioButton {
	mut box := &RadioButton{
		ReplacedBox: replaced_box_base(document, element, computed_values)
	}
	box.has_auto_content_box_size_ = true
	box.auto_content_box_size_ = css.SizeWithAspectRatio{
		width: CSSPixels.new(12)
		height: CSSPixels.new(12)
	}
	return box
}

@[heap]
pub struct CanvasBox {
	ReplacedBox
}

pub fn CanvasBox.new(document &dom.Document, element &dom.Element, computed_values &css.ComputedProperties) &CanvasBox {
	width := nonnegative_integer_attribute_or_default(element, 'width', 300)
	height := nonnegative_integer_attribute_or_default(element, 'height', 150)
	mut box := &CanvasBox{
		ReplacedBox: replaced_box_base(document, element, computed_values)
	}
	box.auto_content_box_size_ = size_with_optional_aspect_ratio(CSSPixels.new(width), CSSPixels.new(height))
	return box
}

@[heap]
pub struct ImageBox {
	ReplacedBox
pub mut:
	renders_as_alt_text_ bool
mut:
	svg_image_document_ ?&dom.Document
	source_             string
}

fn image_alt_text_natural_size(alt string) css.SizeWithAspectRatio {
	if alt.len == 0 {
		return css.SizeWithAspectRatio{
			width: CSSPixels.new(0)
			height: CSSPixels.new(0)
		}
	}
	font := &platform.Font{
		family: 'sans-serif'
		point_size: 12
	}
	alt_text_width := CSSPixels.nearest_value_for(platform.shape_text(0, 0, alt, font, .context_dependent).width())
	width := alt_text_width.plus(CSSPixels.new(16))
	height := CSSPixels.nearest_value_for(font.pixel_metrics().size).plus(CSSPixels.new(16))
	return size_with_optional_aspect_ratio(width, height)
}

pub fn ImageBox.new(document &dom.Document, element &dom.Element, computed_values &css.ComputedProperties) &ImageBox {
	alt := element.get_attribute_value('alt')
	mut box := &ImageBox{
		ReplacedBox: replaced_box_base(document, element, computed_values)
		renders_as_alt_text_: true
	}
	box.is_image_box_ = true
	mut source := element.get_attribute_value('src')
	srcset := element.get_attribute_value('srcset')
	if srcset.len > 0 {
		sizes := element.get_attribute_value('sizes').trim_space().to_lower()
		source_size := if sizes.ends_with('px') {
			sizes[..sizes.len - 2].f64()
		} else {
			100.0
		}
		source_set := html.create_source_set(source, srcset, source_size)
		if !source_set.is_empty() {
			source = source_set.select_an_image_source().source.url
		}
	}
	box.source_ = source
	if intrinsic_size := image_intrinsic_size_for_source(document, source) {
		box.renders_as_alt_text_ = false
		box.natural_size_ = intrinsic_size
	} else {
		box.natural_size_ = image_alt_text_natural_size(alt)
	}
	box.svg_image_document_ = svg_image_document_for_source(document, source)
	box.auto_content_box_size_ = box.natural_size_
	return box
}

pub fn ImageBox.new_generated(document &dom.Document, computed_values &css.ComputedProperties, source string) &ImageBox {
	mut box := &ImageBox{
		ReplacedBox: generated_replaced_box_base(document, computed_values)
		renders_as_alt_text_: true
		source_: source
	}
	box.is_image_box_ = true
	if intrinsic_size := image_intrinsic_size_for_source(document, source) {
		box.renders_as_alt_text_ = false
		box.natural_size_ = intrinsic_size
	} else {
		box.natural_size_ = css.SizeWithAspectRatio{
			width: CSSPixels.new(0)
			height: CSSPixels.new(0)
		}
	}
	box.svg_image_document_ = svg_image_document_for_source(document, source)
	box.auto_content_box_size_ = box.natural_size_
	return box
}

struct SVGImageSource {
	source string
	url    dom.URL
}

fn svg_image_source_for_source(document &dom.Document, source string) ?SVGImageSource {
	if source.len == 0 {
		return none
	}
	trimmed_source := source.trim_space()
	parsed_url := document.encoding_parse_url(trimmed_source) or { return none }
	serialized := parsed_url.serialize()
	if serialized.starts_with('data:') {
		comma := serialized.index(',') or { return none }
		metadata := serialized[..comma].to_lower()
		if !metadata.starts_with('data:image/svg+xml') {
			return none
		}
		payload := serialized[comma + 1..]
		data := if metadata.ends_with(';base64') {
			decoded_payload := url.percent_decode(payload).bytestr()
			mut compact_payload := []u8{cap: decoded_payload.len}
			for byte in decoded_payload.bytes() {
				if byte !in [u8(` `), u8(`\t`), u8(`\n`), u8(`\r`), u8(`\f`)] {
					compact_payload << byte
				}
			}
			for compact_payload.len % 4 != 0 {
				compact_payload << u8(`=`)
			}
			base64.decode(compact_payload.bytestr())
		} else {
			url.percent_decode(payload)
		}
		if data.len == 0 {
			return none
		}
		return SVGImageSource{
			source: data.bytestr()
			url: parsed_url
		}
	}
	mut path := serialized
	if serialized.starts_with('file://') {
		path = url.percent_decode(serialized['file://'.len..]).bytestr()
	} else if serialized.contains('://') {
		return none
	}
	if !path.to_lower().ends_with('.svg') || !os.is_file(path) {
		return none
	}
	return SVGImageSource{
		source: os.read_file(path) or { return none }
		url: parsed_url
	}
}

fn svg_image_document_for_source(document &dom.Document, source string) ?&dom.Document {
	image_source := svg_image_source_for_source(document, source) or { return none }
	mut svg_document := dom.Document.create(image_source.url)
	svg_document.set_content_type('image/svg+xml')
	svg_document.set_document_type(.xml)
	svg_document.set_is_svg_image_document(true)
	html.parse_xml_document_source(svg_document, image_source.source) or { return none }
	return svg_document
}

fn image_intrinsic_size_for_source(document &dom.Document, source string) ?css.SizeWithAspectRatio {
	if source.len == 0 {
		return none
	}
	trimmed_source := source.trim_space()
	serialized := if trimmed_source.starts_with('data:') {
		trimmed_source
	} else {
		parsed := document.encoding_parse_url(source) or { return none }
		parsed.serialize()
	}
	if serialized.starts_with('data:') {
		comma := serialized.index(',') or { return none }
		metadata := serialized[..comma].to_lower()
		payload := serialized[comma + 1..]
		data := if metadata.ends_with(';base64') {
			// Fetch's data: URL processor percent-decodes the body and forgiving-
			// base64 decoding discards ASCII whitespace.
			decoded_payload := url.percent_decode(payload).bytestr()
			mut compact_payload := []u8{cap: decoded_payload.len}
			for byte in decoded_payload.bytes() {
				if byte !in [u8(` `), u8(`\t`), u8(`\n`), u8(`\r`), u8(`\f`)] {
					compact_payload << byte
				}
			}
			// Infra forgiving-base64 decode accepts omitted trailing padding.
			for compact_payload.len % 4 != 0 {
				compact_payload << u8(`=`)
			}
			base64.decode(compact_payload.bytestr())
		} else {
			url.percent_decode(payload)
		}
		if data.len == 0 {
			return none
		}
		if metadata.starts_with('data:image/svg+xml') {
			return svg_image_natural_size(data.bytestr())
		}
		if data.len >= 6 && data[..3].bytestr() == 'GIF' && !gif_image_data_is_decodable(data) {
			return none
		}
		image := stbi.load_from_memory(data.data, data.len) or {
			dimensions := encoded_image_dimensions(data) or { return none }
			return size_with_optional_aspect_ratio(CSSPixels.new(dimensions.width), CSSPixels.new(dimensions.height))
		}
		defer {
			image.free()
		}
		if image.width <= 0 || image.height <= 0 {
			return none
		}
		return size_with_optional_aspect_ratio(CSSPixels.new(image.width), CSSPixels.new(image.height))
	}
	mut path := serialized
	if serialized.starts_with('file://') {
		path = url.percent_decode(serialized['file://'.len..]).bytestr()
	} else if serialized.contains('://') {
		return none
	}
	if !os.is_file(path) {
		return none
	}
	if path.to_lower().ends_with('.svg') {
		svg_source := os.read_file(path) or { return none }
		return svg_image_natural_size(svg_source)
	}
	data_for_validation := os.read_bytes(path) or { return none }
	if data_for_validation.len >= 6 && data_for_validation[..3].bytestr() == 'GIF' && !gif_image_data_is_decodable(data_for_validation) {
		return none
	}
	image := stbi.load(path) or {
		dimensions := encoded_image_dimensions(data_for_validation) or { return none }
		return size_with_optional_aspect_ratio(CSSPixels.new(dimensions.width), CSSPixels.new(dimensions.height))
	}
	defer {
		image.free()
	}
	if image.width <= 0 || image.height <= 0 {
		return none
	}
	return size_with_optional_aspect_ratio(CSSPixels.new(image.width), CSSPixels.new(image.height))
}

fn xml_start_tag_attribute(tag string, requested_name string) ?string {
	mut position := 0
	for position < tag.len && tag[position] != `<` {
		position++
	}
	if position >= tag.len {
		return none
	}
	position++
	for position < tag.len && tag[position] !in [` `, `\t`, `\n`, `\r`, `>`, `/`] {
		position++
	}
	for position < tag.len {
		for position < tag.len && tag[position] in [` `, `\t`, `\n`, `\r`] {
			position++
		}
		if position >= tag.len || tag[position] in [`>`, `/`] {
			return none
		}
		name_start := position
		for position < tag.len && tag[position] !in [` `, `\t`, `\n`, `\r`, `=`, `>`, `/`] {
			position++
		}
		name := tag[name_start..position]
		for position < tag.len && tag[position] in [` `, `\t`, `\n`, `\r`] {
			position++
		}
		if position >= tag.len || tag[position] != `=` {
			continue
		}
		position++
		for position < tag.len && tag[position] in [` `, `\t`, `\n`, `\r`] {
			position++
		}
		if position >= tag.len || tag[position] !in [`'`, `"`] {
			continue
		}
		quote := tag[position]
		position++
		value_start := position
		for position < tag.len && tag[position] != quote {
			position++
		}
		if position >= tag.len {
			return none
		}
		value := tag[value_start..position]
		position++
		if name == requested_name {
			return value
		}
	}
	return none
}

fn svg_image_natural_size(source string) ?css.SizeWithAspectRatio {
	start := source.index('<svg') or { return none }
	end_relative := source[start..].index('>') or { return none }
	start_tag := source[start..start + end_relative + 1]
	width := svg_absolute_length(xml_start_tag_attribute(start_tag, 'width') or { '' })
	height := svg_absolute_length(xml_start_tag_attribute(start_tag, 'height') or { '' })
	mut aspect_ratio := ?css.CSSPixelFraction(none)
	if natural_width := width {
		if natural_height := height {
			if natural_width.raw_value() > 0 && natural_height.raw_value() > 0 {
				aspect_ratio = css.CSSPixelFraction.new(natural_width, natural_height)
			}
		}
	}
	if aspect_ratio == none {
		view_box_text := xml_start_tag_attribute(start_tag, 'viewBox') or {
			xml_start_tag_attribute(start_tag, 'viewbox') or { '' }
		}
		if view_box := svg.parse_viewbox(view_box_text) {
			if view_box.width > 0 && view_box.height > 0 {
				aspect_ratio = css.CSSPixelFraction.new(CSSPixels.nearest_value_for(view_box.width), CSSPixels.nearest_value_for(view_box.height))
			}
		}
	}
	return css.SizeWithAspectRatio{
		width: width
		height: height
		aspect_ratio: aspect_ratio
	}
}

struct ImageDimensions {
	width  int
	height int
}

fn little_endian_u24(data []u8, offset int) int {
	return int(data[offset]) | (int(data[offset + 1]) << 8) | (int(data[offset + 2]) << 16)
}

fn little_endian_u32(data []u8, offset int) u32 {
	return u32(data[offset]) | (u32(data[offset + 1]) << 8) | (u32(data[offset + 2]) << 16) | (u32(data[offset + 3]) << 24)
}

fn big_endian_u32(data []u8, offset int) u32 {
	return (u32(data[offset]) << 24) | (u32(data[offset + 1]) << 16) | (u32(data[offset + 2]) << 8) | u32(data[offset + 3])
}

// LibGfx's GIFImageDecoderPlugin does not make an image available unless its
// LZW frame stream can be decoded through an end-of-data code. stb_image is
// deliberately more forgiving (it accepts truncated streams), so validate the
// part that affects ImageBox::natural_size() before using stb's dimensions.
fn gif_lzw_stream_is_decodable(data []u8, minimum_code_size int) bool {
	if minimum_code_size < 1 || minimum_code_size > 8 || data.len == 0 {
		return false
	}
	mut code_size := minimum_code_size
	mut table_capacity := 1 << code_size
	mut table_entry_lengths := []int{len: table_capacity, init: 1}
	// LzwDecompressor::decompress_all() adds clear and end-of-data controls.
	clear_code := table_entry_lengths.len
	table_entry_lengths << 0
	if table_entry_lengths.len >= table_capacity && code_size < 12 {
		code_size++
		table_capacity *= 2
	}
	end_of_data_code := table_entry_lengths.len
	table_entry_lengths << 0
	original_entry_lengths := table_entry_lengths.clone()
	original_code_size := code_size
	original_table_capacity := table_capacity
	mut previous_output_length := 0
	mut bit_offset := 0
	for {
		if bit_offset + code_size > data.len * 8 {
			return false
		}
		mut code := 0
		for bit in 0 .. code_size {
			byte_offset := (bit_offset + bit) / 8
			bit_in_byte := (bit_offset + bit) % 8
			code |= int((data[byte_offset] >> bit_in_byte) & 1) << bit
		}
		bit_offset += code_size
		if code == clear_code {
			table_entry_lengths = original_entry_lengths.clone()
			code_size = original_code_size
			table_capacity = original_table_capacity
			previous_output_length = 0
			continue
		}
		if code == end_of_data_code {
			return true
		}
		if code > table_entry_lengths.len || (code == table_entry_lengths.len && previous_output_length == 0) {
			return false
		}
		mut output_length := 0
		if code < table_entry_lengths.len {
			output_length = table_entry_lengths[code]
			new_entry_length := previous_output_length + 1
			if new_entry_length > 1 && table_entry_lengths.len < 4096 {
				table_entry_lengths << new_entry_length
				if table_entry_lengths.len >= table_capacity && code_size < 12 {
					code_size++
					table_capacity *= 2
				}
			}
		} else {
			output_length = previous_output_length + 1
			if output_length > 1 && table_entry_lengths.len < 4096 {
				table_entry_lengths << output_length
				if table_entry_lengths.len >= table_capacity && code_size < 12 {
					code_size++
					table_capacity *= 2
				}
			}
		}
		previous_output_length = output_length
	}
	return false
}

fn gif_image_data_is_decodable(data []u8) bool {
	if data.len < 26 || data[..6].bytestr() !in ['GIF87a', 'GIF89a'] {
		return false
	}
	mut offset := 13
	logical_screen_packed_fields := data[10]
	if logical_screen_packed_fields & 0x80 != 0 {
		global_color_table_size := 3 * (1 << (int(logical_screen_packed_fields & 7) + 1))
		if offset + global_color_table_size > data.len {
			return false
		}
		offset += global_color_table_size
	}
	mut saw_frame := false
	for offset < data.len {
		sentinel := data[offset]
		offset++
		if sentinel == `;` {
			return saw_frame
		}
		if sentinel == `!` {
			if offset >= data.len {
				return false
			}
			offset++ // Extension label.
			for {
				if offset >= data.len {
					return false
				}
				block_size := int(data[offset])
				offset++
				if block_size == 0 {
					break
				}
				if offset + block_size > data.len {
					return false
				}
				offset += block_size
			}
			continue
		}
		if sentinel != `,` || offset + 9 > data.len {
			return false
		}
		image_packed_fields := data[offset + 8]
		offset += 9
		if image_packed_fields & 0x80 != 0 {
			local_color_table_size := 3 * (1 << (int(image_packed_fields & 7) + 1))
			if offset + local_color_table_size > data.len {
				return false
			}
			offset += local_color_table_size
		}
		if offset >= data.len {
			return false
		}
		minimum_code_size := int(data[offset])
		offset++
		mut encoded := []u8{}
		for {
			if offset >= data.len {
				return false
			}
			block_size := int(data[offset])
			offset++
			if block_size == 0 {
				break
			}
			if offset + block_size > data.len {
				return false
			}
			encoded << data[offset..offset + block_size]
			offset += block_size
		}
		if !gif_lzw_stream_is_decodable(encoded, minimum_code_size) {
			return false
		}
		saw_frame = true
	}
	return false
}

fn encoded_image_dimensions(data []u8) ?ImageDimensions {
	if data.len >= 24 && data[..8] == [u8(0x89), `P`, `N`, `G`, u8(0x0d), u8(0x0a), u8(0x1a),
		u8(0x0a)] && data[12..16].bytestr() == 'IHDR' {
		width := int(big_endian_u32(data, 16))
		height := int(big_endian_u32(data, 20))
		if width > 0 && height > 0 {
			return ImageDimensions{
				width: width
				height: height
			}
		}
	}
	return webp_image_dimensions(data)
}

// stb_image deliberately does not decode WebP. Preserve the HTML image's
// intrinsic dimensions by reading the three WebP bitstream header variants.
fn webp_image_dimensions(data []u8) ?ImageDimensions {
	if data.len < 20 || data[..4].bytestr() != 'RIFF' || data[8..12].bytestr() != 'WEBP' {
		return none
	}
	mut chunk_offset := 12
	for chunk_offset + 8 <= data.len {
		chunk_size := int(little_endian_u32(data, chunk_offset + 4))
		payload_offset := chunk_offset + 8
		if chunk_size < 0 || payload_offset + chunk_size > data.len {
			return none
		}
		chunk_type := data[chunk_offset..chunk_offset + 4].bytestr()
		if chunk_type == 'VP8X' && chunk_size >= 10 {
			return ImageDimensions{
				width: little_endian_u24(data, payload_offset + 4) + 1
				height: little_endian_u24(data, payload_offset + 7) + 1
			}
		}
		if chunk_type == 'VP8L' && chunk_size >= 5 && data[payload_offset] == 0x2f {
			bits := little_endian_u32(data, payload_offset + 1)
			return ImageDimensions{
				width: int(bits & 0x3fff) + 1
				height: int((bits >> 14) & 0x3fff) + 1
			}
		}
		if chunk_type == 'VP8 ' && chunk_size >= 10 && data[payload_offset + 3] == 0x9d && data[payload_offset + 4] == 0x01 && data[payload_offset + 5] == 0x2a {
			return ImageDimensions{
				width: (int(data[payload_offset + 6]) | (int(data[payload_offset + 7]) << 8)) & 0x3fff
				height: (int(data[payload_offset + 8]) | (int(data[payload_offset + 9]) << 8)) & 0x3fff
			}
		}
		chunk_offset = payload_offset + chunk_size + (chunk_size & 1)
	}
	return none
}

pub fn (box &ImageBox) renders_as_alt_text() bool {
	return box.renders_as_alt_text_
}

pub fn (box &ImageBox) source() string {
	return box.source_
}

pub fn (mut box ImageBox) dom_node_did_update_alt_text() {
	if !box.renders_as_alt_text_ {
		return
	}
	dom_node := box.dom_node() or { return }
	element := dom_node.as_element() or { return }
	box.natural_size_ = image_alt_text_natural_size(element.get_attribute_value('alt'))
	box.auto_content_box_size_ = box.natural_size_
}

pub fn (box &ImageBox) svg_image_document() ?&dom.Document {
	return box.svg_image_document_
}

pub fn (node &Node) as_image_box() ?&ImageBox {
	if !node.is_image_box() {
		return none
	}
	return unsafe { &ImageBox(node) }
}

@[heap]
pub struct AudioBox {
	ReplacedBox
}

pub fn AudioBox.new(document &dom.Document, element &dom.Element, computed_values &css.ComputedProperties) &AudioBox {
	mut box := &AudioBox{
		ReplacedBox: replaced_box_base(document, element, computed_values)
	}
	// AudioBox::can_have_children(): fallback DOM children must not enter the
	// layout tree; only an existing media-controls shadow tree is allowed.
	box.has_auto_content_box_size_ = false
	box.replaced_can_have_children_ = element.shadow_root() != none
	return box
}

@[heap]
pub struct VideoBox {
	ReplacedBox
}

pub fn VideoBox.new(document &dom.Document, element &dom.Element, computed_values &css.ComputedProperties) &VideoBox {
	mut box := &VideoBox{
		ReplacedBox: replaced_box_base(document, element, computed_values)
	}
	// VideoBox::can_have_children() has the same controls-shadow-root boundary
	// as AudioBox.
	box.replaced_can_have_children_ = element.shadow_root() != none
	return box
}

@[heap]
pub struct TextInputBox {
	BlockContainer
}

pub fn TextInputBox.new(document &dom.Document, element &dom.Element, computed_values &css.ComputedProperties) &TextInputBox {
	mut box := &TextInputBox{
		BlockContainer: special_block_container_base(document, element.as_node(), computed_values)
	}
	box.is_text_input_box_ = true
	// TextInputBox::compute_auto_content_box_size(). The `size` attribute is a
	// `ch` length resolved against this box's own font, so the advance is
	// quantized to CSSPixels before it is multiplied - not after.
	columns := positive_integer_attribute_or_default(element, 'size', 20)
	box_node := unsafe { &Node(box) }
	mut width := resolve_font_dependent_length_for_node(box_node, css.Length.new(f64(columns),
		.ch))
	// AD-HOC: 2px is inline shadow DOM padding in HTMLInputElement::create_text_input_shadow_tree()
	mut height := computed_values.line_height().plus(CSSPixels.new(2))
	if computed_values.writing_mode() != .horizontal_tb {
		width, height = height, width
	}
	box.has_auto_content_box_size_ = true
	box.auto_content_box_size_ = css.SizeWithAspectRatio{
		width: width
		height: height
	}
	return box
}

@[heap]
pub struct TextAreaBox {
	BlockContainer
}

pub fn TextAreaBox.new(document &dom.Document, element &dom.Element, computed_values &css.ComputedProperties) &TextAreaBox {
	mut box := &TextAreaBox{
		BlockContainer: special_block_container_base(document, element.as_node(), computed_values)
	}
	box.is_textarea_box_ = true
	// TextAreaBox::compute_auto_content_box_size(): `cols` is a `ch` length and
	// `rows` is an `lh` length, both resolved against this box's own font.
	columns := positive_integer_attribute_or_default(element, 'cols', 20)
	rows := positive_integer_attribute_or_default(element, 'rows', 2)
	box_node := unsafe { &Node(box) }
	mut width := resolve_font_dependent_length_for_node(box_node, css.Length.new(f64(columns),
		.ch))
	mut height := resolve_font_dependent_length_for_node(box_node, css.Length.new(f64(rows),
		.lh))
	if computed_values.writing_mode() != .horizontal_tb {
		width, height = height, width
	}
	box.has_auto_content_box_size_ = true
	box.auto_content_box_size_ = css.SizeWithAspectRatio{
		width: width
		height: height
	}
	return box
}

// HTMLTextAreaElement::create_layout_node(). The element-specific boundary
// lives in Layout because html cannot import layout without a module cycle.
pub fn html_text_area_element_create_layout_node(document &dom.Document, element &dom.Element, computed_values &css.ComputedProperties) &Node {
	return unsafe { &Node(TextAreaBox.new(document, element, computed_values)) }
}

@[heap]
pub struct FieldSetBox {
	BlockContainer
}

pub fn FieldSetBox.new(document &dom.Document, element &dom.Element, computed_values &css.ComputedProperties) &FieldSetBox {
	mut box := &FieldSetBox{
		BlockContainer: special_block_container_base(document, element.as_node(), computed_values)
	}
	box.is_fieldset_box_ = true
	return box
}

pub fn html_field_set_element_create_layout_node(document &dom.Document, element &dom.Element, computed_values &css.ComputedProperties) &Node {
	return unsafe { &Node(FieldSetBox.new(document, element, computed_values)) }
}

pub fn html_field_set_element_layout_node(node &Node) ?&FieldSetBox {
	if !node.is_fieldset_box() {
		return none
	}
	return unsafe { &FieldSetBox(node) }
}

pub fn (box &FieldSetBox) rendered_legend() ?&LegendBox {
	for child in box.children() {
		if child.is_legend_box() && child.is_in_flow() {
			return unsafe { &LegendBox(child) }
		}
	}
	return none
}

@[heap]
pub struct LegendBox {
	BlockContainer
}

pub fn LegendBox.new(document &dom.Document, element &dom.Element, computed_values &css.ComputedProperties) &LegendBox {
	mut box := &LegendBox{
		BlockContainer: special_block_container_base(document, element.as_node(), computed_values)
	}
	box.is_legend_box_ = true
	return box
}

pub fn html_legend_element_create_layout_node(document &dom.Document, element &dom.Element, computed_values &css.ComputedProperties) &Node {
	return unsafe { &Node(LegendBox.new(document, element, computed_values)) }
}

pub fn html_legend_element_layout_node(node &Node) ?&LegendBox {
	if !node.is_legend_box() {
		return none
	}
	return unsafe { &LegendBox(node) }
}

@[heap]
pub struct TableWrapper {
	BlockContainer
}

@[heap]
pub struct ListItemMarkerBox {
	Box
pub:
	list_style_type_     css.ListStyleType
	list_style_position_ css.ListStylePosition
	list_item_element_   &dom.Element = unsafe { nil }
}

pub fn ListItemMarkerBox.new(document &dom.Document, list_style_type css.ListStyleType, list_style_position css.ListStylePosition, list_item_element &dom.Element, computed_values &css.ComputedProperties) &ListItemMarkerBox {
	mut box := special_box_base(document, none, computed_values)
	box.is_list_item_marker_box_ = true
	return &ListItemMarkerBox{
		Box: box
		list_style_type_: list_style_type
		list_style_position_: list_style_position
		list_item_element_: list_item_element
	}
}

pub fn (box &ListItemMarkerBox) text() ?string {
	// The ordinal is deliberately resolved when the marker is laid out or
	// painted, after the complete list layout tree exists. Computing this in
	// the constructor made every item observe the partially-built list and
	// cache ordinal 1.
	return marker_text_for_list_style(box.list_style_type_, box.list_item_element_)
}

pub fn ListItemMarkerBox.counter_style_is_rendered_with_custom_image(counter_style ?css.CounterStyle) bool {
	style := counter_style or { return false }
	return style.name() in ['square', 'circle', 'disc', 'disclosure-closed', 'disclosure-open']
}

pub fn (box &ListItemMarkerBox) list_style_type() css.ListStyleType {
	return box.list_style_type_
}

pub fn (box &ListItemMarkerBox) list_style_position() css.ListStylePosition {
	return box.list_style_position_
}

pub fn (box &ListItemMarkerBox) relative_size() CSSPixels {
	font_size := box.computed_values().font_size()
	if box.text() != none {
		return font_size
	}
	style := box.list_style_type_.counter_style or { return font_size }
	factor := if style.name() in ['disclosure-closed', 'disclosure-open'] {
		0.5
	} else {
		0.35
	}
	return CSSPixels.nearest_value_for(math.ceil(font_size.to_double() * factor))
}

fn marker_text_for_list_style(list_style_type css.ListStyleType, element &dom.Element) ?string {
	if list_style_type.kind == .none_ {
		return none
	}
	if list_style_type.kind == .string {
		return list_style_type.name
	}
	// These predefined counter styles do not participate in text layout;
	// MarkerPaintable draws their geometric image instead.
	if ListItemMarkerBox.counter_style_is_rendered_with_custom_image(list_style_type.counter_style) {
		return none
	}

	mut mutable_element := unsafe { &dom.Element(element) }
	ordinal := mutable_element.ordinal_value()
	registered_counter_styles := css.registered_counter_styles_for_document(element.document())
	representation := css.generate_a_counter_representation(list_style_type.counter_style, registered_counter_styles, i32(ordinal))
	if style := list_style_type.counter_style {
		return '${style.prefix()}${representation}${style.suffix()}'
	}
	// A missing named counter style falls back to decimal.
	return '${representation}. '
}

pub fn TableWrapper.new(document &dom.Document, dom_node ?&dom.Node, computed_values &css.ComputedProperties) &TableWrapper {
	mut box := &TableWrapper{
		BlockContainer: special_block_container_base(document, dom_node, computed_values)
	}
	box.is_table_wrapper_ = true
	return box
}

fn positive_integer_attribute_or_default(element &dom.Element, name string, default_value int) int {
	text := element.get_attribute_value(name).trim_space()
	if text.len == 0 {
		return default_value
	}
	value := strconv.atoi(text) or { return default_value }
	if value <= 0 {
		return default_value
	}
	return value
}

fn nonnegative_integer_attribute_or_default(element &dom.Element, name string, default_value int) int {
	text := element.get_attribute_value(name).trim_space()
	if text.len == 0 {
		return default_value
	}
	value := strconv.atoi(text) or { return default_value }
	if value < 0 {
		return default_value
	}
	return value
}
