from helpers import *

SAMPLES = config["samples"]

rule all:
	input: expand("json/{sample}.json", sample=SAMPLES)

rule compute:
	input: 
		"data/{sample}.txt"
	output:
		"out/{sample}.txt"
	shell:
		"python example_tool.py -i {input} -o {output}"

rule extract_json:
	input:
		out="out/{sample}.txt"
	output:
		"json/{sample}.json"
	run:
		extract_patterns_to_json(
			input[0], output[0],
			patterns=[
				("sum",  r"Sum of numbers:\s+(\S+)"),
				("prod",  r"Product of numbers:\s+(\S+)"),
			]
		)

