FROM debian:squeeze
# Must use older version for libssl0.9.8
MAINTAINER Eric Rasche <rasche.eric@yandex.ru>

# Install all requirements and clean up afterwards
RUN DEBIAN_FRONTEND=noninteractive apt-get update --fix-missing

RUN apt-get install -y locales
RUN echo 'en_US.UTF-8 UTF-8' >> /etc/locale.gen
RUN DEBIAN_FRONTEND=noninteractive dpkg-reconfigure locales

# Set default locale for the environment
ENV LANG en_US.UTF-8
ENV LANGUAGE en_US.UTF-8

# Ensure cran is available
RUN (echo "deb http://cran.mtu.edu/bin/linux/debian squeeze-cran3/" >> /etc/apt/sources.list && apt-key adv --keyserver keys.gnupg.net --recv-key 381BA480)
RUN (echo "deb-src http://http.debian.net/debian squeeze main" >> /etc/apt/sources.list && apt-key adv --keyserver keyserver.ubuntu.com --recv-keys E084DAB9)

RUN DEBIAN_FRONTEND=noninteractive apt-get update -q

# Install packages
RUN DEBIAN_FRONTEND=noninteractive apt-get install --no-install-recommends -y -q r-base r-base-dev
RUN DEBIAN_FRONTEND=noninteractive apt-get install --no-install-recommends -y -q dpkg wget psmisc libssl0.9.8 cron sudo libcurl4-openssl-dev curl libxml2-dev nginx python
RUN DEBIAN_FRONTEND=noninteractive apt-get install --no-install-recommends -y -q python-pip

# Install rstudio-server
RUN DEBIAN_FRONTEND=noninteractive apt-get install --no-install-recommends -y -q lsb-release
RUN wget http://download2.rstudio.org/rstudio-server-0.98.1081-amd64.deb
RUN dpkg -i rstudio-server-0.98.1081-amd64.deb
RUN rm /rstudio-server-0.98.1081-amd64.deb
RUN pip install bioblend

ADD rsession.conf /etc/rstudio/rsession.conf

RUN DEBIAN_FRONTEND=noninteractive apt-get install --no-install-recommends -y -q net-tools
RUN DEBIAN_FRONTEND=noninteractive apt-get autoremove -y
RUN DEBIAN_FRONTEND=noninteractive apt-get clean -y && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

COPY ./GalaxyConnector.tar.gz /tmp/GalaxyConnector.tar.gz
# Install packages
COPY ./packages.R /tmp/packages.R
RUN Rscript /tmp/packages.R
RUN rm /tmp/packages.R

# Suicide
COPY ./monitor_traffic.sh /monitor_traffic.sh
RUN chmod +x /monitor_traffic.sh
RUN echo "* *     * * *   root    /monitor_traffic.sh" >> /etc/crontab

# /import will be the universal mount-point for IPython
# The Galaxy instance can copy in data that needs to be present to the IPython webserver
RUN mkdir /import
VOLUME ["/import"]
WORKDIR /import/

COPY ./startup.sh /startup.sh
RUN chmod +x /startup.sh
COPY ./proxy.conf /proxy.conf
COPY ./galaxy.py /usr/local/bin/galaxy.py
RUN chmod +x /usr/local/bin/galaxy.py
COPY ./Rprofile.site /usr/lib/R/etc/Rprofile.site

# Start IPython Notebook
CMD /startup.sh
