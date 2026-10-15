module dom

// Most elements have no pseudo-element records, element-reference pseudos,
// CSS-defined animations or CSS random() values. Keep their ordinary V maps
// behind one managed allocation rather than constructing four empty maps for
// every HTML, SVG and MathML element.
@[heap]
struct ElementRareData {
mut:
	pseudo_element_data                     map[int]&PseudoElement_
	element_reference_pseudo_elements       map[int]&Element
	css_defined_animations                  map[int]map[string]&CSSAnimation_
	element_specific_css_random_base_values map[string]f64
}

fn (mut e Element) ensure_rare_data() &ElementRareData {
	if e.rare_data_ == unsafe { nil } {
		e.rare_data_ = &ElementRareData{}
	}
	return e.rare_data_
}

// Computed pseudo styles can exist without a layout node. Keep this record
// count separate from has_pseudo_elements(), which checks live layout nodes.
pub fn (e &Element) pseudo_element_record_count() int {
	if e.rare_data_ == unsafe { nil } { return 0 }
	return e.rare_data_.pseudo_element_data.len
}

pub fn (mut e Element) remove_pseudo_element_record(typ int) {
	if e.rare_data_ == unsafe { nil } { return }
	e.rare_data_.pseudo_element_data.delete(typ)
}
