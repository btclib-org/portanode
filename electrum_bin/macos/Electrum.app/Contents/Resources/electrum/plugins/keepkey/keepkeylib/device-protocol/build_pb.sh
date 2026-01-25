#!/bin/bash
# Example usage:
# $ mkdir -p /opt/protoc && \
#   curl -L0 https://github.com/protocolbuffers/protobuf/releases/download/v21.12/protoc-21.12-linux-x86_64.zip -o /tmp/protoc-21.12-linux-x86_64.zip && \
#   unzip /tmp/protoc-21.12-linux-x86_64.zip -d /opt/protoc
# $ PATH="/opt/protoc/bin:$PATH"
# $ ./device-protocol/build_pb.sh

set -e

PROJECT_ROOT="$(dirname "$(readlink -e "$0")")/.."
cd "$PROJECT_ROOT/device-protocol"

echo "Building with protoc version: $(protoc --version)"
for i in messages types exchange ; do
    protoc --python_out="$PROJECT_ROOT/keepkeylib/" -I/usr/include -I. $i.proto
    i=${i/-/_}
    sed -i -Ee 's/^import ([^.]+_pb2)/from . import \1/' "$PROJECT_ROOT"/keepkeylib/"$i"_pb2.py
done

sed -i 's/5000\([2-5]\)/6000\1/g' "$PROJECT_ROOT"/keepkeylib/types_pb2.py
