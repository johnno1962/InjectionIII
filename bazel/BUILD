# BUILD file for hot reload Bazel rules

filegroup(
    name = "hot_reload_rules",
    srcs = ["hot_reload.bzl"],
    visibility = ["//visibility:public"],
)

filegroup(
    name = "all_bazel_files",
    srcs = [
        "hot_reload.bzl",
        "//bazel/tools:all_tools",
    ],
    visibility = ["//visibility:public"],
)