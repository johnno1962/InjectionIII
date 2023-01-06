# InjectionIII - overdue Swift rewrite of InjectionForXcode 

Chinese language README & Tutorial:  [中文集成指南](https://github.com/johnno1962/InjectionIII/blob/main/README_Chinese.md)，[掘金教程](https://juejin.cn/post/6990285526901522463)

![Icon](http://johnholdsworth.com/Syringe_128.png)

Code injection allows you to update the implementation of functions and any method of a class, struct or enum incrementally
in the iOS simulator without having to rebuild or restart your application. This saves the developer a significant amount of time tweaking code or iterating over a design.
This start-over implementation of [Injection for Xcode](https://github.com/johnno1962/injectionforxcode)
has been built into a standalone app: `InjectionIII.app` which runs in the status bar and is [available from the Mac App Store](https://itunes.apple.com/app/injectioniii/id1380446739?mt=12).

**Stop Press:** The functionality of InjectionIII is now available by simply adding a Swift 
Package, the [HotReloading Project](https://github.com/johnno1962/HotReloading) instead.
No need to download the app or select the project directory. The 
package also offers limited support of dynamic code updates on a device in conjunction with a
github release of the the InjectionIII app if you set a user default as described in the package's README.md. _Do not release your app with the HotReloading package included!_

**Stop Stop Press:** Since versions 4.4.0+ of the app and for 
iOS/tvOS 14+ it is possible to use injection by not running the app
at all and just loading one of the "injection bundles" from your client app
by adding the code described below. This is by far the simplest version
of Injection available so far, not requiring you to select the current project.
When the InjectionIII.app is not running, the bundle will fall back to using 
the  "standalone" implementation of injection from the HotReloading
project watching for file changes in your home directory and using the 
logs of your last built project determined by the FileWatcher. Skip to
the notes on "Standalone Injection" below.

This README includes descriptions of some newer features that are only available in more recent
releases of the InjectionIII.app [available on github](https://github.com/johnno1962/InjectionIII/releases).
You should use one of these releases for Apple Silicon and want to 
target a simulator older than iOS 14 or if you have upgraded to 
macOS Monterey or later.

![Icon](http://johnholdsworth.com/InjectionUI.gif)

`InjectionIII.app` needs an Xcode 10.2 or greater at the path `/Applications/Xcode.app` , 
works for `Swift`,  `Objective-C` and since 3.2.2 `C++` and can be used alongside [AppCode](https://www.jetbrains.com/help/objc/create-a-swiftui-application.html) or by using the [AppCode Plugin](https://github.com/johnno1962/InjectionIII/blob/master/AppCodePlugin/INSTALL.md)
instead.

To understand how InjectionIII works and the techniques it uses consult the book [Swift Secrets](http://books.apple.com/us/book/id1551005489).

### Managing Expectations

By rights, InjectionIII shouldn't work and this seems to be a common perception for those who haven't actually tried it and yet it does. It relies on documented 
features of Apple's dynamic linker which have proven to be reliable for over a year now. That 
said,  you can't just inject _any_ source file. For example, it's best not to try to inject a
file containing a protocol definition. Keep in mind though the worst case is that your
application might crash during debugging and you'll have to restart it as you would have 
had to anyway. Gaining trust in the changes you can inject builds with experience and
with it, the amount of time you save. The `iOSInjection.bundle` is only loaded during
development  in the simulator and cannot affect your application when it is deployed 
to a production device.

Always remember to add `"Other Linker Flags"`, `"-Xlinker -interposable"` 
to your project or due to details of how a method is dispatched you may
find InjectionIII half works for classes and classes and not for structs. 
Also, go easy on access control. For example, InjectionIII is unable to 
inject methods in a private extension as the symbols are not exported 
to the object file.

To reason about your app while you are using injection, separate  data and program
in your mind. You can't inject changes to the way data is laid out in memory by adding 
properties or methods on the fly but apart from that exchanging  method implementations
is performed on the main thread and generally reliable. A common question for new
users is: I injected a new version of the code, why can't I see the changes on the screen?
To have effect, the new code needs to be actually executed and it's up to the user to use 
either an `@objc func injected()` method or a notification to reload a view controller 
or refresh a table view to see changes or perform some user action that forces a redisplay. For example, to force all ViewControllers in your app
to reload when they are injected some people use this code:

```Swift
extension UIViewController {
    @objc func injected() {
        viewDidLoad()
    }
}
```
If you try InjectionIII and you think it doesn't work, please, please open an issue so we can
either explain what is going on, improve the documentation or try to resolve the particular 
edge case you have encountered. The project is quite mature now and provided you're 
holding it correctly and don't ask too much of it, it should "just work".

### Getting Started

To use injection, download the app from the App Store and run it. Then, you need to add "-Xlinker -interposable" (without the double quotes) to the "Other Linker Flags" of all targets in your project for the Debug configuration (qualified by the simulator SDK to avoid complications with bitcode). Finally, add one of the following to your application delegate's `applicationDidFinishLaunching:`

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

If you inject a subclass of `XCTest` InjectionIII will try running that
individual test inside your application provided has been compiled at 
some time in the past and doesn't require test specific support code.
If the menu item "Enable TDD" is enabled, when you inject a file
InjectionIII will search for test sources containing that filename,
inject them and run the test.

You can detect when a *class* has been injected in your code (to reload a view controller for example) by adding an `@objc func
injected()` class or instance method.  The instance `@objc
func injected()` method relies on a "sweep" of all objects in your application to find those of
the class you have just injected which can be unreliable when using `unowned` instance variables. If you encounter problems, remove the injected() method and subscribe to the `"INJECTION_BUNDLE_NOTIFICATION"` instead along the lines of the following:

```Swift
NotificationCenter.default.addObserver(self,
    selector: #selector(configureView),
    name: Notification.Name("INJECTION_BUNDLE_NOTIFICATION"), object: nil)
```
Included in this release is "Xprobe" which allows you to browse and inspect the objects in
your application through a web-like interface and execute code against them. Enter text into the search textfield to locate objects quickly by class name.

If you want to build this project from source (which you may need to do to use injection with macOS apps) you'll need to use:

    git clone https://github.com/johnno1962/InjectionIII --recurse-submodules
    
To replicate one of the [github releases](https://github.com/johnno1962/InjectionIII/releases),
turn the App sandbox off in the entitlements file.

If you're looking to understand how the app works it's magic, it's not a 
short story but the staring point is the [ROADMAP.md](ROADMAP.md)
file in this repo.
    
### Available downloads

| Xcode 10.2+ | Monterey & Xcode 13 |
| ------------- | ------------- |
| [Mac app store](https://itunes.apple.com/app/injectioniii/id1380446739?mt=12) | [Github Releases](https://github.com/johnno1962/InjectionIII/releases) |

### Variations on using the InjectionIII app:

[App Store version](https://itunes.apple.com/app/injectioniii/id1380446739?mt=12):
load the injection bundle and you can perform code injection in the simulator.

[Binary Releases](https://github.com/johnno1962/InjectionIII/releases): 
These are often slightly more up to date than the App Store release and
compile outside the App sandbox which avoids complications with
case insensitive filesystems.

[HotReloading Project](https://github.com/johnno1962/HotReloading):
A version of InjectionIII that works just by adding this Swift Package to
your project (and adding the -interposable linker flag). See the repo
README for details. Remember not to leave this package configured 
into your project for a release build or it will bloat your app binary!

**On-Device Injection**: Instead of loading  the `iOSInjection.bundle`,
add the [HotReloading](https://github.com/johnno1962/HotReloading)
Swift Package to your project and add a "Build Phase" in the README 
to run the `injectiond` daemon version of the InjectionIII.app and you
should be able to perform injection on a iOS or tvOS device. For more
detail and the limitations  of this new feature, see the README of the
[HotReloading](https://github.com/johnno1962/HotReloading) project.

**Standalone Injection**: Since 4.4.*+ this is now the recommended way 
of using injection as it contains fewer moving parts that need to be in place 
for injection to "just work". Everything injection needs can be performed
inside the simulator and it automatically determines which project and
build logs to use by finding the most recently modified ".xcactivitylog" file
in ~/Library/Developer/Xcode/DerivedData (which is just a gzip of the
most recently built project's build log). The file watcher will watch for 
all changes to source files in your home directory by default. As always,
you need to add the `-Xlinker -interposable` "Other Linker Flags"
to your project's targets and download a [binary release](https://github.com/johnno1962/InjectionIII/releases) of the app
to make available the "iOSInjection.bundle" but no longer need to run 
the app (though it still works as it did before if you do).

### SwiftUI Injection

It is possible to inject `SwiftUI` interfaces but it requires some minor
code changes. This is because when you add elements to an interface or
use modifiers that change their type, this changes the return type of the
body property's `Content` across the injection which causes a crash. 
To avoid this you need to erase the return type. The easiest way to do 
this is to add the code below to your source somewhere then add the
modifier  `.eraseToAnyView()`  at the very end of any declaration of a
view's body property that you want to inject:

```Swift
#if DEBUG
private var loadInjection: () = {
    guard objc_getClass("InjectionClient") == nil else { return }
    #if os(macOS) || targetEnvironment(macCatalyst)
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
`"Prepare Project"` menu item of the app. If you'd like to execute some code each time your interface is injected, use the 
`.onInjection { ... }` modifier instead of .`eraseToAnyView()`.
As an alternative, this code is available in the
[HotSwiftUI](https://github.com/johnno1962/HotSwiftUI)
Swift Package. Another alternative
from someone who has considerably more experience in iOS development
than I do check out the [Inject](https://github.com/krzysztofzablocki/Inject)
Swift Package introduced by this [blog post](https://merowing.info/2022/04/hot-reloading-in-swift/).

### Limitations/FAQ

New releases of InjectionIII use a [different patching technique](http://johnholdsworth.com/dyld_dynamic_interpose.html)
than previous versions in that you can now update the implementations of class, struct and enum methods (final or not)
provided they have not been inlined which shouldn't be the case for a debug build. You can't however alter the layout of
a class or struct in the course of an injection i.e. add or rearrange properties with storage or add or move methods of a
non-final class or your app will likely crash. Also, see the notes below for injecting `SwiftUI` views and how they require
type erasure.

Before Xcode 14, if you have a complex project including Objective-C or C dependancies, 
using the `-interposable` flag may provoke undefined symbols or the following error on linking:

```
Can't find ordinal for imported symbol for architecture x86_64
```
If this is the case, add the following additional "Other linker Flags" and it will become a warning.

```
-Xlinker -undefined -Xlinker dynamic_lookup
```
If you have a project using extensive bridging & Objective-C it's recommended to use
one of the [binary github releases](https://github.com/johnno1962/InjectionIII/releases)
that have the sandbox turned off. This is because the App Store version operates in 
a case sensitive file system which can create problems if filenames in your project do 
not have the identical casing as the actual filename on disk.

If you inject code which calls a function with default arguments in a framework
you may get an error starting as follows reporting an undefined symbol:

```
💉 *** dlopen() error: dlopen(/var/folders/nh/gqmp6jxn4tn2tyhwqdcwcpkc0000gn/T/com.johnholdsworth.InjectionIII/eval101.dylib, 2): Symbol not found: _$s13TestInjection15QTNavigationRowC4text10detailText4icon6object13customization6action21accessoryButtonActionACyxGSS_AA08QTDetailG0OAA6QTIconOSgypSgySo15UITableViewCellC_AA5QTRow_AA0T5StyleptcSgyAaT_pcSgAWtcfcfA1_
 Referenced from: /var/folders/nh/gqmp6jxn4tn2tyhwqdcwcpkc0000gn/T/com.johnholdsworth.InjectionIII/eval101.dylib
 Expected in: flat namespace
in /var/folders/nh/gqmp6jxn4tn2tyhwqdcwcpkc0000gn/T/com.johnholdsworth.InjectionIII/eval101.dylib ***
```
If you encounter this problem, restart your app and you should find this issue
disappears due to a background task [unhide](https://github.com/johnno1962/unhide)
which is integrated into InjectionIII.

As injection needs to know how to compile Swift files individually it is not compatible with building using
`Whole Module Optimisation`. A workaround for this is to build with `WMO` switched off so there are
logs of individual compiles available then switching `WMO` back on if it suits your workflow better.
You may need to do this each time you open your project as Xcode is now
far for agressive in removing old build logs.

### Resolving issues

Versions > 4.1.1 of InjectionIII have the following environment variables that 
can be added to your Xcode launch scheme to customise its behavour or to 
get a better idea what InjectionIII is doing.

**INJECTION_DETAIL** Providing any value for this variable in the
your scheme will produce detailed output of how InjectionIII is
stitching your new implementations into your application. "Swizzling"
is the legacy Objective-C way of rebinding symbols though the
runtime API. "Patching" is where the "vtable" of a class is overridden
to rebind non-final methods to their new dynamically loaded
implementation. "Interposing" uses a low level dynamic linker
feature to effectively re-link call sites to the newly loaded versions
(provided the "-Xlinker -interposable" "Other Linker Flag" build 
setting has been supplied).

**INJECTION_PRESERVE_STATICS** This allows you to decide 
whether top level variables and static member should be re-initialised
if they are in a file that is injected or they should preserve their values.

**INJECTION_DYNAMIC_CAST** This allows you to opt into a slightly 
more speculative fix for when you dynamic cast (as? in Swift) to a type 
which has been injected and therefore its type identifier may have changed.

In order to implement the `@objc func injected()` call to your 
class when an instance is injected, a sweep of all live objects in your
app is performed. This has two limitations. The instance needs to be
"seen" by a reference to a reference to a reference from an initial set 
of seed instances e.g. appDelegate, rootViewController. Secondly,
technically this is ambitious and can crash for some app states or
if you use `unowned` properties.
If you encounter this, provide a value for the environment variable
**INJECTION_SWEEP_DETAIL** and, as it sweeps it will print the type 
name of the object about to be swept.  If you see a crash, from version 
3.2.2 you can exclude the type shown just before the crash using the
**INJECTION_SWEEP_EXCLUDE** environment variable (which can 
be a regular expression).

**INJECTION_OF_GENERICS** It is possible to inject the methods
of generic classes but this requires a "sweep" of live objects to
find the specializations in use (as they each have their own vtables)
so the feature has been made opt-in.

**INJECTION_UNHIDE** Allows users to opt-into the legacy processing
of defualt arguments symbols using the "unhide" which may be required
for larger projects. Otherwise it will still occur "on demand".

**INJECTION_PROJECT_ROOT** This allows you to specify the source
root of your project in it's scheme automatiically messaging the InjectionIII
app to change the scope of the file watcher as you switch between projects.

### InjectionIII and "The Composable Architecture"

Applications written using "TCA" can have the "reducer" functions
update their implementations without having to restart the application.
You'll need to use a [slightly modified version of TCA](https://github.com/thebrowsercompany/swift-composable-architecture/tree/develop) 
and wrap all initialisers of top level reducer variables in a call to the
global function `ARCInjectable()` defined in that repo.

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

It's possible to inject tracing aspects into your program implemented by the 
package [SwiftTrace](https://github.com/johnno1962/SwiftTrace) that don't
affect its operation but should log every method call. Where possible
it will also decorate their arguments. You can add logging to all
methods in your app's main bundle or the frameworks it uses
or trace calls to system frameworks such as UIKit or SwiftUI.
If you opt into "Type Lookup", custom types in your application
can also be decorated using the CustomStringConvertable
conformance or the default formatter for structs.

### Remote Control

Newer versions of InjectionIII contain a server that allows you to control your development device from your desktop once the service has been started. The UI allows you to record and replay macros of UI actions then verify the device screen against snapshots for end-to-end testing.

To use, import the Swift Package [https://github.com/johnno1962/Remote.git](https://github.com/johnno1962/Remote.git)
and it should connect automatically to your desktop provided you have selected the 
"Remote Control/Start Server" menu item in InjectionIII to start its server.
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

The fabulous app icon is thanks to Katya of [pixel-mixer.com](http://pixel-mixer.com/).

$Date: 2023/01/06 $
