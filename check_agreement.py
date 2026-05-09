"""
Verify ASC paid agreement status + IAP configuration directly via App Store Connect API.

Usage:
  pip install pyjwt cryptography requests
  python check_agreement.py <path_to_AuthKey.p8> <KEY_ID> <ISSUER_ID> [APP_BUNDLE_ID]

Example:
  python check_agreement.py AuthKey_ABC123.p8 ABC123XYZ4 12345678-90ab-cdef-1234-567890abcdef com.yin.iaptest
"""

import sys, time, json
import jwt
import requests


def make_jwt(p8_path, key_id, issuer_id):
    with open(p8_path, 'rb') as f:
        key = f.read()
    headers = {'kid': key_id, 'typ': 'JWT'}
    payload = {
        'iss': issuer_id,
        'iat': int(time.time()),
        'exp': int(time.time()) + 1200,  # 20 min
        'aud': 'appstoreconnect-v1',
    }
    return jwt.encode(payload, key, algorithm='ES256', headers=headers)


def call(token, path, params=None):
    r = requests.get(
        f'https://api.appstoreconnect.apple.com/v1{path}',
        headers={'Authorization': f'Bearer {token}'},
        params=params or {},
    )
    return r.status_code, r.json() if r.text else {}


def main():
    if len(sys.argv) < 4:
        print(__doc__)
        sys.exit(1)
    p8, kid, iss = sys.argv[1], sys.argv[2], sys.argv[3]
    bundle_id = sys.argv[4] if len(sys.argv) > 4 else None

    token = make_jwt(p8, kid, iss)
    print(f'[*] JWT generated (kid={kid[:6]}..., iss={iss[:8]}...)\n')

    # 1. List apps
    code, data = call(token, '/apps', {'limit': 200})
    print(f'[*] /v1/apps -> HTTP {code}')
    if code != 200:
        print(json.dumps(data, indent=2))
        sys.exit(2)
    apps = data.get('data', [])
    print(f'[+] {len(apps)} apps in account')
    for a in apps:
        attr = a.get('attributes', {})
        print(f'    - {attr.get("bundleId"):40s}  name={attr.get("name")!r}  sku={attr.get("sku")}')

    target = None
    if bundle_id:
        for a in apps:
            if a['attributes'].get('bundleId') == bundle_id:
                target = a
                break
        if not target:
            print(f'\n[!] bundleId {bundle_id} NOT in account')
            sys.exit(3)

    if target:
        app_id = target['id']
        print(f'\n[*] target app id={app_id} bundleId={bundle_id}')

        # 2. Subscriptions on this app
        code, data = call(token, f'/apps/{app_id}/subscriptionGroups', {'limit': 50})
        print(f'\n[*] subscriptionGroups -> HTTP {code}')
        if code == 200:
            for g in data.get('data', []):
                gid = g['id']
                gname = g['attributes'].get('referenceName')
                print(f'    group {gid}: {gname}')
                # subscriptions inside
                code2, d2 = call(token, f'/subscriptionGroups/{gid}/subscriptions', {'limit': 50})
                if code2 == 200:
                    for s in d2.get('data', []):
                        sa = s['attributes']
                        print(f'      sub: pid={sa.get("productId"):40s} state={sa.get("state")} family={sa.get("familySharable")}')

    # 3. Crucial: check inAppPurchasesV2 (V1 deprecated) availability check
    if target:
        code, data = call(token, f'/apps/{app_id}/inAppPurchasesV2', {'limit': 50})
        print(f'\n[*] inAppPurchasesV2 -> HTTP {code}')
        if code == 200:
            for iap in data.get('data', []):
                ia = iap['attributes']
                print(f'    iap: pid={ia.get("productId")} state={ia.get("state")} reviewable={ia.get("reviewNote")}')

    # 4. Try fetching agreement-like data
    print('\n[*] (Note: Agreements API endpoint requires Account Holder role. The above')
    print('         subscription queries already tell us if IAP is queryable.)')


if __name__ == '__main__':
    main()
