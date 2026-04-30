//! Minimal NetProvider that handles `file://` URLs only.
//!
//! Blitz uses NetProvider to fetch external resources (images, stylesheets,
//! etc.) referenced from the DOM. The default `blitz-net` provider pulls in
//! reqwest + rustls — heavy and unnecessary for a desktop shell that only
//! references local icon files. This 30-line stub does exactly what we need.

use blitz_traits::net::{Bytes, NetHandler, NetProvider, Request};
use std::sync::Arc;

pub struct LocalFileProvider;

impl LocalFileProvider {
    pub fn arc() -> Arc<dyn NetProvider> {
        Arc::new(Self)
    }
}

impl NetProvider for LocalFileProvider {
    fn fetch(&self, _doc_id: usize, request: Request, handler: Box<dyn NetHandler>) {
        if request.url.scheme() != "file" {
            return;
        }
        let path = match request.url.to_file_path() {
            Ok(p) => p,
            Err(_) => return,
        };
        match std::fs::read(&path) {
            Ok(data) => {
                let resolved = request.url.to_string();
                handler.bytes(resolved, Bytes::from(data));
            }
            Err(e) => {
                log::debug!("LocalFileProvider: read {} failed: {e}", path.display());
            }
        }
    }
}
