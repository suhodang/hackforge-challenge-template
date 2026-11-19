#!/bin/sh
# 문제 등록(ADR 014 "빌드와 등록"). meta/를 읽어 플랫폼 DB의 challenges, challenge_hints에 slug 기준으로 upsert한다
# 사용: PSQL="<PSQL>" sh register.sh <tag>
#   <PSQL>: 플랫폼 DB에 psql로 접속하는 명령. stdin을 넘길 수 있어야 함(docker exec -i, kubectl exec -i)
set -eu
cd "$(dirname "$0")"
export MSYS_NO_PATHCONV=1   # Windows Git Bash가 / 로 시작하는 파일 내용을 경로로 바꾸지 않게
tag=${1:?사용: PSQL="<PSQL>" sh register.sh <tag>}
: "${PSQL:?PSQL에 플랫폼 DB psql 명령을 넣어야 함}"

missing=
for f in challenge.env description.md solution.md attack-check.sh exploit.sh functional-test.sh \
	hints/attack/1.md hints/attack/2.md hints/attack/3.md hints/defense/1.md hints/defense/2.md hints/defense/3.md; do
	[ -s "meta/$f" ] || { echo "meta/$f 없음 또는 비어 있음" >&2; missing=1; }
done
[ -z "$missing" ] || exit 1
. meta/challenge.env
: "${SLUG:?meta/challenge.env에 SLUG 없음}" "${TITLE:?meta/challenge.env에 TITLE 없음}"
: "${MAX_DEFENSE_ATTEMPTS:?meta/challenge.env에 MAX_DEFENSE_ATTEMPTS 없음}"
# 문제 정보(ADR 020). 분류 키가 목록에 있는지는 DB FK가 확인하고, 없으면 transaction 전체가 취소된다
: "${CATEGORY:?meta/challenge.env에 CATEGORY 없음}" "${DIFFICULTY:?meta/challenge.env에 DIFFICULTY 없음}"
: "${ESTIMATED_MINUTES:?meta/challenge.env에 ESTIMATED_MINUTES 없음}" "${SUMMARY:?meta/challenge.env에 SUMMARY 없음}"
case "$DIFFICULTY" in
INTRO | BEGINNER | INTERMEDIATE | ADVANCED) ;;
*) echo "DIFFICULTY는 INTRO, BEGINNER, INTERMEDIATE, ADVANCED 중 하나여야 함: $DIFFICULTY" >&2; exit 1 ;;
esac
case "$ESTIMATED_MINUTES" in
'' | *[!0-9]* | 0*) echo "ESTIMATED_MINUTES는 1 이상 정수(분)여야 함: $ESTIMATED_MINUTES" >&2; exit 1 ;;
esac
# 글자 수로 센다(한글 한 글자 = 1). DB도 80자를 넘으면 거절한다
n=$(printf %s "$SUMMARY" | LC_ALL=C.UTF-8 wc -m)
[ "$n" -le 80 ] || { echo "SUMMARY는 80자 이내여야 함: ${n}자" >&2; exit 1; }

# 파일 내용은 psql 변수로 넘기고 SQL에서는 :'변수'로만 쓴다(문자열을 이어 붙이지 않음)
$PSQL -X -q -v ON_ERROR_STOP=1 \
	-v slug="$SLUG" -v title="$TITLE" -v image="hackforge/challenge-$SLUG:$tag" -v max="$MAX_DEFENSE_ATTEMPTS" \
	-v category="$CATEGORY" -v difficulty="$DIFFICULTY" -v minutes="$ESTIMATED_MINUTES" -v summary="$SUMMARY" \
	-v description="$(cat meta/description.md)" -v solution="$(cat meta/solution.md)" \
	-v attack_check="$(cat meta/attack-check.sh)" -v exploit="$(cat meta/exploit.sh)" \
	-v functional_test="$(cat meta/functional-test.sh)" \
	-v a1="$(cat meta/hints/attack/1.md)" -v a2="$(cat meta/hints/attack/2.md)" -v a3="$(cat meta/hints/attack/3.md)" \
	-v d1="$(cat meta/hints/defense/1.md)" -v d2="$(cat meta/hints/defense/2.md)" -v d3="$(cat meta/hints/defense/3.md)" <<'SQL'
BEGIN;
-- psql 변수는 DO 블록 안에서 치환되지 않아 transaction 설정값으로 넘긴다
SELECT set_config('hackforge.slug', :'slug', true) AS _ \gset
-- 문제 행을 잠가, 확인하는 동안 그 문제로 새 세션이 들어오지 못하게 한다(lab_sessions FK 확인이 기다림)
DO $$
BEGIN
	PERFORM 1 FROM challenges WHERE slug = current_setting('hackforge.slug') FOR UPDATE;
	IF EXISTS (SELECT 1 FROM lab_sessions s JOIN challenges c ON c.id = s.challenge_id
	           WHERE c.slug = current_setting('hackforge.slug') AND s.status NOT IN ('DELETED', 'FAILED')) THEN
		RAISE EXCEPTION '진행 중 세션이 있어 등록하지 않음. 세션이 끝난 뒤 다시 실행';
	END IF;
END $$;
-- created_at은 처음 등록한 시각이라 갱신하지 않는다(새 문제 표시가 다시 등록해도 바뀌지 않게)
INSERT INTO challenges (slug, title, image, description, solution, attack_check, exploit, functional_test, max_defense_attempts,
	category_key, difficulty, estimated_minutes, summary)
VALUES (:'slug', :'title', :'image', :'description', :'solution', :'attack_check', :'exploit', :'functional_test', :'max',
	:'category', :'difficulty', :'minutes', :'summary')
ON CONFLICT (slug) DO UPDATE SET
	title = EXCLUDED.title, image = EXCLUDED.image, description = EXCLUDED.description, solution = EXCLUDED.solution,
	attack_check = EXCLUDED.attack_check, exploit = EXCLUDED.exploit, functional_test = EXCLUDED.functional_test,
	max_defense_attempts = EXCLUDED.max_defense_attempts, category_key = EXCLUDED.category_key,
	difficulty = EXCLUDED.difficulty, estimated_minutes = EXCLUDED.estimated_minutes, summary = EXCLUDED.summary,
	updated_at = now()
RETURNING id AS challenge_id \gset
DELETE FROM challenge_hints WHERE challenge_id = :challenge_id;
INSERT INTO challenge_hints (challenge_id, stage, position, content) VALUES
	(:challenge_id, 'ATTACK', 1, :'a1'), (:challenge_id, 'ATTACK', 2, :'a2'), (:challenge_id, 'ATTACK', 3, :'a3'),
	(:challenge_id, 'DEFENSE', 1, :'d1'), (:challenge_id, 'DEFENSE', 2, :'d2'), (:challenge_id, 'DEFENSE', 3, :'d3');
COMMIT;
\echo 등록함: :slug :image (id :challenge_id)
SQL
