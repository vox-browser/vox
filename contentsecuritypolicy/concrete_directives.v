// Copyright (c) 2026, Ladybird contributors
// SPDX-License-Identifier: BSD-2-Clause

// The V port stores heterogeneous CSP directives in one value type. These
// distinct aliases preserve every concrete upstream directive entry point and
// delegate to that shared, exhaustive implementation.
module contentsecuritypolicy

pub type ChildSourceDirective = Directive
pub type ConnectSourceDirective = Directive
pub type DefaultSourceDirective = Directive
pub type FontSourceDirective = Directive
pub type FormActionDirective = Directive
pub type FrameAncestorsDirective = Directive
pub type FrameSourceDirective = Directive
pub type ImageSourceDirective = Directive
pub type ManifestSourceDirective = Directive
pub type MediaSourceDirective = Directive
pub type ObjectSourceDirective = Directive
pub type SandboxDirective = Directive
pub type ScriptSourceAttributeDirective = Directive
pub type ScriptSourceDirective = Directive
pub type ScriptSourceElementDirective = Directive
pub type StyleSourceAttributeDirective = Directive
pub type StyleSourceDirective = Directive
pub type StyleSourceElementDirective = Directive
pub type WebRTCDirective = Directive
pub type WorkerSourceDirective = Directive

pub fn (directive ChildSourceDirective) pre_request_check(request &Request, policy &Policy) Result {
	return Directive(directive).pre_request_check(request, policy)
}

pub fn (directive ChildSourceDirective) post_request_check(request &Request, response &Response, policy &Policy) Result {
	return Directive(directive).post_request_check(request, response, policy)
}

pub fn (directive ConnectSourceDirective) pre_request_check(request &Request, policy &Policy) Result {
	return Directive(directive).pre_request_check(request, policy)
}

pub fn (directive ConnectSourceDirective) post_request_check(request &Request, response &Response, policy &Policy) Result {
	return Directive(directive).post_request_check(request, response, policy)
}

pub fn (directive DefaultSourceDirective) pre_request_check(request &Request, policy &Policy) Result {
	return Directive(directive).pre_request_check(request, policy)
}

pub fn (directive DefaultSourceDirective) post_request_check(request &Request, response &Response, policy &Policy) Result {
	return Directive(directive).post_request_check(request, response, policy)
}

pub fn (directive DefaultSourceDirective) inline_check(element ?ElementContext, type_ InlineType, policy &Policy, source string) Result {
	return Directive(directive).inline_check(element, type_, policy, source)
}

pub fn (directive FontSourceDirective) pre_request_check(request &Request, policy &Policy) Result {
	return Directive(directive).pre_request_check(request, policy)
}

pub fn (directive FontSourceDirective) post_request_check(request &Request, response &Response, policy &Policy) Result {
	return Directive(directive).post_request_check(request, response, policy)
}

pub fn (directive FormActionDirective) pre_navigation_check(request &Request, navigation_type NavigationType, policy &Policy) Result {
	return Directive(directive).pre_navigation_check(request, navigation_type, policy)
}

pub fn (directive FrameAncestorsDirective) navigation_response_check(response &Response, target NavigableContext, check_type CheckType, policy &Policy) Result {
	return Directive(directive).navigation_response_check(response, target, check_type, policy)
}

pub fn (directive FrameSourceDirective) pre_request_check(request &Request, policy &Policy) Result {
	return Directive(directive).pre_request_check(request, policy)
}

pub fn (directive FrameSourceDirective) post_request_check(request &Request, response &Response, policy &Policy) Result {
	return Directive(directive).post_request_check(request, response, policy)
}

pub fn (directive ImageSourceDirective) pre_request_check(request &Request, policy &Policy) Result {
	return Directive(directive).pre_request_check(request, policy)
}

pub fn (directive ImageSourceDirective) post_request_check(request &Request, response &Response, policy &Policy) Result {
	return Directive(directive).post_request_check(request, response, policy)
}

pub fn (directive ManifestSourceDirective) pre_request_check(request &Request, policy &Policy) Result {
	return Directive(directive).pre_request_check(request, policy)
}

pub fn (directive ManifestSourceDirective) post_request_check(request &Request, response &Response, policy &Policy) Result {
	return Directive(directive).post_request_check(request, response, policy)
}

pub fn (directive MediaSourceDirective) pre_request_check(request &Request, policy &Policy) Result {
	return Directive(directive).pre_request_check(request, policy)
}

pub fn (directive MediaSourceDirective) post_request_check(request &Request, response &Response, policy &Policy) Result {
	return Directive(directive).post_request_check(request, response, policy)
}

pub fn (directive ObjectSourceDirective) pre_request_check(request &Request, policy &Policy) Result {
	return Directive(directive).pre_request_check(request, policy)
}

pub fn (directive ObjectSourceDirective) post_request_check(request &Request, response &Response, policy &Policy) Result {
	return Directive(directive).post_request_check(request, response, policy)
}

pub fn (directive SandboxDirective) initialization(is_worker bool, policy &Policy) Result {
	return Directive(directive).initialization(is_worker, policy)
}

pub fn (directive ScriptSourceAttributeDirective) inline_check(element ?ElementContext, type_ InlineType, policy &Policy, source string) Result {
	return Directive(directive).inline_check(element, type_, policy, source)
}

pub fn (directive ScriptSourceDirective) pre_request_check(request &Request, policy &Policy) Result {
	return Directive(directive).pre_request_check(request, policy)
}

pub fn (directive ScriptSourceDirective) post_request_check(request &Request, response &Response, policy &Policy) Result {
	return Directive(directive).post_request_check(request, response, policy)
}

pub fn (directive ScriptSourceDirective) inline_check(element ?ElementContext, type_ InlineType, policy &Policy, source string) Result {
	return Directive(directive).inline_check(element, type_, policy, source)
}

pub fn (directive ScriptSourceElementDirective) pre_request_check(request &Request, policy &Policy) Result {
	return Directive(directive).pre_request_check(request, policy)
}

pub fn (directive ScriptSourceElementDirective) post_request_check(request &Request, response &Response, policy &Policy) Result {
	return Directive(directive).post_request_check(request, response, policy)
}

pub fn (directive ScriptSourceElementDirective) inline_check(element ?ElementContext, type_ InlineType, policy &Policy, source string) Result {
	return Directive(directive).inline_check(element, type_, policy, source)
}

pub fn (directive StyleSourceAttributeDirective) inline_check(element ?ElementContext, type_ InlineType, policy &Policy, source string) Result {
	return Directive(directive).inline_check(element, type_, policy, source)
}

pub fn (directive StyleSourceDirective) pre_request_check(request &Request, policy &Policy) Result {
	return Directive(directive).pre_request_check(request, policy)
}

pub fn (directive StyleSourceDirective) post_request_check(request &Request, response &Response, policy &Policy) Result {
	return Directive(directive).post_request_check(request, response, policy)
}

pub fn (directive StyleSourceDirective) inline_check(element ?ElementContext, type_ InlineType, policy &Policy, source string) Result {
	return Directive(directive).inline_check(element, type_, policy, source)
}

pub fn (directive StyleSourceElementDirective) pre_request_check(request &Request, policy &Policy) Result {
	return Directive(directive).pre_request_check(request, policy)
}

pub fn (directive StyleSourceElementDirective) post_request_check(request &Request, response &Response, policy &Policy) Result {
	return Directive(directive).post_request_check(request, response, policy)
}

pub fn (directive StyleSourceElementDirective) inline_check(element ?ElementContext, type_ InlineType, policy &Policy, source string) Result {
	return Directive(directive).inline_check(element, type_, policy, source)
}

pub fn (directive WebRTCDirective) webrtc_pre_connect_check() Result {
	return Directive(directive).webrtc_pre_connect_check()
}

pub fn (directive WorkerSourceDirective) pre_request_check(request &Request, policy &Policy) Result {
	return Directive(directive).pre_request_check(request, policy)
}

pub fn (directive WorkerSourceDirective) post_request_check(request &Request, response &Response, policy &Policy) Result {
	return Directive(directive).post_request_check(request, response, policy)
}
