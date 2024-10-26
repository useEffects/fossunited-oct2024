---
author: Joel Samuel
date: 26 Oct 2024 
---
# Nix: New Way to Create Reproducible Builds

```
Joel Samuel
https://joelsamuel.me
FOSS United Oct 2024, Tiger Analytics, Chennai.
```

---
# What goes wrong in software development?
- Incomplete dependencies (DLL hell, runtime linker)
- Implicit assumptions about filesystem layout (eg: `/user/bin/bash`)
- Inexact dependency specification (mismatched versions, different compilers)
- Not possible to mix and match versions of a dependncy
- Build from source or download binary, but not both
- Creating new components might be difficult

---
Imperative package management can complicate setting up environments with specific dependencies like CUDA because each installation must be handled *manually*. 

# Release Compatibility Matrix of pytorch
source: https://github.com/pytorch/pytorch/blob/9656a603b24ba1e3cdeae8839ef18f6364c458f5/RELEASE.md#release-compatibility-matrix

| PyTorch version | Python                   | C++   | Stable CUDA                                         | Experimental CUDA                   | Stable ROCm |
|-----------------|--------------------------|-------|-----------------------------------------------------|-------------------------------------|-------------|
| 2.5             | >=3.9, <=3.12, (3.13 experimental) | C++17 | CUDA 11.8, CUDA 12.1, CUDA 12.4, CUDNN 9.1.0.70    | None                                | ROCm 6.2    |
| 2.4             | >=3.8, <=3.12            | C++17 | CUDA 11.8, CUDA 12.1, CUDNN 9.1.0.70                | CUDA 12.4, CUDNN 9.1.0.70           | ROCm 6.1    |
| 2.3             | >=3.8, <=3.11, (3.12 experimental) | C++17 | CUDA 11.8, CUDNN 8.7.0.84                          | CUDA 12.1, CUDNN 8.9.2.26           | ROCm 6.0    |
| 2.2             | >=3.8, <=3.11, (3.12 experimental) | C++17 | CUDA 11.8, CUDNN 8.7.0.84                          | CUDA 12.1, CUDNN 8.9.2.26           | ROCm 5.7    |
| 2.1             | >=3.8, <=3.11            | C++17 | CUDA 11.8, CUDNN 8.7.0.84                          | CUDA 12.1, CUDNN 8.9.2.26           | ROCm 5.6    |
| 2.0             | >=3.8, <=3.11            | C++14 | CUDA 11.7, CUDNN 8.5.0.96                          | CUDA 11.8, CUDNN 8.7.0.84           | ROCm 5.4    |
| 1.13            | >=3.7, <=3.10            | C++14 | CUDA 11.6, CUDNN 8.3.2.44                          | CUDA 11.7, CUDNN 8.5.0.96           | ROCm 5.2    |
| 1.12            | >=3.7, <=3.10            | C++14 | CUDA 11.3, CUDNN 8.3.2.44                          | CUDA 11.6, CUDNN 8.3.2.44           | ROCm 5.0    |

---
# CUDA setup with nix instead


```nix
# configuration.nix
# NixOS specific config to run `nvidia-smi` without issues.

nix.settings = {
  substituters = [
    "https://cuda-maintainers.cachix.org"
  ];
  trusted-public-keys = [
    "cuda-maintainers.cachix.org-1:0dq3bujKpuEPMCX6U4WylrUDZ9JyUG0VpVZa7CNfq5E="
  ];
  experimental-features = [ "nix-command" "flakes" ];
};
services.xserver.videoDrivers = [ "nvidia" ];
hardware.nvidia = {
  modesetting.enable = true;
  open = false;
  nvidiaSettings = true;
  package = config.boot.kernelPackages.nvidiaPackages.stable;
};
```

---
## continuation

```nix
# shell.nix
{ pkgs ? import <nixpkgs> {
  config = {
    allowUnfree = true;
    cudaSupport = true;
  };
} }:

pkgs.mkShell {
  nativeBuildInputs = with pkgs.buildPackages; [
    python311
    python311Packages.pip
    python311Packages.pytorch-bin
    cudaPackages_12.cudatoolkit
    cudaPackages_12.cudnn
  ];

  shellHook = ''
    export CUDA_PATH=${pkgs.cudaPackages_12.cudatoolkit}
    export CUDNN_PATH=${pkgs.cudaPackages_12.cudnn}
  '';
}
```

---
# How does it work?
Conceptual overview:
- A package is a pure function: if the inputs are same, the outputs are the same
- The outputs are always derivations (build instructions) which then get built
- The Nix language is purely functional language whose only *side effect* is producing derivations
- Build results are stored in `/nix/store` with a hash of the derivation that created them.
```bash
realpath $(which node)
```

---
# The magic of Nix
- Since all we build are derivations, *if you refactor your package definition to produce the same derivation, nothing needs to be rebuilt!*
- Since we has derivations in ther Nix store path, *if two paths are the same they, must be the same component*
- Any change (eg: adding patches, changing compilers, glibc, etc.) propagates down the depenency tree -> *never confuse two packages created with different compilers or build flags*
- *Caching*: if a derivation has been built on a remote machine, just download the build result!

---
# Benefits of Nix
- Things either work *everywhere and always* or *nowhere and never*
- Immutabe system
- Instant, atomic rollbacks
- Reproducible development environments
- Runs *natively* on macOS, Linux

---
# Deep dive into Nix and Nix ecosystem
- nixpkgs != nixlang != NixOS
but;
- nixpkgs ~ nix
- nixlang ~ nix
- NixOS   ~ nix

---
# Nix for DevOps, SysAdmins and real usecases in software deployments
- Nix allows you to define your entire environment in a single file, ensuring that every build is reproducible. This is essential for DevOps practices, as it eliminates the "it works on my machine" problem.
- Nix installs each package in its own unique directory in the Nix store (`/nix/store`), avoiding conflicts with other packages.
- Nix can manage multiple versions of dependencies side by side. This is particularly useful when different projects require different versions of the same library, avoiding conflicts.
- Would it replace docker?

---
# Advanced nix concepts 
- Overlays just cause a new pkgs object to be returned and used instead which contains whichever things the overlay adds to it.
```nix
{ self, super }:
let
  # Use a specific version of jq or apply patches if needed.
  customJq = super.jq.overrideAttrs (oldAttrs: {
    version = "1.6"; # Example: using a specific version
    # If you had patches, you could add them here.
    # patches = [ ./my-jq-patch.patch ];
  });
in
{
  jq = customJq;
}
```
- Nix flakes provide a standard way to write Nix expressions (and therefore packages) whose dependencies are version-pinned in a lock file, improving reproducibility of Nix installations.
- NixOps is a tool for deploying NixOS machines in a network or cloud. It takes as input a declarative specification of a set of "logical" machines and then performs any necessary steps or actions to realise that specification: instantiate cloud machines, build and download dependencies, stop and start services.
