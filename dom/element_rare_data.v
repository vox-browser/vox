module dom

// Keep the first pseudo record directly in its owner. An element with one
// pseudo needs no map; additional records share a lazily created overflow map.
@[heap]
struct ElementRareData {
mut:
	first_pseudo_type_ int
	first_pseudo_ &PseudoElement_ = unsafe { nil }
	additional_pseudos_ &ElementPseudoElementMap = unsafe { nil }
	style_data_ &ElementRareStyleData = unsafe { nil }
}

@[heap]
struct ElementPseudoElementMap {
mut:
	pseudo_element_data map[int]&PseudoElement_
}

@[heap]
struct ElementRareStyleData {
mut:
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

fn (mut e Element) ensure_rare_style_data() &ElementRareStyleData {
	mut data := e.ensure_rare_data()
	if data.style_data_ == unsafe { nil } {
		data.style_data_ = &ElementRareStyleData{}
	}
	return data.style_data_
}

// Computed pseudo styles can exist without a layout node. Keep this record
// count separate from has_pseudo_elements(), which checks live layout nodes.
pub fn (e &Element) pseudo_element_record_count() int {
	if e.rare_data_ == unsafe { nil } { return 0 }
	mut count := if e.rare_data_.first_pseudo_ == unsafe { nil } { 0 } else { 1 }
	if e.rare_data_.additional_pseudos_ != unsafe { nil } {
		count += e.rare_data_.additional_pseudos_.pseudo_element_data.len
	}
	return count
}

pub fn (mut e Element) remove_pseudo_element_record(typ int) {
	if e.rare_data_ == unsafe { nil } { return }
	if e.rare_data_.first_pseudo_ != unsafe { nil } && e.rare_data_.first_pseudo_type_ == typ {
		e.rare_data_.first_pseudo_ = unsafe { nil }
		return
	}
	if e.rare_data_.additional_pseudos_ != unsafe { nil } {
		e.rare_data_.additional_pseudos_.pseudo_element_data.delete(typ)
	}
}

fn (e &Element) pseudo_element_record_types() []int {
	mut types := []int{cap: e.pseudo_element_record_count()}
	if e.rare_data_ == unsafe { nil } { return types }
	if e.rare_data_.first_pseudo_ != unsafe { nil } {
		types << e.rare_data_.first_pseudo_type_
	}
	if e.rare_data_.additional_pseudos_ != unsafe { nil } {
		for typ, _ in e.rare_data_.additional_pseudos_.pseudo_element_data {
			types << typ
		}
	}
	return types
}
