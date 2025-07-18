# BUILD file for hot reload tools

py_binary(
    name = "hot_reload_compiler",
    srcs = ["hot_reload_compiler.py"],
    main = "hot_reload_compiler.py",
    visibility = ["//visibility:public"],
    deps = [],
)

sh_binary(
    name = "setup_injection",
    srcs = ["setup_injection.sh"],
    visibility = ["//visibility:public"],
)

filegroup(
    name = "all_tools",
    srcs = [
        ":hot_reload_compiler",
        ":setup_injection",
    ],
    visibility = ["//visibility:public"],
)