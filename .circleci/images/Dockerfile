FROM circleci/node:7.10

ENV TERRAFORM_VERSION=0.10.6

RUN sudo apt-get update && sudo apt-get install -y  git curl ssh python-pip python-dev && \
    sudo curl https://releases.hashicorp.com/terraform/${TERRAFORM_VERSION}/terraform_${TERRAFORM_VERSION}_linux_amd64.zip > /tmp/terraform_${TERRAFORM_VERSION}_linux_amd64.zip && \
    sudo unzip /tmp/terraform_${TERRAFORM_VERSION}_linux_amd64.zip -d /bin && \
    sudo rm -f /tmp/terraform_${TERRAFORM_VERSION}_linux_amd64.zip && \
    sudo pip install awscli
