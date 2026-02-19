from pathlib import Path

from helpers import *
import pandas as pd


BENCHMARK_DIR = config["benchmark_dir"]
BENCH = config["benchmarks"]
IDS = BENCH.keys()

GOBLINT_CONFIGS = config["configs"]
CONFIG_IDS = GOBLINT_CONFIGS.keys()

GOBLINT = config["goblint"]
GOBLINT_DIR = config["goblint_dir"]

rule all:
	input: "out/summary.csv"

rule aggregate_csv:
    input:
        expand("out/rows/{id}_{conf}.csv", id=IDS, conf=CONFIG_IDS)
    output:
        "out/summary.csv"
    run:
        pd.concat([pd.read_csv(f) for f in input], ignore_index=True)\
          .to_csv(output[0], index=False)

rule json_to_row:
    input:
        "out/json/{id}_{conf}.json"
    output:
        "out/rows/{id}_{conf}.csv"
    run:
        df = pd.read_json(input[0], typ="series", convert_dates=False).to_frame().T
        df["id"], df["conf"] = wildcards.id, wildcards.conf  # wildcards available here!
        df.to_csv(output[0], index=False)

rule extract_json:
        input:
                out="out/{id}_{conf}.out"
        output:
                "out/json/{id}_{conf}.json"
        run:
                extract_patterns_to_json(
                        input[0], output[0],
                        patterns=[
                                ("solver_start",  r"Solver start:\s*(\d+)"),
                                ("solver_end",  r"Solver end:\s*(\d+)"),
                        ]
                )
rule compute:
	input: 
		lambda wc: Path(BENCHMARK_DIR) / BENCH[wc.id]
	output:
		"out/{id}_{conf}.out"
	benchmark:
		"out/benchmarks/{id}_{conf}.txt"
	wrapper:
		"file:wrappers/goblint"
