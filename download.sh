#!/bin/bash

# 脚本描述：批量下载CN区的igp300T码表地图 ZIP 文件，并解压。不确定是否适用于其他型号
# 每次下载前建议到官网 https://www.igpsport.cn/support/product?deviceName=BSC300T 手动下载一份，验证url

BASE_URL="https://igp-zh.oss-cn-hangzhou.aliyuncs.com/Mapinfo/V1/"
DOWNLOAD_DIR="map_zips"         # 存放下载的 ZIP 文件
TEMP_UNZIP_DIR="temp_unzip"     # 临时解压目录
FINAL_CONTENT_DIR="map_content" # 存放最终提取的内容
REGION_CODE="CN"				# 区域代码
AREA_RANGE=33 					# 省区代码范围

# --- 检查依赖 ---
if ! command -v curl &> /dev/null; then
    echo "错误: curl 未安装。请安装 curl 后再运行脚本。"
    exit 1
fi
if ! command -v unzip &> /dev/null; then
    echo "错误: unzip 未安装。请安装 unzip 后再运行脚本。"
    exit 1
fi

# 确保目录存在
mkdir -p "$DOWNLOAD_DIR"
mkdir -p "$TEMP_UNZIP_DIR"
mkdir -p "$FINAL_CONTENT_DIR"

echo "ZIP 文件将保存在: $DOWNLOAD_DIR"
echo "临时解压目录: $TEMP_UNZIP_DIR"
echo "最终内容将平铺保存在: $FINAL_CONTENT_DIR"
echo "-------------------------------------"
echo "警告: 如果不同 ZIP 文件提取出同名文件，解压时旧文件将被覆盖。"
echo "-------------------------------------"

echo "开始下载和处理文件..."

# 循环从 1 到 33
for i in $(seq 1 ${AREA_RANGE}); do
    
    FILE_NUMBER=$(printf "%02d" $i)
    FILE_NAME="${REGION_CODE}${FILE_NUMBER}00.zip"
    
    DOWNLOAD_URL="${BASE_URL}${FILE_NAME}"
    ZIP_PATH="${DOWNLOAD_DIR}/${FILE_NAME}"
    
    # 假设 ZIP 文件解压后会产生一个同名的目录
    INNER_FOLDER_NAME="${FILE_NAME%.zip}" # 例如 CN0100
    
    # 临时解压路径
    TEMP_PATH="${TEMP_UNZIP_DIR}/${INNER_FOLDER_NAME}"
    
    echo "--- (${i}/33) 处理文件: $FILE_NAME ---"

    # --- 1. 下载文件 ---
    echo "  > 正在下载..."
    curl -L --fail -sS "$DOWNLOAD_URL" -o "$ZIP_PATH"

    if [ $? -eq 0 ]; then
        echo "  ✅ 下载成功到 $ZIP_PATH"
        
        # --- 2. 临时解压缩 ---
        
        # 确保临时的解压目标目录是干净的
        rm -rf "$TEMP_PATH"
        mkdir -p "$TEMP_PATH"
        
        echo "  > 正在解压到临时目录 $TEMP_PATH ..."
        
        # 将 ZIP 文件内容解压到 $TEMP_PATH。
        # 由于 ZIP 内部包含 CNXX00 文件夹，所以最终结构是 $TEMP_PATH/CNXX00/...
        unzip -o -q "$ZIP_PATH" -d "$TEMP_PATH"
        
        if [ $? -ne 0 ]; then
            echo "  ❌ 警告: 临时解压 $FILE_NAME 失败。"
            continue
        fi

        # --- 3. 提取内部文件夹的内容并移动到最终目录 ---
        
        # 内部文件夹的完整路径，通常是 $TEMP_PATH/CNXX00
        INNER_CONTENT_PATH="${TEMP_PATH}/${INNER_FOLDER_NAME}"
        
        if [ -d "$INNER_CONTENT_PATH" ]; then
            echo "  > 正在提取内部文件夹 ($INNER_FOLDER_NAME) 内容并移动到 $FINAL_CONTENT_DIR..."
            
            # 使用 find 结合 mv 将所有内容移动到最终目录
            # `mv -t` 是 GNU mv 的特性，用于指定目标目录
            # `*` 在这里可能不够安全，因为可能存在隐藏文件或复杂的子目录结构
            
            # 移动所有内容 (包括隐藏文件，但不包括 . 和 ..)
            find "$INNER_CONTENT_PATH" -mindepth 1 -maxdepth 1 -exec mv -f {} "$FINAL_CONTENT_DIR" \;
            
            echo "  ✅ 内容提取成功。"
        else
            echo "  ❌ 错误: 在 $TEMP_PATH 中未找到预期的内部目录 ($INNER_FOLDER_NAME)。可能ZIP结构不一致。"
        fi
        
    else
        echo "  ❌ 失败: 下载 $FILE_NAME 失败。"
        rm -f "$ZIP_PATH" # 删除不完整的下载文件
    fi
done

echo "-------------------------------------"
echo "清理临时目录..."
rm -rf "$TEMP_UNZIP_DIR"

echo "所有文件处理完成。最终数据平铺在 $FINAL_CONTENT_DIR 目录中。"
