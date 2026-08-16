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

// 이미 구독중인 CLI AI 에이전트가 있으면 그걸 그대로 씀 — 하나만 강제하지 않음.
// AI_CLI 환경변수로 명시 지정 가능(claude|codex|gemini). 안 정하면 이 순서로 자동감지.
const CLI_PROFILES = {
  claude: { bin: 'claude', args: (prompt) => ['-p', prompt] },
  codex: { bin: 'codex', args: (prompt) => ['exec', prompt] },
  gemini: { bin: 'gemini', args: (prompt) => ['-p', prompt] }
};
const AUTO_DETECT_ORDER = ['claude', 'codex', 'gemini'];

let cachedCli = null; // { name, bin, args } | null(미탐지) — 서버 실행중 1회만 감지
let cliDetectPromise = null;

function probeCli(name) {
  return new Promise((resolve) => {
    const profile = CLI_PROFILES[name];
    if (!profile) return resolve(false);
    execFile(profile.bin, ['--version'], { timeout: 5000 }, (error) => {
      resolve(!error || error.code !== 'ENOENT');
    });
  });
}

async function detectCli() {
  const forced = (process.env.AI_CLI || '').trim().toLowerCase();
  if (forced && CLI_PROFILES[forced]) {
    const ok = await probeCli(forced);
    if (ok) return { name: forced, ...CLI_PROFILES[forced] };
    console.warn(`AI_CLI=${forced} 로 지정됐지만 실행파일을 찾을 수 없습니다. 자동감지로 대체합니다.`);
  }
  for (const name of AUTO_DETECT_ORDER) {
    // eslint-disable-next-line no-await-in-loop
    if (await probeCli(name)) return { name, ...CLI_PROFILES[name] };
  }
  return null;
}

async function getCli() {
  if (cachedCli) return cachedCli;
  if (!cliDetectPromise) cliDetectPromise = detectCli();
  cachedCli = await cliDetectPromise;
  return cachedCli;
}

function runPrompt(prompt) {
  return new Promise((resolve) => {
    getCli().then((cli) => {
      if (!cli) {
        return resolve({
          error: '사용 가능한 AI CLI를 찾을 수 없습니다. claude / codex / gemini 중 하나를 설치·로그인 후 다시 시도하세요(또는 AI_CLI 환경변수로 지정).'
        });
      }
      const child = execFile(cli.bin, cli.args(prompt), {
        timeout: 120000,
        maxBuffer: 1024 * 1024,
        encoding: 'utf8'
      }, (error, stdout, stderr) => {
        if (error) {
          const isMissing = error.code === 'ENOENT';
          return resolve({
            error: isMissing
              ? `${cli.name} CLI를 찾을 수 없습니다. 설치 및 PATH 등록을 확인하세요.`
              : `${cli.name} CLI 실행에 실패했습니다: ${(stderr || error.message).trim()}`
          });
        }
        const text = stdout.trim();
        if (!text) {
          return resolve({ error: `${cli.name} CLI가 빈 응답을 반환했습니다.` });
        }
        return resolve({ text, cliName: cli.name });
      });
      // 일부 CLI(codex 등)는 stdin이 안 닫혀있으면 추가입력을 기다리며 무한 대기함 — 즉시 닫아줌
      if (child.stdin) child.stdin.end();
    });
  });
}

app.get('/api/health', (req, res) => {
  getCli().then((cli) => {
    res.json({
      status: 'ok',
      port: PORT,
      detectedCli: cli ? cli.name : null
    });
  });
});

app.post('/api/ai-insight', async (req, res) => {
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

  const result = await runPrompt(prompt);
  if (result.error) return res.status(500).json({ error: result.error });
  return res.json({ insight: result.text, cli: result.cliName });
});

app.post('/api/ai-chat', async (req, res) => {
  const { context, question } = req.body || {};

  if (!String(context || '').trim() || !String(question || '').trim()) {
    return res.status(400).json({ success: false, error: 'context와 question은 필수입니다.' });
  }

  const prompt = [
    `다음은 현재 연구프로젝트 맥락입니다: ${String(context).trim()}`,
    '',
    `질문: ${String(question).trim()}`,
    '',
    '연구자에게 도움되는 답변을 한국어로 작성해줘'
  ].join('\n');

  const result = await runPrompt(prompt);
  if (result.error) return res.status(500).json({ success: false, error: result.error });
  return res.json({ success: true, answer: result.text, cli: result.cliName });
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
  getCli().then((cli) => {
    console.log(cli ? `사용할 CLI: ${cli.name}` : '⚠ 사용 가능한 AI CLI를 못 찾았습니다(claude/codex/gemini 확인 필요)');
  });
});
