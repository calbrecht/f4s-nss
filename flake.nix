{
  description = "Nss nix flake.";

  inputs = {
    nss-dev = {
      # https://kuix.de/mozilla/versions/ NSS: NSS_3_61_RTM
      url = github:nss-dev/nss/70e79341b583ff45a58bf3832d76b6c8782a969b;
      flake = false;
    };
    nixpkgs.url = github:nixos/nixpkgs/nixos-unstable;
  };

  outputs = { self, nixpkgs, nss-dev }:
    let
      nss_version = "3.65";
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages."${system}";
    in
    {
      legacyPackages."${system}" = self.overlay self.legacyPackages."${system}" pkgs;

      overlay = final: prev: {

        nss-testrunner = pkgs.writeScriptBin "nss-testrunner" ''
          #!${prev.stdenv.shell}

          set -e

          tmp_root=$(mktemp -d)
          nss_root=$tmp_root/nss-${nss_version}/nss

          mkdir -p $nss_root
          cp -R ${final.nss-testsuite}/* $nss_root

          find $nss_root -type f -exec chmod u+w \{\} \;
          find $nss_root -type d -exec chmod u+wx \{\} \;

          export BUILT_OPT=1
          export USE_64=1
          export HOST=localhost
          domain=$(${prev.host}/bin/host -t A $HOST | cut -d" " -f1)
          export DOMSUF=''${domain#*.}

          cd $nss_root/tests
          ./all.sh
          exit_value=$?
          rm -fr $tmp_root
          exit $exit_value
        '';

        nss-testsuite = prev.stdenv.mkDerivation {
          name = "nss-testsuite-${nss_version}";
          src = nss-dev;
          dontConfigure = true;
          dontBuild = true;
          installPhase = ''
            mkdir -p $out/cmd/{bltest,pk11gcmtest}

            mv {tests,gtests,coreconf} $out
            mv cmd/bltest/tests $out/cmd/bltest
            mv cmd/pk11gcmtest/tests $out/cmd/pk11gcmtest

            for file in $(grep -r --files-with-matches "\''${DIST}/\''${OBJDIR}/bin" $out)
            do
              substituteInPlace "$file" \
                --replace "\''${DIST}/\''${OBJDIR}/bin" "${final.nss.tools}/bin"
            done

            for file in $(grep -r --files-with-matches "\''${DIST}/\''${OBJDIR}/lib" $out)
            do
              substituteInPlace "$file" \
                --replace "\''${DIST}/\''${OBJDIR}/lib" "${final.nss}/lib"
            done
          '';
        };

        nss = prev.nss.overrideAttrs (old: {
          version = nss_version;
          src = nss-dev;
          postUnpack = ''
            mkdir nss-${nss_version}
            mv $sourceRoot nss-${nss_version}/nss
            sourceRoot=nss-${nss_version}
          '';
        });
      };
    };
}
