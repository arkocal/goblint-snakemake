import json
import subprocess
from pathlib import Path
import tempfile

GNU_TIMEOUT_RETURN_CODE = 124

sm = globals()["snakemake"]

input_file = Path(sm.input[0])
output_path = Path(sm.output[0])
status_output_path = Path(sm.output[1])

goblint_executable = (sm.config["goblint_dir"] 
                      + "/" + sm.config["goblint"]
                      ) 

goblint_config = sm.params.get("config", "")
timeout = sm.params.get("timeout", None)

with tempfile.TemporaryDirectory() as tmpdir:
    had_timeout = False
    try:
        with open(output_path, "w") as output_file:
            result = subprocess.run([
                goblint_executable,
                *goblint_config.split(),
                "--goblint-dir", tmpdir,
                input_file
                ],
                stdout=output_file,
                stderr=output_file,
                timeout=timeout
            )
    except subprocess.TimeoutExpired:
        had_timeout = True

    status = {
        "returncode": result.returncode if not had_timeout else GNU_TIMEOUT_RETURN_CODE,
        "timeout": had_timeout
    }

with open(status_output_path, "w") as status_output_file:
    json.dump(status, status_output_file)



