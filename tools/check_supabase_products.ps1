param(
  [string]$SupabaseUrl = "https://jygqfwpqcwnxdtipokqc.supabase.co",
  [string]$AnonKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imp5Z3Fmd3BxY3dueGR0aXBva3FjIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzY1MDgxMjAsImV4cCI6MjA5MjA4NDEyMH0.xVlvrit_qaF33lWQzfLYpwlvo_czWzQKAAu5GByaqAc"
)

$ErrorActionPreference = "Stop"

$headers = @{
  apikey = $AnonKey
  Authorization = "Bearer $AnonKey"
}

$products = Invoke-RestMethod `
  -Uri "$SupabaseUrl/rest/v1/products?select=catalog_id,name,image_url,brand,category,price&order=catalog_id.asc&limit=5" `
  -Method Get `
  -Headers $headers

$allProducts = Invoke-RestMethod `
  -Uri "$SupabaseUrl/rest/v1/products?select=catalog_id,category&catalog_id=not.is.null" `
  -Method Get `
  -Headers $headers

$images = Invoke-RestMethod `
  -Uri "$SupabaseUrl/rest/v1/product_images?select=id,product_id,image_url,storage_path,image_kind,sort_order&limit=5" `
  -Method Get `
  -Headers $headers

$allImages = Invoke-RestMethod `
  -Uri "$SupabaseUrl/rest/v1/product_images?select=id" `
  -Method Get `
  -Headers $headers

Write-Host "Counts:"
Write-Host "Products: $($allProducts.Count)"
Write-Host "Product images: $($allImages.Count)"
Write-Host ""

Write-Host "Products sample:"
$products | Format-Table -AutoSize

Write-Host ""
Write-Host "Product images sample:"
$images | Format-Table -AutoSize
