const {test}=require('node:test'); const assert=require('node:assert/strict'); const vm=require('node:vm');const fs=require('node:fs');
const code=fs.readFileSync('Extension/content.js','utf8');
async function run(music=false) {
 let tick, listener, packet, clicks=0;
 const video={currentTime:music?4074:42,duration:music?8000:322,paused:false,ended:false,readyState:4};
 const bar=music?{querySelector:s=>s==='.title'?{textContent:'Hero'}:s==='.byline a'?{textContent:'Skillet'}:s==='#progress-bar'?{getAttribute:n=>n==='aria-valuenow'?'109':'187'}:null}:null;
 const context={setInterval:f=>tick=f,URL,location:{href:music?'https://music.youtube.com/':'https://www.youtube.com/watch?v=abc'},navigator:{mediaSession:{playbackState:'playing',metadata:{title:'Green Day - 21 Guns [Official Music Video]',artist:'Green Day'}}},document:{querySelector:s=>s.includes('video.html5')?video:s==='ytmusic-player-bar'?bar:s==='.ytp-play-button'?{click:()=>clicks++}:null},chrome:{runtime:{sendMessage:async m=>packet=m.packet,onMessage:{addListener:f=>listener=f}}}};
 vm.runInNewContext(code,context);await tick();return {packet,control:listener,clicks:()=>clicks};
}
test('YouTube metadata removes only known cosmetic title decorations',async()=>{const {packet}=await run();assert.equal(packet.title,'21 Guns');assert.equal(packet.artist,'Green Day');assert.equal(packet.trackID,'abc');assert.equal(packet.position,42);});
test('YouTube Music uses UI timeline when retained video is wrong',async()=>{const {packet}=await run(true);assert.equal(packet.position,109);assert.equal(packet.duration,187);assert.equal(packet.quantized,true);});
test('control messages cannot target a different song',async()=>{const x=await run();x.control({kind:'liris-control',trackID:'other',command:'toggle'});assert.equal(x.clicks(),0);x.control({kind:'liris-control',trackID:'abc',command:'toggle'});assert.equal(x.clicks(),1);});
