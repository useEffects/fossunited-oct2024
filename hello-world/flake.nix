{ description = "A simple Go application";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs";

  outputs =
    { self, nixpkgs }:
    {
      packages.x86_64-linux.hello-go =
        let
          pkgs = import nixpkgs { system = "x86_64-linux"; };
        in
        pkgs.stdenv.mkDerivation {
          pname = "hello-go";
          version = "1.0";

          src = ./.;

          buildInputs = [ pkgs.go ];

          buildPhase = ''
            export HOME=$(mktemp -d)
            export GOARCH=amd64
            export GOOS=linux
            go build -o hello-go hello-world.go
          '';

          installPhase = ''
            mkdir -p $out/bin
            cp hello-go $out/bin/
          '';
        };

      dockerImage = let
        pkgs = import nixpkgs { system = "x86_64-linux"; };
      in
      pkgs.dockerTools.buildImage {
        name = "hello-go";
        tag = "latest";
        contents = [ self.packages.x86_64-linux.hello-go ];
        config = {
          Cmd = [ "/bin/hello-go" ];
          WorkingDir = "/";
        };
      };
    };
}
