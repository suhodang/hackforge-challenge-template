#!/bin/sh
# 공격 검증(#9). /www/files 밖의 파일을 웹으로 읽은 기록이 있으면 0
outside=$(docker compose exec -T web sh -c 'cat /tmp/view.log 2>/dev/null' | grep -v '^/www/files/' | head -n 1)
if [ -n "$outside" ]; then
	echo "files 폴더 밖의 파일을 읽음: $outside"
	exit 0
fi
echo "files 폴더 밖의 파일을 읽은 기록 없음"
exit 1
