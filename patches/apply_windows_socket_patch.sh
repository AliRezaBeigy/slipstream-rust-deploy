#!/bin/bash
# Apply Windows socket type patches for slipstream-ffi and slipstream-server

set -e

# Patch runtime.rs for Windows socket types
RUNTIME_RS="crates/slipstream-ffi/src/runtime.rs"
if [ -f "$RUNTIME_RS" ]; then
  echo "Patching $RUNTIME_RS for Windows socket types..."
  
  # Replace the libc import with conditional compilation
  sed -i 's/use libc::{c_char, sockaddr_storage};/#[cfg(not(windows))]\nuse libc::{c_char, sockaddr_storage};\n#[cfg(windows)]\nuse winapi::shared::ws2def::{SOCKADDR_STORAGE as sockaddr_storage, SOCKADDR_IN, AF_INET, AF_INET6};\n#[cfg(windows)]\nuse winapi::shared::ws2ipdef::SOCKADDR_IN6_LH;\n#[cfg(windows)]\nuse libc::c_char;/' "$RUNTIME_RS"
  
  # Add #[cfg(not(windows))] before socket_addr_to_storage function
  sed -i 's/^pub fn socket_addr_to_storage(addr: SocketAddr)/#[cfg(not(windows))]\npub fn socket_addr_to_storage(addr: SocketAddr)/' "$RUNTIME_RS"
  
  # Add #[cfg(not(windows))] before sockaddr_storage_to_socket_addr function
  sed -i 's/^pub fn sockaddr_storage_to_socket_addr(storage: \&sockaddr_storage)/#[cfg(not(windows))]\npub fn sockaddr_storage_to_socket_addr(storage: \&sockaddr_storage)/' "$RUNTIME_RS"
  
  # Append Windows versions of the functions and re-export sockaddr_storage
  cat >> "$RUNTIME_RS" << 'WINDOWS_FUNCS'

// Re-export sockaddr_storage for use by other crates
#[cfg(not(windows))]
pub use libc::sockaddr_storage as SockaddrStorage;
#[cfg(windows)]
pub use winapi::shared::ws2def::SOCKADDR_STORAGE as SockaddrStorage;

#[cfg(windows)]
pub fn socket_addr_to_storage(addr: SocketAddr) -> sockaddr_storage {
    match addr {
        SocketAddr::V4(addr) => {
            let mut storage: sockaddr_storage = unsafe { std::mem::zeroed() };
            unsafe {
                let sockaddr_ptr = &mut storage as *mut _ as *mut SOCKADDR_IN;
                (*sockaddr_ptr).sin_family = AF_INET as u16;
                (*sockaddr_ptr).sin_port = addr.port().to_be();
                *(*sockaddr_ptr).sin_addr.S_un.S_addr_mut() = u32::from_ne_bytes(addr.ip().octets());
            }
            storage
        }
        SocketAddr::V6(addr) => {
            let mut storage: sockaddr_storage = unsafe { std::mem::zeroed() };
            unsafe {
                let sockaddr_ptr = &mut storage as *mut _ as *mut SOCKADDR_IN6_LH;
                (*sockaddr_ptr).sin6_family = AF_INET6 as u16;
                (*sockaddr_ptr).sin6_port = addr.port().to_be();
                (*sockaddr_ptr).sin6_flowinfo = addr.flowinfo();
                // Copy IPv6 address bytes directly using raw pointer
                let addr_bytes = addr.ip().octets();
                let dest_ptr = &mut (*sockaddr_ptr).sin6_addr as *mut _ as *mut u8;
                std::ptr::copy_nonoverlapping(addr_bytes.as_ptr(), dest_ptr, 16);
                // Set scope_id via the union
                let scope_ptr = &mut (*sockaddr_ptr).u as *mut _ as *mut u32;
                *scope_ptr = addr.scope_id();
            }
            storage
        }
    }
}

#[cfg(windows)]
pub fn sockaddr_storage_to_socket_addr(storage: &sockaddr_storage) -> Result<SocketAddr, String> {
    let family = storage.ss_family as i32;
    match family {
        AF_INET => {
            let addr_in: &SOCKADDR_IN =
                unsafe { &*(storage as *const _ as *const SOCKADDR_IN) };
            let ip = Ipv4Addr::from(unsafe { addr_in.sin_addr.S_un.S_addr().to_ne_bytes() });
            let port = u16::from_be(addr_in.sin_port);
            Ok(SocketAddr::V4(SocketAddrV4::new(ip, port)))
        }
        AF_INET6 => {
            let addr_in6: &SOCKADDR_IN6_LH =
                unsafe { &*(storage as *const _ as *const SOCKADDR_IN6_LH) };
            // Read IPv6 address bytes directly using raw pointer
            let src_ptr = &addr_in6.sin6_addr as *const _ as *const u8;
            let mut ip_bytes: [u8; 16] = [0; 16];
            unsafe { std::ptr::copy_nonoverlapping(src_ptr, ip_bytes.as_mut_ptr(), 16) };
            let ip = Ipv6Addr::from(ip_bytes);
            let port = u16::from_be(addr_in6.sin6_port);
            // Read scope_id via the union
            let scope_id = unsafe { *(&addr_in6.u as *const _ as *const u32) };
            Ok(SocketAddr::V6(SocketAddrV6::new(
                ip,
                port,
                addr_in6.sin6_flowinfo,
                scope_id,
            )))
        }
        _ => Err("Unsupported sockaddr family".to_string()),
    }
}
WINDOWS_FUNCS
  
  echo "Successfully patched $RUNTIME_RS"
fi

# Patch slipstream-ffi lib.rs to re-export SockaddrStorage
FFI_LIB="crates/slipstream-ffi/src/lib.rs"
if [ -f "$FFI_LIB" ]; then
  echo "Patching $FFI_LIB to re-export SockaddrStorage..."
  
  # Add SockaddrStorage to the re-exports
  sed -i 's/pub use runtime::{/pub use runtime::{\n    SockaddrStorage,/' "$FFI_LIB"
  
  echo "Successfully patched $FFI_LIB"
fi

# Patch picoquic.rs for Windows socket types
PICOQUIC_RS="crates/slipstream-ffi/src/picoquic.rs"
if [ -f "$PICOQUIC_RS" ]; then
  echo "Patching $PICOQUIC_RS for Windows socket types..."
  
  # Replace the libc import with conditional compilation
  sed -i 's/use libc::{c_char, c_int, c_uint, c_void, size_t, sockaddr, sockaddr_storage};/#[cfg(not(windows))]\nuse libc::{c_char, c_int, c_uint, c_void, size_t, sockaddr, sockaddr_storage};\n#[cfg(windows)]\nuse libc::{c_char, c_int, c_uint, c_void, size_t, sockaddr};\n#[cfg(windows)]\nuse winapi::shared::ws2def::SOCKADDR_STORAGE as sockaddr_storage;/' "$PICOQUIC_RS"
  
  echo "Successfully patched $PICOQUIC_RS"
fi

# Patch slipstream-server to use SockaddrStorage from slipstream_ffi
SERVER_RS="crates/slipstream-server/src/server.rs"
if [ -f "$SERVER_RS" ]; then
  echo "Patching $SERVER_RS to use SockaddrStorage from slipstream_ffi..."
  
  # Replace libc::sockaddr_storage with slipstream_ffi::SockaddrStorage
  sed -i 's/libc::sockaddr_storage/slipstream_ffi::SockaddrStorage/g' "$SERVER_RS"
  
  echo "Successfully patched $SERVER_RS"
fi

# Patch the dummy_sockaddr_storage function in server.rs for Windows
# This function creates a dummy IPv6 address for initialization
SERVER_RS="crates/slipstream-server/src/server.rs"
if [ -f "$SERVER_RS" ]; then
  echo "Patching dummy_sockaddr_storage in $SERVER_RS..."
  
  # Add Windows conditional for dummy_sockaddr_storage
  sed -i 's/^fn dummy_sockaddr_storage()/#[cfg(not(windows))]\nfn dummy_sockaddr_storage()/' "$SERVER_RS"
  
  # Append Windows version of dummy_sockaddr_storage
  cat >> "$SERVER_RS" << 'DUMMY_STORAGE'

#[cfg(windows)]
fn dummy_sockaddr_storage() -> slipstream_ffi::SockaddrStorage {
    use std::net::{Ipv6Addr, SocketAddrV6};
    slipstream_ffi::socket_addr_to_storage(
        std::net::SocketAddr::V6(SocketAddrV6::new(
            Ipv6Addr::new(0x2001, 0xdb8, 0, 0, 0, 0, 0, 1),
            12345,
            0,
            0,
        ))
    )
}
DUMMY_STORAGE
  
  echo "Successfully patched dummy_sockaddr_storage"
fi

# Patch slipstream-client files to use SockaddrStorage from slipstream_ffi
# Files that use libc::sockaddr_storage:
# - crates/slipstream-client/src/dns/path.rs
# - crates/slipstream-client/src/dns/poll.rs
# - crates/slipstream-client/src/dns/resolver.rs
# - crates/slipstream-client/src/dns/response.rs
# - crates/slipstream-client/src/runtime/path.rs
# - crates/slipstream-client/src/runtime.rs

CLIENT_FILES=(
  "crates/slipstream-client/src/dns/path.rs"
  "crates/slipstream-client/src/dns/poll.rs"
  "crates/slipstream-client/src/dns/resolver.rs"
  "crates/slipstream-client/src/dns/response.rs"
  "crates/slipstream-client/src/runtime/path.rs"
  "crates/slipstream-client/src/runtime.rs"
)

for CLIENT_FILE in "${CLIENT_FILES[@]}"; do
  if [ -f "$CLIENT_FILE" ]; then
    echo "Patching $CLIENT_FILE to use SockaddrStorage from slipstream_ffi..."
    
    # Replace libc::sockaddr_storage with slipstream_ffi::SockaddrStorage
    sed -i 's/libc::sockaddr_storage/slipstream_ffi::SockaddrStorage/g' "$CLIENT_FILE"
    
    echo "Successfully patched $CLIENT_FILE"
  fi
done

echo "Windows socket patches applied successfully"
