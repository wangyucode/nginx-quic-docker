FROM ubuntu:22.04@sha256:20fa2d7bb4de7723f542be5923b06c4d704370f0390e4ae9e1c833c8785644c1 AS build

WORKDIR /src

COPY . .

RUN apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends git gcc g++ gcc-12 g++-12 mold make cmake perl libunwind-dev golang ca-certificates ninja-build && \
    git clone --depth 1 https://boringssl.googlesource.com/boringssl && \
    mkdir boringssl/build && \
    cd boringssl/build && \
    export CC=/usr/bin/gcc-12 && \
    export CXX=/usr/bin/g++-12 && \
    cmake -DCMAKE_LINKER=/usr/bin/mold -GNinja .. && \
    ninja

RUN mkdir ngx_brotli && \
    cd ngx_brotli && \
    git init && \
    git remote add origin https://github.com/google/ngx_brotli.git && \
    git fetch --depth 1 origin && \
    git checkout --recurse-submodules -q FETCH_HEAD && \
    git submodule update --init --depth 1

RUN DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends mercurial libperl-dev libpcre2-dev zlib1g-dev libxslt1-dev libgd-ocaml-dev libgeoip-dev && \
    hg clone https://hg.nginx.org/nginx-quic && \
    cd nginx-quic && \
    hg update quic && \
    auto/configure `nginx -V 2>&1 | sed "s/ \-\-/ \\\ \n\t--/g" | grep "\-\-" | grep -ve opt= -e param= -e build=` \
      --prefix=/etc/nginx \
      --sbin-path=/usr/sbin/nginx \
      --conf-path=/etc/nginx/nginx.conf \
      --error-log-path=/var/log/nginx/error.log \
      --http-log-path=/var/log/nginx/access.log \
      --pid-path=/var/run/nginx.pid \
      --lock-path=/var/run/nginx.lock \
      --http-client-body-temp-path=/var/cache/nginx/client_temp \
      --http-proxy-temp-path=/var/cache/nginx/proxy_temp \
      --http-fastcgi-temp-path=/var/cache/nginx/fastcgi_temp \
      --http-uwsgi-temp-path=/var/cache/nginx/uwsgi_temp \
      --http-scgi-temp-path=/var/cache/nginx/scgi_temp \
      --build=nginx-quic \
      --with-http_v2_module \
      --with-http_v3_module \
      --with-stream_quic_module \
      --with-http_gzip_static_module \
      --with-http_realip_module \
      --add-module=/src/ngx_brotli \
      --with-cc=/usr/bin/gcc-12 \
      --with-cc-opt='-I/src/boringssl/include -fuse-ld=mold -O3 -march=native -pipe -flto=auto -ffat-lto-objects -fomit-frame-pointer -fstack-protector-all -fPIE -fexceptions --param=ssp-buffer-size=4 -grecord-gcc-switches -pie -fno-semantic-interposition -Wl,-Bsymbolic-functions -Wl,-z,relro -Wl,-z,now -Wformat-security -Wno-error=strict-aliasing -Wextra -Wp,-D_FORTIFY_SOURCE=2' \
      --with-ld-opt='-L/src/boringssl/build/ssl -L/src/boringssl/build/crypto -O3 -Wl,-Bsymbolic-functions -Wl,-z,relro' && \
    NB_PROC=$(grep -c ^processor /proc/cpuinfo) && \
    make -j $NB_PROC && \
    strip objs/nginx && \
    make install



# ----------------------------------------------------------------------------



#FROM nginx
FROM ubuntu:22.04@sha256:20fa2d7bb4de7723f542be5923b06c4d704370f0390e4ae9e1c833c8785644c1

LABEL org.opencontainers.image.authors "Yu Wang <wangyu@wycode.cn>"
LABEL org.opencontainers.image.url "https://github.com/wangyucode/nginx-quic-docker"
LABEL org.opencontainers.image.documentation "https://github.com/wangyucode/nginx-quic-docker"
LABEL org.opencontainers.image.source "https://github.com/wangyucode/nginx-quic-docker"
LABEL org.opencontainers.image.title "wangyucode/nginx-quic"
LABEL org.opencontainers.image.description "nginx is a web server"

COPY --from=build /src/nginx-quic/objs/nginx /usr/sbin/
COPY --from=build /src/files/index.html /etc/nginx/html/
COPY --from=build /src/files/nginx.conf /etc/nginx/nginx.conf
COPY --from=build /src/files/mime.types /etc/nginx/mime.types

COPY --from=build /etc/ssl/certs /etc/ssl/certs

VOLUME ["/var/cache/nginx"]

EXPOSE 80
EXPOSE 443/tcp
EXPOSE 443/udp


ENTRYPOINT ["nginx", "-g", "daemon off;"]
# ENTRYPOINT ["nginx"]