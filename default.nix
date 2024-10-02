{ pkgs ? import <nixpkgs> {} }:

let 
  swift = pkgs.swift;
in 
  pkgs.stdenv.mkDerivation {
    name = "pixivloader";

    src = ./.;

    buildInputs = [ swift ];

    buildPhase = ''
      swift build -c release
    ''; 

    checkPhase = ''
      swift test
    '';

    installPhase = ''
      mkdir -p $out/bin
      cp .build/release/pixivloader $out/bin
    '';
  }  