module css

import dom
import os

const disable_selective_missing_style_query = os.getenv('VOX_DISABLE_SELECTIVE_MISSING_STYLE_QUERY') != ''
const selective_missing_style_query_diagnostics = os.getenv('VOX_SELECTIVE_MISSING_STYLE_QUERY_DIAGNOSTICS') != ''

__global selective_missing_style_query_reported bool

// A new connected element needs the ordinary top-down style walk, including
// pending inheritance and stylesheet changes. An already styled document does
// not need a fresh cascade for every unrelated branch just to bootstrap it.
fn prepare_missing_style_for_query(element &dom.Element) {
	mut document := element.document()
	mut selective := false
	if !disable_selective_missing_style_query && element.as_node().is_connected()
		&& !document.needs_full_style_update() {
		if root := document.document_element() {
			selective = root.el_computed_properties() != none
		}
	}
	if selective {
		mut node := element.as_node()
		node.set_needs_style_update(true)
	} else {
		document.set_needs_full_style_update(true)
	}
	document.update_style()
	if selective && element.el_computed_properties() != none
		&& selective_missing_style_query_diagnostics && !selective_missing_style_query_reported {
		selective_missing_style_query_reported = true
		eprintln('Vox computed style query: bootstrapped a connected element selectively')
	}
}
