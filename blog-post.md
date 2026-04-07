# Claude Code 쓰다가 하루 날려서, 위젯 만들어버렸다

Claude Code 쓰다가
하루 날린 적 있다.

분명 잘 쓰고 있었는데
갑자기 rate limit 걸려버렸다.

이유?

👉 사용량 안 보고 썼다

---

## 이거 공감되면 끝까지 읽어보세요

Claude Code 써본 사람은 알 거다.

사용량 확인하려면
👉 콘솔 들어가야 한다

근데 이게 진짜 귀찮다

- 코딩하다가
- 브라우저 열고
- 로그인하고
- Usage 페이지 찾고

👉 흐름 끊김

---

## 특히 Max 플랜이면 더 위험하다

- 5시간 세션 제한
- 7일 주간 제한

잘못 쓰면?

👉 그냥 하루 날림

---

## 그래서 그냥 만들었다

> "바탕화면에서 보면 되잖아?"

---

## Claude Usage Widget

Claude Code 사용량을
👉 **그냥 눈에 보이게 만든 위젯**

![widget](https://raw.githubusercontent.com/INNO-HI/ClaudeUsageWidget/main/screenshots/04-web-widget-clean.png)

---

## 핵심은 딱 하나다

👉 콘솔 안 들어가도 된다

---

## 기능

- 항상 떠 있음 (메뉴바 / 데스크톱)
- 실시간 사용량 확인
- 세션 + 주간 usage 표시
- 자동 동기화
- **토큰 안 씀**

---

## 이게 왜 중요하냐면

Claude한테 요청 보내는 게 아니라
👉 Usage API만 조회한다

```
Widget  ──OAuth Token──►  Anthropic Usage API
        ◄──Usage Data──   (사용량 % 반환)
```

👉 그래서

- 돈 안 듦
- 제한 없음
- 그냥 계속 켜두면 됨

---

## 구현

### macOS

- Swift + SwiftUI
- Keychain에서 OAuth 읽기

```swift
let query: [String: Any] = [
    kSecClass as String: kSecClassGenericPassword,
    kSecAttrService as String: "Claude Code-credentials",
    kSecReturnData as String: true
]
```

---

### 데스크톱 위젯

- 항상 위에 표시
- 드래그 이동
- 모든 화면에서 보임

![desktop widget](https://raw.githubusercontent.com/INNO-HI/ClaudeUsageWidget/main/screenshots/10-desktop-widget-crop.png)

👉 이게 진짜 편함

---

### 크로스플랫폼

Node.js 버전도 만들었다

```bash
node src/server.js
```

👉 macOS / Windows / Linux 전부 가능

---

## 다운로드 페이지도 만들었다

![landing](https://raw.githubusercontent.com/INNO-HI/ClaudeUsageWidget/main/screenshots/06-landing-download.png)

---

## 써보니까

이거 쓰고 나서

👉 콘솔 한 번도 안 들어갔다

진짜다

코딩하면서 슬쩍 보면

"아직 37%네"

끝

---

## 결론

불편하면

👉 그냥 만들어라

---

## 링크

- **GitHub**: [INNO-HI/ClaudeUsageWidget](https://github.com/INNO-HI/ClaudeUsageWidget)
- **Homepage**: [inno-hi.github.io/ClaudeUsageWidget](https://inno-hi.github.io/ClaudeUsageWidget/)

---

> Tags: `Claude` `Claude Code` `Widget` `macOS` `SideProject`
