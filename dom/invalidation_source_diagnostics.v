module dom

import os
import platform

const trace_style_invalidation_sources = os.getenv('VOX_TRACE_STYLE_INVALIDATION_SOURCES') != ''

__global style_invalidation_source_counts map[string]int

fn trace_style_invalidation_source(node &Node, reason StyleInvalidationReason, source string) {
	if !trace_style_invalidation_sources { return }
	if element := node.as_element() {
		if element.el_computed_properties() == none { return }
	}
	persistent := platform.enter_persistent()
	defer { platform.leave_persistent(persistent) }
	key := '${source}/${int(reason)}'
	count := style_invalidation_source_counts[key]
	if count >= 8 { return }
	style_invalidation_source_counts[key] = count + 1
	if element := node.as_element() {
		eprintln('Vox style invalidation source: ${source} ${style_invalidation_reason_to_string(reason)} ${element.local_name()} id=${element.get_attribute_value('id').limit(120)} class=${element.get_attribute_value('class').limit(120)}')
	} else {
		eprintln('Vox style invalidation source: ${source} ${style_invalidation_reason_to_string(reason)} document=${node.is_document()}')
	}
}
