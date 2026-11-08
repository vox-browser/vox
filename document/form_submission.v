module main

import browserjs
import dom
import html

fn browser_form_document_resource(submission html.FormSubmission) html.DocumentResource {
	if submission.method != .post { return html.EmptyDocumentResource{} }
	return html.POSTResource{
		request_body: submission.body.clone()
		request_content_type: match submission.encoding {
			.url_encoded { .application_x_www_form_urlencoded }
			.multipart { .multipart_form_data }
			.plain_text { .text_plain }
		}
		request_content_type_directives: if submission.encoding == .multipart {
			[html.POSTResourceDirective{type_: 'boundary', value: submission.content_type.all_after('boundary=')}]
		} else { []html.POSTResourceDirective{} }
	}
}

// Use the same navigable and child-document owner as iframe src navigations.
// A form POST retains its body and MIME boundary through the Fetch pipeline.
fn submit_browser_form(element &dom.Element, target string, submission html.FormSubmission, engine browserjs.Engine) ! {
	document := element.document()
	host := document.navigable() or { return }
	if host.html_model_handle_ == unsafe { nil } { return }
	mut model := unsafe { &html.NavigableModel(host.html_model_handle_) }
	mut manager := browser_child_document_host(document, engine)
	mut messages := []string{}
	manager.discover(document, mut messages)
	chosen := model.choose_a_navigable(target, false)!
	mut destination := chosen.navigable or { return }
	for mut child in manager.children {
		if child.closed || voidptr(child.navigable) != voidptr(destination) { continue }
		// This navigation supersedes the frame's current attributes. A later
		// attribute mutation still starts its own navigation in the host poll.
		child.observed = true
		child.src = child.element.get_attribute_value('src').clone()
		child.srcdoc = if value := child.element.get_attribute('srcdoc') { ?string(value.clone()) } else { none }
		child.hold_load_delay()
	}
	destination.navigate(html.NavigableNavigateParams{
		url: submission.url
		source_document: document
		document_resource: browser_form_document_resource(submission)
		source_element: element
		referrer_policy: html.referrer_policy_from_string(submission.referrer_policy) or { html.ReferrerPolicy.empty_string }
		user_involvement: match submission.user_involvement {
			.browser_ui { .browser_ui }
			.activation { .activation }
			.none_ { .none }
		}
	})!
}
