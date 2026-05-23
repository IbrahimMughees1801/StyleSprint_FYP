import argparse
import csv
import hashlib
from pathlib import Path


IMAGE_SUFFIXES = {".jpg", ".jpeg", ".png", ".webp"}


def natural_file_key(path: Path) -> tuple[str, int | str, str]:
    stem = path.stem
    numeric_stem = int(stem) if stem.isdigit() else stem.lower()
    return (path.parent.name.lower(), numeric_stem, path.name.lower())


def chunked(items: list[Path], size: int) -> list[list[Path]]:
    return [items[index : index + size] for index in range(0, len(items), size)]


def file_hash(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as source:
        for chunk in iter(lambda: source.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def title_from_category(category: str, number: int) -> str:
    names = PRODUCT_NAMES.get(category.lower())
    if names:
        return names[(number - 1) % len(names)]

    clean = category.replace("_", " ").replace("-", " ").strip().title()
    if clean.lower() == "tshirt":
        clean = "T-Shirt"
    return f"{clean} {number:03d}"


def title_from_folder(folder_name: str) -> str:
    return folder_name.replace("_", " ").replace("-", " ").strip().title()


TYPE_PRICE_BANDS = {
    "jeans": [
        ("Straight Fit Jeans", 44.99, 69.99),
        ("Slim Fit Jeans", 49.99, 74.99),
        ("Relaxed Denim Jeans", 39.99, 64.99),
        ("Tapered Jeans", 54.99, 79.99),
        ("Washed Blue Jeans", 42.99, 68.99),
        ("Black Denim Jeans", 46.99, 72.99),
    ],
    "tshirt": [
        ("Essential T-Shirt", 14.99, 24.99),
        ("Graphic T-Shirt", 19.99, 34.99),
        ("Oversized T-Shirt", 22.99, 39.99),
        ("Crew Neck T-Shirt", 16.99, 28.99),
        ("Printed T-Shirt", 18.99, 32.99),
        ("Premium Cotton T-Shirt", 24.99, 44.99),
    ],
}


PRODUCT_NAMES = {
    "jeans": [
        "Indigo Straight Jeans",
        "Stonewash Slim Jeans",
        "Charcoal Tapered Denim",
        "Vintage Blue Relaxed Jeans",
        "Black Everyday Denim",
        "Light Wash Weekend Jeans",
        "Classic Mid-Rise Jeans",
        "Deep Blue Stretch Denim",
        "Clean Cut Straight Jeans",
        "Faded Blue Slim Jeans",
        "Urban Black Jeans",
        "Soft Wash Denim Jeans",
        "Dark Rinse Tapered Jeans",
        "Heritage Blue Jeans",
        "Modern Fit Denim",
        "Washed Grey Jeans",
        "Everyday Comfort Jeans",
        "Premium Indigo Denim",
        "Relaxed Street Jeans",
        "Sharp Fit Black Denim",
        "Blue Ridge Jeans",
        "Metro Slim Denim",
        "Easy Fit Jeans",
        "Raw Look Denim Jeans",
        "Slate Wash Jeans",
        "Classic Bootcut Denim",
        "Weekend Straight Jeans",
        "Deep Charcoal Jeans",
        "Minimal Blue Denim",
        "Signature Fit Jeans",
        "Soft Black Denim",
        "Cloud Wash Jeans",
        "Tailored Denim Jeans",
        "Essential Blue Jeans",
    ],
    "tshirt": [
        "Essential Cotton T-Shirt",
        "Oversized Street Tee",
        "Classic Crew Neck Tee",
        "Minimal Graphic T-Shirt",
        "Soft Jersey T-Shirt",
        "Premium Everyday Tee",
        "Relaxed Fit T-Shirt",
        "Vintage Wash Tee",
        "Clean Logo T-Shirt",
        "Urban Basic Tee",
        "Boxy Fit T-Shirt",
        "Lightweight Summer Tee",
        "Core White T-Shirt",
        "Deep Tone Graphic Tee",
        "Soft Touch Crew Tee",
        "Everyday Black Tee",
        "Weekend Cotton Tee",
        "Modern Fit T-Shirt",
        "Street Print Tee",
        "Washed Crew T-Shirt",
        "Premium Plain Tee",
        "Classic Stripe T-Shirt",
        "Relaxed Graphic Tee",
        "Essential Round Neck Tee",
        "Soft Oversized Tee",
        "Minimal Crew T-Shirt",
        "Clean Fit Cotton Tee",
        "Vintage Graphic T-Shirt",
        "Lightweight Crew Tee",
        "Signature Cotton Tee",
        "Urban Relaxed Tee",
        "Everyday Jersey Tee",
        "Fresh Basic T-Shirt",
        "Comfort Fit Tee",
    ],
}


def product_type_and_price(category: str, number: int) -> tuple[str, str]:
    options = TYPE_PRICE_BANDS.get(
        category.lower(),
        [("Fashion Product", 29.99, 69.99)],
    )
    product_type, low, high = options[(number - 1) % len(options)]
    steps = int(round((high - low) / 5))
    varied = low + (((number * 7) % (steps + 1)) * 5)
    return product_type, f"{varied:.2f}"


def public_url(base_url: str, storage_path: str) -> str:
    normalized_path = storage_path.replace("\\", "/")
    return f"{base_url.rstrip('/')}/{normalized_path}"


def image_kind(path: Path, sort_order: int) -> str:
    name = path.stem.lower()
    if "back" in name:
        return "back"
    if "detail" in name or "close" in name:
        return "detail"
    if "model" in name:
        return "model"
    if "front" in name or "flat" in name or "tryon" in name or sort_order == 0:
        return "tryon"
    return "gallery"


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Generate Supabase product CSVs from an image-only dataset."
    )
    parser.add_argument(
        "--dataset",
        default=r"C:\Users\muhdi\Desktop\mobile database\ecommerce products",
        help="Dataset folder. Expected category subfolders such as jeans/ and tshirt/.",
    )
    parser.add_argument(
        "--out",
        default="supabase/import",
        help="Output folder for products.csv and product_images.csv.",
    )
    parser.add_argument(
        "--public-base-url",
        default=(
            "https://jygqfwpqcwnxdtipokqc.supabase.co"
            "/storage/v1/object/public/products"
        ),
        help="Public Storage URL up to the bucket name.",
    )
    parser.add_argument(
        "--keep-duplicates",
        action="store_true",
        help="Deprecated; duplicates are kept by default so 6-image product groups stay intact.",
    )
    parser.add_argument(
        "--skip-duplicates",
        action="store_true",
        help="Skip exact duplicate image files after product groups are formed.",
    )
    parser.add_argument(
        "--flat-group-size",
        type=int,
        default=6,
        help=(
            "For flat category folders, group this many sequential images as "
            "one product. Use 1 for one product per image."
        ),
    )
    args = parser.parse_args()

    if args.flat_group_size < 1:
        raise SystemExit("--flat-group-size must be at least 1")

    dataset = Path(args.dataset)
    out_dir = Path(args.out)
    out_dir.mkdir(parents=True, exist_ok=True)

    if not dataset.exists():
        raise SystemExit(f"Dataset folder does not exist: {dataset}")

    files = sorted(
        (
            path
            for path in dataset.rglob("*")
            if path.is_file() and path.suffix.lower() in IMAGE_SUFFIXES
        ),
        key=natural_file_key,
    )

    groups: dict[str, dict[str, object]] = {}
    files_by_category: dict[str, list[Path]] = {}
    for path in files:
        relative_path = path.relative_to(dataset)
        parts = relative_path.parts
        if len(parts) < 2:
            continue
        files_by_category.setdefault(parts[0], []).append(path)

    for category, category_files in files_by_category.items():
        nested_groups: dict[str, list[Path]] = {}
        flat_files: list[Path] = []

        for path in sorted(category_files, key=natural_file_key):
            parts = path.relative_to(dataset).parts
            if len(parts) > 2:
                group_key = "/".join(parts[:-1])
                nested_groups.setdefault(group_key, []).append(path)
            else:
                flat_files.append(path)

        for group_key, grouped_paths in nested_groups.items():
            groups[group_key] = {
                "category": category,
                "folder_name": Path(group_key).name,
                "images": sorted(grouped_paths, key=natural_file_key),
            }

        for group_number, grouped_paths in enumerate(
            chunked(sorted(flat_files, key=natural_file_key), args.flat_group_size),
            start=1,
        ):
            group_key = f"{category}/product_{group_number:03d}"
            groups[group_key] = {
                "category": category,
                "folder_name": "",
                "images": grouped_paths,
            }

    skipped_duplicates = []

    if args.skip_duplicates and not args.keep_duplicates:
        seen_hashes: set[str] = set()
        for group in groups.values():
            kept_images = []
            images = group["images"]
            assert isinstance(images, list)

            for path in images:
                digest = file_hash(path)
                if digest in seen_hashes:
                    skipped_duplicates.append(path)
                    continue

                seen_hashes.add(digest)
                kept_images.append(path)

            group["images"] = kept_images

    products = []
    product_images = []
    product_id = 1
    category_counts: dict[str, int] = {}

    for group in groups.values():
        category = str(group["category"])
        category_counts[category] = category_counts.get(category, 0) + 1
        number = category_counts[category]
        images = sorted(group["images"], key=natural_file_key)
        folder_name = str(group["folder_name"])
        first_image = images[0]
        first_storage_path = first_image.relative_to(dataset).as_posix()
        image_url = public_url(args.public_base_url, first_storage_path)
        name = (
            title_from_folder(folder_name)
            if folder_name
            else title_from_category(category, number)
        )
        product_type, price = product_type_and_price(category, number)

        products.append(
            {
                "id": product_id,
                "name": name,
                "image_url": image_url,
                "brand": "StyleSprint",
                "category": category,
                "product_type": product_type,
                "price": price,
                "description": (
                    f"Curated {product_type.lower()} from the StyleSprint "
                    "catalog, ready for browsing and virtual try-on demos."
                ),
                "tryon_ready": "true",
            }
        )

        for sort_order, image_path in enumerate(images):
            storage_path = image_path.relative_to(dataset).as_posix()
            product_images.append(
                {
                    "product_id": product_id,
                    "image_url": public_url(args.public_base_url, storage_path),
                    "storage_path": storage_path,
                    "image_kind": image_kind(image_path, sort_order),
                    "sort_order": sort_order,
                }
            )
        product_id += 1

    products_path = out_dir / "products.csv"
    images_path = out_dir / "product_images.csv"

    if not products:
        raise SystemExit(f"No images found under: {dataset}")

    with products_path.open("w", newline="", encoding="utf-8") as target:
        writer = csv.DictWriter(target, fieldnames=list(products[0].keys()))
        writer.writeheader()
        writer.writerows(products)

    with images_path.open("w", newline="", encoding="utf-8") as target:
        writer = csv.DictWriter(target, fieldnames=list(product_images[0].keys()))
        writer.writeheader()
        writer.writerows(product_images)

    print(f"Scanned images: {len(files)}")
    print(f"Flat folder group size: {args.flat_group_size}")
    print(f"Products written: {len(products)}")
    print(f"Duplicate images skipped: {len(skipped_duplicates)}")
    print(f"Wrote: {products_path}")
    print(f"Wrote: {images_path}")
    print()
    print("Upload the image folders to Supabase Storage bucket 'products'")
    print("with the same paths used in storage_path, then import both CSV files.")


if __name__ == "__main__":
    main()
