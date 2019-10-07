# InjectionIII - overdue Swift4 rewrite of Injection

![Icon](http://johnholdsworth.com/Syringe_128.png)

Code injection allows you to update the implementation of methods of a class incrementally
in the iOS simulator without having to rebuild or restart your application saving the developer a significant amount of time.
This start-over implementation of [Injection for Xcode](https://github.com/johnno1962/injectionforxcode)
has been built into a standalone app: `InjectionIII.app` which runs in the status bar and is [available from the Mac App Store](https://itunes.apple.com/app/injectioniii/id1380446739?mt=12).

`InjectionII.app` expects to find your current Xcode at path `/Applications/Xcode.app` , works for `Swift` and `Objective-C` and can be used with [AppCode](https://www.jetbrains.com/objc/features/swift.html) but you need to have built your project using Xcode first to provide the logs used to determine how to compile the project.

To use injection, download and run the app then all you need to add one of the following to your application delegate's `applicationDidFinishLaunching:`

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
resources which connects over a local socket to the macOS app.
Once injection is connected, you'll be prompted to select the project directory for the app you wish to inject. This starts a `file watcher` in the Mac app and whenever
you save a Swift (or Objective-C) source in the project, the target app is messaged through the socket to compile, link, dynamically load and update the implementation of _classes_ in the file being injected. 
The file watcher can be disabled & enabled while the app is running using the status bar menu and
if the file watcher is disabled you can still force injections through manually using a hotkey `ctrl-=` (remember to save the file first!)
If you inject a subclass of `XCTest` it will try running that individual test inside your application provided it does not require test specific support code,
When you run your application without rebuilding (^⌘R), recent injections will be re-applied.

If you get an error from the compiler saying your source file is not found this is typically due to upper/lower case differences as in injection filenames are case sensitive. The easiest way to resolve this is to remove and re-add the file concerned to your project and rebuild. 

To detect when a class has been injected in your code (to reload a view controller for example) add an `@objc func
injected()` class or instance method.  The instance `@objc
func injected()` method relies on a "sweep" of all objects in your application to find those of
the class you have just injected which can be unreliable using `unowned` instance variables in particular. If you encounter problems, subscribe to the `"INJECTION_BUNDLE_NOTIFICATION"` instead.

If your project is organised across multiple directories, after you have selected the main project, you can add directories to be watched for file changes using the "Add Directory"
menu item. This list resets when you select a new project.

Included in this release is "Xprobe" which allows you to browse the objects in
you application through a web-like interface and execute code against them.

If you want to build this project
from source you'll need to use:

    git clone https://github.com/johnno1962/InjectionIII --recurse-submodules
    
### Available downloads

| Xcode 10.2+ |
| ------------- |
| [Mac app store](https://itunes.apple.com/app/injectioniii/id1380446739?mt=12) |

### Limitations

To work, [method dispatch](https://www.raizlabs.com/dev/2016/12/swift-method-dispatch/)
must be through the class' "vtable" and not be "direct" i.e. statically linked. This means
injection will not work for final methods or methods in final classes or structs. Injecting a file containing protocol definitions will likely not work.

The App Tracing functionality uses the trampoline implementation from [

If you are using Code Coverage, you will need to disable it or you may receive a:
>	`Symbol not found: ___llvm_profile_runtime` error.`

Go to `Edit Scheme -> Test -> Options -> Code Coverage` and (temporarily) disable.

Be mindful of global state -- If the file you're injecting as non instance-level variables e.g. singletons, static or global vars
they will be reset when you inject the code as the new method implementations will refer to the newly loaded
version of the class.

As injection needs to know how to compile swift files individually it is incompatible with building using
`Whole Module Optimisation`. One workaround for this is to build with `WMO` switched off so there are
logs of individual compiles available then switching `WMO` back on if it suits your project better.

### Storyboard injection

Sometimes when you are iterating over a UI it is useful to be able to inject storyboards. This works slightly differently from code injection. To inject changes to a storyboard scene, make you changes than build the project instead of saving the storyboard. The "nib" of the currently displayed view controlled should be reloaded and viewDidLoad etc. will be called.

### SwiftUI injection

Single file SwiftUI interfaces can be injected to give you an interactive preview experience even if you don't have `macOS Catalina` installed. First, you need to add one of the bundle loading commands above to your AppDelegate. Then, add the following to the #if DEbUD'd preview section of the SwiftUI file you are injecting:

```Swift
class Refresher {
    @objc class func injected() {
        UIApplication.shared.windows.first?.rootViewController =
            UIHostingController(rootView: ContentView())
    }
}
```
`ContentView()` in this code needs to be replaced with the same initial view as is used in your `SceneDelegate.swift` to initialise the `UIHostingController`. Even though ContentView is a struct and is therefore statically liked, if it is defined in the file being injected containing the `Refresher` class, the new implementation will take precedence when the interface reloads.

### Vaccine

Injection now includes the higher level `Vaccine` functionality, for more information consult the [project README](https://github.com/zenangst/Vaccine) or one of the [following](https://medium.com/itch-design-no/code-injection-in-swift-c49be095414c) [references](https://medium.com/@robnorback/the-secret-to-1-second-compile-times-in-xcode-9de4ec8345a1).

### App Tracing

The InjectionIII menu contains an item "Trace (Beta)" which can be used to enable logging of all Objective-C and non-final class method calls. This feature is experimental. Selecting the menu item again will turn the feature back off.

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

### eval() implementation

The code works by adding an extension to your class source containing the expression.
It then compiles and loads this new version of the class "swizzling" this extension onto
the original class. The expression can refer to instance members in the class containing
the eval class and global variables & functions  in other class sources.

The command to rebuild the class containing the eval is parsed out of the logs of the last
build of your application and the resulting object file linked into a dynamic library for
loading. In the simulator, it was just not possible to codesign a dylib so you have to
be running a small server "'signer", included in this project to do this alas.

### Acknowledgements:

This project includes code from [rentzsch/mach_inject](https://github.com/rentzsch/mach_inject),
[erwanb/MachInjectSample](https://github.com/erwanb/MachInjectSample) and
[davedelong/DDHotKey](https://github.com/davedelong/DDHotKey) under their
respective licenses.

The App Tracing functionality uses the [OliverLetterer/imp_implementationForwardingToSelector](https://github.com/OliverLetterer/imp_implementationForwardingToSelector) trampoline implementation via the [SwiftTrace](https://github.com/johnno1962/SwiftTrace) project under an MIT license.

This release includes a very slightly modified version of the excellent
[canviz](https://code.google.com/p/canviz/) library to render "dot" files
in an HTML canvas which is subject to an MIT license. The changes are to pass
through the ID of the node to the node label tag (line 212), to reverse
the rendering of nodes and the lines linking them (line 406) and to
store edge paths so they can be colored (line 66 and 303) in "canviz-0.1/canviz.js".

It now also includes [CodeMirror](http://codemirror.net/) JavaScript editor
for the code to be evaluated using injection under an MIT license.
