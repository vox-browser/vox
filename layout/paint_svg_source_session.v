module layout

struct PaintSVGSourceProbe {
	image ?SVGImageSource
}

@[heap]
struct PaintSVGSourceSession {
mut:
	sources map[string]PaintSVGSourceProbe
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
