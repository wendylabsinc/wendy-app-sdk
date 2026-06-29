#!/usr/bin/env bash
# Regenerates the committed grpc-swift stubs from the agent .proto files.
# Run after updating Sources/WendyKit/Protos/. Needs protoc +
# protoc-gen-swift on PATH; builds protoc-gen-grpc-swift from the resolved deps.
set -euo pipefail
PKG="$(cd "$(dirname "$0")" && pwd)"
cd "$PKG"
GRPCGEN="$(find .build -name protoc-gen-grpc-swift-tool -type f | head -1)"
[ -n "$GRPCGEN" ] || { echo "build first so protoc-gen-grpc-swift-tool exists (swift build)"; exit 1; }
GEN="Sources/WendyKit/Generated"; rm -rf "$GEN"; mkdir -p "$GEN"
protoc --proto_path=Sources/WendyKit/Protos \
  --plugin=protoc-gen-grpc-swift="$GRPCGEN" \
  --swift_out="$GEN" --swift_opt=Visibility=Public,FileNaming=PathToUnderscores \
  --grpc-swift_out="$GEN" --grpc-swift_opt=Visibility=Public,Client=true,Server=false,FileNaming=PathToUnderscores \
  wendy/agent/services/v1/shared.proto \
  wendy/agent/services/v1/wendy_agent_v1_service.proto \
  wendy/agent/services/v1/wendy_agent_v1_container_service.proto
echo "regenerated $GEN"
