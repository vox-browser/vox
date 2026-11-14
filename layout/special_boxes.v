// Copyright (c) 2018-2026, Ladybird contributors
//
// SPDX-License-Identifier: BSD-2-Clause
module layout

import platform

import css
import dom
import encoding.base64
import html
import http
import loader
import math
import os
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
				computed_values_: computed_values_in_layout_coordinates(computed_values, document)
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

// Layout::NavigableContainerViewport. A hosted navigable supplies its actual
// active document. Standalone layout keeps its about:blank/srcdoc adapter.
@[heap]
pub struct NavigableContainerViewport {
	ReplacedBox
mut:
	content_document_ &dom.Document = unsafe { nil }
	content_source_ string
}

pub fn NavigableContainerViewport.new(document &dom.Document, element &dom.Element, computed_values &css.ComputedProperties) &NavigableContainerViewport {
	mut box := &NavigableContainerViewport{
		ReplacedBox: replaced_box_base(document, element, computed_values)
	}
	box.is_navigable_container_viewport_ = true
	return box
}

pub fn (box &NavigableContainerViewport) content_document() ?&dom.Document {
	node := box.dom_node() or { return none }
	mut mutable_box := unsafe { &NavigableContainerViewport(box) }
	if navigable := node.content_navigable() {
		if mutable_box.content_document_ != unsafe { nil } {
			retire_native_navigable_fallback_document(mutable_box.content_document_)
			mutable_box.content_document_ = unsafe { nil }
			mutable_box.content_source_ = ''
		}
		return navigable.active_document()
	}
	element := node.as_element() or { return none }
	source := element.get_attribute('srcdoc') or { '' }
	if mutable_box.content_document_ == unsafe { nil } || mutable_box.content_source_ != source {
		previous := mutable_box.content_document_
		mutable_box.content_document_ = create_navigable_fallback_document(node.document(), source)
		mutable_box.content_source_ = source
		if previous != unsafe { nil } { retire_native_navigable_fallback_document(previous) }
	}
	return mutable_box.content_document_
}

// NavigableContainerViewport::natural_size(). Only an object embedding an SVG
// document contributes that document's negotiated natural dimensions.
pub fn (box &NavigableContainerViewport) natural_size() css.SizeWithAspectRatio {
	dom_node := box.dom_node() or { return css.SizeWithAspectRatio{} }
	element := dom_node.as_element() or { return css.SizeWithAspectRatio{} }
	if !element.is_html_element() || element.local_name() != 'object' {
		return css.SizeWithAspectRatio{}
	}
	document := box.content_document() or { return css.SizeWithAspectRatio{} }
	root := document.document_element() or { return css.SizeWithAspectRatio{} }
	if !root.is_svg_svg_element() {
		return css.SizeWithAspectRatio{}
	}
	return negotiate_svg_natural_metrics(root)
}

// The C++ paintable calls this hook after copying committed content geometry.
// V lowers directly from UsedValues, so update the hosted document at that
// same boundary in the typed paint adapter.
// A container laid out in device coordinates still gives its hosted document a
// viewport in CSS pixels.
pub fn (box &NavigableContainerViewport) did_set_content_size(size css.CSSPixelSize) {
	mut document := unsafe { &dom.Document(box.content_document() or { return }) }
	old_rect := document.viewport_rect()
	scale := unsafe { &Node(box) }.document().layout_coordinate_scale()
	document.set_viewport_rect(dom.Rect{
		x: old_rect.x
		y: old_rect.y
		width: size.width().to_double() / scale
		height: size.height().to_double() / scale
	})
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
	size := if document.font_rendering_policy() == .chromium { 13 } else { 12 }
	box.auto_content_box_size_ = css.SizeWithAspectRatio{
		width: CSSPixels.new(size)
		height: CSSPixels.new(size)
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
mut:
	svg_image_document_       ?&dom.Document
	source_                   string
	uses_content_replacement_ bool
	// Resolution of the image-set() candidate that selected source_.
	source_resolution_ f64 = 1.0
}

fn image_source_selected_from_attributes(element &dom.Element) string {
	mut source := element.get_attribute_value('src')
	srcset := element.get_attribute_value('srcset')
	if srcset.len == 0 {
		return source
	}
	sizes := element.get_attribute_value('sizes').trim_space().to_lower()
	source_size := if sizes.ends_with('px') {
		sizes[..sizes.len - 2].f64()
	} else {
		100.0
	}
	source_set := html.create_source_set(source, srcset, source_size)
	if !source_set.is_empty() {
		source = source_set.select_an_image_source(html.display_device_pixel_ratio()).source.url
	}
	return source
}

fn available_html_image_natural_size(element &dom.Element) ?css.SizeWithAspectRatio {
	if element.is_html_element() && element.local_name() == 'input' {
		model := html.HTMLInputElementModel.create(unsafe { &dom.HTMLInputElement(element) })
		if !model.is_image_available() { return none }
		return natural_size_with_aspect_ratio(model.intrinsic_width(), model.intrinsic_height(),
			model.intrinsic_aspect_ratio())
	}
	if !element.as_node().is_html_image_element() {
		return none
	}
	image := unsafe { &dom.HTMLImageElement(element) }
	if !html.html_image_element_is_image_available(image) {
		return none
	}
	if document := available_html_svg_image_document(element) {
		return svg_background_natural_size(document)
	}
	return natural_size_with_aspect_ratio(html.html_image_element_intrinsic_width(image),
		html.html_image_element_intrinsic_height(image), html.html_image_element_intrinsic_aspect_ratio(image))
}

fn available_html_svg_image_document(element &dom.Element) ?&dom.Document {
	if element.is_html_element() && element.local_name() == 'input' {
		model := html.HTMLInputElementModel.create(unsafe { &dom.HTMLInputElement(element) })
		decoded := model.decoded_image_data() or { return none }
		if decoded is html.SVGDecodedImageData {
			mut isolated := decoded.svg_document
			isolated.set_font_rendering_policy(element.document().font_rendering_policy())
			return isolated
		}
		return none
	}
	if !element.as_node().is_html_image_element() { return none }
	image := unsafe { &dom.HTMLImageElement(element) }
	decoded := html.html_image_element_model_for_dom_element(image).decoded_image_data() or { return none }
	if decoded is html.SVGDecodedImageData {
		mut isolated := decoded.svg_document
		isolated.set_font_rendering_policy(element.document().font_rendering_policy())
		return isolated
	}
	return none
}

// ImageProvider::intrinsic_aspect_ratio() is the exact width/height fraction
// when both natural dimensions exist. Rounding the ratio itself to a CSS pixel
// quantum turned a 151x97 block image into a 151x96.625 box.
fn natural_size_with_aspect_ratio(width ?f64, height ?f64, ratio ?f64) css.SizeWithAspectRatio {
	mut result := css.SizeWithAspectRatio{}
	if natural_width := width {
		result.width = CSSPixels.nearest_value_for(natural_width)
	}
	if natural_height := height {
		result.height = CSSPixels.nearest_value_for(natural_height)
	}
	if natural_ratio := ratio {
		if natural_ratio > 0 {
			natural_width := result.width or { CSSPixels.new(0) }
			natural_height := result.height or { CSSPixels.new(0) }
			result.aspect_ratio = if natural_width.raw_value() > 0 && natural_height.raw_value() > 0 {
				css.CSSPixelFraction.new(natural_width, natural_height)
			} else {
				css.CSSPixelFraction.new(CSSPixels.nearest_value_for(natural_ratio), CSSPixels.new(1))
			}
		}
	}
	return result
}

fn available_object_image_natural_size(element &dom.Element) ?css.SizeWithAspectRatio {
	if !element.is_html_element() || element.local_name() != 'object' {
		return none
	}
	object_element := unsafe { &dom.HTMLObjectElement(element) }
	model := html.html_object_element_model_for_dom_element(object_element)
	if !model.is_image_available() {
		return none
	}
	return natural_size_with_aspect_ratio(model.intrinsic_width(), model.intrinsic_height(),
		model.intrinsic_aspect_ratio())
}

pub fn ImageBox.new(document &dom.Document, element &dom.Element, computed_values &css.ComputedProperties) &ImageBox {
	mut box := &ImageBox{
		ReplacedBox: replaced_box_base(document, element, computed_values)
	}
	box.is_image_box_ = true
	source := image_source_for_layout(element)
	box.source_ = source
	if intrinsic_size := available_html_image_natural_size(element) {
		box.natural_size_ = intrinsic_size
	} else if intrinsic_size := available_object_image_natural_size(element) {
		box.natural_size_ = intrinsic_size
	} else if intrinsic_size := image_intrinsic_size_for_source(document, source) {
		box.natural_size_ = intrinsic_size
	} else {
		box.natural_size_ = css.SizeWithAspectRatio{
			width: CSSPixels.new(0)
			height: CSSPixels.new(0)
		}
	}
	box.svg_image_document_ = if isolated := available_html_svg_image_document(element) {
		isolated
	} else { svg_image_document_for_source(document, source) }
	box.refresh_svg_natural_size()
	box.auto_content_box_size_ = box.natural_size_
	return box
}

pub fn ImageBox.new_generated(document &dom.Document, computed_values &css.ComputedProperties, source string) &ImageBox {
	mut box := &ImageBox{
		ReplacedBox: generated_replaced_box_base(document, computed_values)
		source_: source
	}
	box.is_image_box_ = true
	if intrinsic_size := image_intrinsic_size_for_source(document, source) {
		box.natural_size_ = intrinsic_size
	} else {
		box.natural_size_ = css.SizeWithAspectRatio{
			width: CSSPixels.new(0)
			height: CSSPixels.new(0)
		}
	}
	box.svg_image_document_ = svg_image_document_for_source(document, source)
	box.refresh_svg_natural_size()
	box.auto_content_box_size_ = box.natural_size_
	return box
}

// ImageSetStyleValue::natural_size(): an image-set() candidate's natural size
// is divided by its resolution; the aspect ratio is unchanged.
fn natural_size_at_resolution(size css.SizeWithAspectRatio, resolution f64) css.SizeWithAspectRatio {
	if resolution <= 0 || resolution == 1.0 {
		return size
	}
	mut scaled := size
	if width := size.width {
		scaled.width = CSSPixels.nearest_value_for(width.to_double() / resolution)
	}
	if height := size.height {
		scaled.height = CSSPixels.nearest_value_for(height.to_double() / resolution)
	}
	return scaled
}

// A generated ImageBox for a content image item, preserving the resolution of
// a selected image-set() candidate.
pub fn ImageBox.new_generated_for_content_item(document &dom.Document, computed_values &css.ComputedProperties, item css.ContentItem) &ImageBox {
	mut box := ImageBox.new_generated(document, computed_values, item.value)
	box.source_resolution_ = item.resolution
	box.natural_size_ = natural_size_at_resolution(box.natural_size_, item.resolution)
	box.auto_content_box_size_ = box.natural_size_
	return box
}

pub fn ImageBox.new_content_replacement_for_item(document &dom.Document, element &dom.Element, computed_values &css.ComputedProperties, item css.ContentItem) &ImageBox {
	mut box := ImageBox.new_content_replacement(document, element, computed_values, item.value)
	box.source_resolution_ = item.resolution
	box.natural_size_ = natural_size_at_resolution(box.natural_size_, item.resolution)
	box.auto_content_box_size_ = box.natural_size_
	return box
}

pub fn ImageBox.new_content_replacement(document &dom.Document, element &dom.Element, computed_values &css.ComputedProperties, source string) &ImageBox {
	mut box := &ImageBox{
		ReplacedBox: replaced_box_base(document, element, computed_values)
		source_: source
		uses_content_replacement_: true
	}
	box.is_image_box_ = true
	if intrinsic_size := image_intrinsic_size_for_source(document, source) {
		box.natural_size_ = intrinsic_size
	} else {
		box.natural_size_ = css.SizeWithAspectRatio{
			width: CSSPixels.new(0)
			height: CSSPixels.new(0)
		}
	}
	box.svg_image_document_ = svg_image_document_for_source(document, source)
	box.refresh_svg_natural_size()
	box.auto_content_box_size_ = box.natural_size_
	return box
}

struct SVGImageSource {
	source string
	url    dom.URL
}

struct SVGImageDocumentCacheEntry {
	source   string
	document &dom.Document
}

// Remote bytes enter through the embedder-populated ResourceLoader store. This
// performs the translated request filtering and response checks without adding
// a network transport or blocking network I/O to layout.
fn remote_svg_image_source(document &dom.Document, image_url dom.URL) ?SVGImageSource {
	if !loader.is_initialized() { return none }
	mut fetch_url := image_url
	fetch_url.set_fragment(none)
	mut request := loader.LoadRequest.create(http.HeaderList.create())
	request.set_url(fetch_url)
	request.set_source_url(document.url)
	request.set_destination(.image)
	mut resource_loader := loader.ResourceLoader.the()
	response := resource_loader.load(mut request)
	if !response.success || response.data.len == 0 { return none }
	status := response.status_code or { return none }
	if status < 200 || status >= 300 { return none }
	mut content_type := ?string(none)
	for header in response.headers {
		if header.name.to_lower() == 'content-type' {
			content_type = header.value.split(';')[0].trim_space().to_lower()
		}
	}
	if declared_type := content_type {
		if declared_type != 'image/svg+xml' { return none }
	} else if !fetch_url.serialize_path().to_lower().ends_with('.svg') {
		// The compact disk cache predates response metadata. Preserve that cache's
		// SVG URL classification only when a response supplied no Content-Type.
		return none
	}
	return SVGImageSource{
		source: response.data.bytestr()
		url:    image_url
	}
}

fn svg_image_source_for_source(document &dom.Document, source string) ?SVGImageSource {
	if source.len == 0 {
		return none
	}
	trimmed_source := source.trim_space()
	parsed_url := document.encoding_parse_url(trimmed_source) or { return none }
	if document.is_svg_image_document() && parsed_url.scheme() != 'data' { return none }
	mut resource_url := parsed_url
	resource_url.set_fragment(none)
	serialized := resource_url.serialize()
	if parsed_url.scheme() in ['http', 'https'] {
		return remote_svg_image_source(document, parsed_url)
	}
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
		record := url.parse(serialized) or { return none }
		path = record.to_file_path() or { return none }
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
	return parse_svg_image_document(image_source, document.preferred_color_scheme(), document)
}

// Background layers within one layout tree use the same decoded image. Keep
// color-scheme variants separate because the isolated document owns its media
// environment, and compare the source bytes before reusing a URL after a
// response or local-file replacement. Failed loads never reuse a cached image.
fn svg_image_document_for_source_in_viewport(node &Node, source string,
	color_scheme css.PreferredColorScheme) ?&dom.Document {
	// Isolated SVG documents and the viewport cache survive paint projections.
	persistent := platform.enter_persistent_if(platform.transient_arena_entered())
	defer { platform.leave_persistent(persistent) }
	image_source := svg_image_source_for_paint(node, source) or { return none }
	scheme := css.preferred_color_scheme_to_string(color_scheme)
	viewport := node.root_viewport() or {
		return parse_svg_image_document(image_source, scheme, node.document())
	}
	cache_key := scheme + '\n' + image_source.url.serialize()
	if existing := viewport.svg_image_documents_[cache_key] {
		if existing.source == image_source.source {
			return existing.document
		}
	}
	isolated := parse_svg_image_document(image_source, scheme, node.document()) or { return none }
	mut mutable_viewport := unsafe { &Viewport(viewport) }
	mutable_viewport.svg_image_documents_[cache_key] = SVGImageDocumentCacheEntry{
		source:   image_source.source
		document: isolated
	}
	return isolated
}

fn parse_svg_image_document(image_source SVGImageSource, color_scheme string, embedder &dom.Document) ?&dom.Document {
	return parse_svg_image_document_with_owner(image_source, color_scheme, embedder.font_rendering_policy(), embedder.native_storage())
}

fn parse_svg_image_document_with_owner(image_source SVGImageSource, color_scheme string,
	font_policy dom.FontRenderingPolicy, storage &platform.RetainedArena) ?&dom.Document {
	mut svg_document := create_svg_image_document(image_source.url, storage)
	mut owner := svg_document.native_storage()
	mut allocations := if owner != unsafe { nil } { owner.enter_nested() } else { platform.RetainedArenaScope{} }
	defer { allocations.finish() }
	svg_document.set_content_type('image/svg+xml')
	svg_document.set_document_type(.xml)
	svg_document.set_is_svg_image_document(true)
	svg_document.set_svg_image_color_scheme(color_scheme)
	// An SVG image renders with its embedding document's compatibility policy.
	svg_document.set_font_rendering_policy(font_policy)
	html.parse_xml_document_source(svg_document, image_source.source.clone()) or {
		svg_document.finalize()
		svg_document.release_native_storage()
		return none
	}
	if image_source.url.scheme() in ['http', 'https'] {
		root := svg_document.document_element() or {
			svg_document.finalize()
			svg_document.release_native_storage()
			return none
		}
		if root.local_name() != 'svg'
			|| (root.namespace_uri() or { '' }) != 'http://www.w3.org/2000/svg' {
			svg_document.finalize()
			svg_document.release_native_storage()
			return none
		}
	}
	retain_svg_image_document_until_owner_retires(svg_document, storage)
	return svg_document
}

fn image_intrinsic_size_for_source(document &dom.Document, source string) ?css.SizeWithAspectRatio {
	if source.len == 0 {
		return none
	}
	trimmed_source := source.trim_space()
	parsed_url := document.encoding_parse_url(trimmed_source) or { return none }
	fragment := parsed_url.fragment() or { '' }
	if document.is_svg_image_document() && parsed_url.scheme() != 'data' { return none }
	mut resource_url := parsed_url
	resource_url.set_fragment(none)
	serialized := resource_url.serialize()
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
			return svg_image_natural_size_with_fragment(data.bytestr(), fragment)
		}
		if dimensions := encoded_image_dimensions(data) {
			return size_with_optional_aspect_ratio(CSSPixels.new(dimensions.width), CSSPixels.new(dimensions.height))
		}
		image := stbi.load_from_memory(data.data, data.len) or {
			return none
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
		record := url.parse(serialized) or { return none }
		path = record.to_file_path() or { return none }
	} else if serialized.starts_with('http://') || serialized.starts_with('https://') {
		image_source := svg_image_source_for_source(document, source) or { return none }
		return svg_image_natural_size_with_fragment(image_source.source, fragment)
	} else if serialized.contains('://') {
		return none
	}
	if !os.is_file(path) {
		return none
	}
	if path.to_lower().ends_with('.svg') {
		svg_source := os.read_file(path) or { return none }
		return svg_image_natural_size_with_fragment(svg_source, fragment)
	}
	data := os.read_bytes(path) or { return none }
	if dimensions := encoded_image_dimensions(data) {
		return size_with_optional_aspect_ratio(CSSPixels.new(dimensions.width), CSSPixels.new(dimensions.height))
	}
	image := stbi.load(path) or {
		return none
	}
	defer {
		image.free()
	}
	if image.width <= 0 || image.height <= 0 {
		return none
	}
	return size_with_optional_aspect_ratio(CSSPixels.new(image.width), CSSPixels.new(image.height))
}

// A viewBox establishes an aspect ratio, not natural width and height. Keep
// absent dimensions absent when resolving an SVG background's concrete size.
pub fn svg_background_natural_size(document &dom.Document) css.SizeWithAspectRatio {
	root := document.document_element() or { return css.SizeWithAspectRatio{} }
	return negotiate_svg_natural_metrics(root)
}

// Use the same decoded SVG for pixels and dimensions. Refetching its source
// here duplicates response bytes and can observe a newer resource revision.
fn background_svg_intrinsic_dimensions(isolated ?&dom.Document) (f64, f64) {
	document := isolated or { return 0, 0 }
	intrinsic := svg_background_natural_size(document)
	return background_svg_natural_dimensions(intrinsic)
}

fn background_svg_natural_dimensions(intrinsic css.SizeWithAspectRatio) (f64, f64) {
	mut width := f64(0)
	mut height := f64(0)
	if natural_width := intrinsic.width {
		width = natural_width.to_double()
	}
	if natural_height := intrinsic.height {
		height = natural_height.to_double()
	}
	if ratio := intrinsic.aspect_ratio {
		if width > 0 && height <= 0 {
			height = width / ratio.to_double()
		} else if height > 0 && width <= 0 {
			width = height * ratio.to_double()
		} else if width <= 0 && height <= 0 {
			width = ratio.numerator().to_double()
			height = ratio.denominator().to_double()
		}
	}
	return width, height
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
	return svg_image_natural_size_with_fragment(source, '')
}

fn svg_image_natural_size_with_fragment(source string, fragment string) ?css.SizeWithAspectRatio {
	start := source.index('<svg') or { return none }
	end := source.index_after('>', start) or { return none }
	start_tag := source[start..end + 1]
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
		mut active_view_box := svg.parse_viewbox(view_box_text)
		if specification := svg.parse_view_specification(svg.decode_fragment_identifier(fragment)) {
			if view_box := specification.view_box { active_view_box = view_box }
		}
		if view_box := active_view_box {
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

fn big_endian_u16(data []u8, offset int) int {
	return (int(data[offset]) << 8) | int(data[offset + 1])
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
	if dimensions := webp_image_dimensions(data) {
		return dimensions
	}
	return jpeg_image_dimensions(data)
}

// JPEG decoders expose frame metadata before decoding the entropy-coded pixel
// stream. Layout only needs that metadata, so avoid fully decoding large local
// photographs while constructing an ImageBox.
fn jpeg_image_dimensions(data []u8) ?ImageDimensions {
	if data.len < 4 || data[0] != 0xff || data[1] != 0xd8 {
		return none
	}
	mut offset := 2
	for offset < data.len {
		for offset < data.len && data[offset] != 0xff {
			offset++
		}
		for offset < data.len && data[offset] == 0xff {
			offset++
		}
		if offset >= data.len {
			return none
		}
		marker := data[offset]
		offset++
		if marker == 0xd9 || marker == 0xda {
			return none
		}
		if marker == 0x01 || (marker >= 0xd0 && marker <= 0xd8) {
			continue
		}
		if offset + 2 > data.len {
			return none
		}
		segment_length := big_endian_u16(data, offset)
		if segment_length < 2 || offset + segment_length > data.len {
			return none
		}
		is_start_of_frame := marker in [u8(0xc0), 0xc1, 0xc2, 0xc3, 0xc5, 0xc6, 0xc7, 0xc9, 0xca,
			0xcb, 0xcd, 0xce, 0xcf]
		if is_start_of_frame {
			if segment_length < 7 {
				return none
			}
			height := big_endian_u16(data, offset + 3)
			width := big_endian_u16(data, offset + 5)
			if width > 0 && height > 0 {
				return ImageDimensions{
					width: width
					height: height
				}
			}
			return none
		}
		offset += segment_length
	}
	return none
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

pub fn (box &ImageBox) source() string {
	return box.source_
}

pub fn (box &ImageBox) uses_content_replacement() bool {
	return box.uses_content_replacement_
}

// Image providers own their decoded pixels. Sharing that owner in retained
// commands also keeps an older frame alive after a paint-only image update.
fn (box &ImageBox) replaced_image_bitmap() ?&dom.Bitmap_ {
	if box.uses_content_replacement_ { return none }
	node := box.dom_node() or { return none }
	element := node.as_element() or { return none }
	if !element.is_html_element() { return none }
	if element.local_name() == 'object' {
		model := html.html_object_element_model_for_dom_element(unsafe { &dom.HTMLObjectElement(element) })
		return model.image_data()
	}
	if element.local_name() == 'input' {
		model := html.HTMLInputElementModel.create(unsafe { &dom.HTMLInputElement(element) })
		frame := model.current_image_frame_sized(0, 0) or { return none }
		return frame.deferred_bitmap()
	}
	if !node.is_html_image_element() { return none }
	model := html.html_image_element_model_for_dom_element(unsafe { &dom.HTMLImageElement(element) })
	frame := model.current_image_frame() or { return none }
	// Recording shares the request's bitmap without its pixels; replay decodes
	// them only for an image it actually draws.
	bitmap := frame.deferred_bitmap()
	if !bitmap.native_resource_replay_compatible { return none }
	return bitmap
}

// ImagePaintable::reset_for_relayout() refreshes image availability whenever
// the retained layout tree is laid out again.
pub fn (mut box ImageBox) reset_for_relayout() {
	mut source := box.source_
	mut provider_natural_size := ?css.SizeWithAspectRatio(none)
	if !box.uses_content_replacement_ {
		if dom_node := box.dom_node() {
			if element := dom_node.as_element() {
				if element.is_html_element() && element.local_name() == 'object' {
					object_element := unsafe { &dom.HTMLObjectElement(element) }
					model := html.html_object_element_model_for_dom_element(object_element)
					source = model.data()
					provider_natural_size = available_object_image_natural_size(element)
				} else {
					source = image_source_for_layout(element)
					provider_natural_size = available_html_image_natural_size(element)
				}
			}
		}
	}
	old_source := box.source_
	box.source_ = source
	if natural_size := provider_natural_size {
		box.natural_size_ = natural_size
	} else if intrinsic_size := image_intrinsic_size_for_source(box.document_, source) {
		box.natural_size_ = natural_size_at_resolution(intrinsic_size, box.source_resolution_)
	} else {
		box.natural_size_ = css.SizeWithAspectRatio{
			width: CSSPixels.new(0)
			height: CSSPixels.new(0)
		}
	}
	mut decoded_svg_document := ?&dom.Document(none)
	if dom_node := box.dom_node() {
		if element := dom_node.as_element() {
			decoded_svg_document = available_html_svg_image_document(element)
		}
	}
	if isolated := decoded_svg_document {
		box.svg_image_document_ = isolated
	} else if source != old_source {
		box.svg_image_document_ = svg_image_document_for_source(box.document_, source)
	}
	box.refresh_svg_natural_size()
	box.auto_content_box_size_ = box.natural_size_
}

fn (mut box ImageBox) refresh_svg_natural_size() {
	if isolated := box.svg_image_document_ {
		box.natural_size_ = natural_size_at_resolution(svg_background_natural_size(isolated),
			box.source_resolution_)
	}
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
	// Video metadata is live. Do not cache the empty ReplacedBox default as an
	// auto content size; Box::compute_auto_content_box_size() delegates to this
	// box's natural_size() on every sizing pass.
	box.has_auto_content_box_size_ = false
	// VideoBox::can_have_children() has the same controls-shadow-root boundary
	// as AudioBox.
	box.replaced_can_have_children_ = element.shadow_root() != none
	return box
}

// Layout::VideoBox::natural_size(). Video dimensions remain live because
// metadata can arrive after the retained layout node has been constructed.
pub fn (box &VideoBox) natural_size() css.SizeWithAspectRatio {
	dom_node := box.dom_node() or { return css.SizeWithAspectRatio{} }
	element := dom_node.as_element() or { return css.SizeWithAspectRatio{} }
	if !element.is_html_element() || element.local_name() != 'video' {
		return css.SizeWithAspectRatio{}
	}
	video := unsafe { &dom.HTMLVideoElement(element) }
	model := html.html_video_element_model_for_dom_element(video)
	dimensions := model.natural_element_size() or { return css.SizeWithAspectRatio{} }
	return size_with_optional_aspect_ratio(CSSPixels.new(int(dimensions.width)), CSSPixels.new(int(dimensions.height)))
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
	box.has_auto_content_box_size_ = true
	box.auto_content_box_size_ = text_input_auto_content_box_size(unsafe { &Node(box) })
	return box
}

// Box.cpp's default_preferred_size_for_text_control() reads live element and
// layout style values, including when style refresh preserves the layout box.
fn text_input_auto_content_box_size(box_node &Node) css.SizeWithAspectRatio {
	dom_node := box_node.dom_node() or { return css.SizeWithAspectRatio{} }
	element := dom_node.as_element() or { return css.SizeWithAspectRatio{} }
	// TextInputBox::compute_auto_content_box_size(). The `size` attribute is a
	// `ch` length resolved against this box's own font, so the advance is
	// quantized to CSSPixels before it is multiplied - not after.
	columns := positive_integer_attribute_or_default(element, 'size', 20)
	mut width := resolve_font_dependent_length_for_node(box_node, css.Length.new(f64(columns), .ch))
	if box_node.document().font_rendering_policy() == .chromium {
		width = chromium_control_intrinsic_inline_size(box_node, columns, false)
	}
	// `normal` depends on the selected face's metrics. Read the document-
	// resolved values retained by the box instead of the pre-materialized
	// ComputedProperties passed across the style boundary.
	mut height := box_node.computed_values().line_height()
	if box_node.computed_values().writing_mode() != .horizontal_tb {
		width, height = height, width
	}
	return css.SizeWithAspectRatio{
		width: width
		height: height
	}
}

@[heap]
pub struct RangeInputBox {
	BlockContainer
}

pub fn RangeInputBox.new(document &dom.Document, element &dom.Element, computed_values &css.ComputedProperties) &RangeInputBox {
	mut box := &RangeInputBox{
		BlockContainer: special_block_container_base(document, element.as_node(), computed_values)
	}
	box.is_range_input_box_ = true
	// A horizontal slider has no in-flow content from which to derive its auto
	// size. Keep the platform default intrinsic width while leaving it eligible
	// for ordinary non-replaced grid-item stretching.
	box_node := unsafe { &Node(box) }
	box.has_auto_content_box_size_ = true
	box.auto_content_box_size_ = css.SizeWithAspectRatio{
		width: resolve_font_dependent_length_for_node(box_node, css.Length.new(20.0, .ch))
		height: CSSPixels.nearest_value_for(16 * document.layout_coordinate_scale())
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
	mut width := resolve_font_dependent_length_for_node(box_node, css.Length.new(f64(columns), .ch))
	mut height := resolve_font_dependent_length_for_node(box_node, css.Length.new(f64(rows), .lh))
	if document.font_rendering_policy() == .chromium {
		width = chromium_control_intrinsic_inline_size(box_node, columns, true)
		values := box_node.computed_values()
		inline_overflow := if values.writing_mode() == .horizontal_tb { values.overflow_x() } else { values.overflow_y() }
		if inline_overflow == .scroll {
			height = height.plus(chromium_control_scrollbar_thickness(box_node))
		}
	}
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
	// https://html.spec.whatwg.org/multipage/rendering.html#the-fieldset-and-legend-elements
	// If the computed outer display type is inline, the fieldset is expected to
	// behave as inline-block. Otherwise, it is expected to behave as flow-root.
	// This changes only the layout-facing display, not the computed value.
	display := box.computed_values_.display()
	if display.is_flow_inside() {
		mut values := unsafe { &css.MutableComputedValues(box.computed_values_) }
		values.set_display(css.Display.from_outside_inside_and_list_item(display.outside(), .flow_root,
			display.list_item()))
	}
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
	BlockContainer
pub:
	list_style_type_     css.ListStyleType
	list_style_position_ css.ListStylePosition
	list_item_element_   &dom.Element = unsafe { nil }
}

pub fn (box &ListItemMarkerBox) has_authored_content() bool {
	content := box.computed_values().computed_content() or { return false }
	return content.type_ == .list
}

pub fn ListItemMarkerBox.new(document &dom.Document, list_style_type css.ListStyleType, list_style_position css.ListStylePosition, list_item_element &dom.Element, computed_values &css.ComputedProperties) &ListItemMarkerBox {
	mut box := special_block_container_base(document, none, computed_values)
	box.is_list_item_marker_box_ = true
	return &ListItemMarkerBox{
		BlockContainer: box
		list_style_type_: list_style_type
		list_style_position_: list_style_position
		list_item_element_: list_item_element
	}
}

pub fn (box &ListItemMarkerBox) text() ?string {
	if box.has_authored_content() || box.list_style_image() != none {
		return none
	}
	if child := box.first_child() {
		if child.is_image_box() {
			return none
		}
	}
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

// Blink's predefined horizontal symbol markers use geometry, rather than the
// font's Unicode bullet. Authored marker content and images keep their normal
// layout and painting paths.
fn (box &ListItemMarkerBox) chromium_symbol_marker() bool {
	return box.document().font_rendering_policy() == .chromium
		&& box.list_style_position_ == .outside
		&& !box.has_authored_content() && box.list_style_image() == none
		&& box.list_style_type_.name in ['disc', 'circle', 'square']
		&& box.computed_values().writing_mode() == .horizontal_tb
		&& box.computed_values().direction() == .ltr
}

fn (box &ListItemMarkerBox) chromium_symbol_ascent() int {
	return int(box.first_available_font().inline_metrics().ascent)
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
	mut mutable_element := unsafe { &dom.Element(element) }
	ordinal := mutable_element.ordinal_value()
	registered_counter_styles := css.registered_counter_styles_for_marker(list_style_type, dom.AbstractElement.new(element, none))
	mut style := list_style_type.counter_style
	if resolved_style := registered_counter_styles[list_style_type.name] {
		style = resolved_style
	}
	representation := css.generate_a_counter_representation(style, registered_counter_styles, i32(ordinal))
	if resolved_style := style {
		return '${resolved_style.prefix()}${representation}${resolved_style.suffix()}'
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
