# InjectionIII.app Project

## Yes, HotReloading for Swift 

Chinese language README:  [中文集成指南](https://github.com/johnno1962/InjectionIII/blob/main/README_Chinese.md)

![Icon](http://johnholdsworth.com/Syringe_128.png)

Code injection allows you to update the implementation of functions and any method of a class, struct or enum incrementally in the iOS simulator
without having to perform a full rebuild or restart your application. This saves the developer a significant amount of time tweaking code or iterating over a design. Effectively it changes Xcode from being a
"source editor" to being a _"program editor"_ where source changes are 
not just saved to disk but into your running program directly.

### How to use it

Setting up your projects to use injection is now as simple as
downloading one of the [github releases](https://github.com/johnno1962/InjectionIII/releases) of the app or from the [Mac App Store](https://itunes.apple.com/app/injectioniii/id1380446739?mt=12) and adding 
the code below somewhere in your app to be executed on startup (it
is no longer necessary to actually run the app itself). It's also
important to add "-Xlinker -interposable" (without the double quotes) 
to the "Other Linker Flags" of all targets in your project for 
the `Debug` configuration only to enable "interposing" (see below).

```Swift
#if DEBUG
Bundle(path: "/Applications/InjectionIII.app/Contents/Resources/iOSInjection.bundle")?.load()
//for tvOS:
Bundle(path: "/Applications/InjectionIII.app/Contents/Resources/tvOSInjection.bundle")?.load()
//Or for macOS:
Bundle(path: "/Applications/InjectionIII.app/Contents/Resources/macOSInjection.bundle")?.load()
#endif
```
After that, when you run your app in the simulator you should see a 
message saying a file watcher has started for your home directory. 
Whenever you save a source file in the current project it should 
report it has been injected. This means all places that formerly 
called the old implementation will have been updated to call your 
latest version of your code.

It's not quite as simple as that to see results on the screen
immediately as the new code needs to have actually been called.
For example, if you inject a view controller it needs to force a
redisplay. To resolve this problem, classes can implement an 
`@objc func injected()` method which will be called after the 
class has been injected to perform any update to the display. 
One technique you can use is to include the following code 
somewhere in your program:

```Swift
#if DEBUG
extension UIViewController {
    @objc func injected() {
        viewDidLoad()
    }
}
#endif
```
Another solution to this problem is "hosting" using the 
[Inject](https://github.com/krzysztofzablocki/Inject)
Swift Package introduced by this 
[blog post](https://merowing.info/2022/04/hot-reloading-in-swift/).

### What injection can't do

You can't inject changes to how data is laid out in memory i.e.
you cannot add, remove or reorder properties with storage. 
For non-final classes this also applies to adding
or removing methods as the `vtable` used for dispatch is 
itself a data structure which must not change over injection.
Injection also can't work out what pieces of code need to
be re-executed to update the display as discussed above.

### Injection of SwiftUI

SwiftUI is, if anything, better suited to injection than UIKit
as it has specific mechanisms to update the display but you need
to make a couple changes to each 	`View` struct you want to inject.
To force redraw the simplest way is to add a property that
observes when an injection has occurred:

```
    @ObserveInjection var forceRedraw
```
This property wrapper is available in either the 
[HotSwiftUI](https://github.com/johnno1962/HotSwiftUI) or
[Inject](https://github.com/krzysztofzablocki/Inject)
Swift Package. You can use one of the following to make 
these packages available throughout your project:

```
@_exported import HotSwiftUI
or
@_exported import Inject
```
The second change you need to make for reliable SwiftUI
injection is to "erase the return type" of the body property
by wrapping it in `AnyView` using the `.enableInjection()` 
method extending `View` in these packages. This is because, 
as you add or remove SwiftUI elements it can change the concrete 
return type of the body property which amounts to a memory layout 
change that may crash. In summary, the tail end of each body should
always look like this:

```
    var body: some View {
    	 VStack or whatever {
        // Your SwiftUI code...
        }
        .enableInjection()
    }

    @ObserveInjection var redraw
```
You can leave these modifications in your production code as, 
for a release build they optimise out to a no-op.

### On-device injection

This can work but you will need to actually run the InjectionIII.app,
set a user default to opt-in and, instead of loading the injection
bundles as shown above you add the 
[HotReloading](https://github.com/johnno1962/HotReloading) 
Swift Package to your target _during development_.
See the README for that project for details no how to debug 
having your program connect to the app. You will also need to 
select the project directory for the file watcher manually from
the menu bar.

_Remember to not release your app with the HotReloading package included!_

### Injection on macOS

It works but you need to temporarily turn off the "app sandbox" and "library validation" under the "hardened runtime" during development 
so it can dynamically load code.

### How it works

Injection has worked various ways over the years, starting out using 
the "Swizzling" apis for Objective-C but is now largely built around 
a feature of Apple's linker called "interposing" which provides a 
solution for any Swift method or computed property of any type.

When your code calls a function in Swift, it is generally "statically
dispatched", i.e. linked using the "mangled symbol" of the function being called.
Whenever you link your application with the "-interposable" option
however, an additional level of indirection is added where it finds 
the address of all functions being called through a section of 
writable memory. Using the operating system's ability to load 
executable code and the [fishhook](https://github.com/facebook/fishhook) 
library to rebind it is therefore possible to "interpose" new
implementations of any function and effectively stitch 
them into the rest of your program at runtime. From that point it will 
perform as if the new code had been built into the program. 

Injection uses the `FSEventSteam` api to watch for when a source
file has been changed and scans the last Xcode build log for how to
recompile it and links a dynamic library that can be loaded into your
program. Runtime support for injection then loads the dynamic library 
and scans it for the function definitions it contains which it then
"interposes" into the rest of the program. This isn't the full story as
the dispatch of non-final class methods uses a "vtable" (like C++ virtual methods) which also has to be updated but the project looks after
that along with any legacy Objective-C "swizzling".

If you are interested knowing more about how injection works
the best source is either my book [Swift Secrets](http://books.apple.com/us/book/id1551005489) or the new, start-over reference implementation
in the [InjectionLite](https://github.com/johnno1962/InjectionLite) 
Swift Package. For more information about "interposing" consult [this
blog post](https://www.mikeash.com/pyblog/friday-qa-2012-11-09-dyld-dynamic-linking-on-os-x.html) or the README of the [fishhook project](https://github.com/facebook/fishhook). For more information about the
organisation of the app itself, consult [ROADMAP.md](ROADMAP.md).

### Further information

Consult the [old README](OLDME.md) which if anything contained 
simply "too much information" including the various environemt
variables you can use for customisation. The first among these
is `INJECTION_DETAIL` which prints verbose information about 
the actions the code is performing.

### Acknowledgements:

This project includes code from [rentzsch/mach_inject](https://github.com/rentzsch/mach_inject),
[erwanb/MachInjectSample](https://github.com/erwanb/MachInjectSample),
[davedelong/DDHotKey](https://github.com/davedelong/DDHotKey) and
[acj/TimeLapseBuilder-Swift](https://github.com/acj/TimeLapseBuilder-Swift) under their
respective licenses.

The App Tracing functionality uses the [OliverLetterer/imp_implementationForwardingToSelector](https://github.com/OliverLetterer/imp_implementationForwardingToSelector) trampoline implementation via the [SwiftTrace](https://github.com/johnno1962/SwiftTrace) project under an MIT license.

SwiftTrace uses the very handy [https://github.com/facebook/fishhook](https://github.com/facebook/fishhook).
See the project source and header file included in the app bundle
for licensing details.

This release includes a very slightly modified version of the excellent
[canviz](https://code.google.com/p/canviz/) library to render "dot" files
in an HTML canvas which is subject to an MIT license. The changes are to pass
through the ID of the node to the node label tag (line 212), to reverse
the rendering of nodes and the lines linking them (line 406) and to
store edge paths so they can be coloured (line 66 and 303) in "canviz-0.1/canviz.js".

It also includes [CodeMirror](http://codemirror.net/) JavaScript editor
for the code to be evaluated using injection under an MIT license.

The fabulous app icon is thanks to Katya of [pixel-mixer.com](http://pixel-mixer.com/).

$Date: 2023/06/08 $
