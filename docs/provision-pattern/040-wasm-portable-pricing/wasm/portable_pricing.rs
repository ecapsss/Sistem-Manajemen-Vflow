use std::io::{Read, Write};

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

fn main() {
    let mut input = String::new();
    let _ = std::io::stdin().read_to_string(&mut input);
    let base = number_after(&input, "\"base_price_cents\"", 1500);
    let discount_bps = number_after(&input, "\"discount_bps\"", 1000);
    let final_price = base.saturating_mul(10_000 - discount_bps) / 10_000;
    let output = format!(
        "{{\"status\":\"wasm_pricing_ok\",\"engine\":\"wasm\",\"base_price_cents\":{},\"discount_bps\":{},\"final_price_cents\":{}}}",
        base, discount_bps, final_price
    );
    let _ = std::io::stdout().write_all(output.as_bytes());
}
