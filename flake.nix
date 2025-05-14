{
  # Basic information about this flake
  description = "Parakeet ASR - A high-performance Automatic Speech Recognition (ASR) server built with NVIDIA's NeMo Parakeet model. This application provides both REST API and WebSocket interfaces for transcribing audio files to text.";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable"; # Use the unstable branch of nixpkgs
  };

  outputs = { self, nixpkgs }: 
    let
      # Define variables used throughout the flake
      system = "x86_64-linux"; # Target system architecture
      pkgs = nixpkgs.legacyPackages.${system}; # Load packages for our target system
      
    in {
      # Define the packages this flake produces
      # packages.${system} = {
      # };
      
      # Define development environments
      devShells.${system}.default = pkgs.mkShell {

        buildInputs = [
          pkgs.python312
          pkgs.uv
          pkgs.gcc
          pkgs.cmake
        ];
        # No special shell setup needed
      };
    };
}