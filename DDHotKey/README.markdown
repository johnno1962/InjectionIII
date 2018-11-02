# DDHotKey

Copyright &copy; Dave DeLong <http://www.davedelong.com>

## About

DDHotKey is an easy-to-use Cocoa class for registering an application to respond to system key events, or "hotkeys".

A global hotkey is a key combination that always executes a specific action, regardless of which app is frontmost.  For example, the Mac OS X default hotkey of "command-space" shows the Spotlight search bar, even if Finder is not the frontmost application.

## License

The license for this framework is included in every source file, and is repoduced in its entirety here:

Permission to use, copy, modify, and/or distribute this software for any purpose with or without fee is hereby granted, provided that the above copyright notice and this permission notice appear in all copies.  The software is provided "as is", without warranty of any kind, including all implied warranties of merchantability and fitness. In no event shall the authors or copyright holders be liable for any claim, damages, or other liability, whether in an action of contract, tort, or otherwise, arising from, out of, or in connection with the software or the use or other dealings in the software.

## Usage

### Including DDHotKey in your project

You will need to copy these six files into your project:

- DDHotKeyCenter.h
- DDHotKeyCenter.m
- DDHotKeyUtilities.h
- DDHotKeyUtilities.m
- DDHotKeyTextField.h
- DDHotKeyTextField.m

Your application will need to link against `Carbon.framework`, and you will need to compile your application with the Clang compiler.  DDHotKey has been tested with Xcode 5 on OS X Mavericks.  No attempt has been made to preserve backwards compatibility.

### Using DDHotKey in your code

When you wish to create a hotkey, you'll need to do so via the `DDHotKeyCenter` singleton.

You can register a hotkey in one of two ways: via a target/action mechanism, or with a block.  The target/action mechanism can take a single extra "object" parameter, which it will pass into the action when the hotkey is fired.  Only the `object` parameter is retained by the `DDHotKeyCenter`.  In addition, an `NSEvent` object is passed, which contains information regarding the hotkey event (such as the location, the keyCode, the modifierFlags, etc).

Hotkey actions must have one of two method signatures (the actual selector is irrelevant):

    //a method with a single NSEvent parameter
    - (void)hotkeyAction:(NSEvent*)hotKeyEvent;
    
 OR
 
    //a method with an NSEvent parameter and an object parameter
    - (void)hotkeyAction:(NSEvent*)hotKeyEvent withObject:(id)anObject;

The other way to register a hotkey is with a block callback.  The block must have the following signature:

	void (^)(NSEvent *);

`DDHotKeyCenter.h` contains a typedef statement to typedef this signature as a `DDHotKeyTask`, for convenience.

Any hotkey that you have registered via `DDHotKeyCenter` can be unregistered based on its target, its target and action, or its keycode and modifier flags.

DDHotKey also includes a rudimentary `DDHotKeyTextField`, which is an `NSTextField` subclass that simplifies the process of creating a key combination.  Simply drop an `NSTextField` into your xib and change its class to `DDHotKeyTextField`.  Programmatically, you'll get an NSTextField into which you can type arbitrary key combinations.  You access the resulting combination via the textfield's `hotKey` property.
