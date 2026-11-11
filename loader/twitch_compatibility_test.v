// Copyright (c) 2026-present, the Ladybird developers.
// SPDX-License-Identifier: BSD-2-Clause

module loader

import dom

// Ladybird 749cd4348e29ede4ffbe055e4c5839d3e656a6f2.
fn test_default_loader_applies_twitch_override_only_to_its_secure_urls() {
	mut resource := ResourceLoader.create()
	default_agent := resource.user_agent()
	for url in ['https://twitch.tv/', 'https://www.twitch.tv/videos/1',
		'https://player.twitch.tv/?channel=test', 'https://a.b.twitch.tv/'] {
		actual := resource.user_agent_for_url(dom.URL{value: url})
		assert !actual.contains('Ladybird/')
		assert actual.contains(compatibility_token)
	}
	for url in ['http://twitch.tv/', 'https://nottwitch.tv/',
		'https://twitch.tv.example.test/', 'https://example.test/twitch.tv/'] {
		assert resource.user_agent_for_url(dom.URL{value: url}) == default_agent
	}
	assert !resource.user_agent_for_websocket_url(dom.URL{value: 'wss://twitch.tv/socket'}).contains('Ladybird/')
	assert resource.user_agent_for_websocket_url(dom.URL{value: 'ws://twitch.tv/socket'}) == default_agent
	resource.set_site_compatibility_data(SiteCompatibilityData{})
	assert resource.user_agent_for_url(dom.URL{value: 'https://twitch.tv/'}) == default_agent
}
