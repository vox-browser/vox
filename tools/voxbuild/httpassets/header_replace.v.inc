

// Rebuild rather than mutating a shared array. Empty values are real fields;
// removal deletes an entry instead of using an empty value as a tombstone.
fn (mut h Header) vox_replace_header_value(key string, value string) {
    mut replaced := false
    mut result := []HeaderKV{cap: h.data.len + 1}
    for kv in h.data {
        if header_key_eq(kv.key, key) {
            if !replaced { result << HeaderKV{key, value}; replaced = true }
        } else {
            result << kv
        }
    }
    if !replaced { result << HeaderKV{key, value} }
    h.data = result
    h.cur_pos = result.len
}
