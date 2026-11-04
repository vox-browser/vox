module css

import os

const retain_empty_media_query_recursion = os.getenv('VOX_RETAIN_EMPTY_MEDIA_QUERY_RECURSION') != ''
const empty_media_query_list_diagnostics = os.getenv('VOX_EMPTY_MEDIA_QUERY_LIST_DIAGNOSTICS') != ''

__global empty_media_query_list_reported bool

// An empty child list has no media match state or other evaluation effects.
// Inspect its live length each time so later CSSOM edits need no cache invalidation.
// This guard applies only to nested lists, never to a stylesheet's own media.
@[inline]
fn (rule_list &CSSRuleList) should_evaluate_nested_media_queries() bool {
	if retain_empty_media_query_recursion || rule_list.rules.len != 0 { return true }
	if empty_media_query_list_diagnostics && !empty_media_query_list_reported {
		empty_media_query_list_reported = true
		eprintln('Vox media queries: skipped empty nested rule list')
	}
	return false
}
