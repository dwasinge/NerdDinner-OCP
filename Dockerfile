FROM mcr.microsoft.com/dotnet/framework/sdk:4.8.1 AS build
WORKDIR /app

RUN mkdir nerddinner
COPY . /app/nerddinner/
WORKDIR /app/nerddinner
RUN nuget restore -PackagesDirectory C:\app\packages
RUN nuget restore

RUN msbuild /p:Configuration=Release

FROM mcr.microsoft.com/dotnet/framework/aspnet:4.8-windowsservercore-ltsc2022
ARG source

# Install LogMonitor.exe
RUN powershell New-Item -ItemType Directory C:\LogMonitor; $downloads = @(@{ uri = 'https://github.com/microsoft/windows-container-tools/releases/download/v1.2/LogMonitor.exe'; outFile = 'C:\LogMonitor\LogMonitor.exe' } ); $downloads.ForEach({ Invoke-WebRequest -UseBasicParsing -Uri $psitem.uri -OutFile $psitem.outFile })

# Enable ETW logging for Default Web Site on IIS
RUN c:\windows\system32\inetsrv\appcmd.exe set config -section:system.applicationHost/sites /"[name='Default Web Site'].logFile.logTargetW3C:"File,ETW"" /commit:apphost

WORKDIR /inetpub/wwwroot
COPY --from=build /app/nerddinner/bin /inetpub/wwwroot/bin/
COPY Content Images Scripts Views favicon.ico Global.asax packages.config Readme.md Web.config /inetpub/wwwroot/
#COPY ${source:-obj/Docker/publish} .
COPY psscripts/*.ps1 /inetpub/wwwroot/
COPY psscripts/LogMonitorConfig.json /LogMonitor/LogMonitorConfig.json

# Start "C:\LogMonitor\LogMonitor.exe and application"
SHELL ["C:/LogMonitor/LogMonitor.exe", "powershell.exe"]
ENTRYPOINT ["powershell.exe", "./Startup.ps1"]