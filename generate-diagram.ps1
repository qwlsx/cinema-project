$ErrorActionPreference = 'Stop'

$sqlPath = Join-Path $PSScriptRoot 'project.sql'
$outputPath = Join-Path $PSScriptRoot 'database-diagram.svg'
$sql = Get-Content -LiteralPath $sqlPath -Raw

$tables = [ordered]@{}
$foreignKeys = [System.Collections.Generic.List[object]]::new()
$tablePattern = '(?ms)^CREATE TABLE\s+(\w+)\s*\(\s*(.*?)^\);'

foreach ($match in [regex]::Matches($sql, $tablePattern)) {
    $tableName = $match.Groups[1].Value
    $body = $match.Groups[2].Value
    $primaryKeyColumns = @()
    $primaryKeyMatch = [regex]::Match($body, '(?im)^\s*PRIMARY KEY\s*\(([^)]+)\)')
    if ($primaryKeyMatch.Success) {
        $primaryKeyColumns = $primaryKeyMatch.Groups[1].Value.Split(',') |
            ForEach-Object { $_.Trim() }
    }

    $columns = [System.Collections.Generic.List[object]]::new()
    foreach ($line in ($body -split "`r?`n")) {
        $clean = $line.Trim().TrimEnd(',')
        if (-not $clean -or $clean -match '^(PRIMARY|UNIQUE|CHECK|CONSTRAINT|FOREIGN)\b') {
            continue
        }

        $columnMatch = [regex]::Match(
            $clean,
            '^(\w+)\s+(.+?)(?=\s+(?:GENERATED|NOT\s+NULL|NULL|PRIMARY|UNIQUE|REFERENCES|CHECK|DEFAULT)\b|$)'
        )
        if (-not $columnMatch.Success) { continue }

        $columnName = $columnMatch.Groups[1].Value
        $dataType = $columnMatch.Groups[2].Value.Trim()
        $isPrimaryKey = ($clean -match '\bPRIMARY KEY\b') -or
            ($primaryKeyColumns -contains $columnName)
        $isForeignKey = $clean -match '\bREFERENCES\s+(\w+)\s*\((\w+)\)'
        $isRequired = ($clean -match '\bNOT NULL\b') -or $isPrimaryKey

        $columns.Add([pscustomobject]@{
            Name = $columnName
            Type = $dataType
            IsPrimaryKey = $isPrimaryKey
            IsForeignKey = $isForeignKey
            IsRequired = $isRequired
        })

        if ($isForeignKey) {
            $referenceMatch = [regex]::Match($clean, '\bREFERENCES\s+(\w+)\s*\((\w+)\)')
            $foreignKeys.Add([pscustomobject]@{
                FromTable = $tableName
                FromColumn = $columnName
                ToTable = $referenceMatch.Groups[1].Value
                ToColumn = $referenceMatch.Groups[2].Value
            })
        }
    }
    $tables[$tableName] = $columns
}

if ($tables.Count -eq 0) {
    throw 'No CREATE TABLE statements were found in project.sql.'
}

$positions = @{
    users         = @(40, 80)
    movies        = @(40, 440)
    genres        = @(40, 850)
    cinemas       = @(40, 1110)
    favorites     = @(570, 80)
    movie_genres  = @(570, 300)
    halls         = @(570, 530)
    seats         = @(570, 820)
    screenings    = @(1100, 80)
    bookings      = @(1100, 460)
    tickets       = @(1630, 80)
    payments      = @(1630, 440)
    notifications = @(1630, 780)
}

$cardWidth = 440
$headerHeight = 46
$rowHeight = 25
$paddingBottom = 12
$canvasWidth = 2130
$canvasHeight = 1320

function Encode-Html([string]$value) {
    return [System.Net.WebUtility]::HtmlEncode($value)
}

function Get-CardHeight([string]$tableName) {
    return $headerHeight + ($tables[$tableName].Count * $rowHeight) + $paddingBottom
}

$svg = [System.Text.StringBuilder]::new()
[void]$svg.AppendLine('<?xml version="1.0" encoding="UTF-8"?>')
[void]$svg.AppendLine("<svg xmlns=`"http://www.w3.org/2000/svg`" width=`"$canvasWidth`" height=`"$canvasHeight`" viewBox=`"0 0 $canvasWidth $canvasHeight`">")
[void]$svg.AppendLine(@'
  <defs>
    <filter id="shadow" x="-10%" y="-10%" width="120%" height="130%">
      <feDropShadow dx="0" dy="3" stdDeviation="4" flood-color="#0f172a" flood-opacity="0.16"/>
    </filter>
    <marker id="arrow" viewBox="0 0 10 10" refX="9" refY="5" markerWidth="7" markerHeight="7" orient="auto-start-reverse">
      <path d="M 0 0 L 10 5 L 0 10 z" fill="#64748b"/>
    </marker>
    <style>
      .title { font: 700 25px 'Segoe UI', Arial, sans-serif; fill: #0f172a; }
      .subtitle { font: 14px 'Segoe UI', Arial, sans-serif; fill: #64748b; }
      .table-name { font: 700 17px 'Segoe UI', Arial, sans-serif; fill: white; }
      .column { font: 13px Consolas, monospace; fill: #1e293b; }
      .type { font: 12px Consolas, monospace; fill: #64748b; }
      .key { font: 700 11px 'Segoe UI', Arial, sans-serif; fill: #0369a1; }
      .relation { fill: none; stroke: #64748b; stroke-width: 1.8; marker-end: url(#arrow); }
    </style>
  </defs>
  <rect width="100%" height="100%" fill="#f8fafc"/>
  <text x="40" y="38" class="title">Cinema database ER diagram</text>
  <text x="40" y="61" class="subtitle">Generated from project.sql | PK = primary key | FK = foreign key | ? = nullable</text>
'@)

# Draw relationships first so table cards remain readable above the lines.
foreach ($fk in $foreignKeys) {
    if (-not $positions.ContainsKey($fk.FromTable) -or -not $positions.ContainsKey($fk.ToTable)) {
        continue
    }
    $from = $positions[$fk.FromTable]
    $to = $positions[$fk.ToTable]
    $fromHeight = Get-CardHeight $fk.FromTable
    $toHeight = Get-CardHeight $fk.ToTable
    $x1 = $from[0] + ($cardWidth / 2)
    $y1 = $from[1] + ($fromHeight / 2)
    $x2 = $to[0] + ($cardWidth / 2)
    $y2 = $to[1] + ($toHeight / 2)
    $midX = ($x1 + $x2) / 2
    [void]$svg.AppendLine("  <path class=`"relation`" d=`"M $x1 $y1 L $midX $y1 L $midX $y2 L $x2 $y2`"/>")
}

foreach ($tableName in $tables.Keys) {
    if (-not $positions.ContainsKey($tableName)) { continue }
    $position = $positions[$tableName]
    $x = $position[0]
    $y = $position[1]
    $height = Get-CardHeight $tableName

    [void]$svg.AppendLine("  <g filter=`"url(#shadow)`">")
    [void]$svg.AppendLine("    <rect x=`"$x`" y=`"$y`" width=`"$cardWidth`" height=`"$height`" rx=`"9`" fill=`"white`" stroke=`"#cbd5e1`"/>")
    [void]$svg.AppendLine("    <path d=`"M $($x + 9) $y H $($x + $cardWidth - 9) Q $($x + $cardWidth) $y $($x + $cardWidth) $($y + 9) V $($y + $headerHeight) H $x V $($y + 9) Q $x $y $($x + 9) $y Z`" fill=`"#0f766e`"/>")
    [void]$svg.AppendLine("  </g>")
    [void]$svg.AppendLine("  <text x=`"$($x + 16)`" y=`"$($y + 29)`" class=`"table-name`">$(Encode-Html $tableName)</text>")

    $row = 0
    foreach ($column in $tables[$tableName]) {
        $baseline = $y + $headerHeight + 19 + ($row * $rowHeight)
        if ($row % 2 -eq 1) {
            [void]$svg.AppendLine("  <rect x=`"$($x + 1)`" y=`"$($baseline - 17)`" width=`"$($cardWidth - 2)`" height=`"$rowHeight`" fill=`"#f1f5f9`"/>")
        }
        $keys = @()
        if ($column.IsPrimaryKey) { $keys += 'PK' }
        if ($column.IsForeignKey) { $keys += 'FK' }
        $keyLabel = $keys -join ' '
        $nullableLabel = if ($column.IsRequired) { '' } else { '?' }
        [void]$svg.AppendLine("  <text x=`"$($x + 14)`" y=`"$baseline`" class=`"key`">$(Encode-Html $keyLabel)</text>")
        [void]$svg.AppendLine("  <text x=`"$($x + 66)`" y=`"$baseline`" class=`"column`">$(Encode-Html $column.Name)</text>")
        [void]$svg.AppendLine("  <text x=`"$($x + 260)`" y=`"$baseline`" class=`"type`">$(Encode-Html $column.Type) $nullableLabel</text>")
        $row++
    }
}

[void]$svg.AppendLine('</svg>')
[System.IO.File]::WriteAllText($outputPath, $svg.ToString(), [System.Text.UTF8Encoding]::new($false))
Write-Output "Generated $outputPath from $($tables.Count) tables and $($foreignKeys.Count) foreign keys."
