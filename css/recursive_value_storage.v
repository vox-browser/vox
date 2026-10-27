module css

// Current V sum types store their variants inline. Recursive child values use
// array storage, as CalculationNode does, to keep finite layouts and structural
// value equality. Optional children retain their public value-based API.
fn optional_style_value_storage(value ?StyleValue) ?[]StyleValue {
	if child := value {
		return [child]
	}
	return none
}

fn style_value_from_optional_storage(value ?[]StyleValue) ?StyleValue {
	if children := value {
		return children[0]
	}
	return none
}
