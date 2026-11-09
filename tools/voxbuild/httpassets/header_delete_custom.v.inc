
pub fn (mut h Header) delete_custom(key string) {
    mut retained := []HeaderKV{cap: h.data.len}
    for kv in h.data {
        if !header_key_eq(kv.key, key) { retained << kv }
    }
    h.data = retained
    h.cur_pos = retained.len
}