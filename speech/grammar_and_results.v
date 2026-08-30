// Copyright (c) 2026, Ladybird contributors
//
// SPDX-License-Identifier: BSD-2-Clause

// Translation of SpeechGrammar, SpeechGrammarList,
// SpeechRecognitionAlternative, SpeechRecognitionResult, and
// SpeechRecognitionResultList .h/.cpp/.idl units.
module speech

@[heap]
pub struct SpeechGrammar {
mut:
	src_    string
	weight_ f32 = 1
}

pub fn SpeechGrammar.new() &SpeechGrammar {
	return SpeechGrammar.construct_impl()
}

pub fn SpeechGrammar.construct_impl() &SpeechGrammar {
	return &SpeechGrammar{}
}

pub fn (grammar &SpeechGrammar) src() string {
	return grammar.src_
}

pub fn (mut grammar SpeechGrammar) set_src(src string) {
	grammar.src_ = src
}

pub fn (grammar &SpeechGrammar) weight() f32 {
	return grammar.weight_
}

pub fn (mut grammar SpeechGrammar) set_weight(weight f32) {
	grammar.weight_ = weight
}

@[heap]
pub struct SpeechGrammarList {
mut:
	grammars_ []&SpeechGrammar
}

pub fn SpeechGrammarList.new() &SpeechGrammarList {
	return SpeechGrammarList.construct_impl()
}

pub fn SpeechGrammarList.construct_impl() &SpeechGrammarList {
	return &SpeechGrammarList{}
}

pub fn (list &SpeechGrammarList) length() u32 {
	return u32(list.grammars_.len)
}

pub fn (list &SpeechGrammarList) item(index u32) ?&SpeechGrammar {
	if index >= u32(list.grammars_.len) { return none }
	return list.grammars_[index]
}

// Platform population boundary; the IDL addFrom* methods remain upstream FIXME.
pub fn (mut list SpeechGrammarList) replace_from_platform(grammars []&SpeechGrammar) {
	list.grammars_ = grammars.clone()
}

@[heap]
pub struct SpeechRecognitionAlternative {
mut:
	transcript_ string
	confidence_ f32
}

pub fn SpeechRecognitionAlternative.create() &SpeechRecognitionAlternative {
	return &SpeechRecognitionAlternative{}
}

pub fn SpeechRecognitionAlternative.from_platform(transcript string, confidence f32) &SpeechRecognitionAlternative {
	return &SpeechRecognitionAlternative{
		transcript_: transcript
		confidence_: confidence
	}
}

pub fn (alternative &SpeechRecognitionAlternative) transcript() string {
	return alternative.transcript_
}

pub fn (alternative &SpeechRecognitionAlternative) confidence() f32 {
	return alternative.confidence_
}

@[heap]
pub struct SpeechRecognitionResult {
mut:
	alternatives_ []&SpeechRecognitionAlternative
	is_final_     bool
}

pub fn SpeechRecognitionResult.create() &SpeechRecognitionResult {
	return &SpeechRecognitionResult{}
}

pub fn (result &SpeechRecognitionResult) length() u32 {
	return u32(result.alternatives_.len)
}

pub fn (result &SpeechRecognitionResult) item(index u32) ?&SpeechRecognitionAlternative {
	if index >= u32(result.alternatives_.len) { return none }
	return result.alternatives_[index]
}

pub fn (result &SpeechRecognitionResult) is_final() bool {
	return result.is_final_
}

pub fn (mut result SpeechRecognitionResult) populate_from_platform(alternatives []&SpeechRecognitionAlternative, is_final bool) {
	result.alternatives_ = alternatives.clone()
	result.is_final_ = is_final
}

@[heap]
pub struct SpeechRecognitionResultList {
mut:
	results_ []&SpeechRecognitionResult
}

pub fn SpeechRecognitionResultList.create() &SpeechRecognitionResultList {
	return &SpeechRecognitionResultList{}
}

pub fn (list &SpeechRecognitionResultList) length() u32 {
	return u32(list.results_.len)
}

pub fn (list &SpeechRecognitionResultList) item(index u32) ?&SpeechRecognitionResult {
	if index >= u32(list.results_.len) { return none }
	return list.results_[index]
}

pub fn (mut list SpeechRecognitionResultList) replace_from_platform(results []&SpeechRecognitionResult) {
	list.results_ = results.clone()
}
