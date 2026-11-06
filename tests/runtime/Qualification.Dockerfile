FROM ubuntu:24.04@sha256:68ee22004a9109b44973313b02ff7b1de250f1de0f5ecb628d73f579aaff33ac
LABEL codex.managed="true" codex.project="godotluau"
ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential clang cmake ninja-build scons python3 python3-pip \
    curl ca-certificates unzip zip git libfontconfig1 pkg-config lld && rm -rf /var/lib/apt/lists/*
WORKDIR /work
