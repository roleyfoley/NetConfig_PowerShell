# Route Lister
param (
    [Parameter(Mandatory=$true)][string]$AppEnvironment 
)

$AppEnvironment = $AppEnvironment.ToLower()

$RouteList = [System.Collections.ArrayList]@()

switch ( $AppEnvironment ) {
    "development" {
         $RouteList.Add('10.11.250.0/24')
         $RouteList.Add('10.5.22.0/23') 
      }
    "preproduction" {
         $RouteList.Add('10.13.250.0/24')
         $RouteList.Add('10.5.78.0/23')
    }
    "production" {
        $RouteList.Add('10.11.249.0/24')    
    } 
}

$Routes = [String]$RouteList.GetEnumerator() -replace ' ', ','
