
# Injection

支持 OC、Swift 以及 Swift 和 OC 混编项目的 UI 热重载工具，采取在**模拟器**(真机不支持)注入方式实现 UI 热重载，修改完 UI 直接 `cmd + s`，不用重新编译运行就能看到 UI 效果。👉🏻 [Github](https://github.com/johnno1962/InjectionIII) 👈🏻

而且 [AppStore](https://apps.apple.com/cn/app/injectioniii/id1380446739) 也有发布。
目前已经更新支持 Xcode 13 和 iOS 15。

**最新消息：** 自从 4.4.0+ 版本开始，针对 iOS/tvOS 14+ 使用 InjectionIII 时，可以不用运行 InjectionIII 了，只需要在代码中集成加载 `injection bundles` 的代码就可以了。目前为止，这是最简单的使用 InjectionIII 的方式，而且不需要手动选择项目的文件夹目录。当 InjectionIII.app 没有运行时，bundle 将回退使用 HotReloading 的 `standalone` 的实现方式，监视主目录中的文件更改，并使用由 File Watcher 确定的上次构建项目的构建日志。跳转 [Standalone Injection](#standalone-injection) 查看更多。

## 使用方法

### 1、Injection 安装

1. [github](https://github.com/johnno1962/InjectionIII) 下载最新 release 版本，或者 [AppStore](https://apps.apple.com/cn/app/injectioniii/id1380446739) 下载安装即可，推荐 [github](https://github.com/johnno1962/InjectionIII) 下载安装，github 更新比 AppStore 更新快。如果你的项目使用混编 OC 时，强烈建议使用 github 的 [releases](https://github.com/johnno1962/InjectionIII/releases) 版本。
   
2. 安装后，打开 InjectionIII，选择 Open Project，选择你的项目目录。
   
![image.png](https://p6-juejin.byteimg.com/tos-cn-i-k3u1fbpfcp/0d197c0ef51f43768c1d00b29ea29bc7~tplv-k3u1fbpfcp-watermark.image)

3. 选择的项目会在 Open Recent 中展示，同时保持 File Watcher 的选项勾选。
   
![image](https://user-images.githubusercontent.com/3097366/203244261-9069e96c-294d-466f-86ab-99e94896fd70.png)


### 2、项目配置

 1. AppDelegate 配置，在 `didFinishLaunchingWithOptions` 配置注入。
需要注意，先打开 InjectionIII 的 Resources 路径，确认 bundle 文件的正确路径

- OC 版本：

```objective-c
#if DEBUG
   // iOS
   [[NSBundle bundleWithPath:@"/Applications/InjectionIII.app/Contents/Resources/iOSInjection.bundle"] load];

   // 同时还支持 tvOS 和 MacOS，配置时只需要在 /Applications/InjectionIII.app/Contents/Resources/ 目录下找到对应的 bundle 文件,替换路径即可
#endif
```
        
- Swift 版本：

```swift
#if DEBUG 
do {
   let injectionBundle = Bundle.init(path: "/Applications/InjectionIII.app/Contents/Resources/iOSInjection.bundle")
   if let bundle = injectionBundle{
       try bundle.loadAndReturnError()
   } else {
        debugPrint("Injection 注入失败,未能检测到 Injection")
   }

} catch {
    debugPrint("Injection 注入失败 \(error)")
}
#endif
```

2. 此时启动项目，在控制台可以看到，表示注入成功了
 如果有多个项目都在使用 Injection，需要查看 Injection 链接路径是否正确，如果不正确，打开 Injection 菜单 -OPen Recent- 选择你需要注入的项目即可。
 
```
    💉 InjectionIII connected /Users/looha/Desktop/Project_lh/BVGenius/BVGenius.xcworkspace
    💉 Watching files under /Users/looha/Desktop/Project_lh/BVGenius
```

3. 注入页面文件配置

在需要热重载的页面 VC 中，实现 injected 方法，把操作 UI 方法添加到 injected 中即可。以 Swift 为例，比如 UI 操作都在 VC 的 viewDidLoad 中，那么就在 injected 添加 viewDidLoad 方法即可。如果项目都想使用，直接添加到 baseVC 即可。
 
 Swift:
 
 ```swift
    @objc func injected()  {
       #if DEBUG 

       self.viewDidLoad()

       #endif
    }
```

4. 在 UI 阶段，修改外 UI，直接 `cmd + s` 就能看到效果，部分页面可能需要重新进入该页面才能看到效果。
ps：当你的项目使用 unowned 时，项目都配置完成并没有报错，但是修改完 UI，按 `cmd + s` 并没有相应的效果，则删除 injected 方法，在需要热重载的界面（或者 baseVC）添加通知 `INJECTION_BUNDLE_NOTIFICATION` 即可。

```swift
NotificationCenter.default.addObserver(self, selector:#selector(hotReloadingUI), name: Notification.Name("INJECTION_BUNDLE_NOTIFICATION"), object: nil)
```

## 使用 InjectionIII 的变化：

### Standalone Injection

自从 4.4.* 版本，这是推荐的使用方式，因为它需要更少的步骤就能“正常工作”。所有 Injection 需要的都会在模拟器内执行，它通过 `~/Library/Developer/Xcode/DerivedData` 目录中最近修改的“.wcactivitylog”文件（最近一次构建项目的构建日志的 gzip 压缩文件）自动确定使用哪个项目和构建日志。默认情况下，File Watcher 会监视 home 主目录中源文件的所有更改。

与之前一样，你需要在你项目 `target` 中的 `Other Linker Flags` 添加 `-Xlinker -interposable` 标识符，并且下载 [release 版 InjectionIII](https://github.com/johnno1962/InjectionIII/releases) app 来使得代码中的 `iOSInjection.bundle` 可访问，但是 **不需要单独运行** InjectionIII App（如果你运行了，也能像之前一样工作）。

## 更多设置

1. Build Settings - Swift Compiler-Code Generation

```
   Compilation Mode - Debug 模式改为 Incremental
   Optimization Level - Debug 模式改为 No Optimization [-Onone]
```

2. 不支持 Swift 的 SWIFT_WHOLE_MODULE_OPTIMIZATION 模式，需要在关闭它

```
   User-Defined - 
   SWIFT_WHOLE_MODULE_OPTIMIZATION Debug模式改为NO
```

3. 如果想对 final 方法和 structs 方法热重载，在 Build Settings - Other Linker Flags 中加入 -Xlinker，-interposable

```
  项目编译报错：Can't find ordinal for imported symbol for architecture x86_64
  增加 -undefined，dynamic_lookup即可
```
       
![image.png](https://p9-juejin.byteimg.com/tos-cn-i-k3u1fbpfcp/ea18dd9722f84aab87c9fdf2cbdfa3d7~tplv-k3u1fbpfcp-watermark.image)

![image.png](https://p9-juejin.byteimg.com/tos-cn-i-k3u1fbpfcp/0a92e51cf8fe4b5d89f56e78d226a26a~tplv-k3u1fbpfcp-watermark.image)


4. 如果你的方法有默认参数，而报以下错误时，重新启动 App 即可

```
 💉 *** dlopen() error: dlopen(/var/folders/nh/gqmp6jxn4tn2tyhwqdcwcpkc0000gn/T/com.johnholdsworth.InjectionIII/eval101.dylib, 2): Symbol not found: _$s13TestInjection15QTNavigationRowC4text10detailText4icon6object13customization6action21accessoryButtonActionACyxGSS_AA08QTDetailG0OAA6QTIconOSgypSgySo15UITableViewCellC_AA5QTRow_AA0T5StyleptcSgyAaT_pcSgAWtcfcfA1_
  Referenced from: /var/folders/nh/gqmp6jxn4tn2tyhwqdcwcpkc0000gn/T/com.johnholdsworth.InjectionIII/eval101.dylib
  Expected in: flat namespace
 in /var/folders/nh/gqmp6jxn4tn2tyhwqdcwcpkc0000gn/T/com.johnholdsworth.InjectionIII/eval101.dylib ***
```

## 更加详细的问题请多在项目 README 和 issues 查找。
