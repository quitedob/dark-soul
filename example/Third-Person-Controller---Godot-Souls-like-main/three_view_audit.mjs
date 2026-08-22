#!/usr/bin/env node
/**
 * 三视图校验(正/反/上 × 全 GLB)—— 自包含单文件版
 * 等价于 build/all-models/viewer.mjs 的 shootAllViews 管线,可直接入库备份。
 *
 * 用法(在仓库根目录执行):
 *   node build/three-view-audit/three_view_audit.mjs
 *   浏览器打开 http://localhost:8769/?batch=1        # 全自动跑完 88 × 3 = 264 张
 *   或打开 http://localhost:8769/?i=63 后在控制台:
 *     window.shootAllViews(63)   // 单模型三视图
 *     window.runBatch()          // 全部
 *     window.goTo(10)            // 只看第 10 个
 *
 * 参数:
 *   --root  game/assets/models     GLB 根目录
 *   --out   screenshot/YYYY-MM-DD  截图输出目录
 *   --port  8769
 *   --three <dir>                  three 包目录(自动探测 node_modules/three、
 *                                  build/glb-models/node_modules/three)
 *
 * 与旧查看器的差异(针对 2026-08-22 审计结论):
 *   - 默认正面补光 + 曝光 1.25,缓解"多数渲染偏暗/背光"
 *   - 地面 GridHelper 作为 y=0 基准,便于 VLM 判读"离地/悬浮"
 *   - 不重定位 Y 轴(只居中 XZ),保留模型原始贴地/悬浮状态
 */
import http from 'node:http';
import fs from 'node:fs';
import path from 'node:path';

const args = {};
for (let i = 2; i < process.argv.length; i++) {
  const a = process.argv[i];
  if (a.startsWith('--')) {
    const k = a.slice(2);
    args[k] = (i + 1 < process.argv.length && !process.argv[i + 1].startsWith('--')) ? process.argv[++i] : '1';
  }
}

const ROOT = path.resolve(args.root || 'game/assets/models');
const TODAY = new Date().toISOString().slice(0, 10);
const OUT = path.resolve(args.out || path.join('screenshot', TODAY));
const PORT = Number(args.port || 8769);

function findThree() {
  const cands = [args.three, 'node_modules/three', 'build/glb-models/node_modules/three',
    'build/all-models/node_modules/three'].filter(Boolean);
  for (const c of cands) {
    const p = path.resolve(c);
    if (fs.existsSync(path.join(p, 'build', 'three.module.js'))) return p;
  }
  return null;
}
const THREE_DIR = findThree();
if (!THREE_DIR) {
  console.error('[三视图] 未找到 three.js,请用 --three 指定,或先 npm i three');
  process.exit(1);
}
if (!fs.existsSync(ROOT)) {
  console.error('[三视图] GLB 根目录不存在: ' + ROOT);
  process.exit(1);
}

function walk(dir, base, out) {
  for (const e of fs.readdirSync(dir, { withFileTypes: true })) {
    if (e.name.startsWith('.')) continue;
    const p = path.join(dir, e.name);
    if (e.isDirectory()) walk(p, base, out);
    else if (e.name.toLowerCase().endsWith('.glb'))
      out.push(path.relative(base, p).split(path.sep).join('/'));
  }
  return out;
}
const MODELS = walk(ROOT, ROOT, []).sort();
console.log('[三视图] 发现 ' + MODELS.length + ' 个 GLB @ ' + ROOT);

fs.mkdirSync(OUT, { recursive: true });
const manifest = { date: TODAY, root: path.relative(process.cwd(), ROOT), count: MODELS.length, models: MODELS, shots: [] };
const saveManifest = () => fs.writeFileSync(path.join(OUT, 'manifest.json'), JSON.stringify(manifest, null, 2));
saveManifest();

const MIME = { '.glb': 'model/gltf-binary', '.png': 'image/png', '.jpg': 'image/jpeg', '.jpeg': 'image/jpeg', '.js': 'text/javascript', '.mjs': 'text/javascript', '.json': 'application/json', '.bin': 'application/octet-stream' };

function safeJoin(base, rel) {
  const p = path.normalize(path.join(base, rel));
  return p.startsWith(base) ? p : null;
}

const PAGE = `<!doctype html><html><head><meta charset="utf-8"><title>three-view audit</title>
<style>body{margin:0;background:#1a1d24;color:#ddd;font:12px monospace}#hud{position:fixed;top:8px;left:8px;white-space:pre}</style>
<script type="importmap">{"imports":{"three":"/three/build/three.module.js","three/addons/":"/three/examples/jsm/"}}<\/script>
</head><body><div id="hud">loading…</div>
<script type="module">
import * as THREE from 'three';
import { GLTFLoader } from 'three/addons/loaders/GLTFLoader.js';

const SIZE = 1024;
const renderer = new THREE.WebGLRenderer({ antialias: true, preserveDrawingBuffer: true });
renderer.setSize(SIZE, SIZE);
renderer.toneMappingExposure = 1.25;
document.body.appendChild(renderer.domElement);
const scene = new THREE.Scene();
scene.background = new THREE.Color(0x1a1d24);
const camera = new THREE.PerspectiveCamera(40, 1, 0.01, 2000);

scene.add(new THREE.HemisphereLight(0xffffff, 0x334455, 1.15));
const key = new THREE.DirectionalLight(0xffffff, 1.6); key.position.set(2, 4, 3); scene.add(key);
const fill = new THREE.DirectionalLight(0xcfe4ff, 0.9); fill.position.set(-1, 1.5, 4); scene.add(fill);
const rim = new THREE.DirectionalLight(0xffe0b3, 0.5); rim.position.set(0, 3, -4); scene.add(rim);
scene.add(new THREE.GridHelper(10, 20, 0x666666, 0x333333));

const hud = document.getElementById('hud');
const loader = new GLTFLoader();
const list = await (await fetch('/list.json')).json();
let current = null, currentBox = null;

function loadOne(i) {
  return new Promise((resolve, reject) => {
    if (current) { scene.remove(current); current = null; }
    const rel = list[i];
    hud.textContent = 'loading ' + i + ' ' + rel;
    loader.load('/models/' + rel.split('/').map(encodeURIComponent).join('/'), (g) => {
      current = g.scene;
      const box = new THREE.Box3().setFromObject(current);
      const c = box.getCenter(new THREE.Vector3());
      current.position.x -= c.x; current.position.z -= c.z;   // 只居中 XZ,保留原始 Y(贴地/悬浮)
      scene.add(current);
      currentBox = new THREE.Box3().setFromObject(current);
      hud.textContent = i + ' ' + rel;
      resolve();
    }, undefined, reject);
  });
}

const VIEWS = {
  front: (c, d) => ({ pos: [c.x, c.y + d * 0.10, c.z + d], up: [0, 1, 0] }),
  back:  (c, d) => ({ pos: [c.x, c.y + d * 0.10, c.z - d], up: [0, 1, 0] }),
  top:   (c, d) => ({ pos: [c.x, c.y + d, c.z + d * 1e-4], up: [0, 0, -1] }),
};

function frame() {
  const size = currentBox.getSize(new THREE.Vector3());
  const center = currentBox.getCenter(new THREE.Vector3());
  const d = Math.max(size.x, size.y, size.z) * 1.8 + 1e-3;
  return { center, d };
}

async function shoot(i, view) {
  const { center, d } = frame();
  const v = VIEWS[view](center, d);
  camera.up.set(...v.up);
  camera.position.set(...v.pos);
  camera.lookAt(center);
  renderer.render(scene, camera);
  const rel = list[i].replace(/\\.glb$/i, '').replaceAll('/', '_').replace(/[^\\w.-]/g, '_');
  const file = String(i).padStart(2, '0') + '_' + rel + '_' + view + '.png';
  await fetch('/capture', { method: 'POST', headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ file, png: renderer.domElement.toDataURL('image/png') }) });
  hud.textContent = 'shot ' + file;
}

window.goTo = async (i) => { await loadOne(i); const { center, d } = frame(); const v = VIEWS.front(center, d); camera.up.set(0,1,0); camera.position.set(...v.pos); camera.lookAt(center); renderer.render(scene, camera); };
window.shootAllViews = async (i) => { await loadOne(i); for (const view of ['front', 'back', 'top']) await shoot(i, view); };
window.runBatch = async (from = 0, to = list.length - 1) => {
  for (let i = from; i <= to; i++) { try { await window.shootAllViews(i); } catch (e) { console.error(i, e); hud.textContent = 'ERROR ' + i; } }
  document.title = 'DONE ' + list.length;
  hud.textContent = 'DONE ' + list.length + ' models × 3 views';
  await fetch('/finish', { method: 'POST' });
};

const q = new URLSearchParams(location.search);
if (q.has('i')) await window.goTo(Number(q.get('i')));
if (q.get('batch') === '1') await window.runBatch();
<\/script></body></html>`;

const server = http.createServer((req, res) => {
  const u = new URL(req.url, 'http://x');
  if (req.method === 'GET' && u.pathname === '/') {
    res.writeHead(200, { 'Content-Type': 'text/html; charset=utf-8' });
    return res.end(PAGE);
  }
  if (req.method === 'GET' && u.pathname === '/list.json') {
    res.writeHead(200, { 'Content-Type': 'application/json' });
    return res.end(JSON.stringify(MODELS));
  }
  if (req.method === 'GET' && (u.pathname.startsWith('/models/') || u.pathname.startsWith('/three/'))) {
    const base = u.pathname.startsWith('/models/') ? ROOT : THREE_DIR;
    const rel = decodeURIComponent(u.pathname.replace(/^\/(models|three)\//, ''));
    const p = safeJoin(base, rel);
    if (!p || !fs.existsSync(p) || !fs.statSync(p).isFile()) {
      res.writeHead(404); return res.end('not found: ' + rel);
    }
    res.writeHead(200, { 'Content-Type': MIME[path.extname(p).toLowerCase()] || 'application/octet-stream' });
    return fs.createReadStream(p).pipe(res);
  }
  if (req.method === 'POST' && u.pathname === '/capture') {
    let body = '';
    req.on('data', (c) => { body += c; });
    req.on('end', () => {
      try {
        const { file, png } = JSON.parse(body);
        const name = path.basename(String(file));
        fs.writeFileSync(path.join(OUT, name), Buffer.from(png.split(',')[1], 'base64'));
        manifest.shots.push(name);
        if (manifest.shots.length % 30 === 0) saveManifest();
        console.log('[三视图] ' + manifest.shots.length + '/' + MODELS.length * 3 + ' ' + name);
        res.writeHead(200); res.end('ok');
      } catch (e) { res.writeHead(400); res.end(String(e)); }
    });
    return;
  }
  if (req.method === 'POST' && u.pathname === '/finish') {
    saveManifest();
    console.log('[三视图] 完成: ' + manifest.shots.length + ' 张 → ' + OUT);
    res.writeHead(200); return res.end('done');
  }
  res.writeHead(404); res.end('?');
});

process.on('SIGINT', () => { saveManifest(); console.log('\n[三视图] 已保存 manifest.json → ' + OUT); process.exit(0); });
server.listen(PORT, () => {
  console.log('[三视图] three.js: ' + THREE_DIR);
  console.log('[三视图] 输出目录: ' + OUT);
  console.log('[三视图] 打开 http://localhost:' + PORT + '/?batch=1 开始全量截图');
});
