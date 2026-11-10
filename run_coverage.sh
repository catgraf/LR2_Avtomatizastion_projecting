#!/usr/bin/env bash

cd "$(dirname "$0")"

echo "=== [1/4] Проверка Verilator ==="
which verilator || { echo "ОШИБКА: verilator не найден"; exit 1; }
verilator --version

echo
echo "=== [2/4] Компиляция с coverage ==="
verilator --binary \
    --timing \
    --coverage-line \
    --coverage-toggle \
    --coverage-branch \
    --top-module tb_triangle_top \
    -Wno-fatal \
    --Mdir obj_dir_cov \
    -o sim_cov \
    apb_master.sv apb_triangle.sv apb_triangle_top.sv apb_tb_triangle_top.sv
RC=$?
if [ $RC -ne 0 ]; then
    echo "ОШИБКА компиляции, rc=$RC"
    exit $RC
fi
echo "OK: obj_dir_cov/sim_cov"
ls -la obj_dir_cov/sim_cov 2>&1

echo
echo "=== [3/4] Симуляция ==="
rm -f coverage.dat
./obj_dir_cov/sim_cov +verilator+coverage+file+coverage.dat
RC=$?
if [ $RC -ne 0 ]; then
    echo "ОШИБКА симуляции, rc=$RC"
    exit $RC
fi

if [ ! -f coverage.dat ]; then
    echo "ОШИБКА: coverage.dat не создан после симуляции"
    exit 1
fi
echo "OK: coverage.dat создан"
ls -la coverage.dat

echo
echo "=== [4/4] Отчёт coverage ==="
rm -rf coverage_report
verilator_coverage --annotate coverage_report --annotate-min 1 coverage.dat
RC=$?
if [ $RC -ne 0 ]; then
    echo "ОШИБКА verilator_coverage, rc=$RC"
    exit $RC
fi

echo "OK: отчёт в coverage_report/"
ls -la coverage_report/