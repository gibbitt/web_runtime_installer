#!/bin/bash

# 当前目录
WORK_PATH=$(cd `dirname $0`; pwd)
# 处理器核心数，用于多线程编译
CPU_COUNT=`cat /proc/cpuinfo| grep "processor"| wc -l`

DEBUG=1

VERSION=1.0
PHP_VERSION=""
NGINX_VERSION=""
PHP_VERSIONS=(7.2.9 )
NGINX_VERSIONS=(1.17.1 )

# 下载目录、安装目录、运行用户等的配置
DOWNLOAD_DIR=downloads
SITE_DIR=www
RUN_USER=www
RUN_GROUP=www
INSTALL_DIR=runtime
PHP_DIR=php
NGINX_DIR=nginx

# nginx编译配置
NGINX_COMPILE_ARGS="--user=www --group=www --with-http_ssl_module --with-http_stub_status_module --with-http_realip_module --with-threads"

# php编译配置
PHP_COMPILE_ARGS="--enable-bcmath \
--with-mysqli \
--with-pdo-mysql \
--with-iconv-dir \
--with-freetype-dir \
--with-jpeg-dir \
--with-png-dir \
--with-zlib \
--with-libxml-dir \
--enable-simplexml \
--enable-xml \
--disable-rpath \
--enable-bcmath \
--enable-soap \
--enable-zip \
--with-curl \
--enable-fpm \
--with-fpm-user=www \
--with-fpm-group=www \
--enable-mbstring \
--enable-sockets \
--with-gd \
--with-openssl \
--with-mhash \
--enable-opcache \
--disable-fileinfo"

# 源码包下载链接
PHP_TARBALL_NAME=""
PHP_TARBALL_DIR=""
NGINX_TARBALL_NAME=""
NGINX_TARBALL_DIR=""
PHP_DOWNLOAD_URL=""
NGINX_DOWNLOAD_URL=""


# 下载目录、安装目录、项目目录
DOWNLOAD_PATH="$WORK_PATH/$DOWNLOAD_DIR"
INSTALL_PATH="$WORK_PATH/$INSTALL_DIR"
SITE_PATH="$WORK_PATH/$SITE_DIR"

PHP_INSTALL_PATH="$INSTALL_PATH/$PHP_DIR/$PHP_VERSION"
NGINX_INSTALL_PATH="$INSTALL_PATH/$NGINX_DIR/$NGINX_VERSION"

# 帮助文本
function print_help() {
    echo "==== PHP环境安装脚本 V${VERSION} ===="
    echo "Usage: $0 install | help"
}

# 准备安装环境
function prepare_env() {
    echo -e "\n正在准备安装环境...\n\n"
    # 安装基础环境
    os=`Get_Dist_Name`
    case $os in
        "CentOS")
            centos_env
            ;;
        "Ubuntu")
            ubuntu_env
            ;;
        *)
            # 其他系统无法安装
            echo "脚本未支持在该系统下运行"
            exit 1
            ;;
    esac

    if [ 1 == $DEBUG ]; then
        echo -e "\n ========= \n"
        echo "       WORK PATH: $WORK_PATH"
        echo "   DOWNLOAD PATH: $DOWNLOAD_PATH"
        echo "    INSTALL PATH: $INSTALL_PATH"
        echo "PHP INSTALL PATH: $PHP_INSTALL_PATH"
        echo " NG INSTALL PATH: $NGINX_INSTALL_PATH"
        echo "PHP DOWNLOAD URL: $PHP_DOWNLOAD_URL"
        echo " NG DOWNLOAD URL: $NGINX_DOWNLOAD_URL"
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

    if [ ! -d "$SITE_PATH" ]; then
        echo "创建项目目录：$SITE_PATH"
        mkdir -pv "$SITE_PATH"
    fi

    # 创建www用户及用户组
    egrep "^$RUN_GROUP" /etc/group >& /dev/null
    if [ $? -ne 0 ]
    then
        groupadd $RUN_GROUP
    fi
    egrep "^$RUN_USER" /etc/passwd >& /dev/null
    if [ $? -ne 0 ]
    then
        useradd -g $RUN_GROUP $RUN_USER
    fi
}

# 下载源码包
function download_files () {
    if [ ! -f "$DOWNLOAD_PATH/$PHP_TARBALL_NAME" ]; then
        wget $PHP_DOWNLOAD_URL -O $DOWNLOAD_PATH/$PHP_TARBALL_NAME
    else
        echo "$PHP_TARBALL_NAME is already downloaded."
    fi
    if [ ! -f "$DOWNLOAD_PATH/$NGINX_TARBALL_NAME" ]; then
        wget $NGINX_DOWNLOAD_URL -O $DOWNLOAD_PATH/$NGINX_TARBALL_NAME
    else
        echo "$NGINX_TARBALL_NAME is already downloaded."

    fi
}

# 编译安装
function install() {
    select_php_version
    select_nginx_version
    # 环境准备
    prepare_env
    download_files

    # 编译
    compile_php
    compile_nginx

    #配置
    configure_php
    configure_nginx

    # 环境变量设置（用户自行设置）
    echo ""
    echo "请自行设置环境变量："
    echo ""
    echo "NGINX_PATH=$NGINX_INSTALL_PATH/sbin"
    echo "PHP_PATH=$PHP_INSTALL_PATH"
    echo "export PATH=\$PATH:\$NGINX_PATH/sbin:\$PHP_PATH/sbin:\$PHP_PATH/bin"
    echo ""
}


function compile_nginx () {
    if [ ! -d "$DOWNLOAD_PATH/$NGINX_TARBALL_DIR" ]; then
        if [ -f "$DOWNLOAD_PATH/$NGINX_TARBALL_NAME" ]; then
             tar -zxf "$DOWNLOAD_PATH/$NGINX_TARBALL_NAME" -C "$DOWNLOAD_PATH"
        fi
    fi
    cd "$DOWNLOAD_PATH/$NGINX_TARBALL_DIR"
    ./configure --prefix="$NGINX_INSTALL_PATH" $NGINX_COMPILE_ARGS
    make "-j$CPU_COUNT"
    make install
}

function configure_nginx() {
    config_path=$NGINX_INSTALL_PATH/conf
    cd $config_path
    mkdir -pv $config_path/conf.d
    cp -r nginx.conf.default nginx.conf
    # 修改运行用户
    sed -i "2s/#user.*/user www;/g" nginx.conf
    sed -i "N;116 a include conf.d/*.conf;" nginx.conf
    # php.conf
    echo "fastcgi_pass 127.0.0.1:9000;" > "php-${PHP_VERSION}.conf"
    echo "fastcgi_index index.php;" >> "php-${PHP_VERSION}.conf"
    echo "fastcgi_param SCRIPT_FILENAME  \$document_root\$fastcgi_script_name;" >> "php-${PHP_VERSION}.conf"
    echo "include fastcgi_params;" >> "php-${PHP_VERSION}.conf"
    # default site.conf
    echo "server {" > "conf.d/site.conf"
    echo "    listen 80;" >> "conf.d/site.conf"
    echo "    server_name 127.0.0.1;" >> "conf.d/site.conf"
    echo "    location / {" >> "conf.d/site.conf"
    echo "        root $SITE_PATH;" >> "conf.d/site.conf"
    echo "        index index.php index.html;" >> "conf.d/site.conf"
    echo "    }" >> "conf.d/site.conf"
    echo "    location ~ \\.php\$ {" >> "conf.d/site.conf"
    echo "        root $SITE_PATH;" >> "conf.d/site.conf"
    echo "        include php-${PHP_VERSION}.conf;" >> "conf.d/site.conf"
    echo "    }" >> "conf.d/site.conf"
    echo "}" >> "conf.d/site.conf"
}

function compile_php () {
    if [ ! -d "$DOWNLOAD_PATH/$PHP_TARBALL_DIR" ]; then
        if [ -f "$DOWNLOAD_PATH/$PHP_TARBALL_NAME" ]; then
             tar -zxf "$DOWNLOAD_PATH/$PHP_TARBALL_NAME" -C "$DOWNLOAD_PATH"
        fi
    fi
    cd "$DOWNLOAD_PATH/$PHP_TARBALL_DIR"
    ./configure --prefix="$PHP_INSTALL_PATH" \
        --with-config-file-path="$PHP_INSTALL_PATH/etc" \
        $PHP_COMPILE_ARGS
    make "-j$CPU_COUNT"
    make install
    # 复制配置文件
    cp -r php.ini-* "$PHP_INSTALL_PATH/etc"
}

function configure_php() {
    config_path=$PHP_INSTALL_PATH/etc
    cd $config_path
    # 配置文件
    cp -r php.ini-production php.ini
    cp -r php-fpm.conf.default php-fpm.conf
    cp -r php-fpm.d/www.conf.default php-fpm.d/www.conf
}

function centos_env () {
    yum install -y \
        libxml2* \
        openssl* \
        libcurl* \
        libjpeg* \
        libpng* \
        freetype* \
        libmcrypt* \
        gcc \
        make \
        wget
}

function ubuntu_env () {
    apt install -y gcc \
        make \
        openssl \
        curl \
        libbz2-dev \
        libxml2-dev \
        libjpeg-dev \
        libpng-dev \
        libfreetype6-dev \
        libzip-dev \
        wget
}


Get_Dist_Name()
{
    if grep -Eqii "CentOS" /etc/issue || grep -Eq "CentOS" /etc/*-release; then
        DISTRO='CentOS'
        PM='yum'
    elif grep -Eqi "Red Hat Enterprise Linux Server" /etc/issue || grep -Eq "Red Hat Enterprise Linux Server" /etc/*-release; then
        DISTRO='RHEL'
        PM='yum'
    elif grep -Eqi "Aliyun" /etc/issue || grep -Eq "Aliyun" /etc/*-release; then
        DISTRO='Aliyun'
        PM='yum'
    elif grep -Eqi "Fedora" /etc/issue || grep -Eq "Fedora" /etc/*-release; then
        DISTRO='Fedora'
        PM='yum'
    elif grep -Eqi "Debian" /etc/issue || grep -Eq "Debian" /etc/*-release; then
        DISTRO='Debian'
        PM='apt'
    elif grep -Eqi "Ubuntu" /etc/issue || grep -Eq "Ubuntu" /etc/*-release; then
        DISTRO='Ubuntu'
        PM='apt'
    elif grep -Eqi "Raspbian" /etc/issue || grep -Eq "Raspbian" /etc/*-release; then
        DISTRO='Raspbian'
        PM='apt'
    else
        DISTRO='unknow'
    fi
    echo $DISTRO;
}


function select_php_version() {
    echo "请选择PHP版本："
    for i in "${!PHP_VERSIONS[@]}";
    do
        printf "%s) %s\n" `expr $i + 1` "${PHP_VERSIONS[$i]}"
    done
    default_version="1"
    read -p "Choose version, default[$default_version]: " version
    if [ $version == "" ]; then
        version=$default_version
    else
        version=`expr $version - 1`
    fi
    PHP_VERSION="${PHP_VERSIONS[$version]}"
    PHP_TARBALL_NAME="php-$PHP_VERSION.tar.gz"
    PHP_TARBALL_DIR="php-$PHP_VERSION"
    PHP_INSTALL_PATH="$INSTALL_PATH/$PHP_DIR/$PHP_VERSION"
    PHP_DOWNLOAD_URL="https://www.php.net/distributions/$PHP_TARBALL_NAME"
}

function select_nginx_version() {
    echo "请选择Nginx版本："
    for i in "${!NGINX_VERSIONS[@]}";
    do
        printf "%s) %s\n" `expr $i + 1` "${NGINX_VERSIONS[$i]}"
    done
    default_version="1"
    read -p "Choose version, default[$default_version]: " version
    if [ $version == "" ]; then
        version=$default_version
    else
        version=`expr $version - 1`
    fi
    NGINX_VERSION="${NGINX_VERSIONS[$version]}"
    NGINX_TARBALL_NAME="nginx-$NGINX_VERSION.tar.gz"
    NGINX_TARBALL_DIR="nginx-$NGINX_VERSION"
    NGINX_INSTALL_PATH="$INSTALL_PATH/$NGINX_DIR/$NGINX_VERSION"
    NGINX_DOWNLOAD_URL="https://nginx.org/download/$NGINX_TARBALL_NAME"
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

