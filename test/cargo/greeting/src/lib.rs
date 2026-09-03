// What a C++ build gets from Rust: a symbol with C linkage and a pointer to
// bytes that outlive the call.
#[no_mangle]
pub extern "C" fn cme_greeting() -> *const u8 {
    concat!("cme-greeting ", env!("CARGO_PKG_VERSION"), "\0").as_ptr()
}
