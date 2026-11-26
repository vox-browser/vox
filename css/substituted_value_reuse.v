module css

import dom
import os
import strings

// A declaration that uses var() is substituted and parsed again for every
// element. Primer's declarations carry fallback chains
// (var(--fgColor-muted, var(--color-fg-muted, #59636e))), so the single-var
// leaf cache rarely applies, and parsing the substituted tokens dominated the
// cascade. Parsing depends only on the property and the substituted component
// values, so within one style batch a fingerprint of those values (types, text,
// numbers, source positions, attr taint and nesting) selects an earlier parse
// of the same declaration with the same substitution. Parsed values are
// immutable and already shared by the single-var cache.
const disable_substituted_value_reuse = os.getenv('VOX_DISABLE_SUBSTITUTED_VALUE_REUSE') != ''
const substituted_value_reuse_diagnostics = os.getenv('VOX_SUBSTITUTED_VALUE_REUSE_DIAGNOSTICS') != ''
const substituted_value_reuse_limit = 8192

@[heap]
struct SubstitutedValueCache {
mut:
	entries map[string]&dom.StyleValue
	hits    u64
	misses  u64
}

fn write_substitution_token(mut out strings.Builder, token Token) {
	out.write_u8(`T`)
	out.write_decimal(i64(token.type_))
	out.write_u8(`:`)
	out.write_string(token.value)
	out.write_u8(0)
	out.write_decimal(i64(token.number_value_.type_))
	out.write_u8(`:`)
	out.write_string(u64(math_f64_bits(token.number_value_.value_)).hex())
	out.write_u8(`:`)
	out.write_decimal(i64(token.hash_type_))
	out.write_u8(`:`)
	out.write_string(token.original_source_text_)
	out.write_u8(0)
	out.write_decimal(i64(token.start_position_.line))
	out.write_u8(`.`)
	out.write_decimal(i64(token.start_position_.column))
	out.write_u8(`-`)
	out.write_decimal(i64(token.end_position_.line))
	out.write_u8(`.`)
	out.write_decimal(i64(token.end_position_.column))
	out.write_u8(`;`)
}

fn write_substitution_fingerprint(mut out strings.Builder, values []ComponentValue) {
	for value in values {
		out.write_u8(if value.attr_tainted { `a` } else { `c` })
		if value.is_token() {
			write_substitution_token(mut out, value.token())
		} else if value.is_function() {
			function := value.function()
			out.write_u8(`F`)
			out.write_string(function.name)
			write_substitution_token(mut out, function.name_token)
			out.write_u8(`(`)
			write_substitution_fingerprint(mut out, function.value)
			write_substitution_token(mut out, function.end_token)
			out.write_u8(`)`)
		} else if value.is_block() {
			block := value.block()
			out.write_u8(`B`)
			write_substitution_token(mut out, block.token)
			out.write_u8(`{`)
			write_substitution_fingerprint(mut out, block.value)
			write_substitution_token(mut out, block.end_token)
			out.write_u8(`}`)
		} else if value.is_guaranteed_invalid() {
			out.write_u8(`G`)
		} else {
			out.write_u8(`R`)
			out.write_string(value.to_string())
			out.write_u8(0)
		}
	}
}

fn math_f64_bits(value f64) u64 {
	return unsafe { *(&u64(&value)) }
}

// Empty when reuse does not apply: outside a style batch, or disabled.
fn substituted_value_fingerprint(element dom.AbstractElement, property_id PropertyID, result []ComponentValue) string {
	if disable_substituted_value_reuse { return '' }
	computer := css_style_computer_for(element.document())
	if computer.computed_property_page_batch_depth_ == 0 { return '' }
	mut out := strings.new_builder(256)
	out.write_decimal(i64(property_id))
	out.write_u8(`|`)
	write_substitution_fingerprint(mut out, result)
	return out.str()
}

fn lookup_substituted_value(element dom.AbstractElement, fingerprint string) ?&dom.StyleValue {
	if fingerprint == '' { return none }
	computer := css_style_computer_for(element.document())
	if computer.substituted_values_ == unsafe { nil } { return none }
	mut cache := computer.substituted_values_
	if value := cache.entries[fingerprint] {
		cache.hits++
		return value
	}
	cache.misses++
	return none
}

// Called after the workspace has been left, so the key copy and the map live
// as long as the batch, like the parsed value.
fn store_substituted_value(element dom.AbstractElement, fingerprint string, value &dom.StyleValue) {
	if fingerprint == '' { return }
	computer := css_style_computer_for(element.document())
	mut owner := unsafe { &StyleComputer(computer) }
	if owner.substituted_values_ == unsafe { nil } {
		owner.substituted_values_ = &SubstitutedValueCache{}
	}
	mut cache := owner.substituted_values_
	if cache.entries.len >= substituted_value_reuse_limit { return }
	cache.entries[fingerprint.clone()] = value
}

fn report_substituted_value_reuse(cache &SubstitutedValueCache) {
	if !substituted_value_reuse_diagnostics || cache == unsafe { nil } { return }
	eprintln('Vox substituted values: hits=${cache.hits} misses=${cache.misses} entries=${cache.entries.len}')
}
