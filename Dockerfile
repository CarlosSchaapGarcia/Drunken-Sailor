FROM ubuntu:22.04
ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y \
	curl git unzip xz-utils wget zip libglu1-mesa openjdk-17-jdk ca-certificates && \
	apt-get clean && rm -rf /var/lib/apt/lists/*

# Ensure Java 17 is the default java/javac
RUN update-alternatives --install /usr/bin/java java /usr/lib/jvm/java-17-openjdk-amd64/bin/java 1 \
 && update-alternatives --install /usr/bin/javac javac /usr/lib/jvm/java-17-openjdk-amd64/bin/javac 1 \
 && update-alternatives --set java /usr/lib/jvm/java-17-openjdk-amd64/bin/java \
 && update-alternatives --set javac /usr/lib/jvm/java-17-openjdk-amd64/bin/javac

ENV ANDROID_SDK_ROOT=/opt/android-sdk
ENV JAVA_HOME=/usr/lib/jvm/java-17-openjdk-amd64

RUN mkdir -p ${ANDROID_SDK_ROOT}/cmdline-tools

RUN wget -qO /tmp/commandlinetools.zip "https://dl.google.com/android/repository/commandlinetools-linux-9477386_latest.zip" \
	&& unzip /tmp/commandlinetools.zip -d /tmp \
	&& mkdir -p ${ANDROID_SDK_ROOT}/cmdline-tools \
	&& mv /tmp/cmdline-tools ${ANDROID_SDK_ROOT}/cmdline-tools/latest \
	&& rm /tmp/commandlinetools.zip

ENV PATH="${PATH}:${ANDROID_SDK_ROOT}/cmdline-tools/latest/bin:${ANDROID_SDK_ROOT}/platform-tools"

RUN yes | ${ANDROID_SDK_ROOT}/cmdline-tools/latest/bin/sdkmanager --sdk_root=${ANDROID_SDK_ROOT} --licenses

RUN ${ANDROID_SDK_ROOT}/cmdline-tools/latest/bin/sdkmanager --sdk_root=${ANDROID_SDK_ROOT} "platform-tools" "platforms;android-33" "build-tools;33.0.2"

RUN git clone https://github.com/flutter/flutter.git -b stable /opt/flutter --depth 1

ENV PATH="${PATH}:/opt/flutter/bin:/opt/flutter/bin/cache/dart-sdk/bin"

RUN flutter doctor -v || true

