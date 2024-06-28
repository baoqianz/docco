#!/usr/bin/env pwsh
$basedir=Split-Path $MyInvocation.MyCommand.Definition -Parent

$ret=0
groovy "$basedir/../docco.gy" $args
$ret=$LASTEXITCODE
exit $ret
