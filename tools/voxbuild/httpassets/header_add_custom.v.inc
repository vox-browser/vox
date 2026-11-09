
pub fn (mut h Header) add_custom(key string, value string) ! {
    is_valid(key)!
    h.data = h.data.clone()
    h.data << HeaderKV{key, value}
    h.cur_pos = h.data.len
}