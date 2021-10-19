{
  description = "nss-dev nix flake for firefox nightly.";

  inputs = {
    nss-dev-src = {
      # https://kuix.de/mozilla/versions/ NSS: NSS_3_71_RTM
      # https://github.com/mozilla/gecko-dev/blob/master/security/nss/TAG-INFO
      # https://hg.mozilla.org/projects/nss/json-rev/de3db3a55aef
      url = github:nss-dev/nss/cea7654c90aaed1d1e29f735ce765974c08898df;
      flake = false;
    };
    nixpkgs.url = github:nixos/nixpkgs/nixos-unstable;
  };

  outputs = { self, nixpkgs, nss-dev-src }:
    let
      nss_version = "3.72-beta";
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
          src = nss-dev-src;
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
                --replace "\''${DIST}/\''${OBJDIR}/bin" "${final.nss-dev.tools}/bin"
            done

            for file in $(grep -r --files-with-matches "\''${DIST}/\''${OBJDIR}/lib" $out)
            do
              substituteInPlace "$file" \
                --replace "\''${DIST}/\''${OBJDIR}/lib" "${final.nss-dev}/lib"
            done
          '';
        };

        nss-dev = prev.nss.overrideAttrs (old: {
          version = nss_version;
          src = nss-dev-src;
          postUnpack = ''
            mkdir nss-${nss_version}
            mv $sourceRoot nss-${nss_version}/nss
            sourceRoot=nss-${nss_version}
          '';
        });
      };
    };
}
