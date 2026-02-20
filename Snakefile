from pathlib import Path
from filelock import FileLock

import pandas as pd
import json


BENCHMARK_DIR = config["benchmark_dir"]
BENCH = config["benchmarks"]
IDS = BENCH.keys()

TIMEOUT = config["timeout"]

GOBLINT_CONFIGS = config["configs"]
CONFIG_IDS = GOBLINT_CONFIGS.keys()

GOBLINT = config["goblint"]
GOBLINT_DIR = config["goblint_dir"]

SUMMARY_INCOMPLETE = "out/summary_incomplete.csv"

rule all:
	input: "out/summary.csv"

rule aggregate_incomplete_csv:
    input:
        lambda wildcards: [
            f for f in expand("out/rows/{id}_{conf}.csv", id=IDS, conf=CONFIG_IDS)
            if Path(f).exists()
        ]
    output:
        "out/summary_incomplete.csv"
    run:
        pd.concat([pd.read_csv(f) for f in input], ignore_index=True)\
          .to_csv(output[0], index=False)

rule aggregate_csv:
    input:
        expand("out/rows/{id}_{conf}.csv", id=IDS, conf=CONFIG_IDS)
    output:
        "out/summary.csv"
    run:
        pd.concat([pd.read_csv(f) for f in input], ignore_index=True)\
          .to_csv(output[0], index=False)

rule extract_csv:
    input:
        ["out/{id}_{conf}.out", "out/{id}_{conf}_status.json"]
    output:
        row_csv="out/rows/{id}_{conf}.csv"
    run:
        # --- extract patterns ---
        def extract_patterns(input_file, patterns):
            matches = {pattern[0]: None for pattern in patterns}
            remaining = patterns.copy()
            with open(input_file, "r") as f:
                for line in f:
                    for pattern in remaining[:]:
                        match = re.search(pattern[1], line)
                        if match:
                            matches[pattern[0]] = match.group(1)
                            remaining.remove(pattern)
            return matches

        with open(input[1]) as f:
            status = json.load(f)
        details = extract_patterns(input[0], patterns=[
            ("solver_start",  r"Solver start:\s*(\d+)"),
            ("solver_end",  r"Solver end:\s*(\d+)"),
        ])
        status.update(details)
        status["id"] = wildcards.id
        status["conf"] = wildcards.conf

        # --- write per-row CSV ---
        df = pd.DataFrame([status])
        df.to_csv(output.row_csv, index=False)

        # --- thread-safe summary update ---
        with FileLock(".summary_lock"):
            try:
                summary = pd.read_csv(SUMMARY_INCOMPLETE)
                summary = summary[~((summary["id"]==wildcards.id) & (summary["conf"]==wildcards.conf))]
            except (FileNotFoundError, pd.errors.EmptyDataError):
                summary = pd.DataFrame()

            summary = pd.concat([summary, df], ignore_index=True)
            summary.to_csv(SUMMARY_INCOMPLETE, index=False)

rule compute:
    input: 
        lambda wc: Path(BENCHMARK_DIR) / BENCH[wc.id]
    output:
        ["out/{id}_{conf}.out", "out/{id}_{conf}_status.json"]
    params:
        timeout=TIMEOUT
    benchmark:
        "out/benchmarks/{id}_{conf}.txt"
    wrapper:
        "file:wrappers/goblint"

onstart:
    # Create fresh summary_incomplete.csv
    path = Path("out/summary_incomplete.csv")
    path.unlink(missing_ok=True)
    path.parent.mkdir(parents=True, exist_ok=True)
    path.touch()
