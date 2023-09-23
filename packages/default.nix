{ pkgs, library }:

{
  uninix-cli = library.callPackage ./uninix { };
}
