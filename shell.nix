{ pkgs ? import <nixpkgs> { config.allowUnfree = true; } }:

(import ./default.nix { inherit pkgs; }).env
