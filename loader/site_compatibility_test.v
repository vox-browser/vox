module loader

import dom
import x.json2

const compatibility_test_user_agent = 'Mozilla/5.0 Ladybird/1.0 Chrome/146.0.0.0 Safari/537.36'

fn compatibility_url(input string) dom.URL {
	return dom.dom_url_parse(input, dom.url_about_blank(), 'UTF-8') or { panic('invalid URL') }
}

fn compatibility_json(input string) json2.Any {
	return json2.decode[json2.Any](input) or { panic(err) }
}

fn test_site_compatibility_rule_matches_url_patterns() {
	rule := SiteCompatibilityRule.from_json(compatibility_json('{"matches":["https://www.example.com/*"],"user_agent":["hide_Ladybird"]}'))!
	assert rule.patterns() == ['https://www.example.com/*']
	assert rule.user_agent_transformations() == [.hide_ladybird]
	assert rule.matches(compatibility_url('https://www.example.com/article'))
	assert !rule.matches(compatibility_url('http://www.example.com/article'))
	assert !rule.matches(compatibility_url('https://example.com/article'))
	assert !rule.matches(compatibility_url('https://www.example.com.evil.test/article'))

	wide := SiteCompatibilityRule.create([
		'https://example.com/*',
		'https://*.example.com/*',
	], [.hide_ladybird], [])!
	assert wide.matches(compatibility_url('https://example.com/article'))
	assert wide.matches(compatibility_url('https://edition.news.example.com/article'))
	assert !wide.matches(compatibility_url('https://notexample.com/article'))
}

fn test_site_compatibility_transforms_only_matching_user_agents() {
	rule := SiteCompatibilityRule.create(['https://www.example.com/*'], [.hide_ladybird], [])!
	assert rule.apply_user_agent_transformations(compatibility_test_user_agent) == 'Mozilla/5.0 Chrome/146.0.0.0 Safari/537.36'
	assert rule.apply_user_agent_transformations('Ladybird/1.0') == ''
	assert rule.apply_user_agent_transformations('Mozilla/5.0 Ladybird Preview/1.0') == 'Mozilla/5.0 Ladybird Preview/1.0'
	assert rule.apply_user_agent_transformations('Mozilla/5.0 MyLadybird/1.0') == 'Mozilla/5.0 MyLadybird/1.0'

	mut data := SiteCompatibilityData{}
	data.add_rule(rule)
	assert data.user_agent_for_url(compatibility_url('https://www.example.com/'), compatibility_test_user_agent) == 'Mozilla/5.0 Chrome/146.0.0.0 Safari/537.36'
	assert data.user_agent_for_url(compatibility_url('https://elsewhere.example/'), compatibility_test_user_agent) == compatibility_test_user_agent
}

fn test_site_compatibility_maps_websocket_schemes_and_exposes_interfaces() {
	mut data := SiteCompatibilityData{}
	data.add_rule(SiteCompatibilityRule.create([
		'http://www.example.com/*',
		'https://secure.example.com/*',
	], [.hide_ladybird], ['PressureObserver'])!)
	assert data.user_agent_for_websocket_url(compatibility_url('ws://www.example.com/socket'), compatibility_test_user_agent) == 'Mozilla/5.0 Chrome/146.0.0.0 Safari/537.36'
	assert data.user_agent_for_websocket_url(compatibility_url('wss://secure.example.com/socket'), compatibility_test_user_agent) == 'Mozilla/5.0 Chrome/146.0.0.0 Safari/537.36'
	assert data.user_agent_for_websocket_url(compatibility_url('ws://secure.example.com/socket'), compatibility_test_user_agent) == compatibility_test_user_agent
	assert data.exposes_experimental_interface(compatibility_url('https://secure.example.com/'), 'PressureObserver')
	assert !data.exposes_experimental_interface(compatibility_url('https://other.example.com/'), 'PressureObserver')
}

fn test_site_compatibility_json_parsing_is_strict() {
	data := SiteCompatibilityData.from_json(compatibility_json('[{"matches":["https://www.example.com/*"],"expose_experimental_interfaces":["PressureObserver"]}]'))!
	assert data.rules().len == 1
	assert data.rules()[0].exposed_interfaces() == ['PressureObserver']

	mut missing_matches_rejected := false
	SiteCompatibilityRule.from_json(compatibility_json('{"user_agent":["hide_Ladybird"]}')) or {
		missing_matches_rejected = true
		assert err.msg().contains('matches')
	}
	assert missing_matches_rejected
	mut unknown_transformation_rejected := false
	SiteCompatibilityRule.from_json(compatibility_json('{"matches":["https://example.com/*"],"user_agent":["dance"]}')) or {
		unknown_transformation_rejected = true
		assert err.msg().contains('Unknown')
	}
	assert unknown_transformation_rejected
	mut invalid_pattern_rejected := false
	SiteCompatibilityRule.from_json(compatibility_json('{"matches":["["],"user_agent":["hide_Ladybird"]}')) or {
		invalid_pattern_rejected = true
		assert err.msg().contains('invalid URL pattern')
	}
	assert invalid_pattern_rejected
	mut missing_action_rejected := false
	SiteCompatibilityRule.from_json(compatibility_json('{"matches":["https://example.com/*"]}')) or {
		missing_action_rejected = true
		assert err.msg().contains("'user_agent'")
	}
	assert missing_action_rejected
}
