import os

for path in ["scripts/terrain.gd", "scripts/siege_environment.gd"]:
    if os.path.exists(path):
        with open(path, "rb") as f:
            data = f.read()
        data_lf = data.replace(b"\r\n", b"\n")
        with open(path, "wb") as f:
            f.write(data_lf)
        print(f"Converted {path} to LF: {len(data)} -> {len(data_lf)} bytes")
