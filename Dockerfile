FROM ubuntu:latest

MAINTAINER Eric Löffler <eloeffler@aservo.com>

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && \
    apt-get -y upgrade && \
    apt-get -y --no-install-recommends install \
        ca-certificates \
        git \
        curl \
        jq \
        openjdk-11-jdk-headless \
        maven \
        && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

ADD ca_certs/ /usr/local/share/ca-certificates/
ADD src/ /opt/app/src/
ADD docker-entrypoint.sh /opt/app/
ADD docker-start.sh /opt/app/

RUN chmod -R 644 /usr/local/share/ca-certificates/ && \
    update-ca-certificates

WORKDIR /opt/app

RUN ./docker-start.sh resolve-maven

ENTRYPOINT ["/opt/app/docker-entrypoint.sh"]

CMD ["/opt/app/docker-start.sh"]
