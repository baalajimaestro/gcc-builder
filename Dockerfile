FROM gcc:latest

RUN mkdir /build

COPY gcc_builder.sh /build

RUN bash gcc_builder.sh