
pub fn (mut h Header) add(key CommonHeader, value string) {
    // Header was a value-copy fixed array. Detach before every mutation so
    // request/response Header copies retain that ownership behavior.
    h.data = h.data.clone()
    h.data << HeaderKV{key.str(), value}
    h.cur_pos = h.data.len
}