module browsertabs

import json2

// The process session and the small FastC regression suite use this same typed
// codec. Keep its data declarations independent of platform and UI services.
fn encode_session_state(state State) string {
	return json2.encode(state)
}

fn decode_session_state(source string) !State {
	return json2.decode[State](source)
}
