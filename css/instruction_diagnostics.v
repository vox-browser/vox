module css

import processmetrics

__global (
	diagnostic_instruction_totals [14]u64
	diagnostic_instruction_calls [14]u64
	diagnostic_font_guard_rejections [16]u64
	diagnostic_style_update_causes [16]u64
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
	}
	return false
}

@[inline]
fn record_diagnostic_style_update_cause(index int) {
	$if vox_css_diagnostics ? {
		diagnostic_style_update_causes[index]++
	}
}

pub fn report_diagnostic_instruction_scopes() {
	$if vox_css_diagnostics ? {
		for index, count in diagnostic_font_guard_rejections {
			if count > 0 { eprintln('Vox diagnostic font guard: ${index} ${count}') }
		}
		for index, count in diagnostic_style_update_causes {
			if count > 0 { eprintln('Vox diagnostic style cause: ${index} ${count}') }
		}
		labels := ['diag_css_parser_create', 'diag_css_raw_stylesheet', 'diag_css_convert_rules',
			'diag_css_collect_matching', 'diag_css_compute_properties', 'diag_css_compute_style',
			'diag_css_cascade_values', 'diag_css_logical_context', 'diag_css_install_custom',
			'diag_css_reuse_custom', 'diag_css_materialize_values', 'diag_css_invalidation',
			'diag_css_candidate_buckets', 'diag_css_selector_matches']
		for index, label in labels {
			if diagnostic_instruction_calls[index] > 0 {
				eprintln('Vox instructions scope: ${label} ${diagnostic_instruction_totals[index]}')
				eprintln('Vox diagnostic scope calls: ${label} ${diagnostic_instruction_calls[index]}')
			}
		}
	}
}
