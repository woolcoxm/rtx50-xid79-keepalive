@echo off
rem Rebuilds GpuKeepAlive.exe from GpuKeepAlive.cs with the C# compiler that ships with Windows.
rem Nothing to install. Run this from this folder (double-click or from a terminal).
setlocal
set CSC=%WINDIR%\Microsoft.NET\Framework64\v4.0.30319\csc.exe
if not exist "%CSC%" set CSC=%WINDIR%\Microsoft.NET\Framework\v4.0.30319\csc.exe
if not exist "%CSC%" (
    echo The C# compiler csc.exe was not found under %WINDIR%\Microsoft.NET .
    echo Any other C# compiler works too: compile GpuKeepAlive.cs as a Windows exe targeting .NET.
    exit /b 1
)
"%CSC%" /nologo /target:winexe /optimize /warn:4 /out:"%~dp0GpuKeepAlive.exe" "%~dp0GpuKeepAlive.cs"
if errorlevel 1 (
    echo Build failed.
    exit /b 1
)
echo Built GpuKeepAlive.exe
