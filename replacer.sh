#!/usr/bin/env bash

########################################
# 配置部分
########################################
config_file="ace-base-build.config"  # 配置文件路径
if [[ -z "$1" ]];then
echo "Need TARGET DIR"
exit
fi
target_dir="${1}"   # 要处理的目标目录

########################################
# 读取 ace-base.config 生成替换字典
########################################
declare -A replacements

while IFS= read -r line; do
    # 跳过空行
    [[ -z "$line" ]] && continue
    
    # 匹配类似 @PKG_NAME@=amber-ce-bookworm 的格式
    if [[ "$line" =~ ^@(.*)@=(.*)$ ]]; then
        key="${BASH_REMATCH[1]}"
        val="${BASH_REMATCH[2]}"
        replacements["$key"]="$val"
    fi
done < "$config_file"

########################################
# 第一步：文本文件内容替换
########################################
# 定义一个函数来判断文件是否是文本文件（示例仅供参考）
is_text_file() {
    local f="$1"
    file --mime-type "$f" | grep -q "text/"
}

# 查找所有文件，逐一判断是否文本类型，如果是则进行内容替换
find "$target_dir" -type f -print0 | while IFS= read -r -d '' file; do
    if is_text_file "$file"; then
        for key in "${!replacements[@]}"; do
            # 用 sed 对文件内容进行替换
            sed -i "s|@$key@|${replacements[$key]}|g" "$file"
        done
    fi
done

########################################
# 第二步：先重命名文件
########################################
find "$target_dir" -type f -print0 | while IFS= read -r -d '' file; do
    # 拆分目录和文件名
    dir_path="$(dirname "$file")"
    filename="$(basename "$file")"

    newfilename="$filename"
    for key in "${!replacements[@]}"; do
        newfilename="${newfilename//@$key@/${replacements[$key]}}"
    done

    # 如果新文件名和原文件名不同，则执行重命名
    if [[ "$newfilename" != "$filename" ]]; then
        mv -v "$file" "$dir_path/$newfilename"
    fi
done

########################################
# 第三步：再重命名目录（由浅到深）
########################################
# 先按目录层级进行排序（层数少的先处理）
# awk -F/ '{print NF, $0}' 会将路径按 / 分割并统计层数，然后 sort -n 升序，层数越小越先处理
find "$target_dir" -type d | awk -F/ '{print NF, $0}' | sort -n | cut -d' ' -f2- | while IFS= read -r dir; do
    # 如果要连同最顶层目录一起改名，可以保留；若不需要改最顶层，可以加条件跳过
    # [ "$dir" = "$target_dir" ] && continue  # 如需跳过顶层可取消注释

    parent_path="$(dirname "$dir")"
    dirname_only="$(basename "$dir")"

    newdirname="$dirname_only"
    for key in "${!replacements[@]}"; do
        newdirname="${newdirname//@$key@/${replacements[$key]}}"
    done

    # 需要改名则执行
    if [[ "$newdirname" != "$dirname_only" ]]; then
        mv -v "$dir" "$parent_path/$newdirname"
    fi
done
    

echo "处理完成！"
