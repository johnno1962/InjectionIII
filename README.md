# InjectionIII - overdue Swift rewrite of InjectionForXcode

![Icon](http://johnholdsworth.com/Syringe_128.png)

Code injection allows you to update the implementation of functions and any method of a class, struct or enum incrementally
in the iOS simulator without having to rebuild or restart your application. This saves the developer a significant amount of time tweaking code or iterating over a design.
This start-over implementation of [Injection for Xcode](https://github.com/johnno1962/injectionforxcode)
has been built into a standalone app: `InjectionIII.app` which runs in the status bar and is [available from the Mac App Store](https://itunes.apple.com/app/injectioniii/id1380446739?mt=12).

![Icon](http://johnholdsworth.com/InjectionUI.gif)

`InjectionIII.app` needs an Xcode 10.2 or greater at the path `/Applications/Xcode.app` , works for `Swift` and `Objective-C` and can be used alongside [AppCode](https://www.jetbrains.com/help/objc/create-a-swiftui-application.html) or by using the [AppCode Plugin](https://github.com/johnno1962/InjectionIII/blob/master/AppCodePlugin/INSTALL.md).

### Getting Started

To use injection, download the app from the App Store and run it. Then, and must add `"-Xlinker -interposable"` to your project's `"Other Linker Flags"` for the Debug target (qualified by the simulator SDK to avoid complications with bitcode). Finally, add one of the following to your application delegate's `applicationDidFinishLaunching:`

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

If you'd rather not modify your project source you can edit your Xcode run `scheme` and add an environment variable
`DYLD_INSERT_LIBRARIES` under the `Arguments` tab with the following value instead of the bundle loads above:

`/Applications/InjectionIII.app/Contents/Resources/iOSInjection.bundle/iOSInjection`

Adding one of these lines loads a bundle included in the `InjectionIII.app`'s
resources which connects over a localhost socket to the InjectionII app which runs on the task bar.
Once injection is connected, you'll be prompted to select the directory containing the project file for the app you wish to inject. This starts a `file watcher` for that directory inside the Mac app so whenever
you save to disk a Swift (or Objective-C) source in the project, the target app is messaged through the socket to compile, link, dynamically load and update the implementation of methods in the file being injected. 

If your project is organised across multiple directories or the project file is not at the root of the source tree you can add other directories to be watched for file changes using the "Add Directory"
menu item. This list resets when you select a new project.

The file watcher can be disabled & enabled while the app is running using the status bar men.
While the file watcher is disabled you can still force injections through manually using a hotkey `ctrl-=` (remember to save the file first!)

If you inject a subclass of `XCTest` InjectionIII will try running that individual test inside your application provided has been compiled at some time in the past and doesn't require test specific support code.
When you run your application without rebuilding (^⌘R), recent injections will be re-applied.

You can detect when a *class* has been injected in your code (to reload a view controller for example) by adding an `@objc func
injected()` class or instance method.  The instance `@objc
func injected()` method relies on a "sweep" of all objects in your application to find those of
the class you have just injected which can be unreliable when using `unowned` instance variables. If you encounter problems, subscribe to the `"INJECTION_BUNDLE_NOTIFICATION"` instead.

Included in this release is "Xprobe" which allows you to browse and inspect the objects in
your application through a web-like interface and execute code against them. Enter text into the search textfield to locate objects quickly by class name.

If you want to build this project from source (which you may need to do to use injection with macOS apps) you'll need to use:

    git clone https://github.com/johnno1962/InjectionIII --recurse-submodules
    
### Available downloads

| Xcode 10.2+ | Big Sur (Beta) | AppCode Plugin |
| ------------- | ------------- | ------------- |
| [Mac app store](https://itunes.apple.com/app/injectioniii/id1380446739?mt=12) | [Release Candidate](https://github.com/johnno1962/InjectionIII/releases) | [Install  Injection.jar](https://github.com/johnno1962/InjectionIII/tree/master/AppCodePlugin) |

### Limitations/FAQ

This new release of InjectionIII uses a [different patching technique](http://johnholdsworth.com/dyld_dynamic_interpose.html) than previous versions in that you can now update the implementations of class, struct and enum methods (final or not) provided they have not been inlined which shouldn't be the case for a debug build. You can't however alter the layout of a class or struct in the course of an injection i.e. add or rearrange properties with storage or add or move methods of a non-final class or your app will likely crash. Also, see the notes below for injecting `SwiftUI` views and how they require type erasure.

If you have a complex project including Objective-C or C dependancies you may get the following error on linking:

```
Can't find ordinal for imported symbol for architecture x86_64
```
If this is the case, add the following additional "Other lInker Flags" and it should go away.

```
-Xlinker -undefined -Xlinker dynamic_lookup
```
If you inject code which calls a function with default arguments you may
get an error starting as follows reporting an undefined symbol:

```
💉 *** dlopen() error: dlopen(/var/folders/nh/gqmp6jxn4tn2tyhwqdcwcpkc0000gn/T/com.johnholdsworth.InjectionIII/eval101.dylib, 2): Symbol not found: _$s13TestInjection15QTNavigationRowC4text10detailText4icon6object13customization6action21accessoryButtonActionACyxGSS_AA08QTDetailG0OAA6QTIconOSgypSgySo15UITableViewCellC_AA5QTRow_AA0T5StyleptcSgyAaT_pcSgAWtcfcfA1_
 Referenced from: /var/folders/nh/gqmp6jxn4tn2tyhwqdcwcpkc0000gn/T/com.johnholdsworth.InjectionIII/eval101.dylib
 Expected in: flat namespace
in /var/folders/nh/gqmp6jxn4tn2tyhwqdcwcpkc0000gn/T/com.johnholdsworth.InjectionIII/eval101.dylib ***
```
If you encounter this problem, download and build [the unhide project](https://github.com/johnno1962/unhide) then add the following
as a "Run Script", "Build Phase" to your project:

```
UNHIDE=~/bin/unhide.sh
if [ -f $UNHIDE ]; then
    $UNHIDE
else
    echo "File $UNHIDE used for code Injection does not exist. Download and build the https://github.com/johnno1962/unhide project."
fi
```
This changes the visibility of symbols for default argument generators
and this issue should disappear.

If you are using Code Coverage, you may need to disable it or you will receive a:
>	`Symbol not found: ___llvm_profile_runtime` error.`

Go to `Edit Scheme -> Test -> Options -> Code Coverage` and (temporarily) disable.

Keep in mind global state -- If the file you're injecting has top level variables e.g. singletons, static or global vars
they will be reset when you inject the code as the new method implementations will refer to the newly loaded
object file containing the type.

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
private var loadInjection = {
    Bundle(path: "/Applications/InjectionIII.app/Contents/Resources/iOSInjection.bundle")?.load()
}()

import Combine

let injectionObserver = InjectionObserver()

class InjectionObserver: ObservableObject {
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
    func eraseToAnyView() -> some View {
        _ = loadInjection
        return AnyView(self)
    }
    func onInjection(bumpState: @escaping () -> ()) -> some View {
        return self
            .onReceive(injectionObserver.publisher, perform: bumpState)
            .eraseToAnyView()
    }
}
#else
extension View {
    func eraseToAnyView() -> some View { return self }
    func onInjection(bumpState: @escaping () -> ()) -> some View {
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

If you'd like to execute some code each time your interface is injected use the 
`.onInjection { ... }` modifier instead of .`eraseToAnyView()`.

### macOS Injection

It is possible to use injection with a macOS/Catalyst project but it is getting progressively more difficult
with each release of the OS. Since Catalina you may need to download the sources and build InjectionIII
yourself and copy it into /Applications for injection of a macOS app to work. With Big Sur, the dynamic library that injection creates
to inject also needs to be signed using the same identity as the app you are injecting. To specify the
codesigning identity to use for a particular project use something like the following from the command line:

```
$ defaults write com.johnholdsworth.InjectionIII '/full/path/to/project/file.xcodeproj' CEE8F2FCE31A71EE5207F70F87D184C826844DC0
```
... replacing `CEE8F2FCE31A71EE5207F70F87D184C826844DC0` with the identity used to sign the
app which you can extract from the -sign argument in the `Sign` step in the Xcode build logs.

### Storyboard injection

Sometimes when you are iterating over a UI it is useful to be able to inject storyboards. This works slightly differently from code injection. To inject changes to a storyboard scene, make you changes then _build_ the project instead of saving the storyboard. The "nib" of the currently displayed view controlled should be reloaded and viewDidLoad etc. will be called.

### Vaccine

Injection now includes the higher level `Vaccine` functionality, for more information consult the [project README](https://github.com/zenangst/Vaccine) or one of the [following](https://medium.com/itch-design-no/code-injection-in-swift-c49be095414c) [references](https://medium.com/@robnorback/the-secret-to-1-second-compile-times-in-xcode-9de4ec8345a1).

### App Tracing

The InjectionIII menu contains an item "Trace" which can be used to enable logging of all Objective-C and non-final Swift class method calls. This feature is experimental. Selecting the menu item again will turn the feature off.

If you want finer grain control of what is being traced, include the following file in your project's bridging header and the internal api will be available to Swift (after an injection bundle has been loaded):

```C++
#import "/Applications/InjectionIII.app/Contents/Resources/SwiftTrace.h"
```

For more information consult the [SwiftTrace source repo](https://github.com/johnno1962/SwiftTrace).

### Remote Control

Newer versions of InjectionIII contain a server that allows you to control your development device from your desktop once the service has been started. The UI allows you to record and replay macros of UI actions then verify the device screen against snapshots for end-to-end testing.

To use, add an Objective-C class to your project and `#import` its header file in the Swift bridging header and include the following in the class *header* file:

```C++
#import "/Applications/InjectionIII.app/Contents/Resources/RemoteCapture.h"
```

Finally, include the following in your application's initialisation

```Swift
#if DEBUG
RemoteCapture.start("192.168.1.14")
#endif
```
(replace
`192.168.1.14` with the IPV4 network address or hostname of your development 
machine or your colleague's machine you would like to project your device 
onto if they are also running InjectionIII.)

When InjectionIII is running, select the "Remote/Start Server" menu item to start the
server and then run your app. It should connect to the server which will pop up a
window showing the device display and accepting tap events. Events can be
saved as `macros` and replayed. If you include a snapshot in a macro this will
be compared against the device display (within a tolerance) when you replay
the macro for automated testing. Remote can also be used to capture videos
of your app in operation but as it operates over the network, it isn't fast enough
to capture animated transitions.

## SwiftEval - Yes, it's eval() for Swift

![Icon](https://courses.cs.washington.edu/courses/cse190m/10su/lectures/slides/images/drevil.png)

SwiftEval is a [single Swift source](InjectionBundle/SwiftEval.swift) you can add to your iOS simulator
or macOS projects to implement an eval function inside classes that inherit from NSObject.
There is a generic form which has the following signature:

```Swift
extension NSObject {
	public func eval<T>(_ expression: String, _ type: T.Type) -> T {
```

This takes a Swift expression as a String and returns an entity of the type specified.
There is also a shorthand function for expressions of type String which accepts the
contents of the String literal as it's argument:

```Swift
	public func eval(_ expression: String) -> String {
	    return eval("\"" + expression + "\"", String.self)
	}
```

An example of how it is used can be found in the EvalApp example.

```Swift
    @IBAction func performEval(_: Any) {
        textView.string = eval(textField.stringValue)
    }

    @IBAction func closureEval(_: Any) {
        if let block = eval(closureText.stringValue, (() -> ())?.self) {
            block()
        }
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

This release includes a very slightly modified version of the excellent
[canviz](https://code.google.com/p/canviz/) library to render "dot" files
in an HTML canvas which is subject to an MIT license. The changes are to pass
through the ID of the node to the node label tag (line 212), to reverse
the rendering of nodes and the lines linking them (line 406) and to
store edge paths so they can be colored (line 66 and 303) in "canviz-0.1/canviz.js".

It also includes [CodeMirror](http://codemirror.net/) JavaScript editor
for the code to be evaluated using injection under an MIT license.

$Date: 2020/08/09 $
