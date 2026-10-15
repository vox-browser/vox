module adblock

import json

fn test_full_ubo_cosmetic_filters_keep_domain_and_generic_exceptions() {
	$if !darwin { return }
	mut engine := new_engine('##.advert\n##.allowed\nexample.test#@#.allowed\nexample.test##.specific\n~example.test##.elsewhere')!
	defer { engine.close() }
	result := evaluate_custom_engine(engine.context,
		'JSON.stringify(voxDocumentFilters("https://example.test/", [".advert", ".allowed"]))')!
	filters := json.decode(DocumentFilters, result)!
	assert filters.css.contains('.advert')
	assert filters.css.contains('.specific')
	assert !filters.css.contains('.allowed')
	assert !filters.css.contains('.elsewhere')
}

fn test_theverge_uses_upstream_cosmetic_rules_and_scriptlets() {
	$if !darwin { return }
	filters := document_filters('https://www.theverge.com/', ['.ad-banner'])!
	assert filters.css.contains('div[data-concert]')
	assert filters.css.contains('.duet--layout--rail')
	assert filters.filters.any(it.contains('abort-current-script'))
	assert filters.filters.any(it.contains('csg_uid'))
	assert filters.filters.any(it.contains('vmidv1'))
	assert filters.scriptlets.contains('const scriptletGlobals =')
}

fn test_cosmetic_filtering_respects_network_generichide_exception() {
	$if !darwin { return }
	mut engine := new_engine('##.advert\nexample.test##.specific\n@@||example.test^$generichide')!
	defer { engine.close() }
	result := evaluate_custom_engine(engine.context,
		'JSON.stringify(voxDocumentFilters("https://example.test/", [".advert"]))')!
	filters := json.decode(DocumentFilters, result)!
	assert !filters.css.contains('.advert')
	assert filters.css.contains('.specific')
}
