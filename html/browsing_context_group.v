// Copyright (c) 2022, Andreas Kling <andreas@ladybird.org>
//
// SPDX-License-Identifier: BSD-2-Clause

// Translation of BrowsingContextGroup.{h,cpp}.
@[has_globals]
module html

import dom
import platform

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
	// Older typed constructors can be appended before their native Window/BC
	// exists. Actual initialized members live only in browsing_context_set_.
	legacy_pending_model_members_ []&BrowsingContextModel
	registered_                 bool
}

pub fn BrowsingContextGroup.create(page &dom.Page) &BrowsingContextGroup {
	// Groups belong to the user agent and outlive the documents that create
	// them (for example through window.open).
	persistent := platform.enter_persistent()
	defer { platform.leave_persistent(persistent) }
	group := &BrowsingContextGroup{
		page_: page
		registered_: true
	}
	html_user_agent_browsing_context_groups << group
	return group
}

pub fn BrowsingContextGroup.create_a_new_browsing_context_group_and_document(page &dom.Page) !BrowsingContextGroupAndDocument {
	mut group := BrowsingContextGroup.create(page)
	created := BrowsingContextModel.create_a_new_browsing_context_and_document(page, none, none)!
	group.append(created.document.get_browsing_context() or {
		panic('Source initial Document requires its actual BrowsingContext')
	})
	return BrowsingContextGroupAndDocument{
		browsing_context_group: group
		document: created.document
	}
}

pub fn (group &BrowsingContextGroup) page() &dom.Page {
	return group.page_
}

pub fn (group &BrowsingContextGroup) browsing_context_set() []&dom.BrowsingContext {
	return group.browsing_context_set_.clone()
}

pub fn (group &BrowsingContextGroup) model_browsing_context_set() []&BrowsingContextModel {
	mut result := []&BrowsingContextModel{}
	for native in group.browsing_context_set_ {
		if native.html_model_handle_ != unsafe { nil } {
			result << browsing_context_model_for_native(native)
		}
	}
	result << group.legacy_pending_model_members_
	return result
}

pub fn (mut group BrowsingContextGroup) append(browsing_context &dom.BrowsingContext) {
	mut present := false
	for existing in group.browsing_context_set_ {
		if voidptr(existing) == voidptr(browsing_context) {
			present = true
			break
		}
	}
	if !present {
		persistent := platform.enter_persistent()
		group.browsing_context_set_ << browsing_context
		platform.leave_persistent(persistent)
	}
	mut mutable_context := unsafe { &dom.BrowsingContext(browsing_context) }
	mutable_context.group_handle = voidptr(&group)
	group.synchronize_typed_member(browsing_context)
}

fn (mut group BrowsingContextGroup) synchronize_typed_member(native &dom.BrowsingContext) {
	if native.html_model_handle_ == unsafe { nil } {
		return
	}
	mut context := browsing_context_model_for_native(native)
	context.group_ = &group
	for index, candidate in group.legacy_pending_model_members_ {
		if voidptr(candidate) == voidptr(context) {
			group.legacy_pending_model_members_.delete(index)
			break
		}
	}
}

pub fn (mut group BrowsingContextGroup) append_model(browsing_context &BrowsingContextModel) {
	if native := browsing_context.native_browsing_context_ {
		group.append(native)
		return
	}
	if document := browsing_context.active_document() {
		if native := document.get_browsing_context() {
			if native.html_model_handle_ == voidptr(browsing_context) {
				group.append(native)
				return
			}
		}
	}
	// Explicit compatibility for pre-native context assembly. Registration of
	// its actual Window/native identity promotes this member into the Source set.
	for existing in group.legacy_pending_model_members_ {
		if voidptr(existing) == voidptr(browsing_context) {
			return
		}
	}
	persistent := platform.enter_persistent()
	group.legacy_pending_model_members_ << browsing_context
	platform.leave_persistent(persistent)
	mut mutable_context := unsafe { &BrowsingContextModel(browsing_context) }
	mutable_context.group_ = &group
}

pub fn (mut group BrowsingContextGroup) remove_model(browsing_context &BrowsingContextModel) {
	mut index := 0
	for index < group.browsing_context_set_.len {
		mut native := group.browsing_context_set_[index]
		if native.html_model_handle_ == voidptr(browsing_context) {
			if native.group_handle == voidptr(&group) {
				native.group_handle = unsafe { nil }
			}
			group.browsing_context_set_.delete(index)
		} else {
			index++
		}
	}
	group.legacy_pending_model_members_ = group.legacy_pending_model_members_.filter(voidptr(it) != voidptr(browsing_context))
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
	for context in group.model_browsing_context_set() {
		mut mutable_context := unsafe { &BrowsingContextModel(context) }
		if current_group := mutable_context.group_ {
			if voidptr(current_group) == voidptr(&group) {
				mutable_context.group_ = none
			}
		}
	}
	group.browsing_context_set_.clear()
	group.legacy_pending_model_members_.clear()
	for index, candidate in html_user_agent_browsing_context_groups {
		if voidptr(candidate) == voidptr(&group) {
			html_user_agent_browsing_context_groups.delete(index)
			break
		}
	}
	group.registered_ = false
}

pub fn user_agent_browsing_context_group_count() int {
	return html_user_agent_browsing_context_groups.len
}

// https://html.spec.whatwg.org/multipage/browsers.html#browsing-context-group-set
pub fn user_agent_browsing_context_group_set() []&BrowsingContextGroup {
	return html_user_agent_browsing_context_groups.clone()
}
