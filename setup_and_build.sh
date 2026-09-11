#!/bin/bash
# ============================================================
# VolumeDoubleTapCamera 一键环境搭建 + 编译脚本
# 使用方法：
#   1. 把整个 VolumeDoubleTapCamera 文件夹拷到 WSL2 中
#      例如：cp -r /mnt/c/Users/Administrator/Desktop/测试越狱ai/VolumeDoubleTapCamera ~/
#   2. cd ~/VolumeDoubleTapCamera
#   3. bash setup_and_build.sh
#   4. 编译完成后，deb 包会生成在 packages/ 目录下
# ============================================================
set -e

echo "[1/5] 检查/安装依赖..."
sudo apt-get update -y
sudo apt-get install -y fakeroot perl rsync dpkg-dev ldid git build-essential

echo "[2/5] 检查 Theos..."
if [ ! -d "$HOME/theos" ]; then
    echo "  Theos 未安装，正在克隆..."
    git clone --recursive https://github.com/theos/theos.git "$HOME/theos"
else
    echo "  Theos 已存在，跳过。"
fi

echo "[3/5] 检查 SDK..."
if [ ! -d "$HOME/theos/sdks/iPhoneOS14.5.sdk" ]; then
    echo "  SDK 未安装，正在克隆..."
    if [ ! -d "$HOME/theos/sdks" ]; then
        git clone https://github.com/theos/sdks.git "$HOME/theos/sdks"
    else
        echo "  sdks 目录已存在，跳过克隆。"
    fi
fi

# 写入环境变量（如果尚未写入）
if ! grep -q "export THEOS=" "$HOME/.bashrc"; then
    echo 'export THEOS=$HOME/theos' >> "$HOME/.bashrc"
fi
export THEOS="$HOME/theos"

echo "[4/5] 开始编译..."
make clean
make package FINALPACKAGE=1

echo "[5/5] 完成！"
echo "===================================="
echo "编译产物位于："
ls -lh "$PWD/packages/"*.deb 2>/dev/null || echo "  (未找到 deb，请检查编译日志)"
echo "===================================="
echo "下一步：把 packages/ 下的 .deb 文件传到手机，用 Sileo 打开安装即可。"
