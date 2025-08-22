@echo off
cd C:\Redline
call venv\Scripts\activate
uvicorn backend.main:app --reload
