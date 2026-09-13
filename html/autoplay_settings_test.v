module html

import dom

fn test_autoplay_policy_parsing_and_origin_decisions() {
	assert autoplay_policy_from_string('allow-audio-and-video')? == .allow_audio_and_video
	assert autoplay_policy_from_string('block-audio')? == .block_audio
	assert autoplay_policy_from_string('block-audio-and-video')? == .block_audio_and_video
	assert autoplay_policy_from_string('invalid') == none
	assert autoplay_policy_to_string(.block_audio_and_video) == 'block-audio-and-video'

	mut document := dom.Document.create_for_fragment_parsing()
	document.set_url(dom.URL{'https://document.test/'})
	mut settings := AutoplaySettings.the()
	settings.set_policy(.block_audio_and_video, ['allowed.test', 'https://also-allowed.test'])
	assert settings.decision_for_origin(document,
		dom.URL{'https://allowed.test/video'}.origin()) == .allowed
	assert settings.decision_for_origin(document,
		dom.URL{'https://also-allowed.test/video'}.origin()) == .allowed
	assert settings.decision_for_origin(document,
		dom.URL{'https://blocked.test/video'}.origin()) == .blocked
	settings.set_policy(.block_audio, [])
	assert settings.decision_for_origin(document,
		dom.URL{'https://blocked.test/video'}.origin()) == .allowed_if_inaudible
	settings.set_policy(.block_audio, [])
}
