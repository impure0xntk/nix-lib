{ pkgs, lib }:

let
  utils = import ../lib/utility/default.nix { inherit pkgs lib; };

  # genSshKeyPair tests
  sshKeyPair = utils.genSshKeyPair { name = "test_key"; };

  # removeDesktopIcon tests
  testPkg = pkgs.writeTextFile {
    name = "test-desktop";
    destination = "/share/applications/test.desktop";
    text = "[Desktop Entry]\nType=Application\n";
  };
  removedIcon = utils.removeDesktopIcon { package = testPkg; desktopFileName = "test.desktop"; };

  # genJavaOpts tests
  javaOpts = utils.genJavaOpts { foo = "bar"; baz = "qux"; };

  # formatEnvLines tests
  envVars = ''
    FOO=bar
    BAZ=qux
    # Comment
    INVALID_LINE
  '';
  bashFormatted = utils.formatEnvLines { raw = envVars; format = "bash"; };
  fishFormatted = utils.formatEnvLines { raw = envVars; format = "fish"; };

  # removeAllDesktopIcons tests
  testPkgWithMultipleIcons = pkgs.runCommand "test-desktop-multiple" {
    passAsFile = ["desktopFiles"];
    desktopFiles = ''
      [Desktop Entry]
      Type=Application
      Name=Test1

      [Desktop Entry]
      Type=Application
      Name=Test2
    '';
  } ''
    mkdir -p $out/share/applications
    echo "$desktopFilesPath" > $out/share/applications/test1.desktop
    echo "$desktopFilesPath" > $out/share/applications/test2.desktop
  '';
  removedAllIcons = utils.removeAllDesktopIcons { package = testPkgWithMultipleIcons; };

  # genJavaProxyOptsAttr tests
  validProxyOpts = utils.genJavaProxyOptsAttr "proxy.example.com:8080" ["localhost" "127.0.0.1"];
  invalidProxyOpts = builtins.tryEval (utils.genJavaProxyOptsAttr "http://proxy.example.com:8080" []);

  # deepMerge tests
  deepMerge1 = utils.deepMerge
    { a = 1; b = { c = 2; d = 3; }; e = [1 2]; }
    { a = 10; b = { d = 30; f = 4; }; e = [3 4]; };
  deepMerge2 = utils.deepMerge
    { a = { b = 1; }; }
    { a = { c = 2; }; };
  deepMerge3 = utils.deepMerge
    { a = [1 2]; }
    { a = [3 4]; };

in pkgs.runCommand "utility-tests" {
  passed = builtins.concatStringsSep "\n" ([
    "genSshKeyPair tests passed"
    "removeDesktopIcon tests passed"
    "genJavaOpts tests passed"
    "formatEnvLines tests passed"
    "removeAllDesktopIcons tests passed"
    "genJavaProxyOptsAttr tests passed"
    "deepMerge tests passed"
  ]);
} ''
  # Assert all tests
  ${lib.concatStringsSep "\n" ([
    (assert lib.pathExists sshKeyPair.pubKey; "")
    (assert lib.pathExists sshKeyPair.priKey; "")
    (assert lib.hasSuffix "test_key.pub" sshKeyPair.pubKey; "")
    (assert lib.hasSuffix "test_key" sshKeyPair.priKey; "")
    (assert lib.pathExists "${removedIcon}/share/applications/test.desktop"; "")
    (assert builtins.match ".*Hidden=1.*" (builtins.readFile "${removedIcon}/share/applications/test.desktop") != null; "")
    (assert javaOpts == "-Dbaz=qux -Dfoo=bar"; "")
    (assert builtins.match ".*export FOO=bar.*" bashFormatted != null; "")
    (assert builtins.match ".*export BAZ=qux.*" bashFormatted != null; "")
    (assert builtins.match ".*set -gx FOO bar.*" fishFormatted != null; "")
    (assert builtins.match ".*set -gx BAZ qux.*" fishFormatted != null; "")
    (assert builtins.match ".*# INVALID: INVALID_LINE.*" bashFormatted != null; "")
    (assert lib.pathExists "${removedAllIcons}/share/applications/test1.desktop"; "")
    (assert lib.pathExists "${removedAllIcons}/share/applications/test2.desktop"; "")
    (assert builtins.match ".*Hidden=1.*" (builtins.readFile "${removedAllIcons}/share/applications/test1.desktop") != null; "")
    (assert builtins.match ".*Hidden=1.*" (builtins.readFile "${removedAllIcons}/share/applications/test2.desktop") != null; "")
    (assert validProxyOpts."http.proxyHost" == "proxy.example.com"; "")
    (assert validProxyOpts."http.proxyPort" == "8080"; "")
    (assert validProxyOpts."http.nonProxyHosts" == "localhost|127.0.0.1"; "")
    (assert validProxyOpts."https.proxyHost" == "proxy.example.com"; "")
    (assert validProxyOpts."https.proxyPort" == "8080"; "")
    (assert validProxyOpts."https.nonProxyHosts" == "localhost|127.0.0.1"; "")
    (assert !invalidProxyOpts.success; "")
    (assert deepMerge1.a == 10; "")
    (assert deepMerge1.b.c == 2; "")
    (assert deepMerge1.b.d == 30; "")
    (assert deepMerge1.b.f == 4; "")
    (assert deepMerge1.e == [1 2 3 4]; "")
    (assert deepMerge2.a.b == 1; "")
    (assert deepMerge2.a.c == 2; "")
    (assert deepMerge3.a == [1 2 3 4]; "")
  ])}
    echo "$passed" >&2
    touch $out
  ''
