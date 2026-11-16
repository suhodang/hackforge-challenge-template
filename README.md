# hackforge-challenge-template

Hackforge Challenge 저장소의 GitHub Template이다. 새 문제는 이 저장소에서 [Use this template]으로 private repo `hackforge-challenge-<문제>`를 만든다. 형식과 이유는 hackforge-docs의 `decisions/007-challenge-저장소.md`, `decisions/014-challenge-형식과-등록.md`에 있다.

예시 문제(`example`)는 path traversal이 있는 파일 보기 페이지다. 형식과 CI가 실제로 도는지 보여 주려고 넣었고, 새 문제를 만들면 지운다.

## 구조

| 경로 | 내용 |
|---|---|
| `app/` | 학습자 환경의 `/app`으로 복사됨. `compose.yaml`과 서비스 폴더 |
| `app/<서비스>/Dockerfile.base` | 의존성 설치. `build.sh`가 `hackforge/challenge-<SLUG>-<서비스>-base`로 빌드 |
| `app/<서비스>/Dockerfile` | 첫 줄 `FROM hackforge/challenge-<SLUG>-<서비스>-base`, 그다음은 소스 `COPY`만 |
| `meta/challenge.env` | `SLUG`, `TITLE`, `MAX_DEFENSE_ATTEMPTS` (셸 변수) |
| `meta/description.md` | 문제 목록에 보이는 설명 |
| `meta/hints/attack/1~3.md` | 공격 힌트. 방향, 위치, 공격 방법 순서 |
| `meta/hints/defense/1~3.md` | 방어 힌트. 방향, 위치, 고치는 방법 순서 |
| `meta/solution.md` | 해답(공격과 수정) |
| `meta/attack-check.sh` | 학습자의 공격이 성공했으면 0 |
| `meta/exploit.sh` | 대표 payload 중 하나라도 통하면 0. 마지막 줄에 통하는 payload |
| `meta/functional-test.sh` | 정상 기능이 모두 동작하면 0 |
| `hackforge/` | 실습 Pod 시작(`entrypoint.sh`)과 readinessProbe(`ready.sh`). 모든 문제 공통이라 고치지 않음 |
| `Dockerfile` | Challenge 이미지. `docker:dind` 위에 `app/`, `images.tar`, `hackforge/`. `meta/`는 넣지 않음 |
| `build.sh` | base 이미지, 서비스 이미지, 공개 이미지를 `images.tar`로 묶고 Challenge 이미지를 import용 tar로 저장 |
| `check.sh` | 로컬 확인. Challenge 이미지를 `--network none`으로 띄우고 검증 스크립트를 실습 Pod처럼 실행 |
| `register.sh` | `meta/`를 플랫폼 DB에 slug 기준으로 upsert |

## 새 문제 만들기

1. [Use this template]으로 `hackforge-challenge-<문제>`를 private으로 만든다
2. `meta/challenge.env`의 `SLUG`, `TITLE`, `MAX_DEFENSE_ATTEMPTS`를 바꾼다. `SLUG`는 영어 소문자, 숫자, `-`만 쓴다
3. `app/`의 예시 서비스를 지우고 문제의 서비스를 만든다. 이미지 이름의 `example`을 새 `SLUG`로 바꾼다(`compose.yaml`의 `image`, 각 `Dockerfile`의 `FROM`)
4. `meta/`의 설명, 힌트 6개, 해답, 스크립트 3개를 쓴다
5. `sh build.sh <tag>`, `sh check.sh <tag>`로 확인하고 PR을 올린다. CI가 같은 두 명령을 실행한다

## 형식 규칙

- 문제 하나는 취약점 하나를 다룬다. `exploit.sh`의 payload는 모두 그 취약점을 노린다
- 공격 검증은 웹 요청을 거쳐서만 남는 Target 쪽 증거로 판정한다. 학습자는 실습 환경에서 root라 `app/`과 DB를 볼 수 있으므로 값을 맞히는 판정(비밀번호, flag)은 쓰지 않는다
- 서비스마다 healthcheck를 둔다. DB는 TCP로 확인한다(`pg_isready -h 127.0.0.1`, `mysqladmin ping -h 127.0.0.1`). unix socket으로 확인하면 초기 데이터가 들어가기 전에 healthy가 된다
- 초기 데이터는 DB의 `/docker-entrypoint-initdb.d/`로 넣는다
- 공개 이미지는 tag를 고정하고 `pull_policy: never`를 둔다. 외부 인터넷이 필요한 기능은 넣지 않는다
- port는 `127.0.0.1:<포트>`로 publish한다. 스크립트는 그 주소로 요청한다

## 검증 스크립트

플랫폼은 실습 Pod에 exec로 들어가 스크립트 본문을 stdin으로 넘기고, 작업 폴더 `/app`에서 `sh`로 실행한다. 파일로 남지 않으므로 다른 파일을 `source`하지 않는다. 쓸 수 있는 도구는 `docker compose exec -T`, `wget`, `nc`, busybox 기본 도구다. exit code 0은 "확인하려는 일이 일어남"이고, 마지막 출력 줄은 결과 메시지로 학습자에게 보일 수 있다. 60초를 넘기면 FAIL이다.

DB는 `-h 127.0.0.1`로 TCP 접속한다. unix socket 접속은 환경에 따라 실패한다(GitHub Actions에서 MySQL `ERROR 2002`). 조회가 실패하면 "기록 없음"으로 넘기지 말고 마지막 줄에 오류를 남기고 0이 아닌 값으로 끝낸다. 그러지 않으면 공격 전 확인이 잘못된 이유로 통과한다.

## 빌드와 로컬 확인

Git Bash나 Linux 셸에서 Docker를 켜고 실행한다.

```sh
sh build.sh 0.1.0      # images.tar, challenge-<SLUG>-0.1.0.tar
sh check.sh 0.1.0
```

`check.sh`는 다음을 차례로 확인하고, 하나라도 기대와 다르면 0이 아닌 값으로 끝난다.

| 순서 | 확인 | 기대 |
|---|---|---|
| 1 | `attack-check.sh` | 0 아님 (공격 전) |
| 2 | `functional-test.sh` | 0 |
| 3 | `exploit.sh` | 0 (고치기 전) |
| 4 | `attack-check.sh` | 0 (`exploit.sh`가 증거를 남김) |
| 5 | Pod 안에서 `docker compose build`, `up -d` | 외부 통신 없이 성공 |
| 6 | `functional-test.sh` | 0 |

고친 뒤의 결과는 직접 확인한다. Challenge 이미지를 띄우고 `/app` 안 소스를 해답대로 고친 다음 다시 빌드해서, `exploit.sh`가 0이 아니고 `functional-test.sh`가 0인지 본다. 증상만 막은 수정(예: decode 전 값에서 `../`만 지움)에서 `exploit.sh`가 아직 0인지도 본다.

```sh
docker run -d --name try --privileged --network none hackforge/challenge-<SLUG>:0.1.0
docker exec -it try sh            # /app에서 소스 수정, docker compose build && docker compose up -d
MSYS_NO_PATHCONV=1 docker exec -i -w /app try sh < meta/exploit.sh; echo $?
docker rm -f try
```

## 노드에 import, 등록

```sh
scp challenge-<SLUG>-0.1.0.tar <user>@<NODE_IP>:~/
# 노드에서
sudo ctr -n k8s.io images import --platform linux/amd64 ~/challenge-<SLUG>-0.1.0.tar
```

`register.sh`는 `<PSQL>`(플랫폼 DB에 psql로 접속하는 명령, hackforge-docs `infra/account-operations.md`)에 stdin을 넘긴다. `docker compose exec`는 `-T`, `docker exec`와 `kubectl exec`는 `-i`가 필요하다.

```sh
# 개발 DB (hackforge-be의 compose)
PSQL="docker exec -i hackforge-be-postgres-1 psql -U hackforge" sh register.sh 0.1.0
```

- 같은 slug가 있으면 제목, 이미지 tag, 설명, 해답, 스크립트, 최대 시도 횟수를 갱신하고 힌트를 다시 넣는다
- `meta/` 필수 파일이 없거나 비어 있으면 DB를 건드리지 않고 끝난다
- 그 문제에 진행 중 세션이 있으면 거절한다. 세션이 끝난 뒤 다시 실행한다
- 이미지를 노드에 import하기 전에 등록하면, 그 사이 시작한 세션은 이미지를 찾지 못해 `FAILED`가 된다. import 다음에 등록한다
