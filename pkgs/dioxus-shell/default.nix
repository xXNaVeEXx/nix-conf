{
  rustPlatform,
  lib,
  pkg-config,
  makeWrapper,
  python3,
  wayland,
  libxkbcommon,
  vulkan-loader,
  fontconfig,
  freetype,
}:

rustPlatform.buildRustPackage {
  pname = "dioxus-shell";
  version = "0.0.1";

  src = lib.cleanSource ./.;

  cargoLock = {
    lockFile = ./Cargo.lock;
    outputHashes = {
      # DioxusLabs/blitz @ 6863eac76c36a64a8926c5a71947f478c3614a64
      "blitz-dom-0.3.0-alpha.2" = "sha256-kwkKWbf/JGdkBX429buFJWelRCkIYdgsqDNwj+/MqtM=";
      "blitz-paint-0.3.0-alpha.2" = "sha256-kwkKWbf/JGdkBX429buFJWelRCkIYdgsqDNwj+/MqtM=";
      "blitz-traits-0.3.0-alpha.2" = "sha256-kwkKWbf/JGdkBX429buFJWelRCkIYdgsqDNwj+/MqtM=";
      "debug_timer-0.1.3" = "sha256-kwkKWbf/JGdkBX429buFJWelRCkIYdgsqDNwj+/MqtM=";
      "dioxus-native-dom-0.7.0" = "sha256-kwkKWbf/JGdkBX429buFJWelRCkIYdgsqDNwj+/MqtM=";
      "stylo_taffy-0.3.0-alpha.2" = "sha256-kwkKWbf/JGdkBX429buFJWelRCkIYdgsqDNwj+/MqtM=";
      # DioxusLabs/anyrender @ c12e3ffd9b50498d776cd7032b4b956c6612b5db
      "anyrender-0.8.0" = "sha256-rNl0YxDdFCgLuF1w0gv+EvHfuz3p/b/M6Nu24FIdPXg=";
      "anyrender_vello-0.8.0" = "sha256-rNl0YxDdFCgLuF1w0gv+EvHfuz3p/b/M6Nu24FIdPXg=";
      "anyrender_vello_cpu-0.10.0" = "sha256-rNl0YxDdFCgLuF1w0gv+EvHfuz3p/b/M6Nu24FIdPXg=";
      "wgpu_context-0.4.0" = "sha256-rNl0YxDdFCgLuF1w0gv+EvHfuz3p/b/M6Nu24FIdPXg=";
    };
  };

  nativeBuildInputs = [
    pkg-config
    makeWrapper
    python3 # stylo build.rs invokes python for property generation
  ];

  buildInputs = [
    wayland
    libxkbcommon
    vulkan-loader
    fontconfig
    freetype
  ];

  postFixup = ''
    wrapProgram $out/bin/dioxus-shell \
      --prefix LD_LIBRARY_PATH : ${
        lib.makeLibraryPath [
          wayland
          libxkbcommon
          vulkan-loader
        ]
      }
  '';

  meta = {
    description = "Dioxus + smithay-client-toolkit Wayland shell (skeleton)";
    mainProgram = "dioxus-shell";
    platforms = lib.platforms.linux;
  };
}
