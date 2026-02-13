SAMPLES = config["samples"]

rule all:
	input: expand("out/{sample}.txt", sample=SAMPLES)

rule compute:
	input: 
		"data/{sample}.txt"
	output:
		"out/{sample}.txt"
	shell:
		"python example_tool.py -i {input} -o {output}"
