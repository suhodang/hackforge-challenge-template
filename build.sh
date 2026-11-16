#!/bin/sh
# Challenge 이미지 빌드(ADR 014 "빌드와 등록"). base 이미지, compose 서비스 이미지, 공개 이미지를 images.tar로 묶고
# Challenge 이미지를 빌드해 노드에 import할 tar로 저장한다
# 사용: sh build.sh <tag>
set -eu
cd "$(dirname "$0")"
tag=${1:?사용: sh build.sh <tag>}
. meta/challenge.env
export DOCKER_DEFAULT_PLATFORM=linux/amd64

bases=
for f in app/*/Dockerfile.base; do
	[ -e "$f" ] || continue
	svc=$(basename "$(dirname "$f")")
	base=hackforge/challenge-$SLUG-$svc-base
	grep -qx "FROM $base" "app/$svc/Dockerfile" || { echo "app/$svc/Dockerfile에 'FROM $base'가 없음" >&2; exit 1; }
	docker build -t "$base" -f "$f" "app/$svc"
	bases="$bases $base"
done
(cd app && docker compose build && docker compose pull --ignore-buildable)
docker save -o images.tar $(cd app && docker compose config --images) $bases

image=hackforge/challenge-$SLUG:$tag
docker build -t "$image" .
docker save -o "challenge-$SLUG-$tag.tar" "$image"
ls -l images.tar "challenge-$SLUG-$tag.tar"
