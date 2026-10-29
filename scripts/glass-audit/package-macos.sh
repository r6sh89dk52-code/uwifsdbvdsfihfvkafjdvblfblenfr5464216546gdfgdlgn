#!/usr/bin/env bash
# Candidate only. No signing, deployment, real clinical data or device install.
set -euo pipefail
cd "$(dirname "$0")/../.."
: "${DANPER_AUDIT_OUT:?Set the evidence directory from validate-macos.sh}"
OUT="$DANPER_AUDIT_OUT"
SHA=$(git rev-parse HEAD)
test "$(cat "$OUT/VALIDATED_SHA.txt")" = "$SHA"
node scripts/glass-audit/identity.cjs
# Do not attribute edited source to a prior commit.
git diff --exit-code HEAD -- native-ios/App native-ios/Sources native-ios/project.yml scripts/glass-audit
DD="$OUT/DeviceDerivedData"
xcodebuild -project native-ios/DANPERNative.xcodeproj -scheme DANPERNative -configuration Release \
 -sdk iphoneos -destination 'generic/platform=iOS' -derivedDataPath "$DD" \
 ARCHS=arm64 ONLY_ACTIVE_ARCH=NO CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO \
 build > "$OUT/release-iphoneos.log" 2>&1
APP="$DD/Build/Products/Release-iphoneos/DANPERNative.app"
python3 - "$APP" "$SHA" <<'PY'
from pathlib import Path
import json,plistlib,sys,subprocess,hashlib,shutil
app=Path(sys.argv[1]); p=plistlib.loads((app/'Info.plist').read_bytes())
assert p['CFBundleIdentifier']=='pe.danper.saludmovil.native.iloaderpreview'
assert p['CFBundleShortVersionString']=='0.4.2' and p['CFBundleVersion']=='13'
assert p['CFBundleSupportedPlatforms']==['iPhoneOS']
assert p['NSFaceIDUsageDescription'] and p['UILaunchStoryboardName']=='LaunchScreen'
assert list(app.rglob('LaunchScreen.storyboardc'))
assert not (app/'embedded.mobileprovision').exists() and not (app/'_CodeSignature').exists()
exe=app/p['CFBundleExecutable']; assert exe.is_file()
archs=subprocess.check_output(['lipo','-archs',str(exe)],text=True).strip(); assert archs=='arm64',archs
header=subprocess.check_output(['otool','-l',str(exe)],text=True);assert 'LC_ENCRYPTION_INFO' not in header or 'cryptid 0' in header
assert subprocess.run(['codesign','--verify',str(app)],capture_output=True).returncode != 0
assert not (app/'N1sDemoResources/n2-synthetic-clinical.json').exists()
assert not list(app.rglob('*.xctest')) and not list(app.rglob('SyntheticFixtures'))
resources=app/'N1sDemoResources'
expected={'n1s-indicator-plan.json','n1s-indicator-template-store.zip','n1s-nursing-plan.json','n1s-nursing-template-store.zip','n2-ambulatory-products.json','n2-nursing-catalog.json','n2-approved-mappings.json','n2-organization-areas.json'}
assert {p.name for p in resources.iterdir()}==expected,'Unexpected bundled dataset/resource'
assert b'DANPER_GREETING_TEST_LOCAL' not in exe.read_bytes(),'Test clock must not ship in Release'
# Asset catalog compilation embeds both images; preserve the exact source digests.
assetutil=shutil.which('assetutil') or '/usr/bin/assetutil'
assetinfo=json.loads(subprocess.check_output([assetutil,'--info',str(app/'Assets.car')]))
names={row.get('Name') for row in assetinfo}
assert {'ClinicalAvatar','ClinicalPortrait'}<=names,names
subprocess.run(['git','diff','--exit-code','5aa09ad20a99eedabd0bbaefd16fbb3d0316f2eb','HEAD','--','native-ios/App/DANPERNativeApp.swift'],check=True)
content={'avatarSHA256':hashlib.sha256(Path('native-ios/App/Assets.xcassets/ClinicalAvatar.imageset/ClinicalAvatar.png').read_bytes()).hexdigest(),
 'portraitSHA256':hashlib.sha256(Path('native-ios/App/Assets.xcassets/ClinicalPortrait.imageset/ClinicalPortrait.png').read_bytes()).hexdigest(),
 'accessViewFileSHA256':hashlib.sha256(Path('native-ios/App/DANPERNativeApp.swift').read_bytes()).hexdigest(),
 'greetingFileSHA256':hashlib.sha256(Path('native-ios/App/DanperGreeting.swift').read_bytes()).hexdigest(),
 'compiledAssetNames':sorted(n for n in names if n),'distributionResources':sorted(expected),
 'testClockAbsentInRelease':True,'clinicalDatasetsBundled':False}
assert content['avatarSHA256']=='51d79d1d46607d4b9e58599e861428790a06c55ebff391c85d28a0b5a829fdcf'
assert content['portraitSHA256']=='c43917268ce67191a70e2b6549747229b3e7414b21c951bf4432d3257f177291'
(app/'DANPER_CONTENTS.json').write_text(json.dumps(content,indent=2))
for name in ['n1s-indicator-template-store.zip','n1s-nursing-template-store.zip','n2-ambulatory-products.json','n2-nursing-catalog.json','n2-approved-mappings.json']:
 assert (app/'N1sDemoResources'/name).is_file(),name
identity={'sourceSHA':sys.argv[2],'bundle':p['CFBundleIdentifier'],'version':p['CFBundleShortVersionString'],'build':p['CFBundleVersion'],'architecture':archs,'signed':False,'deviceValidation':False}
(app/'DANPER_BUILD.json').write_text(json.dumps(identity,indent=2))
manifest={str(f.relative_to(app)):hashlib.sha256(f.read_bytes()).hexdigest() for f in sorted(app.rglob('*')) if f.is_file()}
Path(sys.argv[1]).parent.joinpath('APP_SHA256.json').write_text(json.dumps(manifest,indent=2))
PY
mkdir -p "$OUT/package/Payload" "$OUT/ipa"
cp -R "$APP" "$OUT/package/Payload/"
cp "$DD/Build/Products/Release-iphoneos/APP_SHA256.json" "$OUT/ipa/APP_SHA256.json"
IPA="$OUT/ipa/DANPER_GLASS_PRO_0.4.2_13_ILOADER_UNSIGNED.ipa"
(cd "$OUT/package" && /usr/bin/ditto -c -k --keepParent Payload "$IPA")
unzip -t "$IPA" > "$OUT/ipa/zip-integrity.log"
python3 - "$IPA" "$OUT/ipa/APP_SHA256.json" "$SHA" <<'PY'
import zipfile,json,hashlib,sys,plistlib
with zipfile.ZipFile(sys.argv[1]) as z:
 assert z.testzip() is None
 assert all(n.startswith('Payload/') for n in z.namelist())
 prefix='Payload/DANPERNative.app/'
 for f,digest in json.load(open(sys.argv[2])).items(): assert hashlib.sha256(z.read(prefix+f)).hexdigest()==digest,f
 p=plistlib.loads(z.read(prefix+'Info.plist'));assert p['CFBundleIdentifier']=='pe.danper.saludmovil.native.iloaderpreview'
 assert p['CFBundleShortVersionString']=='0.4.2' and p['CFBundleVersion']=='13'
 content=json.loads(z.read(prefix+'DANPER_CONTENTS.json'));assert content['testClockAbsentInRelease'] and not content['clinicalDatasetsBundled']
 provenance=json.loads(z.read(prefix+'DANPER_BUILD.json'));assert provenance['sourceSHA']==sys.argv[3]
provenance['ipaSHA256']=hashlib.sha256(open(sys.argv[1],'rb').read()).hexdigest()
open(sys.argv[1]+'.json','w').write(json.dumps(provenance,indent=2))
print(json.dumps(provenance,indent=2))
PY
shasum -a 256 "$IPA" > "$OUT/ipa/SHA256SUMS.txt"
echo 'Unsigned candidate; separate installation also depends on iLoader provisioning/signing. Physical device, VoiceOver, Reduce Transparency/Motion and real migration remain unverified.' > "$OUT/ipa/LIMITATIONS.txt"
