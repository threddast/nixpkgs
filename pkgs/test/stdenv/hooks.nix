{ stdenv, pkgs }:

# ordering should match defaultNativeBuildInputs

{
  move-docs = stdenv.mkDerivation {
    name = "test-move-docs";
    buildCommand = ''
      mkdir -p $out/{man,doc,info}
      touch $out/{man,doc,info}/foo
      cat $out/{man,doc,info}/foo

      _moveToShare

      (cat $out/share/{man,doc,info}/foo 2>/dev/null && echo "man,doc,info were moved") || (echo "man,doc,info were not moved" && exit 1)
    '';
  };
  make-symlinks-relative = stdenv.mkDerivation {
    name = "test-make-symlinks-relative";
    buildCommand = ''
      mkdir -p $out/{bar,baz}
      source1="$out/bar/foo"
      destination1="$out/baz/foo"
      echo foo > $source1
      ln -s $source1 $destination1
      echo "symlink before patching: $(readlink $destination1)"

      _makeSymlinksRelative

      echo "symlink after patching: $(readlink $destination1)"
      ([[ -e $destination1 ]] && echo "symlink isn't broken") || (echo "symlink is broken" && exit 1)
      ([[ $(readlink $destination1) == "../bar/foo" ]] && echo "absolute symlink was made relative") || (echo "symlink was not made relative" && exit 1)
    '';
  };
  compress-man-pages =
    let
      manFile = pkgs.writeText "small-man" ''
        .TH HELLO "1" "May 2022" "hello 2.12.1" "User Commands"
        .SH NAME
        hello - friendly greeting program
      '';
    in
    stdenv.mkDerivation {
      name = "test-compress-man-pages";
      buildCommand = ''
        mkdir -p $out/share/man
        cp ${manFile} $out/share/man/small-man.1
        compressManPages $out
        [[ -e $out/share/man/small-man.1.gz ]]
      '';
    };

  # TODO: add strip
  # TODO: move patch-shebangs test from pkgs/test/patch-shebangs/default.nix to here
  prune-libtool-files =
    let
      libFoo = pkgs.writeText "libFoo" ''
        # Generated by libtool (GNU libtool) 2.4.6
        old_library='''
        dependency_libs=' -Lbar.la -Lbaz.la'
      '';
    in
    stdenv.mkDerivation {
      name = "test-prune-libtool-files";
      buildCommand = ''
        mkdir -p $out/lib
        cp ${libFoo} $out/lib/libFoo.la
        _pruneLibtoolFiles
        grep "^dependency_libs=''' #pruned" $out/lib/libFoo.la
        # confirm file doesn't only contain the above
        grep "^old_library='''" $out/lib/libFoo.la
      '';
    };
  # TODO: add audit-tmpdir
  # TODO: add multiple-outputs
  move-sbin = stdenv.mkDerivation {
    name = "test-move-sbin";
    buildCommand = ''
      mkdir -p $out/sbin
      touch $out/sbin/foo
      cat $out/sbin/foo

      _moveSbin

      # check symlink
      [[ -h $out/sbin ]]
      ([[ -e $out/sbin ]] && echo "symlink isn't broken") || (echo "symlink is broken" && exit 1)
      [[ -e $out/bin/foo ]]
    '';
  };

  move-lib64 = stdenv.mkDerivation {
    name = "test-move-lib64";
    buildCommand = ''
      mkdir -p $out/lib64
      touch $out/lib64/foo
      cat $out/lib64/foo

      _moveLib64

      # check symlink
      [[ -h $out/lib64 ]]
      ([[ -e $out/lib64 ]] && echo "symlink isn't broken") || (echo "symlink is broken" && exit 1)
      [[ -e $out/lib/foo ]]
    '';
  };

  set-source-date-epoch-to-latest = stdenv.mkDerivation {
    name = "test-set-source-date-epoch-to-latest";
    buildCommand = ''
      sourceRoot=$NIX_BUILD_TOP/source
      mkdir -p $sourceRoot
      touch --date=1/1/2015 $sourceRoot/foo

      _updateSourceDateEpochFromSourceRoot

      [[ $SOURCE_DATE_EPOCH == "1420070400" ]]
      touch $out
    '';
  };

  reproducible-builds = stdenv.mkDerivation {
    name = "test-reproducible-builds";
    buildCommand = ''
      # can't be tested more precisely because the value of random-seed changes depending on the output
      [[ $NIX_CFLAGS_COMPILE =~ "-frandom-seed=" ]]
      touch $out
    '';
  };
}
