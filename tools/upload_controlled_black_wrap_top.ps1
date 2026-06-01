param(
  [string]$SupabaseUrl = "https://jygqfwpqcwnxdtipokqc.supabase.co",
  [int]$CatalogId = 69,
  [string]$ProductName = "Controlled Black Wrap Top",
  [string]$StoragePath = "controlled/black_wrap_top_fresh_yolo_20260601_02.jpg",
  [string]$ImagePath = "backend\temp_uploads\cloth\fresh_yolo_20260601_02_cloth.jpg"
)

$ErrorActionPreference = "Stop"

if (-not $env:SUPABASE_SERVICE_ROLE_KEY) {
  throw "Set SUPABASE_SERVICE_ROLE_KEY in this terminal first. Do not put it in the repo."
}

if (-not (Test-Path $ImagePath)) {
  throw "Image file not found: $ImagePath"
}

$serviceHeaders = @{
  apikey = $env:SUPABASE_SERVICE_ROLE_KEY
  Authorization = "Bearer $env:SUPABASE_SERVICE_ROLE_KEY"
}

$jsonHeaders = $serviceHeaders.Clone()
$jsonHeaders["Content-Type"] = "application/json"
$jsonHeaders["Prefer"] = "return=representation"

$storageHeaders = $serviceHeaders.Clone()
$storageHeaders["Content-Type"] = "image/jpeg"
$storageHeaders["x-upsert"] = "true"

$publicImageUrl = "$SupabaseUrl/storage/v1/object/public/products/$StoragePath"

Write-Host "Uploading image to products/$StoragePath ..."
Invoke-RestMethod `
  -Method Post `
  -Uri "$SupabaseUrl/storage/v1/object/products/$StoragePath" `
  -Headers $storageHeaders `
  -InFile $ImagePath | Out-Null

$encodedName = [uri]::EscapeDataString($ProductName)
$existingProducts = Invoke-RestMethod `
  -Uri "$SupabaseUrl/rest/v1/products?select=*&or=(catalog_id.eq.$CatalogId,name.eq.$encodedName)" `
  -Headers $serviceHeaders

$productBody = @{
  catalog_id = $CatalogId
  name = $ProductName
  image_url = $publicImageUrl
  brand = "StyleSprint"
  category = "tshirt"
  price = 39.99
  description = "Controlled black wrap top used for evaluation try-on demos."
  tryon_ready = $true
  product_type = "Wrap Top"
} | ConvertTo-Json

if ($existingProducts.Count -gt 0) {
  $productId = $existingProducts[0].id
  Write-Host "Updating existing product $ProductName ($productId) ..."
  $updated = Invoke-RestMethod `
    -Method Patch `
    -Uri "$SupabaseUrl/rest/v1/products?id=eq.$productId" `
    -Headers $jsonHeaders `
    -Body $productBody
  $product = $updated[0]
} else {
  Write-Host "Creating product $ProductName ..."
  $created = Invoke-RestMethod `
    -Method Post `
    -Uri "$SupabaseUrl/rest/v1/products" `
    -Headers $jsonHeaders `
    -Body $productBody
  $product = $created[0]
  $productId = $product.id
}

$existingImages = Invoke-RestMethod `
  -Uri "$SupabaseUrl/rest/v1/product_images?select=*&product_id=eq.$productId&image_kind=eq.tryon&sort_order=eq.0" `
  -Headers $serviceHeaders

$imageBody = @{
  product_id = $productId
  image_url = $publicImageUrl
  storage_path = $StoragePath
  image_kind = "tryon"
  sort_order = 0
} | ConvertTo-Json

if ($existingImages.Count -gt 0) {
  $imageId = $existingImages[0].id
  Write-Host "Updating product_images row $imageId ..."
  Invoke-RestMethod `
    -Method Patch `
    -Uri "$SupabaseUrl/rest/v1/product_images?id=eq.$imageId" `
    -Headers $jsonHeaders `
    -Body $imageBody | Out-Null
} else {
  Write-Host "Creating product_images tryon row ..."
  Invoke-RestMethod `
    -Method Post `
    -Uri "$SupabaseUrl/rest/v1/product_images" `
    -Headers $jsonHeaders `
    -Body $imageBody | Out-Null
}

Write-Host ""
Write-Host "Uploaded controlled product:"
Write-Host "  catalog_id: $CatalogId"
Write-Host "  name: $ProductName"
Write-Host "  image_url: $publicImageUrl"
