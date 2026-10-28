{
  description = "NixOS FHS build environment for Qualcomm Yocto BSP and meta-qcom-qim-product-sdk";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs = { self, nixpkgs }:
    let
      supportedSystems = [ "x86_64-linux" "aarch64-linux" ];
      forAllSystems = f: nixpkgs.lib.genAttrs supportedSystems (system: f system);
    in
    {
      packages = forAllSystems (system:
        let
          pkgs = import nixpkgs {
            inherit system;
            config = {
              allowUnfree = true;
            };
          };
          yoctoFhs = import ./default.nix { inherit pkgs; };
        in
        {
          default = yoctoFhs;
          fhs = yoctoFhs;
        }
      );

      devShells = forAllSystems (system:
        let
          pkgs = import nixpkgs { inherit system; config.allowUnfree = true; };
          fhsPkg = self.packages.${system}.fhs;
        in
        {
          # Default devShell: Lightweight shell designed for direnv & nix develop
          # Does NOT invoke bwrap in shellHook, preventing recursive namespace loops
          default = pkgs.mkShell {
            name = "qualcomm-yocto-host-shell";
            packages = with pkgs; [
              git
              git-repo
              gnumake
              fhsPkg
            ];
            shellHook = ''
              # Automatically create or refresh the fhs-bin symlink whenever jumping into the devShell
              if [ ! -L "$PWD/fhs-bin" ] || [ "$(readlink -f "$PWD/fhs-bin")" != "${fhsPkg}" ]; then
                ln -sfn "${fhsPkg}" "$PWD/fhs-bin"
              fi

              export PATH="$PWD:$PWD/fhs-bin/bin:$PATH"
              export YOCTO_FHS_BIN="${fhsPkg}/bin/yocto-fhs-env"
              alias enter-fhs="$PWD/enter-env.sh"
            '';
          };

          # Dedicated FHS development shell (accessible via `nix develop .#fhs`)
          fhs = (import ./default.nix { inherit pkgs; }).env;
        }
      );
    };
}
