# Supabase Product Dataset Import

The dataset currently lives at:

```text
C:\Users\muhdi\Desktop\mobile database\ecommerce products
```

Current structure:

```text
ecommerce products/
  jeans/   199 images
  tshirt/  199 images
```

The flat image folders are imported in sequential 6-image groups. For example,
`jeans/1.jpg` through `jeans/6.jpg` become `Jeans 001`, then `jeans/7.jpg`
through `jeans/12.jpg` become `Jeans 002`.

## 1. Create Tables

Run this file in the Supabase SQL editor:

```text
supabase/products_schema.sql
```

It keeps the existing `products.image_url` cover image and adds
`product_images` for galleries and try-on-specific images. If your existing
`products.id` is a UUID, the import uses `products.catalog_id` as the numeric
ID Flutter already expects.

## 2. Create Storage Bucket

In Supabase Storage, create a public bucket:

```text
products
```

Upload the dataset category folders into that bucket so paths look like:

```text
products/jeans/1.jpg
products/tshirt/1.jpg
```

## 3. Generate CSV Manifests

From the repo root:

```powershell
.\.venv\Scripts\python.exe tools\generate_supabase_product_manifest.py
```

This writes:

```text
supabase/import/products.csv
supabase/import/product_images.csv
```

By default, flat category folders use 6 images per product. To change that:

```powershell
.\.venv\Scripts\python.exe tools\generate_supabase_product_manifest.py --flat-group-size 4
```

Import `products.csv` into `products`, then `product_images.csv` into
`product_images`.

If you already imported the old one-image-per-product catalog, clear the old
catalog before importing this grouped version. Otherwise Supabase will keep the
extra old `catalog_id` rows that are no longer present in the new CSV.

The PowerShell importer can do that replacement for you:

```powershell
.\tools\supabase_import_products.ps1 -SkipStorageUpload -ReplaceCatalog
```

## Terminal Import Option

You can also upload Storage files and import both tables from PowerShell.
Get the service role key from Supabase Dashboard > Project Settings > API, then
set it only in your local terminal:

```powershell
$env:SUPABASE_SERVICE_ROLE_KEY="your-service-role-key"
.\tools\supabase_import_products.ps1
```

Do not put the service role key in Dart code, markdown, git, or chat.

## Notes

- The current image-only dataset has no metadata, so generated names are simple
  values like `Jeans 001` and `T-Shirt 001`.
- With the current flat folders, every 6 sequential images become one product.
- Since there are 199 images per category, the final jeans and t-shirt products
  currently have 1 leftover image each.
- If you later arrange folders like `jeans/product_001/front.jpg` and
  `jeans/product_001/back.jpg`, the same generator will import those files as
  multiple images for one product.
