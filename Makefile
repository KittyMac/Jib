SWIFT_BUILD_FLAGS=--configuration release

define buildSwift62
	ANDROID_NDK_HOME=~/Downloads/android-ndk-r27d ~/Library/org.swift.swiftpm/swift-sdks/swift-6.2-RELEASE-android-0.1.artifactbundle/swift-android/scripts/setup-android-sdk.sh
	swiftly run swift build  --configuration=release -Xcc -Oz -Xswiftc -Osize -Xswiftc -whole-module-optimization -Xswiftc -gnone --swift-sdk $1-unknown-linux-android28 +6.2
endef

android:
	@$(call buildSwift62,"aarch64","arm64-v8a","aarch64-linux-android")
	@$(call buildSwift62,"armv7","armeabi-v7a","arm-linux-androideabi")
	@$(call buildSwift62,"x86_64","x86_64","x86_64-linux-android")
	
build:
	swift build -Xswiftc -enable-library-evolution -v $(SWIFT_BUILD_FLAGS)

clean:
	rm -rf .build

test:
	swift test -v

update:
	swift package update

profile: clean
	mkdir -p /tmp/jib.stats
	swift build \
		--configuration release \
		-Xswiftc -stats-output-dir \
		-Xswiftc /tmp/jib.stats \
		-Xswiftc -trace-stats-events \
		-Xswiftc -driver-time-compilation \
		-Xswiftc -debug-time-function-bodies

docker:
	-DOCKER_HOST=ssh://rjbowli@192.168.111.203 docker buildx create --name cluster_builder203 --platform linux/amd64
	-docker buildx create --name cluster_builder203 --platform linux/arm64 --append
	-docker buildx use cluster_builder203
	-docker buildx inspect --bootstrap
	-docker login
	docker buildx build --file Dockerfile-focal --platform linux/amd64,linux/arm64 --push -t kittymac/jib .
	docker buildx build --file Dockerfile-fedora37 --platform linux/amd64,linux/arm64 --push -t kittymac/jib .
	docker buildx build --file Dockerfile-fedora38 --platform linux/amd64,linux/arm64 --push -t kittymac/jib .
	
# docker run --rm -it --entrypoint bash fedora:37
