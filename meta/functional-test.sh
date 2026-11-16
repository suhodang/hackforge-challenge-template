#!/bin/sh
# 방어 검증(#11). 정상 기능이 모두 동작하면 0
get() { wget -qO- "http://127.0.0.1:8080/cgi-bin/view?file=$1" 2>/dev/null; }
get hello.txt | grep -q '안녕하세요' || { echo "hello.txt를 읽지 못함"; exit 1; }
get notice.txt | grep -q '점검 공지' || { echo "notice.txt를 읽지 못함"; exit 1; }
if get missing.txt >/dev/null; then echo "없는 파일에 404가 아님"; exit 1; fi
echo "정상 기능 3개 모두 동작"
