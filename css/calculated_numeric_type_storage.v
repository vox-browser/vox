module css

import os

const calculated_numeric_storage_diagnostics = os.getenv('VOX_CALCULATED_NUMERIC_STORAGE_DIAGNOSTICS') != ''
__global calculated_numeric_storage_reported bool

// NumericType itself stays a value record. Its immutable owner keeps that
// relatively large optional payload out of every StyleValue variant's header.
// Public access returns an independent NumericType snapshot.
@[heap]
pub struct CalculatedNumericType {
	value NumericType
}

fn calculated_numeric_type_storage(value ?NumericType) ?&CalculatedNumericType {
	if type_ := value {
		if calculated_numeric_storage_diagnostics && !calculated_numeric_storage_reported {
			calculated_numeric_storage_reported = true
			eprintln('Vox calculation metadata: immutable numeric type stored outside the StyleValue header')
		}
		return &CalculatedNumericType{value: type_}
	}
	return none
}

fn calculated_numeric_types_equal(first ?&CalculatedNumericType,
	second ?&CalculatedNumericType) bool {
	if a := first {
		if b := second { return a.value == b.value }
		return false
	}
	return second == none
}

pub fn (a CalculatedStyleValue) == (b CalculatedStyleValue) bool {
	return a.serialization == b.serialization
		&& calculated_numeric_types_equal(a.numeric_type_, b.numeric_type_)
		&& a.calculation_context == b.calculation_context
		&& a.node == b.node
}
