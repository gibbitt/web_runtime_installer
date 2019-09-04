#!/bin/bash

# 当前目录
WORK_PATH=$(cd `dirname $0`; pwd)

DEBUG=1

VERSION=1.0
JDK_VERSION=""
TOMCAT_VERSION=""
declare -a JDK_VERSIONS
JDK_VERSIONS=(
    "7u80-b15/jdk-7u80-linux-x64.tar.gz"
    "8u202-b08/jdk-8u202-linux-x64.tar.gz"
    "10.0.2+13/jdk-10.0.2_linux-x64_bin.tar.gz"
)
TOMCAT_VERSIONS=(
    "tomcat-8/v8.5.45/bin/apache-tomcat-8.5.45.tar.gz"
    "tomcat-9/v9.0.24/bin/apache-tomcat-9.0.24.tar.gz"
    "tomcat-7/v7.0.96/bin/apache-tomcat-7.0.96.tar.gz"
)

# 下载目录、安装目录、运行用户等的配置
DOWNLOAD_DIR=downloads
JDK_TARBALL_DIR=java
SITE_DIR=www
RUN_USER=www
RUN_GROUP=www
INSTALL_DIR=runtime
JDK_DIR=java
TOMCAT_DIR=tomcat

# 下载目录、安装目录、项目目录
DOWNLOAD_PATH="$WORK_PATH/$DOWNLOAD_DIR"
JDK_TARBALL_PATH="$WORK_PATH/$JDK_TARBALL_DIR"
INSTALL_PATH="$WORK_PATH/$INSTALL_DIR"
SITE_PATH="$WORK_PATH/$SITE_DIR"
JDK_TARBALL_NAME=""
TOMCAT_TARBALL_NAME=""

JDK_INSTALL_PATH="$INSTALL_PATH/$JDK_DIR"
TOMCAT_INSTALL_PATH="$INSTALL_PATH/$TOMCAT_DIR"
JDK_DOWNLOAD_URL="https://repo.huaweicloud.com/java/jdk/"
TOMCAT_DOWNLOAD_URL="http://mirror.bit.edu.cn/apache/tomcat/"

# 帮助文本
function print_help() {
    echo "==== JDK环境安装脚本 V${VERSION} ===="
    echo "Usage: $0 install | help"
}

function install() {
    # 选择版本
    select_jdk_version
    select_tomcat_version
    echo ""
    prepare_env
    download_files
    echo ""
    install_jdk
    install_tomcat

}

# 准备安装环境
function prepare_env() {
    echo -e "\n正在准备安装环境...\n\n"

    if [ 1 == $DEBUG ]; then
        echo -e "\n ========= \n"
        echo "           WORK PATH: $WORK_PATH"
        echo "         JDK VERSION: $JDK_VERSION"
        echo "  TOMCAT VERSION URL: $TOMCAT_VERSION"
        echo "        INSTALL PATH: $INSTALL_PATH"
        echo "    JDK INSTALL PATH: $JDK_INSTALL_PATH"
        echo " TOMCAT INSTALL PATH: $TOMCAT_INSTALL_PATH"
        echo -e "\n ========= \n"
    fi

    if [ ! -d "$DOWNLOAD_PATH" ]; then
        echo "创建下载目录：$DOWNLOAD_PATH"
        mkdir -pv "$DOWNLOAD_PATH"
    fi

    if [ ! -d "$INSTALL_PATH" ]; then
        echo "创建安装目录：$INSTALL_PATH"
        mkdir -pv "$INSTALL_PATH"
    fi

    if [ ! -d "$JDK_INSTALL_PATH" ]; then
        echo "创建JDK安装目录：$JDK_INSTALL_PATH"
        mkdir -pv "$JDK_INSTALL_PATH"
    fi

    if [ ! -d "$TOMCAT_INSTALL_PATH" ]; then
        echo "创建TOMCAT安装目录：$TOMCAT_INSTALL_PATH"
        mkdir -pv "$TOMCAT_INSTALL_PATH"
    fi

    if [ ! -d "$SITE_PATH" ]; then
        echo "创建项目目录：$SITE_PATH"
        mkdir -pv "$SITE_PATH"
    fi
}

# 下载源码包
function download_files () {
    if [ ! -f "$DOWNLOAD_PATH/$JDK_TARBALL_NAME" ]; then
        wget $JDK_DOWNLOAD_URL -O $DOWNLOAD_PATH/$JDK_TARBALL_NAME
    else
        echo "$JDK_TARBALL_NAME is already downloaded."
    fi
    if [ ! -f "$DOWNLOAD_PATH/$TOMCAT_TARBALL_NAME" ]; then
        wget $TOMCAT_DOWNLOAD_URL -O $DOWNLOAD_PATH/$TOMCAT_TARBALL_NAME
    else
        echo "$TOMCAT_TARBALL_NAME is already downloaded."
    fi
}

function install_jdk() {
    cd $JDK_INSTALL_PATH
    tar -zxf "$DOWNLOAD_PATH/$JDK_TARBALL_NAME" -C $JDK_INSTALL_PATH

    echo "* 请手动设置JDK环境变量"
    for jdk_dir in `ls $JDK_INSTALL_PATH`
    do
        echo ""
        echo "=== $jdk_dir"
        echo ""
        jdk_dir=$JDK_INSTALL_PATH/$jdk_dir
        echo "JAVA_HOME=$jdk_dir"
        echo "CLASS_PATH=.:\$JAVA_HOME/lib/dt.jar:\$JAVA_HOME/lib/tools.jar"
        echo "export PATH=\$PATH:\$JAVA_HOME/bin:\$JAVA_HOME/jre/bin"
        echo ""
    done
}

function install_tomcat() {
    cd $TOMCAT_INSTALL_PATH
    tar -zxf "$DOWNLOAD_PATH/$TOMCAT_TARBALL_NAME" -C $TOMCAT_INSTALL_PATH

    echo "* TOMCAT管理命令"
    for tomcat_dir in `ls $TOMCAT_INSTALL_PATH`
    do
        echo ""
        echo "=== $tomcat_dir"
        echo ""
        tomcat_dir=$TOMCAT_INSTALL_PATH/$tomcat_dir
        echo "启动：$tomcat_dir/bin/startup.sh"
        echo "停止：$tomcat_dir/bin/shutdown.sh"
    done
}

function select_jdk_version() {
    for i in "${!JDK_VERSIONS[@]}";
    do
        printf "%s) %s\n" `expr $i + 1` "${JDK_VERSIONS[$i]}"
    done
    default_version="1"
    read -p "Choose version, default[$default_version]: " version
    if [ "$version" == "" ]; then
        version=$default_version
    else
        version=`expr $version - 1`
    fi
    JDK_VERSION="${JDK_VERSIONS[$version]}"
    JDK_DOWNLOAD_URL=$JDK_DOWNLOAD_URL/$JDK_VERSION
    JDK_TARBALL_NAME=${JDK_VERSION/*\//""}
}

function select_tomcat_version() {
    for i in "${!TOMCAT_VERSIONS[@]}";
    do
        printf "%s) %s\n" `expr $i + 1` "${TOMCAT_VERSIONS[$i]}"
    done
    default_version="1"
    read -p "Choose version, default[$default_version]: " version
    if [ "$version" == "" ]; then
        version=$default_version
    else
        version=`expr $version - 1`
    fi
    TOMCAT_VERSION="${TOMCAT_VERSIONS[$version]}"
    TOMCAT_DOWNLOAD_URL=$TOMCAT_DOWNLOAD_URL/$TOMCAT_VERSION
    TOMCAT_TARBALL_NAME=${TOMCAT_VERSION/*\//""}
}

case "$1" in
    "help")
        print_help
        ;;
    "install")
        install
        ;;
    *)
        echo -e "\nUnknow parameters '$1'\n"
        print_help
        ;;
esac

