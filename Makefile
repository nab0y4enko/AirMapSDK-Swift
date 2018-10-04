protos_path := interfaces/grpc

protos_telemetry := \
	$(protos_path)/ids.proto \
	$(protos_path)/measurements.proto \
	$(protos_path)/telemetry.proto \
	$(protos_path)/units.proto \

target_proto_dir_telemetry := Source/Telemetry/grpc

all: bootstrap protos

protos:
	mkdir -p $(target_proto_dir_telemetry) || true
	PATH=:.build/grpc-swift:$$PATH protoc --swift_out=$(target_proto_dir_telemetry) --swiftgrpc_out=Client=true,Server=false:$(target_proto_dir_telemetry) -I$(protos_path) $(protos_telemetry)

bootstrap:
	mkdir -p .build || true
	cd .build && git clone https://github.com/grpc/grpc-swift || true
	cd .build/grpc-swift && make

clean:
	rm -rf .build || true
	rm -rf $(target_proto_dir_telemetry)