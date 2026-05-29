from __future__ import annotations

import argparse
import json
import sys

import api_server


def main() -> int:
    parser = argparse.ArgumentParser(description="Run one virtual try-on pipeline call from local files.")
    parser.add_argument("--person", required=True)
    parser.add_argument("--cloth", required=True)
    parser.add_argument("--session-id", required=True)
    parser.add_argument("--product-category", default=None)
    parser.add_argument("--product-type", default=None)
    args = parser.parse_args()

    result = api_server.run_tryon_pipeline(
        args.person,
        args.cloth,
        args.session_id,
        product_category=args.product_category,
        product_type=args.product_type,
    )
    print(json.dumps(result, indent=2, default=str))
    return 0 if result.get("success") else 1


if __name__ == "__main__":
    raise SystemExit(main())
