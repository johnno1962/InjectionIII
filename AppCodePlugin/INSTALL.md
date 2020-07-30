## Plugin to use InjectionIII inside AppCode

To install, download the file `Injection.jar` and use the ⚙️ icon in  AppCode/Preferences/Plugins to `Install plugin from disk...`. A new item will appear at the end of the `Run` menu, `Inject Source` after restarting AppCode. This can be used once a program is running and indexing has completed. It has a keyboard shortcut of control-=. You still need to add `"-Xlinker -interposable"` to your project's `"Other Linker Flags"` for the simulator Debug target. This plugin should be used instead of running the InjectionIII application once it is installed as it shares the same port.

Also available from the [Jetbrains plugin store](https://plugins.jetbrains.com/plugin/7187-injectioniii-for-appcode/).
