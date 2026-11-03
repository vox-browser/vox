module css

import processmetrics
import dom
import os

const diagnostic_style_reasons_enabled = os.getenv('VOX_DIAGNOSTIC_STYLE_REASONS') != ''
const diagnostic_style_elements_enabled = os.getenv('VOX_DIAGNOSTIC_STYLE_ELEMENTS') != ''
const diagnostic_longhand_inputs_enabled = os.getenv('VOX_DIAGNOSTIC_LONGHAND_INPUTS') != ''

__global (
	diagnostic_instruction_totals [18]u64
	diagnostic_instruction_calls [18]u64
	diagnostic_font_guard_rejections [16]u64
	diagnostic_style_update_causes [16]u64
	diagnostic_longhand_lookups [2]u64
	diagnostic_longhand_rejections map[string]u64
)

@[inline]
fn begin_diagnostic_instruction_scope() processmetrics.InstructionSnapshot {
	$if vox_css_diagnostics ? {
		return processmetrics.begin_instructions()
	}
	return processmetrics.InstructionSnapshot{}
}

@[inline]
fn record_diagnostic_instruction_scope(index int, start processmetrics.InstructionSnapshot) {
	$if vox_css_diagnostics ? {
		if count := processmetrics.instruction_snapshot().since(start) {
			diagnostic_instruction_totals[index] += count
			diagnostic_instruction_calls[index]++
		}
	}
}

@[inline]
fn diagnostic_font_guard_reject(index int) bool {
	$if vox_css_diagnostics ? {
		diagnostic_font_guard_rejections[index]++
	} $else {
		if diagnostic_style_reasons_enabled { diagnostic_font_guard_rejections[index]++ }
	}
	return false
}

@[inline]
fn record_diagnostic_style_update_cause(index int) {
	$if vox_css_diagnostics ? {
		diagnostic_style_update_causes[index]++
	} $else {
		if diagnostic_style_reasons_enabled { diagnostic_style_update_causes[index]++ }
	}
}

fn record_diagnostic_style_update_element(reason int, element &dom.Element) {
	if !diagnostic_style_elements_enabled || reason != 1 { return }
	eprintln('Vox dirty style element: ${element.document().url.serialize()} ${element.local_name()} id=${element.get_attribute_value('id')} class=${element.get_attribute_value('class')}')
}

fn record_diagnostic_longhand_lookup(hit bool) {
	$if vox_css_diagnostics ? {
		diagnostic_longhand_lookups[if hit { 1 } else { 0 }]++
	}
}

fn record_diagnostic_longhand_rejection(id PropertyID, value &dom.StyleValue) {
	if diagnostic_longhand_inputs_enabled {
		kind := if typed := typed_style_value_logic_from_dom(value) { typed.type_name() } else { 'untyped' }
		key := '${string_from_property_id(id)} ${kind}'
		if diagnostic_longhand_rejections[key] == 0 {
			eprintln('Vox rejected longhand input: ${key} ${value.css_text}')
		}
		diagnostic_longhand_rejections[key]++
	}
	$if vox_css_diagnostics ? {
		kind := if typed := typed_style_value_logic_from_dom(value) { typed.type_name() } else { 'untyped' }
		key := '${string_from_property_id(id)} ${kind}'
		diagnostic_longhand_rejections[key]++
	}
}

pub fn report_diagnostic_instruction_scopes() {
	if diagnostic_style_reasons_enabled {
		for index, count in diagnostic_font_guard_rejections {
			if count > 0 { eprintln('Vox runtime font guard: ${index} ${count}') }
		}
		for index, count in diagnostic_style_update_causes {
			if count > 0 { eprintln('Vox runtime style cause: ${index} ${count}') }
		}
	}
	$if vox_css_diagnostics ? {
		for index, count in diagnostic_font_guard_rejections {
			if count > 0 { eprintln('Vox diagnostic font guard: ${index} ${count}') }
		}
		for index, count in diagnostic_style_update_causes {
			if count > 0 { eprintln('Vox diagnostic style cause: ${index} ${count}') }
		}
		eprintln('Vox diagnostic longhand lookups: misses=${diagnostic_longhand_lookups[0]} hits=${diagnostic_longhand_lookups[1]}')
		for key, count in diagnostic_longhand_rejections {
			eprintln('Vox diagnostic longhand rejection: ${key} ${count}')
		}
		labels := ['diag_css_parser_create', 'diag_css_raw_stylesheet', 'diag_css_convert_rules',
			'diag_css_collect_matching', 'diag_css_compute_properties', 'diag_css_compute_style',
			'diag_css_cascade_values', 'diag_css_logical_context', 'diag_css_install_custom',
			'diag_css_reuse_custom', 'diag_css_materialize_values', 'diag_css_invalidation',
			'diag_css_candidate_buckets', 'diag_css_selector_matches',
			'diag_css_longhand_key', 'diag_css_longhand_loop', 'diag_css_computation_context',
			'diag_css_compute_value']
		for index, label in labels {
			if diagnostic_instruction_calls[index] > 0 {
				eprintln('Vox instructions scope: ${label} ${diagnostic_instruction_totals[index]}')
				eprintln('Vox diagnostic scope calls: ${label} ${diagnostic_instruction_calls[index]}')
			}
		}
	}
}
