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

      # Create a base Docker image with common tools
      # This is used as a foundation for other containers to reduce duplication
      baseContainer = pkgs.dockerTools.buildLayeredImage {
        name = "parakeet-asr-base";
        contents = [
          pkgs.bash
          pkgs.coreutils  # For ls, cp, etc.
          pkgs.python312
          pkgs.uv
          pkgs.gcc
          pkgs.glibc
          pkgs.stdenv.cc.cc.lib
          pkgs.cmake
          pkgs.ffmpeg-headless
          pkgs.libsndfile
        ];
        
        extraCommands = ''
          # Create tmp directory with proper permissions
          mkdir -p tmp
          chmod 1777 tmp
        '';
      };
      
      # Development container using UV approach for dynamic package installation
      devContainer = pkgs.dockerTools.buildImage {
        name = "parakeet-asr-dev";
        fromImage = baseContainer;

        extraCommands = ''
          mkdir -p app
          cp -r ${./app}/* app/
        '';
        
        # Container runtime configuration
        config = {
          Cmd = [
            "/bin/bash"
            "-c"
            "cd /app && uv run main.py"
          ];
          WorkingDir = "/app";
          Env = [
            "LD_LIBRARY_PATH=${pkgs.stdenv.cc.cc.lib}/lib:/usr/lib:/lib"
          ];
          ExposedPorts = {
            "8777/tcp" = {};
          };
        };
      };
      
      # Production container - using direct UV sync command
      prodContainer = pkgs.dockerTools.buildImage {
        name = "parakeet-asr-prod";
        fromImage = baseContainer;

        extraCommands = ''
          # Set up directories
          mkdir -p app
          cp -r ${./app}/* app/
          
          # Create a tmp directory for build
          mkdir -p tmp
          chmod -R 777 tmp
        '';
        
        # Container runtime configuration
        config = {
          Cmd = [
            "/bin/bash"
            "-c"
            "cd /app && if [ ! -f .uv-installed ]; then ${pkgs.uv}/bin/uv venv && ${pkgs.uv}/bin/uv sync && touch .uv-installed; fi && .venv/bin/python main.py"
          ];
          WorkingDir = "/app";
          Env = [
            "LD_LIBRARY_PATH=${pkgs.stdenv.cc.cc.lib}/lib:/usr/lib:/lib"
            "UV_CACHE_DIR=/tmp/.uv"
          ];
          ExposedPorts = {
            "8777/tcp" = {};
          };
        };
      };
      
      # Test container with minimal functionality
      testContainer = pkgs.dockerTools.buildImage {
        name = "parakeet-test";
        fromImage = baseContainer;
        
        # Container runtime configuration
        config = {
          Cmd = [
            "/bin/bash"
            "-c"
            "echo 'Hello World'"
          ];
        };
      };
      
    in {
      packages.${system} = {
        default = prodContainer;
        dev = devContainer;
        prod = prodContainer;
        test = testContainer;
      };
      
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