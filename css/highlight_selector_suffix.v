module css

fn highlight_selector_suffix_is_valid(pseudo PseudoElement, suffix []SimpleSelector) bool {
	if suffix.len == 0 { return true }
	if pseudo != .search_text || suffix.len != 1 || suffix[0].type_ != .pseudo_class { return false }
	selector := suffix[0].pseudo_class()
	if selector.type_ == .current_ { return true }
	if selector.type_ != .not_ { return false }
	list := selector.argument_selector_list.selectors
	if list.len != 1 { return false }
	compounds := list[0].compound_selectors()
	return compounds.len == 1 && compounds[0].simple_selectors.len == 1
		&& compounds[0].simple_selectors[0].type_ == .pseudo_class
		&& compounds[0].simple_selectors[0].pseudo_class().type_ == .current_
}
