module speech

import dom

fn test_grammar_result_and_list_indexed_getters() {
	mut grammar := SpeechGrammar.construct_impl()
	grammar.set_src('grammar:test')
	grammar.set_weight(0.5)
	mut grammars := SpeechGrammarList.construct_impl()
	grammars.replace_from_platform([grammar])
	assert grammars.length() == 1
	assert grammars.item(0) or { panic('missing') }.src() == 'grammar:test'
	assert grammars.item(1) == none
	alternative := SpeechRecognitionAlternative.from_platform('hello', 0.9)
	assert alternative.transcript() == 'hello'
	assert alternative.confidence() == f32(0.9)
	mut result := SpeechRecognitionResult.create()
	result.populate_from_platform([alternative], true)
	mut results := SpeechRecognitionResultList.create()
	results.replace_from_platform([result])
	assert results.item(0) or { panic('missing') }.item(0) or { panic('missing') }.transcript() == 'hello'
	assert result.is_final()
}

fn test_recognition_defaults_handlers_phrase_and_event() {
	mut recognition := SpeechRecognition.construct_impl()
	assert recognition.max_alternatives() == 1
	assert recognition.grammars().length() == 0
	recognition.set_lang('en-US')
	recognition.set_continuous(true)
	assert recognition.lang() == 'en-US'
	assert recognition.continuous()
	callback := &dom.CallbackType{}
	recognition.set_onresult(callback)
	assert recognition.onresult() or { panic('missing handler') } == callback
	results := SpeechRecognitionResultList.create()
	event := SpeechRecognitionEvent.construct_impl('result', SpeechRecognitionEventInit{
		result_index: 2
		results:      results
	})
	assert event.interface_ == .speech_recognition_event
	assert event.type_name() == 'result'
	assert event.result_index() == 2
	assert event.results() or { panic('missing results') } == results
	assert SpeechRecognitionPhrase.construct_impl('Ladybird', 2).boost() == 2
	assert SpeechRecognitionPhrase.new_with_default_boost('Ladybird').boost() == 1
}

fn test_all_recognition_and_utterance_event_handler_attributes() {
	recognition := SpeechRecognition.new()
	callback := &dom.CallbackType{}
	recognition.set_onaudiostart(callback)
	recognition.set_onsoundstart(callback)
	recognition.set_onspeechstart(callback)
	recognition.set_onspeechend(callback)
	recognition.set_onsoundend(callback)
	recognition.set_onaudioend(callback)
	recognition.set_onresult(callback)
	recognition.set_onnomatch(callback)
	recognition.set_onerror(callback)
	recognition.set_onstart(callback)
	recognition.set_onend(callback)
	assert recognition.onaudiostart() or { panic('missing') } == callback
	assert recognition.onsoundstart() or { panic('missing') } == callback
	assert recognition.onspeechstart() or { panic('missing') } == callback
	assert recognition.onspeechend() or { panic('missing') } == callback
	assert recognition.onsoundend() or { panic('missing') } == callback
	assert recognition.onaudioend() or { panic('missing') } == callback
	assert recognition.onresult() or { panic('missing') } == callback
	assert recognition.onnomatch() or { panic('missing') } == callback
	assert recognition.onerror() or { panic('missing') } == callback
	assert recognition.onstart() or { panic('missing') } == callback
	assert recognition.onend() or { panic('missing') } == callback
	utterance := SpeechSynthesisUtterance.new('events')
	utterance.set_onstart(callback)
	utterance.set_onend(callback)
	utterance.set_onerror(callback)
	utterance.set_onpause(callback)
	utterance.set_onresume(callback)
	utterance.set_onmark(callback)
	utterance.set_onboundary(callback)
	assert utterance.onstart() or { panic('missing') } == callback
	assert utterance.onend() or { panic('missing') } == callback
	assert utterance.onerror() or { panic('missing') } == callback
	assert utterance.onpause() or { panic('missing') } == callback
	assert utterance.onresume() or { panic('missing') } == callback
	assert utterance.onmark() or { panic('missing') } == callback
	assert utterance.onboundary() or { panic('missing') } == callback
}

fn test_synthesis_current_upstream_defaults_and_utterance_properties() {
	mut synthesis := SpeechSynthesis.create()
	assert !synthesis.pending() && !synthesis.speaking() && !synthesis.paused()
	assert synthesis.get_voices().len == 0
	voice := SpeechSynthesisVoice.from_platform('urn:test', 'Test', 'en', true, true)
	synthesis.replace_voices_from_platform([voice])
	assert synthesis.get_voices()[0].is_default()
	assert synthesis.get_voices()[0].voice_uri() == 'urn:test'
	mut utterance := SpeechSynthesisUtterance.construct_impl('hello')
	utterance.set_lang('en')
	utterance.set_voice(voice)
	utterance.set_volume(0.5)
	utterance.set_rate(1.5)
	utterance.set_pitch(0.75)
	assert utterance.text() == 'hello'
	assert utterance.lang() == 'en'
	assert utterance.voice() or { panic('missing voice') } == voice
	assert utterance.volume() == 0.5
	assert utterance.rate() == 1.5
	assert utterance.pitch() == 0.75
}
