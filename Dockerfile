# Challenge 이미지 (ADR 012, ADR 014). meta/는 넣지 않는다
# 서비스 이미지와 base 이미지는 build.sh가 images.tar로 묶어 넣는다. 실습 Pod는 외부 통신이 없어서 시작할 때 pull하지 않는다
FROM docker:27.5.1-dind
COPY app/ /app/
COPY images.tar /hackforge/images.tar
COPY --chmod=755 hackforge/entrypoint.sh hackforge/ready.sh /hackforge/
ENTRYPOINT ["/hackforge/entrypoint.sh"]
