/**
 * Fix WeChat DevTools "simulator not found":
 * - Junction D:\WeChatDevTools -> Chinese install path
 * - Move User Data from C: to D:\WeChatDevToolsUserData (junction back)
 * - Clean cache + open project with --disable-gpu
 */
import fs from 'fs';
import path from 'path';
import { execSync, spawn } from 'child_process';

const DEVTOOLS_CN = 'D:\\微信web开发者工具';
const DEVTOOLS_EN = 'D:\\WeChatDevTools';
const USERDATA_ON_D = 'D:\\WeChatDevToolsUserData';
const LOCAL_CN = path.join(process.env.LOCALAPPDATA || '', '微信开发者工具');
const PROJECT =
  'D:\\project1\\match_it_app\\apps\\mini-program\\dist\\dev\\mp-weixin';
const CLI = path.join(DEVTOOLS_EN, 'cli.bat');

function run(cmd) {
  console.log('>', cmd);
  execSync(cmd, { stdio: 'inherit', windowsHide: true });
}

function isJunction(p) {
  if (!fs.existsSync(p)) return false;
  try {
    const out = execSync(`cmd /c dir /aL "${p}"`, { encoding: 'utf8' });
    return out.includes('<JUNCTION>') || out.includes('<SYMLINKD>');
  } catch {
    return false;
  }
}

function ensureJunction(link, target) {
  if (fs.existsSync(link)) {
    if (isJunction(link)) return;
    throw new Error(`Path exists and is not a junction: ${link}`);
  }
  if (!fs.existsSync(target)) fs.mkdirSync(target, { recursive: true });
  run(`cmd /c mklink /J "${link}" "${target}"`);
}

function stopDevTools() {
  for (const n of [
    'wechatdevtools.exe',
    '微信开发者工具.exe',
    'wxfilewatcher.exe',
    'wxfilewatcher_x64.exe',
  ]) {
    try {
      execSync(`taskkill /F /IM "${n}" /T`, { stdio: 'ignore' });
    } catch {
      /* not running */
    }
  }
}

function rmDir(dir) {
  if (fs.existsSync(dir)) fs.rmSync(dir, { recursive: true, force: true });
}

console.log('\n==> Stop WeChat DevTools processes');
stopDevTools();

console.log('\n==> English install junction:', DEVTOOLS_EN);
if (!fs.existsSync(DEVTOOLS_EN)) {
  ensureJunction(DEVTOOLS_EN, DEVTOOLS_CN);
  console.log('    OK');
} else {
  console.log('    already exists');
}

function moveToD(src, dest) {
  rmDir(dest);
  fs.mkdirSync(dest, { recursive: true });
  // C: -> D: must use robocopy (rename fails with EXDEV)
  const status = execSync(
    `robocopy "${src}" "${dest}" /E /MOVE /NFL /NDL /NJH /NJS /nc /ns /np`,
    { stdio: 'ignore' },
  ).status;
  // robocopy: 0-7 = success with various copy stats
  if (status > 7) {
    throw new Error(`robocopy failed with code ${status}`);
  }
  try {
    fs.rmdirSync(src);
  } catch {
    /* empty dir may remain */
  }
}

console.log('\n==> Move user data to D:', USERDATA_ON_D);
if (fs.existsSync(LOCAL_CN) && !isJunction(LOCAL_CN)) {
  moveToD(LOCAL_CN, USERDATA_ON_D);
  console.log('    moved to D: (frees C: space, single copy)');
}
if (!fs.existsSync(LOCAL_CN)) {
  if (!fs.existsSync(USERDATA_ON_D)) {
    fs.mkdirSync(path.join(USERDATA_ON_D, 'User Data'), { recursive: true });
  }
  ensureJunction(LOCAL_CN, USERDATA_ON_D);
  console.log('    C: junction -> D: (no duplicate copy)');
}

const userDataDir = path.join(USERDATA_ON_D, 'User Data');
if (fs.existsSync(userDataDir)) {
  for (const name of fs.readdirSync(userDataDir)) {
    const code = path.join(userDataDir, name, 'WeappCode');
    if (fs.existsSync(code)) {
      rmDir(code);
      console.log('    cleaned WeappCode:', name);
    }
  }
}

console.log('\n==> Clean IDE cache');
if (fs.existsSync(CLI)) {
  try {
    run(`"${CLI}" cache --clean all`);
  } catch (e) {
    console.warn('    cache clean skipped:', e.message);
  }
}

console.log('\n==> Open project (disable GPU)');
if (!fs.existsSync(PROJECT)) {
  console.warn('    Project missing. Run: npm run dev:mp-weixin');
} else if (fs.existsSync(CLI)) {
  const child = spawn(
    'cmd.exe',
    ['/c', CLI, 'open', '--project', PROJECT, '--disable-gpu', '--lang', 'zh'],
    { detached: true, stdio: 'ignore', windowsHide: false },
  );
  child.unref();
  console.log('    launched IDE');
}

const launcher = path.join(DEVTOOLS_EN, '微信开发者工具.exe');
console.log('\nDone.');
console.log('Launch from:', launcher);
console.log('Project:', PROJECT);
