// SPDX-License-Identifier: BSD-2-Clause
module domurl

import url as liburl

fn test_domurl_create_owns_the_supplied_url_value() {
	mut supplied := liburl.parse('https://constructor-copy.test/original/item?query#fragment')?
	actual := DOMURL.create(supplied)
	supplied.paths[0] = 'changed'
	assert supplied.serialize(false) == 'https://constructor-copy.test/changed/item?query#fragment'
	assert actual.href() == 'https://constructor-copy.test/original/item?query#fragment'
	assert actual.pathname() == '/original/item'
}

fn test_domurl_initialize_owns_the_supplied_value_and_keeps_its_query_object() {
	mut supplied := liburl.parse('https://initialize-copy.test/original/item?first=one')?
	mut actual := DOMURL.initialize_a_url(supplied)
	query := actual.search_params()
	supplied.paths[1] = 'changed'
	assert actual.href() == 'https://initialize-copy.test/original/item?first=one'
	assert actual.search_params() == query
	actual.set_pathname('/owned/path')
	assert supplied.serialize(false) == 'https://initialize-copy.test/original/changed?first=one'
	assert actual.href() == 'https://initialize-copy.test/owned/path?first=one'
	assert query.get('first')? == 'one'
}
