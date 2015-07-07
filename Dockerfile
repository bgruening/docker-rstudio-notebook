# RStudio container used for Galaxy RStudio Integration
#
# VERSION       0.1.0

FROM debian:squeeze

MAINTAINER Eric Rasche <esr@tamu.edu>

ENV DEBIAN_FRONTEND noninteractive
ENV LANG en_US.UTF-8
ENV LANGUAGE en_US.UTF-8


# Ensure cran is available
RUN (echo "deb http://cran.mtu.edu/bin/linux/debian squeeze-cran3/" >> /etc/apt/sources.list && apt-key adv --keyserver keys.gnupg.net --recv-key 381BA480)
RUN (echo "deb-src http://http.debian.net/debian squeeze main" >> /etc/apt/sources.list && apt-key adv --keyserver keyserver.ubuntu.com --recv-keys E084DAB9)


# Install all requirements and clean up afterwards
RUN apt-get -qq update && \
    apt-get install --no-install-recommends -y apt-transport-https \
        locales r-base r-base-dev dpkg wget psmisc libssl0.9.8 procps sudo \
        libcurl4-openssl-dev curl libxml2-dev nginx python python-pip net-tools \
        lsb-release tcpdump unixodbc unixodbc-dev libmyodbc odbcinst odbc-postgresql && \
    pip install bioblend argparse && \
    apt-get autoremove -y  && \
    apt-get clean -y && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

RUN echo 'en_US.UTF-8 UTF-8' >> /etc/locale.gen
RUN DEBIAN_FRONTEND=noninteractive dpkg-reconfigure locales

# Build specific
ENV RSTUDIO_VERSION 1103

# Install rstudio-server
RUN wget http://download2.rstudio.org/rstudio-server-0.98.${RSTUDIO_VERSION}-amd64.deb && \
    dpkg -i rstudio-server-0.98.${RSTUDIO_VERSION}-amd64.deb && \
    rm /rstudio-server-0.98.${RSTUDIO_VERSION}-amd64.deb

ADD rsession.conf /etc/rstudio/rsession.conf

# Install packages
COPY ./packages.R /tmp/packages.R
RUN Rscript /tmp/packages.R

# ENV variables to replace conf file from Galaxy
ENV DEBUG=false \
    GALAXY_WEB_PORT=10000 \
    NOTEBOOK_PASSWORD=none \
    CORS_ORIGIN=none \
    DOCKER_PORT=none \
    API_KEY=none \
    HISTORY_ID=none \
    REMOTE_HOST=none \
    GALAXY_URL=none

ADD ./startup.sh /startup.sh
ADD ./monitor_traffic.sh /monitor_traffic.sh

# /import will be the universal mount-point for IPython
# The Galaxy instance can copy in data that needs to be present to the IPython webserver
RUN mkdir /import

COPY ./proxy.conf /proxy.conf
COPY ./galaxy.py /usr/local/bin/galaxy.py
COPY ./Rprofile.site /usr/lib/R/etc/Rprofile.site

RUN chmod +x /startup.sh
RUN chmod +x /usr/local/bin/galaxy.py

# Copy in Galaxy Connector
ADD ./GalaxyConnector_0.1.0.tar.gz /tmp/GalaxyConnector
COPY ./packages-gx.R /tmp/packages-gx.R
RUN Rscript /tmp/packages-gx.R


VOLUME ["/import"]
WORKDIR /import/
# Start RStudio
CMD /startup.sh
