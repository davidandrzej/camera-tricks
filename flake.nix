{
  description = "Python project that merges Nix site-packages into a local venv";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
    let
      # Overlay for python3_12, if you have custom overrides
      myOverlay = final: prev: {
        python3_12 = prev.python312.override {
          packageOverrides = pySelf: pySuper: {
            # ... your custom overrides if any ...
          };
        };

        # Alias python3 -> python3_12
        python3 = final.python3_12;
      };

      pkgs = import nixpkgs {
        inherit system;
        overlays = [ myOverlay ];
      };
    in {
      devShells.default = pkgs.mkShell {
        name = "my-devshell";

        # Nix-provided Python + packages
        packages = [
          (pkgs.python3.withPackages (p: [
            # Example: Nix packages you want accessible from the venv
            p.onvif-zeep
            p.opencv-python
            p.accelerate
            p.transformers
            # Omit torch etc. if you plan to install them from PyPI
          ]))
        ];

        shellHook = ''
          echo "System Python (Nix): $(which python)"
          echo "System Python (Nix) version: $(python --version)"

          # 1) Identify the Nix site-packages directory(s)
          #    We'll parse them into NIX_SITE_PACKS (colon-separated if more than one).
          NIX_SITE_PACKS="$(python -c 'import site; print(":".join(site.getsitepackages()))')"

          # 2) If .venv doesn't exist OR if it was made by a different Python version, recreate
          if [ -d .venv ]; then
            # Compare Python versions
            VENV_VERSION=$(.venv/bin/python -c "import sys; print(sys.version_info[:2])" 2>/dev/null || echo "none")
            NIX_VERSION=$(python -c "import sys; print(sys.version_info[:2])")
            if [ "$VENV_VERSION" != "$NIX_VERSION" ]; then
              echo "Removing old .venv (mismatched Python version: $VENV_VERSION != $NIX_VERSION)"
              rm -rf .venv
            fi
          fi

          # 3) Create and activate the venv
          if [ ! -d .venv ]; then
            echo "Creating local venv in .venv..."
            python -m venv .venv
          fi
          source .venv/bin/activate

          # 4) Create a .pth file in the venv site-packages that points to the Nix site-packages
          #    That way, the venv python can import them.
          VENV_SITE_DIR=$(python -c 'import site; print(site.getsitepackages()[0])')
          PTH_FILE="$VENV_SITE_DIR/nix_packages.pth"

          echo "Creating $PTH_FILE with references to the Nix store packages..."

          # Overwrite if existing
          rm -f "$PTH_FILE"
          # Add each path from $NIX_SITE_PACKS
          OLD_IFS="$IFS"
          IFS=":"
          for p in $NIX_SITE_PACKS; do
            echo "$p" >> "$PTH_FILE"
          done
          IFS="$OLD_IFS"

          # 5) (Optional) install PyPI packages if needed
          if ! python -c "import torch" 2>/dev/null; then
            echo "Installing PyTorch from PyPI..."
            pip install --upgrade pip
            pip install torch torchvision torchaudio
          fi

          echo "Venv Python: $(which python)"
          echo "Venv Python version: $(python --version)"
          echo "Done setting up the environment."
        '';
      };
    }
  );
}


# {
#   description = "Python project with a local venv that inherits Nix packages";

#   inputs = {
#     nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
#     flake-utils.url = "github:numtide/flake-utils";
#   };

#   outputs = { self, nixpkgs, flake-utils }:
#     flake-utils.lib.eachDefaultSystem (system:
#     let
#       myOverlay = final: prev: {
#         python3_12 = prev.python312.override {
#           packageOverrides = pySelf: pySuper: {
#             # If you need custom overrides, do them here...
#           };
#         };
#         # Alias "python3" → python3_12
#         python3 = final.python3_12;
#       };

#       pkgs = import nixpkgs {
#         inherit system;
#         overlays = [ myOverlay ];
#       };
#     in
#     {
#       devShells.default = pkgs.mkShell {
#         packages = [
#           (pkgs.python3.withPackages (p: [
#             # Nix-provided packages
#             p.onvif-zeep
#             p.opencv-python
#             # Omit torch from here if you want the PyPI version
#           ]))
#         ];

#         shellHook = ''
#           echo "System python (Nix) path: $(which python)"
#           echo "System python (Nix) version: $(python --version)"

#           # Remove existing .venv if it's for a different Python version
#           # (Optional safety step)
#           if [ -d .venv ]; then
#             venv_python_version=$(.venv/bin/python -c "import sys; print(sys.version_info[:2])" 2>/dev/null || echo "none")
#             nix_python_version=$(python -c "import sys; print(sys.version_info[:2])")
#             if [ "$venv_python_version" != "$nix_python_version" ]; then
#               echo "Removing old .venv (Python $venv_python_version != Nix $nix_python_version)..."
#               rm -rf .venv
#             fi
#           fi

#           # Create .venv if needed, INHERITING system site-packages
#           if [ ! -d .venv ]; then
#             echo "Creating .venv with --system-site-packages..."
#             $(which python) -m venv .venv --system-site-packages
#           fi

#           # Activate the venv
#           source .venv/bin/activate

#           # Now we can see Nix-installed packages (cv2, onvif-zeep, etc.)
#           # AND we can pip-install anything extra:
#           if ! python -c "import torch" 2>/dev/null; then
#             echo "Installing PyTorch from PyPI..."
#             pip install --upgrade pip
#             pip install torch torchvision torchaudio transformers
#           fi

#           echo "Activated venv python: $(which python)"
#           echo "Activated venv python version: $(python --version)"
#         '';
#       };
#     }
#   );
# }

#   # {
# #   description = "Python project with an overlay for moderngl and auto-activated venv for PyTorch";

# #   inputs = {
# #     nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
# #     flake-utils.url = "github:numtide/flake-utils";
# #   };

# #   outputs = { self, nixpkgs, flake-utils }:
# #     flake-utils.lib.eachDefaultSystem (system:
# #     let
# #       # Overlay that adjusts python3_12 (if you have custom overrides)
# #       myOverlay = final: prev: {
# #         python3_12 = prev.python312.override {
# #           packageOverrides = pySelf: pySuper: {
# #             # Example only: override or define custom packages
# #             # moderngl = ...
# #           };
# #         };

# #         # Alias python3 -> python3_12 for convenience
# #         python3 = final.python3_12;
# #       };

# #       pkgs = import nixpkgs {
# #         inherit system;
# #         overlays = [ myOverlay ];
# #       };
# #     in {
# #       devShells.default = pkgs.mkShell {
# #         name = "my-devshell";

# #         # Provide a base Python + some packages from Nix
# #         packages = [
# #           (pkgs.python3.withPackages (p: [
# #             p.onvif-zeep
# #             p.opencv-python   # if you want OpenCV from Nix
# #             p.transformers
# #             # Omit p.torch, p.torchvision, p.torchaudio, p.accelerate
# #             # so they don't conflict with the PyPI versions in the .venv
# #           ]))
# #         ];

# #         shellHook = ''
# #           echo "Using system Python from Nix: $(which python)"
# #           echo "Python version: $(python --version)"

# #           # 1) Create a local .venv if it doesn't exist
# #           if [ ! -d .venv ]; then
# #             echo "Creating local virtual environment in .venv..."
# #             python -m venv .venv
# #           fi

# #           # 2) Activate the venv
# #           source .venv/bin/activate

# #           # 3) Install PyTorch packages from PyPI if they're not already in the venv
# #           if ! python -c "import torch" 2>/dev/null; then
# #             echo "Installing PyTorch & friends from PyPI into .venv..."
# #             pip install --upgrade pip
# #             pip install torch torchvision torchaudio accelerate opencv-python
# #           fi

# #           echo "Virtualenv is now active. Python: $(which python)"
# #         '';
# #       };
# #     }
# #   );
# # }
