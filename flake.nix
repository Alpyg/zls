{
  inputs =
    {
      nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.11";

      zig-overlay.url = "github:Alpyg/zig-overlay";
      zig-overlay.inputs.nixpkgs.follows = "nixpkgs";

      gitignore.url = "github:hercules-ci/gitignore.nix";
      gitignore.inputs.nixpkgs.follows = "nixpkgs";
    };

  outputs = { self, nixpkgs, zig-overlay, gitignore }: let
    inherit (nixpkgs) lib;

    # flake-utils polyfill
    eachSystem = systems: fn:
      lib.foldl' (
        acc: system:
          lib.recursiveUpdate
          acc
          (lib.mapAttrs (_: value: {${system} = value;}) (fn system))
      ) {}
      systems;

    systems = ["x86_64-linux" "aarch64-linux" "x86_64-darwin" "aarch64-darwin"];
  in eachSystem systems (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
        zig = zig-overlay.packages.${system}.master-mach;
        gitignoreSource = gitignore.lib.gitignoreSource;
      in
      rec {
        formatter = pkgs.nixpkgs-fmt;
        packages.default = packages.zls;
        packages.zls = pkgs.stdenvNoCC.mkDerivation {
          name = "zls";
          version = "master-mach";
          meta.mainProgram = "zls";
          src = gitignoreSource ./.;
          nativeBuildInputs = [ zig ];
          dontConfigure = true;
          dontInstall = true;
          doCheck = true;
          buildPhase = ''
            NO_COLOR=1 # prevent escape codes from messing up the `nix log`
            PACKAGE_DIR=${pkgs.callPackage ./deps.nix { zig = zig; }}
            zig build install --global-cache-dir $(pwd)/.cache --system $PACKAGE_DIR -Dcpu=baseline -Doptimize=ReleaseSafe --prefix $out
          '';
          checkPhase = ''
            zig build test --global-cache-dir $(pwd)/.cache --system $PACKAGE_DIR -Dcpu=baseline
          '';
        };
      }
    );
}
