module css

import platform

fn test_normal_and_none_content_installs_keep_presence_without_per_style_payloads() {
	mut styles := []&ComputedProperties{cap:256}
	for _ in 0 .. 256 { styles << ComputedProperties.new() }
	before := platform.thread_arena_usage().used
	for index, mut style in styles {
		style.set_content(ContentData{type_:if index % 2 == 0 { .normal } else { .none_ }})
	}
	$if prealloc { assert platform.thread_arena_usage().used - before < 4096 }
	for index, style in styles {
		content := style.computed_content()?
		assert content.type_ == if index % 2 == 0 { ContentDataType.normal } else { ContentDataType.none_ }
		assert content.text == '' && content.items.len == 0
	}
	mut returned := styles[0].computed_content()?
	returned.text = 'local copy'
	returned.items << ContentItem{type_:.text, value:'local item'}
	assert styles[0].computed_content()?.text == ''
	assert styles[2].computed_content()?.items.len == 0
	styles[0].set_content(none)
	assert styles[0].computed_content() == none
	assert styles[2].computed_content()?.type_ == .normal
}

fn test_keyword_content_with_payload_and_old_snapshots_remain_independent() {
	mut style := ComputedProperties.new()
	style.set_content(ContentData{type_:.normal, text:'retained payload', alt_text:'alternative'})
	old := style.computed_content()?
	style.set_content(ContentData{type_:.normal})
	assert old.text == 'retained payload' && old.alt_text == 'alternative'
	assert style.computed_content()?.text == ''
	style.set_content(ContentData{type_:.list, items:[ContentItem{type_:.text, value:'list item'}]})
	list := style.computed_content()?
	style.set_content(ContentData{type_:.none_})
	assert list.type_ == .list && list.items[0].value == 'list item'
	assert style.computed_content()?.type_ == .none_
}
