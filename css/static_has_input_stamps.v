module css

import dom
import os

const disable_static_has_input_stamps = os.getenv('VOX_DISABLE_STATIC_HAS_INPUT_STAMPS') != ''
const static_has_input_stamp_diagnostics = os.getenv('VOX_STATIC_HAS_INPUT_STAMP_DIAGNOSTICS') != ''
__global static_has_input_stamp_reported bool

// Only names and attributes participate in this proof. Dynamic pseudos,
// sibling relationships, nested selectors and namespace contexts still use
// the ordinary invalidation recheck and its traversal metadata.
fn has_argument_reads_only_static_inputs(selector Selector) bool {
	compounds := selector.compound_selectors()
	if compounds.len != 1 || compounds[0].combinator != .descendant { return false }
	for simple in compounds[0].simple_selectors {
		if simple.type_ !in [.class, .id, .tag_name, .universal, .attribute] { return false }
	}
	return true
}

struct StaticHasInputStamp {
	document u64
	tree u64
	attributes u64
	quirks bool
}

fn static_has_input_stamp(anchor &dom.Element) StaticHasInputStamp {
	document := anchor.document()
	return StaticHasInputStamp{
		document: u64(document.as_node().unique_id().value())
		tree: document.dom_tree_version()
		attributes: document.attribute_version()
		quirks: document.in_quirks_mode()
	}
}

fn (previous &ObservedHasArgument) static_inputs_are_unchanged(stamp StaticHasInputStamp) bool {
	return previous.static_inputs && previous.input_stamp == stamp
}

fn observed_has_argument(selector Selector, sheet ?&CSSStyleSheet, text string,
	sheet_identity u64, result bool, attempted PseudoClassBitmap, anchor &dom.Element) ObservedHasArgument {
	return ObservedHasArgument{
		selector: selector
		sheet: sheet
		selector_text: text
		sheet_identity: sheet_identity
		matched: result
		attempted: attempted
		static_inputs: has_argument_reads_only_static_inputs(selector)
		input_stamp: static_has_input_stamp(anchor)
	}
}

fn report_static_has_input_stamp() {
	if static_has_input_stamp_diagnostics && !static_has_input_stamp_reported {
		static_has_input_stamp_reported = true
		eprintln('Vox has input stamps: unchanged tree and attributes retained static argument result')
	}
}
