{
  description = "claude-extensions dev environment";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
      in {
        devShells.default = pkgs.mkShell {
          packages = with pkgs; [
            bash
            bats
            jq
            tmux
            shellcheck
          ];

          shellHook = ''
            echo "claude-extensions dev environment"
            echo "  bats      $(bats --version)"
            echo "  jq        $(jq --version)"
            echo "  shellcheck $(shellcheck --version | head -2 | tail -1)"
          '';
        };
      });
}
