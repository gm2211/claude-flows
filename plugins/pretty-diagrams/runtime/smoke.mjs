import assert from 'node:assert/strict';
const base=process.env.EXCALIDRAW_URL??'http://127.0.0.1:3100';
async function rpc(method,params={}){const r=await fetch(base+'/mcp',{method:'POST',headers:{'content-type':'application/json',accept:'application/json, text/event-stream'},body:JSON.stringify({jsonrpc:'2.0',id:1,method,params})});assert.equal(r.status,200);const raw=await r.text();const body=raw.startsWith('event:')||raw.startsWith('data:')?JSON.parse(raw.split('\n').find(x=>x.startsWith('data:')).slice(5)):JSON.parse(raw);assert.ok(!body.error,JSON.stringify(body));return body.result;}
assert.equal((await fetch(base+'/health')).status,200);
assert.equal((await fetch(base+'/')).status,200);
const init=await rpc('initialize',{protocolVersion:'2024-11-05',capabilities:{},clientInfo:{name:'pretty-diagrams-smoke',version:'1'}});assert.ok(init.serverInfo);
const tools=await rpc('tools/list');assert.ok(tools.tools.some(x=>x.name==='create_view'));
const ref=await rpc('tools/call',{name:'read_me',arguments:{}});assert.ok(ref.content[0].text.length>100);
const result=await rpc('tools/call',{name:'create_view',arguments:{elements:JSON.stringify([{type:'rectangle',id:'smoke-box',x:10,y:10,width:250,height:100,backgroundColor:'#dcebdc',label:{text:'Local MCP checkpoint'}}])}});assert.ok(!result.isError,JSON.stringify(result));
const id=result.structuredContent.checkpointId;
const checkpoint=await(await fetch(base+'/api/scenes/'+id)).json();assert.equal(checkpoint.elements[0].id,'smoke-box');
assert.equal((await fetch(base+'/api/scenes/'+id,{method:'PUT',headers:{'content-type':'application/json'},body:JSON.stringify({...checkpoint,appState:{viewBackgroundColor:'#fffdf7'}})})).status,200);
assert.equal((await(await fetch(base+'/api/scenes/'+id)).json()).appState.viewBackgroundColor,'#fffdf7');
assert.equal((await fetch(base+'/api/scenes/bad.id',{method:'PUT',headers:{'content-type':'application/json'},body:'{"elements":[]}'})).status,400);
assert.equal((await fetch(base+'/api/scenes/invalid',{method:'PUT',headers:{'content-type':'application/json'},body:'{"elements":null}'})).status,400);
console.log('PASS: health, editor, MCP initialize/list/read/create, shared checkpoint, browser save, invalid inputs');
console.log('Checkpoint:',id);
