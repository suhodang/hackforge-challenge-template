# 실습 Pod 안에서 오프라인으로 다시 빌드한다. base 위에 소스 COPY만 한다(ADR 014)
FROM hackforge/challenge-example-web-base
COPY www /www
COPY --chmod=755 www/cgi-bin /www/cgi-bin
CMD ["httpd", "-f", "-p", "80", "-h", "/www"]
