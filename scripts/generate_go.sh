#!/usr/bin/env bash

SCRIPTS_DIR=$(dirname "$0")
source $SCRIPTS_DIR/common.sh

push $SCRIPTS_DIR/..
KVPROTO_ROOT=`pwd`
pop

PROGRAM=$(basename "$0")
GOPATH=$(go env GOPATH)

if [ -z $GOPATH ]; then
    printf "Error: the environment variable GOPATH is not set, please set it before running %s\n" $PROGRAM > /dev/stderr
    exit 1
fi

GO_PREFIX_PATH=github.com/pingcap/kvproto/pkg
export PATH=$KVPROTO_ROOT/_tools/bin:$GOPATH/bin:$PATH

echo "install tools..."
go install github.com/gogo/protobuf/protoc-gen-gofast@636bf0302bc95575d69441b25a2603156ffdddf1
go install github.com/grpc-ecosystem/grpc-gateway/protoc-gen-grpc-gateway@f7120437bb4f6c71f7f5076ad65a45310de2c009
go install golang.org/x/tools/cmd/goimports@04b5d21e00f1f47bd824a6ade581e7189bacde87

function collect() {
    file=$(basename $1)
    base_name=$(basename $file ".proto")
    mkdir -p ../pkg/$base_name
    if [ -z $GO_OUT_M ]; then
        GO_OUT_M="M$file=$GO_PREFIX_PATH/$base_name"
    else
        GO_OUT_M="$GO_OUT_M,M$file=$GO_PREFIX_PATH/$base_name"
    fi
}

# Although eraftpb.proto is copying from raft-rs, however there is no
# official go code ship with the crate, so we need to generate it manually.
collect include/eraftpb.proto
collect include/rustproto.proto
cd proto
for file in `ls *.proto`
    do
    collect $file
done

echo "generate go code..."
ret=0

function gen() {
    base_name=$(basename $1 ".proto")
    protoc -I.:../include --grpc-gateway_out=logtostderr=true:../pkg/$base_name --gofast_out=plugins=grpc,$GO_OUT_M:../pkg/$base_name $1 || ret=$?
    cd ../pkg/$base_name
    sed_inplace -E 's/import _ \"gogoproto\"//g' *.pb*.go
    sed_inplace -E 's/import fmt \"fmt\"//g' *.pb*.go
    sed_inplace -E 's/import io \"io\"//g' *.pb*.go
    sed_inplace -E 's/import math \"math\"//g' *.pb*.go
    sed_inplace -E 's/import _ \".*rustproto\"//' *.pb*.go
    goimports -w *.pb*.go
    cd ../../proto
}

gen ../include/eraftpb.proto
for file in `ls *.proto`
    do
    gen $file
done
exit $ret
