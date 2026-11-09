module css

import dom
import os

// Raw property arrays are shared by ordinary ComputedProperties value copies.
// A mutation epoch shared by those copies invalidates every geometry snapshot
// derived from that graph, without changing the existing resolved-value flag.
@[heap]
struct ComputedPropertyGraphMutationToken {
mut:
	generation     u64 = 1
	raw_generation u64 = 1
	observed       bool
}

@[heap]
struct ComputedGeometryProvenance {
	document                      &dom.Document = unsafe { nil }
	token                         &ComputedPropertyGraphMutationToken
	generation                    u64
	raw_generation                u64
	compositor_only_animations    bool
	viewport                      CSSPixelRect
	root_font_size                f64
	root_line_height              f64
	root_font_depends_on_viewport bool
	subject_is_pseudo              bool
	subject                       ?&dom.Element
	font_list                     &FontCascadeList
	font_computer                 &FontComputer
	font_generation               u64
	font_cascade_was_settled       bool
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
	font_cascade_was_settled bool
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

// Animation samples change the effective graph without changing the raw
// cascade. Keep both revisions on the shared token so writes through a value
// alias also invalidate an animated target's otherwise reusable geometry.
fn (mut c ComputedProperties) note_raw_computed_property_graph_mutation() {
	c.note_computed_property_graph_mutation()
	if c.computed_property_graph_token_ != unsafe { nil }
		&& c.computed_property_graph_token_.observed {
		if c.computed_property_graph_token_.raw_generation == ~u64(0) {
			c.computed_property_graph_token_.raw_generation = 0
		} else if c.computed_property_graph_token_.raw_generation != 0 {
			c.computed_property_graph_token_.raw_generation++
		}
	}
}

fn (c &ComputedProperties) has_only_compositor_animated_properties() bool {
	if c.has_animated_custom_properties() { return false }
	if c.animated_property_storage_ != unsafe { nil } {
		for property, _ in c.animated_property_storage_.values {
			if !property_is_compositor_animated(property) { return false }
		}
	}
	return true
}

fn computed_geometry_subject_matches(first ?&dom.Element, second ?&dom.Element) bool {
	if a := first {
		b := second or { return false }
		return voidptr(a) == voidptr(b)
	}
	return second == none
}

const disable_live_font_geometry_reuse = os.getenv('VOX_DISABLE_LIVE_FONT_GEOMETRY_REUSE') != ''
const live_font_geometry_diagnostics = os.getenv('VOX_LIVE_FONT_GEOMETRY_DIAGNOSTICS') != ''

// The original cascade must still be live; a replacement with equal metrics
// cannot establish which fonts produced the older resolved geometry.
fn (c &ComputedProperties) font_geometry_generation_is_current(computer &FontComputer, generation u64, was_settled bool) bool {
	if generation == c.cached_computed_font_list_generation_ { return true }
	if disable_live_font_geometry_reuse || !was_settled || computer == unsafe { nil }
		|| generation > c.cached_computed_font_list_generation_
		|| !c.cached_font_inputs_are_unchanged_since(computer, generation) {
		return false
	}
	if live_font_geometry_diagnostics {
		eprintln('Vox font geometry: retained original cascade across environment change')
	}
	return true
}

fn (p &ComputedGeometryProvenance) matches(c &ComputedProperties) bool {
	return p.matches_context(c) && p.generation != 0 && p.generation == p.token.generation
}

fn (p &ComputedGeometryProvenance) matches_context(c &ComputedProperties) bool {
	fonts := c.cached_computed_font_list_ or { return false }
	return voidptr(p.token) == voidptr(c.computed_property_graph_token_) && p.viewport == c.viewport_rect_
		&& p.root_font_size == c.root_font_size_px_ && p.root_line_height == c.root_line_height_px_
		&& p.root_font_depends_on_viewport == c.root_font_metrics_depend_on_viewport_metrics_
		&& p.subject_is_pseudo == c.subject_is_pseudo_
		&& computed_geometry_subject_matches(p.subject, c.subject_element_)
		&& voidptr(p.font_computer) == voidptr(c.cached_computed_font_list_owner_)
		&& c.font_geometry_generation_is_current(p.font_computer, p.font_generation, p.font_cascade_was_settled)
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
		raw_generation:                c.computed_property_graph_token_.raw_generation
		compositor_only_animations:    c.has_only_compositor_animated_properties()
		viewport:                      c.viewport_rect_
		root_font_size:                c.root_font_size_px_
		root_line_height:              c.root_line_height_px_
		root_font_depends_on_viewport: c.root_font_metrics_depend_on_viewport_metrics_
		subject:                       c.subject_element_
		subject_is_pseudo:              c.subject_is_pseudo_
		font_list:                     fonts
		font_computer:                 c.cached_computed_font_list_owner_
		font_generation:               c.cached_computed_font_list_generation_
		font_cascade_was_settled:       fonts.pending_faces.len == 0
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
		|| p.subject_is_pseudo != clone.subject_is_pseudo_
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
		font_cascade_was_settled: p.font_cascade_was_settled
	}
}
