{
  # Basic information about this flake
  description = "Zeitology application containers using UV";

  # External dependencies this flake needs
  # The nixpkgs input provides all the standard Nix packages
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable"; # Use the unstable branch of nixpkgs
  };

  # What this flake produces (packages, development environments, etc.)
  outputs = { self, nixpkgs }: 
    let
      # Define variables used throughout the flake
      system = "x86_64-linux"; # Target system architecture
      pkgs = nixpkgs.legacyPackages.${system}; # Load packages for our target system
      
      # Create a base Docker image with common tools
      # This is used as a foundation for other containers to reduce duplication
      baseContainer = pkgs.dockerTools.buildLayeredImage {
        name = "zeitology-base"; # Name of the container
        contents = [
          # Tools/packages to include in the container
          pkgs.bash       # Shell for running commands
          pkgs.coreutils  # Basic Unix utilities
          pkgs.python312  # Python 3.12 interpreter
          pkgs.uv         # UV package manager
        ];
        # No extraCommands here - we'll add app-specific files in derived images
      };
      
      # App container using UV approach
      appContainer = pkgs.dockerTools.buildLayeredImage {
        name = "zeitology-app";
        fromImage = baseContainer; # Inherit from our base container
        
        # Copy project files into the container during build
        extraCommands = ''
          mkdir -p app
          cp -r ${./src}/* app/       # ${./path} syntax refers to paths relative to this flake.nix file
          cp ${./pyproject.toml} app/pyproject.toml
          cp ${./uv.lock} app/uv.lock
          cp ${./.python-version} app/.python-version
        '';
        
        # Container runtime configuration
        config = {
          # Command to run when the container starts
            # This multi-step command:
            # 1. Changes to the app directory
            # 2. Creates a virtual environment using UV
            # 3. Activates that virtual environment
            # 4. Installs the app in development mode
            # 5. Starts the uvicorn server
          Cmd = [
            "/bin/bash"
            "-c"
            "cd /app && uv venv && . .venv/bin/activate && uv pip install -e . && uvicorn zeitology:app --host 0.0.0.0"
          ];
          WorkingDir = "/app"; # Set the working directory
        };
      };
      
      # Celery worker container - similar to the app container
      celeryContainer = pkgs.dockerTools.buildLayeredImage {
        name = "zeitology-celery";
        fromImage = baseContainer;
        
        # Same file copying as the app container
        extraCommands = ''
          mkdir -p app
          cp -r ${./src}/* app/
          cp ${./pyproject.toml} app/pyproject.toml
          cp ${./uv.lock} app/uv.lock
          cp ${./.python-version} app/.python-version
        '';
        
        config = {
          # Similar to app container, but runs celery instead of uvicorn
          Cmd = [
            "/bin/bash"
            "-c"
            "cd /app && uv venv && . .venv/bin/activate && uv pip install -e . && celery -A zeitology worker --loglevel=info"
          ];
          WorkingDir = "/app";
        };
      };
      
      # Redis container - pulls the official Redis image
      redisContainer = pkgs.dockerTools.buildLayeredImage {
        name = "zeitology-redis";
        # Use an existing Redis image from Docker Hub
        fromImage = pkgs.dockerTools.pullImage {
          imageName = "redis";
          imageDigest = "sha256:a89cb097693dd354de598d279c304a1c73ee550fbfff6685e71c1c4e6a24dc7d";
          sha256 = "1hli5ssf7jkkdn8brvjrgj4a9ai6q8mk5jpp3l5lknpvbv59nmxa"; # Hash that Nix uses to verify the download
        };
        # No additional configuration needed for Redis
      };
      
    in {
      # Define the packages this flake produces
      packages.${system} = {
        default = appContainer; # The default package when using 'nix build'
        app = appContainer;     # Can be built with 'nix build .#app'
        celery = celeryContainer; # Can be built with 'nix build .#celery'
        redis = redisContainer;   # Can be built with 'nix build .#redis'
      };
      
      # Define development environments
      devShells.${system}.default = pkgs.mkShell {
        # Tools available in the development shell
        buildInputs = [
          pkgs.python312
          pkgs.uv
        ];
        # No special shell setup needed
      };
    };
}