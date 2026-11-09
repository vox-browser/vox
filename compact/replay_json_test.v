module main

import browserjs
import html
import x.json2

fn test_private_replay_json_preserves_lone_units_pairs_and_escaped_literals() {
	encoded := r'{"low":"\udc01","high":"\uD800","pair":"\ud83d\ude00","mixed":"\ud800\ud800\udc00","literal":"\\udc01","quote":"\"\\\udc01","\ud800":"key"}'
	mut messages := []string{}
	state := javascript_replay_state(encoded, mut messages)?
	assert messages.len == 0
	assert ((state['low'] or { panic('missing low fixture') }) as string).bytes() == [u8(0xed), 0xb0, 0x81]
	assert ((state['high'] or { panic('missing high fixture') }) as string).bytes() == [u8(0xed), 0xa0, 0x80]
	assert (state['pair'] or { panic('missing pair fixture') }) == json2.Any('😀')
	assert ((state['mixed'] or { panic('missing mixed fixture') }) as string).bytes() == [u8(0xed), 0xa0, 0x80, 0xf0, 0x90, 0x80, 0x80]
	assert (state['literal'] or { panic('missing literal fixture') }) == json2.Any(r'\udc01')
	assert ((state['quote'] or { panic('missing quote fixture') }) as string).bytes() == [u8(34), 92, 0xed, 0xb0, 0x81]
	assert (state[[u8(0xed), 0xa0, 0x80].bytestr()] or { panic('missing raw key') }) == json2.Any('key')
	round_trip := compact_replay_json_result(json2.encode(state))
	assert round_trip.contains(r'"low":"\udc01"')
	assert round_trip.contains(r'"high":"\ud800"')
	assert javascript_replay_state(round_trip, mut messages)? == state
	for invalid in [r'{"text":"\udc0Z"}', r'{"text":"\ud800",}', r'{"text":"bad\x01"}',
		r'{"text":"\udc01"'] {
		if _ := javascript_replay_state(invalid, mut messages) {
			assert false, invalid
		}
	}
}

fn test_private_control_query_keeps_utf16_units_in_typed_fields_and_nested_state() {
	query := compact_decode_query[CompactInputValueQuery](r'{"write":true,"property":"value","value":"\ud800\udc01\udc01","state":{"name":"\ud800"}}')!
	assert query.write && query.property == 'value'
	assert query.value.bytes() == [u8(0xf0), 0x90, 0x80, 0x81, 0xed, 0xb0, 0x81]
	assert ((query.state['name'] or { panic('missing name fixture') }) as string).bytes() == [u8(0xed), 0xa0, 0x80]
}

fn test_form_data_replay_preserves_dom_surrogates_until_scalar_entry_conversion() {
	mut document := html.parse_document('<!doctype html><form id="form"></form>')
	mut runtime := browserjs.Runtime.create()
	defer {
		runtime.close()
		document.finalize()
	}
	mut messages := []string{}
	run_document_javascript(document, 'about:blank', [], runtime, mut messages)
	assert runtime.evaluate_host(r'(()=>{
 const input=document.createElement("input");input.name="field-\udc01";input.value="value-\ud800";
 if(input.name!=="field-\udc01"||input.value!=="value-\ud800")return false;
 form.appendChild(input);const data=new FormData(form);
 return input.name==="field-\udc01"&&input.value==="value-\ud800"&&data.get("field-�")==="value-�";
})()')! == 'true'
	assert messages.len == 0
}
