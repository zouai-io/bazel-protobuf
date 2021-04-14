def _protoc_runner(ctx, protoc, plugin, inputfile, flag, extension, outdir):
    outputs = []
    protocPath = "{}/{}".format(protoc.dirname, protoc.basename)
    mkdirCmd = "mkdir -p proto_out/protos"
    pluginPath = "--plugin={}/{}".format(plugin.dirname, plugin.basename)
    fileName = inputfile.basename.replace(".proto", "", 1)
    generatedFile = ctx.actions.declare_file(ctx.attr.name + "/" + fileName + "."+ extension)
    copyCmd = "cp proto_out/protos/{}.{} {}".format(fileName, extension, generatedFile.path)
    protocCmd = "{} {} {} {}/{}".format(protocPath, flag, pluginPath, inputfile.dirname, inputfile.basename)
    touchCmd = "touch proto_out/protos/{}.{}".format(fileName, extension)
    fullCmd = "{} && {} && {}; {}; exit 0;".format(mkdirCmd, protocCmd, touchCmd, copyCmd)
    print(fullCmd)
    ctx.actions.run_shell(
        outputs = [generatedFile],
        inputs = [inputfile],
        tools = [protoc, plugin],
        command = fullCmd,
    )
    outputs.append(generatedFile)

    copiedFile = ctx.actions.declare_file(ctx.attr.name + "/" + fileName + "."+extension + ".inplace")
    copyStage1 = "if [ -s {}/{} ]; then cp -f {}/{} $(realpath {})/{};fi".format(generatedFile.dirname, generatedFile.basename, generatedFile.dirname, generatedFile.basename, outdir.dirname, generatedFile.basename)
    copyStage2 = "cp {}/{} {}/{}".format(generatedFile.dirname, generatedFile.basename, copiedFile.dirname, copiedFile.basename)
    copyCmd = "{}; {}".format(copyStage1, copyStage2)

    ctx.actions.run_shell(
        inputs = [generatedFile],
        outputs = [copiedFile],
        execution_requirements = {
            "no-sandbox": "1",
            "no-cache": "1",
            "no-remote": "1",
            "local": "1",
        },
        command = copyCmd,
    )
    outputs.append(copiedFile)
    return outputs

def _protoc_runner_impl(ctx):
    protoc = ctx.file.protoc
    plugin = ctx.file.plugin
    inputfile = ctx.file.input
    flag = ctx.attr.flag
    extension = ctx.attr.extension
    outdir = ctx.file.outdir
    outputs = _protoc_runner(ctx, protoc, plugin, inputfile, flag, extension, outdir)
    return [DefaultInfo(files = depset(outputs))]


protoc_runner = rule(
    implementation = _protoc_runner_impl,
    attrs = {
        "protoc": attr.label(
            default = Label("@protoc//:protoc"),
            executable = True,
            allow_single_file = True,
            cfg = "host",
        ),
        "plugin": attr.label(
            allow_single_file = True,
            mandatory = True,
        ),
        "inputfile": attr.label(
            allow_single_file = True,
            mandatory = True,
        ),
        "flag": attr.string(
            mandatory = True,
        ),
        "extension": attr.string(
            mandatory = True,
        ),
        "outdir": attr.label(
            allow_single_file = True,
            mandatory = True,
        ),
    },
)

def _protoc_go_impl(ctx):
    outputs = []
    for i, d in enumerate(ctx.files.file):
        outputs = outputs + _protoc_runner(
            ctx = ctx,
            plugin = ctx.file._protoc_gen_go,
            inputfile = ctx.files.file[i],
            flag = "--go_out='paths=source_relative:proto_out'",
            extension = "pb.go",
            outdir = ctx.file.outdir,
            protoc = ctx.file._protoc,
        )
    gomod = ctx.actions.declare_file(ctx.attr.name + "/go.mod")
    ctx.actions.write(gomod, "module {}".format(ctx.attr.gopackage))
    outputs.append(gomod)
    return [DefaultInfo(files = depset(outputs))]

protoc_go = rule(
    implementation = _protoc_go_impl,
    attrs = {
        "include_paths": attr.string_list(),
        "file": attr.label_list(
            allow_files = [".proto"],
            mandatory = True,
        ),
        "gopackage": attr.string(
            mandatory = True,
        ),
        "outdir": attr.label(
            allow_single_file = True,
        ),
        "dart_outdir": attr.label(
            allow_single_file = True,
        ),
        "_protoc_gen_go": attr.label(
            default = Label("@protoc//:protoc-gen-go"),
            executable = True,
            allow_single_file = True,
            cfg = "host",
        ),
        "_protoc": attr.label(
            default = Label("@protoc//:protoc"),
            executable = True,
            allow_single_file = True,
            cfg = "host",
        ),
    },
)

def _local_repository_impl(repository_ctx):
    if repository_ctx.os.name == "windows":
        repository_ctx.download("https://gobin.zouai.io/binary/github.com/golang/protobuf/protoc-gen-go?os=windows&arch=amd64&version=v1.3.3", output = "protoc-gen-go", executable = True)
        repository_ctx.download_and_extract("https://github.com/protocolbuffers/protobuf/releases/download/v3.11.4/protoc-3.11.4-win64.zip", output = "protoczip")
        repository_ctx.symlink("protoczip/bin/protoc.exe", "protoc.exe")
    elif repository_ctx.os.name == "linux":
        repository_ctx.download("https://gobin.zouai.io/binary/github.com/golang/protobuf/protoc-gen-go?os=linux&arch=amd64&version=v1.3.3", output = "protoc-gen-go", executable = True)
        repository_ctx.download_and_extract("https://github.com/protocolbuffers/protobuf/releases/download/v3.11.4/protoc-3.11.4-linux-x86_64.zip", output = "protoczip")
        repository_ctx.symlink("protoczip/bin/protoc", "protoc")
    else:
        fail("Unknown Arch '{}'".format(repository_ctx.os.name))
    repository_ctx.file("BUILD.bazel", 'exports_files(["protoc-gen-go","protoc"])')

protoc_deps = repository_rule(
    implementation = _local_repository_impl,
    local = False,
)
