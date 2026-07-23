#!/usr/bin/env bash
# Regenerates the committed grpc-swift stubs from the local API .proto files.
# Run after updating Sources/WendyKit/Protos/. Needs protoc and the Swift
# protobuf generators. The generator products can be built from SwiftPM's
# resolved dependency checkouts when they are not installed globally.
set -euo pipefail
PKG="$(cd "$(dirname "$0")" && pwd)"
cd "$PKG"

find_generator() {
  local name="$1"
  command -v "$name" 2>/dev/null || find .build/checkouts -type f -path "*/debug/$name" -perm -111 2>/dev/null | head -1
}

SWIFTGEN="$(find_generator protoc-gen-swift)"
GRPCGEN="$(find_generator protoc-gen-grpc-swift)"
if [ -z "$SWIFTGEN" ] || [ -z "$GRPCGEN" ]; then
  cat >&2 <<'EOF'
protobuf generators not found. Build them from the resolved dependencies first:
  swift build --package-path .build/checkouts/swift-protobuf --product protoc-gen-swift
  swift build --package-path .build/checkouts/grpc-swift-protobuf --product protoc-gen-grpc-swift
EOF
  exit 1
fi

GEN="Sources/WendyKit/Generated"
rm -rf "$GEN"
mkdir -p "$GEN"

# Keep the legacy WendyAgent/admin stubs public for source compatibility.
protoc --proto_path=Sources/WendyKit/Protos \
  --plugin=protoc-gen-swift="$SWIFTGEN" \
  --plugin=protoc-gen-grpc-swift="$GRPCGEN" \
  --swift_out="$GEN" --swift_opt=Visibility=Public,FileNaming=PathToUnderscores \
  --grpc-swift_out="$GEN" --grpc-swift_opt=Visibility=Public,Client=true,Server=false,FileNaming=PathToUnderscores \
  wendy/agent/services/v1/shared.proto \
  wendy/agent/services/v1/wendy_agent_v1_service.proto \
  wendy/agent/services/v1/wendy_agent_v1_container_service.proto

# Wendy System API wire types are implementation details behind domain APIs.
protoc --proto_path=Sources/WendyKit/Protos \
  --plugin=protoc-gen-swift="$SWIFTGEN" \
  --plugin=protoc-gen-grpc-swift="$GRPCGEN" \
  --swift_out="$GEN" --swift_opt=Visibility=Internal,FileNaming=PathToUnderscores \
  --grpc-swift_out="$GEN" --grpc-swift_opt=Visibility=Internal,Client=true,Server=false,FileNaming=PathToUnderscores \
  wendy/system/v1/notifications.proto

echo "regenerated $GEN"
