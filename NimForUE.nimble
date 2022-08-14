# Package

version       = "0.1.0"
author        = "jmgomez"
description   = "A plugin for UnrealEngine 5"
license       = "MIT"
srcDir        = "src"

# Dependencies
requires "nim >= 1.6.4"

backend = "cpp"
#bin = @["nue"]

task nue, "Build the NimForUE tool":
  exec "nim c src/nue.nim" # see src/nue.nims for conf

#[
template callTask(name: untyped) =
    ## Invokes the nimble task with the given name
    exec "nimble " & astToStr(name)

#[
task nimforue, "Builds the main lib. The one that makes sense to hot reload.":
    generateFFIGenFile()
    exec("nim cpp --app:lib --warning:UnusedImport:off --warning:HoleEnumConv:off --warning:Spacing:off --hint:XDeclaredButNotUsed:off --nomain -d:withue -d:genffi --nimcache:.nimcache/nimforue src/nimforue.nim")
    exec("nim c -d:release --warning:UnusedImport:off --run --d:copylib src/buildscripts/copyLib.nim")
]#

task watch, "Watchs the main lib and rebuilds it when something changes.":
    when defined macosx:
        exec("""echo nimble nimforue > nueMac.sh""")
    exec("./nue watch") # use nimble to call the watcher. Typically the user will call `nue watch` since nue will be installed in `.nimble/bin`.


#task buildlibs, "Builds the sdk and the ffi which generates the headers":
#    callTask nimforue


task clean, "deletes all files generated by the project":
    exec("rm -rf ./Binaries/nim/")
    exec("rm /usr/local/lib/libhostnimforue.dylib")
    exec("rm NimForUE.mac.json")

]#