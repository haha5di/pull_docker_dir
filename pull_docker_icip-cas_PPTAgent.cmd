@echo off
setlocal enabledelayedexpansion

:: 强制设置 UTF-8 编码环境
chcp 65001 >nul
powershell -Command "$OutputEncoding = [Console]::InputEncoding = [Console]::OutputEncoding = New-Object System.Text.UTF8Encoding" >nul

:: 从文件名中提取参数
set "script_name=%~n0"
set "target_folder_name="
set "user_name="
set "repo_name="

for /f "tokens=1-4 delims=_" %%a in ("%script_name%") do (
    set "target_folder_name=%%b"
    set "user_name=%%c"
    set "repo_name=%%d"
)

:: 验证参数是否正确
if not defined target_folder_name (
    powershell -Command "Write-Output '错误：文件名格式不正确，无法提取目标文件夹名称。'"
    goto :error
)
if not defined user_name (
    powershell -Command "Write-Output '错误：文件名格式不正确，无法提取用户名。'"
    goto :error
)
if not defined repo_name (
    powershell -Command "Write-Output '错误：文件名格式不正确，无法提取仓库名称。'"
    goto :error
)

set "repo_url=https://github.com/%user_name%/%repo_name%.git"
powershell -Command "Write-Output ('使用的仓库地址: {0}' -f '%repo_url%')"
powershell -Command "Write-Output ('目标文件夹: {0}' -f '%target_folder_name%')"

:: 创建带时间戳的文件夹（保留原功能）
set "output_folder=!repo_name!_!target_folder_name!"
if not exist "!output_folder!" (
    mkdir "!output_folder!" || (
        powershell -Command "Write-Output ('创建输出文件夹失败：{0}' -f '!output_folder!')"
        goto :error
    )
) else (
    powershell -Command "Write-Output ('文件夹 {0} 已存在，将使用现有文件夹。' -f '!output_folder!')"
)
powershell -Command "Write-Output ('使用的输出文件夹：{0}' -f '!output_folder!')"

:: 忽略 SSL 验证
git config --global http.sslVerify false
powershell -Command "Write-Output '忽略 SSL 验证'"

:: 下载仓库中的指定文件夹
:: 修改：生成包含毫秒和随机数的临时文件夹名称
for /f "delims=" %%i in ('powershell -Command " 'temp_repo_' + (Get-Date).ToString('yyyyMMddHHmmssfff') + '_' + (Get-Random -Minimum 10000 -Maximum 99999) "') do set "temp_repo=%%i"

powershell -Command "Write-Output '正在克隆仓库...'"
git clone --depth 1 --no-checkout "%repo_url%" "!temp_repo!" || (
  powershell -Command "Write-Output '克隆仓库失败'"
  goto :reset_ssl
)
pushd "!temp_repo!"

:: 🔧 新增：关闭 NTFS 路径保护
git config core.protectNTFS false
powershell -Command "Write-Output 'Git NTFS 路径保护已关闭（core.protectNTFS = false）'"

:: 调试：显示当前目录和 Git 配置
powershell -Command "Write-Output ('当前目录: {0}' -f (Get-Location).Path)"
powershell -Command "Write-Output '检查 Git 配置...'"
git config --list | findstr sparse-checkout >nul
powershell -Command "Write-Output ''"

:: 设置稀疏检出
powershell -Command "Write-Output '正在设置稀疏检出...'"
git sparse-checkout init --cone
git sparse-checkout set "%target_folder_name%" || (
  powershell -Command "Write-Output '设置稀疏检出失败'"
  goto :cleanup_temp
)

:: 检出分支（优先使用 master 分支）
powershell -Command "Write-Output '正在检出 master 分支...'"
git checkout master || (
  powershell -Command "Write-Output '检出 master 分支失败。尝试切换到 main 分支...'"
  git checkout main || (
    powershell -Command "Write-Output '检出分支失败（main 和 master 均不存在）'"
    goto :cleanup_temp
  )
)

:: 验证检出内容
powershell -Command "Write-Output ('检出后的内容（路径 {0}）：' -f '%target_folder_name%')"
powershell -Command "Get-ChildItem -Path '%target_folder_name%' -Recurse | Select-Object -ExpandProperty FullName"
powershell -Command "Write-Output ''"

:: 验证源路径是否存在
if not exist "%target_folder_name%" (
  powershell -Command "Write-Output ('错误：源路径 {0} 不存在！' -f '%target_folder_name%')"
  goto :cleanup_temp
)

:: 复制文件
powershell -Command "Write-Output '正在复制文件夹内容...'"
xcopy "%target_folder_name%" "..\\!output_folder!" /E /I /Y || (
  powershell -Command "Write-Output '复制文件夹内容失败'"
  goto :cleanup_temp
)
popd
powershell -Command "Write-Output ('仓库的 {0} 文件夹已下载到 {1}' -f '%target_folder_name%', '!output_folder!')"

:: 清理临时仓库
:cleanup_temp
rmdir /s /q "!temp_repo!" >nul
powershell -Command "Write-Output '已移除临时仓库'"
goto :error

:: 重置 SSL 验证设置
:reset_ssl
git config --global http.sslVerify true
goto :error

:error
powershell -Command "Write-Output '请检查错误并重试。'"
:: 保持控制台窗口打开
powershell -Command "Write-Output '按 Enter 键退出...'"
pause >nul
:end
endlocal
exit /b 0