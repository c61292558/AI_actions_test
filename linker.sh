#!/bin/bash
# 安全读取配置文件的推荐方式
read_config() {
    local config_file="$1"

    # 检查文件是否存在
    if [ ! -f "$config_file" ]; then
        echo "Error: Config file $config_file not found" >&2
        return 1
    fi

    # 处理并加载配置
    source <(
        sed -nE '
            # 跳过注释和空行
            /^[[:space:]]*#/d    # 删除注释行
            /^[[:space:]]*$/d     # 删除空行
            # 转换 @VAR@=value 格式
            s/^@([^@]+)@=(.*)$/\1=\2/p
        ' "$config_file"
    )
}


read_config "ace-base-build.config"

# 访问变量
echo "Package Name: $PKG_NAME"
echo "Host Name: $HOST_NAME"
echo "Executable Name: $EXEC_NAME"
echo "Pretty Name: $PRETTY_NAME"
echo "Version: $VERSION"
target_dir="${1}" 
	mkdir ${target_dir}/usr/bin
	ln -vfs ../../opt/apps/$PKG_NAME/files/bin/ace-run ${target_dir}/usr/bin/$EXEC_NAME
	ln -vfs ../../opt/apps/$PKG_NAME/files/bin/amber-ce-configure-nvidia ${target_dir}/usr/bin/$PKG_NAME-configure-nvidia
