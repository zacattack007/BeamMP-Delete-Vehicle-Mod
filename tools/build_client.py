"""Build the server-distributed locator ZIP. Run with Python 3."""
from pathlib import Path
from zipfile import ZipFile, ZIP_DEFLATED

root = Path(__file__).resolve().parents[1] / "BeamMP-Delete-Vehicle"
source = root / "ClientSource"
destination = root / "Client" / "BeamMP-Delete-Vehicle-Locator.zip"
destination.parent.mkdir(parents=True, exist_ok=True)
with ZipFile(destination, "w", ZIP_DEFLATED) as archive:
    for path in sorted(source.rglob("*.lua")):
        archive.write(path, path.relative_to(source).as_posix())
print(destination)
