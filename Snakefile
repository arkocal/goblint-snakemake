from itertools import combinations
from pathlib import Path
from filelock import FileLock

import pandas as pd
import json


BENCHMARK_DIR = config["benchmark_dir"]
BENCH = config["benchmarks"]
IDS = BENCH.keys()

SOLVERS = config["solvers"]

TIMEOUT = config["timeout"]

GOBLINT_CONFIGS = config["configs"]
CONFIG_IDS = GOBLINT_CONFIGS.keys()

GOBLINT = config["goblint"]
GOBLINT_DIR = config["goblint_dir"]

SUMMARY_INCOMPLETE = "out/summary_incomplete.csv"

rule all:
	input: "out/summary.csv"
#
# rule aggregate_csv:
#     input:
#         expand("out/rows/{id}_{conf}.csv", id=IDS, conf=CONFIG_IDS)
#     output:
#         "out/summary.csv"
#     run:
#         pd.concat([pd.read_csv(f) for f in input], ignore_index=True)\
#           .to_csv(output[0], index=False)
#
# rule extract_csv:
#     input:
#         ["out/{id}_{conf}.out", "out/{id}_{conf}_status.json"]
#     output:
#         row_csv="out/rows/{id}_{conf}.csv"
#     run:
#         # --- extract patterns ---
#         def extract_patterns(input_file, patterns):
#             matches = {pattern[0]: None for pattern in patterns}
#             remaining = patterns.copy()
#             with open(input_file, "r") as f:
#                 for line in f:
#                     for pattern in remaining[:]:
#                         match = re.search(pattern[1], line)
#                         if match:
#                             matches[pattern[0]] = match.group(1)
#                             remaining.remove(pattern)
#             return matches
#
#         with open(input[1]) as f:
#             status = json.load(f)
#         details = extract_patterns(input[0], patterns=[
#             ("solver_start",  r"Solver start:\s*(\d+)"),
#             ("solver_end",  r"Solver end:\s*(\d+)"),
#         ])
#         status.update(details)
#         status["id"] = wildcards.id
#         status["conf"] = wildcards.conf
#
#         # --- write per-row CSV ---
#         df = pd.DataFrame([status])
#         df.to_csv(output.row_csv, index=False)
#
#         # --- thread-safe summary update ---
#         with FileLock(".summary_lock"):
#             try:
#                 summary = pd.read_csv(SUMMARY_INCOMPLETE)
#                 summary = summary[~((summary["id"]==wildcards.id) & (summary["conf"]==wildcards.conf))]
#             except (FileNotFoundError, pd.errors.EmptyDataError):
#                 summary = pd.DataFrame()
#
#             summary = pd.concat([summary, df], ignore_index=True)
#             summary.to_csv(SUMMARY_INCOMPLETE, index=False)

rule aggregate_csv:
    input:
        # s1 and s2 are from solvers
        # expand only to those, where s1 and s2 are different, to avoid duplicates
        # also, ensure the index of s1 in SOLVERS is less than the index of s2, to avoid reversed pairs
        # expand("out/rows/{id}_{s1}_{s2}.csv", id=IDS, 
        expand("out/rows/{id}_{pair}.csv", id=IDS, pair=[f"{s1}-{s2}" for s1, s2 in combinations(SOLVERS, 2)])
    output:
        "out/summary.csv"
    run:
        pd.concat([pd.read_csv(f) for f in input], ignore_index=True)\
          .to_csv(output[0], index=False)

rule extract_csv:
    input: 
        "out/{id}_{pair}.out"
    output:
        row_csv="out/rows/{id}_{pair}.csv"
    run:
        # --- extract patterns ---
        def extract_patterns(input_file, patterns):
            matches = {pattern[0]: None for pattern in patterns}
            remaining = patterns.copy()
            with open(input_file, "r") as f:
                for line in f:
                    matched_in_line = []
                    for pattern in remaining[:]:
                        if pattern[1] in matched_in_line:
                            continue
                        match = re.search(pattern[1], line)
                        if match:
                            matched_in_line.append(pattern[1])
                            matches[pattern[0]] = match.group(1)
                            remaining.remove(pattern)
            return matches

        json_file = f"out/{wildcards.id}_{wildcards.pair}_status.json"
        with open(json_file) as f:
            status = json.load(f)
        details = extract_patterns(input[0], patterns=[
            ("solver_start_1",  r"Solver start:\s*(\d+)"),
            ("solver_end_1",  r"Solver end:\s*(\d+)"),
            ("solver_start_2",  r"Solver start:\s*(\d+)"),
            ("solver_end_2",  r"Solver end:\s*(\d+)"),
            ("globals_equal",        r"globals:.*\bequal\s*=\s*(\d+)"),
            ("globals_left",         r"globals:.*\bleft\s*=\s*(\d+)"),
            ("globals_right",        r"globals:.*\bright\s*=\s*(\d+)"),
            ("globals_incomparable", r"globals:.*\bincomparable\s*=\s*(\d+)"),
            ("locals_equal",         r"locals:.*\bequal\s*=\s*(\d+)"),
            ("locals_left",          r"locals:.*\bleft\s*=\s*(\d+)"),
            ("locals_right",         r"locals:.*\bright\s*=\s*(\d+)"),
            ("locals_incomparable",  r"locals:.*\bincomparable\s*=\s*(\d+)"),
        ])
        status.update(details)
        status["id"] = wildcards.id
        status["pair"] = wildcards.pair

        # --- write per-row CSV ---
        df = pd.DataFrame([status])
        df.to_csv(output.row_csv, index=False)

         # --- thread-safe summary update ---
        with FileLock(".summary_lock"):
            try:
                summary = pd.read_csv(SUMMARY_INCOMPLETE)
                summary = summary[~((summary["id"]==wildcards.id) & (summary["pair"]==wildcards.pair))]
            except (FileNotFoundError, pd.errors.EmptyDataError):
                summary = pd.DataFrame()

            summary = pd.concat([summary, df], ignore_index=True)
            summary.to_csv(SUMMARY_INCOMPLETE, index=False)


rule compare:
    input: 
        lambda wc: Path(BENCHMARK_DIR) / BENCH[wc.id]
    output:
        ["out/{id}_{pair}.out", "out/{id}_{pair}_status.json"]
    params:
        timeout=TIMEOUT,
        config=lambda wc: "--solver " + wc.pair.split("-")[0] + " --comparesolver " + wc.pair.split("-")[1]
    benchmark:
        "out/benchmarks/{id}_{pair}.txt"
    wrapper:
        "file:wrappers/goblint"


# rule compute:
#     input: 
#         lambda wc: Path(BENCHMARK_DIR) / BENCH[wc.id]
#     output:
#         ["out/{id}_{conf}.out", "out/{id}_{conf}_status.json"]
#     params:
#         timeout=TIMEOUT,
#         config=lambda wc: GOBLINT_CONFIGS[wc.conf]
#     benchmark:
#         "out/benchmarks/{id}_{conf}.txt"
#     wrapper:
#         "file:wrappers/goblint"

onstart:
    # Create fresh summary_incomplete.csv
    path = Path("out/summary_incomplete.csv")
    path.unlink(missing_ok=True)
    path.parent.mkdir(parents=True, exist_ok=True)
    path.touch()
