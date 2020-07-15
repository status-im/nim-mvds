mode = ScriptMode.Verbose

version     = "0.1.0"
author      = "Status Research & Development GmbH"
description = "Implementation of the Minimum Viable Data Sync protocol."
license     = "MIT"
skipDirs    = @["tests"]

requires "nim >= 1.2.0",
         "stew",
         "nimcrypto",
         "https://github.com/status-im/nim-protobuf-serialization"

task test, "Run all tests":
  exec "nim c -d:MVDS_TESTS -r tests/test_all"
