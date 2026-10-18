# GitHub 사용 가이드 (Ryuun78/hermes-agent 기준)

이 문서는 **내 포크 저장소 `Ryuun78/hermes-agent`** 를 맥 미니와 Claude Code 로 함께
관리하는 방법을 처음부터 설명합니다. 순서대로 한 번 읽고, 이후에는
[자주 쓰는 명령어](#8-자주-쓰는-명령어)와 [문제 해결](#9-문제-해결)만 찾아보면 됩니다.

> 기관 전용 **비공개** 공간(Organization)을 만들고 이 저장소를 그리로 옮기려면
> [organization.md](organization.md) 를 보세요. 옮긴 뒤에도 이 문서의 사용법은 그대로이고,
> `origin` 이 공개 포크 대신 기관 저장소가 된다는 점만 다릅니다.

---

## 1. 큰 그림: 코드가 있는 세 곳

```
NousResearch/hermes-agent    upstream = 원본 프로젝트 (읽기만)
        |
        |  (3) 원본 업데이트 받기: Sync fork 또는 git fetch upstream
        v
Ryuun78/hermes-agent         origin = GitHub 위의 내 포크 (공개)
   - main        내가 실제로 쓰는 코드
   - claude/...  Claude Code 가 작업을 올리는 브랜치 → PR 로 main 에 합침
        ^              |
        | (1) git push | (2) git pull
        |              v
맥 미니의 hermes-agent 폴더   로컬 = 실제로 Hermes 를 실행하는 곳
```

- **맥에서 고친 것**은 `git push` 해야 GitHub 에 올라갑니다. 올리기 전에는 Claude 도 못 봅니다.
- **GitHub 에서 바뀐 것**(Claude 작업을 합친 것 등)은 맥에서 `git pull` 해야 내려옵니다.
- **원본 프로젝트의 새 기능**은 자동으로 오지 않습니다. 직접 받아와야 합니다 ([6절](#6-원본nousresearch-업데이트-받기)).

## 2. 꼭 알아야 할 단어

| 단어 | 뜻 | 비유 |
|---|---|---|
| 저장소 (repository) | 프로젝트 폴더 + 모든 변경 기록 | 문서 + 버전 기록 전체 |
| 커밋 (commit) | "여기까지 저장" 하는 한 번의 기록. 메시지를 붙임 | 게임 세이브 포인트 |
| 브랜치 (branch) | 기록을 갈라서 따로 작업하는 줄기. 기본 줄기는 `main` | 문서 사본에서 작업하기 |
| push | 내 컴퓨터의 커밋을 GitHub 로 올리기 | 업로드 |
| pull | GitHub 의 새 커밋을 내 컴퓨터로 받기 | 다운로드 |
| 포크 (fork) / upstream | 남의 저장소를 내 계정으로 복사한 것 / 복사해 온 원본 | 원본 문서의 내 사본 |
| PR (Pull Request) | "이 브랜치를 main 에 합쳐 주세요" 하는 요청. 바뀐 내용을 보고 합칠지 결정 | 결재 요청서 |
| merge | 두 브랜치의 변경을 하나로 합치기 | 결재 승인 후 반영 |
| 충돌 (conflict) | 같은 줄을 양쪽에서 다르게 고쳐서 자동으로 못 합치는 상황 | 두 사람이 같은 문장을 다르게 고침 |

## 3. 지금 저장소 상태 (2026-10 점검)

| 항목 | 상태 | 할 일 |
|---|---|---|
| 공개 여부 | **공개(public)** 포크 — 누구나 코드와 커밋 기록을 볼 수 있음 | [7절 보안 수칙](#7-보안-수칙-공개-저장소) 꼭 읽기 |
| 커밋 작성자 이메일 | `…@Ryuuns-Mac-mini.local` (맥 컴퓨터 이름) → GitHub 계정과 연결되지 않아 프로필에 기록이 안 잡힘 | [4절 세팅 스크립트](#4-처음-한-번만-맥-세팅)로 해결 |
| 작업 방식 | `main` 에 바로 커밋/푸시 | 혼자면 괜찮음. Claude 작업은 PR 로 합치기 ([5절 B](#b-claude-code-에게-맡겼을-때-pr-로-합치기)) |
| upstream 등록 | 맥 설정에 따라 다름 | 세팅 스크립트가 확인/등록 |
| GitHub Actions | 원본 프로젝트의 자동 테스트가 내 포크에서도 돌아감. 최근 `main` 커밋 옆에 ❌ 가 보이면 그 테스트가 실패했다는 뜻 | 무시해도 Hermes 실행에는 영향 없음. 알림이 귀찮으면 끄기 ([9절](#9-문제-해결)) |
| 브랜치 목록 | 원본의 브랜치 수백 개가 같이 복사되어 있음 | 신경 쓸 것은 `main` 과 `claude/...` 뿐 |

## 4. 처음 한 번만: 맥 세팅

### 4-1. 세팅 스크립트 실행 (추천)

맥 터미널에서:

```bash
cd ~/.hermes/hermes-agent  # Hermes 기본 설치 폴더 (다른 곳에 있으면 그 경로로)
git pull                   # 이 가이드와 스크립트를 받아오기
bash docs/github/setup-mac.sh
```

스크립트는 **바꾸기 전에 매번 `[y/N]` 으로 물어봅니다.** 여러 번 실행해도 안전합니다. 하는 일:

1. 커밋 작성자를 `Ryuun <198872789+Ryuun78@users.noreply.github.com>` 으로 설정
   - GitHub 이 계정마다 주는 비공개용 주소라서, 커밋이 내 계정과 연결되면서 **실제 Gmail 은 공개되지 않습니다.**
   - 이미 올라간 예전 커밋은 그대로이고, **앞으로의 커밋부터** 적용됩니다.
2. 원본을 `upstream` 이라는 이름으로 등록 (main 만 받고, 실수로 원본에 push 하지 못하게 막음)
3. 초보자에게 무난한 기본값: `git pull` 은 합치기 방식, 지워진 브랜치 자동 정리, 로그인 정보는 맥 키체인에 저장
4. GitHub 로그인 상태 확인 (`gh` 가 있으면)
5. 원본보다 커밋이 몇 개 뒤처져 있는지 표시

### 4-2. GitHub 로그인 (push 할 때 필요)

가장 쉬운 방법은 GitHub CLI 입니다.

```bash
brew install gh     # Homebrew 가 있다면
gh auth login       # GitHub.com → HTTPS → "Login with a web browser" 선택
```

> GitHub 은 계정 비밀번호로 push 하는 것을 막아 두었습니다. "Password authentication is not supported"
> 같은 오류가 나오면 위 `gh auth login` 을 하면 해결됩니다.

### 4-3. 스크립트 없이 직접 하려면

```bash
git config --global user.name  "Ryuun"
git config --global user.email "198872789+Ryuun78@users.noreply.github.com"
git remote add upstream https://github.com/NousResearch/hermes-agent.git
git config --global pull.rebase false
git remote -v       # origin = Ryuun78, upstream = NousResearch 이면 성공
```

## 5. 매일 쓰는 흐름

### A. 맥에서 직접 고쳤을 때 (지금까지 하던 방식)

```bash
git status                    # ① 무엇이 바뀌었는지 확인 (가장 자주 쓰는 명령)
git diff                      # ② 바뀐 내용 자세히 보기 (q 로 나가기)
git add 파일경로               # ③ 커밋에 넣을 파일 담기
git diff --staged             # ④ 담긴 내용 최종 확인 — 비밀번호/토큰이 없는지!
git commit -m "fix(cron): 무엇을 왜 고쳤는지"   # ⑤ 저장
git push                      # ⑥ GitHub 에 올리기
```

- `git add .` (전부 담기)는 편하지만 원치 않는 파일까지 올라갈 수 있습니다. 공개 저장소이므로 ④ 확인을 습관으로.
- 커밋 메시지는 지금처럼 `feat(…)`, `fix(…)`, `docs(…)` 형식이면 충분합니다.
- `git push` 가 거절되면(rejected) 먼저 `git pull` 하고 다시 `git push` ([9절](#9-문제-해결)).

### B. Claude Code 에게 맡겼을 때 (PR 로 합치기)

Claude Code(웹/앱)는 클라우드에서 **GitHub 에 올라간 코드**를 받아 작업하고, 결과를
`claude/…` 이름의 브랜치에 올립니다. `main` 은 직접 건드리지 않습니다.

1. **맡기기 전에**: 맥에서 고친 게 있으면 먼저 `git push` (안 그러면 Claude 는 옛날 코드로 작업)
2. Claude 가 끝나면 GitHub 저장소 페이지에 노란 배너 **"claude/… had recent pushes — Compare & pull request"** 가 뜹니다. 누르세요.
   (Claude 에게 "PR 만들어 줘" 라고 해도 됩니다.)
3. ⚠️ **맨 위 `base repository` 가 `Ryuun78/hermes-agent` 인지 꼭 확인!**
   포크에서 PR 을 만들면 GitHub 이 기본으로 **원본(NousResearch)** 을 선택합니다.
   그대로 만들면 내 개인 작업이 원본 프로젝트 관리자들에게 PR 로 공개됩니다.
   `base: main` ← `compare: claude/…` 가 되도록 맞추세요.
4. **Files changed** 탭에서 바뀐 내용을 훑어봅니다. 초록색 = 추가, 빨간색 = 삭제.
5. 괜찮으면 **Merge pull request → Confirm merge**. 그 다음 **Delete branch** 를 눌러도 안전합니다.
6. 맥에서 받아오기:
   ```bash
   git switch main
   git pull
   ```
7. Hermes 가 실행 중이었다면 재시작해야 바뀐 코드가 적용됩니다.

> 마음에 안 들면 Merge 하지 말고 **Close pull request** 를 누르면 끝입니다. `main` 은 그대로입니다.

### C. 맥에서 큰 작업을 안전하게 하고 싶을 때 (브랜치 쓰기)

```bash
git switch -c my-experiment       # 새 브랜치 만들고 이동
# ... 수정 / add / commit ...
git push -u origin my-experiment  # 처음 올릴 때만 -u origin 브랜치이름
# GitHub 에서 PR 만들어 main 에 합치거나, 망했으면 그냥 버림:
git switch main && git branch -D my-experiment
```

## 6. 원본(NousResearch) 업데이트 받기

원본 프로젝트는 계속 업데이트되지만, 포크에는 자동으로 들어오지 않습니다.
내 `main` 에는 원본에 없는 내 커밋이 있어서, 받을 때 **합치기(merge)** 가 일어납니다.

### 방법 1: GitHub 웹의 Sync fork 버튼 (충돌이 없을 때)

1. https://github.com/Ryuun78/hermes-agent 에서 `This branch is N commits ahead of, M commits behind …` 문구 옆 **Sync fork** 클릭
2. **Update branch** 클릭
3. 맥에서 `git pull`

> ⛔ **"Discard N commits" 버튼은 절대 누르지 마세요.** GitHub 의 내 main 에서 내 커밋(캘린더 도우미,
> cron 수정, DEV 문서 등)을 지우고 원본과 똑같이 만들어 버립니다.
> "충돌이 있어 자동으로 못 합친다"는 안내가 나오면 방법 2 로 하세요.

### 방법 2: 맥 터미널에서 (충돌이 있어도 가능)

```bash
git switch main
git pull                      # 먼저 내 포크 최신으로
git fetch upstream            # 원본의 새 커밋 받아오기 (내 파일은 아직 안 바뀜)
git merge upstream/main       # 합치기 — 편집기가 뜨면 저장 후 닫기 (vim 이면 :wq)
```

- `Automatic merge failed; fix conflicts` 가 나오면 → 아래 **충돌 해결**
- 합친 뒤 Hermes 가 잘 도는지 확인하고 `git push`
- 겁이 나면 언제든 `git merge --abort` 로 합치기 전 상태로 돌아갈 수 있습니다.

**충돌 해결**: `git status` 에 `both modified` 로 나오는 파일을 열면 이런 표시가 있습니다.

```
<<<<<<< HEAD
내 main 의 내용
=======
원본(upstream)의 새 내용
>>>>>>> upstream/main
```

둘 중 맞는 쪽(또는 둘을 섞은 것)만 남기고 `<<<<<<<`, `=======`, `>>>>>>>` 줄을 지운 뒤:

```bash
git add 그파일
git commit                    # 메시지는 자동으로 채워져 있음
git push
```

어려우면 Claude 에게 "upstream 업데이트 받아서 충돌 해결해 줘" 라고 맡겨도 됩니다
(Claude 는 `claude/…` 브랜치에 결과를 올리고, 위 5-B 처럼 PR 로 합치면 됩니다).

> 💡 원본 파일(`cron/scheduler.py`, `gateway/run.py` 등)을 직접 많이 고칠수록 업데이트 때 충돌이 늘어납니다.
> 나만 쓰는 기능은 가능하면 `~/.hermes/plugins/`, `~/.hermes/scripts/`, `~/.hermes/skills/` 처럼
> 저장소 **밖**에 두면 원본 업데이트가 훨씬 쉬워집니다 (`AGENTS.md` 의 Plugins 절 참고).

## 7. 보안 수칙 (공개 저장소)

이 저장소는 **공개**이고, GitHub 에 한 번 올라간 내용은 파일을 지워도 **커밋 기록에 남습니다.**

1. **절대 커밋하면 안 되는 것**: `.env`, API 키, 봇 토큰, `google_token.json`, `google_client_secret.json`,
   비밀번호, 개인 이메일/전화번호/채팅 ID.
   - `.env` 는 `.gitignore` 에 있어서 자동으로 제외됩니다.
   - `~/.hermes/` 폴더는 저장소 밖이라 안전합니다. 토큰/설정은 계속 거기에 두세요.
2. 커밋 전에 `git diff --staged` 로 담긴 내용을 확인하는 습관.
3. Hermes/Claude 가 만든 보고서(`docs/dev/…`)나 테스트에 실제 개인 정보가 들어가지 않았는지 확인.
   테스트에는 `user@example.com` 같은 가짜 값을 쓰면 됩니다.
4. **토큰이나 비밀번호를 실수로 올렸다면**: 파일에서 지우는 것으로는 부족합니다.
   **그 키를 즉시 폐기하고 새로 발급**하세요 (텔레그램 BotFather 의 `/revoke`, 각 서비스 콘솔 등).
5. 저장소를 비공개로 하고 싶다면: 포크는 설정에서 바로 비공개로 바꿀 수 없어서,
   새 비공개 저장소를 만들어 옮겨야 합니다 → [organization.md](organization.md).

## 8. 자주 쓰는 명령어

| 하고 싶은 것 | 명령 |
|---|---|
| 지금 상태 보기 | `git status` |
| 바뀐 내용 보기 | `git diff` (담은 것은 `git diff --staged`) |
| 최근 기록 보기 | `git log --oneline -10` |
| 지금 브랜치 이름 | `git branch --show-current` |
| 파일 담기 / 담기 취소 | `git add 파일` / `git restore --staged 파일` |
| 커밋 | `git commit -m "메시지"` |
| 올리기 / 받기 | `git push` / `git pull` |
| 브랜치 이동 / 새로 만들기 | `git switch 이름` / `git switch -c 이름` |
| 수정한 파일 원래대로 (커밋 전, **되돌릴 수 없음**) | `git restore 파일` |
| 원본 업데이트 받기 | `git fetch upstream && git merge upstream/main` |
| 원격 저장소 주소 확인 | `git remote -v` |

## 9. 문제 해결

**`! [rejected] main -> main (fetch first)` / `Updates were rejected`**
GitHub 에 내 컴퓨터에 없는 커밋이 있습니다 (예: Claude PR 을 merge 함). `git pull` 후 다시 `git push`.

**`Your branch is behind 'origin/main'`**
받을 게 있다는 뜻입니다. `git pull`.

**`You have divergent branches and need to specify how to reconcile them`**
pull 방식이 설정되지 않은 경우입니다. 세팅 스크립트를 실행하거나 `git config --global pull.rebase false` 후 다시 `git pull`.

**`error: Your local changes would be overwritten`**
커밋 안 한 수정이 있는 상태에서 pull/switch 를 했습니다. 먼저 커밋하거나, 잠시 치워 두기:
`git stash` → `git pull` → `git stash pop`.

**`Authentication failed` / `Password authentication is not supported`**
`gh auth login` 으로 다시 로그인 ([4-2](#4-2-github-로그인-push-할-때-필요)).

**방금 한 커밋을 취소하고 싶다**
- 아직 push 전: `git reset --soft HEAD~1` (커밋만 취소, 수정 내용은 그대로 남음)
- 이미 push 함: `git revert 커밋번호` (취소하는 커밋을 새로 만듦 → `git push`). 커밋번호는 `git log --oneline` 에서 확인.

**merge 중에 편집기(vim)가 떠서 못 나가겠다**
`Esc` 누르고 `:wq` 입력 후 Enter.

**GitHub Actions 실패 메일(❌)이 귀찮다**
- 알림만 줄이기: GitHub 오른쪽 위 프로필 → **Settings → Notifications → Actions** 에서 이메일 끄기
- 포크에서 자동 실행 자체를 끄기: 저장소 **Settings → Actions → General → Disable actions**
  (원본 프로젝트용 테스트라서 꺼도 Hermes 실행에는 영향이 없습니다.)

**뭐가 뭔지 모르겠다 / 망가진 것 같다**
`git status` 결과를 그대로 복사해서 Claude 에게 물어보세요. 커밋된 내용은 거의 항상 되살릴 수 있습니다.

## 10. 첫 연습: 이 가이드를 PR 로 합쳐 보기

이 문서와 세팅 스크립트는 Claude 가 `claude/github-setup-guide-xdtotv` 브랜치에 올려 두었습니다.
[5-B](#b-claude-code-에게-맡겼을-때-pr-로-합치기) 순서 그대로 연습해 보세요.

1. https://github.com/Ryuun78/hermes-agent/compare/main...claude/github-setup-guide-xdtotv 열기
2. `base repository: Ryuun78/hermes-agent`, `base: main` 인지 확인 → **Create pull request**
3. **Files changed** 확인 → **Merge pull request** → **Confirm merge** → **Delete branch**
4. 맥에서 `git switch main && git pull`
5. `bash docs/github/setup-mac.sh` 실행 ([4절](#4-처음-한-번만-맥-세팅))
6. 확인: `git config user.email` 이 `198872789+Ryuun78@users.noreply.github.com` 이고,
   `git remote -v` 에 `upstream` 이 보이면 세팅 완료입니다.
