// Copyright (c) 2022, Andreas Kling <andreas@ladybird.org>
//
// SPDX-License-Identifier: BSD-2-Clause

// Translation of BrowsingContextGroup.{h,cpp}.
@[has_globals]
module html

import dom

__global (
	html_user_agent_browsing_context_groups = []&BrowsingContextGroup{}
)

pub struct BrowsingContextGroupAndDocument {
pub:
	browsing_context_group &BrowsingContextGroup
	document               &dom.Document
}

@[heap]
pub struct BrowsingContextGroup {
mut:
	page_                       &dom.Page
	browsing_context_set_       []&dom.BrowsingContext
	model_browsing_context_set_ []&BrowsingContextModel
	registered_                 bool
}

pub fn BrowsingContextGroup.create(page &dom.Page) &BrowsingContextGroup {
	group := &BrowsingContextGroup{
		page_: page
		registered_: true
	}
	html_user_agent_browsing_context_groups << group
	return group
}

pub fn BrowsingContextGroup.create_a_new_browsing_context_group_and_document(page &dom.Page) !BrowsingContextGroupAndDocument {
	mut group := BrowsingContextGroup.create(page)
	mut document := &dom.Document{}
	mut browsing_context := &dom.BrowsingContext{
		active_document_: document
	}
	document.set_browsing_context(browsing_context)
	group.append(browsing_context)
	return BrowsingContextGroupAndDocument{
		browsing_context_group: group
		document: document
	}
}

pub fn (group &BrowsingContextGroup) page() &dom.Page {
	return group.page_
}

pub fn (group &BrowsingContextGroup) browsing_context_set() []&dom.BrowsingContext {
	return group.browsing_context_set_.clone()
}

pub fn (group &BrowsingContextGroup) model_browsing_context_set() []&BrowsingContextModel {
	return group.model_browsing_context_set_.clone()
}

pub fn (mut group BrowsingContextGroup) append(browsing_context &dom.BrowsingContext) {
	for existing in group.browsing_context_set_ {
		if voidptr(existing) == voidptr(browsing_context) {
			return
		}
	}
	group.browsing_context_set_ << browsing_context
	mut mutable_context := unsafe { &dom.BrowsingContext(browsing_context) }
	mutable_context.group_handle = voidptr(&group)
}

pub fn (mut group BrowsingContextGroup) append_model(browsing_context &BrowsingContextModel) {
	for existing in group.model_browsing_context_set_ {
		if voidptr(existing) == voidptr(browsing_context) {
			return
		}
	}
	group.model_browsing_context_set_ << browsing_context
	mut mutable_context := unsafe { &BrowsingContextModel(browsing_context) }
	mutable_context.group_ = &group
}

pub fn (mut group BrowsingContextGroup) remove_model(browsing_context &BrowsingContextModel) {
	group.model_browsing_context_set_ = group.model_browsing_context_set_.filter(voidptr(it) != voidptr(browsing_context))
}

pub fn (mut group BrowsingContextGroup) finalize() {
	if !group.registered_ {
		return
	}
	for context in group.browsing_context_set_ {
		mut mutable_context := unsafe { &dom.BrowsingContext(context) }
		if mutable_context.group_handle == voidptr(&group) {
			mutable_context.group_handle = unsafe { nil }
		}
	}
	for context in group.model_browsing_context_set_ {
		mut mutable_context := unsafe { &BrowsingContextModel(context) }
		if current_group := mutable_context.group_ {
			if voidptr(current_group) == voidptr(&group) {
				mutable_context.group_ = none
			}
		}
	}
	group.model_browsing_context_set_.clear()
	html_user_agent_browsing_context_groups = html_user_agent_browsing_context_groups.filter(voidptr(it) != voidptr(&group))
	group.registered_ = false
}

pub fn user_agent_browsing_context_group_count() int {
	return html_user_agent_browsing_context_groups.len
}

// https://html.spec.whatwg.org/multipage/browsers.html#browsing-context-group-set
pub fn user_agent_browsing_context_group_set() []&BrowsingContextGroup {
	return html_user_agent_browsing_context_groups.clone()
}
