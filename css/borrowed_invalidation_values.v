module css

import dom
import os

const retain_invalidation_value_copies = os.getenv('VOX_RETAIN_INVALIDATION_VALUE_COPIES') != ''
const borrowed_invalidation_values_diagnostics = os.getenv('VOX_BORROWED_INVALIDATION_VALUES_DIAGNOSTICS') != ''

__global (
	borrowed_invalidation_values_hits u64
	borrowed_invalidation_values_reported_document dom.UniqueNodeID
)

// Compare the complete payload of these scalar alternatives. In particular,
// floating-point equality preserves NaN's non-reflexive behavior. Composite
// values retain StyleValue.equals(), including its specialized semantics.
fn borrowed_scalar_style_values_changed(old &TypedStyleValueBox, new &TypedStyleValueBox) ?bool {
	match old.value {
		KeywordStyleValue {
			if new.value is KeywordStyleValue { return old.value.keyword_ != new.value.keyword_ }
		}
		LengthStyleValue {
			if new.value is LengthStyleValue { return old.value.length_ != new.value.length_ }
		}
		NumberStyleValue {
			if new.value is NumberStyleValue { return old.value.value_ != new.value.value_ }
		}
		IntegerStyleValue {
			if new.value is IntegerStyleValue { return old.value.value_ != new.value.value_ }
		}
		PercentageStyleValue {
			if new.value is PercentageStyleValue { return old.value.percentage_ != new.value.percentage_ }
		}
		ColorStyleValue {
			if new.value is ColorStyleValue { return old.value.color_ != new.value.color_ }
		}
		DisplayStyleValue {
			if new.value is DisplayStyleValue { return old.value.display_ != new.value.display_ }
		}
		StringStyleValue {
			if new.value is StringStyleValue { return old.value.string_value_ != new.value.string_value_ }
		}
		CustomIdentStyleValue {
			if new.value is CustomIdentStyleValue { return old.value.custom_ident_ != new.value.custom_ident_ }
		}
		else { return none }
	}
	// The old alternative was supported, but the new alternative differs.
	return true
}

@[inline]
fn record_borrowed_invalidation_value() {
	if borrowed_invalidation_values_diagnostics { borrowed_invalidation_values_hits++ }
}

@[inline]
fn borrowed_invalidation_diagnostic_start() u64 {
	return if borrowed_invalidation_values_diagnostics { borrowed_invalidation_values_hits } else { 0 }
}

fn report_borrowed_invalidation_values(style &ComputedProperties, start u64) {
	if !borrowed_invalidation_values_diagnostics || borrowed_invalidation_values_hits == start { return }
	element := style.subject_element_ or { return }
	document := element.document()
	identity := document.as_node().unique_id()
	if borrowed_invalidation_values_reported_document != identity {
		borrowed_invalidation_values_reported_document = identity
		eprintln('Vox invalidation values: compared retained scalar payloads; document=${document.url.serialize()}')
	}
}
