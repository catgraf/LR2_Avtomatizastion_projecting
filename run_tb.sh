#!/usr/bin/env bash
# Скрипт запуска тестбенча

set -e  # остановиться при первой ошибке

cd "$(dirname "$0")"

FILES="apb_master.sv apb_triangle.sv apb_triangle_top.sv apb_tb_triangle_top.sv"
OUT="tb_triangle.out"

echo "=== Компиляция ==="
iverilog -g2012 -Wall -o "$OUT" $FILES
echo "OK: $OUT"

echo
echo "=== Симуляция ==="
vvp "$OUT"