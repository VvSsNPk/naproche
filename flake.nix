{
  description = "Naproche: write formal proofs in natural language and LaTeX";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
        lib = pkgs.lib;

        # GHC 9.6.x matches the Stackage resolver in stack.yaml (lts-22.44).
        ghcVersion = "96";

        # Extra dependency not in nixpkgs (mirrors `extra-deps` in stack.yaml).
        ftlexSrc = pkgs.fetchzip {
          url = "https://codeberg.org/McEarl/ftlex/archive/v0.3.9.tar.gz";
          hash = "sha256-ApriPcOv/PPlPr8KFgPx+CgxbQnQmifABOxQvnGALFo=";
        };

        haskellPackages = pkgs.haskell.packages."ghc${ghcVersion}".override {
          overrides = hfinal: hprev: {
            # ftlex pins megaparsec <= 9.6.1 and bytestring >= 0.12, so relax the bounds;
            # its test suite needs a file argument, so skip it.
            ftlex = with pkgs.haskell.lib;
              dontCheck (doJailbreak (hfinal.callCabal2nix "ftlex" ftlexSrc { }));
            Naproche = hfinal.callCabal2nix "Naproche" (lib.fileset.toSource {
              root = ./.;
              fileset = lib.fileset.unions [
                ./package.yaml
                ./app
                ./src
                ./Isabelle/src
                ./README.md
                ./LICENSE.md
                ./CHANGELOG.md
                ./ACKNOWLEDGMENTS.md
                ./TODO.md
              ];
            }) { };
          };
        };

        # HLS built against exactly the same GHC as the dev shell.
        hls = pkgs.haskell-language-server.override {
          supportedGhcVersions = [ ghcVersion ];
        };
      in
      {
        packages.default = pkgs.haskell.lib.justStaticExecutables haskellPackages.Naproche;

        devShells.default = haskellPackages.shellFor {
          packages = p: [ p.Naproche ];
          withHoogle = false;

          nativeBuildInputs = [
            pkgs.cabal-install
            pkgs.hpack
            pkgs.ghcid
            pkgs.hlint
            hls
	    pkgs.stylish-haskell
            pkgs.stack
            # ATPs used by Naproche
            pkgs.eprover
            pkgs.vampire
            pkgs.spass
            pkgs.zipperposition
          ];

          shellHook = ''
            export NAPROCHE_EPROVER=${lib.getExe' pkgs.eprover "eprover"}
            export NAPROCHE_VAMPIRE=${lib.getExe' pkgs.vampire "vampire"}
            export NAPROCHE_SPASS=${lib.getExe' pkgs.spass "SPASS"}
            export NAPROCHE_ZIPPER=${lib.getExe pkgs.zipperposition}
            export NAPROCHE_FORMALIZATIONS="$PWD/math"
            # Naproche.cabal is generated from package.yaml (and gitignored).
            [ -f Naproche.cabal ] && [ Naproche.cabal -nt package.yaml ] || hpack --silent
          '';
        };
      });
}
