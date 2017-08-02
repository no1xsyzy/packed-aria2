FROM nginx:1.13

# less priviledge user, the id should map the user the downloaded files belongs to
RUN groupadd -r dummy && useradd -r -g dummy dummy -u 1000

# webui + aria2
RUN apt-get update \
	&& apt-get install -y \
		aria2 \
		curl \
		patch \
		unzip \
	&& rm -rf /var/lib/apt/lists/*

# gosu install latest
RUN GITHUB_REPO="https://github.com/tianon/gosu" \
  && LATEST=`curl -s  $GITHUB_REPO"/releases/latest" | grep -Eo "[0-9].[0-9]*"` \
  && curl -L $GITHUB_REPO"/releases/download/"$LATEST"/gosu-amd64" > /usr/local/bin/gosu \
  && chmod +x /usr/local/bin/gosu

# goreman supervisor install latest
RUN GITHUB_REPO="https://github.com/mattn/goreman" \
  && LATEST=`curl -s  $GITHUB_REPO"/releases/latest" | grep -Eo "v[0-9]*.[0-9]*.[0-9]*"` \
  && curl -L $GITHUB_REPO"/releases/download/"$LATEST"/goreman_linux_amd64.zip" > goreman.zip \
  && unzip goreman.zip && mv /goreman /usr/local/bin/goreman && rm -R goreman*

# webui-aria2 install latest
COPY webui-aria2.patch /webui-aria2.patch
RUN GITHUB_REPO="https://github.com/ziahamza/webui-aria2" \
  && curl -L $GITHUB_REPO"/archive/master.zip" -o webui-aria2.zip \
  && unzip webui-aria2.zip && mv webui-aria2-master webui-aria2 && rm webui-aria2.zip \
  && patch -p0 < webui-aria2.patch && rm /webui-aria2.patch \
  && rm \
	/webui-aria2/.dockerignore \
	/webui-aria2/.gitignore \
	/webui-aria2/directurl.md \
	/webui-aria2/docker-compose.yml \
	/webui-aria2/Dockerfile \
	/webui-aria2/Dockerfile.arm \
	/webui-aria2/LICENSE \
	/webui-aria2/node-server.js \
	/webui-aria2/README.md \
	/webui-aria2/webui-aria2.spec

# nginx config
ADD nginx.conf /etc/nginx/nginx.conf

# aria2 config
ADD aria2.conf /etc/aria2/aria2.conf
RUN touch /aria2.session \
	&& chown -R dummy:dummy /aria2.session \
	&& chmod 666 /aria2.session

# goreman setup
RUN echo "web: /usr/sbin/nginx -g 'daemon off;'\nbackend: gosu dummy /usr/bin/aria2c --conf-path=/etc/aria2/aria2.conf" > Procfile

# aria2 downloads directory
RUN mkdir /downloads && chown -R dummy:dummy /downloads && ln -s /downloads /webui-aria2/downloads
VOLUME /downloads

# expose ports
EXPOSE 80/tcp

CMD ["/usr/local/bin/goreman", "start"]
