FROM golang:1.13.5-alpine3.10@sha256:679fe3791d2710d53efe26b05ba1c7083178d6375318b0c669b6bcd98f25c448 AS builder

RUN apk update && apk add --no-cache git tar curl
ENV ANSIBLE_PROVIDER_VERSION v1.0.3
RUN git clone https://github.com/nbering/terraform-provider-ansible.git --branch ${ANSIBLE_PROVIDER_VERSION} /terraform-provider-ansible && \
    cd /terraform-provider-ansible && \
    GO111MODULE=on GOARCH=amd64 CGO_ENABLED=0 go build -ldflags "-extldflags '-static'"

RUN curl -o /tmp/kubectl https://storage.googleapis.com/kubernetes-release/release/$(curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt)/bin/linux/amd64/kubectl \
    && curl -o /tmp/aws-iam-authenticator https://amazon-eks.s3-us-west-2.amazonaws.com/1.14.6/2019-08-22/bin/linux/amd64/aws-iam-authenticator \
    && curl -o /tmp/helm-v2.14.1-linux-amd64.tar.gz https://storage.googleapis.com/kubernetes-helm/helm-v2.14.1-linux-amd64.tar.gz \
    && cd /tmp && tar -xzf helm-v2.14.1-linux-amd64.tar.gz

COPY ssh_key /tmp/ssh_key


FROM runatlantis/atlantis:v0.10.2

ENV ANSIBLE_VERSION 2.8.3
ENV AWS_CLI_VERSION 1.16.290

RUN apk --no-cache update && \
    apk --no-cache add \
        python3 \
        unzip \
        tar && \
    apk --no-cache add \
        python3-dev \
        libffi-dev \
        openssl-dev \
        build-base \
        --virtual .build-deps && \
    python3 -m ensurepip && \
    pip3 install --no-cache-dir --upgrade pip cffi botocore && \
    pip3 install --no-cache-dir --upgrade \
        awscli==${AWS_CLI_VERSION} \
        ansible==${ANSIBLE_VERSION} \
        boto3 && \
    mkdir -p /home/atlantis/.terraform.d/plugins/linux_amd64 && \
    apk del .build-deps

ENV JQ_VERSION 1.6
ENV JQ_URL https://github.com/stedolan/jq/releases/download/jq-${JQ_VERSION}/jq-linux64
RUN wget -O /usr/local/bin/jq ${JQ_URL} && \
    chmod +x /usr/local/bin/jq

ENV ANSIBLE_PROVIDER_VERSION v1.0.3
ENV ANSIBLE_PROVIDER_NAME terraform-provider-ansible_${ANSIBLE_PROVIDER_VERSION}_x4
COPY --from=builder /terraform-provider-ansible/terraform-provider-ansible /home/atlantis/.terraform.d/plugins/linux_amd64/${ANSIBLE_PROVIDER_NAME}
COPY --from=builder /tmp/ssh_key /home/atlantis/id_rsa

COPY --from=builder /tmp/aws-iam-authenticator /usr/local/bin/aws-iam-authenticator
COPY --from=builder /tmp/kubectl /usr/local/bin/kubectl
COPY --from=builder /tmp/linux-amd64/helm /usr/local/bin/helm

RUN chmod 600 /home/atlantis/id_rsa
RUN chown atlantis /home/atlantis/id_rsa
RUN chmod +x /usr/local/bin/aws-iam-authenticator
RUN chmod +x /usr/local/bin/kubectl
RUN chmod +x /usr/local/bin/helm

ENV TERRAGRUNT_VERSION v0.21.9
ENV TERRAGRUNT_URL https://github.com/gruntwork-io/terragrunt/releases/download/${TERRAGRUNT_VERSION}/terragrunt_linux_amd64
RUN wget -O /usr/local/bin/terragrunt ${TERRAGRUNT_URL} && \
    chmod +x /usr/local/bin/terragrunt