#!/usr/bin/env bash
set -euo pipefail

PKG_DIR="pkg"
DEBIAN_DIR="$PKG_DIR/DEBIAN"
FIX_DIRS=()

red()    { printf '\033[31m%b\033[0m\n' "$*"; }
green()  { printf '\033[32m%b\033[0m\n' "$*"; }
yellow() { printf '\033[33m%b\033[0m\n' "$*"; }

# 1. 检测DEBIAN及其内部文件是否为755
check_debian_755(){
  [[ -d $DEBIAN_DIR ]] || { red "错误：未找到 $DEBIAN_DIR 目录"; exit 1; }
  local bad_list=()
  while IFS= read -r -d '' f; do
    [[ $(stat -c '%a' "$f") == "755" ]] || bad_list+=("$f")
  done < <(find "$DEBIAN_DIR" -type f -print0)
  if [[ ${#bad_list[@]} -gt 0 ]]; then
    red "以下文件权限不是 755："
    printf '  %s\n' "${bad_list[@]}"
    exit 1
  else
    green "DEBIAN 目录及其文件权限均为 755，通过"
  fi
}
#1.1
check_and_fix_pkg_dir_permissions() {
  local pkg_base="./pkg"
  [[ -d "$pkg_base" ]] || { red "错误：未找到 $pkg_base 目录"; return 1; }

  local bad_dirs=()
  local bad_perms=()

  # 递归查找所有目录，排除 DEBIAN
  while IFS= read -r -d '' dir; do
    # 过滤掉 pkg 本身（可选）
    [[ "$dir" == "$pkg_base" ]] && continue

    # 获取八进制权限
    local perm=$(stat -c '%a' "$dir")
    
    # 检测：只要【所有者、组、其他】中任何一位是偶数(0,2,4,6)，就表示缺少 x
    if [[ "$perm" =~ [0246]$ ]] || [[ "$perm" =~ [0246].$ ]] || [[ "$perm" =~ [0246]..$ ]]; then
      bad_dirs+=("$dir")
      bad_perms+=("$perm")
    fi
  done < <(find "$pkg_base" -path "$pkg_base/DEBIAN" -prune -o -type d -print0)

  if [[ ${#bad_dirs[@]} -gt 0 ]]; then
    yellow "检测到以下目录缺失 x 权限（所有者/组/其他）："
    echo "------------------------------------------------"
    # 打印缺失权限的目录列表
    for i in "${!bad_dirs[@]}"; do
      printf "  [权限:%s]  %s\n" "${bad_perms[$i]}" "${bad_dirs[$i]}"
    done
    echo "------------------------------------------------"
    
    # 自动修复
    yellow "正在为上述目录添加 a+x 权限..."
    for d in "${bad_dirs[@]}"; do
      chmod a+x "$d"
    done
    green "修复完成！"
  else
    green "pkg 目录下所有文件夹（含子目录）均已具备执行权限。"
  fi
}

# 2. 检查 maintainer scripts 中 rm 路径是否被 "" 包裹
check_rm_quotes(){
  local scripts=()
  for f in postinst preinst postrm prerm; do
    [[ -f $DEBIAN_DIR/$f ]] && scripts+=("$DEBIAN_DIR/$f")
  done
  [[ ${#scripts[@]} -eq 0 ]] && return

  local err=0
  for s in "${scripts[@]}"; do
    # 逐行扫描，跳过注释行
    awk '
    /^[[:space:]]*#/ { next }
    {
      # 从第一个字段开始找 rm 命令
      for(i=1;i<=NF;i++){
        if($i ~ /^rm$/){               # 找到 rm
          # 从 i+1 开始向后找第一个不以 "-" 开头的字段（即真正的路径）
          for(j=i+1;j<=NF;j++){
            if($j !~ /^-/){            # 跳过 -rf 等选项
              path=$j
              # 如果路径不是以双引号开头，就报错
              if(path !~ /^"/){
                print FILENAME":"NR": 路径未用引号包裹： "path
                exit 1
              }
              break
            }
          }
        }
      }
    }' "$s" || err=1
  done
  [[ $err -eq 0 ]] && green "maintainer scripts 中 rm 路径检查通过"
}

# 3. 检测pkg下所有子目录是否有x权限
check_dir_x(){
  FIX_DIRS=()
  while IFS= read -r -d '' d; do
    [[ -x $d ]] || FIX_DIRS+=("$(realpath "$d")")
  done < <(find "$PKG_DIR" -type d -print0)
  if [[ ${#FIX_DIRS[@]} -gt 0 ]]; then
    yellow "以下路径没有 x 权限，不能进入："
    printf '  %s\n' "${FIX_DIRS[@]}"
    read -rp "是否一次性为这些目录添加 x 权限？(y/N) " ans
    if [[ $ans =~ ^[Yy]$ ]]; then
      chmod a+x "${FIX_DIRS[@]}"
      green "已修复"
    else
      red "用户取消，脚本退出"; exit 1
    fi
  else
    green "所有子目录均已具备 x 权限"
  fi
}

# 4. 根据control包名检查图标MD5（不退出）
check_icon_md5(){
  local pkg_name
  pkg_name=$(grep -m1 '^Package:' "$DEBIAN_DIR/control" | awk '{print $2}')
  [[ -n $pkg_name ]] || { red "无法从 control 解析包名"; exit 1; }
  local icon_path="$PKG_DIR/usr/share/icons/${pkg_name}.png"
  [[ -f $icon_path ]] || { green "图标文件不存在，跳过 MD5 检查"; return; }

  local md5
  md5=$(md5sum "$icon_path" | awk '{print $1}')
  if [[ $md5 == "2b58f846d96686a94a2dde366cb8fe8f" ]]; then
    red "你没有修改过 icons 下的图标文件！"
    # 不再exit，继续往下执行
  else
    green "图标 MD5 已变更，继续执行后续流程……"
  fi
}

# 5. 输出.desktop文件中的Exec行
print_desktop_exec(){
  local app_dir="$PKG_DIR/usr/share/applications"
  [[ -d $app_dir ]] || { green "未找到 $app_dir 目录，跳过 .desktop 检查"; return; }

  local desktop_files=("$app_dir"/*.desktop)
  # 当无文件时bash会保留原通配符字符串，需排除
  [[ -e ${desktop_files[0]} ]] || { green "$app_dir 中无 .desktop 文件"; return; }

  green "—— .desktop 文件中 Exec 行 ——"
  for df in "${desktop_files[@]}"; do
    [[ -f $df ]] || continue
    # 只输出Exec所在行
    grep -H "^Exec=" "$df" || true
  done
}

# 6. 检测 pkg/opt/apps/包名/files/ace-env.tar.xz 是否存在（仅提示）
check_ace_env_tar(){
  local pkg_name
  pkg_name=$(grep -m1 '^Package:' "$DEBIAN_DIR/control" | awk '{print $2}')
  [[ -n $pkg_name ]] || { yellow "无法解析包名，跳过 ace-env.tar.xz 检查"; return; }

  local tar_path="$PKG_DIR/opt/apps/$pkg_name/files/ace-env.tar.xz"
  if [[ -f $tar_path ]]; then
    green "存在 ace-env.tar.xz：$(realpath "$tar_path")"
  else
    yellow "未找到 ace-env.tar.xz：$tar_path"
  fi
}
#7.创建info，entries等文件夹
update_pkg_structure() {
    local pkg_dir="pkg"
    local control_file="$pkg_dir/DEBIAN/control"
    local info_template="info" # 假设脚本同级目录下名为 info

    # 1. 检查必要文件是否存在
    if [[ ! -f "$control_file" ]]; then
        echo "错误: 未找到 $control_file"
        return 1
    fi

    # 2. 从 control 文件提取 Package 和 Version
    local package_name=$(grep '^Package:' "$control_file" | awk '{print $2}' | tr -d '\r')
    local version_val=$(grep '^Version:' "$control_file" | awk '{print $2}' | tr -d '\r')

    if [[ -z "$package_name" ]]; then
        echo "错误: 无法从 control 文件提取包名"
        return 1
    fi

    echo "正在处理包: $package_name (版本: $version_val)"

    # 3. 从 .desktop 文件提取 Name 值
    local desktop_file=$(find "$pkg_dir/usr/share/applications" -name "*.desktop" | head -n 1)
    if [[ -z "$desktop_file" ]]; then
        echo "警告: 未找到 .desktop 文件，无法提取 Name 字段"
        local app_name="Unknown"
    else
        # 提取 Name= 之后的内容，只取第一行
        local app_name=$(grep '^Name=' "$desktop_file" | head -n 1 | cut -d'=' -f2- | tr -d '\r')
    fi

    # 4. 创建目标目录并复制资源
    local target_base="$pkg_dir/opt/apps/$package_name"
    local entries_dir="$target_base/entries"

    if [[ -d "$entries_dir" ]]; then
        echo "提示: $entries_dir 已存在，执行覆盖复制..."
    fi

    mkdir -p "$entries_dir"
    
    # 复制 applications 和 icons
    cp -rf "$pkg_dir/usr/share/applications" "$entries_dir/"
    cp -rf "$pkg_dir/usr/share/icons" "$entries_dir/"

    # 5. 处理 info 文件并更新字段
    if [[ -f "$info_template" ]]; then
        local target_info="$target_base/info"
        
        # 使用 sed 进行简单替换 (适用于标准格式的 JSON)
        # 注意：这里使用了临时文件来确保修改成功
        sed -e "s/\"appid\": \".*\"/\"appid\": \"$package_name\"/" \
            -e "s/\"version\": \".*\"/\"version\": \"$version_val\"/" \
            -e "s/\"name\": \".*\"/\"name\": \"$app_name\"/" \
            "$info_template" > "$target_info"
            
        echo "已更新并复制 info 文件到: $target_info"
    else
        echo "错误: 脚本目录下未找到 info 模板文件"
    fi

    echo "处理完成！"
}



# ------------------ main ------------------
update_pkg_structure
check_debian_755
check_and_fix_pkg_dir_permissions
check_rm_quotes
check_dir_x
check_icon_md5
print_desktop_exec
check_ace_env_tar      # <-- 新增调用
echo "检测钩子脚本语法："
#find pkg/DEBIAN -type f -regex ".*\(postinst\|postrm\|preinst\|prerm\)" -exec shellcheck {} +
# ===== 后续 Bash 代码 =====
echo "请自行继续执行后续代码……"
# 这里放你真正需要继续执行的命令
# dpkg-deb -b "$PKG_DIR" "${PKG_DIR}.deb"