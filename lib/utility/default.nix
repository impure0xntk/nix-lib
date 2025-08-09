{ pkgs
, lib,
...
}:
{
  # To get self path from passthru, use overrideAttrs: https://discourse.nixos.org/t/out-in-passthru/23241/3
  genSshKeyPair = { name ? "id_ed25519", ...}:
    pkgs.stdenv.mkDerivation (final: {
      name = "ssh-keypair-${name}";
      nativeBuildInputs = [pkgs.openssh];
      phases = ["installPhase"];
      installPhase = ''
        mkdir $out
        ssh-keygen -q -t ed25519 -N "" -f $out/${name}
      '';
      passthru = {
        pubKey = final.finalPackage.out + "/${name}.pub";
        priKey = final.finalPackage.out + "/${name}";
        priKeyName = name;
      };
    });

  # By ai
  removeShebang = content:
    let
      lines = lib.splitString "\n" content;
      first = lib.head lines;
      rest  = lib.concatStringsSep "\n" (lib.tail lines);
    in if lib.hasPrefix "#!" first then lib.trimWith { start = true; } rest else content;

  # https://discourse.nixos.org/t/make-neovim-wrapper-desktop-optional/37597/3
  removeDesktopIcon = { package, desktopFileName ? "${package.name}.desktop" }: (lib.hiPrio (pkgs.runCommand "${package.name}.desktop-hide" { } ''
    mkdir -p "$out/share/applications"
    cat "${package}/share/applications/${desktopFileName}" > "$out/share/applications/${desktopFileName}"
    echo "Hidden=1" >> "$out/share/applications/${desktopFileName}"
  ''));
  removeAllDesktopIcons = { package }: (lib.hiPrio (pkgs.runCommand "${package.name}.desktop-hide" { } ''
    mkdir -p "$out/share"
    cp -r "${package}/share/applications" "$out/share/applications"
    chmod -R +w "$out/share/applications"
    for file in $out/share/applications/*; do
      echo "Hidden=1" >> "$file"
    done
  ''));

  # Java
  genJavaOpts = attrs:
    let
      javaOpts = lib.mapAttrsToList (n: v: ''-D${n}=${v}'') attrs;
    in lib.concatStringsSep " " javaOpts;
  genJavaProxyOptsAttr = proxyWithoutSchema: noProxyHosts:
    let
      proxyInfos = lib.splitString ":" proxyWithoutSchema;
      proxyHost = lib.head proxyInfos;
      proxyPort = lib.last proxyInfos;
      noProxyHostsStr = lib.concatStringsSep "|" noProxyHosts;
    in
    assert lib.assertMsg
      (builtins.length (lib.strings.splitString "://" proxyWithoutSchema) > 0)
      "proxyWithoutSchema must not have :// .";
    {
      "http.proxyHost" = proxyHost;
      "http.proxyPort" = proxyPort;
      "http.nonProxyHosts" = noProxyHostsStr;
      "https.proxyHost" = proxyHost;
      "https.proxyPort" = proxyPort;
      "https.nonProxyHosts" = noProxyHostsStr;
    };

  # url = http://example.com:8080
  # ->
  # {
  #   schemaAndHost = "http://example.com";
  #   port = "8080";
  # }
  separateHostAndPort = url:
  let
    # Define the separator between scheme and host
    schemeSep = "://";
    schemeSepLen = lib.strings.stringLength schemeSep;
    # Find the index where the scheme ends
    schemeIndex = lib.strings.stringLength (lib.strings.head (lib.strings.splitString schemeSep url));
    # Total length of the scheme including "://"
    baseIndex = schemeIndex + schemeSepLen;
    # Remaining part of the URL after the scheme (host:port)
    rest = lib.strings.substring baseIndex (lib.strings.stringLength url - baseIndex) url;
    # Find all indices where ":" appears in the rest
    colonIndices = lib.lists.filter (i: lib.strings.hasPrefix ":" (lib.strings.substring i 1 rest))
                    (lib.lists.range 0 (lib.strings.stringLength rest - 1));
    # Assume the last ":" in rest separates host and port
    splitPos = lib.lists.last colonIndices;
    # Extract scheme + host part (up to but not including port)
    schemaAndHost = lib.strings.substring 0 (baseIndex + splitPos) url;
    # Extract port part (after the last colon)
    port = lib.strings.substring (splitPos + 1) (lib.strings.stringLength rest - splitPos - 1) rest;
  in {
    inherit schemaAndHost port;
  };

  # Dotenv lines to bash/fish envrc(source command callable) format
  formatEnvLines = {
    raw,
    format ? "bash" # or fish
  }:
    let
      lines = lib.splitString "\n" raw;

      toFormattedLine = line:
        let
          trimmed = lib.strings.trim line;
        in
          if trimmed == "" then
            ""
          else if lib.hasPrefix "#" trimmed then
            trimmed
          else
            let
              parts = lib.splitString "=" trimmed;
            in
              if builtins.length parts != 2 then
                "# INVALID: ${trimmed}"
              else
                let
                  key = lib.elemAt parts 0;
                  value = lib.elemAt parts 1;
                in
                  # Add other format.
                  if format == "fish" then
                    "set -gx ${key} ${value}"
                  else
                    "export ${key}=${value}";
    in
      lib.concatStringsSep "\n" (map toFormattedLine lines);

  # https://discourse.nixos.org/t/nix-function-to-merge-attributes-records-recursively-and-concatenate-arrays/2030/9
  deepMerge = lhs: rhs:
    lhs // rhs
    // (builtins.mapAttrs (
      rName: rValue:
      let
        lValue = lhs.${rName} or null;
      in
      if builtins.isAttrs lValue && builtins.isAttrs rValue then
        lib.my.deepMerge lValue rValue
      else if builtins.isList lValue && builtins.isList rValue then
        lValue ++ rValue
      else
        rValue
    ) rhs);
}

