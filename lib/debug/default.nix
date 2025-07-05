{ lib, ... }:
{
  /*
    traceValSeqWith: Helper to trace each element in a sequence with a custom label.

    Arguments:
      • label: Prefix string for each trace line
      • seq:   Sequence to inspect (e.g., list of attribute sets)

    Internally uses lib.traceValSeqFn, converting each element to JSON and
    prepending "file:line label ->" based on unsafeGetAttrPos.

    { lib, ... }:
    rec {
      traceValSeqWith = label: seq:
        lib.traceValSeqFn (v:
          let
            pos = builtins.unsafeGetAttrPos "traceValSeqWith" ({}: seq);
          in
            "${pos.file}:${toString pos.line} ${label} -> " + builtins.toJSON v
        ) seq;
    }

    Example:
    let
      pkgs = import <nixpkgs> {};
      mySeq = [ { foo = "bar"; } { baz = 123; } ];
    in
      pkgs.callPackage ./traceValSeqWith.nix {} traceValSeqWith "ITEM" mySeq

    # Output:
    # traceValSeqWith.nix:12 ITEM -> {"foo":"bar"}
    # traceValSeqWith.nix:12 ITEM -> {"baz":123}
  */

  traceSeqWith = label: seq: lib.traceValSeqFn (v: "${label} -> " + builtins.toJSON v) seq;

/*   traceValSeqWith = label: seq:
    lib.traceValSeqFn (v:
      let
        pos = builtins.unsafeGetAttrPos "_dummy" (seq // {_dummy = "";});
      in
        "${pos.file}:${toString pos.line} ${label} -> " + builtins.toJSON v
    ) seq; */
}
