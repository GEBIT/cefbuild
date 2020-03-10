FROM ubuntu:xenial

WORKDIR /home/cefbuild/code/cefbuild/linux

RUN dpkg --add-architecture i386 && apt-get update && apt-get install -y \
	git \
	make \
	cmake \
	curl \
	unzip \
	zip \
	gcc-multilib \
	g++-multilib \
	build-essential \
	openjdk-8-jdk:i386 \
	libgtk2.0-dev:i386 \
	libx11-dev:i386 \
	libglib2.0-dev:i386 \
	libnss3:i386 \
	libx11-xcb-dev:i386 \
	libxtst-dev:i386 \
	libxss-dev:i386 \
	libasound2-dev:i386 \
	libatk-adaptor:i386 \
	libatspi2.0-dev:i386

ENV JAVA_HOME=/usr/lib/jvm/java-8-openjdk-i386/

CMD ["/bin/bash"]
