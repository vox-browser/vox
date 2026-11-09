module css

// Current V sum types store their variants inline. A recursive child uses a
// separate slot; nil represents an absent child. Public accessors still return
// optional values, while the storage avoids an array header for one element.
fn optional_style_value_storage(value ?StyleValue) &StyleValueSlot {
	if child := value {
		return style_value_slot(child)
	}
	return unsafe { nil }
}

fn style_value_from_optional_storage(value &StyleValueSlot) ?StyleValue {
	if value != unsafe { nil } {
		return value.value
	}
	return none
}
