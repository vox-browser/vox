module layout

import dom

struct PaintSVGSourceProbe {
	image ?SVGImageSource
}

@[heap]
struct PaintSVGSourceSession {
mut:
	sources map[string]PaintSVGSourceProbe
	resolved_urls map[string]string
}

// Keep repeated sprite resolutions within this paint build. Resolve the live
// document base and encoding before lookup, so changes during a nested paint
// cannot reuse a result from the previous URL context.
fn resolve_css_paint_image_url(node &Node, source string, base_url ?string) string {
	base := if explicit := base_url { dom.URL{value: explicit} } else { node.document().base_url() }
	encoding := if base_url != none { '' } else { node.document().encoding_or_default() }
	viewport := node.root_viewport() or { return parse_css_paint_image_url(source, base, encoding) }
	mut session := viewport.paint_svg_sources_
	if session == unsafe { nil } { return parse_css_paint_image_url(source, base, encoding) }
	base_text := base.serialize()
	key := '${encoding.len}:${encoding}${base_text.len}:${base_text}${source}'
	if resolved := session.resolved_urls[key] { return resolved }
	resolved := parse_css_paint_image_url(source, base, encoding)
	session.resolved_urls[key] = resolved
	return resolved
}

fn parse_css_paint_image_url(source string, base dom.URL, encoding string) string {
	if parsed := dom.dom_url_parse(source, base, encoding) {
		return parsed.to_string()
	}
	return source
}

struct PaintSVGSourceScope {
	viewport ?&Viewport
	previous &PaintSVGSourceSession = unsafe { nil }
}

// A paint-tree build sees one resource snapshot. Repeated background sprites
// should not repeat URL parsing, request filtering and SVG format probes for
// every owner. Failed probes expire with this build, so a completed resource
// or same-URL replacement remains visible to the next refresh.
fn begin_paint_svg_source_session(node &Node) PaintSVGSourceScope {
	viewport := node.root_viewport() or { return PaintSVGSourceScope{} }
	previous := viewport.paint_svg_sources_
	mut mutable_viewport := unsafe { &Viewport(viewport) }
	mutable_viewport.paint_svg_sources_ = &PaintSVGSourceSession{}
	return PaintSVGSourceScope{ viewport: viewport, previous: previous }
}

fn (scope PaintSVGSourceScope) finish() {
	if viewport := scope.viewport {
		mut mutable_viewport := unsafe { &Viewport(viewport) }
		mutable_viewport.paint_svg_sources_ = scope.previous
	}
}

fn svg_image_source_for_paint(node &Node, source string) ?SVGImageSource {
	viewport := node.root_viewport() or {
		return svg_image_source_for_source(node.document(), source)
	}
	mut session := viewport.paint_svg_sources_
	if session == unsafe { nil } {
		return svg_image_source_for_source(node.document(), source)
	}
	// Referenced SVG nodes can belong to a different document while sharing
	// the embedding viewport. Preserve that owner's URL and request context.
	key := u64(voidptr(node.document())).str() + '\n' + source
	if probe := session.sources[key] { return probe.image }
	image := svg_image_source_for_source(node.document(), source)
	session.sources[key] = PaintSVGSourceProbe{ image: image }
	return image
}
