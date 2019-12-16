FROM golang:1.13.5-alpine3.10@sha256:679fe3791d2710d53efe26b05ba1c7083178d6375318b0c669b6bcd98f25c448 AS builder

RUN apk update && apk add --no-cache git tar
ENV ANSIBLE_PROVIDER_VERSION v1.0.3
RUN git clone https://github.com/nbering/terraform-provider-ansible.git --branch ${ANSIBLE_PROVIDER_VERSION} /terraform-provider-ansible && \
    cd /terraform-provider-ansible && \
    GO111MODULE=on GOARCH=amd64 CGO_ENABLED=0 go build -ldflags "-extldflags '-static'"
COPY ssh_key /tmp/ssh_key
RUN apk --update add ca-certificates && \
    cp -R /tmp/certs/* /usr/local/share/ca-certificates/ && \
    update-ca-certificates

FROM runatlantis/atlantis:v0.10.2@sha256:12fd44c060d7f7c5227579bc639dc1be0cc482499b8245519c4bff566a073843

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
RUN chmod 600 /home/atlantis/id_rsa && chown atlantis /home/atlantis/id_rsa

ENV TERRAGRUNT_VERSION v0.21.9
ENV TERRAGRUNT_URL https://github.com/gruntwork-io/terragrunt/releases/download/${TERRAGRUNT_VERSION}/terragrunt_linux_amd64
RUN wget -O /usr/local/bin/terragrunt ${TERRAGRUNT_URL} && \
    chmod +x /usr/local/bin/terragrunt

