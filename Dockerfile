FROM amazon/aws-lambda-python:3.8

RUN yum install unzip jq -y && \
     curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip" && \
     unzip awscliv2.zip && \
     ./aws/install

COPY ./generateXML.sh ${LAMBDA_TASK_ROOT}
COPY ./app.py ${LAMBDA_TASK_ROOT}
RUN chmod +x ${LAMBDA_TASK_ROOT}/generateXML.sh

CMD [ "app.handler" ]