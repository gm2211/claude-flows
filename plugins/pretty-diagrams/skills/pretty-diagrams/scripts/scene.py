#!/usr/bin/env python3
"""Exchange local scenes or call a stateless Streamable HTTP MCP tool."""
import argparse,json,pathlib,urllib.request,urllib.parse
p=argparse.ArgumentParser(description=__doc__)
p.add_argument('--url',default='http://127.0.0.1:3100')
s=p.add_subparsers(dest='command',required=True)
for name in ['put','get','mcp']:
 q=s.add_parser(name);q.add_argument('name');q.add_argument('file',type=pathlib.Path)
a=p.parse_args()
def request(route,data=None,method=None):
 req=urllib.request.Request(a.url+route,data=None if data is None else json.dumps(data).encode(),method=method,headers={'Content-Type':'application/json','Accept':'application/json, text/event-stream'})
 with urllib.request.urlopen(req,timeout=60) as r:raw=r.read().decode()
 if raw.startswith('event:') or raw.startswith('data:'):
  events=[json.loads(line[5:].strip()) for line in raw.splitlines() if line.startswith('data:')]
  return next(e for e in events if 'result' in e or 'error' in e)
 return json.loads(raw)
route='/api/scenes/'+urllib.parse.quote(a.name,safe='')
if a.command=='put':print(json.dumps(request(route,json.loads(a.file.read_text()),'PUT')))
elif a.command=='get':
 result=request(route);result.update(type='excalidraw',version=2,source=a.url);a.file.write_text(json.dumps(result,indent=2)+'\n');print(a.file)
else:
 result=request('/mcp',{'jsonrpc':'2.0','id':1,'method':'tools/call','params':{'name':a.name,'arguments':json.loads(a.file.read_text())}})
 print(json.dumps(result,indent=2))
 if 'error' in result or result.get('result',{}).get('isError'):raise SystemExit(1)
