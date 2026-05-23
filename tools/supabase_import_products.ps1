param(
  [string]$Dataset = "C:\Users\muhdi\Desktop\mobile database\ecommerce products",
  [string]$CsvDir = "supabase\import",
  [string]$SupabaseUrl = "https://jygqfwpqcwnxdtipokqc.supabase.co",
  [string]$Bucket = "products",
  [switch]$SkipStorageUpload,
  [switch]$SkipDatabaseImport,
  [switch]$ReplaceCatalog
)

$ErrorActionPreference = "Stop"

if (-not $env:SUPABASE_SERVICE_ROLE_KEY) {
  throw "Set SUPABASE_SERVICE_ROLE_KEY in this terminal first. Do not put it in the repo."
}

function Get-ContentType {
  param([string]$Path)

  switch ([IO.Path]::GetExtension($Path).ToLowerInvariant()) {
    ".jpg" { "image/jpeg" }
    ".jpeg" { "image/jpeg" }
    ".png" { "image/png" }
    ".webp" { "image/webp" }
    default { "application/octet-stream" }
  }
}

function Get-RelativePath {
  param(
    [string]$Root,
    [string]$Path
  )

  $rootPath = [IO.Path]::GetFullPath($Root)
  if (-not $rootPath.EndsWith([IO.Path]::DirectorySeparatorChar)) {
    $rootPath += [IO.Path]::DirectorySeparatorChar
  }

  $rootUri = [Uri]$rootPath
  $pathUri = [Uri][IO.Path]::GetFullPath($Path)
  return [Uri]::UnescapeDataString($rootUri.MakeRelativeUri($pathUri).ToString())
}

function Invoke-SupabaseJson {
  param(
    [string]$Uri,
    [string]$Method,
    [object]$Body
  )

  $headers = @{
    apikey = $env:SUPABASE_SERVICE_ROLE_KEY
    Authorization = "Bearer $env:SUPABASE_SERVICE_ROLE_KEY"
    Prefer = "resolution=merge-duplicates,return=minimal"
  }

  $json = $Body | ConvertTo-Json -Depth 8
  try {
    Invoke-RestMethod -Uri $Uri -Method $Method -Headers $headers -ContentType "application/json" -Body $json | Out-Null
  } catch {
    $response = $_.Exception.Response
    if ($response -and $response.GetResponseStream()) {
      $reader = New-Object IO.StreamReader($response.GetResponseStream())
      $body = $reader.ReadToEnd()
      Write-Host "Supabase error response:" -ForegroundColor Red
      Write-Host $body -ForegroundColor Red
    }
    throw
  }
}

function Invoke-SupabaseDelete {
  param([string]$Uri)

  $headers = @{
    apikey = $env:SUPABASE_SERVICE_ROLE_KEY
    Authorization = "Bearer $env:SUPABASE_SERVICE_ROLE_KEY"
    Prefer = "return=minimal"
  }

  try {
    Invoke-RestMethod -Uri $Uri -Method Delete -Headers $headers | Out-Null
  } catch {
    $response = $_.Exception.Response
    if ($response -and $response.GetResponseStream()) {
      $reader = New-Object IO.StreamReader($response.GetResponseStream())
      $body = $reader.ReadToEnd()
      Write-Host "Supabase error response:" -ForegroundColor Red
      Write-Host $body -ForegroundColor Red
    }
    throw
  }
}

if (-not $SkipStorageUpload) {
  $datasetRoot = (Resolve-Path -LiteralPath $Dataset).Path
  $imageFiles = Get-ChildItem -LiteralPath $datasetRoot -Recurse -File |
    Where-Object { $_.Extension.ToLowerInvariant() -in @(".jpg", ".jpeg", ".png", ".webp") }

  Write-Host "Uploading $($imageFiles.Count) images to bucket '$Bucket'..."

  foreach ($file in $imageFiles) {
    $relativePath = (Get-RelativePath -Root $datasetRoot -Path $file.FullName).Replace("\", "/")
    $encodedPath = ($relativePath -split "/" | ForEach-Object { [uri]::EscapeDataString($_) }) -join "/"
    $uri = "$SupabaseUrl/storage/v1/object/$Bucket/$encodedPath"
    $bytes = [IO.File]::ReadAllBytes($file.FullName)
    $headers = @{
      apikey = $env:SUPABASE_SERVICE_ROLE_KEY
      Authorization = "Bearer $env:SUPABASE_SERVICE_ROLE_KEY"
      "x-upsert" = "true"
    }

    Invoke-RestMethod -Uri $uri -Method Post -Headers $headers -ContentType (Get-ContentType $file.FullName) -Body $bytes | Out-Null
  }
}

if (-not $SkipDatabaseImport) {
  $productsPath = Join-Path $CsvDir "products.csv"
  $imagesPath = Join-Path $CsvDir "product_images.csv"

  $products = Import-Csv $productsPath | ForEach-Object {
    @{
      catalog_id = [int64]$_.id
      name = $_.name
      image_url = $_.image_url
      brand = $_.brand
      category = $_.category
      product_type = $_.product_type
      price = [decimal]$_.price
      description = $_.description
      tryon_ready = [bool]::Parse($_.tryon_ready)
    }
  }

  $rawProductImages = Import-Csv $imagesPath

  if ($ReplaceCatalog) {
    Write-Host "Deleting existing imported catalog rows..."
    Invoke-SupabaseDelete -Uri "$SupabaseUrl/rest/v1/products?catalog_id=not.is.null"
  }

  Write-Host "Upserting $($products.Count) products..."
  Invoke-SupabaseJson -Uri "$SupabaseUrl/rest/v1/products?on_conflict=catalog_id" -Method "Post" -Body $products

  Write-Host "Fetching Supabase UUIDs for imported products..."
  $headers = @{
    apikey = $env:SUPABASE_SERVICE_ROLE_KEY
    Authorization = "Bearer $env:SUPABASE_SERVICE_ROLE_KEY"
  }
  $catalogRows = Invoke-RestMethod -Uri "$SupabaseUrl/rest/v1/products?select=id,catalog_id&catalog_id=not.is.null" -Method Get -Headers $headers
  $catalogIdToUuid = @{}
  foreach ($row in $catalogRows) {
    $catalogIdToUuid[[string]$row.catalog_id] = [string]$row.id
  }

  $productImages = $rawProductImages | ForEach-Object {
    $productUuid = $catalogIdToUuid[[string]$_.product_id]
    if (-not $productUuid) {
      throw "Could not find Supabase product UUID for catalog_id=$($_.product_id)"
    }

    @{
      product_id = $productUuid
      image_url = $_.image_url
      storage_path = $_.storage_path
      image_kind = $_.image_kind
      sort_order = [int]$_.sort_order
    }
  }

  Write-Host "Upserting $($productImages.Count) product images..."
  Invoke-SupabaseJson -Uri "$SupabaseUrl/rest/v1/product_images?on_conflict=product_id,storage_path" -Method "Post" -Body $productImages
}

Write-Host "Supabase import complete."
