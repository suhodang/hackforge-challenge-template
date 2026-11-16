#!/bin/sh
# 로컬 확인(ADR 014 "형식 규칙"). Challenge 이미지를 외부 통신 없이(--network none) 띄우고,
# 실습 Pod에서처럼 검증 스크립트를 stdin으로 넘겨 /app에서 실행한다
# 사용: sh check.sh <tag>   (build.sh 다음. CI도 같은 순서로 실행)
set -eu
cd "$(dirname "$0")"
export MSYS_NO_PATHCONV=1   # Windows Git Bash가 /app 같은 인자를 바꾸지 않게
tag=${1:?사용: sh check.sh <tag>}
. meta/challenge.env
c=hackforge-check-$SLUG
docker rm -f "$c" >/dev/null 2>&1 || true
trap 'docker rm -f "$c" >/dev/null' EXIT
docker run -d --name "$c" --privileged --network none "hackforge/challenge-$SLUG:$tag" >/dev/null

ready() {
	i=0
	until docker exec "$c" /hackforge/ready.sh; do
		i=$((i + 1))
		[ "$i" -lt 90 ] || { docker logs "$c"; echo "FAIL: 3분 안에 Ready가 아님" >&2; exit 1; }
		sleep 2
	done
}

# expect <스크립트> <기대: 0 | 0아님>
failed=0
expect() {
	if out=$(docker exec -i -w /app "$c" timeout 60 sh < "meta/$1" 2>&1); then got=0; else got=0아님; fi
	if [ "$got" = "$2" ]; then r=ok; else r=FAIL; failed=1; fi
	printf '%-4s %-20s 기대 %-5s 결과 %-5s %s\n' "$r" "$1" "$2" "$got" "$(echo "$out" | tail -n 1)"
}

ready
expect attack-check.sh 0아님
expect functional-test.sh 0
expect exploit.sh 0
expect attack-check.sh 0
echo "오프라인 재빌드"
docker exec -w /app "$c" docker compose build
docker exec -w /app "$c" docker compose up -d
ready
expect functional-test.sh 0
exit "$failed"
