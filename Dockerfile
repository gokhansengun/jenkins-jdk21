FROM jenkins/jenkins:2.440.1-lts-jdk21

# https://docs.docker.com/engine/reference/builder/#automatic-platform-args-in-the-global-scope
ARG TARGETARCH
ARG TARGETOS

ENV HELM_VERSION=v3.13.3
ENV KUBECTL_VERSION=v1.26.12

# change user to root to install some tools
USER root

RUN apt-get update -y \
    && apt-get install python3-pip libpq-dev jq netcat-traditional sshpass rsync vim -y \
    && apt-get clean -y

COPY scripts/* /usr/local/bin/

ENV PIP_BREAK_SYSTEM_PACKAGES 1

RUN fix-pip-dependencies.sh

COPY requirements.txt /tmp/requirements.txt
COPY requirements-ansible.yml /tmp/

RUN pip install --no-cache-dir --no-build-isolation --no-deps -r /tmp/requirements.txt

# TODO: gseng - we may like to proxy ansible-galaxy over Nexus as well
RUN ansible-galaxy collection install -p /usr/share/ansible/collections -r /tmp/requirements-ansible.yml

RUN curl -L https://github.com/mikefarah/yq/releases/download/4.40.5/yq_${TARGETOS}_${TARGETARCH} -o /usr/bin/yq && \
    chmod +x /usr/bin/yq

# NOTE: gseng - disable aws-iam-authenticator for now
# RUN curl -L -o /usr/bin/aws-iam-authenticator \
#     https://amazon-eks.s3.us-west-2.amazonaws.com/1.17.9/2020-08-04/bin/${TARGETOS}/${TARGETARCH}/aws-iam-authenticator && \
#     chmod +x /usr/bin/aws-iam-authenticator

RUN curl -LO https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/linux/${TARGETARCH}/kubectl && \
    chmod +x kubectl && \
    mv kubectl /usr/local/bin/

RUN curl -o /tmp/helm.tar.gz \
      https://get.helm.sh/helm-${HELM_VERSION}-linux-${TARGETARCH}.tar.gz && \
    tar -C /tmp -xvf /tmp/helm.tar.gz && \
    mv /tmp/linux-${TARGETARCH}/helm /usr/local/bin/helm && \
    rm -rf /tmp/linux-${TARGETARCH} && rm -rf /tmp/helm.tar.gz

# overrite install-plugins to limit concurrent downloads
COPY scripts/install-plugins.sh /usr/local/bin/install-plugins.sh

# move jenkins-plugin-cli binary in order to use the old plugin download strategy
RUN mv /bin/jenkins-plugin-cli /bin/jenkins-plugin-cli-moved
