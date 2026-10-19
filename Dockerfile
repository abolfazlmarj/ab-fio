FROM docker.io/abolfazlmarj/fio:latest
COPY . /app/
ENTRYPOINT ["/app/ab-tester.sh"]
#ENTRYPOINT ["/bin/sh"]
