# 해답

## 공격

`file` 값이 URL decode된 뒤 `/www/files/` 뒤에 그대로 붙는다. 상위 폴더 경로를 넣으면 폴더 밖 파일을 읽는다.

```sh
wget -qO- 'http://127.0.0.1:8080/cgi-bin/view?file=../../etc/passwd'
```

## 수정

decode가 끝난 값에 `/`가 있으면 거절한다. `../` 문자열만 지우거나 decode 전 값을 검사하면 `..%2F` 같은 payload가 남는다.

```sh
file=$(httpd -d "${QUERY_STRING#file=}")
case $file in
	*/* | .*) file= ;;
esac
```

고친 뒤 `app/`에서 `docker compose build`, `docker compose up -d`로 다시 띄운다.
