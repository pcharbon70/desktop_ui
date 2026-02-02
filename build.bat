@echo off
REM DesktopUI Build Script for Windows (Batch Wrapper)
REM This calls the PowerShell script for the actual build

powershell -ExecutionPolicy Bypass -File "%~dp0build.ps1"
