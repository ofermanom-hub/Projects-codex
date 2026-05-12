import pillow_heif, base64, io
from PIL import Image

pillow_heif.register_heif_opener()
img = Image.open(r'C:\Users\yotam\Downloads\IMG_4704.HEIC')
img = img.resize((200, 200), Image.LANCZOS)
buf = io.BytesIO()
img.save(buf, 'PNG')
b64 = base64.b64encode(buf.getvalue()).decode()
DATA_URL = "data:image/png;base64," + b64

HTML = r"""<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8" />
  <title>Geometry Dash</title>
  <style>
    * { margin: 0; padding: 0; box-sizing: border-box; }
    body {
      background: #111;
      display: flex;
      align-items: center;
      justify-content: center;
      height: 100vh;
      font-family: 'Arial Black', Arial, sans-serif;
      overflow: hidden;
    }
    canvas { display: block; cursor: pointer; border: 2px solid rgba(255,255,255,0.15); box-shadow: 0 0 60px rgba(100,200,255,0.2); }
  </style>
</head>
<body>
<canvas id="c"></canvas>
<script>
const canvas = document.getElementById('c');
const ctx    = canvas.getContext('2d');
const W = 900, H = 500;
canvas.width = W; canvas.height = H;

// ── Constants ──────────────────────────────────────────────────────────────
const GROUND_Y = H - 90;
const GRAVITY  = 0.55;
const JUMP_VY  = -13.5;
const PW = 44, PH = 44, PX = 160;

// ── State ──────────────────────────────────────────────────────────────────
let state = 'menu', score = 0, best = 0, frame = 0, speed = 6.5, bgHue = 210, attempts = 0;

const player = { y: GROUND_Y - PH, vy: 0, rot: 0, jumps: 0, parts: [] };
let obstacles = [], nextObs = 100, deathParts = [];

// ── Hero image ─────────────────────────────────────────────────────────────
const heroImg = new Image();
heroImg.src = 'HERO_DATA_URL';
let heroReady = false;
heroImg.onload = () => { heroReady = true; };

// ── Parallax ───────────────────────────────────────────────────────────────
const bgLayers = [
  { x:0, speed:0.3, cols: Array.from({length:8},(_,i)=>({x:i*130,h:40+Math.random()*60})) },
  { x:0, speed:0.6, cols: Array.from({length:6},(_,i)=>({x:i*160,h:60+Math.random()*80})) },
];

// ── Obstacle patterns ──────────────────────────────────────────────────────
const PATTERNS = [
  x=>[{t:'spike',x,  y:GROUND_Y-40,w:40,h:40}],
  x=>[{t:'spike',x,  y:GROUND_Y-40,w:40,h:40},{t:'spike',x:x+50,y:GROUND_Y-40,w:40,h:40}],
  x=>[{t:'spike',x,  y:GROUND_Y-40,w:40,h:40},{t:'spike',x:x+50,y:GROUND_Y-40,w:40,h:40},{t:'spike',x:x+100,y:GROUND_Y-40,w:40,h:40}],
  x=>[{t:'block',x,  y:GROUND_Y-50,w:44,h:50}],
  x=>[{t:'block',x,  y:GROUND_Y-90,w:44,h:90}],
  x=>[{t:'block',x,  y:GROUND_Y-50,w:44,h:50},{t:'spike',x:x+60,y:GROUND_Y-40,w:40,h:40}],
  x=>[{t:'spike',x,  y:GROUND_Y-40,w:40,h:40},{t:'block',x:x+60,y:GROUND_Y-50,w:44,h:50}],
];

function spawnObs() {
  const diff = Math.min(6, Math.floor(score/80));
  const pat  = PATTERNS[Math.floor(Math.random()*(2+diff))];
  obstacles.push(...pat(W+60));
  const gap = Math.max(55, 120 - diff*10);
  nextObs = frame + gap + Math.floor(Math.random()*60);
}

// ── Input ──────────────────────────────────────────────────────────────────
function act() {
  if (state==='menu') { state='playing'; attempts=1; return; }
  if (state==='dead') { reset(); return; }
  if (player.jumps < 2) {
    player.vy = JUMP_VY - player.jumps*1.5;
    player.jumps++;
    for(let i=0;i<5;i++) player.parts.push({x:PX+PW/2,y:player.y+PH,vx:(Math.random()-.5)*3,vy:Math.random()*2+.5,life:1});
  }
}
document.addEventListener('keydown', e=>{ if(['Space','ArrowUp','KeyW'].includes(e.code)){ e.preventDefault(); act(); }});
canvas.addEventListener('click', act);
canvas.addEventListener('touchstart', e=>{ e.preventDefault(); act(); }, {passive:false});

// ── Reset ──────────────────────────────────────────────────────────────────
function reset() {
  Object.assign(player, {y:GROUND_Y-PH,vy:0,rot:0,jumps:0,parts:[]});
  obstacles=[]; score=0; frame=0; speed=6.5; nextObs=100; deathParts=[]; attempts++; state='playing';
}

// ── Collision ──────────────────────────────────────────────────────────────
function sign(p,a,b){ return (p.x-b.x)*(a.y-b.y)-(a.x-b.x)*(p.y-b.y); }
function inTri(p,a,b,c){
  const d1=sign(p,a,b),d2=sign(p,b,c),d3=sign(p,c,a);
  return !((d1<0||d2<0||d3<0)&&(d1>0||d2>0||d3>0));
}
function hit(o) {
  const m=6, px1=PX+m,px2=PX+PW-m,py1=player.y+m,py2=player.y+PH-m;
  if(o.t==='spike'){
    const ap={x:o.x+o.w/2,y:o.y-o.h},bl={x:o.x,y:o.y},br={x:o.x+o.w,y:o.y};
    return [{x:px1,y:py1},{x:px2,y:py1},{x:px1,y:py2},{x:px2,y:py2}].some(p=>inTri(p,ap,bl,br));
  }
  return px1<o.x+o.w && px2>o.x && py1<o.y+o.h && py2>o.y;
}

// ── Update ─────────────────────────────────────────────────────────────────
function update() {
  deathParts.forEach(p=>{ p.x+=p.vx; p.y+=p.vy; p.vy+=.2; p.life-=.025; });
  deathParts = deathParts.filter(p=>p.life>0);
  if(state!=='playing') return;

  frame++; score=Math.floor(frame/7); speed=6.5+score*.004; bgHue=(bgHue+.08)%360;
  bgLayers.forEach(l=>{ l.x=(l.x-speed*l.speed+W)%W; });

  player.vy+=GRAVITY; player.y+=player.vy;
  const onG = player.y >= GROUND_Y-PH;
  if(onG){ player.y=GROUND_Y-PH; player.vy=0; player.jumps=0; player.rot=Math.round(player.rot/90)*90; }
  else player.rot+=4.5;
  if(player.y<0){ player.y=0; player.vy=0; }

  player.parts.forEach(p=>{ p.x+=p.vx; p.y+=p.vy; p.vy+=.15; p.life-=.06; });
  player.parts = player.parts.filter(p=>p.life>0);

  if(frame>=nextObs) spawnObs();
  obstacles.forEach(o=>o.x-=speed);
  obstacles = obstacles.filter(o=>o.x>-100);
  for(const o of obstacles){ if(hit(o)){ state='dead'; if(score>best)best=score; spawnDeath(); return; } }
}

function spawnDeath(){
  for(let i=0;i<30;i++){
    const a=Math.random()*Math.PI*2, s=2+Math.random()*6;
    deathParts.push({x:PX+PW/2,y:player.y+PH/2,vx:Math.cos(a)*s,vy:Math.sin(a)*s-2,life:1,sz:3+Math.random()*6,c:`hsl(${Math.random()*60+20},100%,60%)`});
  }
}

// ── Draw ───────────────────────────────────────────────────────────────────
function drawBg(){
  const g=ctx.createLinearGradient(0,0,0,H);
  g.addColorStop(0,`hsl(${bgHue},55%,18%)`); g.addColorStop(1,`hsl(${bgHue+40},55%,10%)`);
  ctx.fillStyle=g; ctx.fillRect(0,0,W,H);

  bgLayers.forEach((layer,li)=>{
    ctx.fillStyle=`hsla(${bgHue+60},40%,${li?55:40}%,${li?.12:.08})`;
    layer.cols.forEach(c=>{ const x=(c.x+layer.x)%W; ctx.fillRect(x-20,GROUND_Y-c.h,2,c.h); if(x<20)ctx.fillRect(x+W-20,GROUND_Y-c.h,2,c.h); });
  });

  ctx.strokeStyle=`hsla(${bgHue+180},60%,50%,.25)`; ctx.lineWidth=1;
  const off=(frame*speed*.5)%50;
  for(let x=-off;x<W;x+=50){ ctx.beginPath(); ctx.moveTo(x,GROUND_Y); ctx.lineTo(x,H); ctx.stroke(); }

  const gg=ctx.createLinearGradient(0,GROUND_Y,0,H);
  gg.addColorStop(0,`hsl(${bgHue+180},50%,22%)`); gg.addColorStop(1,`hsl(${bgHue+180},50%,12%)`);
  ctx.fillStyle=gg; ctx.fillRect(0,GROUND_Y,W,H-GROUND_Y);

  ctx.strokeStyle=`hsl(${bgHue+180},80%,60%)`; ctx.lineWidth=2;
  ctx.shadowColor=`hsl(${bgHue+180},80%,60%)`; ctx.shadowBlur=10;
  ctx.beginPath(); ctx.moveTo(0,GROUND_Y); ctx.lineTo(W,GROUND_Y); ctx.stroke();
  ctx.shadowBlur=0;
}

function drawObs(o){
  ctx.save();
  if(o.t==='spike'){
    const g=ctx.createLinearGradient(o.x,o.y-o.h,o.x,o.y);
    g.addColorStop(0,'#ff3344'); g.addColorStop(1,'#aa0011');
    ctx.fillStyle=g; ctx.strokeStyle='#ff6677'; ctx.lineWidth=1.5;
    ctx.beginPath(); ctx.moveTo(o.x,o.y); ctx.lineTo(o.x+o.w/2,o.y-o.h); ctx.lineTo(o.x+o.w,o.y); ctx.closePath();
    ctx.fill(); ctx.stroke();
  } else {
    const g=ctx.createLinearGradient(o.x,o.y,o.x+o.w,o.y+o.h);
    g.addColorStop(0,'#8833cc'); g.addColorStop(1,'#441166');
    ctx.fillStyle=g; ctx.strokeStyle='#bb55ff'; ctx.lineWidth=1.5;
    ctx.fillRect(o.x,o.y,o.w,o.h); ctx.strokeRect(o.x,o.y,o.w,o.h);
    ctx.fillStyle='rgba(255,255,255,.08)'; ctx.fillRect(o.x+3,o.y+3,o.w-6,(o.h-6)/2);
  }
  ctx.restore();
}

function drawPlayer(){
  // trail
  for(let i=5;i>=1;i--){
    ctx.fillStyle=`hsla(${bgHue+180},80%,70%,${(6-i)*.04})`;
    ctx.fillRect(PX-i*9,player.y+4,PW*(1-i*.12),PH-8);
  }
  // jump particles
  player.parts.forEach(p=>{ ctx.globalAlpha=p.life*.7; ctx.fillStyle=`hsl(${bgHue+180},80%,70%)`; ctx.fillRect(p.x-3,p.y-3,6,6); });
  ctx.globalAlpha=1;

  ctx.save();
  ctx.translate(PX+PW/2, player.y+PH/2);
  ctx.rotate(player.rot*Math.PI/180);
  if(heroReady){
    ctx.drawImage(heroImg, -PW/2, -PH/2, PW, PH);
  } else {
    drawCube();
  }
  ctx.restore();
}

function drawCube(){
  const hw=PW/2, hh=PH/2;
  ctx.shadowColor=`hsl(${bgHue+180},100%,70%)`; ctx.shadowBlur=12;
  const g=ctx.createLinearGradient(-hw,-hh,hw,hh);
  g.addColorStop(0,`hsl(${bgHue+180},90%,70%)`); g.addColorStop(1,`hsl(${bgHue+220},90%,40%)`);
  ctx.fillStyle=g; ctx.fillRect(-hw,-hh,PW,PH);
  ctx.shadowBlur=0;
  ctx.strokeStyle=`hsl(${bgHue+180},100%,85%)`; ctx.lineWidth=1.5; ctx.strokeRect(-hw+3,-hh+3,PW-6,PH-6);
  ctx.fillStyle=`hsl(${bgHue+180},100%,85%)`;
  ctx.beginPath(); ctx.moveTo(0,-hh+10); ctx.lineTo(hw-10,0); ctx.lineTo(0,hh-10); ctx.lineTo(-hw+10,0); ctx.closePath(); ctx.fill();
}

function drawHUD(){
  ctx.fillStyle='rgba(255,255,255,.9)'; ctx.font='bold 28px "Arial Black",Arial'; ctx.textAlign='right';
  ctx.fillText(score,W-20,42);
  ctx.font='14px Arial'; ctx.fillStyle='rgba(255,255,255,.4)'; ctx.fillText('BEST '+best,W-20,62);
  ctx.textAlign='left'; ctx.fillStyle='rgba(255,255,255,.3)'; ctx.font='14px Arial'; ctx.fillText('attempt '+attempts,20,42);
}

function drawMenu(){
  ctx.fillStyle='rgba(0,0,0,.55)'; ctx.fillRect(0,0,W,H);
  ctx.textAlign='center';
  ctx.shadowColor=`hsl(${bgHue},80%,60%)`; ctx.shadowBlur=20;
  ctx.fillStyle='#FFF'; ctx.font='bold 56px "Arial Black",Arial'; ctx.fillText('GEOMETRY DASH',W/2,H/2-60);
  ctx.shadowBlur=0;
  ctx.fillStyle=`hsl(${bgHue+180},80%,75%)`; ctx.font='bold 20px Arial'; ctx.fillText('Press  SPACE  /  CLICK  to Start',W/2,H/2+10);
  ctx.fillStyle='rgba(255,255,255,.35)'; ctx.font='15px Arial'; ctx.fillText('Double jump available  •  Avoid spikes & blocks',W/2,H/2+48);
}

function drawDead(){
  ctx.fillStyle='rgba(200,0,0,.22)'; ctx.fillRect(0,0,W,H);
  ctx.textAlign='center';
  ctx.shadowColor='#f24'; ctx.shadowBlur=30;
  ctx.fillStyle='#FFF'; ctx.font='bold 52px "Arial Black",Arial'; ctx.fillText('GAME OVER',W/2,H/2-55);
  ctx.shadowBlur=0;
  ctx.font='bold 26px Arial'; ctx.fillStyle=`hsl(${bgHue+180},80%,75%)`; ctx.fillText('Score: '+score,W/2,H/2+5);
  if(score>0&&score>=best){ ctx.fillStyle='#FFD700'; ctx.font='bold 20px Arial'; ctx.fillText('NEW BEST!',W/2,H/2+38); }
  ctx.fillStyle='rgba(255,255,255,.5)'; ctx.font='18px Arial'; ctx.fillText('SPACE / CLICK to try again',W/2,H/2+80);
}

function drawDeathParts(){
  deathParts.forEach(p=>{ ctx.globalAlpha=p.life; ctx.fillStyle=p.c; ctx.fillRect(p.x-p.sz/2,p.y-p.sz/2,p.sz,p.sz); });
  ctx.globalAlpha=1;
}

function loop(){
  update();
  drawBg();
  obstacles.forEach(drawObs);
  drawPlayer();
  drawDeathParts();
  drawHUD();
  if(state==='menu') drawMenu();
  if(state==='dead') drawDead();
  requestAnimationFrame(loop);
}
loop();
</script>
</body>
</html>
"""

HTML = HTML.replace("'HERO_DATA_URL'", "'" + DATA_URL + "'")

with open(r'C:\Users\yotam\.claude\projects\geometry-dash\index.html', 'w', encoding='utf-8') as f:
    f.write(HTML)

print("Written OK, file size:", len(HTML), "bytes")
