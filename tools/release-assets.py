"""Package a built payload and matching tagged source, without personal test data."""
from pathlib import Path
import hashlib
import subprocess
import zipfile

root = Path(__file__).resolve().parents[1]
release = root / "release"
release.mkdir(exist_ok=True)
tag = "v0.1.1"
portable = release / "SignalRGBProxy-v0.1.1-portable-win-x64.zip"
with zipfile.ZipFile(portable, "w", zipfile.ZIP_DEFLATED) as archive:
    for name in ("SignalRGBProxy.ps1", "Start.cmd", "Install.cmd", "Uninstall.cmd", "proxy.txt", "README.md", "BUILD.md", "CREDITS.md", "CREDITS.txt", "LICENSE"):
        archive.write(root / name, "SignalRGBProxy/" + name)
    for name in ("DWrite.dll", "force-proxy.dll"):
        archive.write(root / "payload" / name, "SignalRGBProxy/" + name)
    for directory in ("licenses", "docs"):
        for file in sorted((root / directory).rglob("*")):
            if file.is_file():
                archive.write(file, "SignalRGBProxy/" + file.relative_to(root).as_posix())
source = release / "vibecoded-signalrgb-proxy-integration-v0.1.1-source.zip"
subprocess.run(["git", "-C", str(root), "archive", "--format=zip", "--prefix=vibecoded-signalrgb-proxy-integration/", f"--output={source}", tag], check=True)
installer = release / "SignalRGBProxyInstaller-v0.1.1-win-x64.exe"
assets = (installer, portable, source)
for file in assets:
    if file.suffix == ".zip":
        with zipfile.ZipFile(file) as archive:
            assert archive.testzip() is None
    print(f"{file.name}: {file.stat().st_size:,} bytes")
(release / "SHA256SUMS.txt").write_text("".join(
    f"{hashlib.sha256(file.read_bytes()).hexdigest()}  {file.name}\n" for file in assets
))
