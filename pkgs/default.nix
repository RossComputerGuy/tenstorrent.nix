{
  lib,
  newScope,
}:
lib.makeScope newScope (self: with self; {
  metal = callPackage ./metal { };
  logger = callPackage ./logger { };
})
