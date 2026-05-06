# Multi-Account UX Redesign — 2026-05-06

## 배경

v3.0.0 까지 멀티 계정 기능이 부분 구현되었으나 다음 문제가 있다.

1. **팝업 중복** — 활성 계정과 추가 계정 각각이 별도 `NSPopover`를 가진다.
   메뉴바 클릭 → 활성 계정 popover, 추가 계정 status item 클릭 → 별도 popover.
   기존 popover가 닫히지 않은 채 새 popover가 열려 두 개가 겹쳐 보인다.

2. **메뉴바 공간 낭비** — 계정마다 별도 `NSStatusItem` 생성. 활성 계정은
   풀 정보(5h/7d/Extra), 추가 계정은 compact 형태로 메뉴바에 동시 표시되어
   상태 표시줄 폭을 크게 차지한다.

3. **계정별 설정 부재** — 표시 모드, 커스텀 limit 종류, ExtraUsage 표기 방식
   등은 모두 전역 설정이라 한 계정만 ExtraUsage 토글하거나 한 계정만 다른
   limit 조합으로 보고 싶을 때 불가능하다.

4. **전반적 UX 일관성 부족** — 우클릭 메뉴와 좌클릭 popover의 정보가
   분산되어 있고, 계정 전환 시 어떤 popover가 열려 있는지 추적이 어렵다.

## 목표

- 단일 메뉴바 status item + 단일 popover로 통합한다.
- 통합 popover 안에서 모든 계정의 사용량을 한눈에 비교 가능하게 한다.
- 일부 표시 옵션은 계정별로 오버라이드 가능하게 한다 (전역 기본값 유지).
- 메뉴바 표시 정보 압축 정도를 사용자가 선택할 수 있게 한다.

## 비목표

- API 레이어 변경 (Claude/Codex 서비스는 그대로).
- 알림/새로고침 정책 재설계.
- 데이터 모델 변경 (`Account`, `UsageData`, `CodexUsageData`는 그대로).

## 결정 사항

### 1. 단일 status item + 단일 popover

- `MenuBarUI.extraStatusItems` / `extraPopovers` 폐기.
- `NSStatusBar.system.statusItem` 하나, `NSPopover` 하나.
- 추가 계정의 사용량 데이터는 그대로 fetch (단지 화면 노출 방식만 통합).

### 2. 메뉴바 표시 모드 (`MenuBarDisplayMode`)

사용자가 일반 설정에서 셋 중 하나 선택. 단일 계정만 있으면 무관(현재 동작 유지).

| 모드 | 형태 | 설명 |
|------|------|------|
| `compact` (기본) | `K1: 9% K2: 11%` | 각 계정 최댓값 1개만 표시 |
| `abbreviated` | `N1: 5h 0% · 7d 11%   N11: 5h 0% · 7d 11%` | 계정명 + 핵심 limit |
| `primaryWithDots` | `5h 0% · 7d 11% · $100(9%)  ●●` | 활성 계정만 풀, 다른 계정은 색상 점 |

### 3. 통합 팝업 구조

```
┌─ Header: 활성 계정명 + ↻ + ⋯ ─────────┐
│                                          │
│  ╭─────╮                                 │
│  │ 9%  │   $100 (9%)                    │  ← 활성 계정 큰 카드
│  ╰─────╯                                 │
│  🟢 5h    오늘 3:00 PM                   │
│  🟣 7d    5월 9일 오후 7시               │
│  💎 $9 / $100                            │
├─────────────────────────────────────────┤
│ 🟠 NAVER_TEAM_11                  [전환] │  ← 보조 계정 미니 카드 (Claude)
│  ⭕ 0%  5h 0%  7d 11%                    │
├─────────────────────────────────────────┤
│ 🔷 Codex Account                  [전환] │  ← Codex 활성 또는 보조
│  ⭕ 42%  5h 42%  7d 58%                  │
└─────────────────────────────────────────┘
```

- 활성 계정은 기존 `UsageDetailView` 디자인 그대로 사용.
- 보조 계정 미니 카드를 클릭하면 활성 계정으로 전환되고 카드가 위로 올라간다.
- Claude/Codex는 같은 리스트 안에 함께 나열되며 각자 활성 계정 한 명씩.
- 6개 이상 시 ScrollView로 스크롤.

### 4. 계정별 설정 (전역 + 오버라이드)

새 모델:

```swift
struct AccountPreferences: Codable {
    var displayMode: DisplayMode?
    var customDisplayTypes: Set<LimitType>?
    var extraUsageDisplayMode: ExtraUsageDisplayMode?
    var menuBarIconStyle: MenuBarIconStyle?
}
```

- `nil` 필드 = 전역 설정 따름.
- 일반 설정 화면에 계정별 카드 추가, "전역 따름" 토글이 켜져 있으면 모든
  필드 nil. 토글 끄면 개별 입력 UI 노출.
- `UserSettings.resolvedDisplayMode(for: accountId)` 등 헬퍼로 합성된 값 조회.

### 5. 폐기되는 기능

- `menuBarExtraAccountIds`: 더 이상 추가 status item이 없으므로 무의미.
- `accountMenuBarStyles`: 메뉴바 자체에 계정 노출 안 됨. 단 `AccountPreferences.menuBarIconStyle`로 의미 변경(통합 popover 안 미니 카드 스타일).
- 계정별 status item 생성/제거 로직.

마이그레이션은 단순 삭제 (UserDefaults 키 제거). 기존 사용자는 멀티 계정
메뉴바 표시가 사라진 대신 통합 팝업에서 모든 계정을 볼 수 있다.

## 데이터 흐름

1. 앱 시작 → `DataRefreshManager.startRefreshing()` → 활성 Claude + 활성 Codex
   + 모든 보조 Claude 계정 fetch.
2. 결과는 `usageData`(활성 Claude) / `codexUsageData`(활성 Codex) /
   `extraAccountUsageData[UUID]`(보조 Claude)에 저장.
3. `MenuBarUI`는 `MenuBarDisplayMode`에 따라 status item 텍스트/아이콘 합성.
4. 통합 popover는 `usageData` + `extraAccountUsageData` + `codexUsageData` +
   `codexAccounts`를 모두 받아 카드 리스트로 렌더.

## 마이그레이션 단계

1. `MenuBarDisplayMode` enum + 기본값 `compact` 추가.
2. `AccountPreferences` 모델 + `UserSettings.accountPreferences` 저장.
3. `MenuBarUI`에서 extra status items 제거.
4. `UnifiedUsageDetailView` 신규 작성 (기존 `UsageDetailView`는 활성 카드로
   재사용).
5. `MenuBarManager.openPopover` 가 `UnifiedUsageDetailView` 띄우도록 수정.
6. `GeneralSettingsView`에서 멀티 계정 메뉴바 카드 → 메뉴바 표시 모드 카드로
   교체. 계정별 오버라이드 카드 추가.
7. 로컬라이제이션 6개 언어 동기화.

## 테스트 시나리오

- 단일 Claude 계정 → 기존과 거의 동일하게 동작.
- 두 Claude 계정 → 통합 popover에 두 카드, 메뉴바 모드별 표시 확인.
- Claude + Codex → 두 섹션 모두 활성 카드 노출.
- 두 Claude + 한 Codex → 활성 둘 + 보조 하나.
- 보조 카드 클릭 → 활성 전환 후 카드 순서 재배치.
- 일반 설정에서 계정별 오버라이드 토글 → 즉시 반영.
