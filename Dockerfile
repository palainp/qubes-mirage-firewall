# Pin the base image to a specific hash for maximum reproducibility.
# It will probably still work on newer images, though, unless an update
# changes some compiler optimisations (unlikely).
# bookworm-slim taken from https://hub.docker.com/_/debian/tags?page=1&name=bookworm-slim
FROM debian@sha256:a629e796d77a7b2ff82186ed15d01a493801c020eed5ce6adaa2704356f15a1c
# install remove default packages repository
RUN rm /etc/apt/sources.list.d/debian.sources
# and set the package source to a specific release too
# taken from https://snapshot.debian.org/archive/debian
RUN printf "deb [check-valid-until=no] http://snapshot.debian.org/archive/debian/20240926T083932Z bookworm main\n" > /etc/apt/sources.list
# taken from https://snapshot.debian.org/archive/debian-security/
RUN printf "deb [check-valid-until=no] http://snapshot.debian.org/archive/debian-security/20240925T181319Z bookworm-security main\n" >> /etc/apt/sources.list

RUN apt update && apt install --no-install-recommends --no-install-suggests -y wget ca-certificates git patch unzip bzip2 make gcc g++ libc-dev
RUN wget -O /usr/bin/opam https://github.com/ocaml/opam/releases/download/2.2.1/opam-2.2.1-i686-linux && chmod 755 /usr/bin/opam
# taken from https://raw.githubusercontent.com/ocaml/opam/master/shell/install.sh
RUN test `sha512sum /usr/bin/opam | cut -d' ' -f1` = \
"bf16d573137835ce9abbcf6b99cb94a1da69ab58804a4de7c90233f0b354d5e68e9c47ee16670ca9d59866d58c7db345d9723e6eb5fc3a1cb8dca371f0e90225" || exit

ENV OPAMROOT=/tmp
ENV OPAMCONFIRMLEVEL=unsafe-yes
# Pin last known-good version for reproducible builds.
# Remove this line (and the base image pin above) if you want to test with the
# latest versions.
# taken from https://github.com/ocaml/opam-repository
RUN opam init --disable-sandboxing -a --bare https://github.com/ocaml/opam-repository.git#656c3b30bcd13559cef0c0c23f3e3f9c2c60cdbc
RUN opam switch create myswitch 4.14.2
RUN opam exec -- opam install -y mirage opam-monorepo ocaml-solo5
RUN mkdir /tmp/orb-build
ADD config.ml /tmp/orb-build/config.ml
WORKDIR /tmp/orb-build
CMD opam exec -- sh -exc 'mirage configure -t xen --extra-repos=\
opam-overlays:https://github.com/dune-universe/opam-overlays.git#f2bec38beca4aea9e481f2fd3ee319c519124649,\
mirage-overlays:https://github.com/dune-universe/mirage-opam-overlays.git#797cb363df3ff763c43c8fbec5cd44de2878757e \
&& make depend && make tar'
