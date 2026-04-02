# Claude Code 사용량, 매번 확인하기 귀찮아서 위젯을 만들었다

## 불편함의 시작

Claude Code를 쓰다 보면 한 가지 불편한 점이 있다.

> "지금 내 사용량이 얼마나 남았지?"

확인하려면 매번 Anthropic Console에 들어가야 한다. 코딩에 몰입하고 있는데 브라우저 탭을 열고, 로그인하고, 대시보드를 찾아 들어가고... 이 과정이 은근히 흐름을 끊는다.

특히 Claude Code Max 플랜은 **5시간 세션 제한**과 **7일 주간 제한**이 있어서, 사용량을 수시로 확인하게 된다. 한창 작업하다가 갑자기 rate limit에 걸리면 그날의 생산성은 끝이다.

**"그냥 바탕화면에서 바로 보면 안 되나?"**

이 한 줄의 생각이 프로젝트의 시작이었다.

---

## 그래서 뭘 만들었나

**Claude Usage Widget** — Claude Code 사용량을 실시간으로 보여주는 데스크톱 위젯이다.

![위젯 미리보기](https://raw.githubusercontent.com/INNO-HI/ClaudeUsageWidget/main/screenshots/04-web-widget-clean.png)

> *글라스모피즘 디자인의 위젯 UI. 세션 사용량, 주간 제한, 자동 동기화를 한눈에 볼 수 있다.*

핵심은 단순하다:
- 메뉴바(macOS) 또는 바탕화면에 항상 떠 있는 위젯
- 5시간 세션 사용량 + 7일 주간 사용량을 한눈에
- 자동 동기화 (5분/10분/30분/1시간)
- **토큰 소비 없음** — 사용량 조회 API만 호출

### 토큰이 안 든다고?

이게 이 프로젝트의 핵심 포인트다. Claude에게 메시지를 보내는 게 아니라, Anthropic의 **OAuth Usage API** (`/api/oauth/usage`)를 호출해서 사용량 데이터만 읽어온다. Claude Code에 로그인하면 자동으로 저장되는 OAuth 토큰을 재활용하는 구조라서, 별도 API 키도 필요 없다.

```
Widget  ──OAuth Token──►  Anthropic Usage API
        ◄──Usage Data──   (사용량 % 반환)
```

---

## 개발 과정

### 1단계: macOS 메뉴바 앱

처음에는 macOS 메뉴바 앱으로 만들었다. Swift + SwiftUI로 구현했고, 상단 메뉴바 아이콘을 클릭하면 팝오버로 사용량이 표시되는 구조다.

**인증 처리가 관건이었다.** Claude Code는 OAuth 토큰을 macOS Keychain에 저장한다. 이걸 읽어서 Usage API를 호출하고, 토큰이 만료되면 refresh token으로 자동 갱신하는 로직을 구현했다.

```swift
// Keychain에서 Claude Code 자격증명 읽기
let query: [String: Any] = [
    kSecClass as String: kSecClassGenericPassword,
    kSecAttrService as String: "Claude Code-credentials",
    kSecReturnData as String: true
]
```

### 2단계: 디자인 개선 — 글라스모피즘

처음 버전은 다크 테마였는데, 흰색 배경 + 글라스모피즘으로 전면 개편했다.

- 배경: `#FFFFFF` + `NSVisualEffectView` 블러
- 카드: `#F8FAFC` + 미세 그림자 + 반투명 테두리
- 상태 색: 초록(낮음) → 주황(보통) → 빨강(위험)

macOS의 `NSVisualEffectView`를 SwiftUI에서 쓰려면 `NSViewRepresentable`로 감싸야 하는데, 이 부분이 생각보다 까다로웠다. 팝오버의 기본 불투명 배경을 투명하게 만들고, 블러 레이어 위에 반투명 흰색을 얹는 구조로 해결했다.

### 3단계: 데스크톱 위젯

메뉴바 앱도 좋지만, **바탕화면에 항상 떠 있는 위젯**이 더 편하다고 느꼈다. 같은 UI를 `NSWindow`를 `borderless + floating`으로 설정해서 윈도우 위젯처럼 구현했다.

![macOS 데스크톱 위젯](https://raw.githubusercontent.com/INNO-HI/ClaudeUsageWidget/main/screenshots/10-desktop-widget-crop.png)

> *바탕화면에 항상 떠 있는 플로팅 위젯. 드래그로 위치 이동도 가능하다.*

- 항상 최상위에 표시 (`level: .floating`)
- 드래그로 위치 이동 가능
- 모든 Space에서 표시 (`canJoinAllSpaces`)
- 호버 시 그림자 강화 애니메이션

### 4단계: 크로스플랫폼

macOS에서만 되는 건 아쉬워서, **Node.js + HTML/CSS/JS** 버전도 만들었다. 로컬 서버가 API 프록시 역할을 하고, 브라우저에서 위젯 UI를 렌더링하는 구조다.

```bash
node src/server.js
# → http://127.0.0.1:19522 에서 위젯 실행
```

CSS의 `backdrop-filter: blur(24px)`로 글라스모피즘을 구현했는데, macOS 네이티브 블러와 거의 동일한 결과물이 나왔다. macOS, Windows, Linux 어디서든 Node.js만 있으면 동작한다.

---

## 랜딩 페이지도 만들었다

GitHub Pages로 다운로드 페이지도 배포했다. macOS / Windows 플랫폼별로 나눠서 다운받을 수 있다.

![랜딩 페이지 - 히어로](https://raw.githubusercontent.com/INNO-HI/ClaudeUsageWidget/main/screenshots/05-landing-hero.png)

![랜딩 페이지 - 다운로드](https://raw.githubusercontent.com/INNO-HI/ClaudeUsageWidget/main/screenshots/06-landing-download.png)

> *[inno-hi.github.io/ClaudeUsageWidget](https://inno-hi.github.io/ClaudeUsageWidget/) — macOS는 네이티브 Swift 앱, Windows는 Node.js 웹 위젯으로 다운로드 가능.*

---

## 기술 스택

| 구분 | 스택 |
|------|------|
| macOS 네이티브 | Swift, SwiftUI, AppKit, Security (Keychain) |
| 크로스플랫폼 | Node.js, HTML/CSS/JS |
| API | Anthropic OAuth Usage API |
| 배포 | GitHub Pages (랜딩 페이지) |

---

## 사용법

Claude Code에 로그인만 되어 있으면 된다.

```bash
# 1. Claude Code 로그인 (이미 했다면 스킵)
claude login

# 2. 위젯 실행 (크로스플랫폼)
git clone https://github.com/INNO-HI/ClaudeUsageWidget.git
cd ClaudeUsageWidget
node src/server.js
```

macOS 사용자는 네이티브 앱을 빌드할 수도 있다:

```bash
bash build.sh
open "build/Claude Widget.app"
```

---

## 마무리

사실 대단한 프로젝트는 아니다. OAuth 토큰 읽어서 API 한 번 호출하는 게 전부다.

하지만 **"이거 좀 불편한데?"** 라는 생각을 **"그럼 만들면 되지"** 로 바꾸는 과정이 재밌었다. Claude Code로 Claude Code 사용량 위젯을 만드는 것도 나름 메타적이고.

실제로 사용해보니 생각보다 만족스럽다. 코딩하면서 바탕화면 한쪽에 떠 있는 위젯을 슬쩍 보면 "아직 37%네, 여유 있다" 같은 판단이 바로 된다. 더 이상 Console을 열지 않는다.

불편함을 느끼면 직접 만들어보자. 생각보다 간단하고, 생각보다 뿌듯하다.

---

**GitHub**: [INNO-HI/ClaudeUsageWidget](https://github.com/INNO-HI/ClaudeUsageWidget)
**Homepage**: [inno-hi.github.io/ClaudeUsageWidget](https://inno-hi.github.io/ClaudeUsageWidget/)

---

> Tags: `Claude` `Claude Code` `Anthropic` `macOS` `Widget` `SwiftUI` `Node.js` `Side Project`
