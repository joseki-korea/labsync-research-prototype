'use strict';

const express = require('express');
const { execFile } = require('node:child_process');

const app = express();
const HOST = '127.0.0.1';
const PORT = Number(process.env.PORT) || 8787;

app.use((req, res, next) => {
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'POST, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type');
  if (req.method === 'OPTIONS') return res.sendStatus(204);
  next();
});
app.use(express.json({ limit: '256kb' }));

app.post('/api/ai-insight', (req, res) => {
  const {
    paperTitle,
    paperAbstract,
    hypothesisTitle,
    hypothesisDescription
  } = req.body || {};

  if (!paperTitle || !hypothesisTitle) {
    return res.status(400).json({
      error: 'paperTitle과 hypothesisTitle은 필수입니다.'
    });
  }

  const prompt = [
    '다음 논문이 연구 가설에 어떻게 도움이 되는지 분석해 주세요.',
    '논문과 가설의 구체적인 연결점, 활용 가능한 근거 또는 방법, 후속 연구 아이디어를 포함해',
    '실제 연구에 도움이 되는 인사이트를 한국어 3~4문장으로만 요약해 주세요.',
    '',
    `[논문 제목]\n${String(paperTitle)}`,
    `[논문 초록]\n${String(paperAbstract || '초록 정보 없음')}`,
    `[가설 제목]\n${String(hypothesisTitle)}`,
    `[가설 설명]\n${String(hypothesisDescription || '상세 설명 없음')}`
  ].join('\n');

  execFile('claude', ['-p', prompt], {
    timeout: 120000,
    maxBuffer: 1024 * 1024,
    encoding: 'utf8'
  }, (error, stdout, stderr) => {
    if (error) {
      const isMissing = error.code === 'ENOENT';
      return res.status(500).json({
        error: isMissing
          ? 'claude CLI를 찾을 수 없습니다. Claude Code를 설치하고 claude 명령이 PATH에 등록되었는지 확인하세요.'
          : `claude CLI 실행에 실패했습니다: ${(stderr || error.message).trim()}`
      });
    }

    const insight = stdout.trim();
    if (!insight) {
      return res.status(502).json({ error: 'claude CLI가 빈 응답을 반환했습니다.' });
    }
    return res.json({ insight });
  });
});

app.use((error, req, res, next) => {
  if (error instanceof SyntaxError && 'body' in error) {
    return res.status(400).json({ error: '요청 본문이 올바른 JSON 형식이 아닙니다.' });
  }
  console.error(error);
  return res.status(500).json({ error: '로컬 AI 서버에서 예기치 않은 오류가 발생했습니다.' });
});

app.listen(PORT, HOST, () => {
  console.log(`ResearchLab 로컬 AI 서버: http://localhost:${PORT}`);
});
