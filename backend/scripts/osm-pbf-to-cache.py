import sys, json, re, os, osmium
pbf, outdir = sys.argv[1], sys.argv[2]
CITIES = {'ha-noi': (20.8,105.65,21.2,106.05), 'tp-ho-chi-minh': (10.65,106.35,10.95,106.95)}
SOC = re.compile(r'(^|;)soccer(;|$)')
def want(t):
    return t.get('leisure') in ('pitch','sports_centre') and SOC.search(t.get('sport',''))
res = {k: [] for k in CITIES}
def put(typ, oid, lat, lon, tags):
    for k,(s,w,n,e) in CITIES.items():
        if s<=lat<=n and w<=lon<=e:
            el={'type':typ,'id':oid,'tags':tags}
            if typ=='node': el['lat'],el['lon']=lat,lon
            else: el['center']={'lat':lat,'lon':lon}
            res[k].append(el)
class H(osmium.SimpleHandler):
    def node(self,n):
        if want(n.tags) and n.location.valid(): put('node',n.id,n.location.lat,n.location.lon,{t.k:t.v for t in n.tags})
    def area(self,a):
        if not want(a.tags): return
        pts=[(nd.lat,nd.lon) for r in a.outer_rings() for nd in r if nd.location.valid()]
        if not pts: return
        typ='way' if a.from_way() else 'relation'
        put(typ,a.orig_id(),sum(p[0] for p in pts)/len(pts),sum(p[1] for p in pts)/len(pts),{t.k:t.v for t in a.tags})
H().apply_file(pbf, locations=True)
os.makedirs(outdir, exist_ok=True)
for k,els in res.items():
    els.sort(key=lambda e:(e['type'],e['id']))
    with open(os.path.join(outdir,k+'.json'),'w',encoding='utf-8') as f:
        json.dump({'version':0.6,'generator':'geofabrik vietnam-latest.osm.pbf via pyosmium','osm3s':{'copyright':'The data included in this document is from www.openstreetmap.org. The data is made available under ODbL.'},'elements':els},f,ensure_ascii=False,indent=2); f.write('\n')
    print(k, len(els), 'named:', sum(1 for e in els if e['tags'].get('name')))
