"""Verify subscription price after setting it in ASC."""
import time, json, jwt, requests, base64
from collections import Counter

P8 = 'AuthKey_97424KMZ3Y.p8'
KEY_ID = '97424KMZ3Y'
ISSUER_ID = '81066b9e-6b4f-40b0-aacc-e1de4a43343c'
SUB_ID = '6767801250'

with open(P8,'rb') as f: key = f.read()
token = jwt.encode({'iss': ISSUER_ID, 'iat': int(time.time()), 'exp': int(time.time())+1200, 'aud': 'appstoreconnect-v1'}, key, algorithm='ES256', headers={'kid': KEY_ID, 'typ': 'JWT'})

r = requests.get(f'https://api.appstoreconnect.apple.com/v1/subscriptions/{SUB_ID}/prices', 
    headers={'Authorization': f'Bearer {token}'}, params={'limit': 200})
data = r.json()
countries = []
for p in data.get('data', []):
    try:
        decoded = json.loads(base64.b64decode(p['id'] + '==').decode())
        countries.append(decoded)
    except: pass

tier_count = Counter(c.get('p') for c in countries)
us = next((c for c in countries if c.get('c') == 'US'), None)
print(f'total entries: {len(countries)}')
print(f'tier distribution: {dict(tier_count)}')
print(f'US: {us}')
if us and us.get('p') == '0':
    print('❌ STILL TIER 0 (= $0) - price not saved correctly')
elif us and us.get('p') != '0':
    print(f'✅ US price tier = {us.get("p")} - looks set')
else:
    print('? US not found in price list')
