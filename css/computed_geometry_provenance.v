module css

import dom

// Raw property arrays are shared by ordinary ComputedProperties value copies.
// A mutation epoch shared by those copies invalidates every geometry snapshot
// derived from that graph, without changing the existing resolved-value flag.
@[heap]
struct ComputedPropertyGraphMutationToken {
mut:
	generation u64 = 1
	observed   bool
}

@[heap]
struct ComputedGeometryProvenance {
	document                      &dom.Document = unsafe { nil }
	token                         &ComputedPropertyGraphMutationToken
	generation                    u64
	viewport                      CSSPixelRect
	root_font_size                f64
	root_line_height              f64
	root_font_depends_on_viewport bool
	subject                       ?&dom.Element
	font_list                     &FontCascadeList
	font_computer                 &FontComputer
	font_generation               u64
}

fn (c &ComputedProperties) geometry_provenance() &ComputedGeometryProvenance {
	if c.shared_geometry_cache_ != unsafe { nil }
		&& voidptr(c.shared_geometry_cache_) == voidptr(c.computed_layout_cache_) {
		return c.shared_geometry_provenance_
	}
	return c.computed_layout_cache().resolution_provenance
}

struct AnonymousComputedGeometrySource {
	cache           &ComputedLayoutCache
	font_list       &FontCascadeList
	font_computer   &FontComputer
	font_generation u64
}

// Consumers retaining derived data need to detect in-place inherited-style
// updates as well as replacement of the ComputedProperties object. Zero means
// that this graph cannot supply a usable revision (unknown owner or saturation).
pub fn (c &ComputedProperties) mutation_revision() u64 {
	if c.computed_property_graph_token_ == unsafe { nil } { return 0 }
	mut token := unsafe { &ComputedPropertyGraphMutationToken(c.computed_property_graph_token_) }
	token.observed = true
	return token.generation
}

fn (mut c ComputedProperties) note_computed_property_graph_mutation() {
	if c.computed_property_graph_token_ != unsafe { nil }
		&& c.computed_property_graph_token_.observed {
		// A saturated token remains invalid forever, rather than wrapping back
		// to a generation retained by an old snapshot.
		if c.computed_property_graph_token_.generation == ~u64(0) {
			c.computed_property_graph_token_.generation = 0
		} else if c.computed_property_graph_token_.generation != 0 {
			c.computed_property_graph_token_.generation++
		}
	}
}

fn computed_geometry_subject_matches(first ?&dom.Element, second ?&dom.Element) bool {
	if a := first {
		b := second or { return false }
		return voidptr(a) == voidptr(b)
	}
	return second == none
}

fn (p &ComputedGeometryProvenance) matches(c &ComputedProperties) bool {
	fonts := c.cached_computed_font_list_ or { return false }
	return voidptr(p.token) == voidptr(c.computed_property_graph_token_) && p.generation != 0
		&& p.generation == p.token.generation && p.viewport == c.viewport_rect_
		&& p.root_font_size == c.root_font_size_px_ && p.root_line_height == c.root_line_height_px_
		&& p.root_font_depends_on_viewport == c.root_font_metrics_depend_on_viewport_metrics_
		&& computed_geometry_subject_matches(p.subject, c.subject_element_)
		&& voidptr(p.font_computer) == voidptr(c.cached_computed_font_list_owner_)
		&& p.font_generation == c.cached_computed_font_list_generation_
		&& voidptr(fonts) == voidptr(p.font_list)
}

fn (mut c ComputedProperties) publish_computed_geometry_provenance(previous &ComputedGeometryProvenance) {
	if previous != unsafe { nil } && previous.matches(c)
		&& voidptr(previous.document) == voidptr(c.computed_layout_cache_.document_resolution_owner) {
		c.computed_layout_cache_.resolution_provenance = previous
		return
	}
	// Raw record literals cannot prove that earlier value copies share a token.
	// Constructors create it with the raw array; unknown records keep fallback.
	if c.computed_property_graph_token_ == unsafe { nil } { return }
	fonts := c.cached_computed_font_list_ or { return }
	c.computed_property_graph_token_.observed = true
	c.computed_layout_cache_.resolution_provenance = &ComputedGeometryProvenance{
		document:                      c.computed_layout_cache_.document_resolution_owner
		token:                         c.computed_property_graph_token_
		generation:                    c.computed_property_graph_token_.generation
		viewport:                      c.viewport_rect_
		root_font_size:                c.root_font_size_px_
		root_line_height:              c.root_line_height_px_
		root_font_depends_on_viewport: c.root_font_metrics_depend_on_viewport_metrics_
		subject:                       c.subject_element_
		font_list:                     fonts
		font_computer:                 c.cached_computed_font_list_owner_
		font_generation:               c.cached_computed_font_list_generation_
	}
}

fn (c &ComputedProperties) anonymous_computed_geometry_source(clone &ComputedProperties) ?AnonymousComputedGeometrySource {
	cache := c.computed_layout_cache_
	if !c.computed_values_resolved_ || cache == unsafe { nil } || c.has_animated_properties()
		|| c.has_animated_custom_properties() || c.line_height_ != none
		|| c.geometry_provenance() == unsafe { nil } || !c.geometry_provenance().matches(c) {
		return none
	}
	// The clone has an independent raw property array but must retain the
	// exact context against which these inherited geometry values resolved.
	p := c.geometry_provenance()
	if p.viewport != clone.viewport_rect_ || p.root_font_size != clone.root_font_size_px_
		|| p.root_line_height != clone.root_line_height_px_
		|| p.root_font_depends_on_viewport != clone.root_font_metrics_depend_on_viewport_metrics_
		|| !computed_geometry_subject_matches(p.subject, clone.subject_element_) {
		return none
	}
	// The anonymous box resolves against this captured snapshot, which must
	// survive a later restyle of its parent unchanged.
	c.share_computed_layout_cache()
	return AnonymousComputedGeometrySource{
		cache:           cache
		font_list:       p.font_list
		font_computer:   p.font_computer
		font_generation: p.font_generation
	}
}
