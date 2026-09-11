@echo off
set JAVA_HOME=C:\Program Files\Java\jdk-17
set PATH=%JAVA_HOME%\bin;%PATH%
"C:\Users\Disha\AppData\Local\Android\sdk\cmdline-tools\latest\bin\sdkmanager.bat" --sdk_root="C:\Users\Disha\AppData\Local\Android\sdk" "platforms;android-36" "build-tools;28.0.3"
