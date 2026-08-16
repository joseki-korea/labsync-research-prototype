# ResearchLab 로컬 AI 서버

저장된 논문과 가설 정보를 로컬의 Claude CLI에 전달해 연구 인사이트를 생성합니다. 서버는 외부 네트워크에 노출되지 않도록 `127.0.0.1:8787`에서만 실행됩니다.

## 준비

- Node.js 18 이상
- 설치 및 로그인된 Claude CLI (`claude` 명령)

## 실행

```bash
npm install
node server.js
```

그다음 `index.html (프로젝트 루트)`을 열고 저장된 논문 카드에서 **AI 인사이트 생성**을 누르세요. 다른 포트를 쓰려면 `PORT=9000 node server.js`처럼 실행할 수 있지만, 프론트의 서버 주소도 함께 바꿔야 합니다.

## API 확인

```bash
curl -X POST http://localhost:8787/api/ai-insight \
  -H 'Content-Type: application/json' \
  -d '{"paperTitle":"Attention Is All You Need","paperAbstract":"Transformer architecture","hypothesisTitle":"어텐션 기반 모델의 성능 향상","hypothesisDescription":"재현 실험으로 성능을 비교한다"}'
```
