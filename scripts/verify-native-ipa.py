#!/usr/bin/env python3
"""Inspect the packaged binary and exact sanitized resources, independent of Xcode logs."""
import argparse
import hashlib
import json
import os
from pathlib import Path, PurePosixPath
import plistlib
import struct
import subprocess
import zipfile

RESOURCES = {
    'n1s-indicator-plan.json', 'n1s-indicator-template-store.zip',
    'n1s-nursing-plan.json', 'n1s-nursing-template-store.zip',
    'n2-ambulatory-products.json', 'n2-nursing-catalog.json',
    'n2-approved-mappings.json', 'n2-organization-areas.json',
}


def inspect_macho(binary):
    if len(binary) < 32:
        raise ValueError('Truncated executable')
    magic, cpu, _, filetype, ncmds, sizeofcmds, _, _ = struct.unpack_from('<8I', binary)
    if (magic, cpu, filetype) != (0xFEEDFACF, 0x0100000C, 2):
        raise ValueError('Expected thin ARM64 Mach-O executable')
    end = 32 + sizeofcmds
    if end > len(binary):
        raise ValueError('Truncated Mach-O commands')
    platform = None
    offset = 32
    for _ in range(ncmds):
        cmd, size = struct.unpack_from('<II', binary, offset)
        if size < 8 or offset + size > end:
            raise ValueError('Invalid Mach-O command')
        if cmd == 0x1D:
            raise ValueError('LC_CODE_SIGNATURE present: unsigned IPA expected')
        if cmd == 0x32:
            platform = struct.unpack_from('<I', binary, offset + 8)[0]
        offset += size
    if platform != 2:
        raise ValueError('Expected LC_BUILD_VERSION platform iOS (2), not simulator')
    return {'architecture': 'arm64', 'platform': 'iOS', 'signed': False}


def verify(args):
    prefix = 'Payload/DANPERNative.app/'
    with zipfile.ZipFile(args.ipa) as archive:
        if archive.testzip() is not None:
            raise ValueError('ZIP CRC failure')
        names = archive.namelist()
        if len(names) != len(set(names)):
            raise ValueError('Duplicate ZIP entries')
        for name in names:
            if name.startswith('/') or '..' in PurePosixPath(name).parts or not name.startswith('Payload/'):
                raise ValueError('Unexpected package path: ' + name)
            if name != 'Payload/' and not name.startswith(prefix):
                raise ValueError('Unexpected application in Payload')
            if any(part in ('_CodeSignature', 'SyntheticFixtures', 'Documents', 'Library')
                   for part in PurePosixPath(name).parts):
                raise ValueError('Unexpected signature, test fixture or user directory: ' + name)
            if name.lower().endswith(('.danperbackup', '.mobileprovision', '.sqlite', '.sqlite3', '.db', '.xlsx', '.xls', '.csv', '.p12', '.pfx', '.pem', '.key', '.cer', '.crt')):
                raise ValueError('Unexpected personal data or signing material: ' + name)
        info = plistlib.loads(archive.read(prefix + 'Info.plist'))
        expected = {
            'CFBundleIdentifier': 'pe.danper.saludmovil.native.preview',
            'CFBundleExecutable': 'DANPERNative',
            'CFBundleShortVersionString': args.version,
            'CFBundleVersion': args.build,
            'CFBundleSupportedPlatforms': ['iPhoneOS'],
            'UILaunchStoryboardName': 'LaunchScreen',
        }
        for key, value in expected.items():
            if info.get(key) != value:
                raise ValueError(f'{key}: expected {value!r}, got {info.get(key)!r}')
        if not info.get('NSFaceIDUsageDescription'):
            raise ValueError('Missing Face ID purpose')
        if not any('/LaunchScreen.storyboardc/' in n for n in names):
            raise ValueError('Compiled launch storyboard missing')
        icons = info.get('CFBundleIcons', {}).get('CFBundlePrimaryIcon', {}).get('CFBundleIconFiles', [])
        if not icons or not any(n.startswith(prefix + icon) and n.endswith('.png') for icon in icons for n in names):
            raise ValueError('Compiled AppIcon missing')
        if prefix + 'Assets.car' not in names:
            raise ValueError('Compiled image assets missing')
        binary_info = inspect_macho(archive.read(prefix + 'DANPERNative'))
        resource_prefix = prefix + 'N1sDemoResources/'
        actual = {n[len(resource_prefix):] for n in names if n.startswith(resource_prefix) and not n.endswith('/')}
        if actual != RESOURCES:
            raise ValueError(f'Resource allowlist mismatch: {actual ^ RESOURCES}')
        hashes = {}
        for name in sorted(RESOURCES):
            packaged = archive.read(resource_prefix + name)
            source = (args.resources / name).read_bytes()
            if packaged != source:
                raise ValueError('Packaged resource differs from sanitized generator: ' + name)
            hashes[name] = hashlib.sha256(packaged).hexdigest()
    toolchain = subprocess.check_output(['xcodebuild', '-version'], text=True).strip()
    return {
        'commit': args.commit,
        'run_url': f"https://github.com/{os.environ['GITHUB_REPOSITORY']}/actions/runs/{os.environ['GITHUB_RUN_ID']}",
        'run_attempt': os.environ.get('GITHUB_RUN_ATTEMPT'),
        'bundle_id': info['CFBundleIdentifier'],
        'version': args.version, 'build': args.build,
        'minimum_os': info.get('MinimumOSVersion'),
        **binary_info,
        'ipa': args.ipa.name, 'sha256': hashlib.sha256(args.ipa.read_bytes()).hexdigest(),
        'toolchain': toolchain,
        'sdk': subprocess.check_output(['xcrun', '--sdk', 'iphoneos', '--show-sdk-version'], text=True).strip(),
        'status': 'CANDIDATE_UNSIGNED_NOT_CLINICALLY_VALIDATED',
        'technical_verification': 'PASS',
        'privacy_audit': 'PASS: resource allowlist and hashes; no personal data or signing material detected',
        'validation': {'javascript': 'NOT RUN', 'swift_core': 'NOT RUN', 'native_and_ui_xctest': 'NOT RUN'},
        'resource_sha256': hashes,
        'installation': 'Requires signing; no physical device installation performed',
    }


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('ipa', type=Path)
    parser.add_argument('--resources', type=Path, required=True)
    for field in ('version', 'build', 'commit'):
        parser.add_argument('--' + field, required=True)
    parser.add_argument('--output', type=Path, required=True)
    options = parser.parse_args()
    options.output.write_text(json.dumps(verify(options), indent=2) + '\n')
