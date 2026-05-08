{
  description = "Nix derivations for credential-provider and otel-helper from claude-code-with-bedrock";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
        python = pkgs.python312;
        py = python.pkgs;

        # Pull version from source/pyproject.toml so the derivation tracks upstream tags.
        # Anchors to a line that starts exactly with `version = "..."` (preceded by newline)
        # so we skip ruff's `target-version` and any nested `[tool.X.version]` attrs.
        version = let
          pyproject = builtins.readFile ./source/pyproject.toml;
          match = builtins.match ".*\nversion = \"([^\"]+)\".*" pyproject;
        in if match == null then "0.0.0" else builtins.elemAt match 0;

        # credential-provider: OIDC + Cognito federation binary.
        # Deps confirmed by reading source/credential_provider/__main__.py imports.
        credential-provider = py.buildPythonApplication {
          pname = "credential-provider";
          inherit version;
          pyproject = false;
          src = ./source;

          propagatedBuildInputs = with py; [
            boto3
            botocore
            pyjwt
            keyring
            cryptography
            requests
          ];

          dontUnpack = false;
          installPhase = ''
            runHook preInstall

            mkdir -p $out/${python.sitePackages}
            cp -r credential_provider $out/${python.sitePackages}/

            mkdir -p $out/bin
            cat > $out/bin/credential-provider <<EOF
            #!${python.interpreter}
            import sys
            from credential_provider import main
            sys.exit(main())
            EOF
            chmod +x $out/bin/credential-provider

            # Alias under the name AWS install.sh expects.
            ln -s credential-provider $out/bin/credential-process

            runHook postInstall
          '';

          meta = with pkgs.lib; {
            description = "AWS Credential Provider for OIDC + Cognito Identity Pool federation";
            homepage = "https://github.com/WilldanGroup/claude-code-with-aws-bedrock";
            license = licenses.mit;
            mainProgram = "credential-provider";
          };
        };

        # otel-helper-bin: Python entry that extracts OTEL headers from JWT or AWS caller identity.
        # Deps confirmed by reading source/otel_helper/__main__.py imports — stdlib + boto3 fallback.
        otel-helper-bin = py.buildPythonApplication {
          pname = "otel-helper-bin";
          inherit version;
          pyproject = false;
          src = ./source;

          propagatedBuildInputs = with py; [
            boto3
            botocore
            pyjwt
            requests
          ];

          dontUnpack = false;
          installPhase = ''
            runHook preInstall

            mkdir -p $out/${python.sitePackages}
            cp -r otel_helper $out/${python.sitePackages}/

            mkdir -p $out/bin
            cat > $out/bin/otel-helper-bin <<EOF
            #!${python.interpreter}
            import sys
            from otel_helper.__main__ import main
            sys.exit(main())
            EOF
            chmod +x $out/bin/otel-helper-bin

            runHook postInstall
          '';

          meta = with pkgs.lib; {
            description = "OTEL headers helper that extracts user attribution from auth tokens";
            homepage = "https://github.com/WilldanGroup/claude-code-with-aws-bedrock";
            license = licenses.mit;
            mainProgram = "otel-helper-bin";
          };
        };

        # otel-helper: ships the fast-path shell wrapper from source/ next to otel-helper-bin.
        # The shell script bypasses Python startup on cache hit, falls through to otel-helper-bin
        # on miss. Replicates the layout produced by upstream's PyInstaller flow.
        otel-helper = pkgs.runCommand "otel-helper" { } ''
          mkdir -p $out/bin
          install -m 0755 ${./source/otel_helper/otel-helper.sh} $out/bin/otel-helper
          ln -s ${otel-helper-bin}/bin/otel-helper-bin $out/bin/otel-helper-bin
        '';

        # Combined output: lays out both binaries so the directory matches what
        # ~/claude-code-with-bedrock/ expects (credential-process, otel-helper, otel-helper-bin).
        bedrock-helpers = pkgs.symlinkJoin {
          name = "claude-code-bedrock-helpers-${version}";
          paths = [ credential-provider otel-helper ];
        };
      in
      {
        packages = {
          inherit credential-provider otel-helper otel-helper-bin;
          claude-code-bedrock-helpers = bedrock-helpers;
          default = bedrock-helpers;
        };

        apps = {
          credential-provider = {
            type = "app";
            program = "${credential-provider}/bin/credential-provider";
          };
          otel-helper = {
            type = "app";
            program = "${otel-helper}/bin/otel-helper";
          };
        };

        devShells.default = pkgs.mkShell {
          buildInputs = [
            python
            pkgs.poetry
          ];
          shellHook = ''
            echo "Run 'cd source && poetry install' to set up the dev env."
            echo "Run 'nix build .#credential-provider' or 'nix build .#otel-helper' to build binaries."
          '';
        };
      });
}
