# Execute using:
# Set-ExecutionPolicy RemoteSigned
# ./MakeWin.ps1 <target>

$env:JIB = "JSC"

$target = $args[0]

function Install {
	param()

	cp ./DLL C:/Windows/System32/Jib
}

if ($target -eq "build") {
	Install
	swift build -Xlinker "$env:SDKROOT\usr\lib\swift\windows\x86_64\swiftCore.lib" -Xswiftc -enable-library-evolution -v --configuration release
} elseif ($target -eq "clean") {
	rm ./.build
} elseif ($target -eq "test") {
	Install
	swift test -Xlinker "$env:SDKROOT\usr\lib\swift\windows\x86_64\swiftCore.lib" -v
} else {
	Write-Host "Unknown target: $target"
}

