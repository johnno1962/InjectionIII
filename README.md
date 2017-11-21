# InjectionIII - overdue Swift rewrite of Injection

![Icon](http://johnholdsworth.com/Syringe_128.png)

This start-over implementation on [Injection for Xcode](https://github.com/johnno1962/injectionforxcode) has been built into an app: InjectionIII.app included in the
repo which runs in the status bar. To use, run the app, copy/link it to /Applications and add
one of the following to your applicationDidFinishLaunching:

```
#if DEBUG
Bundle(path: "/Applications/InjectionIII.app/Contents/Resources/iOSInjection.bundle")?.load()
//Or for macOS:
Bundle(path: "/Applications/InjectionIII.app/Contents/Resources/macOSInjection.bundle")?.load()
#endif
```

Once your application starts, a file watcher is started in the InjectionIII app and whenever
you save a Swift or Objective-C source the target app is messaged to update the implementation.
The file watcher can be disabled & enabled while the app is running using the status bar menu.

Included is a manual implementation of ["code injection"](InjectionBundle/SwiftInjection.swift).
If you are stopped in a class, you can edit the class' implementation, save it and type
"p inject()". Your changes will be applied without having to restart the application.
To detect this in your code to reload a view controller for example, add an @objc
injected() method or subscribe to the "INJECTION\_BUNDLE\_NOTIFICATION".

### Limitations

To work, method dispatch must be through the classes "vtable" and not be "direct" i.e. statically
linked. This means injection will not work for final methods or methods in final classes or structs.
The  -injected method relies on a sweep of all objects in your application to find those of the class
you have just injected and can be ambitious. If you encounter problems, use the notification. Also,
as injection needs to know how to compile swift files individually it it incompatible with building using
whole module optimization. A workaround for this is to build with WMO switched off so there are
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
