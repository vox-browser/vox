module css

import os

const retain_style_value_union_comparisons = os.getenv('VOX_RETAIN_STYLE_VALUE_UNION_COMPARISONS') != ''
const scalar_style_comparison_diagnostics = os.getenv('VOX_SCALAR_STYLE_COMPARISON_DIAGNOSTICS') != ''
__global scalar_style_comparison_reported bool

// The ordinary sum-type equality copies its largest variant even for a small
// number or keyword. Compare the complete concrete record instead. Complex
// values retain StyleValue.equals, including its specialized image semantics.
fn scalar_style_values_equal(first &StyleValue, second &StyleValue) bool {
	if scalar_style_comparison_diagnostics && !scalar_style_comparison_reported {
		scalar_style_comparison_reported = true
		eprintln('VOX_SCALAR_STYLE_COMPARISON compared concrete payloads')
	}
	return match first {
		KeywordStyleValue { if second is KeywordStyleValue { first.keyword_ == second.keyword_ } else { false } }
		LengthStyleValue { if second is LengthStyleValue { first.length_ == second.length_ } else { false } }
		ColorStyleValue { if second is ColorStyleValue { first.color_ == second.color_ } else { false } }
		NumberStyleValue { if second is NumberStyleValue { first.value_ == second.value_ } else { false } }
		IntegerStyleValue { if second is IntegerStyleValue { first.value_ == second.value_ } else { false } }
		PercentageStyleValue { if second is PercentageStyleValue { first.percentage_ == second.percentage_ } else { false } }
		StringStyleValue { if second is StringStyleValue { first.string_value_ == second.string_value_ } else { false } }
		CustomIdentStyleValue { if second is CustomIdentStyleValue { first.custom_ident_ == second.custom_ident_ } else { false } }
		AngleStyleValue { if second is AngleStyleValue { first.angle_ == second.angle_ } else { false } }
		TimeStyleValue { if second is TimeStyleValue { first.time_ == second.time_ } else { false } }
		FrequencyStyleValue { if second is FrequencyStyleValue { first.frequency_ == second.frequency_ } else { false } }
		ResolutionStyleValue { if second is ResolutionStyleValue { first.resolution_ == second.resolution_ } else { false } }
		FlexStyleValue { if second is FlexStyleValue { first.flex_ == second.flex_ } else { false } }
		DisplayStyleValue { if second is DisplayStyleValue { first.display_ == second.display_ } else { false } }
		GridAutoFlowStyleValue {
			if second is GridAutoFlowStyleValue { first.row_ == second.row_ && first.dense_ == second.dense_ } else { false }
		}
		StyleValueList {
			if second is StyleValueList {
				// Match properties_equal: collapsibility is intentionally not part
				// of StyleValueList.equals, while separator and child types are.
				if first.separator_ != second.separator_ || first.values_.len != second.values_.len { return false }
				for index in 0 .. first.values_.len {
					if !scalar_style_values_equal(&first.values_[index], &second.values_[index]) { return false }
				}
				true
			} else { false }
		}
		else { style_values_equal_using_union(*first, *second) }
	}
}
