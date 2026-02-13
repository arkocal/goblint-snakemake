import re
import json


def extract_patterns_to_json(input_file, output_file, patterns, from_bottom=False):
    """
    Extract values from a file by matching ordered regex patterns and write results to JSON.

    Each key in `patterns` is mapped to the first line matching its corresponding regex.
    Patterns are matched in order, advancing through the file. Once a pattern matches,
    the search for the next pattern begins from that point onward.

    Args:
        input_file (str): Path to the input text file.
        output_file (str): Path to write the resulting JSON file.
        patterns (list[tuple[str, str]] | dict): Ordered key-regexp pairs.
            Use a list of (key, pattern) tuples to guarantee order, or a dict
            (Python 3.7+ preserves insertion order).
        from_bottom (bool): If True, read the file bottom-to-top and match
            patterns in reverse order. Each key is still mapped to the first
            match encountered in the scanning direction.

    Raises:
        ValueError: If a pattern does not match anywhere in the file after its
                    preceding pattern's match position.

    Example:
        patterns = [
            ("version", r"version\\s*=\\s*(\\S+)"),
            ("date",    r"date:\\s*(\\d{4}-\\d{2}-\\d{2})"),
        ]
        extract_patterns_to_json("run.log", "meta.json", patterns)
    """
    # Normalise to list of (key, compiled_pattern) tuples
    if isinstance(patterns, dict):
        pattern_list = [(k, re.compile(v)) for k, v in patterns.items()]
    else:
        pattern_list = [(k, re.compile(v)) for k, v in patterns]

    with open(input_file, "r") as fh:
        lines = fh.readlines()

    if from_bottom:
        lines = list(reversed(lines))
        pattern_list = list(reversed(pattern_list))

    results = {}
    line_index = 0

    for key, regexp in pattern_list:
        matched = False
        while line_index < len(lines):
            m = regexp.search(lines[line_index])
            line_index += 1
            if m:
                # Use the first capture group if present, otherwise the full match
                results[key] = m.group(1) if m.lastindex else m.group(0)
                matched = True
                break
        if not matched:
            raise ValueError(
                f"Pattern for key '{key}' ({regexp.pattern!r}) "
                f"had no match in '{input_file}'"
            )

    with open(output_file, "w") as fh:
        json.dump(results, fh, indent=2)
