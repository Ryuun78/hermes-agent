#!/usr/bin/env bash
# hermes-agent (Ryuun78 포크 또는 기관 비공개 저장소) 용 Git/GitHub 1회 세팅 스크립트.
#
# 사용법 (맥 터미널, 저장소 폴더 안에서):
#   bash docs/github/setup-mac.sh
#
# 무엇이든 바꾸기 전에 먼저 물어봅니다. 여러 번 실행해도 안전합니다.
# 하는 일:
#   1. 커밋 작성자 이름/이메일을 GitHub 계정과 연결되는 값으로 설정
#   2. 원본(NousResearch) 저장소를 'upstream' 이라는 이름으로 등록 (받기 전용)
#   3. 초보자에게 무난한 git 기본값 설정 (pull 방식, 삭제된 브랜치 정리 등)
#   4. GitHub 로그인 상태 확인 (GitHub CLI 'gh')
#   5. 원본보다 몇 커밋 뒤처져 있는지 확인
set -uo pipefail

UPSTREAM_URL="https://github.com/NousResearch/hermes-agent.git"
DEFAULT_NAME="Ryuun"
# GitHub 이 계정마다 만들어 주는 비공개용 이메일. 커밋이 계정(Ryuun78)과 연결되고,
# 실제 이메일 주소는 공개 저장소에 드러나지 않는다.
DEFAULT_EMAIL="198872789+Ryuun78@users.noreply.github.com"

step() { printf '\n== %s\n' "$*"; }
ok()   { printf '  [OK] %s\n' "$*"; }
info() { printf '  - %s\n' "$*"; }
warn() { printf '  [!] %s\n' "$*"; }

# ask "질문" → 'y' 로 답하면 0 (참)
ask() {
  local reply=""
  read -r -p "  $1 [y/N] " reply || true
  [[ "$reply" =~ ^[Yy] ]]
}

# 설정 값 읽기 (없으면 빈 문자열)
cfg() { git config "$@" 2>/dev/null || true; }

# --- 0. 준비 확인 -----------------------------------------------------------
step "0. 준비 확인"
if ! command -v git >/dev/null 2>&1; then
  warn "git 이 설치되어 있지 않습니다. 터미널에서 'xcode-select --install' 을 먼저 실행하세요."
  exit 1
fi
ok "$(git --version)"

repo_root="$(git rev-parse --show-toplevel 2>/dev/null || true)"
if [[ -z "$repo_root" ]]; then
  warn "git 저장소 폴더 안에서 실행해 주세요. 예) cd ~/hermes-agent && bash docs/github/setup-mac.sh"
  exit 1
fi
cd "$repo_root" || exit 1
ok "저장소 위치: $repo_root"

origin_url="$(cfg remote.origin.url)"
if [[ "$origin_url" == *"github.com"*"/hermes-agent"* && "$origin_url" != *"NousResearch/"* ]]; then
  ok "origin (내 저장소): $origin_url"
else
  warn "origin 주소가 예상과 다릅니다: ${origin_url:-없음}"
  warn "이 스크립트는 내 hermes-agent 저장소(포크 또는 기관 저장소)를 기준으로 작성되었습니다."
  ask "그래도 계속할까요?" || exit 1
fi

# --- 1. 커밋 작성자 이름/이메일 -------------------------------------------
step "1. 커밋 작성자 (누가 커밋했는지 기록되는 이름/이메일)"
cur_name="$(cfg --global user.name)"
cur_email="$(cfg --global user.email)"
info "현재 이름  : ${cur_name:-(설정 안 됨)}"
info "현재 이메일: ${cur_email:-(설정 안 됨 → 맥 컴퓨터 이름이 대신 들어감)}"

if [[ "$cur_name" == "$DEFAULT_NAME" && "$cur_email" == "$DEFAULT_EMAIL" ]]; then
  ok "이미 GitHub 계정과 연결되는 값으로 설정되어 있습니다."
else
  info "추천 값 → 이름: $DEFAULT_NAME / 이메일: $DEFAULT_EMAIL"
  if ask "추천 값으로 설정할까요? (앞으로의 커밋부터 적용)"; then
    git config --global user.name "$DEFAULT_NAME"
    git config --global user.email "$DEFAULT_EMAIL"
    ok "설정 완료"
  else
    info "건너뜀"
  fi
fi

local_email="$(cfg --local user.email)"
if [[ -n "$local_email" && "$local_email" != "$DEFAULT_EMAIL" ]]; then
  warn "이 저장소에만 따로 지정된 이메일이 있습니다: $local_email (위 설정보다 우선 적용됨)"
  if ask "저장소 전용 이메일 설정을 지울까요?"; then
    git config --local --unset user.email
    ok "삭제 완료"
  fi
fi

# --- 2. upstream (원본 저장소) 등록 -------------------------------------------
step "2. 원본 저장소(upstream) 등록"
if git remote get-url upstream >/dev/null 2>&1; then
  ok "이미 등록됨: $(git remote get-url upstream)"
elif ask "NousResearch 원본을 'upstream' 으로 등록할까요? (업데이트 받기 전용)"; then
  git remote add upstream "$UPSTREAM_URL"
  ok "등록 완료: $UPSTREAM_URL"
else
  info "건너뜀"
fi

if git remote get-url upstream >/dev/null 2>&1; then
  # 원본의 수백 개 브랜치 대신 main 만 받아 온다.
  git config --replace-all remote.upstream.fetch "+refs/heads/main:refs/remotes/upstream/main"
  # 실수로 원본에 push 하지 않도록 push 주소를 막아 둔다.
  git remote set-url --push upstream "DISABLED-do-not-push-to-upstream"
  ok "upstream 은 main 만 받고, push 는 막아 두었습니다."
fi

# --- 3. 기본 동작 설정 -------------------------------------------------------
step "3. git 기본 동작 (이미 정해 둔 값은 건드리지 않음)"
if [[ -z "$(cfg pull.rebase)" && -z "$(cfg pull.ff)" ]]; then
  git config --global pull.rebase false
  ok "git pull 은 '합치기(merge)' 방식으로 동작 (갈라진 브랜치 경고 방지)"
else
  ok "pull 방식 이미 설정됨"
fi
if [[ -z "$(cfg fetch.prune)" ]]; then
  git config --global fetch.prune true
  ok "GitHub 에서 지운 브랜치는 내 컴퓨터 목록에서도 자동 정리"
fi
if [[ -z "$(cfg init.defaultBranch)" ]]; then
  git config --global init.defaultBranch main
  ok "새 저장소의 기본 브랜치 이름: main"
fi
if [[ "$(uname -s)" == "Darwin" && -z "$(cfg credential.helper)" ]]; then
  git config --global credential.helper osxkeychain
  ok "GitHub 로그인 정보를 맥 키체인에 저장 (매번 비밀번호 입력 방지)"
fi

# --- 4. GitHub 로그인 확인 -------------------------------------------------
step "4. GitHub 로그인 (GitHub CLI 'gh')"
if command -v gh >/dev/null 2>&1; then
  if gh auth status >/dev/null 2>&1; then
    ok "gh 로그인 되어 있음"
  else
    warn "gh 가 설치되어 있지만 로그인되어 있지 않습니다."
    if ask "지금 'gh auth login' 을 실행할까요? (브라우저에서 승인)"; then
      gh auth login --hostname github.com --git-protocol https --web || warn "로그인 실패 — 나중에 'gh auth login' 을 다시 실행하세요."
    fi
  fi
else
  info "GitHub CLI(gh) 가 없습니다. 없어도 되지만, 있으면 로그인/PR 이 쉬워집니다."
  if command -v brew >/dev/null 2>&1; then
    info "설치: brew install gh   →   로그인: gh auth login"
  else
    info "설치 안내: https://cli.github.com"
  fi
fi

# --- 5. 원본과 비교 ----------------------------------------------------------
step "5. 원본(upstream)과 비교"
if git remote get-url upstream >/dev/null 2>&1 && ask "원본의 최신 main 을 받아와서 비교해 볼까요? (내 파일은 바뀌지 않음)"; then
  if git fetch upstream; then
    counts="$(git rev-list --left-right --count main...upstream/main 2>/dev/null || true)"
    if [[ -n "$counts" ]]; then
      read -r mine theirs <<<"$counts"
      info "내 main 에만 있는 커밋 : $mine 개"
      info "원본에만 있는 새 커밋  : $theirs 개"
      if [[ "$theirs" -gt 0 ]]; then
        info "원본 업데이트를 받으려면 가이드의 '원본 업데이트 받기' 절을 따라 하세요."
      fi
    fi
  else
    warn "원본을 받아오지 못했습니다 (네트워크 확인)."
  fi
else
  info "건너뜀"
fi

# --- 요약 --------------------------------------------------------------------
step "완료 — 현재 설정"
info "이름/이메일 : $(cfg user.name) <$(cfg user.email)>"
git remote -v | sed 's/^/  - /'
printf '\n자세한 사용법은 docs/github/README.md 를 보세요.\n'
