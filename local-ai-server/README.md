# ResearchLab 로컬 AI 서버

저장된 논문·가설 정보, 그리고 앱 화면 어디서든 열 수 있는 "AI 연구 도우미" 드로어의 질문을 로컬 AI CLI에 전달합니다. 서버는 외부 네트워크에 노출되지 않도록 `127.0.0.1:8787`에서만 실행됩니다.

## 준비

- Node.js 18 이상
- **이미 구독중인 CLI AI 에이전트 중 하나만 있으면 됩니다** — claude / codex / gemini 중 설치·로그인된 것을 자동으로 찾아 씁니다. 여러개 있으면 이 우선순위로 선택: `claude → codex → gemini`
- 특정 CLI를 강제로 쓰고 싶으면 `AI_CLI=codex` 처럼 환경변수로 지정 (예: `AI_CLI=codex node server.js`)

## 실행

```bash
npm install
node server.js
```

시작 로그에 `사용할 CLI: claude` 처럼 어떤 CLI가 잡혔는지 표시됩니다. 아무 것도 안 잡히면 claude/codex/gemini 중 하나를 설치·로그인하세요.

그다음 `index.html (프로젝트 루트)`을 열면:
- 우측 하단 **"✨ AI 연구 도우미"** 버튼 — 어느 화면에서든 열 수 있는 공용 AI 드로어
- 논문조사 → 저장된 논문 카드의 **AI 인사이트 생성** 버튼 — 논문+가설 맥락 분석 전용

다른 포트를 쓰려면 `PORT=9000 node server.js`처럼 실행할 수 있지만, 프론트의 서버 주소도 함께 바꿔야 합니다.

## API 확인

```bash
curl http://localhost:8787/api/health

curl -X POST http://localhost:8787/api/ai-insight \
  -H 'Content-Type: application/json' \
  -d '{"paperTitle":"Attention Is All You Need","paperAbstract":"Transformer architecture","hypothesisTitle":"어텐션 기반 모델의 성능 향상","hypothesisDescription":"재현 실험으로 성능을 비교한다"}'

curl -X POST http://localhost:8787/api/ai-chat \
  -H 'Content-Type: application/json' \
  -d '{"context":"현재 대시보드 요약","question":"다음에 뭘 해야할까?"}'
```
