// Copyright (c) 2026, Ladybird contributors
// SPDX-License-Identifier: BSD-2-Clause

// Translation of SecurityPolicyViolationEvent.{h,cpp,idl}.
module contentsecuritypolicy

import dom

pub struct SecurityPolicyViolationEventInit {
	dom.EventInit
pub:
	document_uri        string
	referrer            string
	blocked_uri         string
	violated_directive  string
	effective_directive string
	original_policy     string
	source_file         string
	sample              string
	disposition         Disposition
	status_code         u16
	line_number         u32
	column_number       u32
}

@[heap]
pub struct SecurityPolicyViolationEvent {
	dom.Event
pub mut:
	policy_element       ?&dom.Element
pub:
	document_uri_        string
	referrer_            string
	blocked_uri_         string
	violated_directive_  string
	effective_directive_ string
	original_policy_     string
	source_file_         string
	sample_              string
	disposition_         Disposition
	status_code_         u16
	line_number_         u32
	column_number_       u32
}

pub fn SecurityPolicyViolationEvent.create(event_name string, init SecurityPolicyViolationEventInit) &SecurityPolicyViolationEvent {
	base := dom.Event.new_with_init(event_name, init.EventInit)
	return &SecurityPolicyViolationEvent{
		Event:                *base
		document_uri_:        init.document_uri
		referrer_:            init.referrer
		blocked_uri_:         init.blocked_uri
		violated_directive_:  init.violated_directive
		effective_directive_: init.effective_directive
		original_policy_:     init.original_policy
		source_file_:         init.source_file
		sample_:              init.sample
		disposition_:         init.disposition
		status_code_:         init.status_code
		line_number_:         init.line_number
		column_number_:       init.column_number
	}
}

pub fn SecurityPolicyViolationEvent.construct_impl(event_name string, init SecurityPolicyViolationEventInit) !&SecurityPolicyViolationEvent {
	return SecurityPolicyViolationEvent.create(event_name, init)
}

pub fn (event &SecurityPolicyViolationEvent) document_uri() string {
	return event.document_uri_
}

pub fn (event &SecurityPolicyViolationEvent) referrer() string {
	return event.referrer_
}

pub fn (event &SecurityPolicyViolationEvent) blocked_uri() string {
	return event.blocked_uri_
}

pub fn (event &SecurityPolicyViolationEvent) violated_directive() string {
	return event.violated_directive_
}

pub fn (event &SecurityPolicyViolationEvent) effective_directive() string {
	return event.effective_directive_
}

pub fn (event &SecurityPolicyViolationEvent) original_policy() string {
	return event.original_policy_
}

pub fn (event &SecurityPolicyViolationEvent) source_file() string {
	return event.source_file_
}

pub fn (event &SecurityPolicyViolationEvent) sample() string {
	return event.sample_
}

pub fn (event &SecurityPolicyViolationEvent) disposition() Disposition {
	return event.disposition_
}

pub fn (event &SecurityPolicyViolationEvent) status_code() u16 {
	return event.status_code_
}

pub fn (event &SecurityPolicyViolationEvent) line_number() u32 {
	return event.line_number_
}

pub fn (event &SecurityPolicyViolationEvent) column_number() u32 {
	return event.column_number_
}
