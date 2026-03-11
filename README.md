# 文件说明

* ace-base.config ：进行ACE配置的文件，构建出来的环境会使用此文件进行配置
* build-pkg.sh ：构建ACE目录文件的工具，整合了 replacer 和 linker 的操作
* replacer.sh ：根据 ace-base.config 进行目录和文件中的特定字符串替换，让如 @PKG_NAME@ 的文件和内容被替换为配置好的内容
* linker.sh ：根据 ace-base.config 来创建/usr/bin下的程序入口

# 构建指南

## Debian构建

0. 配置 ace-base.config

```
@PKG_NAME@=包名,应当为 amber-ce-`execname的前缀`，如 bookworm-run 对应的包名应当为 amber-ce-bookworm
@HOST_NAME@=HOST名，在终端中标识当前的ACE,应当为 Amber-CE-PrettyName
@EXEC_NAME@=应当为codename-run,若不是debian系列，可以是其他的方法命名，如deepin23-run
@PRETTY_NAME@=会展示在integration的desktop上（安装后的应用在启动器后面括号的名称，一般为codename）
@VERSION@=内部OS版本号.ACE版本号，如13.7.5 意为 Debian 13,使用ACE 7.5 版本构建
@CODE_NAME@=debian或deepin的codename,如bookworm,trixie,sid，用于构建

```


> 请注意，只在内部 rootfs 为使用deb软件包的发行版时才会自动处理.desktop，否则需在容器中手动执行 /opt/ace-host-integration/ace-host-integration 来完成处理

请务必在最后一行空一行，否则读取时无法读取到最后一行

1. 直接执行 `debian-build.sh`即可一键完成构建

## 其他发行版构建（Fedora/Arch）

0. 配置 ace-base.config

```
@PKG_NAME@=包名,应当为 amber-ce-`execname的前缀`，如 bookworm-run 对应的包名应当为 amber-ce-bookworm
@HOST_NAME@=HOST名，在终端中标识当前的ACE,应当为 Amber-CE-PrettyName
@EXEC_NAME@=应当为codename-run,若不是debian系列，可以是其他的方法命名，如deepin23-run
@PRETTY_NAME@=会展示在integration的desktop上（安装后的应用在启动器后面括号的名称，一般为codename）
@VERSION@=内部OS版本号.ACE版本号，如13.7.5 意为 Debian 13,使用ACE 7.5 版本构建
@CODE_NAME@=debian或deepin的codename,如bookworm,trixie,sid，用于构建

```


> 请注意，只在内部 rootfs 为使用deb软件包的发行版时才会自动处理.desktop，否则需在容器中手动执行 /opt/ace-host-integration/ace-host-integration 来完成处理

请务必在最后一行空一行，否则读取时无法读取到最后一行

1. 复制 src 为 pkg 

2. 于根目录下打开终端，执行 `build-pkg.sh pkg`

3. pkg 目录下，DEBIAN文件夹内为应用钩子相关信息，其他目录应当被安装到 / 下。请根据不同的构建系统进行特定的处理

## 自定义rootfs的ACE兼容环境

自定义 ACE 需自行准备rootfs，`build-pkg.sh`不再被使用，您需要手动执行一些步骤，一步一步来，这并不复杂

0. 配置 ace-base.config

```
@PKG_NAME@=包名,应当为 amber-ce-`execname的前缀`，如 bookworm-run 对应的包名应当为 amber-ce-bookworm
@HOST_NAME@=HOST名，在终端中标识当前的ACE,应当为 Amber-CE-PrettyName
@EXEC_NAME@=应当为codename-run,若不是debian系列，可以是其他的方法命名，如deepin23-run
@PRETTY_NAME@=会展示在integration的desktop上（安装后的应用在启动器后面括号的名称，一般为codename）
@VERSION@=内部OS版本号.ACE版本号，如13.7.5 意为 Debian 13,使用ACE 7.5 版本构建
@CODE_NAME@=此处可不写

```
1. 完成文件复制和架构填写

执行

```
cp -r src pkg
cp ace-base.config ace-base-build.config
echo "@ARCH@=$(dpkg --print-architecture)" >> ace-base-build.config
```

若您没有安装dpkg，也可改为 @ARCH@=amd64 

2. 放置rootfs

请把您构建好的rootfs进行tar.xz压缩，重命名为 ace-env.tar.xz 并放置到 pkg/opt/apps/@PKG_NAME@/files/

3. 执行文件替换和可执行文件创建

bash replacer.sh pkg/
bash linker.sh pkg/

4. 进行构建

若您准备构建deb软件包，执行 `dpkg-deb -Z gzip -b pkg/ ./` 即可获取到软件包

若您准备构建其他格式的软件包，pkg 目录下，DEBIAN文件夹内为应用钩子相关信息，其他目录应当被安装到 / 下。请根据不同的构建系统进行特定的处理。
