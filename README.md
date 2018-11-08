# InjectionIII - overdue Swift4 rewrite of Injection

![Icon](http://johnholdsworth.com/Syringe_128.png)

This start-over implementation on [Injection for Xcode](https://github.com/johnno1962/injectionforxcode)
has been built into an app: InjectionIII.app included in the repo which runs in the status bar.
Code injection allows you to update the implementation of methods of a class incrementally
in the iOS simulator without having to rebuild or restart your application saving developer time.
You can avoid the complications of code signing by using the pre-built binary which is available to
[download here](http://johnholdsworth.com/InjectionIII.app.zip).  For some reason you may need
to take the app out of qurantine manually or it will report it as damaged when you run it: `xattr -d
com.apple.quarantine ~/Downloads/InjectionIII.app`. To use, copy/link it to /Applications
and run the app. Injection also expects to find your current Xcode at path /Appplications/Xcode.app.
Finally, you'll need to add one of the following to your application's applicationDidFinishLaunching:

```Swift
#if DEBUG
Bundle(path: "/Applications/InjectionIII.app/Contents/Resources/iOSInjection.bundle")?.load()
//for tvOS:
Bundle(path: "/Applications/InjectionIII.app/Contents/Resources/tvOSInjection.bundle")?.load()
//Or for macOS:
Bundle(path: "/Applications/InjectionIII.app/Contents/Resources/macOSInjection.bundle")?.load()
#endif
```
Or, for Xcode 10:

```Swift
#if DEBUG
Bundle(path: "/Applications/InjectionIII.app/Contents/Resources/iOSInjection10.bundle")?.load()
//for tvOS:
Bundle(path: "/Applications/InjectionIII.app/Contents/Resources/tvOSInjection10.bundle")?.load()
//Or for macOS:
Bundle(path: "/Applications/InjectionIII.app/Contents/Resources/macOSInjection10.bundle")?.load()
#endif
```

Once injection is connected, a file watcher is started in the InjectionIII app and whenever
you save a Swift or Objective-C source the target app is messaged to update the implementation.
The file watcher can be disabled & enabled while the app is running using the status bar menu.
While the file watcher is disabled you can force injection's through manually using a hotkey ctrl-=.
If you inject a subclass of XCTest it will try running that individual test inside your application.
When you run your application without rebuilding (^⌘R), recent injections will be re-applied.

Included is a manual implementation of ["code injection"](InjectionBundle/SwiftInjection.swift).
If you are stopped in a class, you can edit the class' implementation, save it and type
"p inject()". Your changes will be applied without having to restart the application.
To detect this in your code to reload a view controller for example, add an @objc
injected() method or subscribe to the `"INJECTION_BUNDLE_NOTIFICATION"`.

Included in this release is "Xprobe" which allows you to browse the objects in
you application as a graph and execute code against them. If you want to build
from source you'll need to use:

    git clone https://github.com/johnno1962/InjectionIII --recurse-submodules
    
### Available downloads

| Xcode 9.3/4, Xcode 10 |
| ------------- |
| [Mac app store](https://itunes.apple.com/app/injectioniii/id1380446739?mt=12) |

### Limitations

To work, [method dispatch](https://www.raizlabs.com/dev/2016/12/swift-method-dispatch/)
must be through the classes "vtable" and not be "direct" i.e. statically linked. This means
injection will not work for final methods or methods in final classes or structs. The `@objc
func injected()` method relies on a sweep of all objects in your application to find those of
the class you have just injected which can fail. If you encounter problems, use the notification.

If you are using Code Coverage, you will need to disable it or you may receive a:
>	`Symbol not found: ___llvm_profile_runtime` error.`

Go to `Edit Scheme -> Test -> Info -> Code Coverage` and (temporarily) disable.

Be mindful of global state -- If the file you're injecting as non instance-level variables e.g. singletons
they will be reset when you inject the code as the new implementations will refer to the newly loaded
version of the class.

As injection needs to know how to compile swift files individually it is incompatible with building using
whole module optimisation. A workaround for this is to build with WMO switched off so there are
logs of individual compiles then switching it back on if it suits your project best.

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

### implementation

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

This release includes a very slightly modified version of the excellent
[canviz](https://code.google.com/p/canviz/) library to render "dot" files
in an HTML canvas which is subject to an MIT license. The changes are to pass
through the ID of the node to the node label tag (line 212), to reverse
the rendering of nodes and the lines linking them (line 406) and to
store edge paths so they can be colored (line 66 and 303) in "canviz-0.1/canviz.js".

It now also includes [CodeMirror](http://codemirror.net/) JavaScript editor
for the code to be evaluated using injection under an MIT license.
