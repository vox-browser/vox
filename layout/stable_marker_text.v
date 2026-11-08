module layout

import os

const disable_stable_symbol_marker_text_reuse = os.getenv('VOX_DISABLE_STABLE_SYMBOL_MARKER_TEXT_REUSE') != ''
const stable_symbol_marker_text_diagnostics = os.getenv('VOX_STABLE_SYMBOL_MARKER_TEXT_DIAGNOSTICS') != ''
__global stable_symbol_marker_text_reported bool

fn fixed_marker_symbol_text(text string) ?string {
	return match text {
		'•' { '•' }
		'• ' { '• ' }
		'◦' { '◦' }
		'◦ ' { '◦ ' }
		'▪' { '▪' }
		'▪ ' { '▪ ' }
		else { none }
	}
}

fn set_resolved_marker_text_for_layout(mut node TextNode, text string, symbol_marker bool) {
	// These fixed symbols have no case/width transformation or whitespace
	// replacement under text-transform:none. Keep an already identical rendered
	// string and its segmentation/shaping inputs. Ordinary font-owner validation
	// still invalidates shapes when the inherited font or style changes.
	if !disable_stable_symbol_marker_text_reuse && symbol_marker
		&& node.dom_node() == none && node.first_letter_ == none
		&& node.source_range_length_ == none && node.source_range_start_ == 0
		&& node.Node.computed_values().text_transform() == .none_ {
		if canonical := fixed_marker_symbol_text(text) {
			// A producer's generated string can belong to disposable measurement
			// storage. Establish a static source before keeping any derived cache;
			// inspect only addresses/lengths of old strings, never retired bytes.
			if voidptr(node.source_text_.str) == voidptr(canonical.str) && node.source_text_.len == canonical.len
				&& node.text_for_rendering_valid_ && voidptr(node.text_for_rendering_.str) == voidptr(canonical.str)
				&& node.text_for_rendering_.len == canonical.len {
				if stable_symbol_marker_text_diagnostics && !stable_symbol_marker_text_reported {
					stable_symbol_marker_text_reported = true
					eprintln('Vox marker text: retained unchanged fixed-symbol text inputs')
				}
				return
			}
			node.source_text_ = canonical
			node.invalidate_text_for_rendering()
			return
		}
	}
	node.source_text_ = text
	node.invalidate_text_for_rendering()
}
