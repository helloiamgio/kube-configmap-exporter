#!/usr/bin/env bash
# -*- coding: utf-8 -*-

[[ -n $DEBUG ]] && set -x -e

version(){
  echo "kube-configmap-exporter 0.0.1"
}

usage(){
  version
  echo "Usage: kube-configmap-exporter <name> -t <dir> options"
}

help() {
  usage
  cat <<"EOF"

Options:
  <name>                   ConfigMap name to export
  -n, --namespace <name>   Namespace ('default' by default)
  -t, --to <dir>           Directory onto which each configmap data is stored
                           as a file named each configmap key
  -h, --help               Show this message
  -v, --version            Show this command's version

Example:
  # Export configmap "mycm" in namespace "myns" onto directory "/tmp/"
  kube-configmap-exporter mycm -n myns -t /tmp
EOF
}

export_configmap(){
  local configmap_name="$1"
  local namespace="$2"
  local export_dir="$3"

  kubectl get configmap ${configmap_name} -n ${namespace} -o json |

    jq ".data" |

    awk \
    -v basedir=${export_dir} \
      'BEGIN {
        FS="\": \""
      }
      {
        # Filter lines that has 2 column (key and value)
        if (NF==2) {
          # ltrim: space, tab and return
          sub(/^[ \t\r\n]+/, "", $1)
          # remove double quote
          gsub(/"/,"", $1);
          # replace ("\"") to double quote
          gsub("\\\\\"", "\"" ,$2);
          # replace ("\r\n") to LF
          gsub("\\\\r\\\\n|\\\\n", "\n" ,$2);
          # replace ("\t") to TAB
          gsub("\\\\t", "\t" ,$2);
          # rtrim: tab, space, return, single quote and comma
          sub(/[ \t\r\n\",]+$/, "", $2)
          of=basedir "/" $1;
          print $2 > of
      }
    }'
}

cmd_main(){
  configmap_name=""
  namespace="default"
  export_dir=""
  for arg in "$@"; do
    option=""
    if [ "${arg:0:1}" = "-" ]; then
      if [ "${arg:1:1}" = "-" ]; then
        option="${arg:2}"
        prevopt="${arg:2}"
      else
        index=1
        while o="${arg:$index:1}"; do
          [ -n "$o" ] || break
          option="$o"
          prevopt="$o"
          let index+=1
        done
      fi
      case "${option}" in
      "h" | "help" )
        help
        exit 0
        ;;  
      "v" | "version" )
        version
        exit 0
        ;;
      esac
    else
      if [ "${prevopt}" = "" ]; then
        configmap_name="${arg}"
      else
        case "${prevopt}" in
        "n" | "namespace" )
          namespace="${arg}"
          ;;
        "t" | "to" )
          export_dir="${arg}"
          ;;
        * )
          help >&2
          exit 1
          ;;
        esac
      fi 
    fi 
  done

  if [ ! ${export_dir} ] || [ ! ${configmap_name} ]; then
    help >&2
    exit 1
  fi
  if [[ "$(type kubectl &>/dev/null; echo $?)" -eq 1 ]]; then
    echo "Error: missing kubectl command" >&2
    echo "Please install kubectl (https://kubernetes.io/docs/tasks/tools/install-kubectl/)" >&2
    exit 1
  fi
  if [[ "$(type jq &>/dev/null; echo $?)" -eq 1 ]]; then
    echo "Error: missing jq command" >&2
    echo "Please install jq (https://stedolan.github.io/jq/)" >&2
    exit 1
  fi
  if [ ! -d ${export_dir} ]; then
    mkdir -p ${export_dir}
  fi
  export_configmap ${configmap_name} ${namespace} ${export_dir}
}

cmd_main "$@"