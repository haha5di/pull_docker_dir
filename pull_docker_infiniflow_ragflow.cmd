@echo off
setlocal enabledelayedexpansion

:: 设置 CMD 代码页为 UTF-8
chcp 65001 >nul

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
    echo 错误：文件名格式不正确，无法提取目标文件夹名称。
    goto :error
)
if not defined user_name (
    echo 错误：文件名格式不正确，无法提取用户名。
    goto :error
)
if not defined repo_name (
    echo 错误：文件名格式不正确，无法提取仓库名称。
    goto :error
)

set "repo_url=https://github.com/%user_name%/%repo_name%.git"
echo 使用的仓库地址: %repo_url%
echo 目标文件夹: %target_folder_name%

:: 创建带时间戳的文件夹
for /f "tokens=1-6 delims=/:-. " %%a in ('powershell -Command "(Get-Date).ToString('yyyyMMddHHmmss')"' ) do (
  set "timestamp=%%a%%b%%c%%d%%e%%f"
)

set "output_folder=!repo_name!_!target_folder_name!"
if not exist "!output_folder!" (
    mkdir "!output_folder!" || (
        echo 创建输出文件夹失败："!output_folder!"
        goto :error
    )
) else (
    echo 文件夹 "!output_folder!" 已存在，将使用现有文件夹。
)
echo 使用的输出文件夹："!output_folder!"

:: 忽略 SSL 验证
git config --global http.sslVerify false
echo 忽略 SSL 验证

:: 下载仓库中的指定文件夹
set "temp_repo=temp_repo_!timestamp!"
echo 正在克隆仓库...
git clone --depth 1 --sparse "%repo_url%" "!temp_repo!" || (
  echo 克隆仓库失败
  goto :reset_ssl
)
pushd "!temp_repo!"
echo 正在设置稀疏检出...
git sparse-checkout set "%target_folder_name%" || (
  echo 设置稀疏检出失败
  goto :cleanup_temp
)
echo 正在检出主分支...
git checkout main || (
  echo 检出主分支失败
  goto :cleanup_temp
)
echo 正在复制文件夹内容...
xcopy "%target_folder_name%" "..\\!output_folder!" /E /I /Y || (
  echo 复制文件夹内容失败
  goto :cleanup_temp
)
popd
echo 仓库的 "%target_folder_name%" 文件夹已下载到 "!output_folder!"

:: 清理临时仓库
:cleanup_temp
rmdir /s /q "!temp_repo!" >nul
echo 已移除临时仓库

:: 保持 CMD 窗口打开
echo. 按 Enter 键退出...
pause >nul

:: 重置 SSL 验证设置
:reset_ssl
git config --global http.sslVerify true

:end
endlocal
exit /b 0

:error
echo. 请检查错误并重试。
pause
goto :end