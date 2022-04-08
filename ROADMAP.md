
## InjectionIII Roadmap

This isn't a roadmap of future directions as, in a sense, the project is already "there".
Just a locator for the key files and their role implementing "live code injection" for users.

The InjectionIII project is largely a shell project now containing a lot of interesting code 
that is no longer used. The key sources files are brought in from the [HotReloading](https://github.com/johnno1962/HotReloading) Swift package which
is able to build both the app as a daemon and client iOS project support code 
which is normally packaged as the iOSInjection.bundle in the app releases.
HotReloading in turn brings in [SwiftTrace](https://github.com/johnno1962/SwiftTrace)
which contains most of the infrastructure you need for injection such as the ability
associate a function pointer with a symbol name and de-mangle that into the description
of a Swift type member. It also allows you to scan the symbol table of a newly dlopen'd 
dynamic library image to look for all classes, types and functions it contains that should 
be injected using the symbol suffix.

[HotReloading/AppDelegate.swift](https://github.com/johnno1962/HotReloading/blob/main/Sources/injectiond/AppDelegate.swift): The app delegate of the menu bar application/daemon that chiefly looks after setting up a [FileWatcher.swift](https://github.com/johnno1962/HotReloading/blob/main/Sources/injectiond/FileWatcher.swift) instance
 for the selected project that looks for modifications to source files that should be recompiled 
 and injected. More experimental features such as tracing are in the AppDelegate extension in
 [Experimental.swift](https://github.com/johnno1962/HotReloading/blob/main/Sources/injectiond/Experimental.swift).
 The AppDelegate has to cater for three configurations: The Sandboxed App Store
 releaes of the app, the binary [github releases](https://github.com/johnno1962/InjectionIII/releases)
 and when it is run as a daemon from a "Build Phase" using the HotReloading project.

[HotReloading/InjectionServer.swift](https://github.com/johnno1962/HotReloading/blob/main/Sources/injectiond/InjectionServer.swift): listens
on localhost for sockets connections from client apps and sends them commands to inject 
modified source files when they are saved.

[HotReloading/SwiftEval.swift](https://github.com/johnno1962/HotReloading/blob/main/Sources/HotReloading/SwiftEval.swift): Standalone
source which looks after the recompilation of a source file and linking the resulting object file 
into a dynamic  library that can be loaded. It works out the Swift compiler command to do 
this by "grepping" (using perl) the compressed build logs in the current project's DerivedData. 
An instance of the class runs in the simulator for the Sandboxed version of the app and in the 
main app process for the binary github releases.

[HotReloading/SwiftInjection.swift](https://github.com/johnno1962/HotReloading/blob/main/Sources/HotReloading/SwiftInjection.swift): After
the dynamic library prepared by SwiftEval.swift has been dlopen()'d this file sets about the actual
injection of the new implementations into the client app. It does this three ways. For 
Objective-C methods it "Swizzles" the new implementations on top of the old using
Objective-C runtime apis. For Swift classes it scans class information, the later
part of which is a vtable of member function pointers and "patches" in the new function
pointers. For value types, statics and top level functions it scans the symbol table of the
dynamically loaded image for symbols that are functions (using their distinct suffixes) and 
uses "interposing" (a dynamic linker feature used to bind system symbols) to rebind the 
main application bundle to use the new implementations using a unique piece of C code
called [fishhook](https://github.com/johnno1962/fishhook). In order for this to work an app 
needs to have been linked with the option "-interposable" which makes all function calls to 
global symbols indirect through a patchable pointer as described
[here](https://www.mikeash.com/pyblog/friday-qa-2012-11-09-dyld-dynamic-linking-on-os-x.html).

A new final part of injecting a newly compiled source file is the "reverse interpose" of the
"mutable accessors" for top level and static variables which redirects newly injected code to 
take their value from the main app bundle rather than have them reinitialise with each injection.

[HotReloading/UnhidingEval.swift](https://github.com/johnno1962/HotReloading/blob/main/Sources/HotReloading/UnhidingEval.swift). This was introduced as a means of overriding functionality in SwiftEval.swift without making it
dependant on the rest of the project. Contains a pre-Xcode13 fix for default argument
generators which was preventing some files from being injectable, along with other
fixes to tailor Xcode 13 compilation commands to only compile a single file at a time.

[HotReloading/SwiftSweeper.swift](https://github.com/johnno1962/HotReloading/blob/main/Sources/HotReloading/SwiftSweeper.swift): Implements 
a sweep of an application to search for live instances of classes that have just been injected
to implement the `@objc func injected()` method you can use to refresh a display for
example when say, a view controller is injected.

[HotReloading/InjectionClient.swift](https://github.com/johnno1962/HotReloading/blob/main/Sources/HotReloading/InjectionClient.swift): An
instance of this class connects to the InjectionIII app or daemon and receives commands
to compile/load dynamic libraries and inject them. It also has to delegate to the app
the codesigning of the dynamic library.

[HotReloading/ClientBoot.mm](https://github.com/johnno1962/HotReloading/blob/main/Sources/HotReloadingGuts/ClientBoot.mm): Contains
remaining code that can't be conveniently expressed in Swift in particular a `+load` method
to instantiate an InjectionClient.swift object to connect automatically to the app/daemon.

[HotReloading/SimpleSocket.mm](https://github.com/johnno1962/HotReloading/blob/main/Sources/HotReloadingGuts/SimpleSocket.mm). I
draw the line at trying to do BSD socket programming in Swift so this is my Objective-C
client/server abstraction of which InjectionServer.swift and InjectionClient.swift are subclasses.

[HotReloading/UnHide.mm](https://github.com/johnno1962/HotReloading/blob/main/Sources/HotReloadingGuts/Unhide.mm): The ageing
implementation of the "unhiding" functionality built into the app which is headed for
deprecation since Xcode 13 handles default arguments differently.

[HotReloading/SignerService.mm](https://github.com/johnno1962/HotReloading/blob/main/Sources/injectiondGuts/SignerService.m) An
embarrassingly old piece of code which looks after codesigning the dylib so it can be loaded
in the simulator. For the HotReloading daemon version of InjectionIII run from a build phase
it has access to the build environment variables of the project from which it can take the
signing identity.

[HotReloading/DeviceServer.swift](https://github.com/johnno1962/HotReloading/blob/main/Sources/injectiond/DeviceServer.swift). A
subclass of InjectionServer.swift that runs in the daemon process that supports injection
on a real device. To do this it maintains a pointer to an empty buffer of executable nothing
on the client device from the framework package [InjectionScratch](https://github.com/johnno1962/InjectionScratch) 
into which the dylib can be written (while debugging) rather than dynamically loaded and 
then made executable after simulating as much as is possible of the tasks of an actual 
dynamic load/linking. After this, it is "injected" into the app in the way described above.

[HotReloading/StandaloneInjection.swift](https://github.com/johnno1962/HotReloading/blob/main/Sources/injectiond/StandaloneInjection.swift):
A startover implementation of injection for use in the simulator with the
HotReloading project which removes the need for the App itself.


$Date: 2022/04/09 $
 
