# 기관 전용 비공개 공간 만들기와 관리 (GitHub Organization)

GitHub 에서 "기관만의 비공개 공간"은 **조직(Organization)** 을 만들고, 그 안에 **비공개(Private) 저장소**를
두는 방식으로 만듭니다. 이 문서는 조직을 만들고, 지금의 공개 포크(`Ryuun78/hermes-agent`)를
그 안으로 옮기고, 사람과 권한을 관리하는 방법을 설명합니다.

> 기본 Git 사용법(push, pull, PR 등)은 [README.md](README.md) 를 먼저 보세요.

---

## 1. 조직(Organization)이란

개인 계정(`Ryuun78`)은 **사람**의 공간이고, 조직은 **기관**의 공간입니다.

```
<기관이름>  (Organization, 예: github.com/myinst-ai)
  - 사람
      Owner   : 관리자. 모든 설정·결제·사람 관리 (최소 2명 권장)
      Member  : 구성원. 권한을 받은 저장소만 사용
      Outside collaborator : 외부 협력자. 지정한 저장소 하나만 접근
  - 팀 (예: 개발팀, 운영팀) → 팀 단위로 저장소 권한을 줌
  - 저장소 (모두 Private)
      hermes-agent   ← 지금 공개 포크에서 옮겨 올 것
      (앞으로 만드는 기관 저장소들)
```

개인 계정 저장소와 비교한 장점:

- 저장소의 주인이 **기관**이라서, 담당자가 바뀌어도 저장소와 기록이 그대로 남습니다.
- 사람마다, 팀마다 **읽기만/수정 가능/관리자** 같은 권한을 나눠 줄 수 있습니다.
- 기관 전체에 2단계 인증 필수, 공개 저장소 생성 금지 같은 **규칙**을 걸 수 있습니다.
- 각 구성원은 자기 개인 GitHub 계정으로 로그인해 참여합니다 (계정을 따로 만들 필요 없음).

## 2. 요금: 무료(Free)로 충분한가

| | Free (무료) | Team (사용자당 월 $4) |
|---|---|---|
| 비공개 저장소 | 무제한 | 무제한 |
| 구성원/협력자 | 무제한 | 사용자 수만큼 결제 |
| GitHub Actions (비공개 저장소 자동화) | 월 2,000분 | 월 3,000분 |
| 비공개 저장소의 브랜치 보호 규칙, 필수 리뷰어, CODEOWNERS | ✗ | ✓ |
| 비공개 저장소의 위키, Pages, 초안(Draft) PR | ✗ | ✓ |

- **처음에는 Free 로 시작하세요.** 비공개 저장소를 만들고 사람을 초대하는 데는 무료로 충분합니다.
- 여러 사람이 같이 코드를 고치게 되어 "main 에 바로 못 올리게, 반드시 검토 후 합치게" 같은 규칙이
  필요해지면 그때 Team 으로 올리면 됩니다 (Settings → Billing and plans, 언제든 변경 가능).
- 비영리단체·학교 등은 GitHub 의 무료/할인 프로그램 대상일 수 있습니다. 기관 자격을 확인해 보세요.
- 가격과 포함 기능은 바뀔 수 있으니 결제 전 https://github.com/pricing 에서 확인하세요.

## 3. 기관(조직) 만들기 — 웹에서 약 10분

조직은 GitHub 웹에서만 만들 수 있습니다 (Claude 가 대신 만들 수 없음).

1. GitHub 오른쪽 위 프로필 사진 → **Settings**
2. 왼쪽 메뉴 **Access → Organizations** → **New organization**
3. 요금제에서 **Free** 선택
4. 입력 항목
   - **Organization name**: 주소가 됩니다 (`github.com/이름`). 영문 소문자·숫자·하이픈 추천.
     예) `myinst-ai`. 나중에 바꿀 수는 있지만 주소가 바뀌어 연결을 다시 해야 하므로 신중히.
   - **Contact email**: 기관 대표 이메일 (공지·결제 알림을 받을 주소)
   - **This organization belongs to**: 기관 소유면 **A business or institution** 을 고르고 기관 정식 명칭 입력
5. 구성원 초대 화면은 지금은 **Skip** — 4절의 보안 설정을 먼저 끝낸 뒤 초대하세요.

## 4. 사람을 초대하기 전에: 첫 보안 설정

조직 페이지(`github.com/기관이름`) → **Settings** 에서:

| 메뉴 | 설정 | 이유 |
|---|---|---|
| Authentication security | **Require two-factor authentication** 켜기 | 비밀번호가 유출돼도 계정 탈취 방지. 내 계정에 2FA 를 먼저 켜야 선택 가능 |
| Member privileges → Base permissions | **No permission** (또는 소규모면 Read) | 구성원이 아무 저장소나 보지 않도록. 필요한 저장소만 팀으로 권한 부여 |
| Member privileges → Repository creation | **Public 체크 해제** (Private 만 허용) | 구성원이 실수로 공개 저장소를 만드는 것 방지 |
| Member privileges → Repository forking | **비공개 저장소 포크 허용 끄기** | 기관 코드가 개인 계정으로 복사되는 것 방지 |
| Member privileges → Repository visibility change | **구성원의 공개/비공개 변경 허용 끄기** | 비공개 저장소가 실수로 공개되는 것 방지 |
| Member privileges → Repository deletion and transfer | **구성원의 삭제/이전 허용 끄기** | 실수로 저장소를 지우는 것 방지 |
| People | **Owner 를 2명 이상** | 관리자 한 명이 계정을 잃어도 기관을 관리할 수 있도록 |

> 메뉴 이름은 GitHub 화면 개편에 따라 조금 다를 수 있습니다. 비슷한 이름의 항목을 찾으면 됩니다.

## 5. hermes-agent 를 기관 비공개 저장소로 옮기기

지금 `Ryuun78/hermes-agent` 는 원본의 **포크**라서 비공개로 바꿀 수 없습니다.
그래서 기관 안에 **새 비공개 저장소**를 만들고 코드를 옮깁니다. 커밋 기록은 그대로 따라옵니다.

### 5-1. 빈 비공개 저장소 만들기

조직 페이지 → **Repositories** → **New repository**

- **Owner**: 기관 이름 (내 개인 계정이 아님!)
- **Repository name**: `hermes-agent`
- **Private** 선택 ← 가장 중요
- **Add a README / .gitignore / license 는 모두 체크하지 않기** (빈 저장소여야 옮길 수 있음)
- **Create repository**

> 맥에서 `gh auth login` 이 되어 있으면 이 단계는 5-2 스크립트가 대신 해 줄 수도 있습니다
> (`gh` 로그인 시 기관 접근 권한도 허용해야 합니다).

### 5-2. 맥에서 옮기기 스크립트 실행

```bash
cd ~/.hermes/hermes-agent        # Hermes 설치 폴더 (다른 곳에 있으면 그 경로)
git switch main
git pull                          # 이 문서와 스크립트를 받아오고, 맥을 최신으로
bash docs/github/move-to-private.sh 기관이름     # 예) bash docs/github/move-to-private.sh myinst-ai
```

스크립트는 단계마다 `[y/N]` 으로 물어봅니다. 하는 일:

1. 새 저장소가 **Private** 인지, 비어 있는지, 접근 가능한지 확인 — 공개 저장소면 멈춤
2. 맥의 `main` 을 **전체 커밋 기록과 함께** 새 저장소로 올림 (원본에서 딸려 온 수백 개 브랜치는 옮기지 않음)
3. 이 폴더의 `origin` 을 새 저장소로 바꿈. 옛 공개 포크는 지우지 않고 `old-public-fork` 라는 이름으로 남겨 둠
4. 원본(`upstream`) 연결은 그대로 유지 — 원본 업데이트는 [README 6절](README.md#6-원본nousresearch-업데이트-받기) 방법 그대로

여러 번 실행해도 안전하고, 이미 옮겼으면 "이미 옮겨져 있습니다" 하고 끝납니다.

### 5-3. 바뀌는 것과 그대로인 것

| | 옮기기 전 | 옮긴 후 |
|---|---|---|
| `git push` / `git pull` 대상 | 공개 포크 `Ryuun78/hermes-agent` | 기관 비공개 저장소 `기관이름/hermes-agent` |
| 원본 업데이트 받기 | `git fetch upstream` | 똑같음 |
| `hermes update` | 포크로 인식, 내 커밋이 있으면 자동 합치기는 건너뛰고 안내 | 똑같음 |
| 맥의 Hermes 실행, `~/.hermes/` 설정·토큰 | — | 그대로 (파일은 하나도 안 바뀜, 재시작 불필요) |
| GitHub 로그인 | push 할 때만 필요 | **pull 할 때도 필요** (비공개라서). `gh auth login` 해 두기 |

## 6. 옮긴 뒤 할 일

### 6-1. 확인

- `https://github.com/기관이름/hermes-agent` 에 파일이 보이고, 저장소 이름 옆에 **Private** 표시가 있는지
- 맥에서 `git remote -v` → `origin` 이 기관 저장소인지
- 로그아웃한 브라우저(시크릿 창)로 위 주소를 열면 **404** 가 나와야 정상 (남에게 안 보인다는 뜻)

### 6-2. Claude Code 가 새 저장소에서 일할 수 있게 하기

1. https://claude.ai/connect-github 에서 GitHub 연결 상태 확인
2. 같은 페이지 안내대로 **Claude GitHub 앱을 기관(조직)에 설치**하고,
   **Only select repositories** 로 `hermes-agent` 만 선택 (필요한 저장소만 주는 것이 안전)
   - 기관 Owner 만 설치할 수 있습니다.
3. Claude Code 에서 **새 세션을 시작할 때 `기관이름/hermes-agent` 를 선택**
   (세션의 저장소는 시작할 때 정해집니다. 이전 세션은 계속 옛 포크를 봅니다.)

### 6-3. 옛 공개 포크 정리

옛 포크(`Ryuun78/hermes-agent`)는 스크립트가 지우지 않습니다. 계속 공개 상태라서 개인 정보가 남아 있습니다.

1. 1~2주 동안 새 저장소로 문제없이 쓰는지 확인
2. 옛 포크 페이지 → **Settings** → 맨 아래 **Danger Zone → Delete this repository**
   - ⚠️ 되돌릴 수 없습니다. 새 저장소에 모든 내용이 있는지 확인한 뒤에 하세요.
   - 원본 프로젝트(NousResearch)에는 아무 영향이 없습니다.
3. 맥에서 남은 연결 정리: `git remote remove old-public-fork`

## 7. 사람과 권한 관리

### 구성원 초대 / 내보내기

- **초대**: 조직 → **People** → **Invite member** → 상대의 GitHub 아이디 또는 이메일 → Role: **Member**
  (관리자가 더 필요할 때만 Owner)
- **외부 업체·임시 인력**: 조직 구성원으로 넣지 말고, 해당 저장소 → **Settings → Collaborators and teams →
  Add people** 로 그 저장소에만 초대 (Outside collaborator)
- **퇴사·계약 종료**: **People** → 그 사람 → **Remove from organization**.
  그 사람이 알던 공용 비밀번호·API 키가 있으면 같이 교체하세요.

### 팀으로 권한 주기 (사람이 늘어나면)

조직 → **Teams → New team** (예: `dev`, `ops`) → 팀에 사람 추가 → 팀 페이지 **Repositories → Add repository** 에서 권한 선택:

| 권한 | 할 수 있는 것 | 누구에게 |
|---|---|---|
| Read | 코드 보기, 받기(clone/pull), 이슈 작성 | 보기만 하는 사람 |
| Triage | + 이슈·PR 정리(라벨, 담당자) | 관리 보조 |
| Write | + push, PR 합치기 | 코드를 고치는 사람 |
| Maintain | + 저장소 일부 설정 | 저장소 담당자 |
| Admin | 저장소의 모든 것 (삭제·공개 전환 포함) | 최소 인원만 |

원칙: **필요한 최소 권한만**, 개인보다 **팀 단위로** 주면 나중에 관리가 쉽습니다.

### 비공개 저장소에서도 지킬 것

- 비공개여도 **구성원은 모두 볼 수 있습니다.** `.env`, API 키, 토큰, 비밀번호는 여전히 커밋 금지
  ([README 7절](README.md#7-보안-수칙-공개-저장소)). 토큰은 계속 `~/.hermes/` 에 두세요.
- 저장소를 공개로 바꾸는 순간 **모든 커밋 기록이 공개**됩니다. 공개 전환은 Owner 만 할 수 있게 4절 설정을 유지하세요.

## 8. 정기 점검 (분기에 한 번)

- [ ] **People**: 모르는 사람, 퇴사자가 없는지 / Owner 가 2명 이상인지
- [ ] **Outside collaborators**: 계약이 끝난 외부 인력이 남아 있지 않은지
- [ ] **Settings → GitHub Apps / Third-party access**: 쓰지 않는 앱 제거, Claude 앱은 필요한 저장소만
- [ ] **Settings → Logs → Audit log**: 저장소 공개 전환, 삭제, 권한 변경 같은 이상한 기록이 없는지
- [ ] 저장소 목록에 **Public** 표시가 붙은 것이 없는지
- [ ] 원본(NousResearch) 업데이트를 마지막으로 받은 지 오래되지 않았는지 ([README 6절](README.md#6-원본nousresearch-업데이트-받기))
