# InjectionIII - overdue Swift rewrite of InjectionForXcode 
# [中文集成指南](https://github.com/looha518/InjectionIII/blob/main/README_%20Chinese.md)，[掘金教程](https://juejin.cn/post/6990285526901522463)
![Icon](http://johnholdsworth.com/Syringe_128.png)

Code injection allows you to update the implementation of functions and any method of a class, struct or enum incrementally
in the iOS simulator without having to rebuild or restart your application. This saves the developer a significant amount of time tweaking code or iterating over a design.
This start-over implementation of [Injection for Xcode](https://github.com/johnno1962/injectionforxcode)
has been built into a standalone app: `InjectionIII.app` which runs in the status bar and is [available from the Mac App Store](https://itunes.apple.com/app/injectioniii/id1380446739?mt=12).

**Stop Press:** The functionality of InjectionIII is now  available as a Swift Package
in the [HotReloading Project](https://github.com/johnno1962/HotReloading). No
need to download the app, just add this project to yours and add a short
"Run Script" "Build Phase" as described in the README.md.

This README includes descriptions of some newer features that are only available in more recent
releases of the InjectionIII.app [available on github](https://github.com/johnno1962/InjectionIII/releases).
You may need to use one of these releases for Apple Silicon or if you have upgraded to Big Sur
due to changes to macOS codesigning that affect the sandboxed App Store version of the app.

![Icon](http://johnholdsworth.com/InjectionUI.gif)

`InjectionIII.app` needs an Xcode 10.2 or greater at the path `/Applications/Xcode.app` , works for `Swift` and `Objective-C` and can be used alongside [AppCode](https://www.jetbrains.com/help/objc/create-a-swiftui-application.html) or by using the [AppCode Plugin](https://github.com/johnno1962/InjectionIII/blob/master/AppCodePlugin/INSTALL.md)
instead.

To understand how InjectionIII works and the techniques it uses consult the book [Swift Secrets](http://books.apple.com/us/book/id1551005489).

### Managing Expectations

By rights, InjectionIII shouldn't work and this seems to be a common perception for the
sceptics out there who haven't actually tried it and yet it does. It relies on documented 
features of Apple's dynamic linker which have proven to be reliable for a year now. That 
said,  you can't just inject _any_ source file. For example, it's best not to try to inject a
file containing a protocol definition. Keep in mind though the worst case is that your
application might crash during debugging and you'll have to restart it as you would have 
had to anyway. Gaining trust in the changes you can inject builds with experience and
with it, the amount of time you save. The injectionIII bundle is only used during development 
in the simulator and cannot affect your application when it is deployed into production.

To reason about your app while you are using injection, separate  data and program
in your mind. You can't inject changes to the way data is laid out in memory by adding 
properties or methods on the fly but apart from that exchanging  method implementations
is performed on the main thread and perfectly reliable. A common question for new
users is: I injected a new version of the code, why can't I see the changes on the screen?
To have effect, the new code needs to be actually executed and it's up to the user to use 
either an `@objc func injected()` method or a notification to reload a view controller 
or refresh a table view to see changes or perform some user action that forces a redisplay.

If you try InjectionIII and you think it doesn't work, please, please file an issue so we can
either explain what is going on, improve the documentation or try to resolve the particular 
edge case you have encountered. The project is quite mature now and provided you're 
holding it correctly and don't ask too much of it, it should "just work".

### Getting Started

To use injection, download the app from the App Store and run it. Then, you must add `"-Xlinker -interposable"` (without the double quotes) to your project's `"Other Linker Flags"` for the Debug target (qualified by the simulator SDK to avoid complications with bitcode). Finally, add one of the following to your application delegate's `applicationDidFinishLaunching:`

Xcode 10.2 and later (Swift 5+):

```Swift
#if DEBUG
Bundle(path: "/Applications/InjectionIII.app/Contents/Resources/iOSInjection.bundle")?.load()
//for tvOS:
Bundle(path: "/Applications/InjectionIII.app/Contents/Resources/tvOSInjection.bundle")?.load()
//Or for macOS:
Bundle(path: "/Applications/InjectionIII.app/Contents/Resources/macOSInjection.bundle")?.load()
#endif
```

Adding one of these lines loads a bundle included in the `InjectionIII.app`'s
resources which connects over a localhost socket to the InjectionIII app which runs on the task bar.
Once injection is connected, you'll be prompted to select the directory containing the project file for the app you wish to inject. This starts a `file watcher` for that directory inside the Mac app so whenever
you save to disk a Swift (or Objective-C) source in the project, the target app is messaged through the socket to compile, link, dynamically load and update the implementation of methods in the file being injected. 

If your project is organised across multiple directories or the project file is not at the root of the source tree you can add other directories to be watched for file changes using the "Add Directory"
menu item. This list resets when you select a new project.

The file watcher can be disabled & enabled while the app is running using the status bar menu.
While the file watcher is disabled you can still force injections through manually using a hotkey `ctrl-=` (remember to save the file first!)

If you inject a subclass of `XCTest` InjectionIII will try running that individual test inside your application provided has been compiled at some time in the past and doesn't require test specific support code.

You can detect when a *class* has been injected in your code (to reload a view controller for example) by adding an `@objc func
injected()` class or instance method.  The instance `@objc
func injected()` method relies on a "sweep" of all objects in your application to find those of
the class you have just injected which can be unreliable when using `unowned` instance variables. If you encounter problems, remomve the injected() method and subscribe to the `"INJECTION_BUNDLE_NOTIFICATION"` instead along the lines of the following:

```Swift
NotificationCenter.default.addObserver(self,
    selector: #selector(configureView),
    name: Notification.Name("INJECTION_BUNDLE_NOTIFICATION"), object: nil)
```
Included in this release is "Xprobe" which allows you to browse and inspect the objects in
your application through a web-like interface and execute code against them. Enter text into the search textfield to locate objects quickly by class name.

If you want to build this project from source (which you may need to do to use injection with macOS apps) you'll need to use:

    git clone https://github.com/johnno1962/InjectionIII --recurse-submodules
    
### Available downloads

| Xcode 10.2+ | For Big Sur | AppCode Plugin |
| ------------- | ------------- | ------------- |
| [Mac app store](https://itunes.apple.com/app/injectioniii/id1380446739?mt=12) | [Github Releases](https://github.com/johnno1962/InjectionIII/releases) | [Install  Injection.jar](https://github.com/johnno1962/InjectionIII/tree/master/AppCodePlugin) |

### Limitations/FAQ

New releases of InjectionIII use a [different patching technique](http://johnholdsworth.com/dyld_dynamic_interpose.html)
than previous versions in that you can now update the implementations of class, struct and enum methods (final or not)
provided they have not been inlined which shouldn't be the case for a debug build. You can't however alter the layout of
a class or struct in the course of an injection i.e. add or rearrange properties with storage or add or move methods of a
non-final class or your app will likely crash. Also, see the notes below for injecting `SwiftUI` views and how they require
type erasure.

If you have a complex project including Objective-C or C dependancies, using the `-interposable` flag may provoke undefined symbols or the following error on linking:

```
Can't find ordinal for imported symbol for architecture x86_64
```
If this is the case, add the following additional "Other linker Flags" and it should go away.

```
-Xlinker -undefined -Xlinker dynamic_lookup
```

If you have a project using extensive bridging & Objective-C it's recommended to use
one of the [binary github releases](https://github.com/johnno1962/InjectionIII/releases)
that have the sandbox turned off. This is beacuse the App Store version operates in 
a case sensitive file system which can create problems if filenames in your project do 
not have the identical casing as the actual filename on disk.

If you inject code which calls a function with default arguments you may
get an error starting as follows reporting an undefined symbol:

```
💉 *** dlopen() error: dlopen(/var/folders/nh/gqmp6jxn4tn2tyhwqdcwcpkc0000gn/T/com.johnholdsworth.InjectionIII/eval101.dylib, 2): Symbol not found: _$s13TestInjection15QTNavigationRowC4text10detailText4icon6object13customization6action21accessoryButtonActionACyxGSS_AA08QTDetailG0OAA6QTIconOSgypSgySo15UITableViewCellC_AA5QTRow_AA0T5StyleptcSgyAaT_pcSgAWtcfcfA1_
 Referenced from: /var/folders/nh/gqmp6jxn4tn2tyhwqdcwcpkc0000gn/T/com.johnholdsworth.InjectionIII/eval101.dylib
 Expected in: flat namespace
in /var/folders/nh/gqmp6jxn4tn2tyhwqdcwcpkc0000gn/T/com.johnholdsworth.InjectionIII/eval101.dylib ***
```
This typically becuase you are injecting code that uses a default argument.
If you encounter this problem, restart your app and you should find this issue
disappears due to a background task [unhide](https://github.com/johnno1962/unhide)
which is integrated into InjectionIII.

Keep in mind global state -- If the file you're injecting has top level variables e.g. singletons,
static or global vars they will be reset when you inject the code as the new method
implementations will refer to the newly loaded object file containing the variable.

As injection needs to know how to compile Swift files individually it is not compatible with building using
`Whole Module Optimisation`. A workaround for this is to build with `WMO` switched off so there are
logs of individual compiles available then switching `WMO` back on if it suits your workflow better.

### SwiftUI Injection

It is possible to inject `SwiftUI` interfaces but it requires some minor
code changes. This is because when you add elements to an interface or
use modifiers that change their type, this changes the return type of the
body properties' `Content` which causes a crash. To avoid this you need
to erase the return type. The easiest way to do this is to add the code below
to your source somewhere then add the modifier  `.eraseToAnyView()`  at
the very end of any declaration of a view's body property that you want to inject:

```Swift
#if DEBUG
private var loadInjection: () = {
    #if os(macOS)
    let bundleName = "macOSInjection.bundle"
    #elseif os(tvOS)
    let bundleName = "tvOSInjection.bundle"
    #elseif targetEnvironment(simulator)
    let bundleName = "iOSInjection.bundle"
    #else
    let bundleName = "maciOSInjection.bundle"
    #endif
    Bundle(path: "/Applications/InjectionIII.app/Contents/Resources/"+bundleName)!.load()
}()

import Combine

public let injectionObserver = InjectionObserver()

public class InjectionObserver: ObservableObject {
    @Published var injectionNumber = 0
    var cancellable: AnyCancellable? = nil
    let publisher = PassthroughSubject<Void, Never>()
    init() {
        cancellable = NotificationCenter.default.publisher(for:
            Notification.Name("INJECTION_BUNDLE_NOTIFICATION"))
            .sink { [weak self] change in
            self?.injectionNumber += 1
            self?.publisher.send()
        }
    }
}

extension View {
    public func eraseToAnyView() -> some View {
        _ = loadInjection
        return AnyView(self)
    }
    public func onInjection(bumpState: @escaping () -> ()) -> some View {
        return self
            .onReceive(injectionObserver.publisher, perform: bumpState)
            .eraseToAnyView()
    }
}
#else
extension View {
    public func eraseToAnyView() -> some View { return self }
    public func onInjection(bumpState: @escaping () -> ()) -> some View {
        return self
    }
}
#endif
```

To have the view you are working on redisplay automatically when it is injected it's sufficient
to add an `@ObservedObject`, initialised to the `injectionObserver` instance as follows:

```Swift
        .eraseToAnyView()
    }

    #if DEBUG
    @ObservedObject var iO = injectionObserver
    #endif
```
You can make all these changes automatically once you've opened a project using the
`"Prepare Project"` menu item. If you'd like to execute some code each time your interface is injected, use the 
`.onInjection { ... }` modifier instead of .`eraseToAnyView()`. As an alternative
this code is available in the [HotSwiftUI](https://github.com/johnno1962/HotSwiftUI)
Swift Package though you would have to remember to load the 
`iOSInjection.bundle` separately.

### macOS Injection

It is possible to use injection with a macOS/Catalyst project but it is getting progressively more difficult
with each release of the OS. You need to make sure to turn off the "App Sandbox" and also "Disable 
Library Validation" under the "Hardened Runtime" options for your project while you inject. 
On an M1 Mac, if you "Disable  Library Validation" and your app has web content 
you will likely also have to enable "Allow execution of JIT-compiled code".

With an Apple Silicon Mac it is possible to run your iOS application natively on macOS.
You can use injection with these apps but as you can't turn off library validation it's a little
involved. You need re-codesign the maciOSInjection.bundle contained in the InjectionIII
app package using the signing identity used by your target app which you can determine
from the `Sign` phase in your app's build logs. You will also need to set a user default with
the path to your project file as the name and the signing identity as the value so injected
code changes can be signed properly as you can not turn off library validation.

All this is best done by adding the following as a build phase to your target project:

```shell
# Type a script or drag a script file from your workspace to insert its path.
export CODESIGN_ALLOCATE\=/Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin/codesign_allocate
INJECTION_APP_RESOURCES=/Applications/InjectionIII.app/Contents/Resources
/usr/bin/codesign --force --sign $EXPANDED_CODE_SIGN_IDENTITY  $INJECTION_APP_RESOURCES/maciOSInjection.bundle/maciOSInjection
/usr/bin/codesign --force --sign $EXPANDED_CODE_SIGN_IDENTITY  $INJECTION_APP_RESOURCES/maciOSSwiftUISupport.bundle/maciOSSwiftUISupport
/usr/bin/codesign --force --sign $EXPANDED_CODE_SIGN_IDENTITY $INJECTION_APP_RESOURCES/maciOSInjection.bundle/Frameworks/SwiftTrace.framework/SwiftTrace
defaults write com.johnholdsworth.InjectionIII "$PROJECT_FILE_PATH" $EXPANDED_CODE_SIGN_IDENTITY
```
### Storyboard injection

Sometimes when you are iterating over a UI it is useful to be able to inject storyboards. This works slightly differently from code injection. To inject changes to a storyboard scene, make your changes then _build_ the project instead of saving the storyboard. The "nib" of the currently displayed view controlled should be reloaded and viewDidLoad etc. will be called.

### Vaccine

Injection now includes the higher level `Vaccine` functionality, for more information consult the [project README](https://github.com/zenangst/Vaccine) or one of the [following](https://medium.com/itch-design-no/code-injection-in-swift-c49be095414c) [references](https://medium.com/@robnorback/the-secret-to-1-second-compile-times-in-xcode-9de4ec8345a1).

### Method Tracing menu item (SwiftTrace)

It's possible to inject tracing aspects into your program that don't
affect it's operation but log every method call. Where possible
it will also decorate their arguments. You can add logging to all
methods in your app's main bundle or the frameworks it uses
or trace calls to system frameworks such as UIKit or SwiftUI.
If you opt into "Type Lookup", custom types in your appliction
can also be decorated using the CustomStringConvertable
conformance or the default formatter for structs.

These features are implemented by the package [SwiftTrace](https://github.com/johnno1962/SwiftTrace)
which is built into the InjectionBundle. If you want finer grain control of what is being traced,
include the following header file in your project's bridging header and a subset of the internal
api will be available to Swift (after an injection bundle has been loaded):

```C++
#import "/Applications/InjectionIII.app/Contents/Resources/SwiftTrace.h"
```
The "Trace Main Bundle" menu item can be mimicked by using the following call:

```Swift
 NSObject.swiftTraceMainBundleMethods()
```
If you want instead to also trace all Swift calls your application makes to a system
framework such as SwiftUI you can use the following:

```Swift
 NSObject.swiftTraceMethods(inFrameworkContaining:UIHostingController<ContentView>.self)
```
To include or exclude the methods to be traced use the `methodInclusionPattern`
and `methodExclusionPattern` class properties of SwiftTrace. For more information
consult the [SwiftTrace source repo](https://github.com/johnno1962/SwiftTrace). It's also
possible to access the Swift API of SwiftTrace directly in your app. For example, to add 
a new handler to format a particular type by importing SwiftTrace and adding the
following to your app's `"Framework Search Paths"` and `"Runpath Search Paths"`
(for the Debug configuration):

```
/Applications/InjectionIII.app/Contents/Resources/iOSInjection.bundle/Frameworks
```
Then, you can use something like the following to register the type:

```Swift
SwiftTrace.makeTraceable(types: [MovieSwift.MovieRow.Props.self])
```
In this case however the `MovieSwift.MovieRow.Props` type from the excellent 
`MovieSwift` SwiftUI  [example project](https://github.com/Dimillian/MovieSwiftUI)
is too large to format but can be changed to be a class instead of a struct. 
More recent versions of SwiftTrace have the ability to register classes automatically 
if you opt-in using the "Method Tracing/Type Lookup" menu item.

Finally, if you'd like to go directly to the file that defines a logged method, select the
fully qualified method and use the service `Injection Goto` to open the file declaring
that function. (To have the `Injection Goto` item appear on your services context menu
you need to select it in System Preferences/Keyboard, tab Shortcuts/Services, under the
"Text" section.)

There are other SwifTrace features that allow you to "profile" your application to optimise
the order object files are linked into your application which could potentially minimise
paging on startup. These are surfaced in the "Method Tracing" submenu but if I'm honest,
these would only make a difference if you had a very, very large application binary.

### Remote Control

Newer versions of InjectionIII contain a server that allows you to control your development device from your desktop once the service has been started. The UI allows you to record and replay macros of UI actions then verify the device screen against snapshots for end-to-end testing.

To use, import the Swift Package [https://github.com/johnno1962/Remote.git](https://github.com/johnno1962/Remote.git)
and it should connect automatically to your desktop provided you have selected the 
"Remote Control/Start Server" menu item in InjectionIII to start it's server.
Your app should connect to this server when you next run it and will pop up a
window showing the device display and accepting tap events. Events can be
saved as `macros` and replayed. If you include a snapshot in a macro this will
be compared against the device display (within a tolerance) when you replay
the macro for automated testing. Remote can also be used to capture videos
of your app in operation but, as it operates over the network, it isn't fast enough
to capture animated transitions.

## SwiftEval - Yes, it's eval() for Swift

![Icon](https://courses.cs.washington.edu/courses/cse190m/10su/lectures/slides/images/drevil.png)

InjectionIII started out as the SwiftEval class which is a [single Swift source](InjectionBundle/SwiftEval.swift)
that can be added to your iOS simulator or macOS projects to implement an eval function inside
classes that inherit from NSObject. There is a generic form which has the following signature:

```Swift
extension NSObject {
    public func eval<T>(_ expression: String, type: T.Type) -> T
}
```

This takes a Swift expression as a String and returns an entity of the type specified.
There is also a shorthand function for expressions of type String which accepts the
contents of the String literal as it's argument:

```Swift
public func swiftEvalString(contents: String) -> String {
    return eval("\"" + expression + "\"", String.self)
}
```

An example of how it is used can be found in the EvalApp example.

```Swift
@IBAction func performEval(_: Any) {
    textView.string = swiftEvalString(contents: textField.stringValue)
}

@IBAction func closureEval(_: Any) {
    _ = swiftEval(code: closureText.stringValue+"()")
}
```

The code works by adding an extension to your class source containing the expression.
It then compiles and loads this new version of the class "swizzling" this extension onto
the original class. The expression can refer to instance members in the class containing
the eval class and global variables & functions  in other class sources.

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

$Date: 2021/06/06 $
