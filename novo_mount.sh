#!/bin/bash

# version: 1.0
# 基本功能已实现, 通过参数设置挂载目录或者卸载目录
# 如果不指定挂载/卸载目录, 默认会以'tmp'为目标目录名称
# version: 2.0
# 取挂载目录的最后一级为默认挂载名称(方便挂载多个)
# 卸载时读取当前目录下挂载了的远程目录, 全部卸载(读取df -h的信息并进行处理实现
# version:2.1 (规划)
# 清理重复的代码, 对重复的部分进行函数化

arg_list=$@
vpn="N"
while getopts "vmun:" arg #选项后面的冒号表示该选项需要参数
do
    case $arg in
            v)
                vpn="Y"
            ;;
            m)
                mode="mount"
            ;;
            u)
                mode="unmount"
            ;;
            n)
                node="$OPTARG"
                if [ $node != "NJnode" ] && [ $node != "TJnode" ];then
                    echo '-n can only accept NJnode or TJnode, please check your input'
                    exit 1
                fi
            ;;
            ?)  #当有不认识的选项的时候arg为?
                echo $OPTARG
                exit 1
    ;;
    esac
done
# 用来删除上面已解析的项目
shift $(($OPTIND - 1))

if [ $mode == "mount" ];then
    remote_path=$1
    local_path=$2
    if [ ! ${local_path} ];then
        # cut 结合 rev才能取最后一个字段
        local_path=`echo ${remote_path} | rev | cut -d '/' -f 1 | rev`
    fi
    # shell中直在判断式中写变量引用可判断变量是否存在, !代表反向
    # grep -q 只返回判断, 不输出结果
    # 记住, 每一个命令本身是有返回值的, 所以进行判断时可以利用这一点
    if [ ! ${node} ];then
        if echo "${remote_path}" | grep -qE "TJPROJ|BJPROJ|CDD";then
            node='TJnode'
        elif echo "${remote_path}" | grep -q "NJPROJ";then
            node='NJnode'
        else
            echo "Can't tell node from your path, please specify manually using '-n' "
            exit 1
        fi
    fi
    if [ ${vpn} == "Y" ];then
        node="${node}_VPN"
    fi
    echo "node: ${node}"
    if [ ! -d ${local_path} ];then
        mkdir -p ${local_path}
    fi
    sshfs -o reconnect -o follow_symlinks -o cache=yes -o allow_other \
        ${node}:${remote_path} \
        ${local_path}
    echo -E "${remote_path} was mounted to ./${local_path}  !"
    
elif [ $mode == "unmount" ];then
    local_path=$1
    if [ ! ${local_path} ];then
        PWD=`pwd`
        if path_list=`df -h | grep -E "TJnode|NJnode" | grep ${PWD} | cut -d '%' -f 2`;then
            for local_path in ${path_list};do
                if fusermount -u ${local_path};then
                    echo -E "${local_path} was umounted !"
                    rmdir ${local_path}
                fi
            done
        fi
    else
        if fusermount -u ${local_path};then
            echo -E "${local_path} was umounted !"
            rmdir ${local_path}
        fi
    fi
fi
