//! NetProvider for the Dioxus shell.
//!
//! Blitz routes every image URL through `NetProvider::fetch` regardless of
//! scheme — there is no inline shortcut for `data:` URLs in blitz-dom (only
//! the optional `blitz-net` reference provider handles it). Our provider
//! therefore needs to handle both `data:` and `file:` itself, otherwise
//! `<img>` elements with those URLs sit in `pending_images` forever and
//! never paint.

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
        match request.url.scheme() {
            "data" => {
                // Replicates the blitz-net data: branch
                // (packages/blitz-net/src/lib.rs:112-116).
                match data_url::DataUrl::process(request.url.as_str()) {
                    Ok(du) => match du.decode_to_vec() {
                        Ok((decoded, _)) => {
                            handler.bytes(request.url.to_string(), Bytes::from(decoded));
                        }
                        Err(e) => log::debug!("data-url decode failed: {e:?}"),
                    },
                    Err(e) => log::debug!("data-url parse failed: {e:?}"),
                }
            }
            "file" => {
                let path = match request.url.to_file_path() {
                    Ok(p) => p,
                    Err(_) => {
                        log::debug!("LocalFileProvider: bad file path {}", request.url);
                        return;
                    }
                };
                match std::fs::read(&path) {
                    Ok(data) => {
                        handler.bytes(request.url.to_string(), Bytes::from(data));
                    }
                    Err(e) => {
                        log::debug!("LocalFileProvider read {} failed: {e}", path.display());
                    }
                }
            }
            other => {
                log::debug!("LocalFileProvider: dropping {other}: scheme");
            }
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::fs;
    use std::sync::{Arc, Mutex};

    /// Captures `handler.bytes` calls for assertion.
    #[derive(Default, Clone)]
    struct FakeHandler(Arc<Mutex<Vec<(String, Vec<u8>)>>>);

    impl NetHandler for FakeHandler {
        fn bytes(self: Box<Self>, resolved_url: String, bytes: Bytes) {
            self.0
                .lock()
                .unwrap()
                .push((resolved_url, bytes.to_vec()));
        }
    }

    fn fetch_with(provider: &LocalFileProvider, url: &str) -> Vec<(String, Vec<u8>)> {
        let captured: Arc<Mutex<Vec<(String, Vec<u8>)>>> = Arc::default();
        let handler = FakeHandler(captured.clone());
        let parsed = url::Url::parse(url).unwrap_or_else(|e| panic!("bad url {url}: {e}"));
        let request = Request::get(parsed);
        provider.fetch(0, request, Box::new(handler));
        let guard = captured.lock().unwrap();
        guard.clone()
    }

    #[test]
    fn data_url_png_decodes() {
        let provider = LocalFileProvider;
        // 8x8 red PNG
        let url = "data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAgAAAAIAQMAAAD+wSzIAAAABlBMVEX/AAD///9BHTQRAAAADElEQVQI12NgwAYAABIAAemkX9MAAAAASUVORK5CYII=";
        let captured = fetch_with(&provider, url);
        assert_eq!(captured.len(), 1, "expected one bytes call");
        let (resolved, bytes) = &captured[0];
        assert!(resolved.starts_with("data:image/png;base64,"), "{resolved}");
        assert_eq!(&bytes[..8], b"\x89PNG\r\n\x1a\n", "decoded should be a PNG header");
    }

    #[test]
    fn data_url_text_plain_decodes() {
        let provider = LocalFileProvider;
        // base64 of "hello"
        let url = "data:text/plain;base64,aGVsbG8=";
        let captured = fetch_with(&provider, url);
        assert_eq!(captured.len(), 1);
        assert_eq!(captured[0].1, b"hello");
    }

    #[test]
    fn file_url_reads_disk() {
        let provider = LocalFileProvider;
        let tmp = tempfile::TempDir::new().unwrap();
        let path = tmp.path().join("hello.bin");
        fs::write(&path, b"hello disk").unwrap();
        let url = format!("file://{}", path.display());
        let captured = fetch_with(&provider, &url);
        assert_eq!(captured.len(), 1);
        assert_eq!(captured[0].1, b"hello disk");
    }

    #[test]
    fn file_url_missing_returns_no_bytes() {
        let provider = LocalFileProvider;
        let captured = fetch_with(&provider, "file:///nonexistent/path/does/not/exist");
        assert_eq!(captured.len(), 0);
    }

    #[test]
    fn https_scheme_dropped_silently() {
        let provider = LocalFileProvider;
        let captured = fetch_with(&provider, "https://example.com/icon.png");
        assert_eq!(captured.len(), 0);
    }

    /// Helper: build a Dioxus app with one `<img>` element using the given
    /// data URL, render it through DioxusDocument with a custom NetProvider,
    /// and return the document for further inspection.
    fn build_doc_with_img(
        provider: Arc<dyn NetProvider>,
        data_url: &'static str,
    ) -> dioxus_native_dom::DioxusDocument {
        use blitz_dom::DocumentConfig;
        use blitz_traits::shell::{ColorScheme, Viewport};
        use dioxus::prelude::*;
        use dioxus_native_dom::DioxusDocument;

        // Need a function pointer (not closure) for VirtualDom::new. Stash the
        // url in a global since we can't capture into the fn pointer.
        // Test-only — single-threaded test runner means no race.
        thread_local! {
            static URL: std::cell::Cell<&'static str> = const { std::cell::Cell::new("") };
        }
        URL.with(|u| u.set(data_url));

        fn img_app() -> dioxus::prelude::Element {
            let url = URL.with(|u| u.get());
            rsx! { img { src: "{url}" } }
        }

        thread_local! {
            static URL_INNER: std::cell::Cell<&'static str> = const { std::cell::Cell::new("") };
        }
        URL_INNER.with(|u| u.set(data_url));

        let vdom = VirtualDom::new(img_app);
        let mut doc = DioxusDocument::new(
            vdom,
            DocumentConfig {
                viewport: Some(Viewport::new(800, 32, 1.0, ColorScheme::Dark)),
                net_provider: Some(provider),
                ..Default::default()
            },
        );
        doc.initial_build();
        doc
    }

    /// Integration test: build a real DioxusDocument, render rsx that includes
    /// an <img>, run initial_build + poll, and watch whether Blitz actually
    /// invokes our NetProvider for the image src.
    ///
    /// If this passes (`fetch was called`), our provider integration is fine
    /// and the bug is later in the pipeline (paint phase). If it fails
    /// (`fetch was never called`), the bug is in the Dioxus → Blitz mutation
    /// path: <img> doesn't reach the load_image queue at all.
    #[test]
    fn blitz_invokes_net_provider_for_img_elements() {
        use blitz_dom::{Document, DocumentConfig};
        use blitz_traits::shell::{ColorScheme, Viewport};
        use dioxus::prelude::*;
        use dioxus_native_dom::DioxusDocument;
        use std::sync::atomic::{AtomicBool, Ordering};

        struct ProbingProvider {
            called: Arc<AtomicBool>,
        }
        impl NetProvider for ProbingProvider {
            fn fetch(&self, _doc_id: usize, _request: Request, _handler: Box<dyn NetHandler>) {
                self.called.store(true, Ordering::SeqCst);
            }
        }

        let called = Arc::new(AtomicBool::new(false));
        let provider = Arc::new(ProbingProvider {
            called: called.clone(),
        });

        #[component]
        fn ImageApp() -> Element {
            rsx! {
                img {
                    src: "data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAgAAAAIAQMAAAD+wSzIAAAABlBMVEX/AAD///9BHTQRAAAADElEQVQI12NgwAYAABIAAemkX9MAAAAASUVORK5CYII=",
                }
            }
        }

        let vdom = VirtualDom::new(ImageApp);
        let mut doc = DioxusDocument::new(
            vdom,
            DocumentConfig {
                viewport: Some(Viewport::new(800, 32, 1.0, ColorScheme::Dark)),
                net_provider: Some(provider),
                ..Default::default()
            },
        );
        doc.initial_build();

        // Drain any pending DocumentEvents that might cascade more loads.
        doc.inner.borrow_mut().handle_messages();

        assert!(
            called.load(Ordering::SeqCst),
            "Blitz did NOT call NetProvider::fetch for the <img> element. \
             This means dynamically-rendered img elements don't trigger \
             load_image in our Dioxus + Blitz integration."
        );
    }

    /// After our provider delivers bytes via handler.bytes() and we drain
    /// DocumentEvents, the document should contain an Image resource
    /// associated with the <img> element. If this fails, the gap is between
    /// "bytes delivered" and "rendered" — likely missing handle_messages or
    /// missing damage flag.
    /// Build a valid 8x8 red PNG at runtime via the `image` crate, then
    /// produce a data: URL for it.
    fn red_png_data_url() -> String {
        use base64::Engine as _;
        let mut img = image::RgbaImage::new(8, 8);
        for px in img.pixels_mut() {
            *px = image::Rgba([255, 0, 0, 255]);
        }
        let mut bytes = Vec::new();
        image::DynamicImage::ImageRgba8(img)
            .write_to(&mut std::io::Cursor::new(&mut bytes), image::ImageFormat::Png)
            .unwrap();
        let b64 = base64::engine::general_purpose::STANDARD.encode(&bytes);
        format!("data:image/png;base64,{b64}")
    }

    /// Same end-to-end test, but using real-world icons embedded as fixtures.
    /// Tests both a small PNG (brave), a larger PNG (wezterm), and an SVG
    /// (nautilus). If any of these fail to land in the document after
    /// handle_messages, the bug is upstream of our code.
    #[test]
    fn real_icon_fixtures_land_in_document() {
        let cases: &[(&str, &[u8], &str)] = &[
            (
                "brave",
                include_bytes!("../../tests/fixtures/brave-browser.png"),
                "image/png",
            ),
            (
                "wezterm",
                include_bytes!("../../tests/fixtures/wezterm.png"),
                "image/png",
            ),
            (
                "nautilus",
                include_bytes!("../../tests/fixtures/nautilus.svg"),
                "image/svg+xml",
            ),
        ];

        for (name, bytes, mime) in cases {
            // For raster images, sanity-check via the image crate (same lib
            // blitz uses).
            if mime.starts_with("image/png") || mime.starts_with("image/jpeg") {
                let parsed = image::ImageReader::new(std::io::Cursor::new(*bytes))
                    .with_guessed_format()
                    .expect("io")
                    .decode();
                assert!(
                    parsed.is_ok(),
                    "{name}: PNG fixture fails to parse via image crate: {:?}",
                    parsed.err()
                );
            }

            use base64::Engine as _;
            let b64 = base64::engine::general_purpose::STANDARD.encode(bytes);
            let url: &'static str =
                Box::leak(format!("data:{mime};base64,{b64}").into_boxed_str());

            let provider = Arc::new(LocalFileProvider);
            let mut doc = build_doc_with_img(provider, url);

            for _ in 0..5 {
                doc.inner.borrow_mut().handle_messages();
            }

            let inner = doc.inner.borrow();
            let root = inner.root_node();
            let (found, has_data) = walk_for_img(&inner, root);
            assert!(found, "<img> missing for {name}");
            assert!(
                has_data,
                "{name} ({} bytes, {mime}): special_data is None after handle_messages",
                bytes.len()
            );
        }
    }

    /// After handle_messages + resolve, the <img> element should have a
    /// nonzero layout rect. If width/height are 0 even though src/special_data
    /// are populated, vello won't paint visible pixels.
    /// Final integration test: render the document into a vello::Scene via
    /// blitz_paint and verify the scene encoded the image as a draw operation.
    /// vello::Scene exposes its encoding internals; we just check that the
    /// scene isn't empty, with bytes that scale with image content.
    #[test]
    fn paint_scene_emits_image_drawing() {
        use anyrender_vello::VelloScenePainter;
        use blitz_dom::Document;
        use vello::Scene;

        let url = Box::leak(red_png_data_url().into_boxed_str()) as &'static str;

        use blitz_dom::DocumentConfig;
        use blitz_traits::shell::{ColorScheme, Viewport};
        use dioxus::prelude::*;
        use dioxus_native_dom::DioxusDocument;

        thread_local! {
            static U: std::cell::Cell<&'static str> = const { std::cell::Cell::new("") };
        }
        U.with(|u| u.set(url));

        fn app() -> Element {
            let url = U.with(|u| u.get());
            rsx! {
                style { "img.icon {{ width: 40px; height: 40px; object-fit: contain; }}" }
                img { class: "icon", src: "{url}" }
            }
        }

        // --- WITHOUT image: control scene ---
        let vdom = VirtualDom::new(|| {
            rsx! {
                style { "div.box {{ width: 40px; height: 40px; }}" }
                div { class: "box" }
            }
        });
        let mut doc_no_img = DioxusDocument::new(
            vdom,
            DocumentConfig {
                viewport: Some(Viewport::new(800, 100, 1.0, ColorScheme::Dark)),
                net_provider: Some(Arc::new(LocalFileProvider)),
                ..Default::default()
            },
        );
        doc_no_img.initial_build();
        let mut control_scene = Scene::new();
        {
            let mut inner = doc_no_img.inner.borrow_mut();
            inner.resolve(0.0);
            let mut painter = VelloScenePainter::new(&mut control_scene);
            blitz_paint::paint_scene(&mut painter, &inner, 1.0, 800, 100, 0, 0);
        }
        let control_size = control_scene.encoding().path_data.len()
            + control_scene.encoding().draw_data.len();

        // --- WITH image ---
        let vdom = VirtualDom::new(app);
        let mut doc = DioxusDocument::new(
            vdom,
            DocumentConfig {
                viewport: Some(Viewport::new(800, 100, 1.0, ColorScheme::Dark)),
                net_provider: Some(Arc::new(LocalFileProvider)),
                ..Default::default()
            },
        );
        doc.initial_build();
        for _ in 0..5 {
            doc.inner.borrow_mut().handle_messages();
        }
        let mut img_scene = Scene::new();
        {
            let mut inner = doc.inner.borrow_mut();
            inner.resolve(0.0);
            let mut painter = VelloScenePainter::new(&mut img_scene);
            blitz_paint::paint_scene(&mut painter, &inner, 1.0, 800, 100, 0, 0);
        }
        let img_size = img_scene.encoding().path_data.len()
            + img_scene.encoding().draw_data.len();

        // The image-bearing scene should have meaningfully more encoded data
        // than the control. If it's the same or smaller, blitz didn't emit
        // image drawing instructions.
        assert!(
            img_size > control_size,
            "image scene encoding ({img_size} bytes) is not larger than \
             control scene ({control_size} bytes) — paint_scene didn't emit \
             image draw operations"
        );
    }

    #[test]
    fn img_has_nonzero_layout_after_resolve() {
        use blitz_dom::Document;

        let url = Box::leak(red_png_data_url().into_boxed_str()) as &'static str;

        // Build doc with explicit CSS sizing — same shape we use in the dock.
        use blitz_dom::DocumentConfig;
        use blitz_traits::shell::{ColorScheme, Viewport};
        use dioxus::prelude::*;
        use dioxus_native_dom::DioxusDocument;

        thread_local! {
            static U: std::cell::Cell<&'static str> = const { std::cell::Cell::new("") };
        }
        U.with(|u| u.set(url));

        fn app() -> Element {
            let url = U.with(|u| u.get());
            rsx! {
                style { "img.icon {{ width: 40px; height: 40px; object-fit: contain; }}" }
                img { class: "icon", src: "{url}" }
            }
        }

        let vdom = VirtualDom::new(app);
        let mut doc = DioxusDocument::new(
            vdom,
            DocumentConfig {
                viewport: Some(Viewport::new(800, 100, 1.0, ColorScheme::Dark)),
                net_provider: Some(Arc::new(LocalFileProvider)),
                ..Default::default()
            },
        );
        doc.initial_build();
        for _ in 0..5 {
            doc.inner.borrow_mut().handle_messages();
        }

        // resolve() runs styling+layout. After this the layout cache has rects.
        let mut inner = doc.inner.borrow_mut();
        inner.resolve(0.0);

        let root = inner.root_node();
        let (found, w, h) = walk_for_img_layout(&inner, root);
        assert!(found, "img not found");
        assert!(
            w > 0.0 && h > 0.0,
            "img layout rect is {w}x{h} after resolve — vello paints nothing for zero-sized rects"
        );
    }

    fn walk_for_img_layout(
        doc: &blitz_dom::BaseDocument,
        node: &blitz_dom::Node,
    ) -> (bool, f64, f64) {
        if let blitz_dom::NodeData::Element(el) = &node.data {
            if el.name.local.as_ref() == "img" {
                let layout = node.final_layout;
                let w = layout.size.width as f64;
                let h = layout.size.height as f64;
                return (true, w, h);
            }
        }
        for child_id in node.children.iter() {
            if let Some(child) = doc.get_node(*child_id) {
                let (f, w, h) = walk_for_img_layout(doc, child);
                if f {
                    return (f, w, h);
                }
            }
        }
        (false, 0.0, 0.0)
    }

    #[test]
    fn img_resource_lands_in_document_after_handle_messages() {
        // Build a real, valid PNG at runtime.
        let url = Box::leak(red_png_data_url().into_boxed_str()) as &'static str;

        // Sanity: parse the PNG via `image` (same lib blitz uses). If this
        // fails, our generator is bogus.
        use base64::Engine as _;
        let png_bytes = base64::engine::general_purpose::STANDARD
            .decode(url.strip_prefix("data:image/png;base64,").unwrap())
            .unwrap();
        let parsed = image::ImageReader::new(std::io::Cursor::new(&png_bytes))
            .with_guessed_format()
            .expect("io")
            .decode();
        assert!(parsed.is_ok(), "test PNG fails to parse: {:?}", parsed.err());

        let provider = Arc::new(LocalFileProvider);
        let mut doc = build_doc_with_img(provider, url);

        // Drain messages — this is what Ui::poll calls in the real shell.
        for _ in 0..5 {
            doc.inner.borrow_mut().handle_messages();
        }

        // Walk the document tree from root, find the <img> node, check if it
        // has image data attached.
        let inner = doc.inner.borrow();
        let root = inner.root_node();
        let (found, has_data) = walk_for_img(&inner, root);
        assert!(found, "<img> element not found in the document");
        assert!(
            has_data,
            "After handle_messages, the <img> element's special_data is still None — \
             the bytes were delivered to the handler but never landed on the node."
        );
    }

    /// DFS the tree from `node` looking for an <img> element. Returns
    /// (found_img, img_has_special_data).
    fn walk_for_img(
        doc: &blitz_dom::BaseDocument,
        node: &blitz_dom::Node,
    ) -> (bool, bool) {
        if let blitz_dom::NodeData::Element(el) = &node.data {
            if el.name.local.as_ref() == "img" {
                use blitz_dom::node::SpecialElementData;
                let has_data = !matches!(el.special_data, SpecialElementData::None);
                return (true, has_data);
            }
        }
        for child_id in node.children.iter() {
            if let Some(child) = doc.get_node(*child_id) {
                let (found, has_data) = walk_for_img(doc, child);
                if found {
                    return (found, has_data);
                }
            }
        }
        (false, false)
    }
}
