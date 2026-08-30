module xhr

import fileapi
import time

fn test_form_data_append_get_all_delete_set_and_blob_files() {
	mut data := FormData.create()
	data.append('a', 'one')
	data.append('a', 'two')
	assert data.has('a')
	first := data.get('a') or { panic('missing') }
	assert first is string
	assert first == 'one'
	assert data.get_all('a').len == 2
	data.set('a', 'replacement')
	assert data.get_all('a').len == 1
	assert data.get('a') or { panic('missing') } == FormDataEntryValue('replacement')
	blob := fileapi.Blob.create([u8(1), 2], 'application/octet-stream')
	before := time.now().unix_milli()
	data.append_blob('file', blob, 'x.bin')
	file_value := data.get('file') or { panic('missing') }
	assert file_value is FormDataFile
	file := (file_value as FormDataFile).file
	assert file.name() == 'x.bin'
	assert file.raw_bytes() == [u8(1), 2]
	assert file.last_modified() >= before
	original := fileapi.File.create([u8(9)], 'original.bin', 'application/octet-stream', 42)
	data.set_file('file', original, 'renamed.bin')
	replacement := (data.get('file') or { panic('missing') } as FormDataFile).file
	assert replacement.name() == 'renamed.bin'
	assert replacement.last_modified() == 42
	data.delete('a')
	assert !data.has('a')
}

fn test_form_data_iterator_kinds_and_live_entry_list() {
	mut data := FormData.from_query_entries([['x', '1']!, ['y', '2']!])
	mut entries := data.iterator(.key_value)
	first := entries.next()
	assert first.has_key && first.has_value
	assert first.key == 'x'
	assert (first.value as string) == '1'
	data.append('z', '3')
	assert entries.next().key == 'y'
	assert entries.next().key == 'z'
	assert entries.next().done
}

fn test_progress_event_inherits_event_init_members() {
	event := ProgressEvent.construct('progress', ProgressEventInit{
		bubbles:           true
		cancelable:        true
		composed:          true
		length_computable: true
		loaded:            2
		total:             4
	})
	assert event.bubbles && event.cancelable && event.composed
	assert event.length_computable() && event.loaded() == 2 && event.total() == 4
}

fn test_exact_form_data_progress_and_iterator_entry_points() {
	mut data := FormData.construct_impl([FormDataEntry{ name: 'a', value: 'one' }])
	data.append_impl('a', FormDataAppendValue('two'), none)
	assert data.entry_list().len == 2
	data.set_impl('a', FormDataAppendValue('three'), none)
	assert data.entry_list().len == 1
	data.delete_('a')
	assert data.entry_list().len == 0
	mut iterator := FormDataIterator.create(data, .key)
	assert iterator.next().done

	event := ProgressEvent.construct_impl('progress', ProgressEventInit{
		length_computable: true
		loaded:            3
		total:             5
	})
	assert event.length_computable()
	assert event.loaded() == 3
	assert event.total() == 5

	mut target := XMLHttpRequestEventTarget{}
	target.set_onprogress(true)
	assert target.onprogress()
	target.dispatch('progress', 3, 5)
	assert target.events[0].loaded() == 3
}
