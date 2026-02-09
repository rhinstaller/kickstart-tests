FROM fedora:41
LABEL maintainer='anaconda-devel-list@redhat.com'

RUN dnf -y update && \
    dnf -y install \
    python3 \
    vim \
    rsync \
    git \
    virt-install \
    libvirt-daemon-driver-qemu \
    libvirt-daemon-proxy \
    guestfs-tools \
    genisoimage \
    lorax-lmc-virt \
    parallel \
    python3-libvirt \
    createrepo_c \
    python3-pip \
    python3-rpmfluff \
    python3-rpm \
    squid \
    make \
    openssh-clients && \
    dnf -y clean all

ENV APP_ROOT=/opt/kstest
ENV PATH=${APP_ROOT}/bin:${PATH} \
    APP_DATA=${APP_ROOT}/data \
    KSTEST_USER=kstest

RUN groupadd -g 1001 -r ${KSTEST_USER} -f && \
    useradd -u 1001 -r -g ${KSTEST_USER} -m -c "Kickstart test user" ${KSTEST_USER} && \
    mkdir -p ${APP_DATA}

# This is what OpenShift does with random user he is using
# BUT it does not seem to work, kstest user is not in the root group
# so it can't for example create dirs in APP_ROOT
#RUN usermod -a -G root ${KSTEST_USER}

COPY run-kstest ${APP_ROOT}/bin/

# OpenShift
RUN  chgrp -R 0 ${APP_ROOT} && \
     chmod -R g=u ${APP_ROOT} && \
# This is needed as the group above does not work
     chmod -R ugo+w ${APP_ROOT}

# Inputs: boot.iso
# Outputs: logs
VOLUME ${APP_DATA}

USER ${KSTEST_USER}
WORKDIR ${APP_ROOT}

CMD ["run-kstest"]
