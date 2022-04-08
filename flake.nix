{
  description = "Flake to run grub2-theme-preview";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/master";
    flake-utils.url = "github:numtide/flake-utils";
    flake-utils.inputs.nixpkgs.follows = "nixpkgs";

    mach-nix.url = "github:DavHau/mach-nix";
    mach-nix.inputs.nixpkgs.follows = "nixpkgs";
    mach-nix.inputs.flake-utils.follows = "flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils, mach-nix, ... }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        python = "python39";
        pkgs = import nixpkgs {
          inherit system;
        };
        mach-nix-wrapper = import mach-nix { inherit pkgs python; };
        requirements = ''
          # pinned to mach pypi-dep-db revision.
          setuptools
        '';
        pythonBuild = mach-nix-wrapper.mkPython {
          inherit requirements;
        };
        # app requirements
        dependencies = [
          pkgs.grub2_efi
          pkgs.mtools
          pkgs.OVMF
          pkgs.qemu
          pkgs.xorriso
          pythonBuild
        ];
      in
      {
        defaultPackage =
          pkgs.stdenv.mkDerivation {
            name = "grub2-theme-preview";
            src = self;
            propagatedBuildInputs = dependencies;
            installPhase = ''
              mkdir -p $out/bin;
              ${pythonBuild}/bin/python setup.py install --root "$out" --prefix .;
              mv $out/bin/grub2-theme-preview $out/bin/.grub2-theme-preview-wrapped;
              cat <<EOF >> $out/bin/grub2-theme-preview
              #!${pkgs.bash}/bin/bash
              PATH=\$PATH:${pkgs.grub2_efi}/bin:${pkgs.qemu}/bin:${pkgs.xorriso}/bin:${pkgs.mtools}/bin\
                PYTHONPATH=\$PYTHONPATH:$out/lib/python3.9/site-packages\
                G2TP_GRUB_LIB=${pkgs.grub2_efi}/lib/grub\
                G2TP_OVMF_IMAGE=${pkgs.OVMF.fd}/FV/OVMF.fd\
                $out/bin/.grub2-theme-preview-wrapped \$@;
              EOF
              chmod +x $out/bin/grub2-theme-preview;
            '';
          };
      });
}
