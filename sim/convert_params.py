"""Turn the two YAML parameter files into JSON, so the simulation itself needs only
the standard library. Run this once after editing a YAML file. This script needs
PyYAML (pip install pyyaml); the simulation does not."""
import json
import os

import yaml

here = os.path.dirname(os.path.abspath(__file__))
os.makedirs(os.path.join(here, "params"), exist_ok=True)
for name in ("noise-model", "lab-profile"):
    with open(os.path.join(here, name + ".yaml")) as f:
        data = yaml.safe_load(f)
    with open(os.path.join(here, "params", name + ".json"), "w") as f:
        json.dump(data, f, indent=1, default=str)
    print("wrote params/%s.json" % name)
