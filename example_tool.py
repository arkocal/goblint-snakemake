import argparse
from pathlib import Path
from math import prod


def parse_args():
    parser = argparse.ArgumentParser(
        description="Read integers from an input file and write their sum and product to an output file."
    )
    parser.add_argument(
        "-i", "--input",
        type=Path,
        required=True,
        help="Path to the input file containing one integer per line."
    )
    parser.add_argument(
        "-o", "--output",
        type=Path,
        required=False,
        help="Path to the output file where results will be written."
    )
    return parser.parse_args()


def read_integers(path: Path):
    with path.open("r", encoding="utf-8") as f:
        return [int(line.strip()) for line in f if line.strip()]


def main():
    args = parse_args()

    numbers = read_integers(args.input)
    total = sum(numbers)
    product = prod(numbers) if numbers else 0

    output_text = f"Sum of numbers: {total}\nProduct of numbers: {product}\n"

    if args.output:
        args.output.write_text(output_text, encoding="utf-8")
    else:
        print(output_text)


if __name__ == "__main__":
    main()
