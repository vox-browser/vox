// Copyright (c) 2024, Andrew Kaster <andrew@ladybird.org>
//
// SPDX-License-Identifier: BSD-2-Clause

// Translation of Libraries/LibWeb/HTML/UserNavigationInvolvement.cpp.
module html

import dom

pub enum UserNavigationInvolvement {
	browser_ui
	activation
	none_
}

// https://html.spec.whatwg.org/multipage/browsing-the-web.html#event-uni
pub fn user_navigation_involvement(event &dom.Event) UserNavigationInvolvement {
	assert event.type_name() == 'click'
	return if event.is_trusted() { .activation } else { .none_ }
}
