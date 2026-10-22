module layout

import css
import dom
import platform

struct SVGBackgroundImage {
	document ?&dom.Document
	resource ?&StaticSVGBackgroundResource
}

struct StaticSVGBackgroundScene {
	width    int
	height   int
	commands []PaintCommand
}

// Native recordings retain their host document's allocation owner. Shape-only
// images keep their source and independently owned pictures in that owner,
// instead of keeping a parsed DOM and layout tree for every sprite variant.
@[heap]
pub struct StaticSVGBackgroundResource {
	owner        &platform.RetainedArena
	font_policy  dom.FontRenderingPolicy
	source       SVGImageSource
	color_scheme string
	natural_size css.SizeWithAspectRatio
mut:
	fallback_document ?&dom.Document
	scenes            []StaticSVGBackgroundScene
}

pub fn enable_native_static_svg_backgrounds(document &dom.Document) {
	$if prealloc {
		mut mutable_document := unsafe { &dom.Document(document) }
		mutable_document.compact_native_svg_backgrounds = true
	}
}

// Resources keep independent URLs, policies and pictures, but identical source
// bytes need only one copy in their shared host owner. Call while that owner is
// entered; source probes may instead belong to a short-lived paint workspace.
fn retained_static_svg_background_source(viewport &Viewport, source string) string {
	for _, resource in viewport.static_svg_backgrounds_ {
		if resource.source.source == source { return resource.source.source }
	}
	return source.clone()
}

fn svg_background_image_for_source_in_viewport(node &Node, source string,
	color_scheme css.PreferredColorScheme) SVGBackgroundImage {
	if !node.document().compact_native_svg_backgrounds
		|| node.document().native_storage() == unsafe { nil } {
		return SVGBackgroundImage{
			document: svg_image_document_for_source_in_viewport(node, source, color_scheme)
		}
	}
	// Probe before the cache lookup, including failures and same-size updates.
	image_source := svg_image_source_for_paint(node, source) or { return SVGBackgroundImage{} }
	scheme := css.preferred_color_scheme_to_string(color_scheme)
	viewport := node.root_viewport() or {
		return SVGBackgroundImage{ document: parse_svg_image_document(image_source, scheme, node.document()) }
	}
	key := scheme + '\n' + node.document().font_rendering_policy().str() + '\n' + image_source.url.serialize()
	if existing := viewport.static_svg_backgrounds_[key] {
		if existing.source.source == image_source.source {
			return SVGBackgroundImage{ resource: existing }
		}
	}
	// Ineligible images keep the ordinary document cache, so a static-source
	// rejection does not parse the same image once for every background layer.
	generic_key := key
	if existing := viewport.svg_image_documents_[generic_key] {
		if existing.source == image_source.source {
			return SVGBackgroundImage{ document: existing.document }
		}
	}
	isolated := parse_svg_image_document(image_source, scheme, node.document()) or { return SVGBackgroundImage{} }
	mut child_owner := isolated.native_storage()
	mut inspection := child_owner.enter_nested()
	eligible := static_svg_document_is_eligible(isolated)
	inspection.finish()
	mut owner := node.document().native_storage()
	mut allocations := owner.enter_nested()
	defer { allocations.finish() }
	mut mutable_viewport := unsafe { &Viewport(viewport) }
	if !eligible {
		mutable_viewport.svg_image_documents_[generic_key.clone()] = SVGImageDocumentCacheEntry{
			source:   image_source.source.clone()
			document: isolated
		}
		return SVGBackgroundImage{ document: isolated }
	}
	resource := &StaticSVGBackgroundResource{
		owner:        owner
		font_policy:  node.document().font_rendering_policy()
		source:       SVGImageSource{
			source: retained_static_svg_background_source(viewport, image_source.source)
			url:    dom.URL{ value: image_source.url.serialize().clone() }
		}
		color_scheme: scheme.clone()
		natural_size: svg_background_natural_size(isolated)
	}
	mutable_viewport.static_svg_backgrounds_[key.clone()] = resource
	// A background outside the painted viewport may never request a picture.
	// Retire metadata-only parses too, rather than keeping their DOMs at idle.
	allocations.finish()
	retire_svg_image_document(isolated)
	return SVGBackgroundImage{ resource: resource }
}

pub fn (resource &StaticSVGBackgroundResource) natural_metrics() css.SizeWithAspectRatio {
	return resource.natural_size
}

fn (image SVGBackgroundImage) intrinsic_dimensions() (f64, f64) {
	if resource := image.resource {
		return background_svg_natural_dimensions(resource.natural_size)
	}
	return background_svg_intrinsic_dimensions(image.document)
}

// Only direct nested playback consumes these commands: all transforms and
// clips have already been resolved, and child-local context indices must not
// be looked up in the host's layout tree.
pub fn static_svg_background_commands(resource &StaticSVGBackgroundResource, width int,
	height int) ?[]PaintCommand {
	if width <= 0 || height <= 0 { return none }
	mut mutable_resource := unsafe { &StaticSVGBackgroundResource(resource) }
	for scene in resource.scenes {
		if scene.width == width && scene.height == height { return scene.commands }
	}
	if document := resource.fallback_document {
		return static_svg_document_commands(document, width, height)
	}
	document := parse_svg_image_document_with_owner(resource.source, resource.color_scheme,
		resource.font_policy, resource.owner) or { return none }
	commands := static_svg_document_commands(document, width, height) or {
		mutable_resource.fallback_document = document
		return none
	}
	// A resizable image cannot accumulate unbounded pictures. Once its small
	// size cache is full, subsequent dimensions use the ordinary live document.
	if resource.scenes.len >= 4 {
		mutable_resource.fallback_document = document
		return commands
	}
	mut owner := resource.owner
	mut allocations := owner.enter_nested()
	owned := own_static_svg_commands(commands)
	if picture := owned {
		mutable_resource.scenes << StaticSVGBackgroundScene{width, height, picture}
	}
	allocations.finish()
	if picture := owned {
		// No entered scope or copied command refers to the child at this point.
		retire_svg_image_document(document)
		return picture
	}
	mutable_resource.fallback_document = document
	return commands
}

fn static_svg_document_commands(document &dom.Document, width int, height int) ?[]PaintCommand {
	mut image := unsafe { &dom.Document(document) }
	viewport := image.viewport_rect()
	if viewport.width == f64(width) && viewport.height == f64(height)
		&& image.layout_is_up_to_date() && !image.needs_style_update_after_layout() {
		if list := image.cached_display_list() { return display_list_commands(list) }
	}
	mut owner := image.native_storage()
	mut allocations := owner.enter_nested()
	defer { allocations.finish() }
	enable_native_paint_tree_storage(image)
	_ = run_document_layout(image, f64(width), f64(height)) or { return none }
	list := image.record_display_list() or { return none }
	return display_list_commands(list)
}
