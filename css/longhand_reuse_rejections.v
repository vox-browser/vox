module css

import dom

// With -d vox_css_diagnostics: why computed_longhand_reuse_key() found no key,
// by its first failing condition, so the uncached longhand loops can be
// attributed. Evaluated again only for the diagnostic report.
const longhand_reuse_rejection_labels = ['outside batch', 'recascaded font', 'pseudo-element',
	'namespace', 'root or quirks table', 'no parent', 'parent store or animation',
	'font-size environment changed', 'cascaded value', 'font-size question not repeated',
	'parent hash', 'font-size environment unstable']

__global diagnostic_longhand_reuse_rejections [12]u64
__global diagnostic_longhand_reuse_reevaluating bool

fn (s &StyleComputer) note_longhand_reuse_rejection(element dom.AbstractElement,
	cascaded &CascadedProperties, inherited ?&ComputedProperties, recascaded_font bool) {
	$if vox_css_diagnostics ? {
		diagnostic_longhand_reuse_reevaluating = true
		diagnostic_longhand_reuse_rejections[s.longhand_reuse_rejection(element, cascaded,
			inherited, recascaded_font)]++
		diagnostic_longhand_reuse_reevaluating = false
	}
}

fn (s &StyleComputer) longhand_reuse_rejection(element dom.AbstractElement,
	cascaded &CascadedProperties, inherited ?&ComputedProperties, recascaded_font bool) int {
	if s.computed_property_page_batch_depth_ == 0 { return 0 }
	if recascaded_font { return 1 }
	if element.pseudo_element() != none { return 2 }
	if !longhand_reuse_covers_namespace(element.element()) { return 3 }
	if element.element().local_name() == 'html' || is_quirks_table(element) { return 4 }
	parent := inherited or { return 5 }
	if parent.property_store_ == unsafe { nil } || parent.has_animated_properties() { return 6 }
	if s.longhand_reuse_cache_ != unsafe { nil }
		&& s.longhand_reuse_cache_.font_size_unit_environment_changed {
		for id in cascaded.entry_heads_.active {
			property := cascaded.style_property(id) or { continue }
			if font_size_unit_longhand_is_reusable(property.value) { return 7 }
		}
	}
	cascade_key := computed_longhand_cascade_key(cascaded, parent) or { return 8 }
	if cascade_key.font_size_units
		&& (s.longhand_reuse_cache_ == unsafe { nil } || s.longhand_reuse_cache_.entries.len == 0) {
		return 9
	}
	inherited_longhand_hash(parent) or { return 10 }
	return 11
}

fn report_longhand_reuse_rejections() {
	for index, count in diagnostic_longhand_reuse_rejections {
		if count > 0 {
			eprintln('Vox diagnostic longhand reuse rejection: ${longhand_reuse_rejection_labels[index]} ${count}')
		}
	}
}
