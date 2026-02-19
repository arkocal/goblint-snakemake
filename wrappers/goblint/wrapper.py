import subprocess
from pathlib import Path
import tempfile

sm = globals()["snakemake"]

input_file = Path(sm.input[0])
output_path = Path(sm.output[0])

goblint_executable = (sm.config["goblint_dir"] 
                      + "/" + sm.config["goblint"]
                      ) 

goblint_config = sm.config["configs"][sm.wildcards.conf]


print([
    goblint_executable,
    *goblint_config.split(),
    input_file
    ],
)

with tempfile.TemporaryDirectory() as tmpdir:
    with open(output_path, "w") as output_file:
        subprocess.run([
            goblint_executable,
            *goblint_config.split(),
            "--goblint-dir", tmpdir,
            input_file
            ],
            stdout=output_file,
            stderr=output_file
        )


