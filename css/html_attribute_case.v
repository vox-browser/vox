module css

import os

__global html_attribute_case_lookup_mode = 0

fn selector_html_attribute_is_case_insensitive_linear(name string) bool {
	return name in ['accept', 'accept-charset', 'align', 'alink', 'axis', 'bgcolor', 'charset', 'checked',
		'clear', 'codetype', 'color', 'compact', 'declare', 'defer', 'dir', 'direction', 'disabled',
		'enctype', 'face', 'frame', 'hreflang', 'http-equiv', 'lang', 'language', 'link', 'media',
		'method', 'multiple', 'nohref', 'noresize', 'noshade', 'nowrap', 'readonly', 'rel', 'rev',
		'rules', 'scope', 'scrolling', 'selected', 'shape', 'target', 'text', 'type', 'valign',
		'valuetype', 'vlink']
}

fn selector_html_attribute_is_case_insensitive(name string) bool {
	if html_attribute_case_lookup_mode == 0 {
		html_attribute_case_lookup_mode = if os.getenv('VOX_DISABLE_ATTRIBUTE_CASE_BUCKETS') == '' { 1 } else { 2 }
		if html_attribute_case_lookup_mode == 1 && os.getenv('VOX_ATTRIBUTE_CASE_DIAGNOSTICS') != '' {
			eprintln('Vox HTML attribute case: length buckets')
		}
	}
	if html_attribute_case_lookup_mode == 2 {
		return selector_html_attribute_is_case_insensitive_linear(name)
	}
	// Attribute names such as data-testid cannot match any HTML enumerated
	// attribute of a different byte length. Keep the exact original names.
	return match name.len {
		3 { name in ['dir', 'rel', 'rev'] }
		4 { name in ['axis', 'face', 'lang', 'link', 'text', 'type'] }
		5 { name in ['align', 'alink', 'clear', 'color', 'defer', 'frame', 'media', 'rules', 'scope', 'shape', 'vlink'] }
		6 { name in ['accept', 'method', 'nohref', 'nowrap', 'target', 'valign'] }
		7 { name in ['bgcolor', 'charset', 'checked', 'compact', 'declare', 'enctype', 'noshade'] }
		8 { name in ['codetype', 'disabled', 'hreflang', 'language', 'multiple', 'noresize', 'readonly', 'selected'] }
		9 { name in ['direction', 'scrolling', 'valuetype'] }
		10 { name in ['http-equiv'] }
		14 { name in ['accept-charset'] }
		else { false }
	}
}
