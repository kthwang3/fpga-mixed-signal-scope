set MIF_FILES=..\MIF\*.mif
set SOURCE_FILES=../top.v ../../rtl/top/*.v ../../rtl/top/vga_adapter_desim/*.v

REM if any memory initialization files exist, copy them to this folder
%WINDIR%\System32\xcopy /y /c /q /i %MIF_FILES% .\MIF

if exist work rmdir /S /Q work

vlib work
vlog ../tb/*.v
vlog %SOURCE_FILES%
