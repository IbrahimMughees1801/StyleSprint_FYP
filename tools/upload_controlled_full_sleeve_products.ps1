param(
  [string]$SupabaseUrl = "https://jygqfwpqcwnxdtipokqc.supabase.co"
)

$ErrorActionPreference = "Stop"

if (-not $env:SUPABASE_SERVICE_ROLE_KEY) {
  throw "Set SUPABASE_SERVICE_ROLE_KEY in this terminal first. Do not put it in the repo."
}

$products = @(
  @{
    CatalogId = 7001
    Name = "Controlled Black Satin Wrap Top"
    StoragePath = "controlled/full_sleeve/black_satin_wrap_top_10165_00.jpg"
    ImagePath = "backend\datasets\dci_finetune_tiny\test\cloth\10165_00.jpg"
    ProductType = "Wrap Top"
    Description = "Plain black full-sleeve wrap top selected from the local try-on dataset for controlled evaluation demos."
    Price = 39.99
  },
  @{
    CatalogId = 7002
    Name = "Controlled Red Long Sleeve Top"
    StoragePath = "controlled/full_sleeve/red_long_sleeve_top_06789_00.jpg"
    ImagePath = "backend\datasets\dci_finetune_tiny\train\cloth\06789_00.jpg"
    ProductType = "Long Sleeve Top"
    Description = "Plain red full-sleeve top selected from the local try-on dataset for controlled evaluation demos."
    Price = 34.99
  },
  @{
    CatalogId = 7003
    Name = "Controlled Black Button Long Sleeve Top"
    StoragePath = "controlled/full_sleeve/black_button_long_sleeve_top_13532_00.jpg"
    ImagePath = "backend\datasets\dci_finetune_tiny\train\cloth\13532_00.jpg"
    ProductType = "Long Sleeve Top"
    Description = "Plain black full-sleeve button top selected from the local try-on dataset for controlled evaluation demos."
    Price = 36.99
  },
  @{
    CatalogId = 7004
    Name = "Controlled Green Long Sleeve Tee"
    StoragePath = "controlled/full_sleeve/green_long_sleeve_tee_tshirt_119_0061.jpg"
    ImagePath = "backend\datasets\yolo_product_finetune\images\val\tshirt_119_0061.jpg"
    ProductType = "Long Sleeve Tee"
    Description = "Plain green full-sleeve tee selected from the local product dataset for controlled evaluation demos."
    Price = 29.99
  },
  @{
    CatalogId = 7005
    Name = "Controlled Navy Long Sleeve Tee"
    StoragePath = "controlled/full_sleeve/navy_long_sleeve_tee_tshirt_94_0107.jpg"
    ImagePath = "backend\datasets\yolo_product_finetune\images\train\tshirt_94_0107.jpg"
    ProductType = "Long Sleeve Tee"
    Description = "Plain navy full-sleeve tee selected from the local product dataset for controlled evaluation demos."
    Price = 29.99
  },
  @{
    CatalogId = 7006
    Name = "Controlled White Long Sleeve Tee"
    StoragePath = "controlled/full_sleeve/white_long_sleeve_tee_tshirt_95_0136.jpg"
    ImagePath = "backend\datasets\yolo_product_finetune\images\train\tshirt_95_0136.jpg"
    ProductType = "Long Sleeve Tee"
    Description = "Plain white full-sleeve tee selected from the local product dataset for controlled evaluation demos."
    Price = 29.99
  }
)

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

$uploaded = @()

foreach ($item in $products) {
  if (-not (Test-Path $item.ImagePath)) {
    throw "Image file not found: $($item.ImagePath)"
  }

  $publicImageUrl = "$SupabaseUrl/storage/v1/object/public/products/$($item.StoragePath)"

  Write-Host "Uploading image to products/$($item.StoragePath) ..."
  Invoke-RestMethod `
    -Method Post `
    -Uri "$SupabaseUrl/storage/v1/object/products/$($item.StoragePath)" `
    -Headers $storageHeaders `
    -InFile $item.ImagePath | Out-Null

  $encodedName = [uri]::EscapeDataString($item.Name)
  $existingProducts = @(
    Invoke-RestMethod `
      -Uri "$SupabaseUrl/rest/v1/products?select=*&or=(catalog_id.eq.$($item.CatalogId),name.eq.$encodedName)" `
      -Headers $serviceHeaders
  ) | Where-Object { $_ -and $_.id }

  $productBody = @{
    catalog_id = $item.CatalogId
    name = $item.Name
    image_url = $publicImageUrl
    brand = "StyleSprint"
    category = "tshirt"
    price = $item.Price
    description = $item.Description
    tryon_ready = $true
    product_type = $item.ProductType
  } | ConvertTo-Json

  if ($existingProducts.Count -gt 0) {
    $productId = $existingProducts[0].id
    Write-Host "Updating existing product $($item.Name) ($productId) ..."
    $updated = Invoke-RestMethod `
      -Method Patch `
      -Uri "$SupabaseUrl/rest/v1/products?id=eq.$productId" `
      -Headers $jsonHeaders `
      -Body $productBody
    $product = $updated[0]
  } else {
    Write-Host "Creating product $($item.Name) ..."
    $created = Invoke-RestMethod `
      -Method Post `
      -Uri "$SupabaseUrl/rest/v1/products" `
      -Headers $jsonHeaders `
      -Body $productBody
    $product = $created[0]
    $productId = $product.id
  }

  $existingImages = @(
    Invoke-RestMethod `
      -Uri "$SupabaseUrl/rest/v1/product_images?select=*&product_id=eq.$productId&image_kind=eq.tryon&sort_order=eq.0" `
      -Headers $serviceHeaders
  ) | Where-Object { $_ -and $_.id }

  $imageBody = @{
    product_id = $productId
    image_url = $publicImageUrl
    storage_path = $item.StoragePath
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

  $uploaded += [pscustomobject]@{
    catalog_id = $item.CatalogId
    name = $item.Name
    image_url = $publicImageUrl
  }

  Write-Host ""
}

Write-Host "Uploaded controlled full-sleeve products:"
$uploaded | Format-Table -AutoSize
