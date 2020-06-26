# Protobuf Bazel Rules

Custom protobuf rules that support breaking the bazel sandbox to write files into the source directory, while maintaining support for caching.

## Usage
```
http_archive(
    name = "zouai_protobuf",
    urls = ["https://github.com/zouai-io/bazel-protobuf/archive/v0.0.1.zip"],
    sha256 = "a228873999c844a815da7798adc235790caf784c57b21e5e479173258487b34a",
    strip_prefix = "bazel-protobuf-0.0.1"
)

load("@zouai_protobuf//:protobuf.bzl", "protoc_deps")

# protoc_deps will download the appropriate protoc and plugins as tools
protoc_deps(name = "protoc")
```