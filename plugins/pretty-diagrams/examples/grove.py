#!/usr/bin/env python3
"""Regenerate the editable Grove example (coordinates in Excalidraw units)."""
import json,pathlib
els=[]
INK='#243746';BLUE='#dceafb';SAGE='#dcebdc';PEACH='#fae3cf'
def add(kind,id,x,y,w,h,**kw):
 e=dict(type=kind,id=id,x=x,y=y,width=w,height=h,strokeColor=INK,backgroundColor='transparent',fillStyle='solid',strokeWidth=1.6,roughness=1,opacity=100,seed=len(els)+41,**kw);els.append(e);return e
def text(id,x,y,s,size=22,color=INK):
 e=add('text',id,x,y,max(len(t) for t in s.split('\n'))*size*.57,len(s.split('\n'))*size*1.25,text=s,fontSize=size,fontFamily=1,textAlign='left',verticalAlign='top');e['strokeColor']=color

def box(id,x,y,w,h,title,subtitle,color):
 e=add('rectangle',id,x,y,w,h,roundness={'type':3});e['backgroundColor']=color
 text(id+'-title',x+24,y+21,title,28)
 if subtitle:text(id+'-sub',x+24,y+61,subtitle,20)
def arrow(id,points,dashed=False):
 x,y=points[0];e=add('arrow',id,x,y,max(p[0] for p in points)-min(p[0] for p in points),max(p[1] for p in points)-min(p[1] for p in points),points=[[a-x,b-y] for a,b in points],startArrowhead=None,endArrowhead='arrow',strokeStyle='dashed' if dashed else 'solid',roundness={'type':2});return e
text('title',100,45,'Grove turns intent into running work',42)
text('subtitle',102,105,'One control plane. Two separate responsibilities.',24,'#64716b')
text('entry-caption',102,166,'01   INTENT',18,'#64716b')
box('orchestrator',100,205,365,112,'Agent orchestrator','automation & coordination',BLUE)
box('agents',540,205,365,112,'Claude Code / Codex','MCP over stdio',BLUE)
box('cli',980,205,365,112,'grove CLI','direct commands',BLUE)
arrow('orchestrator-api',[(282,325),(282,365),(620,365),(620,398)])
arrow('agents-api',[(722,325),(722,398)])
arrow('cli-api',[(1162,325),(1162,365),(830,365),(830,398)])
box('grove',490,405,465,132,'grove server','HTTP API + embedded UI',SAGE)
text('plane-caption',105,437,'02   CONTROL PLANE',18,'#64716b')
arrow('api-nomad',[(620,545),(620,578),(375,578),(375,634)])
arrow('api-orchard',[(830,545),(830,578),(1080,578),(1080,634)])
text('nomad-protocol',195,598,'Nomad HTTP',20)
text('orchard-protocol',1105,591,'Orchard REST',20)
box('nomad',175,645,400,122,'Nomad server','Schedules jobs inside VMs',BLUE)
box('orchard',880,645,400,122,'Orchard controller','Creates & manages VMs',PEACH)
# These arrows point UP: clients/workers initiate the connection.
arrow('nomad-dial',[(375,918),(375,779)],True)
arrow('worker-dial',[(1080,918),(1080,779)],True)
text('nomad-dial-label',400,786,'client dials out',19)
text('worker-dial-label',1102,786,'worker\ndials out',19)
e=add('rectangle','mac',100,845,1245,250,roundness={'type':3});e['strokeColor']='#a3afa3';e['strokeStyle']='dashed';e['roughness']=.6
text('mac-title',125,866,'03   EACH MAC',18,'#64716b')
box('vm',175,925,400,127,'Tart VMs','Nomad client inside each VM',BLUE)
box('worker',880,925,400,127,'Orchard worker','Runs on the Mac host',PEACH)
text('separation',619,962,'jobs inside VMs\nVM lifecycle outside',19,'#64716b')
arrow('legend-solid',[(105,1145),(165,1145)])
text('legend-solid-text',180,1130,'request / control',18,'#64716b')
arrow('legend-dashed',[(445,1145),(505,1145)],True)
text('legend-dashed-text',520,1130,'connection initiation',18,'#64716b')
scene=dict(type='excalidraw',version=2,source='pretty-diagrams',elements=els,appState={'viewBackgroundColor':'#fffdf7'},files={})
out=pathlib.Path(__file__).with_name('grove.excalidraw');out.write_text(json.dumps(scene,indent=2)+'\n');print(out)
