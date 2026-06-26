use std::ffi::c_char;

static NAME: &[u8] = b"portable_pricing_native\0";

#[no_mangle]
pub extern "C" fn vflow_plugin_name() -> *const c_char {
    NAME.as_ptr() as *const c_char
}

#[no_mangle]
pub unsafe extern "C" fn vflow_plugin_execute(
    in_ptr: *const u8,
    in_len: usize,
    out_ptr: *mut *mut u8,
    out_len: *mut usize,
) -> i32 {
    if out_ptr.is_null() || out_len.is_null() {
        return 1;
    }
    let input = if in_ptr.is_null() || in_len == 0 {
        String::new()
    } else {
        String::from_utf8_lossy(std::slice::from_raw_parts(in_ptr, in_len)).to_string()
    };
    let base = number_after(&input, "\"base_price_cents\"", 2000);
    let discount_bps = number_after(&input, "\"discount_bps\"", 1250);
    let final_price = base.saturating_mul(10_000 - discount_bps) / 10_000;
    let output = format!(
        "{{\"status\":\"native_pricing_ok\",\"engine\":\"nativecode\",\"base_price_cents\":{},\"discount_bps\":{},\"final_price_cents\":{}}}",
        base, discount_bps, final_price
    );
    let boxed = output.into_bytes().into_boxed_slice();
    *out_len = boxed.len();
    *out_ptr = Box::into_raw(boxed) as *mut u8;
    0
}

#[no_mangle]
pub unsafe extern "C" fn vflow_plugin_free(ptr: *mut u8, len: usize) {
    if !ptr.is_null() {
        let slice = std::slice::from_raw_parts_mut(ptr, len);
        let _ = Box::from_raw(slice);
    }
}

fn number_after(input: &str, key: &str, default: i64) -> i64 {
    let Some(pos) = input.find(key) else {
        return default;
    };
    let rest = &input[pos + key.len()..];
    let Some(colon) = rest.find(':') else {
        return default;
    };
    let mut digits = String::new();
    for ch in rest[colon + 1..].chars() {
        if ch.is_ascii_digit() || (digits.is_empty() && ch == '-') {
            digits.push(ch);
        } else if !digits.is_empty() {
            break;
        }
    }
    digits.parse::<i64>().unwrap_or(default)
}
