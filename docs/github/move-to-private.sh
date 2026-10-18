#!/usr/bin/env bash
# 공개 포크(Ryuun78/hermes-agent)의 코드를 기관(Organization)의 비공개 저장소로 옮기는 스크립트.
#
# 사용법 (맥 터미널, 저장소 폴더 안에서):
#   bash docs/github/move-to-private.sh <기관이름> [저장소이름]
#   예) bash docs/github/move-to-private.sh myinst-ai
#
# 먼저 docs/github/organization.md 의 3~5절대로 기관과 빈 비공개 저장소를 만들어 두세요.
# 하는 일:
#   1. 새 저장소가 비공개(Private)이고 접근 가능한지 확인 (gh 로그인 상태면 없을 때 만들어 줌)
#   2. 내 main 브랜치를 전체 기록과 함께 새 저장소로 올림 (원본의 수백 개 브랜치는 옮기지 않음)
#   3. 이 폴더의 origin 을 새 저장소로 바꾸고, 옛 공개 포크는 'old-public-fork' 로 이름만 바꿔 둠
# 옛 공개 포크는 지우지 않습니다. 삭제는 확인 후 GitHub 웹에서 직접 하세요.
set -uo pipefail

ORG="${1:-}"
REPO="${2:-hermes-agent}"
UPSTREAM_URL="https://github.com/NousResearch/hermes-agent.git"
OLD_REMOTE="old-public-fork"

step() { printf '\n== %s\n' "$*"; }
ok()   { printf '  [OK] %s\n' "$*"; }
info() { printf '  - %s\n' "$*"; }
warn() { printf '  [!] %s\n' "$*"; }
die()  { printf '  [!] %s\n' "$*"; exit 1; }

# ask "질문" → 'y' 로 답하면 0 (참)
ask() {
  local reply=""
  read -r -p "  $1 [y/N] " reply || true
  [[ "$reply" =~ ^[Yy] ]]
}

cfg() { git config "$@" 2>/dev/null || true; }

if [[ -z "$ORG" ]]; then
  echo "사용법: bash docs/github/move-to-private.sh <기관이름> [저장소이름]"
  echo "예)     bash docs/github/move-to-private.sh myinst-ai"
  exit 1
fi
[[ "$ORG" =~ ^[A-Za-z0-9-]+$ ]] || die "기관 이름에는 영문, 숫자, 하이픈(-)만 쓸 수 있습니다: $ORG"
[[ "$REPO" =~ ^[A-Za-z0-9._-]+$ ]] || die "저장소 이름이 올바르지 않습니다: $REPO"
NEW_URL="https://github.com/$ORG/$REPO.git"
NEW_WEB="https://github.com/$ORG/$REPO"

# --- 0. 준비 확인 -----------------------------------------------------------
step "0. 준비 확인"
command -v git >/dev/null 2>&1 || die "git 이 없습니다. 'xcode-select --install' 을 먼저 실행하세요."
repo_root="$(git rev-parse --show-toplevel 2>/dev/null || true)"
[[ -n "$repo_root" ]] || die "hermes-agent 저장소 폴더 안에서 실행해 주세요. 예) cd ~/.hermes/hermes-agent"
cd "$repo_root" || exit 1
ok "저장소 위치: $repo_root"

origin_url="$(cfg remote.origin.url)"
if [[ "$origin_url" == "$NEW_URL" || "$origin_url" == "$NEW_WEB" ]]; then
  ok "이미 옮겨져 있습니다. origin = $origin_url"
  exit 0
fi
info "지금 origin: ${origin_url:-없음}"
info "옮길 곳    : $NEW_URL"

git rev-parse --verify --quiet main >/dev/null || die "main 브랜치가 없습니다."
if [[ -n "$(git status --porcelain)" ]]; then
  warn "커밋하지 않은 수정이 있습니다. 이 수정은 옮겨지지 않고 이 폴더에 그대로 남습니다."
  ask "그래도 계속할까요?" || exit 1
fi

if [[ -n "$origin_url" ]]; then
  info "지금 GitHub 포크의 최신 상태를 확인하는 중..."
  if git fetch --quiet origin main 2>/dev/null; then
    behind="$(git rev-list --count main..FETCH_HEAD 2>/dev/null || echo 0)"
    if [[ "$behind" -gt 0 ]]; then
      warn "GitHub 포크에 이 맥에는 없는 커밋이 ${behind}개 있습니다 (예: Claude 작업을 merge 한 것)."
      die "먼저 'git switch main && git pull' 로 받아온 다음 다시 실행하세요."
    fi
    ok "맥의 main 이 최신입니다."
  else
    warn "지금 origin 에서 받아오지 못했습니다. 맥의 main 을 그대로 옮깁니다."
  fi
fi

# --- 1. 새 저장소 확인 -------------------------------------------------------
step "1. 새 비공개 저장소 확인: $ORG/$REPO"
if command -v gh >/dev/null 2>&1 && gh auth status >/dev/null 2>&1; then
  visibility="$(gh repo view "$ORG/$REPO" --json visibility -q .visibility 2>/dev/null || true)"
  if [[ -z "$visibility" ]]; then
    warn "$ORG/$REPO 저장소가 없거나 접근 권한이 없습니다."
    if ask "gh 로 비공개(Private) 저장소를 지금 만들까요?"; then
      gh repo create "$ORG/$REPO" --private --description "기관용 Hermes Agent (비공개)" \
        || die "만들지 못했습니다. 기관 이름과 기관 Owner 권한을 확인하세요."
      visibility="PRIVATE"
      ok "만들었습니다: $NEW_WEB"
    else
      die "웹에서 빈 비공개 저장소를 만든 뒤 다시 실행하세요 (organization.md 5-1절)."
    fi
  fi
  [[ "$visibility" == "PRIVATE" ]] \
    || die "$ORG/$REPO 가 비공개가 아닙니다 (지금: $visibility). 저장소 Settings 에서 Private 로 바꾼 뒤 다시 실행하세요."
  ok "비공개(Private) 저장소 확인"
else
  info "gh 로그인이 안 되어 있어 공개 여부를 자동으로 확인할 수 없습니다."
  ask "$NEW_WEB 를 Private 로, README 없이 만든 것이 맞나요?" || die "organization.md 5-1절대로 먼저 만들어 주세요."
fi

git ls-remote "$NEW_URL" >/dev/null 2>&1 \
  || die "새 저장소에 접근할 수 없습니다. 이름이 맞는지, 'gh auth login' 으로 로그인했는지 확인하세요."

local_main="$(git rev-parse main)"
remote_main="$(git ls-remote --heads "$NEW_URL" main 2>/dev/null | cut -f1)"
if [[ -n "$remote_main" && "$remote_main" != "$local_main" ]]; then
  if ! git merge-base --is-ancestor "$remote_main" main 2>/dev/null; then
    warn "새 저장소가 비어 있지 않고, 맥의 main 과 다른 내용이 들어 있습니다 (README 를 추가했거나 다른 코드)."
    die "저장소를 지우고 'README 추가' 없이 다시 만든 뒤 실행하세요."
  fi
fi

# --- 2. 코드 올리기 ----------------------------------------------------------
step "2. main 브랜치 올리기"
commit_count="$(git rev-list --count main 2>/dev/null || echo '?')"
if [[ "$remote_main" == "$local_main" ]]; then
  ok "이미 올라가 있습니다."
else
  info "커밋 ${commit_count}개 기록을 함께 올립니다. 처음에는 몇 분 걸릴 수 있습니다."
  ask "main 을 $NEW_URL 로 올릴까요?" || exit 1
  git push "$NEW_URL" main:main || die "올리지 못했습니다. 위 오류 메시지를 확인하세요."
  ok "올리기 완료"
fi

# --- 3. 이 폴더가 새 저장소를 바라보게 하기 ---------------------------------
step "3. origin 을 새 저장소로 바꾸기"
if ! ask "이 폴더의 origin 을 새 비공개 저장소로 바꿀까요? (옛 포크는 '$OLD_REMOTE' 로 남겨 둠)"; then
  info "건너뜀. 코드는 새 저장소에 올라갔지만, 이 폴더는 아직 옛 포크로 push/pull 합니다."
  exit 0
fi
if [[ -n "$origin_url" ]]; then
  if git remote get-url "$OLD_REMOTE" >/dev/null 2>&1; then
    git remote remove origin
  else
    git remote rename origin "$OLD_REMOTE"
    ok "옛 포크 → '$OLD_REMOTE' 로 이름 변경"
  fi
fi
git remote add origin "$NEW_URL"
git fetch --quiet origin main
git branch --quiet --set-upstream-to=origin/main main
ok "origin = $NEW_URL (git push / git pull 은 이제 새 저장소로)"

if ! git remote get-url upstream >/dev/null 2>&1; then
  git remote add upstream "$UPSTREAM_URL"
  git config --replace-all remote.upstream.fetch "+refs/heads/main:refs/remotes/upstream/main"
  git remote set-url --push upstream "DISABLED-do-not-push-to-upstream"
  ok "원본(upstream) 등록 — 원본 업데이트는 지금처럼 받을 수 있습니다."
fi

# --- 요약 --------------------------------------------------------------------
step "완료"
git remote -v | sed 's/^/  - /'
cat <<EOF

다음 할 일 (docs/github/organization.md 6절):
  1. $NEW_WEB 를 열어 파일과 자물쇠(Private) 표시를 확인
  2. Claude GitHub 앱이 새 저장소에 접근하도록 설정
  3. 1~2주 써 보고 문제없으면 옛 공개 포크 삭제 여부 결정
EOF
