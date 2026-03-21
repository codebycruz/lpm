{
  description = "A package manager for Lua, written in Lua.";
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";
  inputs.systems.url = "github:nix-systems/default";
  inputs.flake-utils = {
    url = "github:numtide/flake-utils";
    inputs.systems.follows = "systems";
  };

  outputs =
    { nixpkgs, flake-utils, ... }:
    let
      # NOTE: To be generated with get-nix-platform-attrs.sh when lj-dist is updated
      platform_attrs = {
        "aarch64-darwin" = {
          target = "libluajit-macos-aarch64";
          url = "https://github.com/codebycruz/lj-dist/releases/download/latest/libluajit-macos-aarch64.tar.gz";
          hash = "14mgjw6h6m6cryjl4swb1x860vi4xnjqq6swsa31k4xmgba9x9lp";
        };
        "x86_64-darwin" = {
          target = "libluajit-macos-x86-64";
          url = "https://github.com/codebycruz/lj-dist/releases/download/latest/libluajit-macos-x86-64.tar.gz";
          hash = "18qd9i3gjhvapnciffba8dw290hgg4ca3xdfa6vbnmczvxmg89c5";
        };
        "aarch64-linux" = {
          target = "libluajit-linux-aarch64-gnu";
          url = "https://github.com/codebycruz/lj-dist/releases/download/latest/libluajit-linux-aarch64-gnu.tar.gz";
          hash = "1n1yvyzdyrj9x7z49kj8q1w15qg4q66sp5x7sfjvi5zdkp9xmsba";
        };
        "x86_64-linux" = {
          target = "libluajit-linux-x86-64-gnu";
          url = "https://github.com/codebycruz/lj-dist/releases/download/latest/libluajit-linux-x86-64-gnu.tar.gz";
          hash = "1alxh2vmxf63cx78pfxj5a1sa9355j9vqqizsahg85p2gycbin70";
        };
      };
    in
    flake-utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = nixpkgs.legacyPackages.${system};

        target = platform_attrs.${system}.target;
        url = platform_attrs.${system}.url;
        hash = platform_attrs.${system}.hash;

        unpackedTarballPath = fetchTarball {
          url = url;
          sha256 = hash;
        };

        lpm = pkgs.stdenv.mkDerivation {
          pname = "lpm";
          # NOTE: This will have to be updated when the version changes
          version = "0.7.1";
          src = ./.;

          nativeBuildInputs = [ pkgs.luajit ];
          buildPhase = ''
            tmpdir="$out/tmp"
            # Cache expected by the lua program
            cachedir="$tmpdir/luajit-cache/${target}"

            #(Silzinc) HACK: Something is wrong with this approach.
            # I will probably rather write another nix derivation to build
            # libluajit directly rather than fetching it.
            mkdir -p "$(dirname "$cachedir")"
            ln -s "${unpackedTarballPath}" "$cachedir"

            cd packages/lpm
            TMPDIR="$tmpdir" BOOTSTRAP=1 luajit ./src/init.lua compile --outfile lpm
          '';
          installPhase = ''
            mkdir -p "$out/bin"
            cp lpm "$out/bin"
            rm -rf "$out/tmp"
          '';
        };
      in
      {
        packages.default = lpm;

        devShells.default = pkgs.mkShell {
          packages =
            with pkgs;
            [
              luajit
              stylua
              lua-language-server
            ]
            #(Silzinc) NOTE: I'm not sure about bootstraping lpm like that,
            # since the result changes with the commit. Is it necessary to develop lpm itself?
            # Once the commit is merged, I will try fetching this lpm from a version on github.
            ++ [ lpm ];
        };
      }
    );
}
