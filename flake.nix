{
  description = "fakecloud — a local AWS emulator (KMS, DynamoDB, Lambda, API Gateway, …)";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs = { self, nixpkgs }:
    let
      systems = [ "x86_64-linux" "aarch64-linux" "x86_64-darwin" "aarch64-darwin" ];
      forAllSystems = f: nixpkgs.lib.genAttrs systems (system: f (import nixpkgs { inherit system; }));

      # fakecloud is not in nixpkgs, so it is built from source at the tag. The workspace root is
      # virtual (buildAndTestSubdir picks the server crate), the dependencies come from the
      # repository's own lockfile, and the emulator's conformance suite is not run here.
      mkFakecloud = pkgs: pkgs.rustPlatform.buildRustPackage rec {
        pname = "fakecloud";
        version = "0.50.0";

        src = pkgs.fetchFromGitHub {
          owner = "faiscadev";
          repo = "fakecloud";
          rev = "v${version}";
          hash = "sha256-G+0SG9aLeLxubtIuk9bnUPN7c0/jBnUc1XKJl3FynfM=";
        };

        buildAndTestSubdir = "crates/fakecloud-server";
        cargoLock.lockFile = "${src}/Cargo.lock";
        doCheck = false;

        meta.mainProgram = "fakecloud";

        # aws-lc-rs (the crypto provider behind the TLS stack) compiles C with cmake + perl + nasm;
        # some crates link against the system OpenSSL (openssl-sys).
        nativeBuildInputs = [ pkgs.cmake pkgs.perl pkgs.nasm pkgs.pkg-config ];
        buildInputs = [ pkgs.openssl ];
      };
    in {
      packages = forAllSystems (pkgs: rec {
        fakecloud = mkFakecloud pkgs;
        default = fakecloud;
      });

      # nix run . -- --addr 127.0.0.1:4566
      apps = forAllSystems (pkgs: rec {
        fakecloud = {
          type = "app";
          program = nixpkgs.lib.getExe self.packages.${pkgs.stdenv.hostPlatform.system}.fakecloud;
        };
        default = fakecloud;
      });

      overlays.default = final: prev: { fakecloud = mkFakecloud final; };
    };
}
