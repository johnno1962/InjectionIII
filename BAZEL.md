### Experimental Bazel build system support.

The [binary GitHub releases](https://github.com/johnno1962/InjectionIII/releases), version 4.5.* or above contain an initial implementation of injecting larger apps which have switched to using the [bazel](https://bazel.build/) build system.

In fact there are two implementations available. The default, more conservative implementation, searches the Xcode build logs for a line starting `Running "` where `bazel` is invoked and calls this command when a source file is modified. It then looks for object files that have been modified by the build and "injects" then in the way the InjectionIII has up until now. To use this version download one of the binary 4.5+ releases of the InjectionIII app, run it and add the following bundle load code somewhere in your app's initialisation:

```
#if DEBUG
Bundle(path: "/Applications/InjectionIII.app/Contents/Resources/iOSInjection.bundle")!.load()
#endif
```
When your app starts a file open panel will appear asking you to select the project's root directory which will be used to start a "file watcher" watching for modifications to Swift source files. In theory, if you have used [tulsi](https://github.com/bazelbuild/tulsi) to create your Xcode project, when you save a file, the InjectionIII app will see the `bazel` invocation in the build logs and use it to recompile the project sources and inject the object files that were updated. Note: it's important to the `--linkopt="-Wl,interposable"` either in your Xcode project's build phase that invokes `bazel` or in the relevant BUILD file.

There is a second less conservative implementation  that you should find injects code modifications more quickly. To use this version, quit the InjectionIII app and restart your app. When you save a file, this version (if it finds a WORKSPACE file in a directory somewhere above the source file changed) will only recompile the module of Swift file modified rather than a do full `bazel` rebuild. It then injects object files modified as before. To do this, this version very slightly patches your `bazel` installation to make a link available in /tmp/bazel_ModuleName.params to preserve the parameters file `bazel` passed directly to `swiftc` to incrementally recompile the module in the last build.

InjectionIII, using the version with or without the app running works best if you don't use "Whole module optimization" otherwise, all object files are regenerated and injection has to resort to heuristics to determine which other objects will be included to cover "shared hidden symbols" resulting in slower iteration times. For more details on the evolution of this feature consult the original [github issue](https://github.com/johnno1962/InjectionIII/issues/388).
